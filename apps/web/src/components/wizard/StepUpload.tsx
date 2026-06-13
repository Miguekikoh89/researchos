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
    <div className="card">
      <h2 className="text-xl font-bold text-slate-800 mb-1">Sube tu base de datos</h2>
      <p className="text-slate-500 text-sm mb-6">Acepta Excel (.xlsx, .xls) y CSV. Máximo 50 MB. Cada fila debe ser un participante y cada columna un ítem.</p>

      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition ${
          isDragActive ? 'border-indigo-400 bg-indigo-50' :
          uploaded ? 'border-emerald-400 bg-emerald-50' :
          'border-slate-300 hover:border-indigo-300 hover:bg-slate-50'
        }`}
      >
        <input {...getInputProps()} />
        {uploading ? (
          <div className="flex flex-col items-center gap-3">
            <div className="animate-spin w-8 h-8 border-2 border-indigo-600 border-t-transparent rounded-full"/>
            <p className="text-indigo-600 text-sm font-medium">Subiendo archivo…</p>
          </div>
        ) : uploaded ? (
          <div className="flex flex-col items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-emerald-100 flex items-center justify-center">
              <svg className="w-6 h-6 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7"/>
              </svg>
            </div>
            <p className="text-emerald-700 font-medium">{uploaded}</p>
            <p className="text-slate-400 text-xs">{state.columns.length} columnas detectadas · Haz clic para cambiar</p>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-3">
            <svg className="w-10 h-10 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <p className="font-medium text-slate-600">{isDragActive ? 'Suelta el archivo aquí' : 'Arrastra tu archivo o haz clic'}</p>
            <p className="text-slate-400 text-xs">Excel (.xlsx, .xls) · CSV</p>
          </div>
        )}
      </div>

      {error && (
        <div className="mt-4 flex items-start gap-2 rounded-lg bg-rose-50 border border-rose-200 px-4 py-3 text-sm text-rose-700">
          <svg className="w-4 h-4 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          {error}
        </div>
      )}

      <div className="mt-6 flex justify-end">
        <button
          onClick={onNext}
          disabled={!uploaded}
          className="btn-primary"
        >
          Continuar →
        </button>
      </div>
    </div>
  );
}
