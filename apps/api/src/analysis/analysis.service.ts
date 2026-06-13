// ============================================================================
// ResearchOS Stats Engine — analysis.service.ts
// Servicio que orquesta el motor R y gestiona los jobs de análisis
// ============================================================================

import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { ConfigService } from '@nestjs/config';
import * as childProcess from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { JobStatus } from '@prisma/client';

export interface AnalysisConfig {
  // Archivo
  file_path: string;
  sheet?: number;
  has_header?: boolean;
  imputation?: 'none' | 'media' | 'mediana';

  // Variables
  var_a: {
    name: string;
    items: string[];
    dimensions?: Array<{ name: string; items: string[] }>;
  };
  var_b: {
    name: string;
    items: string[];
    dimensions?: Array<{ name: string; items: string[] }>;
  };

  // Escala
  scale?: { min: number; max: number };

  // Baremos
  baremo_method?: 'teorico' | 'percentil' | 'tercil' | 'custom_cut';
  baremo_levels?: [string, string, string];

  // Normalidad
  normality_tests?: ('sw' | 'ks')[];
  method_force?: 'auto' | 'pearson' | 'spearman';

  // Análisis
  analysis_types?: ('vv' | 'vdA' | 'vdB' | 'dd')[];
  alpha?: number;
  analysis_category?: 'correlacional' | 'comparacion' | 'regresion' | 'factorial';
  comparison_type?: 'independiente' | 'pareada' | 'auto';
  group_var?: string;
  group_col?: string;
  group_values?: [string, string];

  // Redacción
  participants?: string;
  study_title?: string;
  objective?: string;
  include_reliability?: boolean;
  export_word?: boolean;
  table_start?: number;
}

@Injectable()
export class AnalysisService {
  private readonly logger = new Logger(AnalysisService.name);
  private readonly rScriptPath: string;
  private readonly outputDir: string;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {
    this.rScriptPath = this.config.get<string>('R_ENGINE_PATH') ||
      path.join(__dirname, '../../../stats-engine-r/run_analysis.R');
    this.outputDir = this.config.get<string>('OUTPUT_DIR') ||
      path.join(os.tmpdir(), 'researchos-outputs');
  }

  // ── Crear nuevo job ────────────────────────────────────────────────────────
  async createJob(
    projectId: string,
    datasetId: string,
    analysisConfig: AnalysisConfig,
  ) {
    // Verificar que dataset existe y pertenece al proyecto
    const dataset = await this.prisma.dataset.findFirst({
      where: { id: datasetId, projectId },
    });
    if (!dataset) {
      throw new NotFoundException('Dataset no encontrado en este proyecto.');
    }

    // Inyectar la ruta del archivo almacenado en la configuración
    const fullConfig: AnalysisConfig = {
      ...analysisConfig,
      file_path: dataset.storedPath,
    };

    const job = await this.prisma.analysisJob.create({
      data: {
        projectId,
        datasetId,
        status: 'PENDING',
        config: fullConfig as any,
      },
    });

    // Lanzar análisis de forma asíncrona
    this.runAnalysisAsync(job.id, fullConfig).catch((err) => {
      this.logger.error(`Job ${job.id} falló:`, err);
    });

    return job;
  }

  // ── Obtener job por ID ─────────────────────────────────────────────────────
  async getJob(jobId: string) {
    const job = await this.prisma.analysisJob.findUnique({
      where: { id: jobId },
      include: { result: true },
    });
    if (!job) throw new NotFoundException('Job no encontrado.');
    return job;
  }

  // ── Listar jobs por proyecto ───────────────────────────────────────────────
  async listJobsByProject(projectId: string) {
    return this.prisma.analysisJob.findMany({
      where: { projectId },
      orderBy: { createdAt: 'desc' },
      include: {
        result: {
          select: {
            method: true,
            correlations: true,
            warnings: true,
          },
        },
      },
    });
  }

  // ── Ejecutar motor R de forma asíncrona ───────────────────────────────────
  private async runAnalysisAsync(jobId: string, config: AnalysisConfig) {
    // Marcar como PROCESSING
    await this.prisma.analysisJob.update({
      where: { id: jobId },
      data: { status: 'PROCESSING', startedAt: new Date() },
    });

    try {
      const rResult = await this.invokeREngine(config);

      if (rResult.status === 'error') {
        throw new Error(
          Array.isArray(rResult.errors) ? rResult.errors.join('; ') : 'Error en motor R',
        );
      }

      // Guardar resultados en BD
      await this.prisma.analysisResult.create({
        data: {
          jobId,
          method:         rResult.method ?? 'spearman',
          diagnostic:     rResult.diagnostic ?? {},
          descriptives:   rResult.descriptives ?? [],
          reliability:    rResult.reliability ?? [],
          normality:      rResult.normality ?? [],
          correlations:   rResult.correlations ?? [],
          baremoA:        rResult.baremo_a ?? null,
          baremoB:        rResult.baremo_b ?? null,
          interpretations: rResult.interpretations ?? {},
          warnings:       rResult.warnings ?? [],
          wordPath:       rResult.word_path ?? null,
          ttest:          rResult.ttest ?? null,
          anova:          rResult.anova ?? null,
          regression:     rResult.regression ?? null,
          logistic:       rResult.logistic ?? null,
          chi_square:     rResult.chi_square ?? null,
          instruments:    rResult.instruments ?? null,
        },
      });

      await this.prisma.analysisJob.update({
        where: { id: jobId },
        data: { status: 'COMPLETED', finishedAt: new Date() },
      });

      this.logger.log(`✅ Job ${jobId} completado. Método: ${rResult.method}`);
    } catch (err) {
      this.logger.error(`❌ Job ${jobId} falló: ${err.message}`);
      await this.prisma.analysisJob.update({
        where: { id: jobId },
        data: {
          status: 'FAILED',
          finishedAt: new Date(),
          errorMsg: err.message,
        },
      });
    }
  }

  // ── Invocar el motor R ────────────────────────────────────────────────────
  private invokeREngine(config: AnalysisConfig): Promise<any> {
    return new Promise((resolve, reject) => {
      // Crear archivo temporal de configuración JSON
      const tmpDir    = os.tmpdir();
      const configId  = `analysis_${Date.now()}_${Math.random().toString(36).slice(2)}`;
      const configFile = path.join(tmpDir, `${configId}_config.json`);
      const jobOutputDir = path.join(this.outputDir, configId);

      fs.mkdirSync(jobOutputDir, { recursive: true });
      fs.writeFileSync(configFile, JSON.stringify(config), 'utf-8');

      const rBin     = this.config.get<string>('R_BIN') || 'Rscript';
      const timeout  = parseInt(this.config.get<string>('R_TIMEOUT_MS') || '120000');

      const proc = childProcess.spawn(
        rBin,
        [this.rScriptPath, configFile, jobOutputDir],
        {
          timeout,
          env: {
            ...process.env,
            // Seguridad: no exponer variables sensibles
            PATH: process.env.PATH,
          },
        },
      );

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => { stdout += data.toString(); });
      proc.stderr.on('data', (data) => { stderr += data.toString(); });

      proc.on('close', (code) => {
        // Limpiar config temporal
        try { fs.unlinkSync(configFile); } catch {}

        if (code !== 0) {
          this.logger.warn(`R stderr: ${stderr}`);
          return reject(new Error(`Motor R salió con código ${code}. ${stderr.slice(0, 500)}`));
        }

        try {
          const jsonMatch = stdout.match(/\{[\s\S]*\}/); if (!jsonMatch) throw new Error("no json"); const result = JSON.parse(jsonMatch[0]);
          resolve(result);
        } catch (parseErr) {
          this.logger.error('Salida R no parseable:', stdout.slice(0, 500));
          reject(new Error('Motor R devolvió salida inválida.'));
        }
      });

      proc.on('error', (err) => {
        reject(new Error(`No se pudo ejecutar Rscript: ${err.message}`));
      });
    });
  }

  // ── Obtener path del Word para descarga ───────────────────────────────────
  async getWordPath(jobId: string): Promise<string> {
    const result = await this.prisma.analysisResult.findUnique({
      where: { jobId },
      select: { wordPath: true },
    });
    if (!result?.wordPath) {
      throw new NotFoundException('Documento Word no disponible para este análisis.');
    }
    if (!fs.existsSync(result.wordPath)) {
      throw new NotFoundException('El archivo Word ya no está disponible en el servidor.');
    }
    return result.wordPath;
  }

  // ── Obtener resultado completo ─────────────────────────────────────────────
  async getResult(jobId: string) {
    const result = await this.prisma.analysisResult.findUnique({
      where: { jobId },
    });
    if (!result) throw new NotFoundException('Resultado no disponible aún.');
    return result;
  }
}
