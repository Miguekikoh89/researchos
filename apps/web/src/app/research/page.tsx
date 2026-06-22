'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, Trash2, ChevronRight, FlaskConical } from 'lucide-react';

const ROLES = ['Independiente','Dependiente','Mediadora','Moderadora','Descriptiva'];
const SCALES = ['Ordinal (Likert)','Nominal','Intervalo','Razón'];
const INSTRUMENTS = ['Escala Likert','Cuestionario dicotómico','Registro numérico','Categoría sociodemográfica'];
const CODES = ['A','B','C','D','E'];

interface Dimension { id: string; name: string; }
interface Variable {
  id: string; code: string; name: string; role: string;
  scale: string; instrument: string; items: number;
  groups: number;
  dimensions: Dimension[];
}

function uid() { return Math.random().toString(36).slice(2,8); }

export default function ResearchPage() {
  const router = useRouter();
  const [variables, setVariables] = useState<Variable[]>([
    { id: uid(), code:'A', name:'', role:'Independiente', scale:'Ordinal (Likert)', instrument:'Escala Likert', items:0, groups:0, dimensions:[] },
    { id: uid(), code:'B', name:'', role:'Dependiente',   scale:'Ordinal (Likert)', instrument:'Escala Likert', items:0, groups:0, dimensions:[] },
  ]);
  const [step, setStep] = useState<'variables'|'dimensions'>('variables');
  const [dimInput, setDimInput] = useState<Record<string,string>>({});

  const addVariable = () => {
    if(variables.length >= 5) return;
    const code = CODES[variables.length];
    setVariables(v => [...v, { id:uid(), code, name:'', role:'Independiente', scale:'Ordinal (Likert)', instrument:'Escala Likert', items:0, groups:0, dimensions:[] }]);
  };

  const updateVar = (id: string, field: string, value: any) =>
    setVariables(v => v.map(x => x.id===id ? {...x,[field]:value} : x));

  const removeVar = (id: string) =>
    setVariables(v => v.filter(x => x.id!==id).map((x,i) => ({...x, code:CODES[i]})));

  const addDim = (varId: string) => {
    const val = (dimInput[varId]||'').trim();
    if(!val) return;
    setVariables(v => v.map(x => x.id===varId ? {...x, dimensions:[...x.dimensions, {id:uid(), name:val}]} : x));
    setDimInput(d => ({...d, [varId]:''}));
  };

  const removeDim = (varId: string, dimId: string) =>
    setVariables(v => v.map(x => x.id===varId ? {...x, dimensions:x.dimensions.filter(d=>d.id!==dimId)} : x));

  const canContinue = variables.every(v => v.name.trim().length > 0);

  const goNext = () => {
    if(step === 'variables') { setStep('dimensions'); return; }
    // Save to localStorage and go to objective builder
    localStorage.setItem('ros_research', JSON.stringify({ variables }));
    router.push('/research/objective');
  };

  const roleColor: Record<string,string> = {
    'Independiente':'bg-indigo-100 text-indigo-700',
    'Dependiente':'bg-purple-100 text-purple-700',
    'Mediadora':'bg-amber-100 text-amber-700',
    'Moderadora':'bg-pink-100 text-pink-700',
    'Descriptiva':'bg-slate-100 text-slate-600',
  };

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header */}
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <a href="/dashboard" className="flex items-center gap-3 hover:opacity-80 transition">
            <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center">
              <FlaskConical className="w-5 h-5 text-white"/>
            </div>
            <div>
              <p className="font-black text-slate-900">CanchariOS</p>
              <p className="text-xs text-slate-400">Asistente metodológico</p>
            </div>
          </a>
        </div>
        {/* Progress */}
        <div className="flex items-center gap-2">
          {['Variables','Dimensiones','Objetivo','Hipótesis','Recomendación','Análisis'].map((s,i) => (
            <div key={s} className="flex items-center gap-1">
              <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all ${
                (step==='variables'&&i===0)||(step==='dimensions'&&i===1) ? 'bg-indigo-600 text-white' :
                i < (['variables','dimensions'].indexOf(step)) ? 'bg-green-500 text-white' : 'bg-slate-200 text-slate-400'
              }`}>{i+1}</div>
              {i < 6 && <div className="w-6 h-0.5 bg-slate-200"/>}
            </div>
          ))}
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-6 py-8 space-y-6">

        {/* STEP: VARIABLES */}
        {step === 'variables' && (
          <>
            <div>
              <h1 className="text-2xl font-black text-slate-900">¿Qué variables tiene tu investigación?</h1>
              <p className="text-slate-500 mt-1">Escribe el nombre de cada variable. El rol ya está sugerido.</p>
            </div>

            <div className="space-y-4">
              {variables.map((v, idx) => (
                <div key={v.id} className="bg-white rounded-2xl border-2 border-slate-200 p-5 space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center text-white font-black text-sm">
                        {v.code}
                      </div>
                      <span className="font-bold text-slate-700">Variable {v.code}</span>
                    </div>
                    {variables.length > 2 && (
                      <button onClick={() => removeVar(v.id)} className="p-1.5 hover:bg-red-50 rounded-lg transition">
                        <Trash2 className="w-4 h-4 text-red-400"/>
                      </button>
                    )}
                  </div>

                  <input
                    className="input text-base font-semibold"
                    placeholder={`Ej: ${idx===0?'Calidad de servicio':idx===1?'Satisfacción del cliente':'Nombre de la variable'}`}
                    value={v.name}
                    onChange={e => updateVar(v.id, 'name', e.target.value)}
                  />

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="label">Rol</label>
                      <div className="flex flex-wrap gap-2">
                        {ROLES.map(r => (
                          <button key={r} onClick={() => updateVar(v.id,'role',r)}
                            className={`text-xs font-bold px-3 py-1.5 rounded-full border-2 transition ${v.role===r ? roleColor[r]+' border-transparent' : 'border-slate-200 text-slate-500 hover:border-slate-300'}`}>
                            {r}
                          </button>
                        ))}
                      </div>
                    </div>
                    <div>
                      <label className="label">Escala</label>
                      <select className="input text-sm" value={v.scale} onChange={e=>updateVar(v.id,'scale',e.target.value)}>
                        {SCALES.map(s=><option key={s}>{s}</option>)}
                      </select>
                      <p className="text-xs text-slate-400 mt-1">
                        {v.scale === 'Nominal' && 'Ejemplo: sexo (M/F), área de trabajo, turno, religión. Categorías sin orden.'}
                        {v.scale === 'Ordinal (Likert)' && 'Ejemplo: nivel de satisfacción (1=Muy en desacuerdo a 5=Muy de acuerdo), nivel educativo. Categorías con orden, distancia no exacta.'}
                        {v.scale === 'Intervalo' && 'Ejemplo: puntaje de un test psicométrico, temperatura en °C. Distancias iguales, sin cero absoluto.'}
                        {v.scale === 'Razón' && 'Ejemplo: edad, ingresos, años de experiencia, peso. Distancias iguales y cero absoluto real.'}
                      </p>
                    </div>
                  </div>
                  {v.scale === 'Nominal' && (
                    <div className="grid grid-cols-1 gap-3">
                      <div>
                        <label className="label">¿Cuántas categorías o grupos tiene?</label>
                        <input type="number" min={2} max={10} className="input text-sm" placeholder="Ej: 2 (Sí/No), 3 (Bajo/Medio/Alto)" value={v.groups || ''} onChange={e=>updateVar(v.id,'groups',parseInt(e.target.value)||0)} />
                        <p className="text-xs text-slate-400 mt-1">Esto nos ayuda a recomendarte el método correcto (ej: 2 grupos → comparación o logística; 3+ grupos → ANOVA).</p>
                      </div>
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="label">Instrumento</label>
                      <select className="input text-sm" value={v.instrument} onChange={e=>updateVar(v.id,'instrument',e.target.value)}>
                        {INSTRUMENTS.map(s=><option key={s}>{s}</option>)}
                      </select>
                    </div>
                    <div>
                      <label className="label">N° de ítems</label>
                      <input type="number" min={0} className="input text-sm" value={v.items||''} placeholder="Ej: 12"
                        onChange={e=>updateVar(v.id,'items',parseInt(e.target.value)||0)}/>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {variables.length < 5 && (
              <button onClick={addVariable}
                className="w-full border-2 border-dashed border-slate-300 rounded-2xl py-4 text-slate-400 font-semibold hover:border-indigo-400 hover:text-indigo-500 transition flex items-center justify-center gap-2">
                <Plus className="w-4 h-4"/> Agregar otra variable
              </button>
            )}
          </>
        )}

        {/* STEP: DIMENSIONES */}
        {step === 'dimensions' && (
          <>
            <div>
              <h1 className="text-2xl font-black text-slate-900">¿Cuáles son las dimensiones?</h1>
              <p className="text-slate-500 mt-1">Agrega las dimensiones de cada variable. Escribe y presiona Enter.</p>
            </div>

            <div className="space-y-5">
              {variables.map(v => (
                <div key={v.id} className="bg-white rounded-2xl border-2 border-slate-200 p-5 space-y-4">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center text-white font-black text-sm">{v.code}</div>
                    <div>
                      <p className="font-black text-slate-800">{v.name}</p>
                      <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${roleColor[v.role]}`}>{v.role}</span>
                    </div>
                  </div>

                  {/* Dimensiones existentes */}
                  <div className="flex flex-wrap gap-2">
                    {v.dimensions.map(d => (
                      <div key={d.id} className="flex items-center gap-1.5 bg-indigo-50 border border-indigo-200 rounded-full px-3 py-1.5">
                        <span className="text-sm font-semibold text-indigo-700">{d.name}</span>
                        <button onClick={() => removeDim(v.id, d.id)} className="text-indigo-400 hover:text-red-500 transition">×</button>
                      </div>
                    ))}
                  </div>

                  {/* Input nueva dimensión */}
                  <div className="flex gap-2">
                    <input
                      className="input flex-1 text-sm"
                      placeholder="Ej: Tangibilidad, Fiabilidad..."
                      value={dimInput[v.id]||''}
                      onChange={e => setDimInput(d=>({...d,[v.id]:e.target.value}))}
                      onKeyDown={e => { if(e.key==='Enter') { e.preventDefault(); addDim(v.id); } }}
                    />
                    <button onClick={() => addDim(v.id)}
                      className="px-4 py-2 bg-indigo-600 text-white rounded-xl font-bold text-sm hover:bg-indigo-700 transition">
                      + Agregar
                    </button>
                  </div>

                  {v.dimensions.length === 0 && (
                    <p className="text-xs text-slate-400">Sin dimensiones — se usará la variable completa en el análisis.</p>
                  )}
                </div>
              ))}
            </div>
          </>
        )}

        {/* Navigation */}
        <div className="flex justify-between pt-2">
          {step === 'dimensions' ? (
            <button onClick={() => setStep('variables')} className="btn-secondary">← Volver</button>
          ) : (
            <button onClick={() => router.push('/dashboard')} className="btn-secondary">← Dashboard</button>
          )}
          <button onClick={goNext} disabled={!canContinue}
            className="btn-primary flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed">
            {step==='variables' ? 'Continuar con dimensiones' : 'Construir objetivo'}
            <ChevronRight className="w-4 h-4"/>
          </button>
        </div>
      </div>
    </div>
  );
}
