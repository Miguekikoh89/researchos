'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ChevronRight, CheckCircle, AlertTriangle, XCircle } from 'lucide-react';

interface Check { label:string; status:'ok'|'warn'|'error'; message:string; }

function validate(data: any): Check[] {
  const checks: Check[] = [];
  const obj = data.objective || {};
  const meth = data.methodology || {};
  const action = obj.action || '';
  const alcance = meth.alcance || '';
  const diseño = meth.diseño || '';
  const vars = data.variables || [];

  // 1. Acción vs alcance
  if(action==='relacionar' && alcance==='Descriptivo')
    checks.push({label:'Alcance vs objetivo', status:'warn', message:'Tu objetivo plantea relación entre variables. El nivel más coherente es Correlacional.'});
  else if(action==='relacionar' && alcance==='Correlacional')
    checks.push({label:'Alcance vs objetivo', status:'ok', message:'El alcance correlacional es coherente con tu objetivo de relacionar variables.'});
  else if(action==='predecir' && alcance==='Predictivo')
    checks.push({label:'Alcance vs objetivo', status:'ok', message:'El alcance predictivo es coherente con tu objetivo.'});
  else if(action==='comparar' && alcance==='Comparativo')
    checks.push({label:'Alcance vs objetivo', status:'ok', message:'El alcance comparativo es coherente con tu objetivo.'});
  else if(action==='describir' && alcance==='Descriptivo')
    checks.push({label:'Alcance vs objetivo', status:'ok', message:'El alcance descriptivo es coherente con tu objetivo.'});
  else
    checks.push({label:'Alcance vs objetivo', status:'warn', message:`Revisa si el alcance "${alcance}" corresponde con la acción "${action}".`});

  // 2. Diseño
  if(diseño==='No experimental')
    checks.push({label:'Diseño de investigación', status:'ok', message:'El diseño no experimental es adecuado para estudios correlacionales y descriptivos.'});
  else if(diseño==='Experimental')
    checks.push({label:'Diseño de investigación', status:'ok', message:'El diseño experimental es adecuado para estudios comparativos con grupos control.'});

  // 3. Escala vs análisis
  const escala = meth.escala || '';
  if((escala.includes('Likert') || escala==='Ordinal') && action==='relacionar')
    checks.push({label:'Escala vs prueba estadística', status:'ok', message:'Escala Likert con análisis correlacional → se usará Spearman o Pearson según normalidad.'});
  else if(escala==='Categórica' && action==='relacionar')
    checks.push({label:'Escala vs prueba estadística', status:'warn', message:'Para variables categóricas se recomienda Chi-cuadrado, no correlación lineal.'});
  else
    checks.push({label:'Escala vs prueba estadística', status:'ok', message:'La escala de medición es compatible con el análisis planificado.'});

  // 4. Variables
  if(vars.length >= 2)
    checks.push({label:'Variables registradas', status:'ok', message:`${vars.length} variables registradas correctamente.`});
  else
    checks.push({label:'Variables registradas', status:'error', message:'Se requieren al menos 2 variables para el análisis.'});

  // 5. Objetivo
  if(obj.text)
    checks.push({label:'Objetivo general', status:'ok', message:'Objetivo general generado correctamente.'});
  else
    checks.push({label:'Objetivo general', status:'warn', message:'No se detectó objetivo general. Vuelve al paso anterior.'});

  // 6. PLS-SEM check
  if(action==='estructural' && vars.length < 2)
    checks.push({label:'PLS-SEM', status:'error', message:'PLS-SEM requiere al menos 2 constructos con indicadores (dimensiones).'});
  else if(action==='estructural')
    checks.push({label:'PLS-SEM', status:'ok', message:'Configuración compatible con modelo estructural.'});

  return checks;
}

export default function CoherencePage() {
  const router = useRouter();
  const [checks, setChecks] = useState<Check[]>([]);
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    const d = JSON.parse(localStorage.getItem('ros_research') || '{}');
    setData(d);
    setChecks(validate(d));
  }, []);

  const hasError = checks.some(c => c.status==='error');
  const hasWarn = checks.some(c => c.status==='warn');
  const overall = hasError ? 'error' : hasWarn ? 'warn' : 'ok';

  const goToAnalysis = () => {
    if(!data) return;
    // Build config for existing wizard
    const vars = data.variables || [];
    const obj = data.objective || {};
    const meth = data.methodology || {};
    const varA = vars.find((v:any) => v.id === obj.varA);
    const varB = vars.find((v:any) => v.id === obj.varB);

    const actionMap: Record<string,string> = {
      relacionar:'correlacional', comparar:'comparacion', predecir:'regresion',
      describir:'correlacional', evaluar:'chi_cuadrado', estructural:'correlacional',
    };

    const config = {
      analysisCategory: actionMap[obj.action] || 'correlacional',
      varAName: varA?.name || '',
      varAItems: varA?.dimensions?.flatMap((d:any) => d.name) || [],
      varBName: varB?.name || '',
      varBItems: varB?.dimensions?.flatMap((d:any) => d.name) || [],
      studyTitle: obj.text || '',
      participants: meth.poblacion || 'los participantes',
      researchData: data,
    };

    localStorage.setItem('ros_analysis_config', JSON.stringify(config));
    router.push('/analysis/new?from=research');
  };

  const icon = (s:string) => s==='ok' ? <CheckCircle className="w-5 h-5 text-green-600"/> :
    s==='warn' ? <AlertTriangle className="w-5 h-5 text-amber-500"/> : <XCircle className="w-5 h-5 text-red-500"/>;

  const bg = (s:string) => s==='ok'?'bg-green-50 border-green-200':s==='warn'?'bg-amber-50 border-amber-200':'bg-red-50 border-red-200';

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center text-white font-black text-sm">OS</div>
          <p className="font-black text-slate-900">Asistente metodológico</p>
        </div>
        <div className="text-xs text-slate-400 font-medium">
          <span className="text-green-600 font-bold">✓ Variables → ✓ Objetivo → ✓ Metodología</span>
          <span className="mx-1">→</span>
          <span className="text-indigo-600 font-bold">Coherencia</span>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-6 py-8 space-y-6">
        <div>
          <h1 className="text-2xl font-black text-slate-900">Validación de coherencia</h1>
          <p className="text-slate-500 mt-1">Revisamos que tu metodología sea consistente con tu objetivo.</p>
        </div>

        {/* Overall */}
        <div className={`rounded-2xl border-2 p-5 ${overall==='ok'?'bg-green-50 border-green-300':overall==='warn'?'bg-amber-50 border-amber-300':'bg-red-50 border-red-300'}`}>
          <p className={`text-lg font-black ${overall==='ok'?'text-green-800':overall==='warn'?'text-amber-800':'text-red-800'}`}>
            {overall==='ok'?'✅ Coherencia verificada — listo para cargar la base de datos':
             overall==='warn'?'⚠️ Revisa algunas observaciones antes de continuar':
             '❌ Hay inconsistencias que debes corregir'}
          </p>
        </div>

        {/* Checks */}
        <div className="space-y-3">
          {checks.map((c,i) => (
            <div key={i} className={`rounded-2xl border-2 p-4 flex items-start gap-3 ${bg(c.status)}`}>
              <div className="mt-0.5">{icon(c.status)}</div>
              <div>
                <p className="font-bold text-slate-800 text-sm">{c.label}</p>
                <p className="text-slate-600 text-sm mt-0.5">{c.message}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Research summary */}
        {data && (
          <div className="bg-white rounded-2xl border border-slate-200 p-5 space-y-3">
            <p className="font-bold text-slate-800">Resumen de tu investigación</p>
            {data.objective?.text && <p className="text-sm text-slate-600"><span className="font-semibold">Objetivo:</span> {data.objective.text}</p>}
            {data.hypothesis?.h1 && <p className="text-sm text-slate-600"><span className="font-semibold">H₁:</span> {data.hypothesis.h1}</p>}
            {data.hypothesis?.h0 && <p className="text-sm text-slate-600"><span className="font-semibold">H₀:</span> {data.hypothesis.h0}</p>}
            {data.methodology && (
              <div className="flex flex-wrap gap-2 mt-2">
                {Object.entries(data.methodology).filter(([k]) => !['muestra','poblacion'].includes(k)).map(([k,v]:any) => (
                  <span key={k} className="text-xs bg-slate-100 text-slate-600 font-semibold px-3 py-1 rounded-full">{v}</span>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Siguiente paso */}
        <div className="bg-slate-50 border-2 border-slate-200 rounded-2xl p-5 space-y-2">
          <p className="font-bold text-slate-800 flex items-center gap-2">📂 Siguiente paso</p>
          <p className="text-sm text-slate-600">Ahora debes cargar la base de datos para que CanchariOS pueda mapear las columnas con tus variables y dimensiones, evaluar supuestos estadísticos y seleccionar la prueba adecuada.</p>
        </div>

        <div className="flex justify-between pt-2">
          <button onClick={() => router.push('/research/methodology')} className="btn-secondary">← Volver a metodología</button>
          <button onClick={goToAnalysis} disabled={hasError}
            className="btn-primary flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed">
            Continuar a carga de datos <ChevronRight className="w-4 h-4"/>
          </button>
        </div>
      </div>
    </div>
  );
}
