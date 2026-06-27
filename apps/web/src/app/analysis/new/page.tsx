'use client';
import dynamic from 'next/dynamic';
import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';

const WizardInner = dynamic(() => import('./WizardInner'), { ssr: false });

function WizardPage() {
  const searchParams = useSearchParams();
  const [projectId, setProjectId] = useState<string|null>(null);
  const methodParam = searchParams.get('method');

  useEffect(() => {
    const pid = searchParams.get('projectId');
    if (pid) { setProjectId(pid); return; }
    const token = localStorage.getItem('ros_token');
    if (!token) { window.location.href = '/login'; return; }
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';
    fetch(`${apiUrl}/projects`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ name: `Analisis ${new Date().toLocaleDateString('es-PE')}`, description: '' })
    }).then(r => r.json()).then(d => { if(d.id) setProjectId(d.id); }).catch((err) => { console.error('Error creando proyecto:', err); });
  }, [searchParams]);

  return <WizardInner key={methodParam || 'default'} projectId={projectId} initialState={methodParam ? { preConfig: { analysisCategory: methodParam } } as any : null} methodFromUrl={methodParam || ''} />;
}

export default function AnalysisWizardPage() {
  return <Suspense fallback={<div className="min-h-screen bg-slate-950"/>}><WizardPage/></Suspense>;
}

export interface AnalysisFormConfig {
  studyTitle: string; participants: string; objective: string;
  varAName: string; varAItems: string[]; varADimensions: { name: string; items: string[] }[];
  varBName: string; varBItems: string[]; varBDimensions: { name: string; items: string[] }[];
  extraPredictors: { name: string; items: string[]; dimensions: { name: string; items: string[] }[] }[];
  scale: { min: number; max: number }; baremoMethod: string;
  baremoLevels: [string, string, string]; normalityTests: ('sw' | 'ks')[];
  methodForce: 'auto' | 'pearson' | 'spearman'; analysisTypes: ('vv' | 'vdA' | 'vdB' | 'dd')[]; analysisCategory: 'correlacional' | 'comparacion' | 'anova' | 'ancova' | 'regresion' | 'regresion_multiple' | 'regresion_ordinal' | 'regresion_jerarquica' | 'regresion_multinomial' | 'logistica' | 'chi_cuadrado' | 'instrumentos' | 'cronbach' | 'cluster' | 'discriminante' | 'descriptivo' | 'factorial' | 'structural_model';
  logisticType: 'binaria' | 'ordinal'; comparisonType: 'independiente' | 'pareada' | 'auto'; groupVar: string; groupValues: [string, string]; comparisonVarA: boolean; comparisonVarB: boolean;
  alpha: number; includeReliability: boolean; exportWord: boolean; nBoot: number; scaleMin: number; scaleMax: number;
}

export interface WizardState {
  projectId: string | null; datasetId: string | null; columns: string[];
  jobId: string | null; results: any | null; config: AnalysisFormConfig;
}
