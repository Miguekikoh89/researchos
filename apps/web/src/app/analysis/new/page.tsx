'use client';
import dynamic from 'next/dynamic';
import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';

const WizardInner = dynamic(() => import('./WizardInner'), { ssr: false });

function WizardPage() {
  const searchParams = useSearchParams();
  const [projectId, setProjectId] = useState<string|null>(null);

  useEffect(() => {
    const pid = searchParams.get('projectId');
    if (pid) { setProjectId(pid); return; }
    const token = localStorage.getItem('ros_token');
    if (!token) { window.location.href = '/login'; return; }
    fetch('/api/v1/projects', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: `Analisis ${new Date().toLocaleDateString('es-PE')}`, description: '' })
    }).then(r => r.json()).then(d => { if(d.id) setProjectId(d.id); }).catch(()=>{});
  }, [searchParams]);

  return <WizardInner projectId={projectId} initialState={null} />;
}

export default function AnalysisWizardPage() {
  return <Suspense fallback={<div className="min-h-screen bg-slate-950"/>}><WizardPage/></Suspense>;
}

export interface AnalysisFormConfig {
  studyTitle: string; participants: string; objective: string;
  varAName: string; varAItems: string[]; varADimensions: { name: string; items: string[] }[];
  varBName: string; varBItems: string[]; varBDimensions: { name: string; items: string[] }[];
  scale: { min: number; max: number }; baremoMethod: string;
  baremoLevels: [string, string, string]; normalityTests: ('sw' | 'ks')[];
  methodForce: 'auto' | 'pearson' | 'spearman'; analysisTypes: ('vv' | 'vdA' | 'vdB' | 'dd')[]; analysisCategory: 'correlacional' | 'comparacion' | 'anova' | 'regresion' | 'logistica' | 'chi_cuadrado' | 'instrumentos' | 'factorial';
  logisticType: 'binaria' | 'ordinal'; comparisonType: 'independiente' | 'pareada' | 'auto'; groupVar: string; groupValues: [string, string]; comparisonVarA: boolean; comparisonVarB: boolean;
  alpha: number; includeReliability: boolean; exportWord: boolean;
}

export interface WizardState {
  projectId: string | null; datasetId: string | null; columns: string[];
  jobId: string | null; results: any | null; config: AnalysisFormConfig;
}
