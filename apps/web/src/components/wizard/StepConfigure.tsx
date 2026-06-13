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
  { id:'correlacional', label:'Correlacional', icon:'📈', desc:'Relación entre dos variables', color:'indigo', available:true },
  { id:'comparacion',   label:'Comparación',   icon:'⚖️', desc:'Diferencias entre 2 grupos', color:'purple', available:true },
  { id:'anova',         label:'ANOVA',         icon:'📊', desc:'Comparar 3 o más grupos',   color:'amber',  available:true },
  { id:'regresion',     label:'Regresión lineal', icon:'📉', desc:'Predicción continua',    color:'green',  available:true },
  { id:'logistica',     label:'Reg. logística',  icon:'🎯', desc:'Predicción categórica',   color:'pink',   available:true },
  { id:'chi_cuadrado',  label:'Chi-cuadrado',    icon:'📋', desc:'Variables categóricas',   color:'orange', available:true },
  { id:'factorial',     label:'Factorial',       icon:'🔲', desc:'Próximamente',            color:'slate',  available:false },
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

export default function StepConfigure({ state, config: cfg, updateConfig, onNext, onBack }: Props) {
  const columns = state.columns ?? [];
  const [showDimsA, setShowDimsA] = useState(cfg.varADimensions?.length > 0);
  const [showDimsB, setShowDimsB] = useState(cfg.varBDimensions?.length > 0);

  const cat = cfg.analysisCategory;
  const mode = cat === 'instrumentos' ? 'piloto' : 'analisis';

  return (
    <div className="space-y-8 animate-slide-up">
      {/* Page Header */}
      <div>
        <h1 className="text-3xl font-bold text-slate-900">Configura tu análisis</h1>
        <p className="text-slate-500 mt-2 text-lg">Selecciona el tipo de análisis que necesitas</p>
      </div>

      {/* SELECTOR DE MODO */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        <button type="button"
          onClick={() => updateConfig({ analysisCategory: 'instrumentos' })}
          className={`rounded-3xl border-2 p-7 text-left transition-all hover:-translate-y-1 hover:shadow-lg ${
            mode === 'piloto' ? 'border-cyan-500 bg-cyan-50 shadow-md shadow-cyan-100' : 'border-slate-200 bg-white hover:border-slate-300'
          }`}>
          <div className="flex items-center gap-4 mb-4">
            <div className={`w-14 h-14 rounded-2xl flex items-center justify-center text-3xl ${mode==='piloto'?'bg-cyan-100':'bg-slate-100'}`}>🔬</div>
            <div>
              <p className={`text-xl font-black ${mode==='piloto'?'text-cyan-800':'text-slate-800'}`}>Validar mi instrumento</p>
              <p className="text-sm text-slate-500 font-semibold">Fase 1 — Prueba piloto</p>
            </div>
          </div>
          <div className="space-y-1.5 text-sm text-slate-600">
            {['V de Aiken · Validez de contenido','AFE · KMO · Bartlett · Cargas','AFC · CFI · TLI · RMSEA · SRMR','Cronbach · Omega · CR · AVE · HTMT','30-100 participantes'].map(item => (
              <div key={item} className="flex items-center gap-2">
                <span className={`text-xs ${mode==='piloto'?'text-cyan-500':'text-slate-400'}`}>✓</span>
                <span>{item}</span>
              </div>
            ))}
          </div>
          {mode === 'piloto' && <div className="mt-4 bg-cyan-600 text-white text-xs font-bold px-3 py-1.5 rounded-full inline-block">✓ Seleccionado</div>}
        </button>

        <button type="button"
          onClick={() => updateConfig({ analysisCategory: 'correlacional' })}
          className={`rounded-3xl border-2 p-7 text-left transition-all hover:-translate-y-1 hover:shadow-lg ${
            mode === 'analisis' ? 'border-indigo-500 bg-indigo-50 shadow-md shadow-indigo-100' : 'border-slate-200 bg-white hover:border-slate-300'
          }`}>
          <div className="flex items-center gap-4 mb-4">
            <div className={`w-14 h-14 rounded-2xl flex items-center justify-center text-3xl ${mode==='analisis'?'bg-indigo-100':'bg-slate-100'}`}>📊</div>
            <div>
              <p className={`text-xl font-black ${mode==='analisis'?'text-indigo-800':'text-slate-800'}`}>Analizar mis datos</p>
              <p className="text-sm text-slate-500 font-semibold">Fase 2 — Análisis final</p>
            </div>
          </div>
          <div className="space-y-1.5 text-sm text-slate-600">
            {['Correlación · t-test · ANOVA','Regresión lineal y logística','Chi-cuadrado · Descriptivos · Baremos','100+ participantes'].map(item => (
              <div key={item} className="flex items-center gap-2">
                <span className={`text-xs ${mode==='analisis'?'text-indigo-500':'text-slate-400'}`}>✓</span>
                <span>{item}</span>
              </div>
            ))}
          </div>
          {mode === 'analisis' && <div className="mt-4 bg-indigo-600 text-white text-xs font-bold px-3 py-1.5 rounded-full inline-block">✓ Seleccionado</div>}
        </button>
      </div>

      {/* STEP 1: Tipo de análisis — solo si modo analisis */}
      {mode === 'analisis' && <div className="card">
        <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-4">Paso 1 — Método estadístico</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {ANALYSIS_TYPES.map(t => (
            <button key={t.id} type="button" disabled={!t.available}
              onClick={() => updateConfig({ analysisCategory: t.id as any })}
              className={`method-card text-left ${
                !t.available ? 'disabled opacity-40 cursor-not-allowed border-slate-200 bg-slate-50' :
                cat === t.id ? `active ${colorMap[t.color]}` : 'inactive border-slate-200 bg-white hover:border-slate-300'
              }`}>
              <span className="text-3xl block mb-3">{t.icon}</span>
              <p className={`font-bold text-base mb-1 ${cat===t.id ? iconColorMap[t.color] : 'text-slate-800'}`}>{t.label}</p>
              <p className="text-xs text-slate-500 leading-relaxed">{t.desc}</p>
              {!t.available && <span className="text-xs text-slate-400 font-semibold mt-1 block">Próximamente</span>}
            </button>
          ))}
        </div>

        {/* Subtipo comparacion */}
        {cat === 'comparacion' && (
          <div className="mt-6 pt-6 border-t border-slate-100">
            <p className="text-sm font-bold text-slate-700 mb-4">Tipo de comparación</p>
            <div className="grid grid-cols-3 gap-3">
              {[
                { id:'independiente', label:'Grupos independientes', desc:'Dos grupos distintos', info:'t de Student o Mann-Whitney' },
                { id:'pareada',       label:'Muestras relacionadas', desc:'Pre-test / Post-test',  info:'t pareada o Wilcoxon' },
                { id:'auto',          label:'Automático',            desc:'El sistema elige',      info:'Verifica supuestos' },
              ].map(s => (
                <button key={s.id} type="button" onClick={() => updateConfig({ comparisonType: s.id as any })}
                  className={`rounded-2xl border-2 p-4 text-left transition-all ${cfg.comparisonType===s.id?'border-purple-400 bg-purple-50':'border-slate-200 bg-white hover:border-slate-300'}`}>
                  <p className={`font-bold text-sm mb-1 ${cfg.comparisonType===s.id?'text-purple-700':'text-slate-800'}`}>{s.label}</p>
                  <p className="text-xs text-slate-500">{s.desc}</p>
                  <p className="text-xs text-purple-600 font-semibold mt-2">{s.info}</p>
                </button>
              ))}
            </div>
            {/* Variable de agrupacion */}
            <div className="mt-4 grid grid-cols-2 gap-4">
              <div>
                <label className="label">Variable de agrupación (columna)</label>
                <select className="input" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value, groupValues: ['',''] })}>
                  <option value="">-- Seleccionar columna --</option>
                  {columns.map(col => <option key={col} value={col}>{col}</option>)}
                </select>
              </div>
              {cfg.groupVar && (
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="label">Valor Grupo 1</label>
                    <input className="input" placeholder="ej: Masculino" value={cfg.groupValues[0]}
                      onChange={e => updateConfig({ groupValues: [e.target.value, cfg.groupValues[1]] })} />
                  </div>
                  <div>
                    <label className="label">Valor Grupo 2</label>
                    <input className="input" placeholder="ej: Femenino" value={cfg.groupValues[1]}
                      onChange={e => updateConfig({ groupValues: [cfg.groupValues[0], e.target.value] })} />
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ANOVA config */}
        {cat === 'anova' && (
          <div className="mt-6 pt-6 border-t border-slate-100">
            <p className="text-sm font-bold text-slate-700 mb-3">Variable de agrupación (3+ grupos)</p>
            <select className="input max-w-sm" value={cfg.groupVar} onChange={e => updateConfig({ groupVar: e.target.value })}>
              <option value="">-- Seleccionar columna --</option>
              {columns.map(col => <option key={col} value={col}>{col}</option>)}
            </select>
            <p className="text-xs text-slate-500 mt-2">El sistema verificará normalidad y elegirá ANOVA o Kruskal-Wallis automáticamente.</p>
          </div>
        )}

        {/* Logistica config */}
        {cat === 'logistica' && (
          <div className="mt-6 pt-6 border-t border-slate-100">
            <p className="text-sm font-bold text-slate-700 mb-4">Tipo de regresión logística</p>
            <div className="grid grid-cols-2 gap-3 max-w-md">
              {[{id:'binaria',label:'Binaria',desc:'VD dicotómica (0/1)'},{id:'ordinal',label:'Ordinal',desc:'VD con orden (bajo/medio/alto)'}].map(t=>(
                <button key={t.id} type="button" onClick={()=>updateConfig({logisticType:t.id as any})}
                  className={`rounded-2xl border-2 p-4 text-left transition-all ${cfg.logisticType===t.id?'border-pink-400 bg-pink-50':'border-slate-200 bg-white'}`}>
                  <p className={`font-bold text-sm ${cfg.logisticType===t.id?'text-pink-700':'text-slate-800'}`}>{t.label}</p>
                  <p className="text-xs text-slate-500 mt-1">{t.desc}</p>
                </button>
              ))}
            </div>
          </div>
        )}

      </div>}



      {/* STEP 2: Info del estudio */}
      <div className="card">
        <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-5">Paso 2 — Información del estudio</p>
        <div className="grid grid-cols-2 gap-5 mb-5">
          <div>
            <label className="label">Título del estudio</label>
            <input className="input text-base" placeholder="Ej: Gestión del conocimiento y desempeño docente"
              value={cfg.studyTitle} onChange={e => updateConfig({ studyTitle: e.target.value })} />
          </div>
          <div>
            <label className="label">Participantes</label>
            <input className="input text-base" placeholder="los participantes"
              value={cfg.participants} onChange={e => updateConfig({ participants: e.target.value })} />
          </div>
        </div>
        <div>
          <label className="label">Objetivo general</label>
          <textarea className="input text-base resize-none" rows={3}
            placeholder="Determinar la relación entre..."
            value={cfg.objective} onChange={e => updateConfig({ objective: e.target.value })} />
        </div>
      </div>

      {/* STEP 3: Variables */}
      {(
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Variable A */}
          <div className="card border-l-4 border-l-indigo-500">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-200">
                <span className="text-white font-black text-lg">A</span>
              </div>
              <div>
                <p className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Variable independiente</p>
                <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full mt-0.5"
                  value={cfg.varAName} onChange={e => updateConfig({ varAName: e.target.value })} />
              </div>
            </div>
            <div className="mb-5">
              <label className="label">Ítems de {cfg.varAName}</label>
              <ItemChips columns={columns} selected={cfg.varAItems} onChange={v => updateConfig({ varAItems: v })} color="indigo" />
            </div>
            <div>
              <button type="button" onClick={() => setShowDimsA(!showDimsA)}
                className="flex items-center gap-2 text-sm font-semibold text-indigo-600 hover:text-indigo-700 mb-4 transition">
                <div className={`w-5 h-5 rounded border-2 border-indigo-400 flex items-center justify-center ${showDimsA?'bg-indigo-500 border-indigo-500':''}`}>
                  {showDimsA && <span className="text-white text-xs">✓</span>}
                </div>
                ¿Tiene dimensiones?
              </button>
              {showDimsA && <DimEditor dimensions={cfg.varADimensions} columns={cfg.varAItems} onChange={v => updateConfig({ varADimensions: v })} color="indigo" />}
            </div>
          </div>

          {/* Variable B */}
          <div className="card border-l-4 border-l-teal-500">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 bg-teal-600 rounded-xl flex items-center justify-center shadow-lg shadow-teal-200">
                <span className="text-white font-black text-lg">B</span>
              </div>
              <div>
                <p className="text-xs font-bold text-teal-600 uppercase tracking-wider">Variable dependiente</p>
                <input className="text-xl font-bold text-slate-900 bg-transparent border-none outline-none w-full mt-0.5"
                  value={cfg.varBName} onChange={e => updateConfig({ varBName: e.target.value })} />
              </div>
            </div>
            <div className="mb-5">
              <label className="label">Ítems de {cfg.varBName}</label>
              <ItemChips columns={columns} selected={cfg.varBItems} onChange={v => updateConfig({ varBItems: v })} color="teal" />
            </div>
            <div>
              <button type="button" onClick={() => setShowDimsB(!showDimsB)}
                className="flex items-center gap-2 text-sm font-semibold text-teal-600 hover:text-teal-700 mb-4 transition">
                <div className={`w-5 h-5 rounded border-2 border-teal-400 flex items-center justify-center ${showDimsB?'bg-teal-500 border-teal-500':''}`}>
                  {showDimsB && <span className="text-white text-xs">✓</span>}
                </div>
                ¿Tiene dimensiones?
              </button>
              {showDimsB && <DimEditor dimensions={cfg.varBDimensions} columns={cfg.varBItems} onChange={v => updateConfig({ varBDimensions: v })} color="teal" />}
            </div>
          </div>
        </div>
      )}

      {/* Tipos de correlacion - solo si hay dimensiones */}
      {cat === 'correlacional' && (cfg.varADimensions?.length > 0 || cfg.varBDimensions?.length > 0) && (
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

      {/* STEP 4: Parámetros estadísticos */}
      {cat !== 'instrumentos' && (
        <div className="card">
          <p className="text-xs font-bold text-indigo-600 uppercase tracking-widest mb-5">Paso 4 — Parámetros estadísticos</p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-5">
            <div>
              <label className="label">Nivel de significancia (α)</label>
              <select className="input text-base" value={cfg.alpha} onChange={e => updateConfig({ alpha: parseFloat(e.target.value) })}>
                <option value={0.05}>0.05 (estándar)</option>
                <option value={0.01}>0.01 (estricto)</option>
                <option value={0.10}>0.10 (explorat.)</option>
              </select>
            </div>
            <div>
              <label className="label">Método de correlación</label>
              <select className="input text-base" value={cfg.methodForce} onChange={e => updateConfig({ methodForce: e.target.value as any })}>
                <option value="auto">Automático (según normalidad)</option>
                <option value="pearson">Pearson (r)</option>
                <option value="spearman">Spearman (ρ)</option>
              </select>
            </div>
            <div>
              <label className="label">Escala mínima</label>
              <input type="number" className="input text-base" value={cfg.scale?.min ?? 1}
                onChange={e => updateConfig({ scale: { ...cfg.scale, min: parseInt(e.target.value) } })} />
            </div>
            <div>
              <label className="label">Escala máxima</label>
              <input type="number" className="input text-base" value={cfg.scale?.max ?? 5}
                onChange={e => updateConfig({ scale: { ...cfg.scale, max: parseInt(e.target.value) } })} />
            </div>
          </div>
          <div className="mt-5 pt-5 border-t border-slate-100">
            <label className="label">Niveles de baremo</label>
            <div className="flex gap-3">
              {(cfg.baremoLevels ?? ['Bajo','Medio','Alto']).map((lv, i) => (
                <input key={i} className="input text-base flex-1" value={lv}
                  onChange={e => {
                    const lvs = [...(cfg.baremoLevels ?? ['Bajo','Medio','Alto'])];
                    lvs[i] = e.target.value;
                    updateConfig({ baremoLevels: lvs as [string,string,string] });
                  }} />
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Navigation */}
      <div className="flex justify-between items-center pt-2">
        <button onClick={onBack} className="btn-secondary">
          <ChevronLeft className="w-5 h-5"/> Atrás
        </button>
        <button onClick={onNext}
          disabled={cat !== 'instrumentos' && cfg.varAItems.length < 2}
          className="btn-primary disabled:opacity-40 disabled:cursor-not-allowed px-8 py-4 text-base">
          {cat === 'instrumentos' ? 'Iniciar validación' : 'Continuar al análisis'}
          <ArrowRight className="w-5 h-5"/>
        </button>
      </div>
    </div>
  );
}
