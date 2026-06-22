'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronRight } from 'lucide-react';

const OPTS: Record<string, string[]> = {
  enfoque:    ['Cuantitativo','Cualitativo','Mixto'],
  tipo:       ['Básica','Aplicada'],
  diseño:     ['No experimental','Experimental','Cuasiexperimental'],
  corte:      ['Transversal','Longitudinal'],
  alcance:    ['Descriptivo','Correlacional','Comparativo','Explicativo','Predictivo'],
  muestreo:   ['Probabilístico aleatorio simple','Probabilístico estratificado','No probabilístico por conveniencia','No probabilístico intencional','Censal'],
  tecnica:    ['Encuesta','Observación','Análisis documental','Experimento'],
  instrumento:['Cuestionario','Escala','Ficha de observación','Ficha documental'],
  escala:     ['Likert 5 puntos','Likert 3 puntos','Likert 7 puntos','Dicotómica','Numérica','Categórica'],
};

const BASE_RECOMMENDED: Record<string,string> = {
  enfoque:'Cuantitativo', tipo:'Aplicada', diseño:'No experimental',
  corte:'Transversal', alcance:'Correlacional', muestreo:'No probabilístico por conveniencia',
  tecnica:'Encuesta', instrumento:'Cuestionario', escala:'Likert 5 puntos',
};
const RECOMMENDED = BASE_RECOMMENDED;
const NOTES: Record<string,string> = {
  enfoque:'Recomendado porque tus objetivos requieren análisis estadístico.',
  tipo:'Orienta la investigación a resolver problemas prácticos.',
  diseño:'Recomendado cuando no se manipulan variables.',
  corte:'Recomendado si los datos se recolectarán una sola vez.',
  alcance:'Recomendado porque tu objetivo busca relacionar variables.',
  muestreo:'Adecuado cuando no se requiere representatividad estadística.',
  tecnica:'Recomendada para recolectar datos mediante cuestionarios estructurados.',
  instrumento:'Coherente con estudios cuantitativos basados en escalas.',
  escala:'Frecuente en estudios con percepción, actitudes o satisfacción.',
};
const LABELS: Record<string,string> = {
  enfoque:'Enfoque', tipo:'Tipo de investigación', diseño:'Diseño', corte:'Corte temporal',
  alcance:'Nivel / Alcance', muestreo:'Tipo de muestreo', tecnica:'Técnica de recolección',
  instrumento:'Instrumento', escala:'Escala de medición',
};

export default function MethodologyPage() {
  const router = useRouter();
  const [method, setMethod] = useState<Record<string,string>>({
    enfoque:'Cuantitativo', tipo:'Aplicada', diseño:'No experimental',
    corte:'Transversal', alcance:'Correlacional', muestreo:'No probabilístico por conveniencia',
    tecnica:'Encuesta', instrumento:'Cuestionario', escala:'Likert 5 puntos',
  });
  const [muestra, setMuestra] = useState('');
  const [diag, setDiag] = useState<any>({});
  const [poblacion, setPoblacion] = useState('');

  const set = (k:string, v:string) => setMethod(m => ({...m, [k]:v}));

  useEffect(() => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    const action = d.objective?.action || 'relacionar';
    // Según Hernández-Sampieri, Hair et al., Creswell
    const actionMap: Record<string,string> = {
      relacionar:  'Correlación (Pearson o Spearman según normalidad)',
      comparar:    'Comparación de grupos (t de Student, Mann-Whitney, ANOVA o Kruskal-Wallis)',
      predecir:    'Regresión lineal o logística según naturaleza de VD',
      describir:   'Estadística descriptiva (frecuencias, medias, dispersión)',
      evaluar:     'Chi-cuadrado / V de Cramér (asociación entre variables categóricas)',
      explicar:    'Mediación / Moderación (regresión con efectos indirectos)',
      estructural: 'PLS-SEM o CB-SEM (modelo de ecuaciones estructurales)',
    };
    const alcanceMap: Record<string,string> = {
      relacionar:  'Correlacional',
      comparar:    'Comparativo',
      predecir:    'Predictivo',
      describir:   'Descriptivo',
      evaluar:     'Correlacional',   // asociación entre variables — nivel correlacional
      explicar:    'Explicativo',
      estructural: 'Explicativo',
    };
    const escalaMap: Record<string,string> = {
      relacionar:  'Likert 5 puntos',
      comparar:    'Likert 5 puntos',
      predecir:    'Likert 5 puntos',
      describir:   'Likert 5 puntos',
      evaluar:     'Categórica',      // Chi-cuadrado requiere variables categóricas/nominales
      explicar:    'Likert 5 puntos',
      estructural: 'Likert 5 puntos',
    };
    const alcance = alcanceMap[action] || 'Correlacional';
    const escala  = escalaMap[action]  || 'Likert 5 puntos';
    setDiag({ action, alcance, analysis: actionMap[action]||'Correlación' });
    setMethod(m => ({ ...m, alcance, escala }));
  }, []);

  const save = () => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    d.methodology = { ...method, muestra, poblacion };
    localStorage.setItem('ros_research', JSON.stringify(d));
    router.push('/research/coherence');
  };

  const tagColor = (k:string, v:string, sel:string) =>
    sel===v ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-slate-600 border-slate-200 hover:border-indigo-300';

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
          <span className="text-indigo-600 font-bold">Metodología</span>
          <span className="mx-1">→ Coherencia</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-8 space-y-6">
        <div>
          <h1 className="text-2xl font-black text-slate-900">Metodología</h1>
          <p className="text-slate-500 mt-1">Solo haz clic. Todo está preseleccionado según tu objetivo.</p>
        </div>

        {/* Diagnóstico previo */}
        <div className="bg-indigo-50 border border-indigo-200 rounded-2xl p-4 space-y-2">
          <p className="font-bold text-indigo-800 text-sm">🔍 Diagnóstico previo</p>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div className="bg-white rounded-xl p-3 border border-indigo-100">
              <p className="text-slate-400 font-medium">Objetivo identificado</p>
              <p className="font-bold text-slate-700 mt-0.5 capitalize">{diag.action || 'Relacionar variables'}</p>
            </div>
            <div className="bg-white rounded-xl p-3 border border-indigo-100">
              <p className="text-slate-400 font-medium">Alcance sugerido</p>
              <p className="font-bold text-slate-700 mt-0.5">{diag.alcance || 'Correlacional'}</p>
            </div>
            <div className="bg-white rounded-xl p-3 border border-indigo-100">
              <p className="text-slate-400 font-medium">Análisis esperado</p>
              <p className="font-bold text-slate-700 mt-0.5">{diag.analysis || 'Correlación'}</p>
            </div>
            <div className="bg-white rounded-xl p-3 border border-indigo-100">
              <p className="text-slate-400 font-medium">Estado</p>
              <p className="font-bold text-amber-600 mt-0.5">Pendiente de validación</p>
            </div>
          </div>
        </div>

        <div className="space-y-5">
          {Object.entries(OPTS).map(([key, opts]) => {
            const rec = RECOMMENDED[key];
            const note = NOTES[key];
            return (
            <div key={key} className="bg-white rounded-2xl border border-slate-200 p-4 space-y-3">
              <p className="font-bold text-slate-700 text-sm">{LABELS[key]}</p>
              <div className="flex flex-wrap gap-2">
                {opts.map(opt => (
                  <button key={opt} onClick={() => set(key, opt)}
                    className={`text-sm font-semibold px-4 py-2 rounded-full border-2 transition flex items-center gap-1.5 ${tagColor(key, opt, method[key])}`}>
                    {opt}
                    {opt===rec && <span className={`text-xs px-1.5 py-0.5 rounded-full font-bold ${method[key]===opt?'bg-white/30':'bg-indigo-100 text-indigo-600'}`}>Recomendado</span>}
                  </button>
                ))}
              </div>
              {note && method[key] && <p className="text-xs text-slate-400 mt-1">{note}</p>}
            </div>
            );
          })}

          <div className="bg-white rounded-2xl border border-slate-200 p-4 space-y-3">
            <p className="font-bold text-slate-700 text-sm">Muestra y población</p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Tamaño de muestra</label>
                <input type="number" className="input" placeholder="Ej: 120" value={muestra} onChange={e=>setMuestra(e.target.value)}/>
              </div>
              <div>
                <label className="label">Descripción de población</label>
                <input className="input" placeholder="Ej: Docentes de Lima" value={poblacion} onChange={e=>setPoblacion(e.target.value)}/>
              </div>
            </div>
          </div>
        </div>

        <div className="flex justify-between pt-2">
          <button onClick={() => router.push('/research/hypothesis')} className="btn-secondary">← Volver</button>
          <button onClick={save} className="btn-secondary">Guardar borrador</button>
          <button onClick={save} className="btn-primary flex items-center gap-2">
            Validar coherencia metodológica <ChevronRight className="w-4 h-4"/>
          </button>
        </div>
      </div>
    </div>
  );
}
