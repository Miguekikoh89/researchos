'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronRight, Sparkles, Edit3, Check } from 'lucide-react';
import { needsPurposeQuestion, recommendMethod, type ScaleResultado, type ScaleExplicativa, type CovariateType, type Purpose } from '@/lib/methodRecommendation';

interface Variable { id:string; code:string; name:string; role:string; scale?:string; groups?:number; dimensions?:{name:string; items?:string[]}[]; }

function getPurposeOptions(explicativa: ScaleExplicativa | null, resultado: ScaleResultado | null): { id: Purpose; icon: string; label: string; desc: string }[] {
  const explicativaIsNominal = explicativa === 'nominal_2' || explicativa === 'nominal_3mas';
  const resultadoIsNominal3 = resultado === 'nominal_3mas';
  if (resultadoIsNominal3 && explicativaIsNominal) {
    return [
      { id:'asociar', icon:'🔀', label:'Asociar', desc:'Analizar si las categorías de ambas variables están asociadas (Chi-cuadrado).' },
      { id:'predecir', icon:'📈', label:'Predecir o clasificar', desc:'Estimar la probabilidad de cada categoría a partir de la otra variable (logística multinomial).' },
    ];
  }
  if (explicativaIsNominal) {
    return [
      { id:'comparar', icon:'⚖️', label:'Comparar', desc:'Comparar la media de tu variable resultado entre los grupos.' },
      { id:'predecir', icon:'📈', label:'Predecir', desc:'Usar el grupo como predictor categórico dentro de una regresión.' },
    ];
  }
  return [
    { id:'relacionar', icon:'🔗', label:'Relacionar', desc:'Analizar si las variables se asocian, sin predecir.' },
    { id:'predecir',    icon:'📈', label:'Predecir',   desc:'Estimar una variable a partir de la otra.' },
  ];
}

const ACTION_VERBS: Record<string,string> = {
  relacionar: 'Determinar la relación entre',
  predecir:   'Determinar en qué medida',
  comparar:   'Determinar las diferencias en',
  clasificar: 'Determinar la clasificación de',
  asociar:    'Evaluar la asociación entre',
};

function scaleToResultado(scale: string, groups: number): ScaleResultado {
  const s = (scale || '').toLowerCase();
  if (s.includes('nomin')) return groups >= 3 ? 'nominal_3mas' : 'nominal_2';
  if (s.includes('ordinal')) return 'ordinal';
  return 'continua';
}
function scaleToExplicativa(scale: string, groups: number): ScaleExplicativa {
  return scaleToResultado(scale, groups) as ScaleExplicativa;
}

export default function ObjectivePage() {
  const router = useRouter();
  const [variables, setVariables] = useState<Variable[]>([]);
  const [varA, setVarA] = useState(''); // Variable explicativa / independiente
  const [varB, setVarB] = useState(''); // Variable resultado / dependiente
  const [covariateVar, setCovariateVar] = useState('');
  const [purpose, setPurpose] = useState<Purpose | ''>('');
  const [population, setPopulation] = useState('');
  const [generated, setGenerated] = useState('');
  const [editing, setEditing] = useState(false);
  const [edited, setEdited] = useState('');

  useEffect(() => {
    const data = localStorage.getItem('ros_research');
    if (data) {
      const parsed = JSON.parse(data);
      setVariables(parsed.variables || []);
      const vi = parsed.variables?.find((v:any) => v.role === 'Independiente');
      const vd = parsed.variables?.find((v:any) => v.role === 'Dependiente');
      if (vi) setVarA(vi.id);
      if (vd) setVarB(vd.id);
    }
  }, []);

  const getVar = (id: string) => variables.find(v => v.id === id);
  const a = getVar(varA);
  const b = getVar(varB);
  const cov = getVar(covariateVar);

  const resultadoScale: ScaleResultado | null = b ? scaleToResultado(b.scale || '', b.groups || 0) : null;
  const explicativaScale: ScaleExplicativa | null = a ? scaleToExplicativa(a.scale || '', a.groups || 0) : null;
  const requiresPurpose = resultadoScale && explicativaScale ? needsPurposeQuestion(resultadoScale, explicativaScale) : false;
  const covariateType: CovariateType = !cov ? 'no' : (cov.scale || '').toLowerCase().includes('nomin') ? 'categorica' : 'continua';

  const canRecommend = !!a && !!b && (!requiresPurpose || !!purpose);

  const rec = canRecommend && resultadoScale && explicativaScale
    ? recommendMethod({ resultado: resultadoScale, explicativa: explicativaScale, covariate: covariateType, purpose: purpose || undefined, hasDims: (a?.dimensions?.length||0)>0 || (b?.dimensions?.length||0)>0 })
    : null;

  const generate = () => {
    if (!a || !b || !rec) return;
    const pop = population || 'la población de estudio';
    // Derivar el verbo del objetivo a partir del proposito elegido o del metodo recomendado
    const verbKey: Purpose = purpose || (rec.methodSlug === 'correlacional' ? 'relacionar'
      : rec.methodSlug === 'chi_cuadrado' ? 'asociar'
      : rec.methodSlug === 'discriminante' ? 'clasificar'
      : (rec.methodSlug === 'anova' || rec.methodSlug === 'ancova' || rec.methodSlug === 'comparacion') ? 'comparar'
      : 'predecir');
    const verb = ACTION_VERBS[verbKey] || 'Analizar';
    let text = '';
    if (verbKey === 'relacionar' || verbKey === 'asociar') text = `${verb} ${a.name.toLowerCase()} y ${b.name.toLowerCase()} en ${pop}.`;
    else if (verbKey === 'comparar') text = `${verb} ${b.name.toLowerCase()} según ${a.name.toLowerCase()} en ${pop}.`;
    else if (verbKey === 'predecir') text = `${verb} ${a.name.toLowerCase()} predice ${b.name.toLowerCase()} en ${pop}.`;
    else if (verbKey === 'clasificar') text = `${verb} ${b.name.toLowerCase()} a partir de ${a.name.toLowerCase()} en ${pop}.`;
    setGenerated(text);
    setEdited(text);
  };

  const [specDir, setSpecDir] = useState<'AvsB'|'BvsA'|'dimDim'>('AvsB');
  const [specObjs, setSpecObjs] = useState<{text:string, enabled:boolean}[]>([]);

  const generateSpecific = () => {
    if (!a || !b) return;
    const dimsA = a.dimensions || [];
    const dimsB = b.dimensions || [];
    const verbKey: Purpose = purpose || 'relacionar';
    const verb = ACTION_VERBS[verbKey] || 'Analizar';
    const pop = population || 'la población de estudio';
    let objs: {text:string, enabled:boolean}[] = [];
    if (specDir === 'AvsB' && dimsA.length) {
      objs = dimsA.map(d => ({ text: `${verb} ${d.name.toLowerCase()} de ${a.name.toLowerCase()} y ${b.name.toLowerCase()} en ${pop}.`, enabled: true }));
    } else if (specDir === 'BvsA' && dimsB.length) {
      objs = dimsB.map(d => ({ text: `${verb} ${d.name.toLowerCase()} de ${b.name.toLowerCase()} y ${a.name.toLowerCase()} en ${pop}.`, enabled: true }));
    } else if (specDir === 'dimDim' && dimsA.length && dimsB.length) {
      objs = [];
      for (const da of dimsA) for (const db of dimsB) objs.push({ text: `${verb} ${da.name.toLowerCase()} y ${db.name.toLowerCase()} en ${pop}.`, enabled: true });
    }
    setSpecObjs(objs);
  };

  const save = () => {
    const data = JSON.parse(localStorage.getItem('ros_research') || '{}');
    data.objective = {
      action: purpose || rec?.methodSlug, varA, varB, varC: covariateVar || undefined,
      text: editing ? edited : generated,
      specificObjectives: specObjs.filter(s=>s.enabled).map(s=>s.text),
      recommendedMethodSlug: rec?.methodSlug,
    };
    localStorage.setItem('ros_research', JSON.stringify(data));
    router.push('/research/hypothesis');
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center text-white font-black text-sm">OS</div>
          <p className="font-black text-slate-900">Asistente metodológico</p>
        </div>
        <div className="text-xs text-slate-400 font-medium">
          <span className="text-green-600 font-bold">✓ Variables → ✓ Dimensiones</span>
          <span className="mx-1">→</span>
          <span className="text-indigo-600 font-bold">Objetivo</span>
          <span className="mx-1">→</span>
          <span>Hipótesis → Recomendación</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-8 space-y-6">
        <div>
          <h1 className="text-2xl font-black text-slate-900">¿Qué variables quieres relacionar?</h1>
          <p className="text-slate-500 mt-1">Selecciona tus variables. CanchariOS usará la escala que ya registraste para sugerirte el método más adecuado.</p>
        </div>

        {/* Selector de variables */}
        <div className="bg-white rounded-2xl border-2 border-slate-200 p-5 space-y-4">
          <div className="grid grid-cols-1 gap-3">
            <div>
              <label className="label">Variable explicativa / independiente</label>
              <select className="input" value={varA} onChange={e=>setVarA(e.target.value)}>
                <option value="">Seleccionar...</option>
                {variables.map(v=><option key={v.id} value={v.id}>{v.name} ({v.scale || 'sin escala'})</option>)}
              </select>
            </div>
            <div>
              <label className="label">Variable resultado / dependiente</label>
              <select className="input" value={varB} onChange={e=>setVarB(e.target.value)}>
                <option value="">Seleccionar...</option>
                {variables.filter(v=>v.id!==varA).map(v=><option key={v.id} value={v.id}>{v.name} ({v.scale || 'sin escala'})</option>)}
              </select>
            </div>
            <div>
              <label className="label">¿Existe una covariable a controlar? (opcional)</label>
              <select className="input" value={covariateVar} onChange={e=>setCovariateVar(e.target.value)}>
                <option value="">No tengo covariable</option>
                {variables.filter(v=>v.id!==varA&&v.id!==varB).map(v=><option key={v.id} value={v.id}>{v.name} ({v.scale || 'sin escala'})</option>)}
              </select>
            </div>
            <div>
              <label className="label">Población / contexto (opcional)</label>
              <input className="input" placeholder="Ej: docentes de educación básica de Lima, 2024" value={population} onChange={e=>setPopulation(e.target.value)} />
            </div>
          </div>
        </div>

        {/* Pregunta de proposito - solo si hay ambiguedad */}
        {a && b && requiresPurpose && (
          <div className="bg-amber-50 border-2 border-amber-200 rounded-2xl p-5 space-y-3 animate-fade-in">
            <p className="font-bold text-amber-800 text-sm">Una pregunta más: ¿qué deseas hacer?</p>
            <p className="text-xs text-amber-700">La escala de tus variables no basta para decidir entre estos dos métodos. Elige tu propósito:</p>
            <div className="grid grid-cols-2 gap-3">
              {getPurposeOptions(explicativaScale, resultadoScale).map(p => (
                <button key={p.id} onClick={() => setPurpose(p.id)}
                  className={`text-left p-3 rounded-xl border-2 transition ${purpose===p.id?'bg-amber-500 border-amber-500 text-white':'bg-white border-amber-200 text-slate-700 hover:border-amber-400'}`}>
                  <span className="text-xl block mb-1">{p.icon}</span>
                  <p className="font-bold text-sm">{p.label}</p>
                  <p className={`text-xs mt-0.5 ${purpose===p.id?'text-amber-100':'text-slate-500'}`}>{p.desc}</p>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Recomendacion en vivo */}
        {rec && (
          <div className="bg-indigo-50 border-2 border-indigo-200 rounded-2xl p-5 space-y-2 animate-fade-in">
            <p className="text-xs font-bold text-indigo-600 uppercase tracking-wide">Método sugerido</p>
            <p className="text-xl font-black text-indigo-900">{rec.recommendedMethod}</p>
            <p className="text-sm text-indigo-700">{rec.justification}</p>
          </div>
        )}

        {/* Generar objetivo */}
        {rec && (
          <button onClick={generate} className="w-full btn-primary flex items-center justify-center gap-2">
            <Sparkles className="w-4 h-4"/> Generar objetivo automáticamente
          </button>
        )}

        {generated && (
          <div className="bg-indigo-50 border-2 border-indigo-200 rounded-2xl p-5 space-y-3 animate-fade-in">
            <div className="flex items-center justify-between">
              <p className="font-bold text-indigo-800 flex items-center gap-2"><Check className="w-4 h-4"/>Objetivo general generado</p>
              <button onClick={() => setEditing(!editing)} className="text-xs font-bold text-indigo-600 flex items-center gap-1 hover:text-indigo-800">
                <Edit3 className="w-3 h-3"/> {editing?'Ver resultado':'Editar'}
              </button>
            </div>
            {editing ? (
              <textarea className="input text-sm w-full resize-none" rows={3} value={edited} onChange={e=>setEdited(e.target.value)} />
            ) : (
              <p className="text-indigo-900 font-medium italic">"{edited || generated}"</p>
            )}
          </div>
        )}

        {/* Objetivos especificos por dimension */}
        {generated && ((a?.dimensions?.length||0)>0 || (b?.dimensions?.length||0)>0) && (
          <div className="bg-white rounded-2xl border-2 border-slate-200 p-5 space-y-4 animate-fade-in">
            <p className="font-bold text-slate-800">Objetivos específicos</p>
            <p className="text-sm text-slate-500">¿Cómo quieres construirlos?</p>
            <div className="flex flex-wrap gap-2">
              {[
                {id:'AvsB', label:`Dimensiones de ${a?.name||'Var A'} → ${b?.name||'Var B'}`},
                {id:'BvsA', label:`Dimensiones de ${b?.name||'Var B'} → ${a?.name||'Var A'}`},
                {id:'dimDim', label:'Dimensión × Dimensión'},
              ].map(opt => (
                <button key={opt.id} onClick={() => setSpecDir(opt.id as any)}
                  className={`text-xs font-bold px-3 py-2 rounded-full border-2 transition ${specDir===opt.id?'bg-indigo-600 text-white border-indigo-600':'bg-white text-slate-600 border-slate-200 hover:border-indigo-300'}`}>
                  {opt.label}
                </button>
              ))}
            </div>
            <button onClick={generateSpecific} className="w-full btn-primary text-sm py-2">✨ Generar objetivos específicos</button>
            {specObjs.length > 0 && (
              <div className="space-y-2 mt-2">
                {specObjs.map((s,i) => (
                  <div key={i} className="flex items-start gap-3">
                    <button onClick={() => setSpecObjs(sp=>sp.map((x,j)=>j===i?{...x,enabled:!x.enabled}:x))}
                      className={`mt-1 w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 ${s.enabled?'bg-indigo-600 border-indigo-600 text-white':'border-slate-300'}`}>
                      {s.enabled && <span className="text-xs">✓</span>}
                    </button>
                    <textarea className={`input text-sm flex-1 resize-none ${!s.enabled?'opacity-40':''}`} rows={1}
                      value={s.text} onChange={e=>setSpecObjs(sp=>sp.map((x,j)=>j===i?{...x,text:e.target.value}:x))} />
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        <div className="flex justify-between pt-2">
          <button onClick={() => router.push('/research')} className="btn-secondary">← Volver</button>
          <button onClick={save} disabled={!generated} className="btn-primary flex items-center gap-2 disabled:opacity-40">
            Continuar con hipótesis <ChevronRight className="w-4 h-4"/>
          </button>
        </div>
      </div>
    </div>
  );
}
