'use client';
import { useState } from 'react';
import CanchariLogo from '@/components/branding/CanchariLogo';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { api, setToken, setUser } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { user, token } = await api.auth.login(form.email, form.password);
      setToken(token);
      setUser(user);
      router.push('/start');
    } catch (err: any) {
      setError(err.message || 'Error al iniciar sesión');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-slate-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8 flex flex-col items-center">
          <CanchariLogo width={220} showBackground={false} />
          <p className="text-slate-500 text-sm mt-2">Motor estadístico para tesis</p>
        </div>

        <div className="card">
          <h2 className="text-lg font-semibold text-slate-800 mb-6">Iniciar sesión</h2>

          {error && (
            <div className="mb-4 rounded-lg bg-rose-50 border border-rose-200 px-4 py-3 text-sm text-rose-700">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="label">Correo electrónico</label>
              <input
                type="email"
                className="input"
                placeholder="tu@email.com"
                value={form.email}
                onChange={e => setForm({ ...form, email: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="label">Contraseña</label>
              <input
                type="password"
                className="input"
                placeholder="••••••••"
                value={form.password}
                onChange={e => setForm({ ...form, password: e.target.value })}
                required
              />
            </div>
            <button type="submit" className="btn-primary w-full" disabled={loading}>
              {loading ? 'Ingresando…' : 'Ingresar'}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-slate-500">
            ¿No tienes cuenta?{' '}
            <Link href="/register" className="font-medium text-indigo-600 hover:text-indigo-700">
              Regístrate gratis
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
