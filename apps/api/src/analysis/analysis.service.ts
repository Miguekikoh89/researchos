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
import * as XLSX from 'xlsx';
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
  analysis_category?: 'correlacional' | 'comparacion' | 'regresion' | 'factorial' | 'structural_model'
    | 'regresion_ordinal' | 'regresion_jerarquica' | 'ancova' | 'discriminante' | 'frecuencias'
    | 'cluster' | 'cronbach' | 'baremos' | 'descriptivos' | 'descriptivo'
    | 'anova' | 'logistica' | 'chi_cuadrado' | 'instrumentos' | 'mediacion';
  hierarchical_blocks?: Array<{name: string; items: string[]}>;
  n_clusters?: number;

  // Nivel de medición (F-021, F-022, F-024)
  measurement_level_a?: 'nominal' | 'ordinal' | 'interval' | 'ratio';
  measurement_level_b?: 'nominal' | 'ordinal' | 'interval' | 'ratio';

  // Niveles ordenados para VD ordinal — obligatorio en regresion_ordinal (F-024)
  ordered_levels?: string[];

  // Evento de referencia para logística binaria — obligatorio (F-023)
  event_level?: string;

  // Categoría de referencia para logística multinomial
  reference_level?: string;

  // Mediación
  mediator?: string;
  mediators?: string[];

  // Bootstrap genérico (para mediación)
  bootstrap?: boolean;
  seed?: number;

  // Subtipo logístico (binaria | multinomial)
  logistic_type?: 'binaria' | 'multinomial';

  // PLS-SEM
  engine?: string;
  constructs?: Array<{ name: string; items: string[] }>;
  structural_paths?: Array<{ from: string; to: string }>;
  n_boot?: number;
  scale_min?: number;
  scale_max?: number;
  ipma_target?: string | null;
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

// Block 7: Sanitiza valores no-finitos recursivamente.
// NaN/Infinity/-Infinity/undefined → null para que JSON.stringify genere null
// y PostgreSQL lo almacene como SQL NULL en campos Json?.
export function rejectNonFinite(value: any): any {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === 'string') return value;
  if (typeof value === 'boolean') return value;
  if (Array.isArray(value)) return value.map(rejectNonFinite);
  if (typeof value === 'object') {
    const out: Record<string, any> = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = rejectNonFinite(v);
    }
    return out;
  }
  return value;
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
      const isPls = config.analysis_category === 'structural_model';
      const rResult = isPls ? await this.invokePlsEngine(config) : await this.invokeREngine(config);
      if (isPls) {
        if (rResult.blocked) {
          throw new Error(rResult.error ?? 'Bloqueo metodológico en PLS-SEM.');
        }
        await this.prisma.analysisResult.create({
          data: {
            jobId,
            method: 'pls_sem',
            diagnostic: rResult.tables ?? {},
            descriptives: [],
            reliability: rResult.tables?.Confiabilidad ?? [],
            normality: [],
            correlations: rResult.tables?.Paths ?? [],
            interpretations: { pls: rResult },
            warnings: [],
            wordPath: rResult.word_path ?? null,
          },
        });
        await this.prisma.analysisJob.update({ where: { id: jobId }, data: { status: 'COMPLETED', finishedAt: new Date() } });
        return;
      }

      if (rResult.status === 'error' || rResult.blocked === true) {
        const errMsg = Array.isArray(rResult.errors)
          ? rResult.errors.join('; ')
          : (rResult.error ?? 'Error en motor R');
        throw new Error(errMsg);
      }

      // Un payload de método con error embebido (tryCatch del despachador R)
      // no puede terminar COMPLETED: ningún resultado parcial/errado se
      // persiste como éxito.
      const methodPayloadKeys = [
        'anova', 'regression', 'logistic', 'chi_square', 'instruments',
        'ordinal_regression', 'hierarchical_regression', 'ancova',
        'discriminant', 'frequencies', 'cluster', 'cronbach_only',
        'baremos_only', 'descriptives_full', 'analisis_descriptivo', 'mediation',
      ];
      for (const key of methodPayloadKeys) {
        const payload = rResult[key];
        if (
          payload && typeof payload === 'object' && !Array.isArray(payload) &&
          typeof payload.error === 'string' && payload.error.length > 0
        ) {
          throw new Error(`Error en motor R (${key}): ${payload.error}`);
        }
      }

      // Sanitizar valores no-finitos antes de persistir (Block 7)
      const safeResult = rejectNonFinite(rResult);

      // Guardar resultados en BD
      await this.prisma.analysisResult.create({
        data: {
          jobId,
          method:         safeResult.method ?? 'spearman',
          diagnostic:     safeResult.diagnostic ?? {},
          descriptives:   safeResult.descriptives ?? [],
          reliability:    safeResult.reliability ?? [],
          normality:      safeResult.normality ?? [],
          correlations:   safeResult.correlations ?? [],
          baremoA:        safeResult.baremo_a ?? null,
          baremoB:        safeResult.baremo_b ?? null,
          interpretations: safeResult.interpretations ?? {},
          warnings:       safeResult.warnings ?? [],
          wordPath:       safeResult.word_path ?? null,
          ttest:          safeResult.ttest ?? null,
          anova:          safeResult.anova ?? null,
          regression:     safeResult.regression ?? null,
          logistic:       safeResult.logistic ?? null,
          chi_square:     safeResult.chi_square ?? null,
          instruments:    safeResult.instruments ?? null,
          ordinal_regression: safeResult.ordinal_regression ?? null,
          hierarchical_regression: safeResult.hierarchical_regression ?? null,
          ancova:           safeResult.ancova ?? null,
          discriminant:     safeResult.discriminant ?? null,
          frequencies:      safeResult.frequencies ?? null,
          cluster:          safeResult.cluster ?? null,
          cronbach_only:    safeResult.cronbach_only ?? null,
          baremos_only:     safeResult.baremos_only ?? null,
          descriptives_full: safeResult.descriptives_full ?? null,
          analisis_descriptivo: safeResult.analisis_descriptivo ?? null,
          mediation:            safeResult.mediation ?? null,
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

  
  // ── Invocar motor PLS-SEM ─────────────────────────────────────────────────
  // ── Filtra el Excel para dejar SOLO columnas numéricas relevantes para PLS-SEM ──
  // Esto evita que columnas de texto (Sexo, Área, etc.) se conviertan en NA y
  // eliminen todas las filas via complete.cases() dentro del motor R blindado.
  private buildPlsCleanDataFile(originalPath: string, config: AnalysisConfig): string {
    try {
      const wb = XLSX.readFile(originalPath);
      const sheetName = wb.SheetNames[0];
      const ws = wb.Sheets[sheetName];
      const json: any[] = XLSX.utils.sheet_to_json(ws, { defval: null });
      if (!json.length) return originalPath;

      // Columnas necesarias: todas las de los constructos + group_var si existe
      const constructs = config.constructs ?? [];
      const neededCols = new Set<string>();
      for (const c of constructs) {
        for (const item of (c.items ?? [])) neededCols.add(item);
      }
      if (config.group_var) neededCols.add(config.group_var);

      // Si no hay columnas necesarias detectadas, no filtrar (fallback seguro)
      if (neededCols.size === 0) return originalPath;

      const filtered = json.map((row) => {
        const out: any = {};
        for (const col of neededCols) {
          if (col in row) out[col] = row[col];
        }
        return out;
      });

      const newWs = XLSX.utils.json_to_sheet(filtered);
      const newWb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(newWb, newWs, 'Datos');
      const tmpPath = path.join(os.tmpdir(), `pls_clean_${Date.now()}.xlsx`);
      XLSX.writeFile(newWb, tmpPath);
      this.logger.log(`PLS-SEM: archivo filtrado a ${neededCols.size} columnas numéricas → ${tmpPath}`);
      return tmpPath;
    } catch (e: any) {
      this.logger.warn(`No se pudo filtrar el Excel para PLS-SEM, usando original: ${e.message}`);
      return originalPath;
    }
  }

  private invokePlsEngine(config: AnalysisConfig): Promise<any> {
    return new Promise((resolve, reject) => {
      const plsScriptPath = '/app/stats-engine-r/R/pls_sem_engine.R';
      const cleanDataPath = this.buildPlsCleanDataFile(config.file_path, config);
      const plsParams = {
        data_path:         cleanDataPath,
        constructs:        config.constructs ?? [],
        paths:             config.structural_paths ?? [],
        n_boot:            config.n_boot ?? 5000,
        calc_q2:           true,
        omission_distance: 7,
        study_title:       config.study_title ?? 'Modelo PLS-SEM',
        language:          'es',
        group_var:         config.group_var ?? null,
        scale_min:         config.scale_min ?? 1,
        scale_max:         config.scale_max ?? 5,
        ipma_target:       config.ipma_target ?? null,
        n_permut:          100,
      };
      const tmpFile = path.join(os.tmpdir(), `pls_${Date.now()}.json`);
      fs.writeFileSync(tmpFile, JSON.stringify(plsParams), 'utf8');
      const rBin = this.config.get('R_BIN') || '/usr/bin/Rscript';
      const proc = require('child_process').spawn(rBin, [plsScriptPath, tmpFile], {
        timeout: 600000, // 10 min: investigadores reales suelen usar 5000-10000 bootstraps en PLS-SEM
        env: { ...process.env, PATH: process.env.PATH },
      });
      let stdout = ''; let stderr = '';
      proc.stdout.on('data', (d) => { stdout += d.toString(); });
      proc.stderr.on('data', (d) => { stderr += d.toString(); });
      proc.on('close', (code) => {
        try { fs.unlinkSync(tmpFile); } catch (_) {}
        if (cleanDataPath !== config.file_path) { try { fs.unlinkSync(cleanDataPath); } catch (_) {} }
        if (code !== 0) return reject(new Error('PLS-SEM R error: ' + stderr.slice(0, 600)));
        try {
          const start = stdout.indexOf('{');
          const end   = stdout.lastIndexOf('}');
          if (start === -1 || end === -1) throw new Error('No JSON in stdout: ' + stdout.slice(0, 300));
          const parsed = JSON.parse(stdout.slice(start, end + 1));
          // Generar el Word APA del modelo PLS-SEM a partir del resultado ya calculado.
          // Best-effort: si falla, el analisis se entrega igual, sin Word.
          try {
            const resultTmpFile = path.join(os.tmpdir(), `pls_result_${Date.now()}.json`);
            fs.writeFileSync(resultTmpFile, JSON.stringify(parsed), 'utf8');
            const outDir = path.join(os.tmpdir(), `pls_word_${Date.now()}`);
            fs.mkdirSync(outDir, { recursive: true });
            const wordProc = require('child_process').spawnSync(
              rBin,
              ['/app/stats-engine-r/R/pls_word_wrapper.R', resultTmpFile, outDir, config.study_title ?? 'Modelo PLS-SEM'],
              { timeout: 60000 }
            );
            try { fs.unlinkSync(resultTmpFile); } catch (_) {}
            const wordOut = wordProc.stdout?.toString() ?? '';
            const wStart = wordOut.indexOf('{');
            const wEnd = wordOut.lastIndexOf('}');
            if (wStart !== -1 && wEnd !== -1) {
              const wordResult = JSON.parse(wordOut.slice(wStart, wEnd + 1));
              if (wordResult.word_path) parsed.word_path = wordResult.word_path;
            }
          } catch (wordErr: any) { this.logger.warn('PLS-SEM Word generation failed (non-blocking): ' + wordErr.message); }
          resolve(parsed);
        } catch (e: any) { reject(new Error('PLS-SEM parse error: ' + e.message)); }
      });
      proc.on('error', (e) => reject(new Error('No se pudo ejecutar Rscript: ' + e.message)));
    });
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
      try {
        const fd = fs.openSync(configFile, 'r+');
        fs.fsyncSync(fd);
        fs.closeSync(fd);
      } catch (fsyncErr) {
        this.logger.warn(`No se pudo fsync configFile: ${fsyncErr}`);
      }

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
        if (code !== 0) {
          this.logger.error(`[R_SPAWN_FAIL] code=${code}`);
          this.logger.error(`[R_STDERR] ${stderr || '(vacio)'}`);
          this.logger.error(`[R_STDOUT] ${stdout.slice(0, 1000) || '(vacio)'}`);
          this.logger.error(`[CONFIG_FILE_EXISTS] ${fs.existsSync(configFile)}`);
          try { fs.unlinkSync(configFile); } catch {}
          return reject(new Error(`Motor R salió con código ${code}. ${stderr.slice(0, 500)}`));
        }
        try { fs.unlinkSync(configFile); } catch {}

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
