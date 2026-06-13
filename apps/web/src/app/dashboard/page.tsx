'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api, getUser, clearToken } from '@/lib/api';

const STATUS_BADGE: Record<string, string> = {
  COMPLETED:  'badge-green',
  PROCESSING: 'badge-blue',
  PENDING:    'badge-yellow',
  FAILED:     'badge-red',
};

const STATUS_LABEL: Record<string, string> = {
  COMPLETED:  'Completado',
  PROCESSING: 'Procesando',
  PENDING:    'Pendiente',
  FAILED:     'Error',
};

export default function DashboardPage() {
  const router = useRouter();
  const [user]   = useState(() => getUser());
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [newProjectName, setNewProjectName] = useState('');
  const [creating, setCreating] = useState(false);
  const [showCreate, setShowCreate] = useState(false);

  useEffect(() => {
    api.projects.dashboard()
      .then(setData)
      .catch(() => router.push('/login'))
      .finally(() => setLoading(false));
  }, [router]);

  async function createProject() {
    if (!newProjectName.trim()) return;
    setCreating(true);
    try {
      const project = await api.projects.create({ name: newProjectName.trim() });
      router.push(`/analysis/new?projectId=${project.id}`);
    } catch (err: any) {
      alert(err.message);
    } finally {
      setCreating(false);
    }
  }

  function logout() {
    clearToken();
    router.push('/login');
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-slate-400 text-sm animate-pulse">Cargando dashboard…</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Navbar */}
      <nav className="bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center">
            <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
          </div>
          <a href="/" className="font-semibold text-slate-800 hover:text-indigo-600 transition cursor-pointer">ResearchOS</a>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-sm text-slate-500">{user?.name}</span>
          <span className={user?.role === 'ADMIN' ? 'badge-red' : user?.role === 'ADVISOR' ? 'badge-blue' : 'badge-green'}>
            {user?.role === 'ADMIN' ? 'Admin' : user?.role === 'ADVISOR' ? 'Asesor' : 'Estudiante'}
          </span>
          {user?.role === 'ADMIN' && (
          <a href="/admin" className="text-sm font-bold text-indigo-600 hover:text-indigo-800 transition px-3 py-1.5 bg-indigo-50 rounded-lg">🛡️ Panel CEO</a>
        )}
        {user?.role === 'ADMIN' && (
          <a href="/admin" className="text-sm font-bold text-indigo-600 hover:text-indigo-800 transition px-3 py-1.5 bg-indigo-50 rounded-lg">🛡️ Panel CEO</a>
        )}
        <button onClick={logout} className="text-sm text-slate-500 hover:text-slate-700">
            Salir
          </button>
        </div>
      </nav>

      <main className="max-w-5xl mx-auto px-6 py-8">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">
              Hola, {user?.name?.split(' ')[0]} 👋
            </h1>
            <p className="text-slate-500 text-sm mt-1">
              Aquí están tus proyectos y análisis recientes
            </p>
          </div>
          <button
            className="btn-primary"
            onClick={() => setShowCreate(true)}
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Nuevo análisis
          </button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-4 mb-8">
          {[
            { label: 'Proyectos', value: data?.totalProjects ?? 0, icon: '📁' },
            { label: 'Análisis', value: data?.totalAnalyses ?? 0, icon: '🔬' },
            { label: 'Completados', value: data?.completedAnalyses ?? 0, icon: '✅' },
          ].map(stat => (
            <div key={stat.label} className="card flex items-center gap-4">
              <span className="text-3xl">{stat.icon}</span>
              <div>
                <p className="text-2xl font-bold text-slate-900">{stat.value}</p>
                <p className="text-sm text-slate-500">{stat.label}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Create project modal-ish */}
        {showCreate && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
              <h2 className="text-lg font-semibold mb-4">Nuevo proyecto de análisis</h2>
              <input
                className="input mb-4"
                placeholder="Ej: Correlación estrés-rendimiento académico"
                value={newProjectName}
                onChange={e => setNewProjectName(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && createProject()}
                autoFocus
              />
              <div className="flex gap-3">
                <button
                  className="btn-secondary flex-1"
                  onClick={() => { setShowCreate(false); setNewProjectName(''); }}
                >
                  Cancelar
                </button>
                <button
                  className="btn-primary flex-1"
                  onClick={createProject}
                  disabled={creating || !newProjectName.trim()}
                >
                  {creating ? 'Creando…' : 'Crear y configurar →'}
                </button>
              </div>
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-6">
          {/* Recent projects */}
          <div className="card">
            <h2 className="font-semibold text-slate-800 mb-4">Proyectos recientes</h2>
            {data?.projects?.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-slate-400 text-sm">Aún no tienes proyectos</p>
                <button
                  className="mt-3 text-indigo-600 text-sm font-medium hover:underline"
                  onClick={() => setShowCreate(true)}
                >
                  Crear el primero →
                </button>
              </div>
            ) : (
              <ul className="space-y-2">
                {data?.projects?.map((p: any) => (
                  <li key={p.id}>
                    <Link
                      href={`/analysis/new?projectId=${p.id}`}
                      className="flex items-center justify-between rounded-lg p-3 hover:bg-slate-50 transition group"
                    >
                      <div>
                        <p className="text-sm font-medium text-slate-800 group-hover:text-indigo-600">
                          {p.name}
                        </p>
                        <p className="text-xs text-slate-400 mt-0.5">
                          {p._count?.analysisJobs ?? 0} análisis
                        </p>
                      </div>
                      <svg className="w-4 h-4 text-slate-400 group-hover:text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                      </svg>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </div>

          {/* Recent jobs */}
          <div className="card">
            <h2 className="font-semibold text-slate-800 mb-4">Análisis recientes</h2>
            {data?.recentJobs?.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-slate-400 text-sm">Ningún análisis ejecutado aún</p>
              </div>
            ) : (
              <ul className="space-y-2">
                {data?.recentJobs?.map((j: any) => (
                  <li key={j.id} className="flex items-center justify-between rounded-lg p-3 hover:bg-slate-50">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-slate-700 truncate">{j.project?.name}</p>
                      <p className="text-xs text-slate-400 mt-0.5">
                        {new Date(j.createdAt).toLocaleDateString('es-PE')}
                        {j.result?.method && ` · ${j.result.method}`}
                      </p>
                    </div>
                    <span className={STATUS_BADGE[j.status] ?? 'badge-yellow'}>
                      {STATUS_LABEL[j.status] ?? j.status}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
