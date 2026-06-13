'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Users, BarChart2, Activity, Shield, CheckCircle, XCircle, Search, Download, Trash2, Eye, Lock, Unlock, TrendingUp } from 'lucide-react';

const API = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';
const tok = () => typeof window !== 'undefined' ? localStorage.getItem('ros_token') || '' : '';
const hdr = () => ({ Authorization: `Bearer ${tok()}`, 'Content-Type': 'application/json' });

export default function AdminPage() {
  const router = useRouter();
  const [tab, setTab] = useState<'stats'|'users'|'activity'|'metrics'|'logs'>('stats');
  const [stats, setStats] = useState<any>(null);
  const [users, setUsers] = useState<any[]>([]);
  const [activity, setActivity] = useState<any[]>([]);
  const [metrics, setMetrics] = useState<any>(null);
  const [logs, setLogs] = useState<any[]>([]);
  const [search, setSearch] = useState('');
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [userAnalyses, setUserAnalyses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [confirm, setConfirm] = useState<string|null>(null);

  const api = async (path: string, opts?: any) => {
    const r = await fetch(`${API}/admin/${path}`, { headers: hdr(), ...opts });
    if(r.status === 401 || r.status === 403) { router.push('/dashboard'); return null; }
    return r.json();
  };

  const load = async () => {
    setLoading(true);
    const [s, u, a, m] = await Promise.all([api('stats'), api('users'), api('activity'), api('metrics')]);
    if(s) setStats(s); if(u) setUsers(u); if(a) setActivity(a); if(m) setMetrics(m);
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const updateRole = async (id: string, role: string) => {
    await api(`users/${id}/role`, { method: 'PATCH', body: JSON.stringify({ role }) });
    load();
  };

  const toggleActive = async (id: string, active: boolean) => {
    await api(`users/${id}/active`, { method: 'PATCH', body: JSON.stringify({ active }) });
    load();
  };

  const deleteUser = async (id: string) => {
    if(confirm !== id) { setConfirm(id); return; }
    await api(`users/${id}`, { method: 'DELETE' });
    setConfirm(null); load();
  };

  const viewUserAnalyses = async (user: any) => {
    setSelectedUser(user);
    const data = await api(`users/${user.id}/analyses`);
    if(data) setUserAnalyses(data);
  };

  const exportCSV = () => {
    const rows = [['Nombre','Email','Rol','Proyectos','Análisis','Registro'],...users.map(u=>[u.name,u.email,u.role,u.projects,u.analyses,new Date(u.createdAt).toLocaleDateString('es-PE')])];
    const csv = rows.map(r=>r.join(',')).join('\n');
    const blob = new Blob([csv], {type:'text/csv'});
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob);
    a.download = 'usuarios_researchos.csv'; a.click();
  };

  const filtered = users.filter(u => u.name?.toLowerCase().includes(search.toLowerCase()) || u.email?.toLowerCase().includes(search.toLowerCase()));
  const catL: Record<string,string> = { correlacional:'Correlación', comparacion:'Comparación', anova:'ANOVA', regresion:'Regresión', logistica:'Logística', chi_cuadrado:'Chi²', instrumentos:'Validación' };
  const catC: Record<string,string> = { correlacional:'bg-indigo-100 text-indigo-700', comparacion:'bg-purple-100 text-purple-700', anova:'bg-amber-100 text-amber-700', regresion:'bg-green-100 text-green-700', logistica:'bg-pink-100 text-pink-700', chi_cuadrado:'bg-orange-100 text-orange-700', instrumentos:'bg-cyan-100 text-cyan-700' };

  if(loading) return <div className="min-h-screen bg-slate-50 flex items-center justify-center text-slate-500 text-lg">Cargando panel CEO...</div>;

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="bg-white border-b border-slate-200 px-8 py-4 flex items-center justify-between sticky top-0 z-10">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center"><Shield className="w-5 h-5 text-white"/></div>
          <div><p className="text-xl font-black text-slate-900">Panel CEO</p><p className="text-xs text-slate-500">ResearchOS — Control total</p></div>
        </div>
        <button onClick={() => router.push('/dashboard')} className="text-sm font-semibold text-slate-500 hover:text-slate-700">← Dashboard</button>
      </div>

      <div className="max-w-7xl mx-auto px-8 py-6 space-y-6">
        {/* KPIs */}
        {stats && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              {label:'Usuarios totales', value:stats.totalUsers, icon:Users, color:'indigo', sub:`+${stats.todayUsers} hoy · ${metrics?.activeUsers||0} activos 30d`},
              {label:'Análisis realizados', value:stats.totalJobs, icon:BarChart2, color:'green', sub:`+${stats.todayJobs} hoy`},
              {label:'Completados', value:stats.completedJobs, icon:CheckCircle, color:'emerald', sub:`${stats.totalJobs>0?Math.round(stats.completedJobs/stats.totalJobs*100):0}% éxito`},
              {label:'Fallidos', value:stats.failedJobs, icon:XCircle, color:'red', sub:'errores totales'},
            ].map(k=>(
              <div key={k.label} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
                <div className={`w-10 h-10 rounded-xl bg-${k.color}-100 flex items-center justify-center mb-3`}>
                  <k.icon className={`w-5 h-5 text-${k.color}-600`}/>
                </div>
                <p className="text-3xl font-black text-slate-900">{k.value}</p>
                <p className="text-sm font-semibold text-slate-600 mt-1">{k.label}</p>
                <p className="text-xs text-slate-400 mt-0.5">{k.sub}</p>
              </div>
            ))}
          </div>
        )}

        {/* Tabs */}
        <div className="flex gap-1 bg-slate-100 rounded-2xl p-1 w-fit flex-wrap">
          {([['stats','📊 Stats'],['users','👥 Usuarios'],['activity','📋 Actividad'],['metrics','📈 Métricas'],['logs','🔐 Logs']] as const).map(([t,l])=>(
            <button key={t} onClick={()=>setTab(t as any)}
              className={`px-4 py-2 rounded-xl text-sm font-bold transition ${tab===t?'bg-white text-slate-900 shadow-sm':'text-slate-500 hover:text-slate-700'}`}>{l}</button>
          ))}
        </div>

        {/* STATS */}
        {tab==='stats' && stats && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
              <h3 className="font-black text-slate-800 mb-4">Análisis por método</h3>
              <div className="space-y-3">
                {Object.entries(stats.byCategory||{}).sort((a:any,b:any)=>b[1]-a[1]).map(([cat,count]:any)=>(
                  <div key={cat} className="flex items-center justify-between">
                    <span className={`text-xs font-bold px-3 py-1 rounded-full ${catC[cat]||'bg-slate-100 text-slate-600'}`}>{catL[cat]||cat}</span>
                    <div className="flex items-center gap-3">
                      <div className="w-32 bg-slate-100 rounded-full h-2"><div className="bg-indigo-500 h-2 rounded-full" style={{width:`${stats.totalJobs>0?Math.round(count/stats.totalJobs*100):0}%`}}/></div>
                      <span className="text-sm font-bold text-slate-700 w-6 text-right">{count}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
              <h3 className="font-black text-slate-800 mb-4">Últimos 7 días</h3>
              <div className="space-y-2">
                {stats.days?.map((d:any)=>(
                  <div key={d.date} className="flex items-center gap-3 text-sm">
                    <span className="text-slate-400 w-16 text-xs">{d.date.slice(5)}</span>
                    <div className="flex gap-4">
                      <div className="flex items-center gap-1"><BarChart2 className="w-3 h-3 text-indigo-400"/><span className="font-semibold">{d.jobs}</span><span className="text-slate-400 text-xs">análisis</span></div>
                      <div className="flex items-center gap-1"><Users className="w-3 h-3 text-green-400"/><span className="font-semibold">{d.users}</span><span className="text-slate-400 text-xs">usuarios</span></div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* USERS */}
        {tab==='users' && (
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="relative flex-1 max-w-sm">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"/>
                <input className="input pl-9 text-sm" placeholder="Buscar por nombre o email..." value={search} onChange={e=>setSearch(e.target.value)}/>
              </div>
              <button onClick={exportCSV} className="flex items-center gap-2 text-sm font-bold text-indigo-600 hover:text-indigo-800 bg-indigo-50 px-4 py-2 rounded-xl transition">
                <Download className="w-4 h-4"/> Exportar CSV
              </button>
            </div>
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-slate-100">
                <h3 className="font-black text-slate-800">Usuarios ({filtered.length})</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Nombre','Email','Rol','Proyectos','Análisis','Estado','Registro','Acciones'].map(h=><th key={h} className="px-4 py-3 text-left font-semibold text-slate-600 text-xs">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {filtered.map((u:any)=>(
                      <tr key={u.id} className={`border-b border-slate-100 hover:bg-slate-50 ${!u.isActive?'opacity-50':''}`}>
                        <td className="px-4 py-3 font-semibold text-slate-800">{u.name}</td>
                        <td className="px-4 py-3 text-slate-500 text-xs">{u.email}</td>
                        <td className="px-4 py-3">
                          <select value={u.role} onChange={e=>updateRole(u.id,e.target.value)}
                            className="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white focus:outline-none focus:ring-1 focus:ring-indigo-400">
                            <option value="STUDENT">STUDENT</option>
                            <option value="ADVISOR">ADVISOR</option>
                            <option value="ADMIN">ADMIN</option>
                          </select>
                        </td>
                        <td className="px-4 py-3 text-center text-slate-600">{u.projects}</td>
                        <td className="px-4 py-3 text-center font-semibold text-indigo-600">{u.analyses}</td>
                        <td className="px-4 py-3">
                          <span className={`text-xs font-bold px-2 py-1 rounded-full ${u.isActive?'bg-green-100 text-green-700':'bg-red-100 text-red-700'}`}>
                            {u.isActive?'Activo':'Bloqueado'}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-slate-400 text-xs">{new Date(u.createdAt).toLocaleDateString('es-PE')}</td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-1">
                            <button onClick={()=>viewUserAnalyses(u)} title="Ver análisis" className="p-1.5 hover:bg-slate-100 rounded-lg transition"><Eye className="w-4 h-4 text-slate-500"/></button>
                            <button onClick={()=>toggleActive(u.id,!u.isActive)} title={u.isActive?'Bloquear':'Activar'} className="p-1.5 hover:bg-slate-100 rounded-lg transition">
                              {u.isActive?<Lock className="w-4 h-4 text-amber-500"/>:<Unlock className="w-4 h-4 text-green-500"/>}
                            </button>
                            <button onClick={()=>deleteUser(u.id)} title="Eliminar" className={`p-1.5 rounded-lg transition ${confirm===u.id?'bg-red-100':'hover:bg-slate-100'}`}>
                              <Trash2 className={`w-4 h-4 ${confirm===u.id?'text-red-600':'text-red-400'}`}/>
                            </button>
                            {confirm===u.id && <button onClick={()=>deleteUser(u.id)} className="text-xs bg-red-600 text-white px-2 py-1 rounded-lg font-bold">¿Confirmar?</button>}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            {/* User analyses modal */}
            {selectedUser && (
              <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
                  <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
                    <h3 className="font-black text-slate-800">Análisis de {selectedUser.name}</h3>
                    <button onClick={()=>setSelectedUser(null)} className="text-slate-400 hover:text-slate-600 text-xl font-bold">×</button>
                  </div>
                  <div className="overflow-y-auto flex-1">
                    {userAnalyses.length===0?<p className="text-slate-400 text-center py-8">Sin análisis</p>:(
                      <table className="w-full text-sm">
                        <thead className="bg-slate-50 border-b border-slate-200 sticky top-0">
                          <tr>{['Proyecto','Método','Estado','Fecha'].map(h=><th key={h} className="px-4 py-3 text-left font-semibold text-slate-600 text-xs">{h}</th>)}</tr>
                        </thead>
                        <tbody>
                          {userAnalyses.map((a:any)=>(
                            <tr key={a.id} className="border-b border-slate-100">
                              <td className="px-4 py-3 text-slate-700">{a.project}</td>
                              <td className="px-4 py-3"><span className={`text-xs font-bold px-2 py-1 rounded-full ${catC[a.category]||'bg-slate-100 text-slate-600'}`}>{catL[a.category]||a.category}</span></td>
                              <td className="px-4 py-3"><span className={`text-xs font-bold px-2 py-1 rounded-full ${a.status==='COMPLETED'?'bg-green-100 text-green-700':'bg-red-100 text-red-700'}`}>{a.status}</span></td>
                              <td className="px-4 py-3 text-slate-400 text-xs">{new Date(a.createdAt).toLocaleDateString('es-PE')}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ACTIVITY */}
        {tab==='activity' && (
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-100"><h3 className="font-black text-slate-800">Últimos 50 análisis</h3></div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-slate-50 border-b border-slate-200">
                  <tr>{['Usuario','Método','Estado','Fecha'].map(h=><th key={h} className="px-4 py-3 text-left font-semibold text-slate-600 text-xs">{h}</th>)}</tr>
                </thead>
                <tbody>
                  {activity.map((a:any)=>(
                    <tr key={a.id} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="px-4 py-3"><p className="font-semibold text-slate-800">{a.userName}</p><p className="text-xs text-slate-400">{a.user}</p></td>
                      <td className="px-4 py-3"><span className={`text-xs font-bold px-2 py-1 rounded-full ${catC[a.category]||'bg-slate-100 text-slate-600'}`}>{catL[a.category]||a.category}</span></td>
                      <td className="px-4 py-3"><span className={`text-xs font-bold px-2 py-1 rounded-full ${a.status==='COMPLETED'?'bg-green-100 text-green-700':a.status==='FAILED'?'bg-red-100 text-red-700':'bg-amber-100 text-amber-700'}`}>{a.status}</span></td>
                      <td className="px-4 py-3 text-slate-400 text-xs">{new Date(a.createdAt).toLocaleString('es-PE')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* METRICS */}
        {tab==='metrics' && metrics && (
          <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
            <h3 className="font-black text-slate-800 mb-2">Métricas últimos 6 meses</h3>
            <p className="text-sm text-slate-500 mb-6">Usuarios activos (30d): <span className="font-bold text-indigo-600">{metrics.activeUsers}</span></p>
            <div className="space-y-3">
              {metrics.months?.map((m:any)=>(
                <div key={m.month} className="flex items-center gap-4">
                  <span className="text-xs text-slate-400 w-16">{m.month.slice(5)}</span>
                  <div className="flex gap-6 flex-1">
                    <div className="flex items-center gap-2">
                      <div className="w-24 bg-slate-100 rounded-full h-2"><div className="bg-indigo-500 h-2 rounded-full" style={{width:`${Math.min(m.jobs*5,100)}%`}}/></div>
                      <span className="text-sm font-bold text-slate-700">{m.jobs}</span><span className="text-xs text-slate-400">análisis</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-24 bg-slate-100 rounded-full h-2"><div className="bg-green-500 h-2 rounded-full" style={{width:`${Math.min(m.users*10,100)}%`}}/></div>
                      <span className="text-sm font-bold text-slate-700">{m.users}</span><span className="text-xs text-slate-400">usuarios</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* LOGS */}
        {tab==='logs' && (
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="px-6 py-4 border-b border-slate-100"><h3 className="font-black text-slate-800">Log de accesos y acciones</h3></div>
            {logs.length===0?(
              <p className="text-slate-400 text-center py-12">No hay logs registrados aún</p>
            ):(
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200">
                    <tr>{['Usuario','Acción','Recurso','IP','Fecha'].map(h=><th key={h} className="px-4 py-3 text-left font-semibold text-slate-600 text-xs">{h}</th>)}</tr>
                  </thead>
                  <tbody>
                    {logs.map((l:any)=>(
                      <tr key={l.id} className="border-b border-slate-100 hover:bg-slate-50">
                        <td className="px-4 py-3"><p className="font-semibold">{l.user?.name}</p><p className="text-xs text-slate-400">{l.user?.email}</p></td>
                        <td className="px-4 py-3"><span className="text-xs font-bold bg-slate-100 text-slate-700 px-2 py-1 rounded">{l.action}</span></td>
                        <td className="px-4 py-3 text-slate-500">{l.resource}</td>
                        <td className="px-4 py-3 text-slate-400 text-xs">{l.ipAddress||'-'}</td>
                        <td className="px-4 py-3 text-slate-400 text-xs">{new Date(l.createdAt).toLocaleString('es-PE')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
