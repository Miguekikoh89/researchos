'use client';
import { useState } from 'react';
import { Activity, BarChart2, TrendingUp, BookOpen, Shield, ChevronLeft, ChevronRight, ChevronDown, ChevronUp } from 'lucide-react';
import type { WizardState } from '@/app/analysis/new/page';

interface Props { state: WizardState; onNext: () => void; onBack: () => void; }

function dt(text: any): string {
  if (!text) return '';
  let s = String(text);
  // Fix <U+00F3> style unicode
  s = s.replace(/<U[+]([0-9A-Fa-f]{4})>/g, (_: string, hex: string) => String.fromCharCode(parseInt(hex, 16)));
  return s
    .replace(/<c3><b3>/g,'ó').replace(/<c3><a1>/g,'á').replace(/<c3><a9>/g,'é')
    .replace(/<c3><ad>/g,'í').replace(/<c3><ba>/g,'ú').replace(/<c3><b1>/g,'ñ')
    .replace(/<c3><93>/g,'Ó').replace(/<c3><81>/g,'Á').replace(/<c3><89>/g,'É')
    .replace(/<cf><81>/g,'ρ').replace(/<ce><b1>/g,'α')
    .replace(/<cf><87>/g,'χ').replace(/<c2><b2>/g,'²').replace(/<c2><b3>/g,'³')
    .replace(/<e2><89><a4>/g,'≤').replace(/<e2><89><a5>/g,'≥')
    .replace(/<e2><80><93>/g,'–').replace(/<e2><9c><97>/g,'✗').replace(/<e2><9c><93>/g,'✓')
    .replace(/<e2><89><a4>/g,'\u2264').replace(/<e2><89><a5>/g,'\u2265').replace(/<e2><89><a0>/g,'\u2260')
    .replace(/<e2><9c><97>/g,'\u2717').replace(/<e2><9c><93>/g,'\u2713').replace(/<e2><80><93>/g,'\u2013').replace(/<e2><82><80>/g,'₀');
}

function sa(val: any): any[] {
  if (Array.isArray(val)) return val;
  if (val && typeof val === 'object') return Object.values(val);
  return [];
}

function Section({ title, icon: Icon, color='indigo', defaultOpen=true, children }: {
  title: string; icon: any; color?: string; defaultOpen?: boolean; children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const bc: Record<string,string> = { indigo:'border-indigo-200 bg-indigo-50/40', teal:'border-teal-200 bg-teal-50/40', amber:'border-amber-200 bg-amber-50/40', blue:'border-blue-200 bg-blue-50/40', purple:'border-purple-200 bg-purple-50/40', green:'border-green-200 bg-green-50/40' };
  const ic: Record<string,string> = { indigo:'text-indigo-600', teal:'text-teal-600', amber:'text-amber-600', blue:'text-blue-600', purple:'text-purple-600', green:'text-green-600' };
  return (
    <div className={`rounded-2xl border ${bc[color]||bc.indigo} overflow-hidden`}>
      <button onClick={() => setOpen(!open)} className="w-full flex items-center justify-between px-5 py-4 hover:bg-white/40 transition">
        <div className="flex items-center gap-3"><Icon className={`w-5 h-5 ${ic[color]}`}/><span className="font-semibold text-slate-800">{title}</span></div>
        {open ? <ChevronUp className="w-4 h-4 text-slate-400"/> : <ChevronDown className="w-4 h-4 text-slate-400"/>}
      </button>
      {open && <div className="px-5 pb-5 space-y-4">{children}</div>}
    </div>
  );
}

function Tbl({ headers, rows }: { headers: string[]; rows: any[][] }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 border-b border-slate-200"><tr>{headers.map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600 whitespace-nowrap">{h}</th>)}</tr></thead>
        <tbody>{sa(rows).map((row,i)=><tr key={i} className="border-b border-slate-100 hover:bg-slate-50">{sa(row).map((cell,j)=><td key={j} className="px-3 py-2 text-slate-700">{cell}</td>)}</tr>)}</tbody>
      </table>
    </div>
  );
}

function KPI({ label, value }: { label: string; value: any }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-3 text-center">
      <p className="text-xs text-slate-500 mb-1">{label}</p>
      <p className="font-bold text-indigo-700">{value}</p>
    </div>
  );
}

const TABS = [
  { id:'resumen', label:'Resumen', icon:BookOpen },
  { id:'normalidad', label:'Normalidad', icon:Activity },
  { id:'confiabilidad', label:'Confiabilidad', icon:Shield },
  { id:'correlacion', label:'Correlación', icon:TrendingUp },
  { id:'descriptivos', label:'Descriptivos', icon:BarChart2 },
  { id:'baremos', label:'Baremos', icon:BarChart2 },
  { id:'comparacion', label:'Comparación', icon:Activity },
  { id:'anova', label:'ANOVA', icon:BarChart2 },
  { id:'regresion', label:'Regresión', icon:TrendingUp },
  { id:'logistica', label:'Logística', icon:TrendingUp },
  { id:'chi', label:'Chi²', icon:Activity },
  { id:'instrumentos', label:'Validación', icon:Shield },
];

export default function StepResults({ state, onNext, onBack }: Props) {
  const r = state.results;
  const [tab, setTab] = useState('resumen');
  if (!r) return <div className="py-12 text-center text-slate-500">No hay resultados. Vuelve al paso anterior.</div>;

  const method = r.method ?? 'spearman';
  const sym = method === 'pearson' ? 'r' : 'ρ';
  const corrs = sa(r.correlations);
  const mainCorr = corrs.find((c:any)=>c.type==='general');
  const dimCorrs = corrs.filter((c:any)=>c.type!=='general');

  const badge = r.instruments ? 'Validación de instrumento' : r.ttest ? r.ttest.auto_selected : r.anova ? r.anova.auto_selected : r.regression ? `R² = ${r.regression?.R2}` : r.logistic ? 'Logística' : r.chi_square ? 'Chi-cuadrado' : method==='pearson' ? 'r de Pearson' : 'Rho de Spearman';
  const badgeColor = r.instruments ? 'bg-cyan-100 text-cyan-700' : r.ttest ? 'bg-purple-100 text-purple-700' : r.anova ? 'bg-amber-100 text-amber-700' : r.regression ? 'bg-green-100 text-green-700' : r.logistic ? 'bg-pink-100 text-pink-700' : r.chi_square ? 'bg-orange-100 text-orange-700' : 'bg-indigo-100 text-indigo-700';

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div><h2 className="text-2xl font-bold text-slate-800">Resultados del análisis</h2><p className="text-slate-500 mt-1">Resumen estadístico completo con interpretación APA 7.</p></div>
        <span className={`text-sm font-semibold px-4 py-1.5 rounded-full ${badgeColor}`}>{badge}</span>
      </div>

      {sa(r.warnings).length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-800">
          <p className="font-semibold mb-1">Advertencias metodológicas</p>
          {sa(r.warnings).map((w:string,i:number)=><p key={i}>• {dt(w)}</p>)}
        </div>
      )}

      <div className="flex gap-1 bg-slate-100 p-1 rounded-xl overflow-x-auto">
        {TABS.map(t=>(
          <button key={t.id} onClick={()=>setTab(t.id)} className={`flex items-center gap-1.5 px-3 py-2 rounded-lg text-sm font-medium whitespace-nowrap transition-all ${tab===t.id?'bg-white text-indigo-700 shadow-sm':'text-slate-500 hover:text-slate-700'}`}>
            <t.icon className="w-4 h-4"/>{t.label}
          </button>
        ))}
      </div>

      {/* RESUMEN */}
      {tab==='resumen' && (
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-4">
            {[{label:'Participantes',value:r.diagnostic?.n_rows??'-',sub:'observaciones'},{label:'Variables',value:r.diagnostic?.n_cols??'-',sub:'columnas'},{label:'Datos perdidos',value:`${r.diagnostic?.missing_pct??0}%`,sub:'del total'}].map(k=>(
              <div key={k.label} className="bg-white rounded-xl border border-slate-200 p-4 text-center">
                <p className="text-xs font-semibold text-slate-500 uppercase">{k.label}</p>
                <p className="text-3xl font-bold text-indigo-700 my-1">{k.value}</p>
                <p className="text-xs text-slate-400">{k.sub}</p>
              </div>
            ))}
          </div>
          {mainCorr && (
            <div className="bg-gradient-to-br from-indigo-600 to-purple-700 rounded-2xl p-6 text-white">
              <p className="text-indigo-200 text-sm font-semibold uppercase mb-1">Resultado principal</p>
              <p className="font-bold text-lg">{dt(mainCorr.var_a)} × {dt(mainCorr.var_b)}</p>
              <div className="flex items-baseline gap-3 mt-2">
                <span className="text-5xl font-black">{sym} = {mainCorr.r_apa}</span>
                <span className="text-indigo-200">p {mainCorr.p_apa}</span>
                <span className="text-yellow-300 text-xl font-bold">{mainCorr.stars}</span>
              </div>
              <div className="flex flex-wrap gap-2 mt-3">
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">Correlación {dt(mainCorr.magnitude)}</span>
                <span className="bg-white/20 px-3 py-1 rounded-full text-sm">n = {mainCorr.n}</span>
                <span className={`px-3 py-1 rounded-full text-sm font-semibold ${mainCorr.significant?'bg-green-400/30':'bg-red-400/30'}`}>{dt(mainCorr.decision)}</span>
              </div>
              {mainCorr.ci_lower!=null&&<p className="text-indigo-200 text-xs mt-2">IC 95%: [{mainCorr.ci_lower}, {mainCorr.ci_upper}] | Potencia: {mainCorr.power?`${Math.round(mainCorr.power*100)}%`:'-'}</p>}
              {mainCorr.text_apa&&<div className="mt-4 bg-white/10 rounded-xl p-4"><p className="text-xs font-bold text-indigo-200 uppercase mb-1">Redacción APA 7</p><p className="text-sm leading-relaxed italic">{dt(mainCorr.text_apa)}</p></div>}
            </div>
          )}
          {dimCorrs.length>0&&(
            <div className="space-y-2">
              <p className="text-sm font-semibold text-slate-700">Correlaciones por dimensiones</p>
              {dimCorrs.map((c:any,i:number)=>(
                <div key={i} className="bg-white rounded-xl border border-slate-200 p-4 flex items-center justify-between">
                  <div><p className="font-medium text-slate-800">{dt(c.var_a)} × {dt(c.var_b)}</p><p className="text-xs text-slate-500">Magnitud: {dt(c.magnitude)} · n = {c.n}</p></div>
                  <div className="text-right"><p className="text-xl font-bold text-indigo-700">{sym} = {c.r_apa}<span className="text-yellow-500 ml-1">{c.stars}</span></p><p className="text-xs text-slate-500">p {c.p_apa}</p></div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* NORMALIDAD */}
      {tab==='normalidad' && (
        <Section title="Prueba de normalidad" icon={Activity} color="blue">
          <Tbl headers={['Variable','n','SW (W)','p (SW)','KS (D)','p (KS)','Decisión']}
            rows={sa(r.normality).map((row:any)=>[dt(String(row.variable||'')),row.n,row.sw_statistic,
              <span className={row.sw_p<0.05?'text-red-600 font-semibold':''}>{row.sw_p}</span>,
              row.ks_statistic,
              <span className={row.ks_p<0.05?'text-red-600 font-semibold':''}>{row.ks_p}</span>,
              <span className={row.decision==='No normal'?'text-red-600 font-semibold':'text-green-600'}>{row.decision}</span>
            ])} />
          {r.interpretations?.normality_text&&<p className="text-sm text-slate-700 bg-white rounded-xl p-4 border border-slate-200">{dt(r.interpretations.normality_text)}</p>}
        </Section>
      )}

      {/* CONFIABILIDAD */}
      {tab==='confiabilidad' && (
        <div className="space-y-4">
          <Section title="Alfa de Cronbach" icon={Shield} color="indigo">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {sa(r.reliability).map((cr:any,i:number)=>(
                <div key={i} className={`rounded-xl border-2 p-4 ${cr.interpretation==='Excelente'?'border-green-300 bg-green-50':cr.interpretation==='Bueno'?'border-blue-300 bg-blue-50':cr.interpretation==='Aceptable'?'border-amber-300 bg-amber-50':'border-red-300 bg-red-50'}`}>
                  <p className="font-bold text-slate-800 mb-1">{dt(String(cr.name||""))}</p>
                  <p className="text-2xl font-black">α = {cr.alpha}<span className="text-sm font-normal text-slate-500 ml-2">IC [{cr.ci_lower}, {cr.ci_upper}]</span></p>
                  <p className="text-sm text-slate-600 mt-1">{cr.interpretation} · k={cr.k} ítems · n={cr.n}</p>
                  {cr.omega&&<div className="mt-2 pt-2 border-t border-slate-200 grid grid-cols-3 gap-1 text-xs text-slate-500"><span>ω = {cr.omega.omega_t}</span><span>α std = {cr.alpha_std}</span><span>r̄ = {cr.inter_item_mean}</span></div>}
                </div>
              ))}
            </div>
          </Section>
          {sa(r.reliability).filter((cr:any)=>cr.item_stats&&Object.keys(cr.item_stats).length>0).map((cr:any,idx:number)=>(
            <Section key={idx} title={`Estadísticos elemento-total — ${dt(String(cr.name||""))}`} icon={Shield} color="purple" defaultOpen={idx===0}>
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-xs">
                  <thead className="bg-slate-50 border-b border-slate-200"><tr>{['Ítem','M','DE','M escala s/ítem','r ítem-total','α si elimina','Interp.'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600 whitespace-nowrap">{h}</th>)}</tr></thead>
                  <tbody>{sa(Object.values(cr.item_stats||{})).map((it:any,i:number)=>(
                    <tr key={i} className={`border-b border-slate-100 ${it.alpha_if_deleted>cr.alpha?'bg-amber-50':'hover:bg-slate-50'}`}>
                      <td className="px-3 py-1.5 font-bold">{it.item}</td>
                      <td className="px-3 py-1.5">{it.mean}</td><td className="px-3 py-1.5">{it.sd}</td>
                      <td className="px-3 py-1.5">{it.mean_scale_del}</td>
                      <td className="px-3 py-1.5 font-semibold text-indigo-700">{it.r_item_total_corr}</td>
                      <td className={`px-3 py-1.5 font-semibold ${it.alpha_if_deleted>cr.alpha?'text-amber-600':''}`}>{it.alpha_if_deleted}</td>
                      <td className="px-3 py-1.5 text-slate-500">{it.interpretation_del}</td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            </Section>
          ))}
        </div>
      )}

      {/* CORRELACION */}
      {tab==='correlacion' && (
        <div className="space-y-4">
          {mainCorr&&(
            <Section title={`Objetivo general: ${dt(mainCorr.var_a)} × ${dt(mainCorr.var_b)}`} icon={TrendingUp} color="indigo">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([{label:'Coeficiente',value:`${sym} = ${mainCorr.r_apa}${mainCorr.stars}`},{label:'p-valor',value:`p ${mainCorr.p_apa}`},{label:'IC 95%',value:mainCorr.ci_lower!=null?`[${mainCorr.ci_lower}, ${mainCorr.ci_upper}]`:'-'},{label:'Potencia',value:mainCorr.power?`${Math.round(mainCorr.power*100)}%`:'-'}] as {label:string,value:any}[]).map(k=>(
                  <KPI key={k.label} label={k.label} value={k.value}/>
                ))}
              </div>
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-200">
                <p className="text-xs font-bold text-slate-500 uppercase mb-2">Decisión: {dt(mainCorr.decision)}</p>
                <p className="text-sm text-slate-700 leading-relaxed italic">{dt(mainCorr.text_apa)}</p>
              </div>
            </Section>
          )}
          {dimCorrs.length>0&&(
            <Section title="Objetivos específicos" icon={TrendingUp} color="teal">
              <div className="space-y-3">
                {dimCorrs.map((c:any,i:number)=>(
                  <div key={i} className="bg-white rounded-xl border border-slate-200 p-4">
                    <div className="flex items-center justify-between mb-2">
                      <p className="font-semibold text-slate-800">{dt(c.var_a)} × {dt(c.var_b)}</p>
                      <span className={`text-xs px-3 py-1 rounded-full font-semibold ${c.significant?'bg-green-100 text-green-700':'bg-slate-100 text-slate-600'}`}>{dt(c.decision)}</span>
                    </div>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                      <div><span className="text-slate-500">Coef. </span><span className="font-bold text-indigo-700">{sym} = {c.r_apa}{c.stars}</span></div>
                      <div><span className="text-slate-500">p </span><span className="font-medium">{c.p_apa}</span></div>
                      <div><span className="text-slate-500">Magnitud </span><span className="font-medium">{dt(c.magnitude)}</span></div>
                      <div><span className="text-slate-500">n </span><span className="font-medium">{c.n}</span></div>
                    </div>
                    {c.ci_lower!=null&&<p className="text-xs text-slate-400 mt-1">IC 95%: [{c.ci_lower}, {c.ci_upper}] | Potencia: {c.power?`${Math.round(c.power*100)}%`:'-'}</p>}
                  </div>
                ))}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* DESCRIPTIVOS */}
      {tab==='descriptivos' && (
        <Section title="Estadística descriptiva" icon={BarChart2} color="green">
          <Tbl headers={['Variable','n','M','DE','Mín','Máx','Asimetría']}
            rows={sa(r.descriptives).map((row:any)=>[<span className="font-medium">{dt(String(row.variable||""))}</span>,row.n,row.mean,row.sd,row.min,row.max,row.skewness])} />
        </Section>
      )}

      {/* BAREMOS */}
      {tab==='baremos' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[r.baremoA,r.baremoB].filter(Boolean).map((br:any,idx:number)=>(
            <Section key={idx} title={`Baremo — ${dt(String(br.variable||""))}`} icon={BarChart2} color="amber">
              <Tbl headers={['Nivel','Desde','Hasta']} rows={sa(br.table).map((row:any)=>[<span className="font-semibold">{row.nivel}</span>,row.desde,row.hasta])} />
              {sa(br.frequencies).length>0&&<>
                <p className="text-sm font-semibold text-slate-700">Distribución de niveles</p>
                <Tbl headers={['Nivel','f','%','% acumulado']} rows={sa(br.frequencies).map((row:any)=>[<span className="font-semibold">{row.nivel}</span>,row.f,`${row.pct}%`,`${row.pct_ac}%`])} />
                {br.levels_text&&<p className="text-xs text-slate-500 italic">{dt(br.levels_text)}</p>}
              </>}
            </Section>
          ))}
        </div>
      )}

      {/* COMPARACION */}
      {tab==='comparacion' && r.ttest && (
        <div className="space-y-4">
          <Section title={`Comparación — ${r.ttest.auto_selected||r.ttest.test_type}`} icon={Activity} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {(r.ttest.test_type==='mann_whitney'?[{label:'U Mann-Whitney',value:r.ttest.U},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'r rango biserial',value:r.ttest.r_rb},{label:'Tamaño efecto',value:r.ttest.r_interpret}]:r.ttest.test_type==='wilcoxon_pareado'?[{label:'W Wilcoxon',value:r.ttest.W},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'r rango biserial',value:r.ttest.r_rb},{label:'Tamaño efecto',value:r.ttest.r_interpret}]:[{label:'t',value:r.ttest.t},{label:'gl',value:r.ttest.df},{label:'p-valor',value:`p ${r.ttest.p_apa}`},{label:'d Cohen',value:`${r.ttest.d} (${r.ttest.d_interpret})`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            {r.ttest.ci_lower!=null&&<p className="text-sm text-slate-600">IC 95%: [{r.ttest.ci_lower}, {r.ttest.ci_upper}]</p>}
            <div className={`rounded-xl p-4 border ${r.ttest.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.ttest.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">α = {r.ttest.alpha} | Método: {r.ttest.auto_selected}</p>
            </div>
          </Section>
          {r.ttest.descriptives&&(
            <Section title="Descriptivos por grupo" icon={BarChart2} color="teal">
              <Tbl headers={['Grupo','n','M','DE','Mediana/SE']}
                rows={[r.ttest.descriptives.group1,r.ttest.descriptives.group2].filter(Boolean).map((g:any)=>[<span className="font-semibold">{dt(String(g.name||""))}</span>,g.n,g.mean,g.sd,g.median??g.se??'-'])} />
            </Section>
          )}
          {r.ttest.levene&&(
            <Section title="Prueba de Levene" icon={Shield} color="amber">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'F Levene',value:r.ttest.levene.F},{label:'p-valor',value:r.ttest.levene.p},{label:'Varianzas',value:r.ttest.levene.equal_variances?'Iguales':'Desiguales'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
          {r.ttest.normality&&(
            <Section title="Normalidad por grupo" icon={Activity} color="blue">
              <Tbl headers={['Grupo','SW (W)','p','¿Normal?']}
                rows={[{name:r.ttest.descriptives?.group1?.name,data:r.ttest.normality.group1},{name:r.ttest.descriptives?.group2?.name,data:r.ttest.normality.group2}].filter(x=>x.data).map((g:any)=>[
                  g.name??'-', g.data?.W, g.data?.p,
                  <span className={g.data?.normal?'text-green-600':'text-red-600 font-semibold'}>{g.data?.normal?'Sí':'No'}</span>
                ])} />
            </Section>
          )}
        </div>
      )}

      {/* ANOVA */}
      {tab==='anova' && r.anova && (
        <div className="space-y-4">
          <Section title={`ANOVA — ${r.anova.auto_selected||r.anova.test_type}`} icon={BarChart2} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {(r.anova.test_type==='anova'?[{label:'F',value:r.anova.F},{label:`gl (${r.anova.df_between},${r.anova.df_within})`,value:'-'},{label:'p-valor',value:`p ${r.anova.p_apa}`},{label:`η² = ${r.anova.eta2}`,value:r.anova.eta2_interpret}]:[{label:'H Kruskal-Wallis',value:r.anova.H},{label:`gl = ${r.anova.df}`,value:'-'},{label:'p-valor',value:`p ${r.anova.p_apa}`},{label:`ε² = ${r.anova.epsilon2}`,value:r.anova.epsilon2_interpret}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.anova.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.anova.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">Método: {r.anova.auto_selected} | Post-hoc: {r.anova.posthoc_method}</p>
            </div>
          </Section>
          {r.anova.test_type==='anova'&&(
            <Section title="Tabla ANOVA" icon={BarChart2} color="indigo">
              <Tbl headers={['Fuente','SC','gl','MC','F','p']} rows={[
                ['Entre grupos',r.anova.ss_between,r.anova.df_between,r.anova.ms_between,r.anova.F,`p ${r.anova.p_apa}`],
                ['Dentro grupos',r.anova.ss_within,r.anova.df_within,r.anova.ms_within,'-','-'],
                ['Total',r.anova.ss_total,(r.anova.df_between||0)+(r.anova.df_within||0),'-','-','-'],
              ]}/>
            </Section>
          )}
          {sa(r.anova.descriptives).length>0&&(
            <Section title="Descriptivos por grupo" icon={BarChart2} color="teal">
              <Tbl headers={['Grupo','n','M','DE',r.anova.test_type==='anova'?'SE':'Mediana']}
                rows={sa(r.anova.descriptives).map((g:any)=>[<span className="font-semibold">{dt(String(g.group||""))}</span>,g.n,g.mean,g.sd,g.se??g.median??'-'])} />
            </Section>
          )}
          {r.anova.test_type==='anova'&&sa(r.anova.posthoc).length>0&&(
            <Section title={`Post-hoc: ${r.anova.posthoc_method}`} icon={Activity} color="amber">
              <Tbl headers={['Comparación','Diferencia','IC inf','IC sup','p ajustado','Sig.']}
                rows={sa(r.anova.posthoc).map((row:any)=>[row.comparison,row.diff,row.ci_lower,row.ci_upper,row.p_adj,<span className={row.significant?'text-green-600 font-semibold':'text-slate-400'}>{row.significant?'Sí *':'No'}</span>])} />
            </Section>
          )}
          {r.anova.test_type==='kruskal_wallis'&&sa(r.anova.posthoc).length>0&&(
            <Section title="Post-hoc: Dunn (Bonferroni)" icon={Activity} color="amber">
              <Tbl headers={['Comparación','z','p sin ajuste','p Bonferroni','Sig.']}
                rows={sa(r.anova.posthoc).map((row:any)=>[row.comparison,row.z,row.p_raw,row.p_bonf,<span className={row.significant?'text-green-600 font-semibold':'text-slate-400'}>{row.significant?'Sí *':'No'}</span>])} />
            </Section>
          )}
          {r.anova.levene&&(
            <Section title="Prueba de Levene" icon={Shield} color="blue">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'F Levene',value:r.anova.levene.F},{label:'p-valor',value:r.anova.levene.p},{label:'Varianzas',value:r.anova.levene.equal_variances?'Iguales':'Desiguales'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* REGRESION */}
      {tab==='regresion' && r.regression && (
        <div className="space-y-4">
          <Section title={`Regresión ${r.regression.k===1?'simple':'múltiple'}`} icon={TrendingUp} color="indigo">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'R',value:r.regression.R},{label:'R²',value:`${r.regression.R2} (${r.regression.R2_interpret})`},{label:'R² ajustado',value:r.regression.R2_adj},{label:'F',value:`${r.regression.F} (p ${r.regression.p_apa})`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.regression.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.regression.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">n = {r.regression.n} | SE = {r.regression.SE_est}</p>
            </div>
          </Section>
          <Section title="Coeficientes" icon={TrendingUp} color="teal">
            <Tbl headers={['Variable','B','SE','β','t','p','IC inf','IC sup','Sig.']}
              rows={sa(r.regression.coefficients).map((c:any)=>[<span className="font-semibold">{c.term}</span>,c.B,c.SE,c.beta??'-',c.t,`p ${c.p_apa}`,c.ci_lower,c.ci_upper,<span className={c.significant?'text-green-600 font-bold':'text-slate-400'}>{c.significant?'*':''}</span>])} />
          </Section>
          {sa(r.regression.vif).length>0&&(
            <Section title="VIF — Multicolinealidad" icon={Shield} color="amber">
              <Tbl headers={['Variable','VIF','Interpretación']}
                rows={sa(r.regression.vif).map((v:any)=>[v.term,<span className={v.vif>=5?'text-red-600 font-bold':'text-green-600'}>{v.vif}</span>,v.interpretation])} />
            </Section>
          )}
          {r.regression.assumptions&&(
            <Section title="Verificación de supuestos" icon={Activity} color="blue">
              {(()=>{
                const a=r.regression.assumptions;
                const rows=[
                  {label:'Normalidad residuos (SW)',result:`W = ${a.normality_residuals?.W}, p = ${a.normality_residuals?.p}`,ok:a.normality_residuals?.ok,text:a.normality_residuals?.interpretation},
                  {label:'Independencia (Durbin-Watson)',result:`DW = ${a.independence?.dw}`,ok:a.independence?.ok,text:a.independence?.interpretation},
                  {label:'Homocedasticidad (Breusch-Pagan)',result:`p = ${a.homoscedasticity?.p}`,ok:a.homoscedasticity?.ok,text:a.homoscedasticity?.interpretation},
                  {label:'Outliers influyentes (Cook)',result:`n = ${a.influential_cases?.n_outliers}`,ok:a.influential_cases?.ok,text:a.influential_cases?.interpretation},
                  {label:'Especificación (RESET)',result:`p = ${a.model_specification?.p}`,ok:a.model_specification?.ok,text:a.model_specification?.interpretation},
                ];
                return <Tbl headers={['Supuesto','Resultado','Estado']} rows={rows.map(r=>[r.label,r.result,<span className={r.ok?'text-green-600':'text-red-600 font-semibold'}>{r.text}</span>])}/>;
              })()}
            </Section>
          )}
        </div>
      )}

      {/* LOGISTICA */}
      {tab==='logistica' && r.logistic && (
        <div className="space-y-4">
          <Section title={`Regresión logística ${r.logistic.test_type==='logistica_binaria'?'binaria':'ordinal'}`} icon={TrendingUp} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'R² Nagelkerke',value:`${r.logistic.r2_nagelkerke} (${r.logistic.r2_interpret})`},{label:'R² Cox-Snell',value:r.logistic.r2_cox_snell},{label:'-2LL ratio',value:r.logistic.ll_ratio},{label:'p-valor',value:`p ${r.logistic.p_apa}`}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            <div className={`rounded-xl p-4 border ${r.logistic.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.logistic.decision)}</p>
            </div>
          </Section>
          <Section title="Coeficientes y Odds Ratio" icon={TrendingUp} color="teal">
            <Tbl headers={['Variable','B','SE','Wald','p','OR','IC OR inf','IC OR sup','Sig.']}
              rows={sa(r.logistic.coefficients).map((c:any)=>[<span className="font-semibold">{c.term}</span>,c.B,c.SE,c.Wald,`p ${c.p_apa}`,<span className="font-bold text-indigo-700">{c.OR}</span>,c.OR_ci_lower,c.OR_ci_upper,<span className={c.significant?'text-green-600 font-bold':'text-slate-400'}>{c.significant?'*':''}</span>])} />
          </Section>
          {r.logistic.hosmer_lemeshow&&(
            <Section title="Hosmer-Lemeshow" icon={Shield} color="green">
              <div className="grid grid-cols-3 gap-3">
                {([{label:'χ²',value:r.logistic.hosmer_lemeshow.chi2},{label:'gl',value:r.logistic.hosmer_lemeshow.df},{label:'p-valor',value:r.logistic.hosmer_lemeshow.p}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              <p className={`text-sm font-semibold ${r.logistic.hosmer_lemeshow.ok?'text-green-600':'text-red-600'}`}>{r.logistic.hosmer_lemeshow.interpretation}</p>
            </Section>
          )}
          {r.logistic.classification&&(
            <Section title="Tabla de clasificación" icon={BarChart2} color="amber">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([{label:'Accuracy',value:`${r.logistic.classification.overall_pct}%`},{label:'Sensibilidad',value:r.logistic.classification.sensitivity},{label:'Especificidad',value:r.logistic.classification.specificity},{label:'Punto corte',value:'0.50'}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
            </Section>
          )}
        </div>
      )}

      {/* CHI-CUADRADO */}
      {tab==='chi' && r.chi_square && (
        <div className="space-y-4">
          <Section title={`Chi-cuadrado — ${r.chi_square.method_used}`} icon={Activity} color="purple">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {([{label:'χ²',value:r.chi_square.chi2},{label:`gl = ${r.chi_square.df}`,value:`p ${r.chi_square.p_apa}`},{label:'V de Cramer',value:r.chi_square.v_cramer},{label:'Tamaño efecto',value:r.chi_square.v_interpret}] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
            </div>
            {r.chi_square.phi&&<p className="text-sm text-slate-600">Phi = {r.chi_square.phi} | n = {r.chi_square.n} | Tabla {r.chi_square.r}×{r.chi_square.c}</p>}
            {r.chi_square.chi2_yates && typeof r.chi_square.chi2_yates === 'number' && <p className="text-sm text-slate-600">χ² Yates = {r.chi_square.chi2_yates} | p = {r.chi_square.p_yates}</p>}
            {r.chi_square.p_fisher && typeof r.chi_square.p_fisher === 'number' && <p className="text-sm text-slate-600">Fisher exacto: p = {r.chi_square.p_fisher}{typeof r.chi_square.or_fisher === 'number' ? ` | OR = ${r.chi_square.or_fisher}` : ''}</p>}
            <div className={`rounded-xl p-4 border ${r.chi_square.significant?'bg-green-50 border-green-200':'bg-slate-50 border-slate-200'}`}>
              <p className="font-semibold">{dt(r.chi_square.decision)}</p>
              <p className="text-xs text-slate-500 mt-1">{r.chi_square.assumption_note}</p>
            </div>
          </Section>
          {sa(r.chi_square.contingency_table).length>0&&(
            <Section title="Tabla de contingencia" icon={BarChart2} color="teal">
              {(()=>{
                const rows=sa(r.chi_square.row_names);
                const cols=sa(r.chi_square.col_names);
                const cells=sa(r.chi_square.contingency_table);
                const getCell=(row:string,col:string)=>cells.find((c:any)=>c.row===row&&c.col===col);
                return (
                  <div className="overflow-x-auto rounded-xl border border-slate-200">
                    <table className="w-full text-sm">
                      <thead className="bg-slate-50 border-b border-slate-200"><tr>
                        <th className="px-3 py-2"></th>
                        {cols.map((col:string)=><th key={col} className="px-3 py-2 text-center font-semibold text-slate-600">{col}</th>)}
                        <th className="px-3 py-2 text-center font-semibold text-slate-600">Total</th>
                      </tr></thead>
                      <tbody>
                        {rows.map((row:string,i:number)=>(
                          <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                            <td className="px-3 py-2 font-semibold text-slate-800">{row}</td>
                            {cols.map((col:string)=>{const cell=getCell(row,col);return <td key={col} className="px-3 py-2 text-center"><div className="font-medium">{cell?.observed??0}</div><div className="text-xs text-slate-400">({cell?.expected??0})</div></td>;})}
                            <td className="px-3 py-2 text-center font-semibold text-indigo-700">{cols.reduce((s:number,col:string)=>{const c=getCell(row,col);return s+(c?.observed??0);},0)}</td>
                          </tr>
                        ))}
                        <tr className="bg-slate-50 border-t border-slate-200">
                          <td className="px-3 py-2 font-semibold">Total</td>
                          {cols.map((col:string)=><td key={col} className="px-3 py-2 text-center font-semibold">{rows.reduce((s:number,row:string)=>{const c=getCell(row,col);return s+(c?.observed??0);},0)}</td>)}
                          <td className="px-3 py-2 text-center font-bold text-indigo-700">{r.chi_square.n}</td>
                        </tr>
                      </tbody>
                    </table>
                    <p className="text-xs text-slate-400 p-3">Observadas. Entre paréntesis: esperadas.</p>
                  </div>
                );
              })()}
            </Section>
          )}
        </div>
      )}

      {/* INSTRUMENTOS */}
      {tab === 'instrumentos' && r.instruments && (
        <div className="space-y-4 animate-fade-in">

          {/* KMO + Bartlett */}
          {r.instruments.kmo && (
            <Section title="KMO y Prueba de Bartlett" icon={Shield} color="indigo">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([
                  {label:'KMO', value: r.instruments.kmo.kmo_overall},
                  {label:'Interpretación', value: r.instruments.kmo.kmo_interpret},
                  {label:'Bartlett χ²', value: r.instruments.kmo.bartlett_chi2},
                  {label:'p-valor', value: `p ${r.instruments.kmo.bartlett_p_apa}`},
                ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              <div className={`rounded-xl p-4 border ${r.instruments.kmo.factorizable?'bg-green-50 border-green-200':'bg-red-50 border-red-200'}`}>
                <p className="font-semibold text-sm">{r.instruments.kmo.factorizable ? '✅ Datos factorizables — Procede con AFE/AFC' : '❌ Datos no factorizables — Revisar instrumento'}</p>
              </div>
            </Section>
          )}

          {/* Normalidad por ítem */}
          {r.instruments.normality?.por_item && (
            <Section title="Normalidad por ítem (Asimetría y Curtosis)" icon={Activity} color="blue">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Ítem','n','M','DE','Asimetría','Curtosis','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.normality?.por_item).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className={`border-b border-slate-100 ${row.no_normal?'bg-amber-50':''}`}>
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        <td className="px-3 py-2">{row.n}</td>
                        <td className="px-3 py-2">{row.media}</td>
                        <td className="px-3 py-2">{row.de}</td>
                        <td className={`px-3 py-2 ${Math.abs(row.skewness)>2?'text-red-600 font-semibold':''}`}>{row.skewness}</td>
                        <td className={`px-3 py-2 ${Math.abs(row.kurtosis)>7?'text-red-600 font-semibold':''}`}>{row.kurtosis}</td>
                        <td className="px-3 py-2"><span className={row.no_normal?'text-amber-600 font-semibold':'text-green-600'}>{row.no_normal?'⚠️ Revisar':'✓ Normal'}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {r.instruments.normality.mardia_skew != null && (
                <div className="bg-slate-50 rounded-xl p-4 border border-slate-200 text-sm">
                  <p className="font-semibold mb-1">Normalidad multivariante de Mardia</p>
                  <p>Asimetría: {r.instruments.normality.mardia_skew} (p = {r.instruments.normality.mardia_skew_p})</p>
                  <p>Curtosis: {r.instruments.normality.mardia_kurt} (p = {r.instruments.normality.mardia_kurt_p})</p>
                  <p className="mt-2 font-semibold text-indigo-700">{r.instruments.normality.recommend_mlr ? '→ Se recomienda estimador MLR en AFC' : '→ Estimador ML apropiado'}</p>
                </div>
              )}
            </Section>
          )}

          {/* Confiabilidad */}
          {r.instruments.reliability && Object.keys(r.instruments.reliability).length > 0 && (
            <Section title="Confiabilidad — Cronbach · Omega · CR · AVE" icon={Shield} color="purple">
              <div className="space-y-4">
                {sa(Object.values(r.instruments.reliability||{})).map((rel:any, i:number) => (
                  <div key={i} className={`rounded-xl border-2 p-4 ${rel.alpha>=.90?'border-green-300 bg-green-50':rel.alpha>=.70?'border-amber-300 bg-amber-50':'border-red-300 bg-red-50'}`}>
                    <p className="font-bold text-slate-800 mb-2">{dt(String(rel.name||""))}</p>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                      {([
                        {label:'α Cronbach', value:`${rel.alpha} — ${rel.interpretation}`},
                        {label:'ω McDonald', value:rel.omega??'-'},
                        {label:'IC 95%', value:`[${rel.ci_lower}, ${rel.ci_upper}]`},
                        {label:'r̄ inter-ítem', value:rel.inter_item??'-'},
                      ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
                    </div>
                    {/* Item-total table */}
                    {sa(rel.item_stats).length > 0 && (
                      <div className="overflow-x-auto rounded-xl border border-slate-200 mt-2">
                        <table className="w-full text-xs">
                          <thead className="bg-slate-50 border-b border-slate-200">
                            <tr>{['Ítem','M','DE','r ítem-total corr.','α si elimina'].map(h=><th key={h} className="px-3 py-1.5 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                          </thead>
                          <tbody>
                            {sa(rel.item_stats).filter((it:any)=>typeof it==='object'&&it!==null).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).filter((it:any)=>typeof it==='object'&&it!==null&&!Array.isArray(it)).map((it:any,j:number)=>(
                              <tr key={j} className={`border-b border-slate-100 ${it.alpha_drop>rel.alpha?'bg-amber-50':''}`}>
                                <td className="px-3 py-1.5 font-bold">{it.item}</td>
                                <td className="px-3 py-1.5">{it.mean}</td>
                                <td className="px-3 py-1.5">{it.sd}</td>
                                <td className={`px-3 py-1.5 font-semibold ${it.r_cor<0.3?'text-red-600':''}`}>{it.r_cor}</td>
                                <td className={`px-3 py-1.5 ${it.alpha_drop>rel.alpha?'text-amber-600 font-semibold':''}`}>{it.alpha_drop}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </Section>
          )}

          {/* AFE */}
          {r.instruments.afe && !r.instruments.afe.error && (
            <Section title={`AFE — ${r.instruments.afe.n_factors} factor(es) · Rotación ${r.instruments.afe.rotation}`} icon={BarChart2} color="teal">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {([
                  {label:'Factores sugeridos (AP)', value:r.instruments.afe.n_factors_pa},
                  {label:'Factores usados', value:r.instruments.afe.n_factors},
                  {label:'RMSEA', value:r.instruments.afe.rmsea},
                  {label:'TLI', value:r.instruments.afe.tli},
                ] as {label:string,value:any}[]).map(k=><KPI key={k.label} label={k.label} value={k.value}/>)}
              </div>
              {/* Loadings table */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>
                      <th className="px-3 py-2 text-left font-semibold text-slate-600">Ítem</th>
                      {Array.from({length: r.instruments.afe?.n_factors||1}).map((_,i) => (
                        <th key={i} className="px-3 py-2 text-center font-semibold text-slate-600">F{i+1}</th>
                      ))}
                      <th className="px-3 py-2 text-center font-semibold text-slate-600">h²</th>
                    </tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afe?.loadings).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        {Array.from({length: r.instruments.afe?.n_factors||1}).map((_,j) => {
                          const val = row[`F${j+1}`] ?? 0;
                          return <td key={j} className={`px-3 py-2 text-center font-medium ${Math.abs(val)>=0.4?'text-indigo-700 font-bold':'text-slate-400'}`}>{val}</td>;
                        })}
                        <td className="px-3 py-2 text-center">{row.h2}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {/* Variance explained */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Factor','SS Cargas','% Varianza','% Acumulado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afe?.variance).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100">
                        <td className="px-3 py-2 font-semibold">{row.factor}</td>
                        <td className="px-3 py-2">{row.ss_load}</td>
                        <td className="px-3 py-2">{row.pct_var}%</td>
                        <td className="px-3 py-2 font-semibold text-indigo-700">{row.cum_var}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>
          )}

          {/* AFC */}
          {r.instruments.afc && !r.instruments.afc.error && (
            <Section title="AFC — Análisis Factorial Confirmatorio" icon={TrendingUp} color="green">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Índice','Valor','Criterio','Evaluación'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afc?.fit_table).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{dt(row.indice)}</td>
                        <td className="px-3 py-2 font-bold text-indigo-700">{row.valor}</td>
                        <td className="px-3 py-2 text-slate-500">{dt(String(row.criterio||""))}</td>
                        <td className="px-3 py-2">
                          <span className={`font-semibold ${row.eval==='Excelente'||row.eval==='✓'?'text-green-600':row.eval==='Aceptable'?'text-amber-600':row.eval==='Deficiente'||row.eval==='✗'?'text-red-600':'text-slate-500'}`}>{row.eval}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className={`rounded-xl p-4 border ${r.instruments.afc.ajuste_global==='excelente'?'bg-green-50 border-green-200':r.instruments.afc.ajuste_global==='aceptable'?'bg-amber-50 border-amber-200':'bg-red-50 border-red-200'}`}>
                <p className="font-semibold">Ajuste global: {r.instruments.afc.ajuste_global}</p>
                <p className="text-xs text-slate-500 mt-1">Estimador: {r.instruments.afc.estimator} | n = {r.instruments.afc.n}</p>
              </div>
              {/* Cargas estandarizadas */}
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Factor','Ítem','λ std','SE','z','p','Estado'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.afc?.loadings).sort((a:any,b:any)=>{ const n=(s:string)=>parseInt(s.replace(/\D/g,'')); return n(a.item)-n(b.item); }).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold text-indigo-700">{row.factor}</td>
                        <td className="px-3 py-2 font-semibold">{row.item}</td>
                        <td className={`px-3 py-2 font-bold ${Math.abs(row.lambda)>=0.5?'text-green-700':'text-red-600'}`}>{row.lambda}</td>
                        <td className="px-3 py-2 text-slate-500">{row.se}</td>
                        <td className="px-3 py-2">{row.z}</td>
                        <td className="px-3 py-2">{row.p_apa}</td>
                        <td className="px-3 py-2"><span className={row.ok?'text-green-600':'text-red-600'}>{row.ok?'✓':'⚠️'}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>
          )}

          {/* HTMT */}
          {r.instruments.htmt && !r.instruments.htmt.error && sa(r.instruments.htmt.pairs).length > 0 && (
            <Section title={`HTMT — Validez Discriminante (Bootstrap n=${r.instruments.htmt.n_boot})`} icon={Activity} color="amber">
              <div className="overflow-x-auto rounded-xl border border-slate-200">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Par de constructos','HTMT','IC 95% inf','IC 95% sup','Veredicto'].map(h=><th key={h} className="px-3 py-2 text-left font-semibold text-slate-600">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {sa(r.instruments.htmt?.pairs).map((row:any,i:number)=>(
                      <tr key={i} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-3 py-2 font-semibold">{dt(row.par)}</td>
                        <td className={`px-3 py-2 font-bold ${row.ok?'text-green-700':'text-red-600'}`}>{row.htmt}</td>
                        <td className="px-3 py-2 text-slate-500">{row.ic_low}</td>
                        <td className="px-3 py-2 text-slate-500">{row.ic_high}</td>
                        <td className="px-3 py-2"><span className={row.ok?'text-green-600 font-semibold':'text-red-600 font-semibold'}>{dt(String(row.verdict||'')).replace('x','✗')}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="text-xs text-slate-500">Criterio: HTMT {'<'} .85 indica validez discriminante (Henseler et al., 2015)</p>
            </Section>
          )}

        </div>
      )}

      <div className="flex justify-between pt-4">
        <button onClick={onBack} className="flex items-center gap-2 text-slate-600 hover:text-slate-800 font-medium px-5 py-2.5 rounded-xl border border-slate-300 hover:bg-slate-50 transition-all">
          <ChevronLeft className="w-4 h-4"/> Atrás
        </button>
        <button onClick={onNext} className="flex items-center gap-2 bg-blue-700 hover:bg-blue-800 text-white font-semibold px-7 py-3 rounded-xl transition-all">
          Exportar resultados <ChevronRight className="w-4 h-4"/>
        </button>
      </div>
    </div>
  );
}
