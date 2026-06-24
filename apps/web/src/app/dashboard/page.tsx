'use client';
import React from 'react';
import CanchariLogo from '@/components/branding/CanchariLogo';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { BarChart2, FlaskConical, Shield, LogOut, Plus, ChevronRight, Clock, CheckCircle, BookOpen, Compass, Users } from 'lucide-react';

const API = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';


function MethodCard({ method, onSelect }: { method: any; onSelect: () => void }) {
  const [hovered, setHovered] = React.useState(false);
  return (
    <button type="button" onClick={onSelect}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className="relative group rounded-3xl p-5 text-left transition-all duration-300 hover:scale-105 hover:-translate-y-1 border"
      style={{
        background: hovered
          ? 'linear-gradient(135deg,' + method.from + ',' + method.to + ')'
          : 'linear-gradient(135deg,' + method.from + '22,' + method.to + '22)',
        borderColor: hovered ? 'rgba(255,255,255,0.3)' : method.from + '44',
        minHeight: '160px',
      }}>
      <span className="absolute -top-2.5 -right-2.5 text-xs font-bold px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 border border-slate-700">
        {method.badge}
      </span>
      <div className="text-3xl mb-3">{method.icon}</div>
      <p className="font-black text-sm mb-1 text-slate-200 group-hover:text-white transition-colors">{method.label}</p>
      <p className="text-xs text-slate-500 group-hover:text-slate-400 transition-colors leading-relaxed">{method.desc}</p>
      <div className={'mt-3 text-xs font-bold text-slate-500 transition-all duration-200 ' + (hovered ? 'opacity-100' : 'opacity-0')}>
        Comenzar →
      </div>
    </button>
  );
}

export default function DashboardPage() {
  const router = useRouter();
  const [user, setUser]   = useState<any>(null);
  const [data, setData]   = useState<any>(null);
  const [jobs, setJobs]   = useState<any[]>([]);
  const [projs, setProjs] = useState<any[]>([]);

  const tok = () => localStorage.getItem('ros_token') || '';
  const hdr = () => ({ Authorization: `Bearer ${tok()}` });

  useEffect(() => {
    if(!tok()) { router.push('/login'); return; }
    fetch(`${API}/auth/me`, { headers: hdr() }).then(r=>r.json()).then(u => {
      if(!u.id) { router.push('/login'); return; }
      setUser(u);
    });
    fetch(`${API}/projects/dashboard`, { headers: hdr() }).then(r=>r.json()).then(setData);
    fetch(`${API}/projects`, { headers: hdr() }).then(r=>r.json()).then(d => setProjs(Array.isArray(d)?d.slice(0,4):[]));
  }, []);

  const logout = () => { localStorage.removeItem('ros_token'); router.push('/login'); };

  const catLabel: Record<string,string> = {
    correlacional:'Correlación', comparacion:'Comparación', anova:'ANOVA',
    regresion:'Regresión', logistica:'Logística', chi_cuadrado:'Chi²',
    instrumentos:'Validación', correlational:'Correlación',
  };
  const catColor: Record<string,string> = {
    correlacional:'bg-indigo-100 text-indigo-700', comparacion:'bg-purple-100 text-purple-700',
    anova:'bg-amber-100 text-amber-700', regresion:'bg-green-100 text-green-700',
    logistica:'bg-pink-100 text-pink-700', chi_cuadrado:'bg-orange-100 text-orange-700',
    instrumentos:'bg-cyan-100 text-cyan-700',
  };

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Buenos días' : hour < 19 ? 'Buenas tardes' : 'Buenas noches';

  return (
    <div className="min-h-screen bg-slate-50">

      {/* Navbar */}
      <nav className="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-3">
          <a href="/start" className="flex items-center gap-3 hover:opacity-80 transition">
            <CanchariLogo width={140} showBackground={false} />
          </a>
        </div>
        <div className="flex items-center gap-3">
          {user?.role === 'ADMIN' && (
            <a href="/admin" className="flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-indigo-600 transition px-3 py-1.5 rounded-lg hover:bg-indigo-50">
              <Shield className="w-3.5 h-3.5"/> Panel CEO
            </a>
          )}
          <div className="flex items-center gap-2 px-3 py-1.5 bg-slate-50 rounded-xl">
            <div className="w-7 h-7 bg-indigo-100 rounded-lg flex items-center justify-center">
              <span className="text-indigo-700 font-black text-xs">{user?.name?.[0]?.toUpperCase()}</span>
            </div>
            <div>
              <p className="text-xs font-bold text-slate-700">{user?.name}</p>
              <p className="text-xs text-slate-400">{user?.role === 'ADMIN' ? 'Admin' : user?.role === 'ADVISOR' ? 'Asesor' : 'Estudiante'}</p>
            </div>
          </div>
          <button onClick={logout} className="p-2 hover:bg-red-50 rounded-lg transition text-slate-400 hover:text-red-500">
            <LogOut className="w-4 h-4"/>
          </button>
        </div>
      </nav>

      <div className="w-full">

        {/* Hero oscuro */}
        <div className="bg-slate-950 w-full px-8 pt-8 pb-14">
          {/* Top row */}
          <div className="max-w-6xl mx-auto flex items-center justify-between mb-10">
            <div>
              <p className="text-slate-500 text-sm">{greeting},</p>
              <h1 className="text-3xl font-black text-white mt-0.5">{user?.name?.split(' ')[0] || 'Investigador'} 👋</h1>
            </div>
            <div className="flex gap-3">
              {[
                { label:'Proyectos', value:data?.totalProjects ?? 0, color:'text-cyan-400' },
                { label:'Análisis', value:data?.totalJobs ?? 0, color:'text-purple-400' },
                { label:'Completados', value:data?.completedJobs ?? 0, color:'text-green-400' },
              ].map(stat => (
                <div key={stat.label} className="bg-slate-900 border border-slate-800 rounded-2xl px-5 py-3 text-center min-w-20">
                  <p className={'text-2xl font-black ' + stat.color}>{stat.value}</p>
                  <p className="text-xs text-slate-500 mt-0.5">{stat.label}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Title */}
          <div className="max-w-6xl mx-auto text-center mb-10">
            <div className="inline-flex items-center gap-2 bg-slate-900 border border-slate-700 rounded-full px-4 py-2 mb-5">
              <span className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse inline-block"/>
              <span className="text-slate-300 text-sm font-semibold">Motor estadístico APA 7 · CanchariOS</span>
            </div>
            <h2 className="text-6xl font-black text-white mb-4 leading-tight">
              ¿Qué quieres<br/>
              <span style={{background:'linear-gradient(90deg,#22d3ee,#818cf8,#c084fc)',WebkitBackgroundClip:'text',WebkitTextFillColor:'transparent'}}>
                analizar hoy?
              </span>
            </h2>
            <p className="text-slate-400 text-lg">Selecciona tu método — sube tus datos — resultados APA 7</p>
          </div>

          {/* Grid de métodos */}
          <div className="max-w-6xl mx-auto grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            {[
              { id:'structural_model',     label:'PLS-SEM',              desc:'Ecuaciones estructurales',         icon:'🔷', badge:'⭐ Avanzado',   from:'#06b6d4', to:'#2563eb' },
              { id:'correlacional',        label:'Correlacional',        desc:'Relacion entre dos variables',     icon:'📈', badge:'🔥 Muy usado',  from:'#6366f1', to:'#a855f7' },
              { id:'regresion',            label:'Regresion lineal',     desc:'Prediccion variable continua',     icon:'📉', badge:'📚 Pregrado',   from:'#10b981', to:'#059669' },
              { id:'regresion_ordinal',    label:'Regresion ordinal',    desc:'VD ordinal bajo/medio/alto',       icon:'📊', badge:'🎓 Postgrado',  from:'#0ea5e9', to:'#0369a1' },
              { id:'regresion_jerarquica', label:'Reg. jerarquica',      desc:'Bloques de predictores',           icon:'📐', badge:'🎓 Postgrado',  from:'#8b5cf6', to:'#6d28d9' },
              { id:'logistica',            label:'Reg. logistica',       desc:'Prediccion variable categorica',   icon:'🎯', badge:'🎓 Postgrado',  from:'#ec4899', to:'#f43f5e' },
              { id:'comparacion',          label:'Comparacion',          desc:'Diferencias entre 2 grupos',       icon:'⚖️', badge:'📚 Pregrado',   from:'#8b5cf6', to:'#ec4899' },
              { id:'anova',                label:'ANOVA',                desc:'Comparar 3 o mas grupos',          icon:'📊', badge:'🔥 Muy usado',  from:'#f59e0b', to:'#ef4444' },
              { id:'ancova',               label:'ANCOVA',               desc:'ANOVA con covariable',             icon:'🔬', badge:'🎓 Postgrado',  from:'#f97316', to:'#dc2626' },
              { id:'discriminante',        label:'Discriminante',        desc:'Clasificar grupos',                icon:'🧩', badge:'🎓 Postgrado',  from:'#14b8a6', to:'#0891b2' },
              { id:'chi_cuadrado',         label:'Chi-cuadrado',         desc:'Asociacion variables categoricas', icon:'📋', badge:'📚 Pregrado',   from:'#f97316', to:'#dc2626' },
              { id:'cluster',              label:'Analisis cluster',     desc:'Agrupar casos similares',          icon:'🔵', badge:'🎓 Postgrado',  from:'#6366f1', to:'#4f46e5' },
              { id:'instrumentos',         label:'Validar instrumento',  desc:'AFE AFC Alpha CR AVE',             icon:'🔬', badge:'⭐ Avanzado',   from:'#14b8a6', to:'#0891b2' },
              { id:'cronbach',             label:'Alfa de Cronbach',     desc:'Solo confiabilidad',               icon:'🛡️', badge:'📚 Pregrado',   from:'#3b82f6', to:'#1d4ed8' },
              { id:'descriptivo',          label:'Analisis Descriptivo', desc:'Media DE moda baremos y niveles',  icon:'📑', badge:'📚 Pregrado',   from:'#10b981', to:'#3f6212' },
            ].map(m => (
              <MethodCard key={m.id} method={m} onSelect={() => router.push('/analysis/new?method=' + m.id)} />
            ))}
          </div>

          {/* Herramientas metodológicas */}
          <div className="max-w-6xl mx-auto grid grid-cols-2 gap-3">
            <button onClick={() => router.push('/research/sampling')}
              className="flex items-center gap-3 bg-slate-900 border border-slate-800 hover:border-teal-500/40 rounded-2xl p-4 text-left transition-all group">
              <div className="w-10 h-10 bg-teal-500/10 rounded-xl flex items-center justify-center flex-shrink-0">
                <Users className="w-5 h-5 text-teal-400"/>
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-black text-slate-200 text-sm">Población y Muestra</p>
                <p className="text-xs text-slate-500 mt-0.5 truncate">Cochran · G*Power · PLS-SEM · Texto tesis</p>
              </div>
              <ChevronRight className="w-4 h-4 text-slate-600 flex-shrink-0"/>
            </button>
            <button onClick={() => router.push('/research')}
              className="flex items-center gap-3 bg-slate-900 border border-slate-800 hover:border-indigo-500/40 rounded-2xl p-4 text-left transition-all group">
              <div className="w-10 h-10 bg-indigo-500/10 rounded-xl flex items-center justify-center flex-shrink-0">
                <Compass className="w-5 h-5 text-indigo-400"/>
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-black text-slate-200 text-sm">Asistente metodológico</p>
                <p className="text-xs text-slate-500 mt-0.5 truncate">Variables · Dimensiones · Operacionalización</p>
              </div>
              <ChevronRight className="w-4 h-4 text-slate-600 flex-shrink-0"/>
            </button>
          </div>
        </div>





        {/* Recent projects */}
        {projs.length > 0 && (
          <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-black text-slate-800">Proyectos recientes</h2>
              <button onClick={() => router.push('/analysis/new')}
                className="flex items-center gap-1 text-xs font-bold text-indigo-600 hover:text-indigo-800 transition">
                <Plus className="w-3 h-3"/> Nuevo
              </button>
            </div>
            <div className="space-y-2">
              {projs.map((p:any) => (
                <button key={p.id} onClick={() => router.push(`/analysis/new?projectId=${p.id}`)}
                  className="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 transition group border border-transparent hover:border-slate-200">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-indigo-100 rounded-lg flex items-center justify-center">
                      <BookOpen className="w-4 h-4 text-indigo-600"/>
                    </div>
                    <div className="text-left">
                      <p className="font-bold text-slate-800 text-sm">{p.name}</p>
                      <p className="text-xs text-slate-400">{p._count?.jobs ?? 0} análisis · {new Date(p.createdAt).toLocaleDateString('es-PE')}</p>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-slate-300 group-hover:text-indigo-500 transition"/>
                </button>
              ))}
            </div>
          </div>
        )}

        {projs.length === 0 && (
          <div className="bg-white rounded-2xl border-2 border-dashed border-slate-200 p-10 text-center">
            <div className="w-14 h-14 bg-indigo-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
              <Compass className="w-7 h-7 text-indigo-600"/>
            </div>
            <h3 className="font-black text-slate-800 mb-2">Comienza tu primera investigación</h3>
            <p className="text-slate-400 text-sm mb-5">Usa el asistente metodológico para construir tu investigación paso a paso.</p>
            <button onClick={() => router.push('/research')}
              className="btn-primary mx-auto">
              🧭 Iniciar asistente metodológico
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
