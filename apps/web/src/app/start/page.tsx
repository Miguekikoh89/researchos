'use client';
import { useRouter } from 'next/navigation';
import { Compass, LayoutGrid, ArrowRight, Sparkles, FlaskConical, ChevronRight } from 'lucide-react';

export default function StartPage() {
  const router = useRouter();

  return (
    <div className="min-h-screen bg-slate-950 text-white overflow-x-hidden relative">

      {/* Background glow — same language as landing */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[500px] bg-indigo-600/20 rounded-full blur-[130px]" />
        <div className="absolute top-1/4 left-[10%] w-[400px] h-[400px] bg-cyan-600/10 rounded-full blur-[110px]" />
        <div className="absolute top-1/3 right-[10%] w-[400px] h-[400px] bg-purple-600/10 rounded-full blur-[110px]" />
      </div>

      {/* NAV */}
      <nav className="relative z-10 max-w-6xl mx-auto px-6 py-8 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-500/30">
            <FlaskConical className="w-5 h-5 text-white" />
          </div>
          <span className="font-bold text-lg tracking-tight">CanchariOS</span>
        </div>
        <button onClick={() => router.push('/dashboard')} className="text-sm text-slate-400 hover:text-white font-medium transition">
          Saltar e ir al panel →
        </button>
      </nav>

      {/* HERO */}
      <section className="relative z-10 max-w-4xl mx-auto px-6 pt-12 pb-6 text-center">
        <div className="inline-flex items-center gap-2 bg-indigo-500/10 border border-indigo-500/20 rounded-full px-4 py-2 text-sm text-indigo-300 font-semibold mb-8">
          <Sparkles className="w-4 h-4 text-indigo-400" />
          Bienvenido a tu espacio de análisis
        </div>
        <h1 className="text-5xl md:text-6xl font-black leading-[1.05] tracking-tight mb-6">
          ¿Cómo quieres
          <span className="block bg-gradient-to-r from-indigo-400 via-purple-400 to-cyan-400 bg-clip-text text-transparent">
            comenzar hoy?
          </span>
        </h1>
        <p className="text-lg text-slate-400 max-w-xl mx-auto leading-relaxed">
          Elige la ruta que mejor se adapte a tu experiencia. Las dos te llevan
          al mismo lugar: resultados confiables para tu investigación.
        </p>
      </section>

      {/* TWO PATHS */}
      <section className="relative z-10 max-w-5xl mx-auto px-6 py-10">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

          {/* CARD 1 — Guided */}
          <button
            onClick={() => router.push('/research')}
            className="group relative text-left bg-gradient-to-br from-indigo-950/80 to-slate-900 border-2 border-indigo-500/30 hover:border-indigo-400/60 rounded-3xl p-8 transition-all hover:-translate-y-1 hover:shadow-2xl hover:shadow-indigo-500/20 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
          >
            <span className="absolute top-6 right-6 bg-indigo-500/20 border border-indigo-400/30 text-indigo-300 text-xs font-bold uppercase tracking-wide px-3 py-1 rounded-full">
              Recomendado si tienes dudas
            </span>
            <div className="w-14 h-14 bg-indigo-600/30 border border-indigo-400/30 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-105 transition-transform">
              <Compass className="w-7 h-7 text-indigo-300" />
            </div>
            <h2 className="text-2xl font-black text-white mb-1">Necesito orientación metodológica</h2>
            <p className="text-indigo-300 text-sm font-semibold mb-4">No estoy seguro de qué análisis utilizar</p>
            <p className="text-slate-400 leading-relaxed mb-6">
              Responde algunas preguntas sobre tu investigación y CanchariOS analizará tu objetivo,
              tus variables y su escala de medición para recomendarte el método estadístico más adecuado.
            </p>
            <span className="inline-flex items-center gap-2 text-indigo-300 font-bold group-hover:gap-3 transition-all">
              Iniciar asistente metodológico <ArrowRight className="w-5 h-5" />
            </span>
          </button>

          {/* CARD 2 — Direct */}
          <button
            onClick={() => router.push('/dashboard')}
            className="group relative text-left bg-gradient-to-br from-slate-900 to-slate-900 border-2 border-white/10 hover:border-cyan-400/40 rounded-3xl p-8 transition-all hover:-translate-y-1 hover:shadow-2xl hover:shadow-cyan-500/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400"
          >
            <div className="w-14 h-14 bg-cyan-600/20 border border-cyan-400/20 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-105 transition-transform">
              <LayoutGrid className="w-7 h-7 text-cyan-300" />
            </div>
            <h2 className="text-2xl font-black text-white mb-1">Ya sé qué análisis necesito</h2>
            <p className="text-cyan-300 text-sm font-semibold mb-4">Quiero seleccionar el método directamente</p>
            <p className="text-slate-400 leading-relaxed mb-6">
              Accede al catálogo completo de métodos estadísticos: PLS-SEM, correlación, regresión,
              ANOVA, validación de instrumentos y más. Carga tu base de datos y comienza.
            </p>
            <span className="inline-flex items-center gap-2 text-cyan-300 font-bold group-hover:gap-3 transition-all">
              Ver métodos estadísticos <ArrowRight className="w-5 h-5" />
            </span>
          </button>
        </div>

        <p className="text-center text-slate-500 text-sm mt-8">
          Podrás cambiar de ruta en cualquier momento, sin perder tu progreso.
        </p>
      </section>
    </div>
  );
}
