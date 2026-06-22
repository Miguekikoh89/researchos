'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronRight, Sparkles, ToggleLeft, ToggleRight } from 'lucide-react';

const HYP_TEMPLATES: Record<string, (a:string, b:string, m?:string) => {h1:string, h0:string, specific?:string[]}> = {
  relacionar: (a,b) => ({
    h1: `Existe relación significativa entre ${a} y ${b}.`,
    h0: `No existe relación significativa entre ${a} y ${b}.`,
  }),
  comparar: (a,b) => ({
    h1: `Existen diferencias significativas en ${a} según ${b}.`,
    h0: `No existen diferencias significativas en ${a} según ${b}.`,
  }),
  predecir: (a,b) => ({
    h1: `${a} predice significativamente ${b}.`,
    h0: `${a} no predice significativamente ${b}.`,
  }),
  explicar: (a,b,m) => ({
    h1: `${m||'la variable mediadora'} media la relación entre ${a} y ${b}.`,
    h0: `${m||'la variable mediadora'} no media la relación entre ${a} y ${b}.`,
  }),
  describir: (a) => ({
    h1: ``, h0: ``,
  }),
  evaluar: (a,b) => ({
    h1: `Existe asociación significativa entre ${a} y ${b}.`,
    h0: `No existe asociación significativa entre ${a} y ${b}.`,
  }),
  estructural: (a,b) => ({
    h1: `Existe un modelo estructural significativo entre ${a} y ${b}.`,
    h0: `No existe un modelo estructural significativo entre ${a} y ${b}.`,
  }),
};

export default function HypothesisPage() {
  const router = useRouter();
  const [data, setData] = useState<any>(null);
  const [h1, setH1] = useState('');
  const [h0, setH0] = useState('');
  const [enabled, setEnabled] = useState(true);
  const [specific, setSpecific] = useState<{text:string, enabled:boolean}[]>([]);

  useEffect(() => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    setData(d);
    if(!d.objective) return;

    const { action, varA, varB, varM } = d.objective;
    const vars = d.variables || [];
    const getN = (id:string) => vars.find((v:any)=>v.id===id)?.name?.toLowerCase() || '';
    const a = getN(varA); const b = getN(varB); const m = getN(varM);

    if(action === 'describir') { setEnabled(false); return; }

    const tmpl = HYP_TEMPLATES[action];
    if(tmpl) {
      const res = tmpl(a, b, m);
      setH1(res.h1); setH0(res.h0);
    }

    // Specific hypotheses from objective specific objectives
    const specObjs = d.objective?.specificObjs || [];
    if(specObjs.length > 0) {
      setSpecific(specObjs.map((s:any) => ({
        text: s.text.replace('Determinar la relación entre', 'Existe relación significativa entre').replace('.', ' (H₁).'),
        enabled: s.enabled
      })));
    } else {
      const varAObj = vars.find((v:any)=>v.id===varA);
      const varBObj = vars.find((v:any)=>v.id===varB);
      if(action === 'relacionar' && varAObj?.dimensions?.length > 0 && varBObj) {
        const specs = varAObj.dimensions.map((dim:any) => ({
          text: `Existe relación significativa entre ${dim.name.toLowerCase()} y ${varBObj.name.toLowerCase()}.`,
          enabled: true
        }));
        setSpecific(specs);
      }
    }
  }, []);

  const save = () => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    d.hypothesis = { enabled, h1, h0, specific };
    localStorage.setItem('ros_research', JSON.stringify(d));
    router.push('/research/recommendation');
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center text-white font-black text-sm">OS</div>
          <p className="font-black text-slate-900">Asistente metodológico</p>
        </div>
        <div className="flex items-center gap-1 text-xs text-slate-400 font-medium">
          <span className="text-green-600 font-bold">✓ Variables → ✓ Dimensiones → ✓ Objetivo</span>
          <span className="mx-1">→</span>
          <span className="text-indigo-600 font-bold">Hipótesis</span>
          <span className="mx-1">→</span>
          <span>Recomendación → Análisis</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-8 space-y-6">
        <div>
          <h1 className="text-2xl font-black text-slate-900">Hipótesis de investigación</h1>
          <p className="text-slate-500 mt-1">Generadas automáticamente desde tu objetivo. Puedes editarlas.</p>
        </div>

        {!enabled && (
          <div className="bg-amber-50 border-2 border-amber-200 rounded-2xl p-5">
            <p className="font-bold text-amber-800">📋 Estudio descriptivo</p>
            <p className="text-amber-700 text-sm mt-1">Los estudios descriptivos generalmente no requieren hipótesis, salvo que tu institución lo exija.</p>
            <button onClick={() => setEnabled(true)} className="mt-3 text-sm font-bold text-amber-700 underline">
              Agregar hipótesis de todas formas
            </button>
          </div>
        )}

        {enabled && h1 && (
          <div className="space-y-4">
            <div className="bg-white rounded-2xl border-2 border-green-200 p-5 space-y-3">
              <div className="flex items-center justify-between">
                <p className="font-bold text-green-800 flex items-center gap-2">✅ Hipótesis general (H₁)</p>
              </div>
              <textarea className="input text-sm w-full resize-none" rows={2}
                value={h1} onChange={e=>setH1(e.target.value)}/>
            </div>

            <div className="bg-white rounded-2xl border-2 border-red-100 p-5 space-y-3">
              <p className="font-bold text-red-700">❌ Hipótesis nula (H₀)</p>
              <textarea className="input text-sm w-full resize-none" rows={2}
                value={h0} onChange={e=>setH0(e.target.value)}/>
            </div>

            {specific.length > 0 && (
              <div className="bg-white rounded-2xl border-2 border-slate-200 p-5 space-y-3">
                <p className="font-bold text-slate-800">Hipótesis específicas</p>
                {specific.map((s,i) => (
                  <div key={i} className="flex items-start gap-3">
                    <button onClick={() => setSpecific(sp => sp.map((x,j)=>j===i?{...x,enabled:!x.enabled}:x))}>
                      {s.enabled ? <ToggleRight className="w-5 h-5 text-indigo-600 mt-0.5"/> : <ToggleLeft className="w-5 h-5 text-slate-300 mt-0.5"/>}
                    </button>
                    <textarea className={`input text-sm flex-1 resize-none ${!s.enabled?'opacity-40':''}`} rows={1}
                      value={s.text} onChange={e=>setSpecific(sp=>sp.map((x,j)=>j===i?{...x,text:e.target.value}:x))}/>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => router.push('/research/objective')} className="btn-secondary">← Volver</button>
          <button onClick={save} className="btn-primary flex items-center gap-2">
            Ver método recomendado <ChevronRight className="w-4 h-4"/>
          </button>
        </div>
      </div>
    </div>
  );
}
