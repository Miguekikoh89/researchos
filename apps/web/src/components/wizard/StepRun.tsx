'use client';

// ============================================================================
// ResearchOS — Wizard Step 3: Ejecutar análisis (polling del job)
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
  const [status, setStatus] = useState<JobStatus>('idle');
  const [error, setError]   = useState('');
  const [steps, setSteps]   = useState<{ label: string; done: boolean }[]>([
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
  ]);

  const cfg = state.config;

  const buildApiConfig = () => ({
    datasetId: state.datasetId!,
    config: {
      sheet:              1,
      has_header:         true,
      imputation:         'media',
      var_a: {
        name:       cfg.varAName,
        items:      cfg.varAItems,
        dimensions: cfg.varADimensions,
      },
      var_b: {
        name:       cfg.varBName,
        items:      cfg.varBItems,
        dimensions: cfg.varBDimensions,
      },
      scale:              cfg.scale,
      baremo_method:      cfg.baremoMethod,
      baremo_levels:      cfg.baremoLevels,
      normality_tests:    cfg.normalityTests,
      method_force:       cfg.methodForce,
      analysis_types:      cfg.analysisTypes,
      analysis_category:   cfg.analysisCategory,
      comparison_type:     cfg.comparisonType,
      group_var:           cfg.groupVar,
      group_values:        cfg.groupValues,
      alpha:              cfg.alpha,
      participants:       cfg.participants,
      study_title:        cfg.studyTitle,
      objective:          cfg.objective,
      include_reliability: cfg.includeReliability,
      export_word:        cfg.exportWord,
      table_start:        1,
    },
  });

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
    const maxAttempts = 60; // 2 minutos (poll cada 2 seg)

    const interval = setInterval(async () => {
      attempts++;
      if (attempts > maxAttempts) {
        clearInterval(interval);
        setStatus('FAILED');
        setError('El análisis tardó demasiado. Intenta de nuevo.');
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
