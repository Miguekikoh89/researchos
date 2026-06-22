'use client';

// ============================================================================
// CanchariOS — Wizard Step 5: Exportar resultados
// ============================================================================

import { useState } from 'react';
import { FileText, Download, CheckCircle2, Loader2, ChevronLeft, RefreshCw } from 'lucide-react';
import type { WizardState, AnalysisFormConfig } from '@/app/analysis/new/page';

function dt(text: any): string {
  if (!text) return '';
  let s = String(text);
  s = s.replace(/<U[+]([0-9A-Fa-f]{4})>/g, (_: string, hex: string) => String.fromCharCode(parseInt(hex, 16)));
  return s
    .replace(/<c3><b3>/g,'ó').replace(/<c3><a1>/g,'á').replace(/<c3><a9>/g,'é')
    .replace(/<c3><ad>/g,'í').replace(/<c3><ba>/g,'ú').replace(/<c3><b1>/g,'ñ')
    .replace(/<c3><93>/g,'Ó').replace(/<c3><81>/g,'Á').replace(/<c3><89>/g,'É')
    .replace(/<cf><81>/g,'ρ').replace(/<ce><b1>/g,'α')
    .replace(/<cf><87>/g,'χ').replace(/<c2><b2>/g,'²').replace(/<c2><b3>/g,'³')
    .replace(/<e2><89><a4>/g,'\u2264').replace(/<e2><89><a5>/g,'\u2265').replace(/<e2><89><a0>/g,'\u2260')
    .replace(/<e2><9c><97>/g,'\u2717').replace(/<e2><9c><93>/g,'\u2713').replace(/<e2><80><93>/g,'\u2013').replace(/<e2><82><80>/g,'₀');
}

interface Props {
  state:        WizardState;
  updateState:  (patch: Partial<WizardState>) => void;
  updateConfig: (patch: Partial<AnalysisFormConfig>) => void;
  onNext:       () => void;
  onBack:       () => void;
}

export default function StepExport({ state, onBack }: Props) {
  const [downloading, setDownloading] = useState<string | null>(null);
  const [downloaded, setDownloaded]   = useState<Set<string>>(new Set());

  const download = async (type: 'word' | 'json') => {
    if (!state.jobId) return;
    setDownloading(type);
    const projectId = state.projectId || 'default';

    try {
      if (type === 'word') {
        const res = await fetch(
          `/api/v1/projects/${projectId}/analysis/${state.jobId}/download/word`,
          { headers: { Authorization: `Bearer ${localStorage.getItem('ros_token')}` } },
        );
        if (!res.ok) throw new Error('No se pudo descargar el Word.');
        const blob = await res.blob();
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = `ResultadosAPA_${new Date().toISOString().slice(0, 10)}.docx`;
        a.click();
        URL.revokeObjectURL(url);
      }

      if (type === 'json') {
        const result = state.results;
        const blob = new Blob([JSON.stringify(result, null, 2)], { type: 'application/json' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = `ResultadosTecnicos_${new Date().toISOString().slice(0, 10)}.json`;
        a.click();
        URL.revokeObjectURL(url);
      }

      setDownloaded((prev) => new Set([...prev, type]));
    } catch (e: any) {
      alert(e.message);
    } finally {
      setDownloading(null);
    }
  };

  const mainCorr = state.results?.correlations?.find((c: any) => c.type === 'general');
  const method   = state.results?.method ?? 'spearman';

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-800">Exportar resultados</h2>
        <p className="text-slate-500 mt-1">
          Descarga tu informe Word con formato APA 7, listo para copiar en tu tesis.
        </p>
      </div>

      {/* Resumen rápido de resultado clave */}
      {mainCorr && (
        <div className={`rounded-2xl p-6 border-2 ${
          mainCorr.significant ? 'bg-teal-50 border-teal-400' : 'bg-amber-50 border-amber-400'
        }`}>
          <p className="text-sm font-semibold text-slate-500 uppercase tracking-wide mb-2">Resultado principal</p>
          <p className="text-xl font-bold text-slate-800">
            {dt(mainCorr.var_a)} × {dt(mainCorr.var_b)}
          </p>
          <div className="flex items-center gap-4 mt-3">
            <span className="text-3xl font-mono font-bold text-slate-800">
              {method === 'pearson' ? 'r' : 'ρ'} = {mainCorr.r_apa}
            </span>
            <span className="font-mono text-slate-600">p = {mainCorr.p_apa}</span>
            <span className={`px-3 py-1 rounded-full font-bold text-sm ${
              mainCorr.significant ? 'bg-teal-600 text-white' : 'bg-amber-600 text-white'
            }`}>
              {mainCorr.significant ? 'Se rechaza H₀' : 'No se rechaza H₀'}
            </span>
          </div>
        </div>
      )}

      {/* Opciones de descarga */}
      <div className="grid grid-cols-1 gap-4">
        {/* Word APA */}
        <div className="bg-white border border-slate-200 rounded-2xl p-6 shadow-sm">
          <div className="flex items-start justify-between">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center flex-shrink-0">
                <FileText className="w-6 h-6 text-blue-700" />
              </div>
              <div>
                <h3 className="font-bold text-slate-800">Word APA 7</h3>
                <p className="text-sm text-slate-500 mt-0.5">
                  Documento con tablas de normalidad, correlaciones, descriptivos,
                  baremos y redacción académica lista para tu tesis.
                </p>
                <div className="flex flex-wrap gap-2 mt-3">
                  {['Normalidad', 'Correlaciones', 'Descriptivos', 'Baremos', 'Confiabilidad'].map((tag) => (
                    <span key={tag} className="text-xs bg-blue-50 text-blue-700 border border-blue-200 px-2 py-0.5 rounded-full">
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            </div>
            <button
              onClick={() => download('word')}
              disabled={downloading === 'word' || !state.results?.wordPath}
              className="flex items-center gap-2 bg-blue-700 hover:bg-blue-800 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold px-5 py-2.5 rounded-xl transition-all whitespace-nowrap flex-shrink-0"
            >
              {downloading === 'word' ? (
                <><Loader2 className="w-4 h-4 animate-spin" /> Descargando…</>
              ) : downloaded.has('word') ? (
                <><CheckCircle2 className="w-4 h-4" /> Descargado</>
              ) : (
                <><Download className="w-4 h-4" /> Descargar .docx</>
              )}
            </button>
          </div>
        </div>

        {/* JSON técnico */}
        <div className="bg-white border border-slate-200 rounded-2xl p-6 shadow-sm">
          <div className="flex items-start justify-between">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-slate-100 rounded-xl flex items-center justify-center flex-shrink-0">
                <span className="text-lg font-bold text-slate-500">{ }</span>
              </div>
              <div>
                <h3 className="font-bold text-slate-800">Datos técnicos JSON</h3>
                <p className="text-sm text-slate-500 mt-0.5">
                  Todos los resultados estadísticos en formato JSON para integración
                  con otros sistemas o revisión técnica.
                </p>
              </div>
            </div>
            <button
              onClick={() => download('json')}
              disabled={downloading === 'json'}
              className="flex items-center gap-2 bg-slate-700 hover:bg-slate-800 disabled:opacity-50 text-white font-semibold px-5 py-2.5 rounded-xl transition-all whitespace-nowrap flex-shrink-0"
            >
              {downloading === 'json' ? (
                <><Loader2 className="w-4 h-4 animate-spin" /> Exportando…</>
              ) : downloaded.has('json') ? (
                <><CheckCircle2 className="w-4 h-4" /> Exportado</>
              ) : (
                <><Download className="w-4 h-4" /> Exportar .json</>
              )}
            </button>
          </div>
        </div>
      </div>

      {/* Tip para sustentación */}
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-5">
        <p className="font-semibold text-amber-900 mb-2">💡 Cómo usar estos resultados en tu sustentación</p>
        <ul className="text-sm text-amber-800 space-y-1.5 list-disc list-inside">
          <li>El documento Word contiene cada tabla numerada (Tabla 1, Tabla 2…) lista para pegar.</li>
          <li>La redacción APA 7 incluye la decisión sobre H₀ correctamente formulada.</li>
          <li>Si el asesor pide cambios, vuelve al Paso 2 y reconfigura.</li>
          <li>Recuerda que "no se rechaza H₀" ≠ "se acepta H₀".</li>
        </ul>
      </div>

      {/* Navegación */}
      <div className="flex justify-between">
        <button onClick={onBack}
          className="flex items-center gap-2 text-slate-600 hover:text-slate-800 font-medium px-5 py-2.5 rounded-xl border border-slate-300 hover:bg-slate-50 transition-all">
          <ChevronLeft className="w-4 h-4" /> Ver resultados
        </button>
        <a href="/dashboard"
          className="flex items-center gap-2 text-blue-700 hover:text-blue-900 font-semibold px-5 py-2.5 rounded-xl border border-blue-300 hover:bg-blue-50 transition-all">
          <RefreshCw className="w-4 h-4" /> Nuevo análisis
        </a>
      </div>
    </div>
  );
}
