'use client';
import React from 'react';
import { useState } from 'react';
import { ChevronRight, ChevronLeft, Plus, Trash2, TrendingUp, BarChart2, GitBranch, Grid, FlaskConical, Users, ArrowRight } from 'lucide-react';
import type { WizardState, AnalysisFormConfig } from '@/app/analysis/new/page';

interface Props {
  state: WizardState;
  config: AnalysisFormConfig;
  updateConfig: (patch: Partial<AnalysisFormConfig>) => void;
  onNext: () => void;
  onBack: () => void;
  hideMethodSelector?: boolean;
}

function ItemChips({ columns, selected, onChange, color='indigo' }: {
  columns: string[]; selected: string[]; onChange: (v: string[]) => void; color?: string;
}) {
  const [rangeFrom, setRangeFrom] = React.useState('');
  const [rangeTo, setRangeTo]   = React.useState('');

  const toggle = (col: string) =>
    onChange(selected.includes(col) ? selected.filter(c => c !== col) : [...selected, col]);

  const applyRange = () => {
    if (!rangeFrom || !rangeTo) return;
    const i1 = columns.indexOf(rangeFrom);
    const i2 = columns.indexOf(rangeTo);
    if (i1 < 0 || i2 < 0) return;
    const [from, to] = i1 < i2 ? [i1, i2] : [i2, i1];
    const range = columns.slice(from, to + 1);
    onChange([...new Set([...selected, ...range])]);
  };

  const active = color === 'teal' ? 'bg-teal-600 text-white shadow-sm' : 'bg-indigo-600 text-white shadow-sm';
  return (
    <div>
      <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
        <div className="flex items-center gap-2">
          <select value={rangeFrom} onChange={e=>setRangeFrom(e.target.value)}
            className="text-xs border border-slate-200 rounded-lg px-2 py-1.5 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-indigo-400">
            <option value="">Desde</option>
            {columns.map(c=><option key={c} value={c}>{c}</option>)}
          </select>
          <select value={rangeTo} onChange={e=>setRangeTo(e.target.value)}
            className="text-xs border border-slate-200 rounded-lg px-2 py-1.5 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-indigo-400">
            <option value="">Hasta</option>
            {columns.map(c=><option key={c} value={c}>{c}</option>)}
          </select>
          <button type="button" onClick={applyRange}
            className="text-xs font-semibold bg-indigo-600 text-white px-3 py-1.5 rounded-lg hover:bg-indigo-700 transition">
            Agregar
          </button>
        </div>
        <div className="flex gap-3">
          <button type="button" onClick={() => onChange([...columns])} className="text-xs font-semibold text-indigo-600 hover:text-indigo-700 transition">Todos</button>
          <button type="button" onClick={() => onChange([])} className="text-xs font-semibold text-slate-400 hover:text-slate-600 transition">Limpiar</button>
        </div>
      </div>
      <div className="flex flex-wrap gap-2 p-4 bg-slate-50/80 rounded-2xl border border-slate-200 min-h-[80px]">
        {columns.length === 0
          ? <p className="text-slate-400 text-sm m-auto">Sin columnas disponibles</p>
          : columns.map(col => (
            <button key={col} type="button" onClick={() => toggle(col)}
              className={`item-chip ${selected.includes(col) ? active + ' selected' : 'bg-white text-slate-600 border border-slate-200 hover:border-slate-300 unselected'} rounded-xl px-3 py-2 text-sm font-medium transition-all`}>
              {col}
            </button>
          ))}
      </div>
      <p className="text-xs text-slate-500 mt-2 font-medium">{selected.length} ítem(s) seleccionado(s)</p>
    </div>
  );
}

function DimEditor({ dimensions, columns, onChange, color='indigo' }: {
  dimensions: {name:string;items:string[]}[]; columns: string[];
  onChange: (d: {name:string;items:string[]}[]) => void; color?: string;
}) {
  const active = color === 'teal' ? 'bg-teal-600 text-white' : 'bg-indigo-600 text-white';
  const addDim = () => onChange([...dimensions, { name: `Dimensión ${dimensions.length+1}`, items: [] }]);
  const removeDim = (i: number) => onChange(dimensions.filter((_,j) => j !== i));
  const updateName = (i: number, name: string) => onChange(dimensions.map((d,j) => j===i ? {...d,name} : d));
  const toggleItem = (i: number, col: string) => onChange(dimensions.map((d,j) => j===i ? {...d, items: d.items.includes(col) ? d.items.filter(c=>c!==col) : [...d.items, col]} : d));
  return (
    <div className="space-y-4">
      {dimensions.map((dim, i) => (
        <div key={i} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <div className={`w-7 h-7 rounded-lg flex items-center justify-center text-xs font-bold text-white ${color==='teal'?'bg-teal-500':'bg-indigo-500'}`}>{i+1}</div>
            <input value={dim.name} onChange={e=>updateName(i,e.target.value)}
              className="flex-1 input text-base font-semibold" placeholder="Nombre de la dimensión" />
            <button onClick={()=>removeDim(i)} className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition"><Trash2 className="w-4 h-4"/></button>
          </div>
          <div className="flex flex-wrap gap-2">
            {columns.map(col => (
              <button key={col} type="button" onClick={()=>toggleItem(i,col)}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${dim.items.includes(col) ? active : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}>
                {col}
              </button>
            ))}
          </div>
          <p className="text-xs text-slate-400 mt-3">{dim.items.length} ítems</p>
        </div>
      ))}
      <button onClick={addDim} type="button"
        className="w-full py-4 border-2 border-dashed border-slate-300 rounded-2xl text-slate-500 hover:border-indigo-400 hover:text-indigo-600 hover:bg-indigo-50/50 transition-all font-semibold flex items-center justify-center gap-2">
        <Plus className="w-5 h-5"/> Agregar dimensión
      </button>
    </div>
  );
}

const ANALYSIS_TYPES = [
  { id:'structural_model', label:'PLS-SEM',        icon:'🔷', desc:'Modelo estructural por ecuaciones', badge:'⭐ Más avanzado', color:'cyan',   available:true },
  { id:'correlacional',    label:'Correlacional',   icon:'📈', desc:'Relación entre dos variables',      badge:'🎓 Pregrado',     color:'indigo', available:true },
  { id:'regresion',        label:'Regresión lineal',icon:'📉', desc:'Predicción de variable continua',   badge:'📊 Muy usado',    color:'green',  available:true },
  { id:'comparacion',      label:'Comparación',     icon:'⚖️', desc:'Diferencias entre 2 grupos',        badge:'🎓 Pregrado',     color:'purple', available:true },
  { id:'anova',            label:'ANOVA',           icon:'📊', desc:'Comparar 3 o más grupos',           badge:'📊 Muy usado',    color:'amber',  available:true },
  { id:'logistica',        label:'Reg. logística',  icon:'🎯', desc:'Predicción de variable categórica', badge:'🔬 Avanzado',     color:'pink',   available:true },
  { id:'chi_cuadrado',     label:'Chi-cuadrado',    icon:'📋', desc:'Asociación entre variables categ.', badge:'🎓 Pregrado',     color:'orange', available:true },
  { id:'factorial',        label:'Factorial',       icon:'🔲', desc:'Próximamente disponible',           badge:'🚧 Pronto',       color:'slate',  available:false },
];

const colorMap: Record<string,string> = {
  indigo: 'border-indigo-400 bg-indigo-50', purple: 'border-purple-400 bg-purple-50',
  amber:  'border-amber-400  bg-amber-50',  green:  'border-green-400  bg-green-50',
  pink:   'border-pink-400   bg-pink-50',   orange: 'border-orange-400 bg-orange-50',
  cyan:   'border-cyan-400   bg-cyan-50',   slate:  'border-slate-300  bg-slate-50',
};
const iconColorMap: Record<string,string> = {
  indigo:'text-indigo-600', purple:'text-purple-600', amber:'text-amber-600',
  green:'text-green-600', pink:'text-pink-600', orange:'text-orange-600',
  cyan:'text-cyan-600', slate:'text-slate-400',
};

export default function StepConfigure({ state, config: cfg, updateConfig, onNext, onBack, hideMethodSelector = false }: Props) {
  const columns = state.columns ?? [];

  // Auto-load from research assistant if available
  React.useEffect(() => {
    try {
      const rc = JSON.parse(localStorage.getItem('ros_research') || '{}');
      if(!rc.variables || !rc.objective) return;
      const vars = rc.variables || [];
      const obj = rc.objective || {};
      const meth = rc.methodology || {};
      const varA = vars.find((v:any) => v.id === obj.varA) || vars[0];
      const varB = vars.find((v:any) => v.id === obj.varB) || vars[1];

      const catMap: Record<string,any> = {
        relacionar:'correlacional', comparar:'comparacion',
        predecir:'regresion', describir:'correlacional',
        evaluar:'chi_cuadrado', explicar:'regresion', estructural:'correlacional',
      };
      const scaleMap: Record<string,{min:number,max:number}> = {
        'Likert 3 puntos':{min:1,max:3}, 'Likert 5 puntos':{min:1,max:5},
        'Likert 7 puntos':{min:1,max:7}, 'Dicotómica':{min:0,max:1},
        'Numérica continua':{min:1,max:100},
      };
      const scale = scaleMap[meth.scale||'Likert 5 puntos'] || {min:1,max:5};

      const updates: Partial<any> = {};
      const fromUrl = typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('method');
      if(!fromUrl && varA?.name) updates.varAName = varA.name;
      if(!fromUrl && varB?.name) updates.varBName = varB.name;
      if(!fromUrl && obj.action) updates.analysisCategory = catMap[obj.action] || 'correlacional';
      if(!fromUrl && obj.text) updates.studyTitle = obj.text;
      if(!fromUrl && meth.poblacion) updates.participants = meth.poblacion;
      if(scale) { updates.scale = scale; }
      if(varA?.dimensions?.length > 0 && cfg.varADimensions?.length === 0) {
        updates.varADimensions = varA.dimensions.map((d:any) => ({ name: d.name, items: [] }));
      }
      if(varB?.dimensions?.length > 0 && cfg.varBDimensions?.length === 0) {
        updates.varBDimensions = varB.dimensions.map((d:any) => ({ name: d.name, items: [] }));
      }
      if(Object.keys(updates).length > 0) updateConfig(updates);
    } catch(e) {}
  }, []);
  const [showDimsA, setShowDimsA] = useState(cfg.varADimensions?.length > 0);
  const [showDimsB, setShowDimsB] = useState(cfg.varBDimensions?.length > 0);

  const cat = cfg.analysisCategory;
  const urlMethod = typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('method') : null;
  const effectiveCat = (urlMethod || cat) as string;
  // Sincronizar con URL si hay método en URL y config aún no fue actualizado
  React.useEffect(() => {
    if (typeof window !== 'undefined') {
      const m = new URLSearchParams(window.location.search).get('method');
      if (m && m !== cfg.analysisCategory) {
        updateConfig({ analysisCategory: m as any });
      }
    }
  }, []);
  const singleVarMethods = ['cronbach','descriptivo','cluster'];
  const mode = effectiveCat === 'instrumentos' ? 'piloto' : 'analisis';

  const methodLabels: Record<string,{label:string,icon:string,from:string,to:string}> = {
    structural_model:     {label:'PLS-SEM',icon:'🔷',from:'#06b6d4',to:'#2563eb'},
    correlacional:        {label:'Correlacional',icon:'📈',from:'#6366f1',to:'#a855f7'},
    regresion:            {label:'Regresión lineal',icon:'📉',from:'#10b981',to:'#059669'},
    regresion_ordinal:    {label:'Regresión ordinal',icon:'📊',from:'#0ea5e9',to:'#0369a1'},
    regresion_jerarquica: {label:'Reg. jerárquica',icon:'📐',from:'#8b5cf6',to:'#6d28d9'},
    comparacion:          {label:'Comparación',icon:'⚖️',from:'#8b5cf6',to:'#ec4899'},
    anova:                {label:'ANOVA',icon:'📊',from:'#f59e0b',to:'#ef4444'},
    ancova:               {label:'ANCOVA',icon:'🔬',from:'#f97316',to:'#dc2626'},
    discriminante:        {label:'Discriminante',icon:'🧩',from:'#14b8a6',to:'#0891b2'},
    logistica:            {label:'Reg. logística',icon:'🎯',from:'#ec4899',to:'#f43f5e'},
    chi_cuadrado:         {label:'Chi-cuadrado',icon:'📋',from:'#f97316',to:'#dc2626'},
    cluster:              {label:'Análisis clúster',icon:'🔵',from:'#6366f1',to:'#4f46e5'},
    instrumentos:         {label:'Validar instrumento',icon:'🔬',from:'#14b8a6',to:'#0891b2'},
    cronbach:             {label:'Alfa de Cronbach',icon:'🛡️',from:'#3b82f6',to:'#1d4ed8'},
    descriptivos:         {label:'Descriptivos completos',icon:'📑',from:'#10b981',to:'#065f46'},
    descriptivo:          {label:'Análisis Descriptivo',icon:'📑',from:'#10b981',to:'#065f46'},
    frecuencias:          {label:'Frecuencias',icon:'📊',from:'#f59e0b',to:'#92400e'},
    baremos:              {label:'Baremos',icon:'📏',from:'#84cc16',to:'#3f6212'},
  };
  const currentMethod = methodLabels[effectiveCat] || methodLabels[cat] || methodLabels['correlacional'];

  return (
    <div className="space-y-8 animate-slide-up">
      {/* Page Header */}
      {hideMethodSelector ? (
        <div className="rounded-3xl p-6 text-white relative overflow-hidden" style={{background:`linear-gradient(135deg, ${currentMethod.from}, ${currentMethod.to})`}}>
          <div className="absolute top-0 right-0 text-9xl opacity-10 -translate-y-4 translate-x-4 pointer-events-none">{currentMethod.icon}</div>
          <div className="relative z-10">
            <p className="text-white/70 text-sm font-semibold uppercase tracking-widest mb-2">Paso 3 de 6 — Configurar</p>
            <div className="flex items-center gap-3 mb-1">
              <span className="text-4xl">{currentMethod.icon}</span>
              <h1 className="text-4xl font-black">{currentMethod.label}</h1>
            </div>
            <p className="text-white/70 text-base mt-1">Selecciona tus variables y configura los parámetros del análisis</p>
          </div>
        </div>
      ) : (
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Configura tu análisis</h1>
          <p className="text-slate-500 mt-2 text-lg">Selecciona el tipo de análisis que necesitas</p>
        </div>
      )}

      {/* ═══ SELECTOR VISUAL DE MÉTODOS ═══ */}
      {!hideMethodSelector && <div>
        <h2 className="text-2xl font-black text-slate-900 mb-1">¿Qué quieres analizar hoy?</h2>
        <p className="text-slate-500 mb-6">Selecciona el método — luego configuras los detalles</p>

        {/* FASE 1: Validar instrumento */}
        <div className="mb-5">
          <p className="text-xs font-black text-slate-400 uppercase tracking-widest mb-3">Fase 1 — Validación del instrumento</p>
          <button type="button"
            onClick={() => updateConfig({ analysisCategory: 'instrumentos' })}
            className={`w-full rounded-2xl border-2 p-5 text-left transition-all hover:scale-[1.01] ${
              mode==='piloto' ? 'border-cyan-500 bg-gradient-to-r from-cyan-500 to-teal-500 shadow-lg shadow-cyan-200' : 'border-slate-200 bg-white hover:border-cyan-300 hover:shadow-md'
            }`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className={`w-14 h-14 rounded-2xl flex items-center justify-center text-3xl ${mode==='piloto'?'bg-white/20':'bg-cyan-50'}`}>🔬</div>
                <div>
                  <p className={`text-lg font-black ${mode==='piloto'?'text-white':'text-slate-800'}`}>Validar mi instrumento</p>
                  <p className={`text-sm ${mode==='piloto'?'text-cyan-100':'text-slate-500'}`}>AFE · AFC · KMO · Bartlett · Alpha · CR · AVE · HTMT · V de Aiken</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <span className={`text-xs font-bold px-3 py-1.5 rounded-full ${mode==='piloto'?'bg-white/20 text-white':'bg-cyan-100 text-cyan-700'}`}>30–100 participantes</span>
                {mode==='piloto' && <span className="text-xs font-black bg-white text-cyan-600 px-3 py-1.5 rounded-full">✓ Seleccionado</span>}
              </div>
            </div>
          </button>
        </div>

        {/* FASE 2: Análisis estadístico */}
        <div>
          <p className="text-xs font-black text-slate-400 uppercase tracking-widest mb-3">Fase 2 — Análisis estadístico final</p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {ANALYSIS_TYPES.map(t => {
              const gradients: Record<string,string> = {
                cyan:   'from-cyan-500 to-blue-600',
                indigo: 'from-indigo-500 to-purple-600',
                green:  'from-green-500 to-teal-600',
                purple: 'from-purple-500 to-pink-600',
                amber:  'from-amber-500 to-orange-600',
                pink:   'from-pink-500 to-rose-600',
                orange: 'from-orange-500 to-red-500',
                slate:  'from-slate-400 to-slate-500',
              };
              const isActive = cat === t.id;
              const grad = gradients[t.color]||'from-slate-400 to-slate-500';
              return (
                <button key={t.id} type="button" disabled={!t.available}
                  onClick={() => updateConfig({ analysisCategory: t.id as any })}
                  className={`relative rounded-2xl border-2 p-4 text-left transition-all ${
                    !t.available ? 'opacity-40 cursor-not-allowed border-slate-200 bg-slate-50' :
                    isActive ? `border-transparent bg-gradient-to-br ${grad} shadow-lg scale-[1.02]`
                    : 'border-slate-200 bg-white hover:border-slate-300 hover:shadow-md hover:scale-[1.01]'
                  }`}>
                  {t.badge && !isActive && (
                    <span className="absolute -top-2 -right-2 text-xs font-bold bg-white border border-slate-200 text-slate-600 px-2 py-0.5 rounded-full shadow-sm">{t.badge}</span>
                  )}
                  {isActive && (
                    <span className="absolute -top-2 -right-2 text-xs font-black bg-white text-green-600 px-2 py-0.5 rounded-full shadow-sm border border-green-200">✓ Seleccionado</span>
                  )}
                  <span className="text-3xl block mb-3">{t.icon}</span>
                  <p className={`font-black text-sm mb-1 ${isActive?'text-white':'text-slate-800'}`}>{t.label}</p>
                  <p className={`text-xs leading-relaxed ${isActive?'text-white/80':'text-slate-500'}`}>{t.desc}</p>
                  {!t.available && <span className="text-xs text-slate-400 font-semibold mt-1 block">Próximamente</span>}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      }
      {/* PLS-SEM config */}
      {effectiveCat === 'structural_model' && (
        <div className="space-y-6">
          <div className="card">
            <p className="text-sm font-bold text-slate-700 mb-4">Configuración PLS-SEM</p>

            {/* Constructos */}
            <div>
              <p className="text-xs font-bold text-cyan-600 uppercase tracking-widest mb-3">Constructos</p>
              <div className="space-y-3">
                {((cfg as any).plsConstructs ?? [{name:'',items:[]}]).map((con: any, i: number) => { const safeItems = Array.isArray(con.items) ? con.items : []; return (
                  <div key={i} className="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="w-7 h-7 rounded-lg bg-cyan-500 flex items-center justify-center text-xs font-bold text-white">{i+1}</div>
                      <input className="flex-1 input text-sm font-semibold" placeholder={`Nombre del constructo ${i+1}`} value={con.name}
                        onChange={e => { try { const l=JSON.parse(JSON.stringify((cfg as any).plsConstructs ?? [{name:'',items:[]}])); l[i]={...l[i],name:e.target.value}; updateConfig({plsConstructs:l} as any); } catch(err) { console.error(err); } }} />
                      <button type="button" onClick={() => { const l=((cfg as any).plsConstructs??[]).filter((_:any,j:number)=>j!==i); updateConfig({plsConstructs:l} as any); }}
                        className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition"><Trash2 className="w-4 h-4"/></button>
                    </div>
                    <label className="label text-xs">Ítems del constructo</label>
                    <ItemChips columns={columns} selected={safeItems}
                      onChange={v => { const l=JSON.parse(JSON.stringify((cfg as any).plsConstructs??[])); l[i]={...l[i],items:v}; updateConfig({plsConstructs:l} as any); }}
                      color="indigo" />
                  </div>
                ); })}
              </div>
              <button type="button"
                onClick={() => { const l=JSON.parse(JSON.stringify((cfg as any).plsConstructs??[])); l.push({name:'',items:[]}); updateConfig({plsConstructs:l} as any); }}
                className="mt-3 w-full py-3 border-2 border-dashed border-cyan-300 rounded-2xl text-cyan-600 hover:border-cyan-400 hover:bg-cyan-50/50 transition-all font-semibold flex items-center justify-center gap-2 text-sm">
                <Plus className="w-4 h-4"/> Agregar constructo
              </button>
            </div>

            {/* Rutas estructurales */}
            <div className="mt-6">
              <p className="text-xs font-bold text-cyan-600 uppercase tracking-widest mb-3">Rutas estructurales (→)</p>
              <div className="space-y-2">
                {((cfg as any).plsPaths ?? [{from:'',to:''}]).map((path: any, i: number) => (
                  <div key={i} className="flex items-center gap-3 bg-white rounded-xl border border-slate-200 p-3">
                    <select className="input text-sm flex-1" value={path.from}
                      onChange={e => { const l=[...((cfg as any).plsPaths??[])]; l[i]={...l[i],from:e.target.value}; updateConfig({plsPaths:l} as any); }}>
                      <option value="">Constructo origen</option>
                      {((cfg as any).plsConstructs??[]).map((c:any)=>c.name&&<option key={c.name} value={c.name}>{c.name}</option>)}
                    </select>
                    <span className="text-cyan-600 font-bold text-lg">→</span>
                    <select className="input text-sm flex-1" value={path.to}
                      onChange={e => { const l=[...((cfg as any).plsPaths??[])]; l[i]={...l[i],to:e.target.value}; updateConfig({plsPaths:l} as any); }}>
                      <option value="">Constructo destino</option>
                      {((cfg as any).plsConstructs??[]).map((c:any)=>c.name&&<option key={c.name} value={c.name}>{c.name}</option>)}
                    </select>
                    <button type="button" onClick={() => { const l=((cfg as any).plsPaths??[]).filter((_:any,j:number)=>j!==i); updateConfig({plsPaths:l} as any); }}
                      className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition"><Trash2 className="w-4 h-4"/></button>
                  </div>
                ))}
              </div>
              <button type="button"
                onClick={() => { const l=[...((cfg as any).plsPaths??[]),{from:'',to:''}]; updateConfig({plsPaths:l} as any); }}
                className="mt-3 w-full py-3 border-2 border-dashed border-cyan-300 rounded-2xl text-cyan-600 hover:border-cyan-400 hover:bg-cyan-50/50 transition-all font-semibold flex items-center justify-center gap-2 text-sm">
                <Plus className="w-4 h-4"/> Agregar ruta
              </button>
            </div>

            {/* Bootstrap */}
            <div className="grid grid-cols-2 gap-4 mt-6">
              <div>
                <label className="label">Iteraciones bootstrap</label>
                <select className="input" value={(cfg as any).nBoot ?? 5000} onChange={e => updateConfig({ nBoot: parseInt(e.target.value) } as any)}>
                  <option value={500}>500 (rápido — pruebas)</option>
                  <option value={1000}>1000</option>
                  <option value={5000}>5000 (estándar)</option>
                  <option value={10000}>10000 (alta precisión)</option>
                </select>
              </div>
              <div>
                <label className="label">Variable de grupo <span className="text-slate-400 font-normal">(opcional — para MICOM y MGA)</span></label>
                <select className="input" value={(cfg as any).groupVar ?? ''} onChange={e => updateConfig({ groupVar: e.target.value } as any)}>
                  <option value="">Sin análisis multigrupo</option>
                  {(columns??[]).map((col:any)=>{
                    const name = typeof col==='string'?col:col.name;
                    return <option key={name} value={name}>{name}</option>;
                  })}
                </select>
                {(cfg as any).groupVar && <p className="text-xs text-indigo-600 mt-1">✓ Se calculará MICOM + MGA para grupos en "{(cfg as any).groupVar}"</p>}
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4 mt-3">
              <div>
                <label className="label">Escala Likert mín. <span className="text-slate-400 font-normal">(para IPMA)</span></label>
                <select className="input" value={(cfg as any).scaleMin ?? 1} onChange={e => updateConfig({ scaleMin: parseInt(e.target.value) } as any)}>
                  <option value={1}>1</option>
                  <option value={0}>0</option>
                </select>
              </div>
              <div>
                <label className="label">Escala Likert máx. <span className="text-slate-400 font-normal">(para IPMA)</span></label>
                <select className="input" value={(cfg as any).scaleMax ?? 5} onChange={e => updateConfig({ scaleMax: parseInt(e.target.value) } as any)}>
                  <option value={5}>5</option>
                  <option value={7}>7</option>
                  <option value={10}>10</option>
                  <option value={4}>4</option>
                </select>
              </div>
            </div>
            <p className="text-xs text-cyan-700 bg-cyan-50 border border-cyan-200 rounded-xl px-4 py-3 mt-4">
              🔷 Se calculará: cargas factoriales, β, T-valor, p-valor, IC 95%, AVE, CR, Alpha de Cronbach y R² para cada constructo endógeno.
            </p>
          </div>
        </div>
      )}

      {/* STEP 3: UI específica por método */}
      {effectiveCat !== 'structural_model' && (
        <div className="space-y-4">

          {/* ── MÉTODOS CON VARIABLE A + VARIABLE B (correlacional, regresión, ordinal, logística) ── */}
          {(['correlacional','regresion','regresion_multiple','regresion_ordinal','regresion_multinomial','logistica'].includes(effectiveCat)) && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="card border-l-4 border-l-indigo-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">A</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Variable independiente (X)</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Calidad de servicio" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems de {cfg.varAName || 'Variable A'}</label>
                <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
                <button type="button" onClick={() => setShowDimsA(!showDimsA)} className="flex items-center gap-2 text-sm font-semibold text-indigo-600 mt-4">
                  <div className={`w-5 h-5 rounded border-2 border-indigo-400 flex items-center justify-center ${showDimsA?'bg-indigo-500 border-indigo-500':''}`}>{showDimsA && <span className="text-white text-xs">✓</span>}</div>
                  ¿Tiene dimensiones?
                </button>
                {showDimsA && <DimEditor dimensions={cfg.varADimensions} columns={cfg.varAItems} onChange={v => updateConfig({ varADimensions: v })} color="indigo" />}
              </div>
              <div className="card border-l-4 border-l-teal-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-teal-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">B</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-teal-600 uppercase tracking-wider">{effectiveCat==='regresion_ordinal'?'Variable dependiente ordinal (Y)':'Variable dependiente (Y)'}</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Satisfacción del cliente" value={cfg.varBName} onChange={e => updateConfig({ varBName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems de {cfg.varBName || 'Variable B'}</label>
                <ItemChips columns={columns} selected={cfg.varBItems} onChange={v => updateConfig({ varBItems: v })} color="teal" />
                <button type="button" onClick={() => setShowDimsB(!showDimsB)} className="flex items-center gap-2 text-sm font-semibold text-teal-600 mt-4">
                  <div className={`w-5 h-5 rounded border-2 border-teal-400 flex items-center justify-center ${showDimsB?'bg-teal-500 border-teal-500':''}`}>{showDimsB && <span className="text-white text-xs">✓</span>}</div>
                  ¿Tiene dimensiones?
                </button>
                {showDimsB && <DimEditor dimensions={cfg.varBDimensions} columns={cfg.varBItems} onChange={v => updateConfig({ varBDimensions: v })} color="teal" />}
              </div>
            </div>
          )}
          {/* ── PREDICTORES ADICIONALES: Regresion multiple / multinomial (2+ predictores) ── */}
          {((['regresion_multiple','regresion_multinomial','regresion_ordinal'].includes(effectiveCat)) || (effectiveCat === 'logistica' && (cfg as any).logisticType !== 'multinomial')) && (
            <div className="card border-l-4 border-l-amber-500">
              <div className="flex items-center justify-between mb-4">
                <p className="text-xs font-bold text-amber-600 uppercase tracking-widest">Predictores adicionales (X2, X3...)</p>
                <button type="button"
                  onClick={() => updateConfig({ extraPredictors: [...cfg.extraPredictors, { name: '', items: [], dimensions: [] }] })}
                  className="text-xs font-bold text-amber-600 bg-amber-50 hover:bg-amber-100 px-3 py-1.5 rounded-lg transition-colors">
                  + Agregar predictor
                </button>
              </div>
              {cfg.extraPredictors.length === 0 && (
                <p className="text-sm text-slate-400">Variable independiente (X) ya cuenta como el primer predictor. Agrega aqui los predictores adicionales (X2, X3...).</p>
              )}
              {cfg.extraPredictors.map((pred, idx) => (
                <div key={idx} className="mt-4 pt-4 border-t border-slate-200">
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-8 h-8 bg-amber-500 rounded-lg flex items-center justify-center flex-shrink-0">
                      <span className="text-white font-black text-sm">X{idx + 2}</span>
                    </div>
                    <input className="flex-1 text-lg font-bold text-slate-900 bg-transparent border-none outline-none placeholder-slate-300"
                      placeholder={`Ej: Predictor ${idx + 2}`} value={pred.name}
                      onChange={e => {
                        const next = [...cfg.extraPredictors];
                        next[idx] = { ...next[idx], name: e.target.value };
                        updateConfig({ extraPredictors: next });
                      }} />
                    <button type="button" onClick={() => {
                      const next = cfg.extraPredictors.filter((_, i) => i !== idx);
                      updateConfig({ extraPredictors: next });
                    }} className="text-rose-500 hover:text-rose-700 text-sm font-bold px-2">✕</button>
                  </div>
                  <label className="label">Ítems de {pred.name || `Predictor ${idx + 2}`}</label>
                  <ItemChips columns={columns} selected={pred.items} onChange={v => {
                    const next = [...cfg.extraPredictors];
                    next[idx] = { ...next[idx], items: v };
                    updateConfig({ extraPredictors: next });
                  }} color="amber" />
                </div>
              ))}
            </div>
          )}


          {/* ── REGRESIÓN JERÁRQUICA: VD + Bloques de VI ── */}
          {effectiveCat === 'regresion_jerarquica' && (
            <div className="space-y-4">
              <div className="card border-l-4 border-l-teal-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-teal-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">Y</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-teal-600 uppercase tracking-wider">Variable dependiente (criterio)</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Rendimiento laboral" value={cfg.varBName} onChange={e => updateConfig({ varBName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems de {cfg.varBName || 'Variable Y'}</label>
                <ItemChips columns={columns} selected={cfg.varBItems} onChange={v => updateConfig({ varBItems: v })} color="teal" />
              </div>
              <div className="card">
                <p className="text-xs font-bold text-purple-600 uppercase tracking-widest mb-3">Bloques de predictores (X)</p>
                <div className="space-y-3">
                  {((cfg as any).hierBlocks ?? [{name:'Bloque 1',items:[]}]).map((blk: any, i: number) => (
                    <div key={i} className="bg-purple-50 border border-purple-200 rounded-2xl p-4">
                      <div className="flex items-center gap-3 mb-3">
                        <div className="w-7 h-7 rounded-lg bg-purple-500 flex items-center justify-center text-xs font-bold text-white">{i+1}</div>
                        <input className="flex-1 input text-sm font-semibold" placeholder={"Nombre bloque "+(i+1)} value={blk.name}
                          onChange={e => { const l=JSON.parse(JSON.stringify((cfg as any).hierBlocks??[])); l[i]={...l[i],name:e.target.value}; updateConfig({hierBlocks:l} as any); }} />
                        {i>0 && <button type="button" onClick={() => { const l=((cfg as any).hierBlocks??[]).filter((_:any,j:number)=>j!==i); updateConfig({hierBlocks:l} as any); }} className="p-2 text-red-400 hover:text-red-600"><Trash2 className="w-4 h-4"/></button>}
                      </div>
                      <label className="label text-xs">Variables predictoras del bloque {i+1}</label>
                      <ItemChips columns={columns} selected={blk.items??[]}
                        onChange={v => { const l=JSON.parse(JSON.stringify((cfg as any).hierBlocks??[])); l[i]={...l[i],items:v}; updateConfig({hierBlocks:l} as any); }}
                        color="indigo" />
                    </div>
                  ))}
                </div>
                <button type="button"
                  onClick={() => { const l=JSON.parse(JSON.stringify((cfg as any).hierBlocks??[])); l.push({name:'Bloque '+(l.length+1),items:[]}); updateConfig({hierBlocks:l} as any); }}
                  className="mt-3 w-full py-3 border-2 border-dashed border-purple-300 rounded-2xl text-purple-600 hover:border-purple-400 hover:bg-purple-50 transition font-semibold flex items-center justify-center gap-2 text-sm">
                  <Plus className="w-4 h-4"/> Agregar bloque
                </button>
              </div>
            </div>
          )}

          {/* ── COMPARACIÓN: VD + Variable de grupo + Valores ── */}
          {effectiveCat === 'comparacion' && (
            <div className="space-y-4">
              <div className="card border-l-4 border-l-purple-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-purple-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">Y</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-purple-600 uppercase tracking-wider">Variable a comparar</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Satisfaccion laboral" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems de {cfg.varAName || 'Variable'}</label>
                <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
                <button type="button" onClick={() => setShowDimsA(!showDimsA)} className="flex items-center gap-2 text-sm font-semibold text-purple-600 mt-4">
                  <div className={`w-5 h-5 rounded border-2 border-purple-400 flex items-center justify-center ${showDimsA?'bg-purple-500 border-purple-500':''}`}>{showDimsA && <span className="text-white text-xs">✓</span>}</div>
                  ¿Tiene dimensiones?
                </button>
                {showDimsA && <DimEditor dimensions={cfg.varADimensions} columns={cfg.varAItems} onChange={v => updateConfig({ varADimensions: v })} color="indigo" />}
              </div>
              <div className="card">
                <p className="text-xs font-bold text-purple-600 uppercase tracking-widest mb-4">Grupos a comparar</p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div>
                    <label className="label">Columna de agrupación</label>
                    <select className="input" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value, groupValues: ['',''] })}>
                      <option value="">-- Seleccionar columna --</option>
                      {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="label">Valor Grupo 1</label>
                    <input className="input" placeholder="Ej: Masculino o 1" value={cfg.groupValues?.[0]??''} onChange={e => updateConfig({ groupValues: [e.target.value, cfg.groupValues?.[1]??''] })} />
                  </div>
                  <div>
                    <label className="label">Valor Grupo 2</label>
                    <input className="input" placeholder="Ej: Femenino o 2" value={cfg.groupValues?.[1]??''} onChange={e => updateConfig({ groupValues: [cfg.groupValues?.[0]??'', e.target.value] })} />
                  </div>
                </div>
                <div className="mt-4">
                  <label className="label">Tipo de comparación</label>
                  <div className="grid grid-cols-3 gap-3 mt-2">
                    {[{id:'independiente',label:'Grupos independientes',desc:'Dos grupos distintos'},{id:'pareada',label:'Muestras relacionadas',desc:'Pre-test / Post-test'},{id:'auto',label:'Automatico',desc:'El sistema elige'}].map(t => (
                      <button key={t.id} type="button" onClick={() => updateConfig({ comparisonType: t.id as any })}
                        className={`rounded-2xl border-2 p-3 text-left ${cfg.comparisonType===t.id?'border-purple-400 bg-purple-50':'border-slate-200 bg-white'}`}>
                        <p className={`font-bold text-sm ${cfg.comparisonType===t.id?'text-purple-700':'text-slate-800'}`}>{t.label}</p>
                        <p className="text-xs text-slate-500 mt-1">{t.desc}</p>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ── ANOVA: VD + Variable de grupo (3+ niveles) ── */}
          {effectiveCat === 'anova' && (
            <div className="space-y-4">
              <div className="card border-l-4 border-l-amber-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-amber-500 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">Y</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-amber-600 uppercase tracking-wider">Variable dependiente</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Rendimiento academico" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems de {cfg.varAName || 'Variable'}</label>
                <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
                <button type="button" onClick={() => setShowDimsA(!showDimsA)} className="flex items-center gap-2 text-sm font-semibold text-amber-600 mt-4">
                  <div className={`w-5 h-5 rounded border-2 border-amber-400 flex items-center justify-center ${showDimsA?'bg-amber-500 border-amber-500':''}`}>{showDimsA && <span className="text-white text-xs">✓</span>}</div>
                  ¿Tiene dimensiones?
                </button>
                {showDimsA && <DimEditor dimensions={cfg.varADimensions} columns={cfg.varAItems} onChange={v => updateConfig({ varADimensions: v })} color="indigo" />}
              </div>
              <div className="card">
                <p className="text-xs font-bold text-amber-600 uppercase tracking-widest mb-4">Variable de agrupación (3 o más grupos)</p>
                <select className="input max-w-md" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value })}>
                  <option value="">-- Seleccionar columna de grupo --</option>
                  {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                </select>
                {cfg.groupVar && <p className="text-xs text-amber-600 mt-2">✓ Se compararán todos los grupos en la columna "{cfg.groupVar}" automáticamente</p>}
              </div>
            </div>
          )}

          {/* ── ANCOVA: VD + Covariable + Grupo ── */}
          {effectiveCat === 'ancova' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div className="card border-l-4 border-l-orange-500">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 bg-orange-500 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">Y</span></div>
                    <div className="flex-1">
                      <p className="text-xs font-bold text-orange-600 uppercase tracking-wider">Variable dependiente</p>
                      <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Rendimiento" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                    </div>
                  </div>
                  <label className="label">Ítems</label>
                  <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
                </div>
                <div className="card border-l-4 border-l-blue-500">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 bg-blue-500 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">C</span></div>
                    <div className="flex-1">
                      <p className="text-xs font-bold text-blue-600 uppercase tracking-wider">Covariable (variable de control)</p>
                      <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Pretest, Edad" value={cfg.varBName} onChange={e => updateConfig({ varBName: e.target.value })} />
                    </div>
                  </div>
                  <label className="label">Ítems de la covariable</label>
                  <ItemChips columns={columns} selected={cfg.varBItems} onChange={v => updateConfig({ varBItems: v })} color="teal" />
                </div>
              </div>
              <div className="card">
                <p className="text-xs font-bold text-orange-600 uppercase tracking-widest mb-3">Variable de grupo</p>
                <select className="input max-w-md" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value })}>
                  <option value="">-- Seleccionar columna --</option>
                  {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                </select>
              </div>
            </div>
          )}

          {/* ── DISCRIMINANTE: Predictores + Grupo ── */}
          {effectiveCat === 'discriminante' && (
            <div className="space-y-4">
              <div className="card border-l-4 border-l-teal-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-teal-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">X</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-teal-600 uppercase tracking-wider">Variables predictoras (discriminantes)</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Habilidades cognitivas" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Ítems predictores</label>
                <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
              </div>
              <div className="card">
                <p className="text-xs font-bold text-teal-600 uppercase tracking-widest mb-3">Variable de clasificación (grupos)</p>
                <select className="input max-w-md" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value })}>
                  <option value="">-- Seleccionar columna de grupos --</option>
                  {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                </select>
                {cfg.groupVar && <p className="text-xs text-teal-600 mt-2">✓ Se clasificarán los grupos en "{cfg.groupVar}"</p>}
              </div>
            </div>
          )}

          {/* ── CHI-CUADRADO: Variable 1 + Variable 2 ── */}
          {effectiveCat === 'chi_cuadrado' && (
            <div className="space-y-4">
              {/* Tipo de variable */}
              <div className="card">
                <p className="text-xs font-bold text-orange-600 uppercase tracking-widest mb-3">Tipo de variables</p>
                <div className="grid grid-cols-2 gap-3">
                  {[{id:'categorica',label:'Variables categóricas',desc:'Columnas con categorías directas (Sexo, Área, etc.)'},{id:'likert',label:'Ítems Likert categorizados',desc:'Ítems numéricos → se categorizan en Bajo/Medio/Alto'}].map(t=>(
                    <button key={t.id} type="button" onClick={() => updateConfig({ chiVarType: t.id } as any)}
                      className={`rounded-2xl border-2 p-4 text-left ${((cfg as any).chiVarType??'categorica')===t.id?'border-orange-400 bg-orange-50':'border-slate-200 bg-white hover:border-orange-200'}`}>
                      <p className={`font-bold text-sm ${((cfg as any).chiVarType??'categorica')===t.id?'text-orange-700':'text-slate-800'}`}>{t.label}</p>
                      <p className="text-xs text-slate-500 mt-1">{t.desc}</p>
                    </button>
                  ))}
                </div>
              </div>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div className="card border-l-4 border-l-orange-500">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 bg-orange-500 rounded-xl flex items-center justify-center"><span className="text-white font-black">V1</span></div>
                    <div className="flex-1">
                      <p className="text-xs font-bold text-orange-600 uppercase tracking-wider">Variable 1</p>
                      <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Calidad de servicio" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                    </div>
                  </div>
                  {((cfg as any).chiVarType??'categorica')==='categorica' ? (
                    <>
                      <label className="label">Selecciona la columna categórica</label>
                      <select className="input" value={cfg.varAItems[0]??''} onChange={e => updateConfig({ varAItems: e.target.value ? [e.target.value] : [] })}>
                        <option value="">-- Seleccionar columna --</option>
                        {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                      </select>
                    </>
                  ) : (
                    <>
                      <label className="label">Selecciona los ítems (se categorizarán automáticamente)</label>
                      <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
                    </>
                  )}
                </div>
                <div className="card border-l-4 border-l-red-500">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 bg-red-500 rounded-xl flex items-center justify-center"><span className="text-white font-black">V2</span></div>
                    <div className="flex-1">
                      <p className="text-xs font-bold text-red-600 uppercase tracking-wider">Variable 2</p>
                      <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Satisfacción" value={cfg.varBName} onChange={e => updateConfig({ varBName: e.target.value })} />
                    </div>
                  </div>
                  {((cfg as any).chiVarType??'categorica')==='categorica' ? (
                    <>
                      <label className="label">Selecciona la columna categórica</label>
                      <select className="input" value={cfg.varBItems[0]??''} onChange={e => updateConfig({ varBItems: e.target.value ? [e.target.value] : [] })}>
                        <option value="">-- Seleccionar columna --</option>
                        {columns.map((col:string) => <option key={col} value={col}>{col}</option>)}
                      </select>
                    </>
                  ) : (
                    <>
                      <label className="label">Selecciona los ítems (se categorizarán automáticamente)</label>
                      <ItemChips columns={columns} selected={cfg.varBItems} onChange={v => updateConfig({ varBItems: v })} color="teal" />
                    </>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ── CLUSTER: Variables múltiples + N clusters ── */}
          {effectiveCat === 'cluster' && (
            <div className="space-y-4">
              <div className="card border-l-4 border-l-indigo-500">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">X</span></div>
                  <div className="flex-1">
                    <p className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Variables para agrupación</p>
                    <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Perfil del estudiante" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                  </div>
                </div>
                <label className="label">Selecciona los ítems/variables</label>
                <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
              </div>
              <div className="card">
                <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-3">Número de clústeres</p>
                <div className="flex gap-3">
                  {[2,3,4,5].map(n => (
                    <button key={n} type="button" onClick={() => updateConfig({ nClusters: n } as any)}
                      className={`w-14 h-14 rounded-2xl border-2 font-black text-xl transition ${((cfg as any).nClusters??3)===n?'border-indigo-500 bg-indigo-50 text-indigo-700':'border-slate-200 text-slate-600 hover:border-indigo-300'}`}>{n}</button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ── UNA SOLA VARIABLE: cronbach, frecuencias, baremos, descriptivos ── */}
          {(['cronbach','descriptivo'].includes(effectiveCat)) && (
            <div className="card border-l-4 border-l-indigo-500 max-w-2xl">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">A</span></div>
                <div className="flex-1">
                  <p className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Variable / Instrumento</p>
                  <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Clima organizacional" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                </div>
              </div>
              <label className="label">Ítems de {cfg.varAName || 'la variable'}</label>
              <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
            </div>
          )}

          {/* ── INSTRUMENTOS ── */}
          {effectiveCat === 'instrumentos' && (
            <div className="card border-l-4 border-l-cyan-500">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 bg-cyan-600 rounded-xl flex items-center justify-center"><span className="text-white font-black text-lg">A</span></div>
                <div className="flex-1">
                  <p className="text-xs font-bold text-cyan-600 uppercase tracking-wider">Variable independiente</p>
                  <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full placeholder-slate-300" placeholder="Ej: Calidad de servicio" value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
                </div>
              </div>
              <label className="label">Ítems</label>
              <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
              <button type="button" onClick={() => setShowDimsA(!showDimsA)} className="flex items-center gap-2 text-sm font-semibold text-cyan-600 mt-4">
                <div className={`w-5 h-5 rounded border-2 border-cyan-400 flex items-center justify-center ${showDimsA?'bg-cyan-500 border-cyan-500':''}`}>{showDimsA && <span className="text-white text-xs">✓</span>}</div>
                ¿Tiene dimensiones?
              </button>
              {showDimsA && <DimEditor dimensions={cfg.varADimensions} columns={cfg.varAItems} onChange={v => updateConfig({ varADimensions: v })} color="indigo" />}
            </div>
          )}
          {effectiveCat === 'instrumentos' && (
            <div className="card">
              <p className="text-xs font-bold text-cyan-600 uppercase tracking-widest mb-4">Parametros de validacion psicometrica</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Numero de factores (AFE)</label>
                  <select className="input" value={(cfg as any).nFactors ?? 'auto'} onChange={e => updateConfig({ nFactors: e.target.value === 'auto' ? null : parseInt(e.target.value) } as any)}>
                    <option value="auto">Automatico (analisis paralelo)</option>
                    <option value="1">1 factor</option>
                    <option value="2">2 factores</option>
                    <option value="3">3 factores</option>
                    <option value="4">4 factores</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tipo de rotacion</label>
                  <select className="input" value={(cfg as any).rotation ?? 'oblimin'} onChange={e => updateConfig({ rotation: e.target.value } as any)}>
                    <option value="oblimin">Oblimin (oblicua - recomendada)</option>
                    <option value="varimax">Varimax (ortogonal)</option>
                    <option value="promax">Promax (oblicua)</option>
                    <option value="none">Sin rotacion</option>
                  </select>
                </div>
                <div>
                  <label className="label">Metodo de estimacion (CFA)</label>
                  <select className="input" value={(cfg as any).estimator ?? 'MLR'} onChange={e => updateConfig({ estimator: e.target.value } as any)}>
                    <option value="MLR">MLR (robusto - recomendado)</option>
                    <option value="ML">ML (maxima verosimilitud)</option>
                    <option value="WLSMV">WLSMV (datos categoricos)</option>
                  </select>
                </div>
              </div>
            </div>
          )}
          {effectiveCat === 'instrumentos' && (
            <div className="card">
              <button type="button" onClick={() => updateConfig({ enableVAiken: !(cfg as any).enableVAiken } as any)} className="flex items-center gap-2 text-sm font-bold text-cyan-700 uppercase tracking-wider">
                <div className={`w-5 h-5 rounded border-2 border-cyan-400 flex items-center justify-center ${(cfg as any).enableVAiken?'bg-cyan-500 border-cyan-500':''}`}>{(cfg as any).enableVAiken && <span className="text-white text-xs">check</span>}</div>
                Incluir validez de contenido - V de Aiken (opcional)
              </button>
              <p className="text-xs text-slate-500 mt-2">Activa esto si tienes calificaciones de jueces/expertos sobre la pertinencia de cada item.</p>
              {(cfg as any).enableVAiken && (
                <div className="mt-4">
                  <div className="grid grid-cols-3 gap-4 mb-4">
                    <div>
                      <label className="label">Numero de jueces</label>
                      <input type="number" min={2} max={15} className="input" value={(cfg as any).vAikenJudges ?? 5} onChange={e => updateConfig({ vAikenJudges: parseInt(e.target.value) || 5 } as any)} />
                    </div>
                    <div>
                      <label className="label">Escala minima</label>
                      <input type="number" className="input" value={(cfg as any).vAikenScaleMin ?? 1} onChange={e => updateConfig({ vAikenScaleMin: parseInt(e.target.value) } as any)} />
                    </div>
                    <div>
                      <label className="label">Escala maxima</label>
                      <input type="number" className="input" value={(cfg as any).vAikenScaleMax ?? 4} onChange={e => updateConfig({ vAikenScaleMax: parseInt(e.target.value) } as any)} />
                    </div>
                  </div>
                  <label className="label">Calificaciones por item (filas) y juez (columnas)</label>
                  <div className="overflow-x-auto">
                    <table className="text-sm border-collapse">
                      <thead>
                        <tr>
                          <th className="p-2 text-left text-xs text-slate-500">Item</th>
                          {Array.from({length: (cfg as any).vAikenJudges ?? 5}).map((_,j) => (
                            <th key={j} className="p-2 text-xs text-slate-500">{`J${j+1}`}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {(cfg.varAItems ?? []).map((item) => (
                          <tr key={item}>
                            <td className="p-2 font-semibold text-slate-700">{item}</td>
                            {Array.from({length: (cfg as any).vAikenJudges ?? 5}).map((_,j) => {
                              const matrix = (cfg as any).vAikenMatrix ?? {};
                              const val = matrix[item] && matrix[item][j] != null ? matrix[item][j] : '';
                              return (
                                <td key={j} className="p-1">
                                  <input type="number" className="input w-14 text-center" value={val} onChange={e => {
                                    const matrix2 = { ...((cfg as any).vAikenMatrix ?? {}) };
                                    if (!matrix2[item]) matrix2[item] = [];
                                    matrix2[item] = [...matrix2[item]];
                                    matrix2[item][j] = e.target.value === '' ? null : parseFloat(e.target.value);
                                    updateConfig({ vAikenMatrix: matrix2 } as any);
                                  }} />
                                </td>
                              );
                            })}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  {(!cfg.varAItems || cfg.varAItems.length===0) && <p className="text-xs text-amber-600 mt-2">Selecciona primero los items de la variable arriba para ingresar las calificaciones de los jueces.</p>}
                </div>
              )}
            </div>
          )}

        </div>
      )}

      {/* Tipos de correlacion - solo si hay dimensiones */}
      {effectiveCat === 'correlacional' && (cfg.varADimensions?.length > 0 || cfg.varBDimensions?.length > 0) && (
        <div className="card">
          <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-4">Paso 3 — Tipos de correlación a calcular</p>
          <p className="text-sm text-slate-500 mb-4">Selecciona qué correlaciones deseas calcular entre variables y dimensiones</p>
          <div className="grid grid-cols-2 gap-3">
            {[
              { id:'vv',  label:`${cfg.varAName} × ${cfg.varBName}`, desc:'Correlación general (objetivo general)', icon:'🎯', always:true },
              { id:'vdA', label:`Dimensiones de ${cfg.varAName} × ${cfg.varBName}`, desc:'Objetivos específicos por dimensión de A', icon:'📐', show: cfg.varADimensions?.length > 0 },
              { id:'vdB', label:`${cfg.varAName} × Dimensiones de ${cfg.varBName}`, desc:'Objetivos específicos por dimensión de B', icon:'📏', show: cfg.varBDimensions?.length > 0 },
              { id:'dd',  label:'Dimensiones A × Dimensiones B', desc:'Correlaciones entre todas las dimensiones', icon:'🔀', show: cfg.varADimensions?.length > 0 && cfg.varBDimensions?.length > 0 },
            ].filter(t => t.always || t.show).map(t => {
              const selected = cfg.analysisTypes?.includes(t.id as any) ?? false;
              return (
                <button key={t.id} type="button"
                  disabled={t.always}
                  onClick={() => {
                    if (t.always) return;
                    const current = cfg.analysisTypes ?? ['vv'];
                    const next = selected ? current.filter(x => x !== t.id) : [...current, t.id];
                    updateConfig({ analysisTypes: next as any });
                  }}
                  className={`rounded-2xl border-2 p-4 text-left transition-all ${
                    selected || t.always ? 'border-indigo-400 bg-indigo-50' : 'border-slate-200 bg-white hover:border-slate-300'
                  } ${t.always ? 'cursor-default' : 'cursor-pointer'}`}>
                  <div className="flex items-center gap-3 mb-2">
                    <span className="text-2xl">{t.icon}</span>
                    <div className={`w-5 h-5 rounded border-2 flex items-center justify-center ${selected || t.always ? 'bg-indigo-500 border-indigo-500' : 'border-slate-300'}`}>
                      {(selected || t.always) && <span className="text-white text-xs font-bold">✓</span>}
                    </div>
                  </div>
                  <p className={`font-semibold text-sm mb-1 ${selected || t.always ? 'text-indigo-700' : 'text-slate-800'}`}>{t.label}</p>
                  <p className="text-xs text-slate-500">{t.desc}</p>
                  {t.always && <p className="text-xs text-indigo-400 font-semibold mt-1">Siempre incluido</p>}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* STEP 4: Parámetros estadísticos específicos por método */}
      {effectiveCat !== 'structural_model' && (
        <div className="space-y-4">
          {/* Objetivo e hipotesis - conecta el resultado con lo que el usuario quiere responder */}
          <div className="card border-l-4 border-l-indigo-500 bg-indigo-50/30">
            <p className="text-xs font-bold text-indigo-700 uppercase tracking-widest mb-1">Objetivo de tu análisis (opcional, pero recomendado)</p>
            <p className="text-xs text-slate-500 mb-3">Si escribes tu objetivo y/o hipótesis, CanchariOS te mostrará exactamente qué resultado lo responde, tanto en pantalla como en el Word.</p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="label">Objetivo (ej: Determinar la relación entre X y Y)</label>
                <textarea className="input" rows={2} value={(cfg as any).objective ?? ''} onChange={e => updateConfig({ objective: e.target.value } as any)} placeholder="Determinar la relación entre..." />
              </div>
              <div>
                <label className="label">Hipótesis de investigación (H1)</label>
                <textarea className="input" rows={2} value={(cfg as any).hypothesisH1 ?? ''} onChange={e => updateConfig({ hypothesisH1: e.target.value } as any)} placeholder="Existe una relación significativa entre..." />
              </div>
            </div>
          </div>

          {/* Parámetros comunes — alpha y escala */}
          {!['instrumentos'].includes(effectiveCat) && (
            <div className="card">
              <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-4">Parámetros generales</p>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <label className="label">Nivel de significancia (α)</label>
                  <select className="input" value={cfg.alpha} onChange={e => updateConfig({ alpha: parseFloat(e.target.value) })}>
                    <option value={0.05}>0.05 (estándar)</option>
                    <option value={0.01}>0.01 (estricto)</option>
                    <option value={0.10}>0.10 (exploratorio)</option>
                  </select>
                </div>
                {!['cronbach','descriptivo','cluster','discriminante','ancova','anova','comparacion','chi_cuadrado'].includes(effectiveCat) && <>
                  <div>
                    <label className="label">Escala mínima</label>
                    <input type="number" className="input" value={cfg.scale?.min ?? 1} onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
                  </div>
                  <div>
                    <label className="label">Escala máxima</label>
                    <input type="number" className="input" value={cfg.scale?.max ?? 5} onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
                  </div>
                </>}
              </div>
            </div>
          )}

          {/* CORRELACIONAL — hipótesis, método, potencia */}
          {effectiveCat === 'correlacional' && (
            <div className="card">
              <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-4">Parámetros de correlación</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Método de correlación</label>
                  <select className="input" value={cfg.methodForce} onChange={e => updateConfig({ methodForce: e.target.value as any })}>
                    <option value="auto">Automático (según normalidad SW)</option>
                    <option value="pearson">Pearson (r) — distribución normal</option>
                    <option value="spearman">Spearman (ρ) — no paramétrico</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tipo de hipótesis</label>
                  <select className="input" value={(cfg as any).hypothesisType ?? 'bilateral'} onChange={e => updateConfig({ hypothesisType: e.target.value } as any)}>
                    <option value="bilateral">Bilateral (dos colas)</option>
                    <option value="unilateral_pos">Unilateral positiva (cola derecha)</option>
                    <option value="unilateral_neg">Unilateral negativa (cola izquierda)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Nivel de confianza</label>
                  <select className="input" value={(cfg as any).confidenceLevel ?? 0.95} onChange={e => updateConfig({ confidenceLevel: parseFloat(e.target.value) } as any)}>
                    <option value={0.95}>95% (estándar)</option>
                    <option value={0.99}>99% (estricto)</option>
                    <option value={0.90}>90% (exploratorio)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Escala mínima (baremos)</label>
                  <input type="number" className="input" value={cfg.scale?.min ?? 1} onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
                </div>
                <div>
                  <label className="label">Escala máxima (baremos)</label>
                  <input type="number" className="input" value={cfg.scale?.max ?? 5} onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
                </div>
                <div>
                  <label className="label">Corrección para múltiples correlaciones</label>
                  <select className="input" value={(cfg as any).multipleCorrection ?? 'none'} onChange={e => updateConfig({ multipleCorrection: e.target.value } as any)}>
                    <option value="none">Sin corrección</option>
                    <option value="bonferroni">Bonferroni</option>
                    <option value="fdr">FDR (Benjamini-Hochberg)</option>
                  </select>
                </div>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-100">
                <label className="label">Niveles de baremo</label>
                <div className="flex gap-3">
                  {(cfg.baremoLevels ?? ['Bajo','Medio','Alto']).map((lv, i) => (
                    <input key={i} className="input flex-1" value={lv} onChange={e => { const lvs=[...(cfg.baremoLevels??['Bajo','Medio','Alto'])]; lvs[i]=e.target.value; updateConfig({ baremoLevels: lvs as [string,string,string] }); }} />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* REGRESIÓN LINEAL — método entrada, supuestos */}
          {effectiveCat === 'regresion' && (
            <div className="card">
              <p className="text-xs font-bold text-green-600 uppercase tracking-widest mb-4">Parámetros de regresión lineal</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Método de entrada</label>
                  <select className="input" value={(cfg as any).regressionMethod ?? 'enter'} onChange={e => updateConfig({ regressionMethod: e.target.value } as any)}>
                    <option value="enter">Enter (simultáneo)</option>
                    <option value="stepwise">Stepwise (paso a paso)</option>
                    <option value="forward">Forward (hacia adelante)</option>
                    <option value="backward">Backward (hacia atrás)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Verificar supuestos</label>
                  <select className="input" value={(cfg as any).checkAssumptions ?? 'yes'} onChange={e => updateConfig({ checkAssumptions: e.target.value } as any)}>
                    <option value="yes">Sí — normalidad, homocedasticidad, DW, VIF</option>
                    <option value="no">No (solo coeficientes)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Criterio entrada/salida (Stepwise)</label>
                  <select className="input" value={(cfg as any).stepwiseCriteria ?? 'p05'} onChange={e => updateConfig({ stepwiseCriteria: e.target.value } as any)}>
                    <option value="p05">p entrada=.05, p salida=.10</option>
                    <option value="p01">p entrada=.01, p salida=.05</option>
                    <option value="aic">AIC mínimo</option>
                  </select>
                </div>
                <div>
                  <label className="label">Intervalo de confianza coeficientes</label>
                  <select className="input" value={(cfg as any).coefCI ?? 0.95} onChange={e => updateConfig({ coefCI: parseFloat(e.target.value) } as any)}>
                    <option value={0.95}>95%</option>
                    <option value={0.99}>99%</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tratar outliers influyentes</label>
                  <select className="input" value={(cfg as any).handleOutliers ?? 'report'} onChange={e => updateConfig({ handleOutliers: e.target.value } as any)}>
                    <option value="report">Solo reportar (Cook)</option>
                    <option value="remove">Eliminar automáticamente</option>
                  </select>
                </div>
                <div>
                  <label className="label">Umbral VIF multicolinealidad</label>
                  <select className="input" value={(cfg as any).vifThreshold ?? 5} onChange={e => updateConfig({ vifThreshold: parseFloat(e.target.value) } as any)}>
                    <option value={3.3}>3.3 (estricto — PLS)</option>
                    <option value={5}>5 (estándar)</option>
                    <option value={10}>10 (tolerante)</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* REGRESIÓN ORDINAL */}
          {effectiveCat === 'regresion_ordinal' && (
            <div className="card">
              <p className="text-xs font-bold text-blue-600 uppercase tracking-widest mb-4">Parámetros de regresión ordinal</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Función de enlace</label>
                  <select className="input" value={(cfg as any).linkFunction ?? 'logit'} onChange={e => updateConfig({ linkFunction: e.target.value } as any)}>
                    <option value="logit">Logit (logística ordinal)</option>
                    <option value="probit">Probit (distribución normal)</option>
                    <option value="cloglog">Log-log complementario</option>
                  </select>
                </div>
                <div>
                  <label className="label">Categorización de VD</label>
                  <select className="input" value={(cfg as any).ordinalizacion ?? 'terciles'} onChange={e => updateConfig({ ordinalizacion: e.target.value } as any)}>
                    <option value="terciles">Terciles automáticos</option>
                    <option value="percentiles">Percentiles 25/75</option>
                    <option value="teorico">Corte teórico (media ± DE)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Pseudo R² a reportar</label>
                  <select className="input" value={(cfg as any).pseudoR2 ?? 'nagelkerke'} onChange={e => updateConfig({ pseudoR2: e.target.value } as any)}>
                    <option value="nagelkerke">Nagelkerke (más usado)</option>
                    <option value="cox_snell">Cox y Snell</option>
                    <option value="mcfadden">McFadden</option>
                    <option value="all">Todos</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* REGRESIÓN JERÁRQUICA */}
          {effectiveCat === 'regresion_jerarquica' && (
            <div className="card">
              <p className="text-xs font-bold text-purple-600 uppercase tracking-widest mb-4">Parámetros de regresión jerárquica</p>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Método por bloque</label>
                  <select className="input" value={(cfg as any).hierMethod ?? 'enter'} onChange={e => updateConfig({ hierMethod: e.target.value } as any)}>
                    <option value="enter">Enter (todos los predictores)</option>
                    <option value="stepwise">Stepwise por bloque</option>
                  </select>
                </div>
                <div>
                  <label className="label">Reportar cambio en R²</label>
                  <select className="input" value={(cfg as any).reportDeltaR2 ?? 'yes'} onChange={e => updateConfig({ reportDeltaR2: e.target.value } as any)}>
                    <option value="yes">Sí (ΔR², F cambio, p cambio)</option>
                    <option value="no">No</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* LOGÍSTICA */}
          {effectiveCat === 'logistica' && (
            <div className="card">
              <p className="text-xs font-bold text-pink-600 uppercase tracking-widest mb-4">Parámetros de regresión logística</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Tipo de variable dependiente</label>
                  <select className="input" value={(cfg as any).logisticType ?? 'binaria'} onChange={e => updateConfig({ logisticType: e.target.value } as any)}>
                    <option value="binaria">Binaria (2 categorías)</option>
                    <option value="multinomial">Multinomial (3+ categorías, sin orden)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Método de entrada</label>
                  <select className="input" value={(cfg as any).logisticEntry ?? 'enter'} onChange={e => updateConfig({ logisticEntry: e.target.value } as any)}>
                    <option value="enter">Enter (simultáneo)</option>
                    <option value="forward_lr">Forward LR</option>
                    <option value="backward_lr">Backward LR</option>
                  </select>
                </div>
                <div>
                  <label className="label">Punto de corte clasificación</label>
                  <select className="input" value={(cfg as any).cutPoint ?? 0.5} onChange={e => updateConfig({ cutPoint: parseFloat(e.target.value) } as any)}>
                    <option value={0.5}>0.5 (estándar)</option>
                    <option value={0.3}>0.3 (sensibilidad alta)</option>
                    <option value={0.7}>0.7 (especificidad alta)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Pseudo R² a reportar</label>
                  <select className="input" value={(cfg as any).pseudoR2 ?? 'nagelkerke'} onChange={e => updateConfig({ pseudoR2: e.target.value } as any)}>
                    <option value="nagelkerke">Nagelkerke</option>
                    <option value="cox_snell">Cox y Snell</option>
                    <option value="all">Todos</option>
                  </select>
                </div>
                <div>
                  <label className="label">Prueba Hosmer-Lemeshow</label>
                  <select className="input" value={(cfg as any).hosmerLemeshow ?? 'yes'} onChange={e => updateConfig({ hosmerLemeshow: e.target.value } as any)}>
                    <option value="yes">Sí (ajuste del modelo)</option>
                    <option value="no">No</option>
                  </select>
                </div>
                <div>
                  <label className="label">Curva ROC y AUC</label>
                  <select className="input" value={(cfg as any).rocCurve ?? 'yes'} onChange={e => updateConfig({ rocCurve: e.target.value } as any)}>
                    <option value="yes">Sí</option>
                    <option value="no">No</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* COMPARACIÓN */}
          {effectiveCat === 'comparacion' && (
            <div className="card">
              <p className="text-xs font-bold text-purple-600 uppercase tracking-widest mb-4">Parámetros de comparación</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Tipo de hipótesis</label>
                  <select className="input" value={(cfg as any).hypothesisType ?? 'bilateral'} onChange={e => updateConfig({ hypothesisType: e.target.value } as any)}>
                    <option value="bilateral">Bilateral (dos colas)</option>
                    <option value="unilateral_pos">Unilateral: Grupo 1 &gt; Grupo 2</option>
                    <option value="unilateral_neg">Unilateral: Grupo 1 &lt; Grupo 2</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tamaño de efecto</label>
                  <select className="input" value={(cfg as any).effectSize ?? 'cohend'} onChange={e => updateConfig({ effectSize: e.target.value } as any)}>
                    <option value="cohend">d de Cohen (paramétrico)</option>
                    <option value="r_rb">r rango biserial (no paramétrico)</option>
                    <option value="both">Ambos</option>
                  </select>
                </div>
                <div>
                  <label className="label">Prueba de varianzas (Levene)</label>
                  <select className="input" value={(cfg as any).leveneTest ?? 'yes'} onChange={e => updateConfig({ leveneTest: e.target.value } as any)}>
                    <option value="yes">Sí (automático)</option>
                    <option value="no">No</option>
                  </select>
                </div>
                <div>
                  <label className="label">Escala mínima</label>
                  <input type="number" className="input" value={cfg.scale?.min ?? 1} onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
                </div>
                <div>
                  <label className="label">Escala máxima</label>
                  <input type="number" className="input" value={cfg.scale?.max ?? 5} onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
                </div>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-100">
                <label className="label">Niveles de baremo</label>
                <div className="flex gap-3">
                  {(cfg.baremoLevels ?? ['Bajo','Medio','Alto']).map((lv, i) => (
                    <input key={i} className="input flex-1" value={lv} onChange={e => { const lvs=[...(cfg.baremoLevels??['Bajo','Medio','Alto'])]; lvs[i]=e.target.value; updateConfig({ baremoLevels: lvs as [string,string,string] }); }} />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ANOVA */}
          {effectiveCat === 'anova' && (
            <div className="card">
              <p className="text-xs font-bold text-amber-600 uppercase tracking-widest mb-4">Parámetros de ANOVA</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Prueba post-hoc</label>
                  <select className="input" value={(cfg as any).posthoc ?? 'tukey'} onChange={e => updateConfig({ posthoc: e.target.value } as any)}>
                    <option value="tukey">Tukey HSD (varianzas iguales)</option>
                    <option value="bonferroni">Bonferroni (conservador)</option>
                    <option value="scheffe">Scheffé (grupos desiguales)</option>
                    <option value="games_howell">Games-Howell (varianzas desiguales)</option>
                    <option value="dunn">Dunn-Bonferroni (no paramétrico)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tamaño de efecto</label>
                  <select className="input" value={(cfg as any).effectSize ?? 'eta2'} onChange={e => updateConfig({ effectSize: e.target.value } as any)}>
                    <option value="eta2">η² (eta cuadrado)</option>
                    <option value="omega2">ω² (omega cuadrado — menos sesgado)</option>
                    <option value="both">Ambos</option>
                  </select>
                </div>
                <div>
                  <label className="label">Prueba de homogeneidad (Levene)</label>
                  <select className="input" value={(cfg as any).leveneTest ?? 'yes'} onChange={e => updateConfig({ leveneTest: e.target.value } as any)}>
                    <option value="yes">Sí (automático)</option>
                    <option value="no">No</option>
                  </select>
                </div>
                <div>
                  <label className="label">Escala mínima</label>
                  <input type="number" className="input" value={cfg.scale?.min ?? 1} onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
                </div>
                <div>
                  <label className="label">Escala máxima</label>
                  <input type="number" className="input" value={cfg.scale?.max ?? 5} onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
                </div>
              </div>
              <div className="mt-4 pt-4 border-t border-slate-100">
                <label className="label">Niveles de baremo</label>
                <div className="flex gap-3">
                  {(cfg.baremoLevels ?? ['Bajo','Medio','Alto']).map((lv, i) => (
                    <input key={i} className="input flex-1" value={lv} onChange={e => { const lvs=[...(cfg.baremoLevels??['Bajo','Medio','Alto'])]; lvs[i]=e.target.value; updateConfig({ baremoLevels: lvs as [string,string,string] }); }} />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ANCOVA */}
          {effectiveCat === 'ancova' && (
            <div className="card">
              <p className="text-xs font-bold text-orange-600 uppercase tracking-widest mb-4">Parámetros de ANCOVA</p>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Post-hoc (medias ajustadas)</label>
                  <select className="input" value={(cfg as any).posthoc ?? 'tukey'} onChange={e => updateConfig({ posthoc: e.target.value } as any)}>
                    <option value="tukey">Tukey HSD</option>
                    <option value="bonferroni">Bonferroni</option>
                    <option value="none">Sin post-hoc</option>
                  </select>
                </div>
                <div>
                  <label className="label">Verificar homogeneidad de pendientes</label>
                  <select className="input" value={(cfg as any).homogeneitySlopes ?? 'yes'} onChange={e => updateConfig({ homogeneitySlopes: e.target.value } as any)}>
                    <option value="yes">Sí (supuesto ANCOVA)</option>
                    <option value="no">No</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* CHI-CUADRADO */}
          {effectiveCat === 'chi_cuadrado' && (
            <div className="card">
              <p className="text-xs font-bold text-orange-600 uppercase tracking-widest mb-4">Parámetros de Chi-cuadrado</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Corrección de Yates</label>
                  <select className="input" value={(cfg as any).yatesCorrection ?? 'auto'} onChange={e => updateConfig({ yatesCorrection: e.target.value } as any)}>
                    <option value="auto">Automática (tablas 2×2)</option>
                    <option value="yes">Siempre aplicar</option>
                    <option value="no">No aplicar</option>
                  </select>
                </div>
                <div>
                  <label className="label">Tamaño de efecto</label>
                  <select className="input" value={(cfg as any).chiEffectSize ?? 'cramer'} onChange={e => updateConfig({ chiEffectSize: e.target.value } as any)}>
                    <option value="cramer">V de Cramer</option>
                    <option value="phi">Phi (tablas 2×2)</option>
                    <option value="both">Ambos</option>
                  </select>
                </div>
                <div>
                  <label className="label">Frecuencias esperadas mínimas</label>
                  <select className="input" value={(cfg as any).minExpected ?? 5} onChange={e => updateConfig({ minExpected: parseInt(e.target.value) } as any)}>
                    <option value={5}>5 (estándar — regla de Cochran)</option>
                    <option value={1}>1 (prueba exacta de Fisher)</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* DISCRIMINANTE */}
          {effectiveCat === 'discriminante' && (
            <div className="card">
              <p className="text-xs font-bold text-teal-600 uppercase tracking-widest mb-4">Parámetros de análisis discriminante</p>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Método de entrada</label>
                  <select className="input" value={(cfg as any).ldaMethod ?? 'simultaneous'} onChange={e => updateConfig({ ldaMethod: e.target.value } as any)}>
                    <option value="simultaneous">Simultáneo (todas las variables)</option>
                    <option value="stepwise">Stepwise (Lambda de Wilks)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Validación cruzada</label>
                  <select className="input" value={(cfg as any).ldaCV ?? 'yes'} onChange={e => updateConfig({ ldaCV: e.target.value } as any)}>
                    <option value="yes">Sí (Leave-one-out)</option>
                    <option value="no">No</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* CLUSTER */}
          {effectiveCat === 'cluster' && (
            <div className="card">
              <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-4">Parámetros de clúster</p>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Estandarizar variables</label>
                  <select className="input" value={(cfg as any).standardize ?? 'yes'} onChange={e => updateConfig({ standardize: e.target.value } as any)}>
                    <option value="yes">Sí (Z-scores — recomendado)</option>
                    <option value="no">No (escala original)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Semilla aleatoria (reproducibilidad)</label>
                  <input type="number" className="input" value={(cfg as any).seed ?? 42} onChange={e => updateConfig({ seed: parseInt(e.target.value) } as any)} />
                </div>
              </div>
            </div>
          )}

          {/* CRONBACH */}
          {effectiveCat === 'cronbach' && (
            <div className="card">
              <p className="text-xs font-bold text-blue-600 uppercase tracking-widest mb-4">Parámetros de confiabilidad</p>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Umbral mínimo r ítem-total</label>
                  <select className="input" value={(cfg as any).minRIT ?? 0.3} onChange={e => updateConfig({ minRIT: parseFloat(e.target.value) } as any)}>
                    <option value={0.3}>0.30 (estándar — Nunnally)</option>
                    <option value={0.2}>0.20 (flexible)</option>
                    <option value={0.4}>0.40 (estricto)</option>
                  </select>
                </div>
                <div>
                  <label className="label">Calcular Omega McDonald (ω)</label>
                  <select className="input" value={(cfg as any).calcOmega ?? 'yes'} onChange={e => updateConfig({ calcOmega: e.target.value } as any)}>
                    <option value="yes">Sí (recomendado)</option>
                    <option value="no">No (solo Alpha)</option>
                  </select>
                </div>
                <div>
                  <label className="label">IC bootstrap para Alpha</label>
                  <select className="input" value={(cfg as any).bootstrapCI ?? 'yes'} onChange={e => updateConfig({ bootstrapCI: e.target.value } as any)}>
                    <option value="yes">Sí (1000 iteraciones)</option>
                    <option value="no">No</option>
                  </select>
                </div>
                <div>
                  <label className="label">Modelo (unidimensional / tau-equivalente)</label>
                  <select className="input" value={(cfg as any).alphaModel ?? 'standard'} onChange={e => updateConfig({ alphaModel: e.target.value } as any)}>
                    <option value="standard">Estándar (tau-equivalente)</option>
                    <option value="ordinal">Alpha ordinal (escalas Likert)</option>
                  </select>
                </div>
              </div>
            </div>
          )}

          {/* ANALISIS DESCRIPTIVO (fusion de Baremos + Frecuencias + Descriptivos) */}
          {effectiveCat === 'descriptivo' && (
            <div className="card">
              <p className="text-xs font-bold text-green-600 uppercase tracking-widest mb-4">Parámetros del análisis descriptivo</p>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div>
                  <label className="label">Método de corte (Baremo)</label>
                  <select className="input" value={cfg.baremoMethod ?? 'tercil'} onChange={e => updateConfig({ baremoMethod: e.target.value as any })}>
                    <option value="tercil">Terciles (P33/P66)</option>
                    <option value="percentil">Percentiles (P25/P75)</option>
                    <option value="teorico">Teórico (media ± DE)</option>
                    <option value="custom_cut">Personalizado</option>
                  </select>
                </div>
                <div>
                  <label className="label">Prueba de normalidad</label>
                  <select className="input" value={(cfg as any).normalityTest ?? 'sw'} onChange={e => updateConfig({ normalityTest: e.target.value } as any)}>
                    <option value="sw">Shapiro-Wilk (n menor 2000)</option>
                    <option value="ks">Kolmogorov-Smirnov (n mayor 2000)</option>
                    <option value="both">Ambas</option>
                  </select>
                </div>
                <div>
                  <label className="label">Nivel de confianza (IC media)</label>
                  <select className="input" value={(cfg as any).confidenceLevel ?? 0.95} onChange={e => updateConfig({ confidenceLevel: parseFloat(e.target.value) } as any)}>
                    <option value={0.95}>95%</option>
                    <option value={0.99}>99%</option>
                  </select>
                </div>
                <div>
                  <label className="label">Escala mínima</label>
                  <input type="number" className="input" value={cfg.scale?.min ?? 1} onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
                </div>
                <div>
                  <label className="label">Escala máxima</label>
                  <input type="number" className="input" value={cfg.scale?.max ?? 5} onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
                </div>
              </div>
              <div className="mt-4">
                <label className="label">Nombres de niveles</label>
                <div className="flex gap-3">
                  {(cfg.baremoLevels ?? ['Bajo','Medio','Alto']).map((lv, i) => (
                    <input key={i} className="input flex-1" value={lv} onChange={e => { const lvs=[...(cfg.baremoLevels??['Bajo','Medio','Alto'])]; lvs[i]=e.target.value; updateConfig({ baremoLevels: lvs as [string,string,string] }); }} />
                  ))}
                </div>
              </div>
              <p className="text-xs text-green-700 bg-green-50 border border-green-200 rounded-xl px-4 py-3 mt-4">
                📑 Se calculará: media, mediana, moda, DE, varianza, asimetría, curtosis, prueba de normalidad, baremo (cortes), distribución por niveles con % y % acumulado, gráfico de barras y redacción APA 7 automática.
              </p>
            </div>
          )}

        </div>
      )}

      {/* Navigation */}
      <div className="flex justify-between items-center pt-2">
        <button onClick={onBack} className="btn-secondary">
          <ChevronLeft className="w-5 h-5"/> Atrás
        </button>
        <button onClick={onNext}
          disabled={(() => {
            if(effectiveCat === 'structural_model' || effectiveCat === 'instrumentos') return false;
            if(['cronbach','descriptivo','cluster'].includes(effectiveCat)) return cfg.varAItems.length < 1;
            if(effectiveCat === 'anova' || effectiveCat === 'discriminante') return cfg.varAItems.length < 1 || !cfg.groupVar;
            if(effectiveCat === 'comparacion') return cfg.varAItems.length < 1 || !cfg.groupVar;
            if(effectiveCat === 'ancova') return cfg.varAItems.length < 1 || cfg.varBItems.length < 1;
            if(effectiveCat === 'chi_cuadrado') return cfg.varAItems.length < 1 || cfg.varBItems.length < 1;
            if(effectiveCat === 'regresion_jerarquica') return cfg.varBItems.length < 1;
            return cfg.varAItems.length < 1;
          })()}
          className="btn-primary disabled:opacity-40 disabled:cursor-not-allowed px-8 py-4 text-base">
          {effectiveCat === 'instrumentos' ? 'Iniciar validación' : 'Continuar al análisis'}
          <ArrowRight className="w-5 h-5"/>
        </button>
      </div>
    </div>
  );
}
