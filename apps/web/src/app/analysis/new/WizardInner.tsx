'use client';
import { useState, useEffect } from 'react';
import CanchariLogo from '@/components/branding/CanchariLogo';

import { Upload, Settings, Play, BarChart2, Download, CheckCircle, FlaskConical, Zap } from 'lucide-react';
import StepUpload    from '@/components/wizard/StepUpload';
import StepConfigure from '@/components/wizard/StepConfigure';
import StepRun       from '@/components/wizard/StepRun';
import StepResults   from '@/components/wizard/StepResults';
import StepExport    from '@/components/wizard/StepExport';
import type { WizardState, AnalysisFormConfig } from './page';

const STEPS = [
  { id: 0, label: 'Método',        icon: Zap,         desc: 'Elige tu análisis' },
  { id: 1, label: 'Subir datos',   icon: Upload,      desc: 'Carga tu Excel o CSV' },
  { id: 2, label: 'Configurar',    icon: Settings,    desc: 'Define variables' },
  { id: 3, label: 'Analizar',      icon: Play,        desc: 'Motor estadístico R' },
  { id: 4, label: 'Resultados',    icon: BarChart2,   desc: 'Tablas APA 7' },
  { id: 5, label: 'Exportar',      icon: Download,    desc: 'Word listo para tu tesis' },
];

const METHODS = [
  { id:'structural_model', label:'PLS-SEM',          desc:'Modelos de ecuaciones estructurales',     icon:'🔷', badge:'⭐ Más avanzado',  from:'#06b6d4', to:'#2563eb' },
  { id:'correlacional',    label:'Correlacional',     desc:'Relación entre variables continuas',      icon:'📈', badge:'🎓 Pregrado',      from:'#6366f1', to:'#a855f7' },
  { id:'regresion',        label:'Regresión lineal',  desc:'Predicción de variable continua',         icon:'📉', badge:'📊 Muy usado',     from:'#10b981', to:'#059669' },
  { id:'comparacion',      label:'Comparación',       desc:'Diferencias entre 2 grupos independientes',icon:'⚖️', badge:'🎓 Pregrado',   from:'#8b5cf6', to:'#ec4899' },
  { id:'anova',            label:'ANOVA',             desc:'Comparar 3 o más grupos',                icon:'📊', badge:'📊 Muy usado',     from:'#f59e0b', to:'#ef4444' },
  { id:'logistica',        label:'Reg. logística',    desc:'Predicción de variable categórica',       icon:'🎯', badge:'🔬 Avanzado',     from:'#ec4899', to:'#f43f5e' },
  { id:'chi_cuadrado',     label:'Chi-cuadrado',      desc:'Asociación entre variables categóricas',  icon:'📋', badge:'🎓 Pregrado',     from:'#f97316', to:'#dc2626' },
  { id:'instrumentos',     label:'Validar instrumento',desc:'AFE · AFC · Alpha · CR · AVE · HTMT',   icon:'🔬', badge:'🧪 Prueba piloto', from:'#14b8a6', to:'#0891b2' },
];

const DEFAULT_CONFIG: AnalysisFormConfig = {
  studyTitle: '', participants: 'los participantes', objective: '',
  varAName: '', varAItems: [], varADimensions: [],
  varBName: '', varBItems: [], varBDimensions: [],
  scale: { min: 1, max: 5 },
  baremoMethod: 'percentil', baremoLevels: ['Bajo', 'Medio', 'Alto'],
  normalityTests: ['sw', 'ks'],
  methodForce: 'auto', analysisTypes: ['vv'],
  alpha: 0.05,
  includeReliability: true, exportWord: true,
  analysisCategory: 'correlacional',
  comparisonType: 'auto',
  groupVar: '', groupValues: ['', ''] as [string, string],
  comparisonVarA: true, comparisonVarB: false,
  logisticType: 'binaria' as const, nBoot: 5000, scaleMin: 1, scaleMax: 5,
};

export default function WizardInner({ projectId, initialState, methodFromUrl }: { projectId?: string | null; initialState?: WizardState | null; methodFromUrl?: string | null }) {
  const methodParam = methodFromUrl ?? null;
  const [step, setStep] = useState(methodParam ? 1 : 0);
  const [state, setState] = useState<WizardState>(() => {
    // Lazy init: se ejecuta una sola vez, de forma segura para SSR/hidratacion
    let storedConfig: any = null;
    if (typeof window !== 'undefined') {
      try {
        const raw = window.localStorage.getItem('ros_analysis_config');
        if (raw) storedConfig = JSON.parse(raw);
      } catch (e) { storedConfig = null; }
    }
    const preConfig = storedConfig ?? (initialState as any)?.preConfig;
    const initState = preConfig ? {
      projectId: projectId ?? null, datasetId: null, columns: [],
      jobId: null, results: null, config: { ...DEFAULT_CONFIG, ...preConfig }
    } : (initialState ?? {
      projectId: projectId ?? null, datasetId: null, columns: [],
      jobId: null, results: null, config: DEFAULT_CONFIG
    });
    return {
      ...initState,
      projectId: projectId ?? initState.projectId,
      config: {
        ...(initState.config ?? DEFAULT_CONFIG),
        ...(methodParam ? { analysisCategory: methodParam as any } : {}),
      }
    };
  });
  useEffect(() => {
    try { window.localStorage.removeItem('ros_analysis_config'); } catch (e) {}
  }, []);

  useEffect(() => {
    if (projectId) setState(prev => ({ ...prev, projectId }));
  }, [projectId]);

  useEffect(() => {
    if (methodParam) {
      setState(prev => ({
        ...prev,
        config: { ...prev.config, analysisCategory: methodParam as any }
      }));
    }
  }, [methodParam]);

  const updateState = (patch: Partial<WizardState>) =>
    setState(prev => ({ ...prev, ...patch }));

  const updateConfig = (patch: Partial<AnalysisFormConfig>) =>
    setState(prev => ({ ...prev, config: { ...prev.config, ...patch } }));

  return (
    <div className={step === 0 ? "min-h-screen bg-slate-950" : "min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-50"}>
      {/* Header */}
      <div className={step === 0 ? "bg-slate-900/80 backdrop-blur-sm border-b border-slate-700 sticky top-0 z-50" : "bg-white/80 backdrop-blur-sm border-b border-slate-200 sticky top-0 z-50"}>
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between mb-5">
            <a href="/dashboard" className="flex items-center gap-3 hover:opacity-80 transition">
              <CanchariLogo width={130} showBackground={false} />
            </a>
            <div className="text-right">
              <p className={`text-xs ${step===0?'text-slate-500':'text-slate-400'}`}>Paso {step + 1} de {STEPS.length}</p>
              <p className={`text-sm font-semibold ${step===0?'text-slate-200':'text-slate-700'}`}>{STEPS[step].label}</p>
            </div>
          </div>

          {/* Stepper */}
          <div className="flex items-center">
            {STEPS.map((s, i) => (
              <div key={s.id} className="flex items-center flex-1 last:flex-none">
                <button
                  onClick={() => i < step && setStep(i)}
                  disabled={i > step}
                  className="flex flex-col items-center gap-1.5 group"
                >
                  <div className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all duration-300 ${
                    i < step  ? (step===0?'bg-cyan-600 shadow-lg shadow-cyan-900':'bg-indigo-600 shadow-lg shadow-indigo-200') :
                    i === step ? (step===0?'bg-cyan-500 shadow-lg shadow-cyan-900 ring-4 ring-cyan-900':'bg-indigo-600 shadow-lg shadow-indigo-200 ring-4 ring-indigo-100') :
                    (step===0?'bg-slate-800':'bg-slate-100')
                  }`}>
                    {i < step
                      ? <CheckCircle className="w-5 h-5 text-white" />
                      : <s.icon className={`w-5 h-5 ${i === step ? 'text-white' : 'text-slate-400'}`} />
                    }
                  </div>
                  <span className={`text-xs font-semibold hidden sm:block transition-colors ${
                    i <= step ? (step===0?'text-cyan-400':'text-indigo-700') : (step===0?'text-slate-600':'text-slate-400')
                  }`}>{s.label}</span>
                </button>
                {i < STEPS.length - 1 && (
                  <div className={`flex-1 h-0.5 mx-3 rounded-full transition-all duration-500 ${
                    i < step ? (step===0?'bg-cyan-600':'bg-indigo-500') : (step===0?'bg-slate-700':'bg-slate-200')
                  }`} />
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-6xl mx-auto px-6 py-10">
        <div className="animate-fade-in">
          {step === 1 && <StepUpload    state={state} onNext={() => setStep(2)} updateState={updateState} />}
          {step === 2 && <StepConfigure state={state} onNext={() => setStep(3)} onBack={() => setStep(1)} updateConfig={updateConfig} config={state.config ?? DEFAULT_CONFIG} hideMethodSelector={!!methodParam} />}
          {step === 3 && <StepRun       state={state} onNext={() => setStep(4)} onBack={() => setStep(2)} updateState={updateState} updateConfig={updateConfig} />}
          {step === 4 && <StepResults   state={state} onNext={() => setStep(5)} onBack={() => setStep(3)} />}
          {step === 5 && <StepExport    state={state} onBack={() => setStep(4)} onNext={() => {}} updateState={updateState} updateConfig={updateConfig} />}
        </div>
      </div>
    </div>
  );
}
