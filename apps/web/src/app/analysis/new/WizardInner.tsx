'use client';
import { useState, useEffect } from 'react';
import { Upload, Settings, Play, BarChart2, Download, CheckCircle, FlaskConical } from 'lucide-react';
import StepUpload    from '@/components/wizard/StepUpload';
import StepConfigure from '@/components/wizard/StepConfigure';
import StepRun       from '@/components/wizard/StepRun';
import StepResults   from '@/components/wizard/StepResults';
import StepExport    from '@/components/wizard/StepExport';
import type { WizardState, AnalysisFormConfig } from './page';

const STEPS = [
  { id: 0, label: 'Subir datos',   icon: Upload,      desc: 'Carga tu Excel o CSV' },
  { id: 1, label: 'Configurar',    icon: Settings,    desc: 'Define variables y método' },
  { id: 2, label: 'Analizar',      icon: Play,        desc: 'Motor estadístico R' },
  { id: 3, label: 'Resultados',    icon: BarChart2,   desc: 'Tablas APA 7' },
  { id: 4, label: 'Exportar',      icon: Download,    desc: 'Word listo para tu tesis' },
];

const DEFAULT_CONFIG: AnalysisFormConfig = {
  studyTitle: '', participants: 'los participantes', objective: '',
  varAName: 'Variable A', varAItems: [], varADimensions: [],
  varBName: 'Variable B', varBItems: [], varBDimensions: [],
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
  logisticType: 'binaria' as const,
};

export default function WizardInner({ projectId, initialState }: { projectId?: string | null; initialState?: WizardState | null }) {
  const [step, setStep]   = useState(0);
  const initState = initialState ?? {
    projectId: projectId ?? null, datasetId: null, columns: [],
    jobId: null, results: null, config: DEFAULT_CONFIG
  };
  const [state, setState] = useState<WizardState>({...initState, projectId: projectId ?? initState.projectId});

  useEffect(() => {
    if (projectId) setState(prev => ({ ...prev, projectId }));
  }, [projectId]);

  const updateState = (patch: Partial<WizardState>) =>
    setState(prev => ({ ...prev, ...patch }));

  const updateConfig = (patch: Partial<AnalysisFormConfig>) =>
    setState(prev => ({ ...prev, config: { ...prev.config, ...patch } }));

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-50">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-sm border-b border-slate-200 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between mb-5">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-200">
                <FlaskConical className="w-5 h-5 text-white" />
              </div>
              <div>
                <p className="text-xs font-semibold text-indigo-600 uppercase tracking-widest">ResearchOS</p>
                <p className="text-sm text-slate-500 leading-none mt-0.5">Motor estadístico · APA 7</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-xs text-slate-400">Paso {step + 1} de {STEPS.length}</p>
              <p className="text-sm font-semibold text-slate-700">{STEPS[step].label}</p>
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
                    i < step  ? 'bg-indigo-600 shadow-lg shadow-indigo-200' :
                    i === step ? 'bg-indigo-600 shadow-lg shadow-indigo-200 ring-4 ring-indigo-100' :
                    'bg-slate-100'
                  }`}>
                    {i < step
                      ? <CheckCircle className="w-5 h-5 text-white" />
                      : <s.icon className={`w-5 h-5 ${i === step ? 'text-white' : 'text-slate-400'}`} />
                    }
                  </div>
                  <span className={`text-xs font-semibold hidden sm:block transition-colors ${
                    i <= step ? 'text-indigo-700' : 'text-slate-400'
                  }`}>{s.label}</span>
                </button>
                {i < STEPS.length - 1 && (
                  <div className={`flex-1 h-0.5 mx-3 rounded-full transition-all duration-500 ${
                    i < step ? 'bg-indigo-500' : 'bg-slate-200'
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
          {step === 0 && <StepUpload    state={state} onNext={() => setStep(1)} updateState={updateState} />}
          {step === 1 && <StepConfigure state={state} onNext={() => setStep(2)} onBack={() => setStep(0)} updateConfig={updateConfig} config={state.config ?? DEFAULT_CONFIG} />}
          {step === 2 && <StepRun       state={state} onNext={() => setStep(3)} onBack={() => setStep(1)} updateState={updateState} updateConfig={updateConfig} />}
          {step === 3 && <StepResults   state={state} onNext={() => setStep(4)} onBack={() => setStep(2)} />}
          {step === 4 && <StepExport    state={state} onBack={() => setStep(3)} onNext={() => {}} updateState={updateState} updateConfig={updateConfig} />}
        </div>
      </div>
    </div>
  );
}
