'use client';

// ============================================================================
// CanchariOS — Wizard Step 3: Ejecutar análisis (polling del job)
// ============================================================================

import { useState, useEffect } from 'react';
import { FlaskConical, ChevronLeft, Loader2, CheckCircle2, XCircle, AlertTriangle } from 'lucide-react';
import type { WizardState, AnalysisFormConfig } from '@/app/analysis/new/page';

interface Props {
  state:        WizardState;
  updateState:  (patch: Partial<WizardState>) => void;
  updateConfig: (patch: Partial<AnalysisFormConfig>) => void;
  onNext:       () => void;
  onBack:       () => void;
}

type JobStatus = 'idle' | 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

const STATUS_CONFIG: Record<JobStatus, { label: string; color: string; icon: any }> = {
  idle:       { label: 'Listo para analizar', color: 'text-slate-600', icon: FlaskConical },
  PENDING:    { label: 'En cola…', color: 'text-amber-600', icon: Loader2 },
  PROCESSING: { label: 'Motor R procesando…', color: 'text-blue-600', icon: Loader2 },
  COMPLETED:  { label: '¡Análisis completado!', color: 'text-teal-600', icon: CheckCircle2 },
  FAILED:     { label: 'Error en el análisis', color: 'text-red-600', icon: XCircle },
};

export default function StepRun({ state, updateState, onNext, onBack }: Props) {
  const cfg = state.config;
  const isPls = cfg.analysisCategory === 'structural_model';
  const [status, setStatus] = useState<JobStatus>('idle');
  const [error, setError]   = useState('');
  const [steps, setSteps]   = useState<{ label: string; done: boolean }[]>(
    isPls ? [
      { label: 'Carga, limpieza y validación de datos', done: false },
      { label: 'Construcción del modelo de medida y controles', done: false },
      { label: 'Estimación PLS y bootstrapping', done: false },
      { label: 'Confiabilidad y validez del modelo de medición', done: false },
      { label: 'Efectos directos, indirectos y totales', done: false },
      { label: 'Q², PLS-Predict, SRMR, CMB e IPMA', done: false },
      { label: 'Endogeneidad, FIMIX, MICOM y MGA', done: false },
      { label: 'Comparación de modelos y reporte APA 7', done: false },
    ] : [
      { label: 'Limpieza automática de datos', done: false },
      { label: 'Cálculo de puntajes por variable', done: false },
      { label: 'Estadística descriptiva', done: false },
      { label: 'Alfa de Cronbach (confiabilidad)', done: false },
      { label: 'Baremos y niveles', done: false },
      { label: 'Prueba de normalidad (SW / KS)', done: false },
      { label: 'Selección del método (Pearson/Spearman)', done: false },
      { label: 'Cálculo de correlaciones', done: false },
      { label: 'Redacción académica APA 7', done: false },
      { label: 'Exportación Word', done: false },
    ]
  );

  const buildApiConfig = () => {
    const inferVariableName = (name: string, items: string[], fallback: string) => {
      const explicitName = name?.trim();
      if (explicitName) return explicitName;

      const prefixes = items
        .map(item => item.trim().replace(/[\d_]+$/, ''))
        .filter(Boolean);

      const uniquePrefixes = Array.from(new Set(prefixes));
      return uniquePrefixes.length === 1 ? uniquePrefixes[0] : fallback;
    };

    const varAName = inferVariableName(cfg.varAName, cfg.varAItems, 'Variable A');
    const varBName = inferVariableName(cfg.varBName, cfg.varBItems, 'Variable B');

    if (cfg.analysisCategory === 'structural_model') {
      const plsConstructsRaw = (cfg as any).plsConstructs ?? [
        { name: varAName, items: cfg.varAItems },
        { name: varBName, items: cfg.varBItems },
      ];
      // Separar HOC de constructos simples
      const hocSpecs: Record<string,string[]> = {};
      const plsConstructs = plsConstructsRaw.flatMap((con: any) => {
        if (con.isHOC && Array.isArray(con.dimensions) && con.dimensions.length >= 2) {
          hocSpecs[con.name] = con.dimensions.map((d: any) => d.name);
          // Enviar dimensiones (LOC) + el HOC como constructo placeholder de 1 item
          // El motor R Two-Stage lo reemplazará con scores de Stage 1
          const dims = con.dimensions.map((d: any) => ({ name: d.name, items: Array.isArray(d.items) ? d.items : [] }));
          return dims;
        }
        return [con];
      });
      const plsPaths = (cfg as any).plsPaths ?? [
        { from: varAName, to: varBName },
      ];
      return {
        datasetId: state.datasetId!,
        config: {
          analysis_category: 'structural_model',
          constructs: plsConstructs,
          structural_paths: plsPaths,
          hoc_specs: Object.keys(hocSpecs).length > 0 ? hocSpecs : undefined,
          n_boot:      (cfg as any).nBoot ?? 5000,
          bootstrap_seed: (cfg as any).advancedSeed ?? 20260704,
          advanced_seed: (cfg as any).advancedSeed ?? 20260704,
          advanced_pls: (cfg as any).advancedPls ?? true,
          calc_srmr: (cfg as any).calcSrmr ?? true,
          calc_q2: (cfg as any).calcQ2 ?? true,
          q2_omission_distance: (cfg as any).q2OmissionDistance ?? 7,
          calc_pls_predict: (cfg as any).calcPlsPredict ?? true,
          pls_predict_folds: (cfg as any).plsPredictFolds ?? 10,
          pls_predict_reps: (cfg as any).plsPredictReps ?? 10,
          calc_htmt_ci: (cfg as any).calcHtmtCi ?? true,
          calc_full_vif: (cfg as any).calcFullVif ?? true,
          full_vif_threshold: (cfg as any).fullVifThreshold ?? 3.3,
          calc_vaf: (cfg as any).calcVaf ?? true,
          calc_ipma: (cfg as any).calcIpma ?? true,
          ipma_target: (cfg as any).ipmaTarget || null,
          calc_gaussian_copula: (cfg as any).calcGaussianCopula ?? false,
          copula_boot: (cfg as any).copulaBoot ?? 5000,
          group_var: (cfg as any).groupVar || null,
          calc_micom: (cfg as any).calcMicom ?? true,
          calc_mga: (cfg as any).calcMga ?? true,
          n_permut: (cfg as any).nPermut ?? 5000,
          scale_min: (cfg as any).scaleMin ?? 1,
          scale_max: (cfg as any).scaleMax ?? 5,
          control_variables: (cfg as any).controlVariables ?? [],
          calc_fimix: (cfg as any).calcFimix ?? false,
          fimix_k_min: (cfg as any).fimixKMin ?? 2,
          fimix_k_max: (cfg as any).fimixKMax ?? 4,
          fimix_nstart: (cfg as any).fimixNStart ?? 10,
          fimix_max_iter: (cfg as any).fimixMaxIter ?? 5000,
          fimix_stop_criterion: (cfg as any).fimixStopCriterion ?? 0.000001,
          use_fimix_for_mga: (cfg as any).useFimixForMga ?? true,
          compare_models: (cfg as any).compareModels ?? false,
          comparison_roles: {
            x: (cfg as any).comparisonX || '',
            m1: (cfg as any).comparisonM1 || '',
            m2: (cfg as any).comparisonM2 || '',
            y: (cfg as any).comparisonY || '',
          },
          study_title: cfg.studyTitle,
        },
      };
    }
    return {
      datasetId: state.datasetId!,
      config: {
        sheet:              1,
        has_header:         true,
        imputation:         'none',
        var_a: {
          name:       varAName,
          items:      cfg.varAItems,
          dimensions: cfg.varADimensions,
        },
        var_b: {
          name:       varBName,
          items:      cfg.varBItems,
          dimensions: cfg.varBDimensions,
        },
        extra_predictors: cfg.extraPredictors,
        // Para regresion multiple/multinomial: lista de nombres de columnas
        // (Variable A + cada predictor adicional con nombre valido) que el
        // motor R usa como matriz de predictores. Para los demas metodos
        // de regresion/logistica (1 solo predictor), queda undefined y el
        // backend usa var_a por defecto (comportamiento sin cambios).
        regression_predictors: ((['regresion_multiple','regresion_multinomial','logistica'].includes(cfg.analysisCategory)) && cfg.extraPredictors.length > 0)
          ? [varAName, ...cfg.extraPredictors.map(p => p.name).filter(n => n && n.trim() !== '')]
          : undefined,
        scale:              cfg.scale,
        baremo_method:      cfg.baremoMethod || 'teorico',
        baremo_levels:      cfg.baremoLevels,
        normality_tests:    cfg.normalityTests,
        method_force:       cfg.methodForce,
        analysis_types:      cfg.analysisTypes,
        // El backend (run_analysis.R) solo reconoce 'regresion' y 'logistica';
        // multiple/multinomial son variantes visibles en el frontend que
        // reutilizan esa misma logica del motor (que ya soporta N predictores
        // via regression_predictors, y logistic_type='multinomial' via el
        // submodo existente). No requieren bloques nuevos en el motor R.
        analysis_category:   cfg.analysisCategory === 'regresion_multiple' ? 'regresion'
                              : cfg.analysisCategory === 'regresion_multinomial' ? 'logistica'
                              : cfg.analysisCategory,
        comparison_type:     cfg.comparisonType,
        group_var:           cfg.groupVar,
        scale_min:           (cfg as any).scale?.min ?? cfg.scaleMin ?? 1,
        scale_max:           (cfg as any).scale?.max ?? cfg.scaleMax ?? 5,
        group_values:        cfg.groupValues,
        alpha:              cfg.alpha,
        participants:       cfg.participants,
        study_title:        cfg.studyTitle,
        objective:          cfg.objective,
        hypothesis_h1:      (cfg as any).hypothesisH1 ?? '',
        include_reliability: cfg.includeReliability,
        export_word:        cfg.exportWord,
        table_start:        1,
        // Nuevos parámetros específicos por método
        regression_method:   (cfg as any).regressionMethod ?? 'enter',
        check_assumptions:   (cfg as any).checkAssumptions ?? 'yes',
        stepwise_criteria:   (cfg as any).stepwiseCriteria ?? 'p05',
        coef_ci:             (cfg as any).coefCI ?? 0.95,
        handle_outliers:     (cfg as any).handleOutliers ?? 'report',
        vif_threshold:       (cfg as any).vifThreshold ?? 5,
        hypothesis_type:     (cfg as any).hypothesisType ?? 'bilateral',
        confidence_level:    (cfg as any).confidenceLevel ?? 0.95,
        multiple_correction: (cfg as any).multipleCorrection ?? 'none',
        posthoc:             (cfg as any).posthoc ?? 'tukey',
        effect_size:         cfg.analysisCategory === 'anova' ? ((cfg as any).effectSize ?? 'eta2') : (cfg.analysisCategory === 'comparacion' ? ((cfg as any).effectSize ?? 'cohend') : ((cfg as any).effectSize ?? 'eta2')),
        levene_test:         (cfg as any).leveneTest ?? 'yes',
        link_function:       (cfg as any).linkFunction ?? 'logit',
        ordinalizacion:      (cfg as any).ordinalizacion ?? 'teorico',
        // F-024: ordered_levels para regresion_ordinal — usa orderedLevels del wizard.
        ordered_levels:      cfg.analysisCategory === 'regresion_ordinal'
                               ? (cfg.orderedLevels?.length > 0 ? cfg.orderedLevels : undefined)
                               : undefined,
        // F-023: event_level para logistica binaria — usa eventLevel del wizard.
        event_level:         (cfg.eventLevel && cfg.eventLevel.trim() !== '')
                               ? cfg.eventLevel.trim()
                               : undefined,
        mediator:            (cfg as any).mediator ?? undefined,
        pseudo_r2:           (cfg as any).pseudoR2 ?? 'nagelkerke',
        hier_method:         (cfg as any).hierMethod ?? 'enter',
        hier_blocks:         (cfg as any).hierBlocks ?? [],
        report_delta_r2:     (cfg as any).reportDeltaR2 ?? 'yes',
        logistic_type:       cfg.analysisCategory === 'regresion_multinomial' ? 'multinomial' : ((cfg as any).logisticType ?? 'binaria'),
        logistic_entry:      (cfg as any).logisticEntry ?? 'enter',
        cut_point:           (cfg as any).cutPoint ?? 0.5,
        hosmer_lemeshow:     (cfg as any).hosmerLemeshow ?? 'yes',
        roc_curve:           (cfg as any).rocCurve ?? 'yes',
        yates_correction:    (cfg as any).yatesCorrection ?? 'auto',
        chi_effect_size:     (cfg as any).chiEffectSize ?? 'cramer',
        min_expected:        (cfg as any).minExpected ?? 5,
        // Cuando el usuario elige 'likert', las variables se categorizaran internamente
        // por baremos teoricos -> se marcan como nominal para eximir del guard de continuidad
        measurement_level_a: cfg.analysisCategory === 'chi_cuadrado' && (cfg as any).chiVarType === 'likert' ? 'nominal' : undefined,
        measurement_level_b: cfg.analysisCategory === 'chi_cuadrado' && (cfg as any).chiVarType === 'likert' ? 'nominal' : undefined,
        homogeneity_slopes:  (cfg as any).homogeneitySlopes ?? 'yes',
        lda_method:          (cfg as any).ldaMethod ?? 'simultaneous',
        lda_cv:              (cfg as any).ldaCV ?? 'yes',
        n_clusters:          (cfg as any).nClusters ?? 3,
        standardize:         (cfg as any).standardize ?? 'yes',
        seed:                (cfg as any).seed ?? 42,
        min_rit:             (cfg as any).minRIT ?? 0.3,
        calc_omega:          (cfg as any).calcOmega ?? 'yes',
        bootstrap_ci:        (cfg as any).bootstrapCI ?? 'yes',
        alpha_model:         (cfg as any).alphaModel ?? 'standard',
        normality_test:      (cfg as any).normalityTest ?? 'sw',
        n_factors:           (cfg as any).nFactors ?? null,
        rotation:            (cfg as any).rotation ?? 'oblimin',
        estimator:           (cfg as any).estimator ?? 'MLR',
        enable_v_aiken:      (cfg as any).enableVAiken ? 'yes' : 'no',
        v_aiken_matrix:      (cfg as any).vAikenMatrix ?? {},
        v_aiken_judges:      (cfg as any).vAikenJudges ?? 5,
        v_aiken_scale_min:   (cfg as any).vAikenScaleMin ?? 1,
        v_aiken_scale_max:   (cfg as any).vAikenScaleMax ?? 4,
      },
    };
  };

  const startAnalysis = async () => {
    setStatus('PENDING');
    setError('');

    try {
      const projectId = state.projectId || 'default';
      const body = buildApiConfig();

      const res = await fetch(`/api/v1/projects/${projectId}/analysis`, {
        method:  'POST',
        headers: {
          'Content-Type':  'application/json',
          'Authorization': `Bearer ${localStorage.getItem('ros_token')}`,
        },
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'No se pudo iniciar el análisis.');
      }

      const { jobId } = await res.json();
      updateState({ jobId });
      pollJob(jobId, projectId);
    } catch (e: any) {
      setStatus('FAILED');
      setError(e.message);
    }
  };

  const pollJob = (jobId: string, projectId: string) => {
    let stepIdx = 0;
    let attempts = 0;
    const maxAttempts = 180; // 6 minutos (poll cada 2 seg)

    const interval = setInterval(async () => {
      attempts++;
      if (attempts > maxAttempts) {
        clearInterval(interval);
        setStatus('FAILED');
        setError('El análisis tardó demasiado. Para modelos grandes usa 1000 iteraciones bootstrap.');
        return;
      }

      try {
        const res = await fetch(`/api/v1/projects/${projectId}/analysis/${jobId}`, {
          headers: { Authorization: `Bearer ${localStorage.getItem('ros_token')}` },
        });
        const data = await res.json();

        // Animar pasos
        if (data.status === 'PROCESSING' && stepIdx < steps.length - 1) {
          setSteps((prev) =>
            prev.map((s, i) => ({ ...s, done: i < stepIdx + 1 })),
          );
          stepIdx++;
        }

        setStatus(data.status as JobStatus);

        if (data.status === 'COMPLETED') {
          clearInterval(interval);
          setSteps((prev) => prev.map((s) => ({ ...s, done: true })));
          // Cargar resultado
          const resultRes = await fetch(
            `/api/v1/projects/${projectId}/analysis/${jobId}/result`,
            { headers: { Authorization: `Bearer ${localStorage.getItem('ros_token')}` } },
          );
          const result = await resultRes.json();
          updateState({ results: result });
        }

        if (data.status === 'FAILED') {
          clearInterval(interval);
          setError(data.errorMsg || 'Error desconocido en el motor R.');
        }
      } catch {
        // Silenciar errores de red en polling
      }
    }, 2000);
  };

  const statusCfg = STATUS_CONFIG[status];
  const Icon = statusCfg.icon;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-800">Ejecutar análisis</h2>
        <p className="text-slate-500 mt-1">El motor R procesará tu base de datos y generará todos los resultados.</p>
      </div>

      {/* Resumen de configuración */}
      <div className="bg-slate-50 rounded-xl border border-slate-200 p-5 grid grid-cols-2 gap-4 text-sm">
        {isPls ? (
          <>
            <div className="col-span-2">
              <p className="font-semibold text-slate-700 mb-2">🔷 Modelo PLS-SEM</p>
              {((cfg as any).plsConstructs ?? []).map((con: any, i: number) => (
                <div key={i} className="flex items-center gap-2 text-slate-600">
                  <span className="w-5 h-5 rounded bg-cyan-500 text-white text-xs flex items-center justify-center font-bold">{i+1}</span>
                  <span className="font-medium text-cyan-700">{con.name}</span>
                  <span className="text-slate-400">— {(con.items ?? []).length} ítems</span>
                </div>
              ))}
            </div>
            <div>
              <p className="font-semibold text-slate-700">Rutas</p>
              {((cfg as any).plsPaths ?? []).map((p: any, i: number) => (
                <p key={i} className="text-slate-600">{p.from} → {p.to}</p>
              ))}
            </div>
            <div>
              <p className="font-semibold text-slate-700">Bootstrap</p>
              <p className="text-slate-600">{(cfg as any).nBoot ?? 5000} iteraciones</p>
            </div>
          </>
        ) : (
          <>
            <div>
              <p className="font-semibold text-slate-700">Variable A</p>
              <p className="text-blue-700 font-medium">{cfg.varAName}</p>
              <p className="text-slate-500">{cfg.varAItems.length} ítems</p>
              {cfg.varADimensions.length > 0 && (
                <p className="text-slate-400 text-xs">{cfg.varADimensions.length} dimensiones</p>
              )}
            </div>
            <div>
              <p className="font-semibold text-slate-700">Variable B</p>
              <p className="text-teal-700 font-medium">{cfg.varBName}</p>
              <p className="text-slate-500">{cfg.varBItems.length} ítems</p>
              {cfg.varBDimensions.length > 0 && (
                <p className="text-slate-400 text-xs">{cfg.varBDimensions.length} dimensiones</p>
              )}
            </div>
            {cfg.extraPredictors && cfg.extraPredictors.length > 0 && cfg.extraPredictors.map((p, i) => (
              <div key={i}>
                <p className="font-semibold text-slate-700">Predictor X{i+2}</p>
                <p className="text-purple-700 font-medium">{p.name}</p>
                <p className="text-slate-500">{p.items?.length ?? 0} ítems</p>
              </div>
            ))}
            <div>
              <p className="font-semibold text-slate-700">Método</p>
              <p className="text-slate-600">
                {cfg.methodForce === 'auto' ? 'Automático (según normalidad)' :
                 cfg.methodForce === 'pearson' ? 'Pearson (r) — Forzado' : 'Spearman (ρ) — Forzado'}
              </p>
            </div>
            <div>
              <p className="font-semibold text-slate-700">Exportación</p>
              <p className="text-slate-600">{cfg.exportWord ? '✅ Word APA 7' : '—'}</p>
            </div>
          </>
        )}
      </div>

      {/* Status y progreso */}
      {status !== 'idle' && (
        <div className="space-y-3">
          <div className={`flex items-center gap-3 font-semibold ${statusCfg.color}`}>
            <Icon className={`w-5 h-5 ${status === 'PROCESSING' || status === 'PENDING' ? 'animate-spin' : ''}`} />
            {statusCfg.label}
          </div>

          <div className="space-y-2">
            {steps.map((step, i) => (
              <div key={i} className="flex items-center gap-3">
                <div className={`w-4 h-4 rounded-full border-2 flex-shrink-0 flex items-center justify-center transition-all ${
                  step.done
                    ? 'bg-teal-600 border-teal-600'
                    : status === 'PROCESSING' && i === steps.filter((s) => s.done).length
                    ? 'border-blue-600 border-dashed animate-pulse'
                    : 'border-slate-300'
                }`}>
                  {step.done && (
                    <svg className="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  )}
                </div>
                <span className={`text-sm ${step.done ? 'text-teal-700 font-medium' : 'text-slate-400'}`}>
                  {step.label}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="flex items-start gap-3 bg-red-50 border border-red-200 rounded-xl p-4">
          <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
          <p className="text-red-700 text-sm">{error}</p>
        </div>
      )}

      {/* Navegación */}
      <div className="flex justify-between">
        <button onClick={onBack} disabled={status === 'PROCESSING' || status === 'PENDING'}
          className="flex items-center gap-2 text-slate-600 hover:text-slate-800 font-medium px-5 py-2.5 rounded-xl border border-slate-300 hover:bg-slate-50 transition-all disabled:opacity-40">
          <ChevronLeft className="w-4 h-4" /> Atrás
        </button>

        {status === 'COMPLETED' ? (
          <button onClick={onNext}
            className="flex items-center gap-2 bg-teal-700 hover:bg-teal-800 text-white font-semibold px-7 py-3 rounded-xl transition-all">
            Ver resultados <CheckCircle2 className="w-4 h-4" />
          </button>
        ) : (
          <button
            onClick={startAnalysis}
            disabled={status === 'PROCESSING' || status === 'PENDING'}
            className="flex items-center gap-2 bg-blue-700 hover:bg-blue-800 disabled:opacity-60 disabled:cursor-not-allowed text-white font-semibold px-7 py-3 rounded-xl transition-all"
          >
            {status === 'PROCESSING' || status === 'PENDING'
              ? <><Loader2 className="w-4 h-4 animate-spin" /> Procesando…</>
              : <><FlaskConical className="w-4 h-4" /> Iniciar análisis</>
            }
          </button>
        )}
      </div>
    </div>
  );
}
