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
  bootstrap_seed?: number;
  scale_min?: number;
  scale_max?: number;
  ipma_target?: string | null;
  advanced_pls?: boolean;
  calc_srmr?: boolean;
  calc_q2?: boolean;
  q2_omission_distance?: number;
  calc_pls_predict?: boolean;
  pls_predict_folds?: number;
  pls_predict_reps?: number;
  calc_htmt_ci?: boolean;
  calc_full_vif?: boolean;
  full_vif_threshold?: number;
  calc_vaf?: boolean;
  calc_ipma?: boolean;
  calc_gaussian_copula?: boolean;
  copula_boot?: number;
  calc_micom?: boolean;
  calc_mga?: boolean;
  n_permut?: number;
  advanced_seed?: number;
  control_variables?: Array<{ name?: string; column: string; targets: string[] }>;
  calc_fimix?: boolean;
  fimix_k_min?: number;
  fimix_k_max?: number;
  fimix_nstart?: number;
  fimix_max_iter?: number;
  fimix_stop_criterion?: number;
  use_fimix_for_mga?: boolean;
  compare_models?: boolean;
  comparison_roles?: { x?: string; m1?: string; m2?: string; y?: string };
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


  private requireFinite(value: unknown, label: string, min?: number, max?: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw new Error(`Contrato numérico inválido: ${label} no es un número finito.`);
    }
    if (min !== undefined && value < min) {
      throw new Error(`Contrato numérico inválido: ${label}=${value} es menor que ${min}.`);
    }
    if (max !== undefined && value > max) {
      throw new Error(`Contrato numérico inválido: ${label}=${value} es mayor que ${max}.`);
    }
    return value;
  }

  private requireProbability(value: unknown, label: string): number {
    return this.requireFinite(value, label, 0, 1);
  }

  private assertAllNumbersFinite(value: any, label = 'resultado'): void {
    if (value === null || value === undefined) return;
    if (typeof value === 'number') {
      if (!Number.isFinite(value)) {
        throw new Error(`Contrato numérico inválido: ${label} contiene un valor no finito.`);
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((v, i) => this.assertAllNumbersFinite(v, `${label}[${i}]`));
      return;
    }
    if (typeof value !== 'object') return;
    for (const [key, child] of Object.entries(value)) {
      this.assertAllNumbersFinite(child, `${label}.${key}`);
    }
  }

  private assertNoNestedFailure(value: any, label = 'resultado'): void {
    if (value === null || value === undefined) return;
    if (Array.isArray(value)) {
      value.forEach((v, i) => this.assertNoNestedFailure(v, `${label}[${i}]`));
      return;
    }
    if (typeof value !== 'object') return;
    const embeddedError = typeof value.error === 'string' && value.error.trim().length > 0
      ? value.error.trim()
      : null;
    const embeddedErrors = Array.isArray(value.errors)
      ? value.errors.filter((item: unknown) => typeof item === 'string' && item.trim().length > 0)
      : [];
    if (value.blocked === true || value.success === false || value.status === 'error' || embeddedError || embeddedErrors.length > 0) {
      const detail = embeddedError ?? (embeddedErrors.length > 0 ? embeddedErrors.join('; ') : null) ?? value.reason ?? 'sin detalle';
      throw new Error(`Resultado bloqueado en ${label}: ${detail}`);
    }
    for (const [key, child] of Object.entries(value)) {
      this.assertNoNestedFailure(child, `${label}.${key}`);
    }
  }

  private assertProbabilityFields(value: any, label = 'resultado'): void {
    if (value === null || value === undefined) return;
    if (Array.isArray(value)) {
      value.forEach((v, i) => this.assertProbabilityFields(v, `${label}[${i}]`));
      return;
    }
    if (typeof value !== 'object') return;
    const probabilityKey = /^(p|p_value|pvalor|p_valor|p_adj|p_adjusted|p_ajustado|p_bonf|p_raw|p_change|p_grupo|p_lr|lr_p|direct_p|sobel_p|P_Valor|p_permutacion|p_permutacion_ajustado|p_dif_medias|p_dif_medias_ajustado|p_dif_varianzas|p_dif_varianzas_ajustado|Normalidad_p)$/i;
    for (const [key, child] of Object.entries(value)) {
      if (probabilityKey.test(key) && child !== null && child !== undefined) {
        this.requireProbability(child, `${label}.${key}`);
      }
      this.assertProbabilityFields(child, `${label}.${key}`);
    }
  }

  private validatePlsContract(result: any): void {
    this.assertAllNumbersFinite(result, 'pls');
    this.assertNoNestedFailure(result, 'pls');
    this.requireFinite(result.n_observations, 'pls.n_observations', 30);
    this.requireFinite(result.n_boot, 'pls.n_boot', 1000);
    if (!result.tables || !Array.isArray(result.tables.Paths) || result.tables.Paths.length < 1) {
      throw new Error('Contrato PLS inválido: falta la tabla de rutas.');
    }
    const requiredCoreTables = ['Confiabilidad', 'Cargas', 'R2', 'HTMT', 'FornellLarcker', 'CrossLoadings', 'VIF'];
    for (const key of requiredCoreTables) {
      if (!Array.isArray(result.tables[key]) || result.tables[key].length < 1) {
        throw new Error(`Contrato PLS inválido: falta la tabla núcleo ${key}.`);
      }
    }
    result.tables.Paths.forEach((row: any, i: number) => {
      this.requireFinite(row.Beta, `pls.Paths[${i}].Beta`);
      this.requireFinite(row.STDEV, `pls.Paths[${i}].STDEV`, Number.MIN_VALUE);
      this.requireProbability(row.P_Valor, `pls.Paths[${i}].P_Valor`);
      const lo = this.requireFinite(row['IC_2.5'], `pls.Paths[${i}].IC_2.5`);
      const hi = this.requireFinite(row['IC_97.5'], `pls.Paths[${i}].IC_97.5`);
      if (lo > hi) throw new Error(`Contrato PLS inválido: IC invertido en ruta ${i + 1}.`);
      if (typeof row.CI_Significant !== 'boolean') {
        throw new Error(`Contrato PLS inválido: falta CI_Significant en ruta ${i + 1}.`);
      }
    });
    result.tables.Confiabilidad.forEach((row: any, i: number) => {
      const isControl = String(row.Tipo ?? '').toLowerCase().includes('control');
      if (!isControl || row.Composite_Reliability_CR !== null && row.Composite_Reliability_CR !== undefined) {
        this.requireFinite(row.Composite_Reliability_CR, `pls.Confiabilidad[${i}].CR`, 0, 1);
      }
      if (!isControl || row.AVE !== null && row.AVE !== undefined) {
        this.requireFinite(row.AVE, `pls.Confiabilidad[${i}].AVE`, 0, 1);
      }
    });
    result.tables.Cargas.forEach((row: any, i: number) => {
      this.requireFinite(row.Loading, `pls.Cargas[${i}].Loading`, -1, 1);
    });
    result.tables.R2.forEach((row: any, i: number) => {
      this.requireFinite(row.R2, `pls.R2[${i}].R2`, 0, 1);
      this.requireFinite(row.R2_adj, `pls.R2[${i}].R2_adj`, -1, 1);
    });
    result.tables.HTMT.forEach((row: any, i: number) => {
      this.requireFinite(row.HTMT, `pls.HTMT[${i}].HTMT`, 0);
    });
    result.tables.VIF.forEach((row: any, i: number) => {
      this.requireFinite(row.VIF, `pls.VIF[${i}].VIF`, 1);
    });
    if (result.tables.IndirectEffects !== null && result.tables.IndirectEffects !== undefined) {
      if (!Array.isArray(result.tables.IndirectEffects)) {
        throw new Error('Contrato PLS inválido: IndirectEffects debe ser una tabla o null.');
      }
      result.tables.IndirectEffects.forEach((row: any, i: number) => {
        this.requireFinite(row.Beta_ind, `pls.IndirectEffects[${i}].Beta_ind`);
        this.requireFinite(row.STDEV, `pls.IndirectEffects[${i}].STDEV`, Number.MIN_VALUE);
        this.requireProbability(row.P_Valor, `pls.IndirectEffects[${i}].P_Valor`);
        const lo = this.requireFinite(row['IC_2.5'], `pls.IndirectEffects[${i}].IC_2.5`);
        const hi = this.requireFinite(row['IC_97.5'], `pls.IndirectEffects[${i}].IC_97.5`);
        if (lo > hi || typeof row.CI_Significant !== 'boolean') {
          throw new Error(`Contrato PLS inválido: efecto indirecto inconsistente en fila ${i + 1}.`);
        }
      });
    }

    const optionalTable = (key: string): any[] => {
      const table = result.tables[key];
      if (table === null || table === undefined) return [];
      if (!Array.isArray(table)) {
        // El motor R puede devolver un objeto de estado (string, objeto) cuando
        // un modulo opcional esta deshabilitado o fallo internamente.
        // En ese caso, tratamos como tabla vacia para no bloquear el analisis.
        return [];
      }
      return table;
    };
    optionalTable('SRMR').forEach((row: any, i: number) => {
      this.requireFinite(row.Valor, `pls.SRMR[${i}].Valor`, 0);
    });
    optionalTable('Q2').forEach((row: any, i: number) => {
      this.requireFinite(row.Q2, `pls.Q2[${i}].Q2`, -100, 1);
      this.requireFinite(row.SSE, `pls.Q2[${i}].SSE`, 0);
      this.requireFinite(row.SSO, `pls.Q2[${i}].SSO`, Number.MIN_VALUE);
    });
    optionalTable('PLSPredict').forEach((row: any, i: number) => {
      this.requireFinite(row.RMSE_modelo, `pls.PLSPredict[${i}].RMSE_modelo`, 0);
      this.requireFinite(row.RMSE_naive, `pls.PLSPredict[${i}].RMSE_naive`, 0);
      this.requireFinite(row.RMSE_LM, `pls.PLSPredict[${i}].RMSE_LM`, 0);
      this.requireFinite(row.Q2_predict, `pls.PLSPredict[${i}].Q2_predict`, -100, 1);
    });
    optionalTable('HTMT_CI').forEach((row: any, i: number) => {
      const lo = this.requireFinite(row['IC_2.5'], `pls.HTMT_CI[${i}].IC_2.5`, 0);
      const hi = this.requireFinite(row['IC_97.5'], `pls.HTMT_CI[${i}].IC_97.5`, 0);
      if (lo > hi) throw new Error(`Contrato PLS inválido: IC HTMT invertido en fila ${i + 1}.`);
    });
    optionalTable('FullVIF_CMB').forEach((row: any, i: number) => {
      this.requireFinite(row.VIF_Full, `pls.FullVIF_CMB[${i}].VIF_Full`, 1);
    });
    optionalTable('VAF_Mediacion').forEach((row: any, i: number) => {
      this.requireFinite(row.Beta_indirecto, `pls.VAF_Mediacion[${i}].Beta_indirecto`);
      this.requireFinite(row.Beta_total, `pls.VAF_Mediacion[${i}].Beta_total`);
      if (row.Beta_directo !== null && row.Beta_directo !== undefined) {
        this.requireFinite(row.Beta_directo, `pls.VAF_Mediacion[${i}].Beta_directo`);
      }
      if (row.VAF_pct !== null && row.VAF_pct !== undefined) {
        this.requireFinite(row.VAF_pct, `pls.VAF_Mediacion[${i}].VAF_pct`, -10000, 10000);
      }
      if (typeof row.Directo_significativo_IC !== 'boolean' || typeof row.Indirecto_significativo_IC !== 'boolean') {
        throw new Error(`Contrato PLS inválido: clasificación de mediación incompleta en fila ${i + 1}.`);
      }
    });
    optionalTable('GaussianCopula').forEach((row: any, i: number) => {
      this.requireFinite(row.PLS_Beta_Original, `pls.GaussianCopula[${i}].PLS_Beta_Original`);
      this.requireFinite(row.PLS_Beta_Corregido, `pls.GaussianCopula[${i}].PLS_Beta_Corregido`);
      this.requireFinite(row.Copula_Coef, `pls.GaussianCopula[${i}].Copula_Coef`);
      this.requireFinite(row.Std_Error, `pls.GaussianCopula[${i}].Std_Error`, Number.MIN_VALUE);
      const gcLo = this.requireFinite(row.IC_lo, `pls.GaussianCopula[${i}].IC_lo`);
      const gcHi = this.requireFinite(row.IC_hi, `pls.GaussianCopula[${i}].IC_hi`);
      const betaLo = this.requireFinite(row.Beta_Corregido_IC_lo, `pls.GaussianCopula[${i}].Beta_Corregido_IC_lo`);
      const betaHi = this.requireFinite(row.Beta_Corregido_IC_hi, `pls.GaussianCopula[${i}].Beta_Corregido_IC_hi`);
      if (gcLo > gcHi || betaLo > betaHi) {
        throw new Error(`Contrato PLS inválido: IC de cópula invertido en fila ${i + 1}.`);
      }
      this.requireProbability(row.p_valor, `pls.GaussianCopula[${i}].p_valor`);
      this.requireProbability(row.Normalidad_p, `pls.GaussianCopula[${i}].Normalidad_p`);
      this.requireFinite(row.Cor_X_Copula, `pls.GaussianCopula[${i}].Cor_X_Copula`, -1, 1);
      this.requireFinite(row.Omega_Simple, `pls.GaussianCopula[${i}].Omega_Simple`, 0, 1);
      this.requireFinite(row.Bootstrap_Valid, `pls.GaussianCopula[${i}].Bootstrap_Valid`, 160);
      if (typeof row.Bootstrap_Alcance !== 'string' || !row.Bootstrap_Alcance.includes('condicional')) {
        throw new Error(`Contrato PLS inválido: alcance bootstrap de cópula ausente en fila ${i + 1}.`);
      }
    });
    optionalTable('MICOM').forEach((row: any, i: number) => {
      this.requireProbability(row.p_permutacion, `pls.MICOM[${i}].p_permutacion`);
      this.requireProbability(row.p_permutacion_ajustado, `pls.MICOM[${i}].p_permutacion_ajustado`);
      this.requireProbability(row.p_dif_medias, `pls.MICOM[${i}].p_dif_medias`);
      this.requireProbability(row.p_dif_medias_ajustado, `pls.MICOM[${i}].p_dif_medias_ajustado`);
      this.requireProbability(row.p_dif_varianzas, `pls.MICOM[${i}].p_dif_varianzas`);
      this.requireProbability(row.p_dif_varianzas_ajustado, `pls.MICOM[${i}].p_dif_varianzas_ajustado`);
      if (typeof row.Compositional_Invariance !== 'boolean') {
        throw new Error(`Contrato PLS inválido: MICOM sin decisión composicional en fila ${i + 1}.`);
      }
    });
    optionalTable('MGA').forEach((row: any, i: number) => {
      this.requireProbability(row.p_valor, `pls.MGA[${i}].p_valor`);
      this.requireProbability(row.p_ajustado, `pls.MGA[${i}].p_ajustado`);
    });
    optionalTable('IPMA').forEach((row: any, i: number) => {
      this.requireFinite(row.Importancia_Efecto_Total, `pls.IPMA[${i}].Importancia_Efecto_Total`);
      this.requireFinite(row.Performance_0_100, `pls.IPMA[${i}].Performance_0_100`, 0, 100);
      this.requireFinite(row.Scale_Min, `pls.IPMA[${i}].Scale_Min`);
      this.requireFinite(row.Scale_Max, `pls.IPMA[${i}].Scale_Max`);
      if (Number(row.Scale_Max) <= Number(row.Scale_Min)) {
        throw new Error(`Contrato PLS inválido: límites teóricos IPMA invertidos en fila ${i + 1}.`);
      }
    });
    optionalTable('Controls').forEach((row: any, i: number) => {
      for (const key of ['Control', 'Columna', 'Destinos']) {
        if (typeof row[key] !== 'string' || row[key].trim().length === 0) {
          throw new Error(`Contrato PLS inválido: Controls[${i}].${key} ausente.`);
        }
      }
    });
    optionalTable('FIMIX_Fit').forEach((row: any, i: number) => {
      this.requireFinite(row.K, `pls.FIMIX_Fit[${i}].K`, 2, 8);
      if (row.Seleccionado !== null && row.Seleccionado !== undefined && typeof row.Seleccionado !== 'boolean') {
        throw new Error(`Contrato PLS inválido: FIMIX_Fit[${i}].Seleccionado debe ser booleano.`);
      }
    });
    optionalTable('FIMIX_Segments').forEach((row: any, i: number) => {
      this.requireFinite(row.Segmento, `pls.FIMIX_Segments[${i}].Segmento`, 1);
      this.requireFinite(row.N, `pls.FIMIX_Segments[${i}].N`, 1);
      this.requireFinite(row.Proporcion, `pls.FIMIX_Segments[${i}].Proporcion`, 0, 1);
      this.requireFinite(row.K_seleccionado, `pls.FIMIX_Segments[${i}].K_seleccionado`, 2, 8);
    });
    optionalTable('FIMIX_Paths').forEach((row: any, i: number) => {
      this.requireFinite(row.Segmento, `pls.FIMIX_Paths[${i}].Segmento`, 1);
      this.requireFinite(row.Beta, `pls.FIMIX_Paths[${i}].Beta`);
      if (typeof row.Ruta !== 'string' || row.Ruta.trim().length === 0) {
        throw new Error(`Contrato PLS inválido: FIMIX_Paths[${i}].Ruta ausente.`);
      }
    });
    optionalTable('FIMIX_Assignments').forEach((row: any, i: number) => {
      this.requireFinite(row.Fila_analitica, `pls.FIMIX_Assignments[${i}].Fila_analitica`, 1);
      this.requireFinite(row.Segmento, `pls.FIMIX_Assignments[${i}].Segmento`, 1);
      if (row.Probabilidad_posterior_max !== null && row.Probabilidad_posterior_max !== undefined) {
        this.requireFinite(row.Probabilidad_posterior_max, `pls.FIMIX_Assignments[${i}].Probabilidad_posterior_max`, 0, 1);
      }
    });
    optionalTable('ModelComparison').forEach((row: any, i: number) => {
      if (typeof row.Modelo !== 'string' || row.Modelo.trim().length === 0) {
        throw new Error(`Contrato PLS inválido: ModelComparison[${i}].Modelo ausente.`);
      }
      if (row.R2_promedio !== null && row.R2_promedio !== undefined) this.requireFinite(row.R2_promedio, `pls.ModelComparison[${i}].R2_promedio`, 0, 1);
      if (row.R2_ajustado_promedio !== null && row.R2_ajustado_promedio !== undefined) this.requireFinite(row.R2_ajustado_promedio, `pls.ModelComparison[${i}].R2_ajustado_promedio`, -100, 1);
      if (row.Q2_promedio !== null && row.Q2_promedio !== undefined) this.requireFinite(row.Q2_promedio, `pls.ModelComparison[${i}].Q2_promedio`, -1000, 1);
      if (row.SRMR_saturado !== null && row.SRMR_saturado !== undefined) this.requireFinite(row.SRMR_saturado, `pls.ModelComparison[${i}].SRMR_saturado`, 0, 2);
      if (row.SRMR_estimado !== null && row.SRMR_estimado !== undefined) this.requireFinite(row.SRMR_estimado, `pls.ModelComparison[${i}].SRMR_estimado`, 0, 2);
    });
    if (result.advanced_modules !== null && result.advanced_modules !== undefined) {
      if (typeof result.advanced_modules !== 'object' || Array.isArray(result.advanced_modules)) {
        throw new Error('Contrato PLS inválido: advanced_modules debe ser un objeto de estados.');
      }
      for (const [moduleName, status] of Object.entries(result.advanced_modules)) {
        if (typeof status !== 'string' || !/^(implemented|not_applicable|disabled_by_configuration|failed_closed)/.test(status)) {
          throw new Error(`Contrato PLS inválido: estado desconocido para ${moduleName}.`);
        }
      }
    }
    this.assertProbabilityFields(result, 'pls');
  }

  private validateMethodContract(category: string, result: any): void {
    this.assertAllNumbersFinite(result, category);
    this.assertNoNestedFailure(result, category);
    this.assertProbabilityFields(result, category);
    const payloadKey: Record<string, string> = {
      correlacional: 'correlations', comparacion: 'ttest', anova: 'anova', regresion: 'regression',
      logistica: 'logistic', regresion_ordinal: 'ordinal_regression', regresion_jerarquica: 'hierarchical_regression',
      ancova: 'ancova', discriminante: 'discriminant', descriptivo: 'analisis_descriptivo', frecuencias: 'frequencies',
      cluster: 'cluster', cronbach: 'cronbach_only', baremos: 'baremos_only', descriptivos: 'descriptives_full',
      instrumentos: 'instruments', mediacion: 'mediation', chi_cuadrado: 'chi_square',
    };
    const key = payloadKey[category];
    const payload = key ? result[key] : undefined;
    if (key && (payload === null || payload === undefined || (Array.isArray(payload) && payload.length === 0))) {
      throw new Error(`Contrato numérico inválido: falta el payload ${key}.`);
    }

    if (category === 'correlacional') {
      if (!Array.isArray(payload)) throw new Error('Contrato de correlación inválido: se esperaba una tabla.');
      payload.forEach((row: any, i: number) => {
        this.requireFinite(row.n, `correlations[${i}].n`, 3);
        this.requireFinite(row.r, `correlations[${i}].r`, -1, 1);
        this.requireProbability(row.p, `correlations[${i}].p`);
        const lo = this.requireFinite(row.ci_lower, `correlations[${i}].ci_lower`, -1, 1);
        const hi = this.requireFinite(row.ci_upper, `correlations[${i}].ci_upper`, -1, 1);
        if (lo > hi || row.r < lo || row.r > hi) throw new Error(`IC de correlación inconsistente en fila ${i + 1}.`);
      });
    } else if (category === 'comparacion') {
      this.requireProbability(payload.p, 'ttest.p');
      const statistic = payload.t ?? payload.U ?? payload.W;
      this.requireFinite(statistic, 'ttest.statistic');
    } else if (category === 'anova') {
      this.requireProbability(payload.p, 'anova.p');
      this.requireFinite(payload.F ?? payload.H, 'anova.statistic', 0);
    } else if (category === 'regresion') {
      this.requireProbability(payload.p, 'regression.p');
      this.requireFinite(payload.R2_raw ?? payload.R2, 'regression.R2', 0, 1);
      if (!Array.isArray(payload.coefficients) || payload.coefficients.length < 1) {
        throw new Error('Contrato de regresión inválido: faltan coeficientes.');
      }
    } else if (category === 'logistica') {
      this.requireProbability(payload.p_lr, 'logistic.p_lr');
      this.requireFinite(payload.events, 'logistic.events', 1);
      this.requireFinite(payload.non_events, 'logistic.non_events', 1);
      if (payload.roc?.auc !== null && payload.roc?.auc !== undefined) {
        this.requireFinite(payload.roc.auc, 'logistic.roc.auc', 0, 1);
      }
    } else if (category === 'regresion_ordinal') {
      this.requireProbability(payload.lr_p, 'ordinal.lr_p');
      this.requireFinite(payload.nagelkerke_r2, 'ordinal.nagelkerke_r2', 0, 1);
    } else if (category === 'chi_cuadrado') {
      this.requireProbability(payload.p, 'chi_square.p');
      this.requireFinite(payload.chi2, 'chi_square.chi2', 0);
      this.requireFinite(payload.selected_effect?.value, 'chi_square.selected_effect.value', 0, 1);
    } else if (category === 'mediacion') {
      this.requireFinite(payload.indirect, 'mediation.indirect');
      const lo = this.requireFinite(payload.ci_lower, 'mediation.ci_lower');
      const hi = this.requireFinite(payload.ci_upper, 'mediation.ci_upper');
      if (lo > hi) throw new Error('Contrato de mediación inválido: IC invertido.');
      this.requireFinite(payload.n_boot_valid, 'mediation.n_boot_valid', 800);
      if (payload.total_effect_identity_ok !== true) {
        throw new Error('Contrato de mediación inválido: c != c′ + ab dentro de tolerancia.');
      }
    }
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
        if (rResult.blocked === true || rResult.success !== true) {
          throw new Error(rResult.error ?? 'PLS-SEM no produjo un resultado válido.');
        }
        this.validatePlsContract(rResult);
        const safePls = rejectNonFinite(rResult);
        if (!safePls.tables || !Array.isArray(safePls.tables.Paths) || safePls.tables.Paths.length === 0) {
          throw new Error('PLS-SEM no devolvió la tabla obligatoria de rutas.');
        }
        await this.prisma.analysisResult.create({
          data: {
            jobId,
            method: 'pls_sem',
            diagnostic: safePls.tables ?? {},
            descriptives: [],
            reliability: safePls.tables?.Confiabilidad ?? [],
            normality: [],
            correlations: safePls.tables?.Paths ?? [],
            interpretations: { pls: safePls },
            warnings: [],
            wordPath: safePls.word_path ?? null,
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

      const categoryToPayload: Record<string, string | null> = {
        correlacional: 'correlations', comparacion: 'ttest', anova: 'anova', regresion: 'regression',
        logistica: 'logistic', regresion_ordinal: 'ordinal_regression', regresion_jerarquica: 'hierarchical_regression',
        ancova: 'ancova', discriminante: 'discriminant', descriptivo: 'analisis_descriptivo', frecuencias: 'frequencies',
        cluster: 'cluster', cronbach: 'cronbach_only', baremos: 'baremos_only', descriptivos: 'descriptives_full',
        instrumentos: 'instruments', mediacion: 'mediation', chi_cuadrado: 'chi_square'
      };
      const requiredPayload = categoryToPayload[config.analysis_category ?? 'correlacional'];
      if (requiredPayload) {
        const payload = rResult[requiredPayload];
        const missing = payload == null || (Array.isArray(payload) && payload.length === 0);
        if (missing) throw new Error(`Motor R no devolvió el payload obligatorio: ${requiredPayload}`);
      }
      this.validateMethodContract(config.analysis_category ?? 'correlacional', rResult);

      // Sanitizar valores no-finitos antes de persistir
      const safeResult = rejectNonFinite(rResult);

      // Guardar resultados en BD
      await this.prisma.analysisResult.create({
        data: {
          jobId,
          method:         safeResult.method ?? config.analysis_category ?? 'unknown',
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
  // ── Filtra el archivo para conservar indicadores PLS-SEM y la variable de grupo ──
  // Los indicadores se validan como numéricos en R; la variable de grupo puede conservarse como texto.
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
      for (const ctrl of (config.control_variables ?? [])) {
        if (ctrl?.column) neededCols.add(ctrl.column);
      }

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
        bootstrap_seed:    config.bootstrap_seed ?? config.seed ?? 20260704,
        advanced_seed:     config.advanced_seed ?? config.bootstrap_seed ?? config.seed ?? 20260704,
        advanced_pls:      config.advanced_pls ?? true,
        calc_srmr:         config.calc_srmr ?? true,
        calc_q2:           config.calc_q2 ?? true,
        q2_omission_distance: config.q2_omission_distance ?? 7,
        calc_pls_predict:  config.calc_pls_predict ?? true,
        pls_predict_folds: config.pls_predict_folds ?? 10,
        pls_predict_reps:  config.pls_predict_reps ?? 10,
        calc_htmt_ci:      config.calc_htmt_ci ?? true,
        calc_full_vif:     config.calc_full_vif ?? true,
        full_vif_threshold: config.full_vif_threshold ?? 3.3,
        calc_vaf:          config.calc_vaf ?? true,
        calc_ipma:         config.calc_ipma ?? true,
        calc_gaussian_copula: config.calc_gaussian_copula ?? false,
        copula_boot:       config.copula_boot ?? 5000,
        calc_micom:        config.calc_micom ?? true,
        calc_mga:          config.calc_mga ?? true,
        n_permut:          config.n_permut ?? 5000,
        control_variables: config.control_variables ?? [],
        calc_fimix:        config.calc_fimix ?? false,
        fimix_k_min:       config.fimix_k_min ?? 2,
        fimix_k_max:       config.fimix_k_max ?? 4,
        fimix_nstart:      config.fimix_nstart ?? 10,
        fimix_max_iter:    config.fimix_max_iter ?? 5000,
        fimix_stop_criterion: config.fimix_stop_criterion ?? 0.000001,
        use_fimix_for_mga: config.use_fimix_for_mga ?? true,
        compare_models:    config.compare_models ?? false,
        comparison_roles:  config.comparison_roles ?? {},
        study_title:       config.study_title ?? 'Modelo PLS-SEM',
        language:          'es',
        group_var:         config.group_var ?? null,
        scale_min:         config.scale_min ?? config.scale?.min ?? 1,
        scale_max:         config.scale_max ?? config.scale?.max ?? 5,
        ipma_target:       config.ipma_target ?? null,
      };
      const tmpFile = path.join(os.tmpdir(), `pls_${Date.now()}.json`);
      fs.writeFileSync(tmpFile, JSON.stringify(plsParams), 'utf8');
      const rBin = this.config.get('R_BIN') || '/usr/bin/Rscript';
      const proc = require('child_process').spawn(rBin, [plsScriptPath, tmpFile], {
        timeout: 7200000, // 120 min: MICOM/MGA confirmatorios reestiman el modelo en cada permutación
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
