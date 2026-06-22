'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronRight, Sparkles, CheckCircle2, AlertTriangle, ArrowRight } from 'lucide-react';
import { recommendMethod, methodRoutes, type MethodRecommendation, type ScaleResultado, type ScaleExplicativa, type CovariateType } from '@/lib/methodRecommendation';

function scaleToCode(scale: string, groups: number): ScaleResultado {
  const s = (scale || '').toLowerCase();
  if (s.includes('nomin')) return groups >= 3 ? 'nominal_3mas' : 'nominal_2';
  if (s.includes('ordinal')) return 'ordinal';
  return 'continua';
}
function buildRecommendation(d: any): MethodRecommendation | null {
  const vars = d.variables || [];
  const obj = d.objective || {};
  const varA = vars.find((v: any) => v.id === obj.varA);
  const varB = vars.find((v: any) => v.id === obj.varB);
  const varCov = vars.find((v: any) => v.id === obj.varC);
  if (!varA || !varB) return null;
  const resultado = scaleToCode(varB.scale, varB.groups || 0);
  const explicativa = scaleToCode(varA.scale, varA.groups || 0) as ScaleExplicativa;
  const covariate: CovariateType = !varCov ? 'no' : (varCov.scale || '').toLowerCase().includes('nomin') ? 'categorica' : 'continua';
  const hasDims = (varA.dimensions?.length||0) > 0 || (varB.dimensions?.length||0) > 0;
  return recommendMethod({ resultado, explicativa, covariate, purpose: obj.action, hasDims });
}

const CONFIDENCE_LABEL: Record<string, { text: string; color: string }> = {
  alta: { text: 'Confianza alta', color: 'bg-green-100 text-green-700 border-green-200' },
  media: { text: 'Confianza media', color: 'bg-amber-100 text-amber-700 border-amber-200' },
  baja: { text: 'Confianza baja', color: 'bg-red-100 text-red-700 border-red-200' },
};

export default function RecommendationPage() {
  const router = useRouter();
  const [data, setData] = useState<any>(null);
  const [rec, setRec] = useState<MethodRecommendation | null>(null);

  useEffect(() => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    setData(d);
    setRec(buildRecommendation(d));
  }, []);

  const goToAnalysis = () => {
    if (!data || !rec) return;
    const vars = data.variables || [];
    const obj = data.objective || {};
    const varA = vars.find((v: any) => v.id === obj.varA);
    const varB = vars.find((v: any) => v.id === obj.varB);

    const config = {
      analysisCategory: rec.methodSlug,
      varAName: varA?.name || '',
      varAItems: varA?.dimensions?.flatMap((d: any) => d.items || []) || [],
      varADimensions: varA?.dimensions?.map((d: any) => ({ name: d.name, items: d.items || [] })) || [],
      varBName: varB?.name || '',
      varBItems: varB?.dimensions?.flatMap((d: any) => d.items || []) || [],
      varBDimensions: varB?.dimensions?.map((d: any) => ({ name: d.name, items: d.items || [] })) || [],
      studyTitle: obj.text || '',
      objective: obj.text || '',
      hypothesisH1: data.hypothesis?.h1 || '',
      participants: data.methodology?.poblacion || 'los participantes',
      researchData: data,
    };
    localStorage.setItem('ros_analysis_config', JSON.stringify(config));
    const route = methodRoutes[rec.methodSlug] || '/analysis/new';
    router.push(`${route}${route.includes('?') ? '&' : '?'}from=research`);
  };

  if (!rec) return null;

  const conf = CONFIDENCE_LABEL[rec.confidence];

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center text-white font-black text-sm">OS</div>
          <p className="font-black text-slate-900">Asistente metodológico</p>
        </div>
        <div className="text-xs text-slate-400 font-medium">
          <span className="text-green-600 font-bold">✓ Variables → ✓ Objetivo → ✓ Hipótesis</span>
          <span className="mx-1">→</span>
          <span className="text-indigo-600 font-bold">Recomendación</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-10 space-y-6">
        <div className="text-center">
          <div className="inline-flex items-center gap-2 bg-indigo-50 border border-indigo-200 rounded-full px-4 py-1.5 text-sm text-indigo-700 font-semibold mb-4">
            <Sparkles className="w-4 h-4" />
            Análisis completado
          </div>
          <h1 className="text-2xl font-black text-slate-900">Tu método estadístico recomendado</h1>
          <p className="text-slate-500 mt-2">Basado en tu objetivo, hipótesis y el tipo de variables que registraste.</p>
        </div>

        {/* Main recommendation card */}
        <div className="bg-gradient-to-br from-indigo-600 to-purple-700 rounded-3xl p-7 text-white shadow-xl">
          <div className="flex items-center justify-between mb-3">
            <span className="text-indigo-200 text-xs font-bold uppercase tracking-wider">Análisis principal</span>
            <span className={`text-xs font-bold px-3 py-1 rounded-full border ${conf.color}`}>{conf.text}</span>
          </div>
          <h2 className="text-3xl font-black mb-3">{rec.recommendedMethod}</h2>
          <p className="text-indigo-100 leading-relaxed">{rec.justification}</p>
        </div>

        {/* Preliminary analyses */}
        {rec.preliminary && rec.preliminary.length > 0 && (
          <div className="bg-white rounded-2xl border border-slate-200 p-5">
            <p className="font-bold text-slate-800 mb-3 flex items-center gap-2"><CheckCircle2 className="w-4 h-4 text-blue-500" /> Análisis preliminares</p>
            <ul className="space-y-1.5">
              {rec.preliminary.map((p, i) => (
                <li key={i} className="text-sm text-slate-600 flex items-start gap-2">
                  <span className="text-blue-400 mt-1">•</span>{p}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Assumptions */}
        {rec.assumptions && rec.assumptions.length > 0 && (
          <div className="bg-white rounded-2xl border border-slate-200 p-5">
            <p className="font-bold text-slate-800 mb-3 flex items-center gap-2"><CheckCircle2 className="w-4 h-4 text-amber-500" /> Pruebas de supuestos a verificar</p>
            <ul className="space-y-1.5">
              {rec.assumptions.map((a, i) => (
                <li key={i} className="text-sm text-slate-600 flex items-start gap-2">
                  <span className="text-amber-400 mt-1">•</span>{a}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Alternatives */}
        {rec.alternatives && rec.alternatives.length > 0 && (
          <div className="bg-slate-100 rounded-2xl p-5">
            <p className="font-bold text-slate-700 mb-3 text-sm">También podrías considerar</p>
            {rec.alternatives.map((alt, i) => (
              <p key={i} className="text-sm text-slate-600 mb-1"><span className="font-semibold">{alt.method}:</span> {alt.reason}</p>
            ))}
          </div>
        )}

        {/* Academic citation */}
        {rec.citation && (
          <div className="bg-slate-50 border border-slate-200 rounded-2xl p-5">
            <p className="font-bold text-slate-700 mb-2 text-sm flex items-center gap-2">📚 Sustento metodológico</p>
            <p className="text-sm text-slate-600 leading-relaxed italic">{rec.citation}</p>
          </div>
        )}

        {/* Warnings */}
        {rec.warnings && rec.warnings.length > 0 && (
          <div className="bg-amber-50 border-2 border-amber-200 rounded-2xl p-5">
            <p className="font-bold text-amber-800 mb-2 flex items-center gap-2"><AlertTriangle className="w-4 h-4" /> Advertencia metodológica</p>
            {rec.warnings.map((w, i) => (
              <p key={i} className="text-sm text-amber-700 leading-relaxed mb-1">{w}</p>
            ))}
          </div>
        )}

        {/* Research summary */}
        {data?.objective?.text && (
          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-2">
            <p className="font-bold text-slate-800 text-sm">Resumen de tu investigación</p>
            <p className="text-sm text-slate-600"><span className="font-semibold">Objetivo:</span> {data.objective.text}</p>
            {data.hypothesis?.h1 && <p className="text-sm text-slate-600"><span className="font-semibold">H₁:</span> {data.hypothesis.h1}</p>}
          </div>
        )}

        <div className="flex justify-between items-center pt-2">
          <button onClick={() => router.push('/research/hypothesis')} className="btn-secondary">← Volver a hipótesis</button>
          <button onClick={goToAnalysis} className="btn-primary flex items-center gap-2 px-6">
            Continuar con {rec.recommendedMethod} <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
