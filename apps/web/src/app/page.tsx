'use client';
import { useEffect, useState } from 'react';
import CanchariLogo from '@/components/branding/CanchariLogo';
import { useRouter } from 'next/navigation';
import { ArrowRight, BarChart2, Shield, Zap, BookOpen, TrendingUp, Users, CheckCircle, FlaskConical, Star } from 'lucide-react';

export default function HomePage() {
  const router = useRouter();
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('ros_token') : null;
    if (token) { router.replace('/start'); } else { setChecking(false); }
  }, [router]);

  if (checking) return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 bg-indigo-500 rounded-xl animate-pulse"/>
        <span className="text-slate-400 text-sm">Cargando...</span>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-slate-950 text-white overflow-x-hidden">

      {/* NAV */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-xl border-b border-white/5">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <CanchariLogo width={150} showBackground={false} />
          </div>
          <div className="flex items-center gap-3">
            <button onClick={() => router.push('/login')}
              className="px-5 py-2 text-sm font-semibold text-slate-300 hover:text-white transition">
              Iniciar sesión
            </button>
            <button onClick={() => router.push('/register')}
              className="px-5 py-2 text-sm font-semibold bg-indigo-600 hover:bg-indigo-500 rounded-xl transition shadow-lg shadow-indigo-500/20">
              Comenzar gratis
            </button>
          </div>
        </div>
      </nav>

      {/* HERO */}
      <section className="relative pt-32 pb-24 px-6">
        {/* Background glow */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-indigo-600/20 rounded-full blur-[120px]"/>
          <div className="absolute top-1/3 left-1/4 w-[400px] h-[300px] bg-purple-600/10 rounded-full blur-[100px]"/>
          <div className="absolute top-1/3 right-1/4 w-[400px] h-[300px] bg-cyan-600/10 rounded-full blur-[100px]"/>
        </div>

        <div className="max-w-5xl mx-auto text-center relative">
          <div className="inline-flex items-center gap-2 bg-indigo-500/10 border border-indigo-500/20 rounded-full px-4 py-2 text-sm text-indigo-300 font-semibold mb-8">
            <Star className="w-4 h-4 text-indigo-400"/>
            Motor estadístico R · Resultados APA 7 · Para tesis
          </div>

          <h1 className="text-6xl md:text-7xl font-black leading-[1.05] tracking-tight mb-8">
            Análisis estadístico
            <span className="block bg-gradient-to-r from-indigo-400 via-purple-400 to-cyan-400 bg-clip-text text-transparent">
              para tu tesis
            </span>
          </h1>

          <p className="text-xl text-slate-400 max-w-2xl mx-auto mb-12 leading-relaxed">
            Sube tu base de datos, configura tus variables y obtén resultados estadísticos
            completos con redacción APA 7 lista para pegar en tu tesis. Sin SPSS. Sin experiencia previa.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <button onClick={() => router.push('/register')}
              className="flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold px-8 py-4 rounded-2xl text-lg transition-all shadow-2xl shadow-indigo-500/30 hover:shadow-indigo-500/40 hover:-translate-y-0.5">
              Analizar mis datos ahora
              <ArrowRight className="w-5 h-5"/>
            </button>
            <button onClick={() => router.push('/login')}
              className="flex items-center justify-center gap-2 bg-white/5 hover:bg-white/10 border border-white/10 text-white font-semibold px-8 py-4 rounded-2xl text-lg transition-all">
              Ya tengo cuenta
            </button>
          </div>

          <p className="text-sm text-slate-500 mt-6">✓ Gratis · ✓ Sin instalación · ✓ Resultados en minutos</p>
        </div>

        {/* Stats preview card */}
        <div className="max-w-4xl mx-auto mt-20 relative">
          <div className="bg-slate-900 rounded-3xl border border-white/10 p-6 shadow-2xl">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-3 h-3 rounded-full bg-red-500"/>
              <div className="w-3 h-3 rounded-full bg-yellow-500"/>
              <div className="w-3 h-3 rounded-full bg-green-500"/>
              <span className="text-slate-500 text-xs ml-3">CanchariOS · Resultados del análisis</span>
            </div>
            <div className="grid grid-cols-4 gap-4 mb-6">
              {[
                { label:'Correlación', value:'ρ = .842', color:'text-indigo-400', bg:'bg-indigo-500/10' },
                { label:'p-valor',     value:'< .001',  color:'text-green-400',  bg:'bg-green-500/10'  },
                { label:'IC 95%',      value:'[.79, .88]', color:'text-purple-400', bg:'bg-purple-500/10' },
                { label:'Potencia',    value:'100%',    color:'text-cyan-400',   bg:'bg-cyan-500/10'   },
              ].map(k => (
                <div key={k.label} className={`${k.bg} rounded-xl p-4 text-center`}>
                  <p className="text-xs text-slate-500 mb-1">{k.label}</p>
                  <p className={`text-xl font-black ${k.color}`}>{k.value}</p>
                </div>
              ))}
            </div>
            <div className="bg-indigo-500/5 border border-indigo-500/20 rounded-2xl p-4">
              <p className="text-xs font-bold text-indigo-400 uppercase tracking-wider mb-2">Redacción APA 7 automática</p>
              <p className="text-slate-300 text-sm italic leading-relaxed">
                "Se observa una relación positiva, muy alta y estadísticamente significativa entre Variable A y Variable B, ρ = .842, p {'<'} .001. Esto indica que, a mayores niveles de Variable A, tienden a presentarse mayores niveles de Variable B..."
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* METHODS */}
      <section className="py-24 px-6 border-t border-white/5">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <p className="text-indigo-400 font-bold text-sm uppercase tracking-widest mb-4">Métodos estadísticos</p>
            <h2 className="text-4xl font-black">Todo lo que necesita tu tesis</h2>
            <p className="text-slate-400 mt-4 text-lg">El sistema elige automáticamente el método correcto según tus datos</p>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { icon:'📈', label:'Correlación', desc:'Pearson · Spearman · Kendall · IC Fisher', color:'indigo' },
              { icon:'🛡️', label:'Confiabilidad', desc:'Alfa Cronbach · Omega McDonald · Ítem-total', color:'purple' },
              { icon:'⚖️', label:'Comparación', desc:'t Student · Mann-Whitney · Wilcoxon', color:'amber' },
              { icon:'📊', label:'ANOVA', desc:'F Fisher · Kruskal-Wallis · Tukey · Dunn', color:'green' },
              { icon:'📉', label:'Regresión lineal', desc:'Simple · Múltiple · 7 supuestos · VIF', color:'cyan' },
              { icon:'🎯', label:'Reg. logística', desc:'Binaria · Ordinal · OR · Hosmer-Lemeshow', color:'pink' },
              { icon:'📋', label:'Chi-cuadrado', desc:'Pearson · Yates · Fisher · V Cramer', color:'orange' },
              { icon:'🔬', label:'Validación', desc:'AFE · AFC · HTMT · V Aiken · CR · AVE', color:'teal' },
            ].map(m => (
              <div key={m.label} className="bg-slate-900 hover:bg-slate-800 border border-white/5 hover:border-white/10 rounded-2xl p-5 transition-all hover:-translate-y-1 cursor-default">
                <span className="text-3xl block mb-3">{m.icon}</span>
                <p className="font-bold text-white mb-1">{m.label}</p>
                <p className="text-xs text-slate-500 leading-relaxed">{m.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="py-24 px-6 bg-slate-900/50 border-t border-white/5">
        <div className="max-w-5xl mx-auto">
          <div className="text-center mb-16">
            <p className="text-indigo-400 font-bold text-sm uppercase tracking-widest mb-4">Cómo funciona</p>
            <h2 className="text-4xl font-black">Del Excel a la tesis en 5 pasos</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            {[
              { step:'01', icon:'📁', label:'Sube tu Excel', desc:'Arrastra tu base de datos o selecciona el archivo' },
              { step:'02', icon:'⚙️', label:'Configura', desc:'Elige el método y define tus variables' },
              { step:'03', icon:'⚡', label:'Analiza', desc:'El motor R procesa tus datos en segundos' },
              { step:'04', icon:'📊', label:'Resultados', desc:'Tablas completas con interpretación APA 7' },
              { step:'05', icon:'📄', label:'Exporta Word', desc:'Documento listo para pegar en tu tesis' },
            ].map((s, i) => (
              <div key={i} className="relative text-center">
                <div className="w-14 h-14 bg-indigo-600/20 border border-indigo-500/30 rounded-2xl flex items-center justify-center text-2xl mx-auto mb-4">
                  {s.icon}
                </div>
                <p className="text-xs font-black text-indigo-500 mb-1">{s.step}</p>
                <p className="font-bold text-white mb-2">{s.label}</p>
                <p className="text-xs text-slate-500 leading-relaxed">{s.desc}</p>
                {i < 4 && <div className="hidden md:block absolute top-7 left-[60%] w-[40%] h-px bg-gradient-to-r from-indigo-500/30 to-transparent"/>}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section className="py-24 px-6 border-t border-white/5">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-8">
          {[
            { icon: Zap, title:'Selección automática', desc:'El sistema verifica normalidad (Shapiro-Wilk), homogeneidad (Levene) y elige el método correcto: paramétrico o no paramétrico.', color:'yellow' },
            { icon: Shield, title:'Idéntico a SPSS', desc:'Algoritmos validados contra SPSS Statistics 29. Mismos coeficientes, mismos p-valores, mismos intervalos de confianza.', color:'green' },
            { icon: BookOpen, title:'Redacción APA lista', desc:'Cada resultado incluye su interpretación en español y la redacción académica lista para copiar en tu tesis.', color:'indigo' },
          ].map((f, i) => (
            <div key={i} className="bg-slate-900 border border-white/5 rounded-3xl p-8">
              <div className={`w-12 h-12 rounded-2xl flex items-center justify-center mb-6 ${
                f.color==='yellow'?'bg-yellow-500/10':'bg-'+f.color+'-500/10'
              }`}>
                <f.icon className={`w-6 h-6 ${f.color==='yellow'?'text-yellow-400':f.color==='green'?'text-green-400':'text-indigo-400'}`}/>
              </div>
              <h3 className="text-xl font-bold text-white mb-3">{f.title}</h3>
              <p className="text-slate-400 leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="py-24 px-6 border-t border-white/5">
        <div className="max-w-3xl mx-auto text-center">
          <div className="bg-gradient-to-br from-indigo-600/20 to-purple-600/20 border border-indigo-500/20 rounded-3xl p-12">
            <h2 className="text-4xl font-black mb-4">¿Listo para analizar tus datos?</h2>
            <p className="text-slate-400 text-lg mb-8">Únete a cientos de estudiantes que ya obtienen sus resultados estadísticos en minutos.</p>
            <button onClick={() => router.push('/register')}
              className="inline-flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold px-10 py-4 rounded-2xl text-lg transition-all shadow-2xl shadow-indigo-500/30 hover:-translate-y-0.5">
              Crear cuenta gratis
              <ArrowRight className="w-5 h-5"/>
            </button>
            <p className="text-slate-500 text-sm mt-4">Sin tarjeta de crédito · Acceso inmediato</p>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="border-t border-white/5 py-8 px-6">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CanchariLogo width={110} showBackground={false} />
            <span className="text-slate-600 text-sm">· Motor estadístico APA 7</span>
          </div>
          <p className="text-slate-600 text-sm">Hecho para investigadores latinoamericanos</p>
        </div>
      </footer>
    </div>
  );
}
