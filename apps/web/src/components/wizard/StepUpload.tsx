'use client';
import { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import type { WizardState } from '@/app/analysis/new/page';

interface Props {
  state: WizardState;
  updateState: (patch: Partial<WizardState>) => void;
  onNext: () => void;
}

export default function StepUpload({ state, updateState, onNext }: Props) {
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const [uploaded, setUploaded] = useState<string | null>(null);

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    if (!file) return;
    if (!state.projectId) { setError('No hay proyecto seleccionado'); return; }

    setError('');
    setUploading(true);
    try {
      const token = localStorage.getItem('ros_token');
      const form = new FormData();
      form.append('file', file);

      const res = await fetch(`/api/v1/projects/${state.projectId}/datasets`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
      });

      const text = await res.text();
      let data: any;
      try { data = JSON.parse(text); }
      catch { throw new Error(`Error del servidor: ${text.slice(0, 100)}`); }

      if (!res.ok) throw new Error(data.message || `Error ${res.status}`);

      setUploaded(file.name);
      updateState({
        datasetId: data.id,
        columns: Array.isArray(data.columns)
          ? data.columns.map((c: any) => typeof c === 'string' ? c : c.name)
          : [],
        config: {
          ...state.config,
          varAItems: [], varADimensions: [],
          varBItems: [], varBDimensions: [],
          groupVar: '', groupValues: ['',''],
          // varAName, varBName, studyTitle, objective, hypothesisH1 se conservan
          // si ya vinieron precargados desde el asistente metodologico (/research)
        } as any,
      });
    } catch (e: any) {
      setError(e.message);
    } finally {
      setUploading(false);
    }
  }, [state.projectId, updateState]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
      'application/vnd.ms-excel': ['.xls'],
      'text/csv': ['.csv'],
    },
    maxFiles: 1,
    maxSize: 50 * 1024 * 1024,
    disabled: uploading,
  });

  return (
    <div className="min-h-screen flex flex-col items-center justify-center py-12 px-6" style={{background:'linear-gradient(135deg,#0f172a 0%,#1e1b4b 50%,#0f172a 100%)'}}>

      {/* Header */}
      <div className="text-center mb-10">
        <div className="inline-flex items-center gap-2 rounded-full px-4 py-2 mb-5 border border-white/10" style={{background:'rgba(255,255,255,0.05)'}}>
          <span className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse inline-block"/>
          <span className="text-slate-300 text-sm font-semibold">Motor estadístico APA 7 · CanchariOS</span>
        </div>
        <h2 className="text-5xl font-black text-white mb-3 leading-tight">
          Carga tu<br/>
          <span style={{background:'linear-gradient(90deg,#22d3ee,#818cf8)',WebkitBackgroundClip:'text',WebkitTextFillColor:'transparent'}}>
            base de datos
          </span>
        </h2>
        <p className="text-slate-400 text-lg">Excel (.xlsx, .xls) o CSV · Máx. 50 MB · Una fila por participante</p>
      </div>

      {/* Drop zone */}
      <div
        {...getRootProps()}
        className="w-full max-w-2xl cursor-pointer transition-all duration-300 rounded-3xl"
        style={{
          background: isDragActive
            ? 'linear-gradient(135deg,#6366f133,#8b5cf633)'
            : uploaded
            ? 'linear-gradient(135deg,#10b98115,#05966915)'
            : 'rgba(255,255,255,0.04)',
          border: isDragActive
            ? '2px dashed #6366f1'
            : uploaded
            ? '2px solid #10b981'
            : '2px dashed rgba(255,255,255,0.15)',
          boxShadow: isDragActive
            ? '0 0 60px #6366f144'
            : uploaded
            ? '0 0 40px #10b98133'
            : '0 0 40px rgba(99,102,241,0.1)',
        }}
      >
        <input {...getInputProps()} />
        <div className="p-16 flex flex-col items-center gap-6">
          {uploading ? (
            <>
              <div className="w-24 h-24 rounded-3xl flex items-center justify-center" style={{background:'linear-gradient(135deg,#6366f1,#8b5cf6)'}}>
                <div className="animate-spin w-12 h-12 rounded-full" style={{border:'3px solid rgba(255,255,255,0.3)',borderTopColor:'white'}}/>
              </div>
              <div className="text-center">
                <p className="text-white font-black text-2xl">Procesando archivo...</p>
                <p className="text-slate-400 text-sm mt-2">Detectando columnas y filas</p>
              </div>
            </>
          ) : uploaded ? (
            <>
              <div className="w-24 h-24 rounded-3xl flex items-center justify-center text-5xl" style={{background:'linear-gradient(135deg,#10b981,#059669)'}}>
                ✓
              </div>
              <div className="text-center">
                <p className="text-white font-black text-2xl">{uploaded}</p>
                <p className="text-emerald-400 text-sm mt-1 font-semibold">{state.columns.length} columnas detectadas · listo para analizar</p>
                <p className="text-slate-500 text-xs mt-1">Haz clic para cambiar el archivo</p>
              </div>
              <div className="flex flex-wrap gap-2 justify-center max-w-lg">
                {state.columns.slice(0,8).map((col:string)=>(
                  <span key={col} className="text-xs font-semibold px-3 py-1 rounded-full" style={{background:'rgba(16,185,129,0.2)',color:'#6ee7b7',border:'1px solid rgba(16,185,129,0.3)'}}>{col}</span>
                ))}
                {state.columns.length > 8 && <span className="text-xs font-semibold px-3 py-1 rounded-full" style={{background:'rgba(255,255,255,0.05)',color:'#94a3b8'}}>+{state.columns.length-8} más</span>}
              </div>
            </>
          ) : (
            <>
              <div className="w-24 h-24 rounded-3xl flex items-center justify-center text-5xl" style={{background: isDragActive ? 'linear-gradient(135deg,#6366f1,#8b5cf6)' : 'rgba(255,255,255,0.08)'}}>
                {isDragActive ? '📂' : '📊'}
              </div>
              <div className="text-center">
                <p className="font-black text-2xl text-white">{isDragActive ? '¡Suelta aquí!' : 'Arrastra tu archivo o haz clic'}</p>
                <p className="text-slate-400 text-sm mt-2">Excel (.xlsx, .xls) · CSV · Máximo 50 MB</p>
              </div>
              <div className="flex gap-3">
                {[['📈','Excel .xlsx'],['📋','CSV'],['🔢','Datos numéricos']].map(([icon,label])=>(
                  <div key={label} className="flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold text-slate-300" style={{background:'rgba(255,255,255,0.06)',border:'1px solid rgba(255,255,255,0.1)'}}>
                    <span>{icon}</span><span>{label}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      {error && (
        <div className="mt-4 w-full max-w-2xl flex items-start gap-3 rounded-2xl px-5 py-4 text-sm" style={{background:'rgba(239,68,68,0.1)',border:'1px solid rgba(239,68,68,0.3)',color:'#fca5a5'}}>
          <svg className="w-5 h-5 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <span className="font-medium">{error}</span>
        </div>
      )}

      <div className="mt-8 flex justify-center">
        <button
          onClick={onNext}
          disabled={!uploaded}
          className="flex items-center gap-3 text-white font-black px-10 py-4 rounded-2xl text-lg transition-all disabled:opacity-30 disabled:cursor-not-allowed hover:scale-105 hover:-translate-y-0.5"
          style={{
            background: uploaded ? 'linear-gradient(135deg,#6366f1,#8b5cf6)' : 'rgba(255,255,255,0.1)',
            boxShadow: uploaded ? '0 10px 40px rgba(99,102,241,0.4)' : 'none',
          }}>
          Continuar al análisis
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M13 7l5 5m0 0l-5 5m5-5H6"/>
          </svg>
        </button>
      </div>
    </div>
  );
}
