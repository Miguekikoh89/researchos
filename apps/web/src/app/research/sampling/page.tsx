'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Users, ChevronRight, ArrowLeft, Copy, Check, Info, BookOpen, AlertTriangle, HelpCircle, ChevronDown, ChevronUp } from 'lucide-react';
import {
  INIT_STATE, SamplingState,
  populationDecisionEngine, samplingDecisionEngine,
  sampleSizeRoute, calcularMuestra, generarTextoTesis,
  plsSampleSizeEngine, gPowerReg, gPowerAnova, gPowerCorr, gPowerT, krejcieMorgan
} from '@/lib/sampling/engines';

export default function SamplingPage() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [s, setS] = useState<SamplingState>(INIT_STATE);
  const [copied, setCopied] = useState(false);
  const [showWhy, setShowWhy] = useState<string|null>(null);

  const set = (k: keyof SamplingState, v: any) => setS(p=>({...p,[k]:v}));
  const toggleArr = (k: keyof SamplingState, v: string) => setS(p=>{
    const arr = (p[k] as string[]);
    return {...p,[k]:arr.includes(v)?arr.filter(x=>x!==v):[...arr,v]};
  });

  const popDec = populationDecisionEngine(s);
  const sampDec = samplingDecisionEngine(s);
  const ruta = sampleSizeRoute(s);
  const calc = calcularMuestra(s);
  const tesis = step===STEPS(s).length-1 ? generarTextoTesis(s) : '';

  function STEPS(st: SamplingState) {
    return st.enfoque==='cualitativo'
      ? ['Tipo de estudio','Objetivo','Población','Marco muestral','Muestra','Criterios','Resultado']
      : ['Tipo de estudio','Objetivo','Población','Marco muestral','Tamaño muestral','Criterios','Resultado'];
  }
  const steps = STEPS(s);

  const Opt = ({val,cur,onClick,children}:{val:any,cur:any,onClick:()=>void,children:React.ReactNode}) => (
    <button onClick={onClick} className={`px-4 py-2.5 rounded-xl border-2 font-semibold text-sm transition-all ${cur===val?'bg-indigo-600 border-indigo-600 text-white':'border-slate-200 text-slate-600 hover:border-indigo-300 bg-white'}`}>{children}</button>
  );
  const Card = ({val,cur,onClick,title,sub}:{val:string,cur:string,onClick:()=>void,title:string,sub:string}) => (
    <button onClick={onClick} className={`p-4 rounded-2xl border-2 text-left w-full transition-all ${cur===val?'bg-teal-50 border-teal-500':'border-slate-200 bg-white hover:border-teal-200'}`}>
      <p className={`font-bold text-sm ${cur===val?'text-teal-800':'text-slate-800'}`}>{title}</p>
      <p className="text-xs text-slate-500 mt-0.5 leading-tight">{sub}</p>
    </button>
  );
  const InfoBox = ({children}:{children:React.ReactNode}) => (
    <div className="bg-blue-50 border border-blue-200 rounded-xl p-3 flex gap-2 text-sm text-blue-800">
      <Info className="w-4 h-4 flex-shrink-0 mt-0.5 text-blue-500"/><div>{children}</div>
    </div>
  );
  const WarnBox = ({children}:{children:React.ReactNode}) => (
    <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex gap-2 text-sm text-amber-800">
      <AlertTriangle className="w-4 h-4 flex-shrink-0 mt-0.5 text-amber-500"/><div>{children}</div>
    </div>
  );
  const WhyBtn = ({id,label,children}:{id:string,label?:string,children:React.ReactNode}) => (
    <div className="mt-2">
      <button onClick={()=>setShowWhy(showWhy===id?null:id)} className="flex items-center gap-1.5 text-xs text-indigo-600 font-semibold hover:text-indigo-800">
        <HelpCircle className="w-3.5 h-3.5"/>{label||'¿Por qué se recomienda esto?'}{showWhy===id?<ChevronUp className="w-3 h-3"/>:<ChevronDown className="w-3 h-3"/>}
      </button>
      {showWhy===id&&<div className="mt-2 bg-indigo-50 border border-indigo-100 rounded-xl p-3 text-xs text-indigo-800 leading-relaxed">{children}</div>}
    </div>
  );
  const Num = ({label,k,min,max,ph}:{label:string,k:keyof SamplingState,min:number,max:number,ph:string}) => (
    <div><p className="text-xs text-slate-500 mb-1">{label}</p>
      <input type="number" min={min} max={max} placeholder={ph} className="input max-w-28 text-center font-bold"
        value={(s[k] as number)||''} onChange={e=>set(k,parseFloat(e.target.value)||0)}/></div>
  );

  const save = () => {
    const data = {...s,tecnica:sampDec.tecnica,n:calc.nFinal,tesis:generarTextoTesis(s)};
    localStorage.setItem('ros_sampling',JSON.stringify(data));
    router.push('/dashboard');
  };

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header */}
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-teal-600 rounded-xl flex items-center justify-center"><Users className="w-5 h-5 text-white"/></div>
          <div><p className="font-black text-slate-900">Población y Muestra</p><p className="text-xs text-slate-400">Sistema experto metodológico · CanchariOS</p></div>
        </div>
        <div className="flex items-center gap-1">
          {steps.map((st,i)=>(
            <div key={st} className="flex items-center gap-0.5">
              <button onClick={()=>i<step&&setStep(i)} className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all ${i===step?'bg-teal-600 text-white':i<step?'bg-green-500 text-white cursor-pointer hover:opacity-80':'bg-slate-200 text-slate-400'}`}>{i+1}</button>
              {i<steps.length-1&&<div className={`w-4 h-0.5 ${i<step?'bg-green-400':'bg-slate-200'}`}/>}
            </div>
          ))}
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-8 space-y-5">

        {/* ═══ PASO 0: TIPO DE ESTUDIO ═══ */}
        {step===0 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Tipo de estudio</h1>
            <p className="text-slate-500 mt-1">Estas decisiones determinan toda la lógica metodológica del muestreo.</p></div>

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
            <p className="font-bold text-slate-800">Enfoque de investigación</p>
            <div className="grid grid-cols-3 gap-3">
              {[['cuantitativo','Cuantitativo','Estadísticas, hipótesis, generalización'],
                ['cualitativo','Cualitativo','Interpretación, significados, profundidad'],
                ['mixto','Mixto','Combina ambos enfoques']].map(([v,t,sub])=>(
                <button key={v} onClick={()=>set('enfoque',v)} className={`p-4 rounded-2xl border-2 text-center transition-all ${s.enfoque===v?'bg-teal-50 border-teal-500':'border-slate-200 bg-white hover:border-teal-300'}`}>
                  <p className={`font-bold text-sm ${s.enfoque===v?'text-teal-800':'text-slate-800'}`}>{t}</p>
                  <p className="text-xs text-slate-500 mt-1 leading-tight">{sub}</p>
                </button>
              ))}
            </div>
            <WhyBtn id="enfoque">El enfoque determina la epistemología del estudio y la lógica del muestreo. El cuantitativo busca representatividad o potencia estadística; el cualitativo busca profundidad y saturación teórica; el mixto combina estrategias (Hernández-Sampieri, 2018; Creswell, 2013; Teddlie & Yu, 2007).</WhyBtn>
          </div>

          {s.enfoque && <>
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
              <p className="font-bold text-slate-800">Alcance de la investigación</p>
              <div className="flex flex-wrap gap-2">
                {[['exploratorio','Exploratorio'],['descriptivo','Descriptivo'],['correlacional','Correlacional'],['explicativo','Explicativo / Causal'],['predictivo','Predictivo']].map(([v,t])=>(
                  <Opt key={v} val={v} cur={s.alcance} onClick={()=>set('alcance',v)}>{t}</Opt>
                ))}
              </div>
              <WhyBtn id="alcance">El alcance define el tipo de conocimiento a generar. Los descriptivos priorizan representatividad; los correlacionales y explicativos requieren potencia estadística; los exploratorios permiten muestras más pequeñas (Hernández-Sampieri, 2018).</WhyBtn>
            </div>

            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
              <p className="font-bold text-slate-800">Diseño de investigación</p>
              <div className="flex flex-wrap gap-2">
                {[['transversal','Transversal'],['longitudinal','Longitudinal'],['experimental','Experimental'],['cuasi_exp','Cuasiexperimental'],['no_exp','No experimental'],['fenomenologia','Fenomenológico'],['grounded','Teoría fundamentada'],['estudio_caso','Estudio de caso']].map(([v,t])=>(
                  <Opt key={v} val={v} cur={s.diseño} onClick={()=>set('diseño',v)}>{t}</Opt>
                ))}
              </div>
            </div>
          </>}
        </>}

        {/* ═══ PASO 1: OBJETIVO Y ANÁLISIS ═══ */}
        {step===1 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Objetivo principal y análisis estadístico</h1>
            <p className="text-slate-500 mt-1">El análisis previsto es el factor más determinante para calcular el tamaño muestral.</p></div>

          {s.enfoque!=='cualitativo' ? <>
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
              <p className="font-bold text-slate-800">¿Cuál es el análisis estadístico principal?</p>
              <div className="grid grid-cols-2 gap-2">
                {[['descriptivo','Descriptivo / Prevalencia','Nivel, frecuencia, porcentaje, distribución'],
                  ['correlacion','Correlación','Relación entre variables (Pearson, Spearman)'],
                  ['regresion','Regresión múltiple','Predicción de variable dependiente continua'],
                  ['anova','ANOVA / ANCOVA / MANOVA','Comparación de medias entre grupos'],
                  ['ttest','t-test / Comparación','Dos grupos independientes o pareados'],
                  ['logistica','Regresión logística','Variable dependiente categórica'],
                  ['pls_sem','PLS-SEM','Ecuaciones estructurales por mínimos cuadrados'],
                  ['cb_sem','CB-SEM / AMOS','Ecuaciones estructurales basadas en covarianza']].map(([v,t,sub])=>(
                  <Card key={v} val={v} cur={s.analisis} onClick={()=>set('analisis',v)} title={t} sub={sub}/>
                ))}
              </div>
              <WhyBtn id="analisis">Cada método estadístico tiene su propia lógica de justificación muestral: los descriptivos usan Cochran o Krejcie-Morgan; los inferenciales usan G*Power (potencia estadística); los modelos SEM tienen criterios especializados. Usar la fórmula incorrecta es el error metodológico más frecuente en tesis (Cohen, 1988; Hair et al., 2022).</WhyBtn>
            </div>

            {/* Parámetros específicos por análisis */}
            {s.analisis==='pls_sem' && (() => {
              const pls = s.itemsMax>0||s.flechasMax>0 ? plsSampleSizeEngine(s.flechasMax||4,s.itemsMax||5) : null;
              return <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-4">
                <p className="font-bold text-indigo-800">PLS-SEM — Parámetros del modelo</p>
                <p className="text-xs text-indigo-700">CanchariOS aplicará 4 criterios concurrentes y adoptará el más conservador.</p>
                <div className="grid grid-cols-2 gap-4">
                  <Num label="Ítems en el constructo más complejo (regla 10×)" k="itemsMax" min={1} max={30} ph="Ej: 14"/>
                  <Num label="Flechas al constructo endógeno con más predictores" k="flechasMax" min={1} max={10} ph="Ej: 3"/>
                </div>
                {pls && <div className="bg-white rounded-xl p-4 space-y-2 text-sm">
                  <p className="font-bold text-slate-700 text-xs uppercase tracking-wider">Comparativo de métodos</p>
                  {[['G*Power (Faul et al., 2007)',pls.gPower],['Inverse Square Root (Kock & Hadaya, 2018)',pls.inverseRoot],['Gamma-Exponential (Kock & Hadaya, 2018)',pls.gammaExp],['Regla 10× (Hair et al., 2022)',pls.regla10x]].map(([label,val])=>(
                    <div key={label as string} className={`flex justify-between ${val===pls.conservador?'font-black text-indigo-700':''}`}>
                      <span className="text-slate-600">{label as string}{val===pls.conservador?' ← más conservador':''}</span>
                      <span>n ≥ {val as number}</span>
                    </div>
                  ))}
                  <div className="border-t pt-2 flex justify-between text-teal-700 font-black text-base">
                    <span>n mínimo recomendado</span><span>{pls.conservador}</span>
                  </div>
                </div>}
                <WarnBox>La regla de 10× es una aproximación heurística. Para mayor rigor metodológico, Kock & Hadaya (2018) recomiendan los métodos Inverse Square Root y Gamma-Exponential como alternativas más robustas.</WarnBox>
              </div>;
            })()}

            {s.analisis==='cb_sem' && <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-3">
              <p className="font-bold text-indigo-800">CB-SEM — Criterios de tamaño muestral</p>
              <Num label="N° de constructos latentes en el modelo" k="constructosN" min={2} max={20} ph="Ej: 5"/>
              <div className="bg-white rounded-xl p-3 text-sm space-y-1">
                <div className="flex justify-between"><span className="text-slate-500">Mínimo absoluto (Tabachnick & Fidell, 2013)</span><span className="font-bold">n ≥ 200</span></div>
                <div className="flex justify-between"><span className="text-slate-500">{'>'} 5 constructos recomendado</span><span className="font-bold">n ≥ 300</span></div>
                <div className="flex justify-between"><span className="text-slate-500">Con estimadores robustos (Bentler & Chou)</span><span className="font-bold">n ≥ 150</span></div>
              </div>
            </div>}

            {s.analisis==='regresion' && <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-4">
              <p className="font-bold text-indigo-800">G*Power — Regresión múltiple (Faul et al., 2007)</p>
              <div className="grid grid-cols-2 gap-4">
                <Num label="N° de variables predictoras" k="predictores" min={1} max={20} ph="Ej: 3"/>
                <div><p className="text-xs text-slate-500 mb-1">Tamaño del efecto f²</p>
                  <div className="flex flex-col gap-1">
                    {[[0.02,'0.02 — Pequeño'],[0.15,'0.15 — Mediano'],[0.35,'0.35 — Grande']].map(([v,t])=>(
                      <Opt key={v} val={v} cur={s.f2} onClick={()=>set('f2',v)}>{t as string}</Opt>
                    ))}
                  </div>
                </div>
              </div>
              {s.predictores>0 && <div className="bg-white rounded-xl p-3 text-sm space-y-1">
                <div className="flex justify-between"><span>G*Power (α=0.05, 1-β=0.80):</span><span className="font-bold text-indigo-700">n ≥ {gPowerReg(s.predictores,s.f2)}</span></div>
                <div className="flex justify-between"><span>Field (2018) regla 15×:</span><span className="font-bold">n ≥ {s.predictores*15}</span></div>
              </div>}
            </div>}

            {s.analisis==='anova' && <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-4">
              <p className="font-bold text-indigo-800">G*Power — ANOVA (Cohen, 1988)</p>
              <div className="grid grid-cols-2 gap-4">
                <Num label="Número de grupos" k="grupos" min={2} max={10} ph="Ej: 3"/>
                <div><p className="text-xs text-slate-500 mb-1">Efecto f</p>
                  <div className="flex flex-col gap-1">
                    {[[0.10,'0.10 — Pequeño'],[0.25,'0.25 — Mediano'],[0.40,'0.40 — Grande']].map(([v,t])=>(
                      <Opt key={v} val={v} cur={s.fAnova} onClick={()=>set('fAnova',v)}>{t as string}</Opt>
                    ))}
                  </div>
                </div>
              </div>
              {s.grupos>0 && <div className="bg-white rounded-xl p-3 text-sm">
                <div className="flex justify-between"><span>G*Power total:</span><span className="font-bold text-indigo-700">{gPowerAnova(s.grupos,s.fAnova)}</span></div>
                <div className="flex justify-between"><span>Por grupo:</span><span className="font-bold">{Math.ceil(gPowerAnova(s.grupos,s.fAnova)/s.grupos)}</span></div>
              </div>}
            </div>}

            {s.analisis==='correlacion' && <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-3">
              <p className="font-bold text-indigo-800">G*Power — Correlación (Cohen, 1988)</p>
              <div className="flex gap-2">{[[0.10,'r = 0.10'],[0.30,'r = 0.30'],[0.50,'r = 0.50']].map(([v,t])=>(
                <Opt key={v} val={v} cur={s.rEsp} onClick={()=>set('rEsp',v)}>{t as string}</Opt>
              ))}</div>
              <div className="bg-white rounded-xl p-3 text-sm">
                <div className="flex justify-between"><span>G*Power (α=0.05, 1-β=0.80):</span><span className="font-bold text-indigo-700">n ≥ {gPowerCorr(s.rEsp)}</span></div>
              </div>
            </div>}

            {(s.analisis==='ttest'||s.analisis==='comparacion') && <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-5 space-y-3">
              <p className="font-bold text-indigo-800">G*Power — t-test (Cohen, 1988)</p>
              <div className="flex gap-2">{[[0.20,'d = 0.20'],[0.50,'d = 0.50'],[0.80,'d = 0.80']].map(([v,t])=>(
                <Opt key={v} val={v} cur={s.cohenD} onClick={()=>set('cohenD',v)}>{t as string}</Opt>
              ))}</div>
              <div className="bg-white rounded-xl p-3 text-sm">
                <div className="flex justify-between"><span>G*Power total:</span><span className="font-bold text-indigo-700">{gPowerT(s.cohenD)}</span></div>
                <div className="flex justify-between"><span>Por grupo:</span><span className="font-bold">{Math.ceil(gPowerT(s.cohenD)/2)}</span></div>
              </div>
            </div>}

          </> : <>
            {/* Cualitativo */}
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
              <p className="font-bold text-slate-800">Diseño cualitativo específico</p>
              <div className="grid grid-cols-2 gap-2">
                {[['fenomenologia','Fenomenología','Experiencias vividas (6–10 participantes)'],
                  ['grounded','Teoría fundamentada','Construcción de teoría (20–30)'],
                  ['etnografia','Etnografía','Cultura en contexto (12–30)'],
                  ['estudio_caso','Estudio de caso','Análisis profundo (1–5 casos)'],
                  ['narrativo','Narrativo','Historias de vida (3–10)'],
                  ['investigacion_accion','Investigación-acción','Reflexión participativa (variable)']].map(([v,t,sub])=>(
                  <Card key={v} val={v} cur={s.diseño} onClick={()=>set('diseño',v)} title={t} sub={sub}/>
                ))}
              </div>
            </div>
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
              <p className="font-bold text-slate-800">Técnica de muestreo cualitativo</p>
              <div className="grid grid-cols-1 gap-2">
                {[['propositivo','Propositivo / Intencional','Máxima capacidad informativa'],
                  ['bola_nieve','Bola de nieve','Participantes refieren a nuevos participantes'],
                  ['teorico','Teórico (Grounded Theory)','Guiado por categorías emergentes'],
                  ['criterio','Por criterio','Todos cumplen criterios predefinidos'],
                  ['maximo','Máxima variación','Máxima diversidad de casos'],
                  ['homogeneo','Homogéneo','Casos similares para análisis detallado']].map(([v,t,sub])=>(
                  <Card key={v} val={v} cur={s.tecnicaCual} onClick={()=>set('tecnicaCual',v)} title={t} sub={sub}/>
                ))}
              </div>
            </div>
            <InfoBox>En investigación cualitativa el tamaño muestral no se calcula estadísticamente. El criterio principal es la <strong>saturación teórica</strong> (Morse, 1995): se continúa seleccionando hasta que los datos no aportan nuevas categorías. No hay un número fijo — depende del diseño y la complejidad del fenómeno.</InfoBox>
          </>}
        </>}

        {/* ═══ PASO 2: POBLACIÓN ═══ */}
        {step===2 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Caracterización de la población</h1></div>

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
            <p className="font-bold text-slate-800">Unidad de análisis</p>
            <p className="text-xs text-slate-500">¿Qué o quién es el elemento que se estudia? (persona, empresa, documento, evento...)</p>
            <input className="input text-sm" placeholder="Ej: Trabajadores del sector retail del distrito de Miraflores"
              value={s.unidadAnalisis} onChange={e=>set('unidadAnalisis',e.target.value)}/>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
            <p className="font-bold text-slate-800">Tipo de población</p>
            <div className="grid grid-cols-2 gap-2">
              {[['institucional','Institucional','Empresas, universidades, hospitales'],
                ['educativa','Educativa','Estudiantes, docentes, directivos'],
                ['clinica','Clínica / Salud','Pacientes, personal sanitario'],
                ['empresarial','Empresarial','Trabajadores, gerentes, clientes'],
                ['comunitaria','Comunitaria','Hogares, ciudadanos, comunidades'],
                ['online','Online / Virtual','Usuarios de plataformas digitales'],
                ['oculta','Oculta / Vulnerable','Difícil localización o acceso'],
                ['registros','Registros / BD secundaria','Datos administrativos o archivos']].map(([v,t,sub])=>(
                <Card key={v} val={v} cur={s.tipoPob} onClick={()=>set('tipoPob',v)} title={t} sub={sub}/>
              ))}
            </div>
          </div>

          {s.tipoPob && s.enfoque!=='cualitativo' && (
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
              <p className="font-bold text-slate-800">¿Conoces el tamaño de tu población (N)?</p>
              <div className="flex flex-wrap gap-2">
                {[['exacto','Sí, conozco el número exacto'],['aprox','Tengo una estimación aproximada'],['desconocido','No, es indeterminada / muy grande']].map(([v,t])=>(
                  <Opt key={v} val={v} cur={s.tamConocido} onClick={()=>set('tamConocido',v)}>{t}</Opt>
                ))}
              </div>
              {(s.tamConocido==='exacto'||s.tamConocido==='aprox')&&(
                <div className="flex items-center gap-3">
                  <input type="number" min={1} className="input max-w-40" placeholder="Ej: 350"
                    value={s.nPobl||''} onChange={e=>set('nPobl',parseInt(e.target.value)||0)}/>
                  <span className="text-slate-500 text-sm">personas / elementos</span>
                </div>
              )}
              {s.nPobl>0&&s.nPobl<=100&&<div className="bg-green-50 border border-green-300 rounded-xl p-3 text-sm text-green-800"><strong>→ CENSO recomendado.</strong> N = {s.nPobl} ≤ 100. El censo elimina el error muestral (Hernández-Sampieri, 2018; Kish, 1965).</div>}
              {s.nPobl>100&&<div className="bg-blue-50 border border-blue-200 rounded-xl p-3 text-sm text-blue-800"><strong>→ MUESTRA recomendada.</strong> N = {s.nPobl} {'>'} 100. Se justifica muestreo representativo con Cochran o Krejcie-Morgan.{calc.nKM?` Krejcie & Morgan → n = ${calc.nKM}.`:''}</div>}
              {s.tamConocido==='desconocido'&&<div className="bg-slate-50 border border-slate-200 rounded-xl p-3 text-sm text-slate-700">Población indeterminada — se usará la fórmula de Cochran para población infinita (caso más conservador).</div>}
            </div>
          )}

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
            <p className="font-bold text-slate-800">Contexto espacial y temporal</p>
            <div className="grid grid-cols-2 gap-3">
              <div><p className="text-xs text-slate-500 mb-1">Ubicación / institución / ciudad</p>
                <input className="input text-sm" placeholder="Ej: Lima, Perú"
                  value={s.ubicacion} onChange={e=>set('ubicacion',e.target.value)}/></div>
              <div><p className="text-xs text-slate-500 mb-1">Período de recolección</p>
                <input className="input text-sm" placeholder="Ej: enero–junio 2025"
                  value={s.periodo} onChange={e=>set('periodo',e.target.value)}/></div>
            </div>
          </div>
        </>}

        {/* ═══ PASO 3: MARCO MUESTRAL ═══ */}
        {step===3 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Marco muestral y acceso</h1>
            <p className="text-slate-500 mt-1">La disponibilidad del listado determina el tipo de muestreo posible.</p></div>

          {s.enfoque!=='cualitativo' ? <>
            <div className="space-y-3">
              {[['si','Sí — listado / padrón completo disponible','Habilita muestreo probabilístico. Máximo rigor estadístico.'],
                ['sistematico','Listado disponible pero muy extenso','Permite muestreo sistemático (cada k-ésimo elemento)'],
                ['parcial','Parcialmente — acceso a grupos o registros','Permite muestreo por conglomerados o multietápico'],
                ['no','No existe listado o no tengo acceso','Requiere muestreo no probabilístico bien justificado']].map(([v,t,sub])=>(
                <button key={v} onClick={()=>set('padron',v)} className={`w-full p-4 rounded-2xl border-2 text-left transition-all ${s.padron===v?'border-teal-500 bg-teal-50':'border-slate-200 bg-white hover:border-teal-200'}`}>
                  <p className={`font-bold text-sm ${s.padron===v?'text-teal-800':'text-slate-800'}`}>{t}</p>
                  <p className="text-xs text-slate-500 mt-0.5">{sub}</p>
                </button>
              ))}
            </div>

            {s.padron==='si'&&(
              <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
                <p className="font-bold text-slate-800">¿Tu población tiene subgrupos o estratos relevantes?</p>
                <p className="text-xs text-slate-500">Ej: por género, área de trabajo, nivel educativo, región, tipo de empresa...</p>
                <div className="flex flex-wrap gap-2">
                  {[['ninguno','No, es homogénea'],['2-4','Sí, 2–4 subgrupos'],['5+','Sí, 5 o más subgrupos']].map(([v,t])=>(
                    <Opt key={v} val={v} cur={s.estratos} onClick={()=>set('estratos',v)}>{t}</Opt>
                  ))}
                </div>
                {s.estratos!=='ninguno'&&<InfoBox>Muestreo estratificado: nᵢ = n × (Nᵢ/N). Cada estrato recibe una muestra proporcional a su tamaño. Garantiza representación de todos los subgrupos (Cochran, 1977; Lohr, 2010).</InfoBox>}
              </div>
            )}

            {s.padron&&(
              <div className="bg-teal-50 border border-teal-200 rounded-2xl p-5">
                <p className="text-xs text-teal-500 uppercase font-bold tracking-widest mb-2">Técnica recomendada</p>
                <p className="font-black text-teal-800 text-lg">{sampDec.tecnica}</p>
                <span className={`text-xs font-bold px-2 py-1 rounded-full mt-2 inline-block ${sampDec.tipoMuestreo==='Probabilístico'?'bg-green-100 text-green-700':'bg-amber-100 text-amber-700'}`}>{sampDec.tipoMuestreo}</span>
                <p className="text-xs text-teal-700 mt-2">{sampDec.detalle}</p>
                <p className="text-xs text-teal-500 italic mt-1">{sampDec.ref}</p>
                {sampDec.advertencia&&<WarnBox>{sampDec.advertencia}</WarnBox>}
                <WhyBtn id="tecnica" label="Ver fundamento metodológico">La técnica se determina por la disponibilidad del marco muestral y el objetivo de generalización. El muestreo probabilístico garantiza inferencia estadística; el no probabilístico puede ser válido con criterios explícitos (Saunders et al., 2019; Hernández-Sampieri, 2018).</WhyBtn>
              </div>
            )}
            {s.tipoPob==='oculta'&&<WarnBox><strong>Población oculta o de difícil acceso:</strong> No es factible el muestreo probabilístico sin marco muestral. Use bola de nieve o respondent-driven sampling. Documente las limitaciones de generalización (Heckathorn, 1997; Etikan et al., 2016).</WarnBox>}

          </> : <>
            <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
              <p className="font-bold text-slate-800">¿Cómo accederás a los participantes?</p>
              <div className="flex flex-wrap gap-2">
                {[['directo','Acceso directo'],['intermediario','Intermediario / institución'],['virtual','Contacto virtual / redes'],['cadena','Por referidos / cadena']].map(([v,t])=>(
                  <Opt key={v} val={v} cur={s.accesibilidad} onClick={()=>set('accesibilidad',v)}>{t}</Opt>
                ))}
              </div>
            </div>
            <InfoBox>La accesibilidad a los participantes influye en la técnica de muestreo. En investigación cualitativa, el acceso puede ser progresivo — los primeros participantes pueden facilitar el acceso a otros (Patton, 2015).</InfoBox>
          </>}
        </>}

        {/* ═══ PASO 4: TAMAÑO MUESTRAL ═══ */}
        {step===4 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Determinación del tamaño muestral</h1></div>

          <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-4">
            <p className="text-xs text-indigo-600 uppercase font-bold tracking-widest mb-1">Estrategia metodológica identificada</p>
            <p className="font-black text-indigo-800">{ruta.label}</p>
            <p className="text-xs text-indigo-700 mt-1 leading-relaxed">{ruta.razon}</p>
            <p className="text-xs text-indigo-500 italic mt-1">{ruta.ref}</p>
          </div>

          {ruta.ruta==='censo'?(
            <div className="bg-green-50 border-2 border-green-400 rounded-2xl p-6 text-center">
              <p className="text-6xl font-black text-green-700">{s.nPobl}</p>
              <p className="text-green-700 font-bold mt-2">CENSO — Totalidad de la población</p>
              <p className="text-xs text-green-600 mt-1">N = {s.nPobl} ≤ 100 · Sin error muestral</p>
            </div>
          ):(
            <>
              <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-4">
                <p className="font-bold text-slate-800">Parámetros Cochran (1977)</p>
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <p className="text-xs text-slate-500 mb-2 font-semibold">Nivel de confianza</p>
                    <div className="flex flex-col gap-1.5">
                      {([[1.96,'95%','Estándar'],[2.576,'99%','Alta precisión'],[1.645,'90%','Exploratorio']] as any[]).map(([v,t,sub])=>(
                        <button key={v} onClick={()=>set('z',v)} className={`p-2.5 rounded-xl border-2 transition-all ${s.z===v?'bg-indigo-50 border-indigo-500':'border-slate-200 bg-white'}`}>
                          <span className={`font-black block ${s.z===v?'text-indigo-700':'text-slate-700'}`}>{t}</span>
                          <span className="text-xs text-slate-400">{sub}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500 mb-2 font-semibold">Error (e)</p>
                    <div className="flex flex-col gap-1.5">
                      {([[0.05,'5%','Estándar'],[0.03,'3%','Alta precisión'],[0.10,'10%','Exploratorio']] as any[]).map(([v,t,sub])=>(
                        <button key={v} onClick={()=>set('e',v)} className={`p-2.5 rounded-xl border-2 transition-all ${s.e===v?'bg-indigo-50 border-indigo-500':'border-slate-200 bg-white'}`}>
                          <span className={`font-black block ${s.e===v?'text-indigo-700':'text-slate-700'}`}>{t}</span>
                          <span className="text-xs text-slate-400">{sub}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500 mb-2 font-semibold">Proporción (p)</p>
                    <div className="flex flex-col gap-1.5">
                      {([[0.5,'0.50','Máx. variab.'],[0.3,'0.30',''],[0.7,'0.70','']] as any[]).map(([v,t,sub])=>(
                        <button key={v} onClick={()=>set('p',v)} className={`p-2.5 rounded-xl border-2 transition-all ${s.p===v?'bg-indigo-50 border-indigo-500':'border-slate-200 bg-white'}`}>
                          <span className={`font-black block ${s.p===v?'text-indigo-700':'text-slate-700'}`}>{t}</span>
                          <span className="text-xs text-slate-400">{sub}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
                <div>
                  <p className="text-xs text-slate-500 mb-2 font-semibold">Tasa de no respuesta esperada</p>
                  <div className="flex gap-2">{[[0.10,'10%'],[0.15,'15%'],[0.20,'20%'],[0.25,'25%']].map(([v,t])=>(
                    <Opt key={v} val={v} cur={s.tasaNoResp} onClick={()=>set('tasaNoResp',v)}>{t as string}</Opt>
                  ))}</div>
                </div>
              </div>

              <div className="bg-gradient-to-br from-teal-600 to-indigo-700 rounded-2xl p-6 text-white">
                <p className="text-teal-200 text-xs font-bold uppercase tracking-widest mb-4">Comparativo de métodos</p>
                <div className="grid grid-cols-2 gap-3 mb-4">
                  <div className="bg-white/15 rounded-xl p-3 text-center">
                    <p className="text-xs text-teal-200">Cochran (1977)</p>
                    <p className="text-3xl font-black">{calc.nCochran}</p>
                    <p className="text-xs text-teal-300">{s.nPobl>0?`N=${s.nPobl}`:'Infinita'}</p>
                  </div>
                  {calc.nKM&&<div className="bg-white/15 rounded-xl p-3 text-center">
                    <p className="text-xs text-teal-200">Krejcie & Morgan</p>
                    <p className="text-3xl font-black">{calc.nKM}</p>
                    <p className="text-xs text-teal-300">N={s.nPobl}</p>
                  </div>}
                  {calc.nGPower&&<div className="bg-white/15 rounded-xl p-3 text-center">
                    <p className="text-xs text-teal-200">G*Power</p>
                    <p className="text-3xl font-black text-green-300">{calc.nGPower}</p>
                    <p className="text-xs text-teal-300">{calc.metodoLabel}</p>
                  </div>}
                  {calc.nMetodo&&<div className="bg-white/15 rounded-xl p-3 text-center">
                    <p className="text-xs text-teal-200">Criterio SEM</p>
                    <p className="text-3xl font-black text-yellow-300">{calc.nMetodo}</p>
                  </div>}
                </div>
                <div className="bg-white/20 rounded-xl p-4 border border-white/30">
                  <p className="text-xs text-teal-200 mb-1">n recomendado (criterio más exigente + no respuesta)</p>
                  <p className="text-5xl font-black text-yellow-300">{calc.nFinal}</p>
                  <p className="text-xs text-teal-300 mt-1">Base: {calc.nBase} + {Math.round(s.tasaNoResp*100)}% = {calc.nFinal}</p>
                </div>
              </div>
            </>
          )}
        </>}

        {/* ═══ PASO 5: CRITERIOS ═══ */}
        {step===5 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Criterios de inclusión y exclusión</h1>
            <p className="text-slate-500 mt-1">Definen con precisión quién pertenece a la población accesible. Obligatorios en toda tesis.</p></div>

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-5">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center"><span className="text-green-700 font-black text-sm">+</span></div>
                <p className="font-bold text-slate-800">Criterios de inclusión</p>
              </div>
              <p className="text-xs text-slate-500 mb-2">Condiciones NECESARIAS para pertenecer a la muestra.</p>
              <textarea className="input w-full h-24 text-sm resize-none" placeholder="Ej: Trabajadores activos con antigüedad ≥ 6 meses, mayores de 18 años, con acceso a internet, que hayan interactuado con el sistema al menos 3 veces al mes."
                value={s.inclusion} onChange={e=>set('inclusion',e.target.value)}/>
            </div>
            <div>
              <div className="flex items-center gap-2 mb-2">
                <div className="w-6 h-6 bg-red-100 rounded-full flex items-center justify-center"><span className="text-red-700 font-black text-sm">−</span></div>
                <p className="font-bold text-slate-800">Criterios de exclusión</p>
              </div>
              <p className="text-xs text-slate-500 mb-2">Condiciones que IMPIDEN la participación. No son la negación de los de inclusión.</p>
              <textarea className="input w-full h-24 text-sm resize-none" placeholder="Ej: Trabajadores en período de prueba, personal en licencia médica, directivos de nivel gerencial o superior, participantes en otro estudio simultáneo."
                value={s.exclusion} onChange={e=>set('exclusion',e.target.value)}/>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
            <p className="font-bold text-slate-800">Posibles sesgos a declarar</p>
            <p className="text-xs text-slate-500">Selecciona los que aplican — se incluirán en las limitaciones metodológicas del texto generado.</p>
            <div className="flex flex-wrap gap-2">
              {[['seleccion','Sesgo de selección'],['cobertura','Sesgo de cobertura'],['no_respuesta','Sesgo de no respuesta'],['autoseleccion','Sesgo de autoselección'],['conveniencia','Limitación por conveniencia'],['supervivencia','Sesgo de supervivencia']].map(([v,t])=>(
                <button key={v} onClick={()=>toggleArr('sesgos',v)}
                  className={`px-3 py-2 rounded-xl border-2 text-sm font-semibold transition-all ${(s.sesgos).includes(v)?'bg-red-50 border-red-400 text-red-700':'border-slate-200 text-slate-600 hover:border-red-200 bg-white'}`}>{t}</button>
              ))}
            </div>
          </div>
        </>}

        {/* ═══ PASO 6: RESULTADO FINAL ═══ */}
        {step===6 && <>
          <div><h1 className="text-2xl font-black text-slate-900">Resultado metodológico completo</h1>
            <p className="text-slate-500 mt-1">Sección 3.4 lista para tu tesis.</p></div>

          <div className="grid grid-cols-2 gap-3">
            <div className="bg-white rounded-2xl border border-slate-200 p-4">
              <p className="text-xs text-slate-400 uppercase font-bold tracking-widest mb-1">Técnica de muestreo</p>
              <p className="font-black text-slate-800 text-sm">{sampDec.tecnica}</p>
              <span className={`text-xs font-bold px-2 py-0.5 rounded-full mt-1.5 inline-block ${sampDec.tipoMuestreo==='Probabilístico'?'bg-green-100 text-green-700':'bg-amber-100 text-amber-700'}`}>{sampDec.tipoMuestreo}</span>
            </div>
            <div className="bg-white rounded-2xl border border-slate-200 p-4">
              <p className="text-xs text-slate-400 uppercase font-bold tracking-widest mb-1">Tamaño muestral</p>
              <p className="text-4xl font-black text-teal-700">{ruta.ruta==='censo'?s.nPobl:ruta.ruta==='saturacion'?'Saturación':calc.nFinal}</p>
              <p className="text-xs text-slate-400 mt-1">{ruta.ruta==='censo'?'Censo':ruta.ruta==='saturacion'?'Saturación teórica':`+${Math.round(s.tasaNoResp*100)}% no respuesta`}</p>
            </div>
          </div>

          {ruta.ruta!=='censo'&&ruta.ruta!=='saturacion'&&(
            <div className="bg-white rounded-2xl border border-slate-200 p-4">
              <p className="text-xs text-slate-400 uppercase font-bold tracking-widest mb-2">Desglose del cálculo</p>
              <div className="space-y-1 text-sm">
                <div className="flex justify-between"><span className="text-slate-500">Cochran (1977)</span><span className="font-bold">{calc.nCochran}</span></div>
                {calc.nKM&&<div className="flex justify-between"><span className="text-slate-500">Krejcie & Morgan (1970)</span><span className="font-bold">{calc.nKM}</span></div>}
                {calc.nGPower&&<div className="flex justify-between"><span className="text-slate-500">G*Power — {calc.metodoLabel}</span><span className="font-bold text-indigo-600">{calc.nGPower}</span></div>}
                {calc.nMetodo&&<div className="flex justify-between"><span className="text-slate-500">Criterio SEM</span><span className="font-bold text-indigo-600">{calc.nMetodo}</span></div>}
                <div className="flex justify-between border-t pt-1 font-bold"><span>n base</span><span>{calc.nBase}</span></div>
                <div className="flex justify-between text-teal-700 font-black"><span>+ {Math.round(s.tasaNoResp*100)}% no respuesta</span><span>{calc.nFinal}</span></div>
              </div>
            </div>
          )}

          <div className="bg-white rounded-2xl border border-slate-200 p-5">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2"><BookOpen className="w-4 h-4 text-teal-600"/><p className="font-bold text-slate-800">Texto para tu tesis (Sección 3.4)</p></div>
              <button onClick={()=>{navigator.clipboard.writeText(tesis).then(()=>{setCopied(true);setTimeout(()=>setCopied(false),2500)});}}
                className="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg border border-slate-200 hover:bg-slate-50 transition text-slate-600">
                {copied?<><Check className="w-3.5 h-3.5 text-green-500"/>Copiado</>:<><Copy className="w-3.5 h-3.5"/>Copiar</>}
              </button>
            </div>
            <div className="bg-slate-50 rounded-xl p-4 text-sm text-slate-700 leading-relaxed whitespace-pre-wrap border border-slate-200 max-h-96 overflow-y-auto font-serif">{tesis}</div>
          </div>

          <button onClick={save} className="w-full bg-teal-600 hover:bg-teal-700 text-white font-bold py-3.5 rounded-2xl transition flex items-center justify-center gap-2">
            Guardar y volver al dashboard <ChevronRight className="w-4 h-4"/>
          </button>
        </>}

        {/* Navegación */}
        {step<6 && (
          <div className="flex justify-between pt-2">
            <button onClick={()=>step>0?setStep(step-1):router.push('/dashboard')}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl border border-slate-200 font-semibold text-slate-600 hover:bg-slate-100 transition text-sm">
              <ArrowLeft className="w-4 h-4"/>{step===0?'Dashboard':'Atrás'}
            </button>
            <button onClick={()=>setStep(step+1)}
              className="flex items-center gap-2 bg-teal-600 hover:bg-teal-700 text-white font-bold px-6 py-2.5 rounded-xl transition text-sm">
              Continuar <ChevronRight className="w-4 h-4"/>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
