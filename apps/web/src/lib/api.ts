const API_URL =
  process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';

function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('ros_token');
}

export function setToken(token: string) {
  localStorage.setItem('ros_token', token);
}

export function clearToken() {
  localStorage.removeItem('ros_token');
  localStorage.removeItem('ros_user');
}

export function getUser() {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem('ros_user');
  return raw ? JSON.parse(raw) : null;
}

export function setUser(user: any) {
  localStorage.setItem('ros_user', JSON.stringify(user));
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${API_URL}${path}`, { ...options, headers });

  if (res.status === 401) {
    clearToken();
    if (typeof window !== 'undefined') window.location.href = '/login';
    throw new Error('No autorizado');
  }

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.message || `Error ${res.status}`);
  }
  return data as T;
}

// ── Auth ──────────────────────────────────────────────────────────────────────
export const api = {
  auth: {
    register: (name: string, email: string, password: string, role?: string) =>
      request<{ user: any; token: string }>('/auth/register', {
        method: 'POST',
        body: JSON.stringify({ name, email, password, role }),
      }),
    login: (email: string, password: string) =>
      request<{ user: any; token: string }>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      }),
    me: () => request<any>('/auth/me'),
  },

  // ── Projects ──────────────────────────────────────────────────────────────
  projects: {
    dashboard: () => request<any>('/projects/dashboard'),
    list: () => request<any[]>('/projects'),
    get: (id: string) => request<any>(`/projects/${id}`),
    create: (data: { name: string; description?: string }) =>
      request<any>('/projects', { method: 'POST', body: JSON.stringify(data) }),
  },

  // ── Datasets ──────────────────────────────────────────────────────────────
  datasets: {
    upload: (projectId: string, file: File) => {
      const form = new FormData();
      form.append('file', file);
      const token = getToken();
      return fetch(`${API_URL}/projects/${projectId}/datasets`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
      }).then((r) => r.json());
    },
    preview: (projectId: string, datasetId: string) =>
      request<any>(`/projects/${projectId}/datasets/${datasetId}/preview`),
  },

  // ── Analysis ──────────────────────────────────────────────────────────────
  analysis: {
    create: (projectId: string, config: any) =>
      request<{ jobId: string }>(`/projects/${projectId}/analysis`, {
        method: 'POST',
        body: JSON.stringify(config),
      }),
    get: (projectId: string, jobId: string) =>
      request<any>(`/projects/${projectId}/analysis/${jobId}`),
    result: (projectId: string, jobId: string) =>
      request<any>(`/projects/${projectId}/analysis/${jobId}/result`),
    downloadWord: async (projectId: string, jobId: string) => {
      const token = getToken();
      const res = await fetch(
        `${API_URL}/projects/${projectId}/analysis/${jobId}/download/word`,
        { headers: token ? { Authorization: `Bearer ${token}` } : {} },
      );
      if (!res.ok) throw new Error('Error al descargar el Word');
      return res.blob();
    },
  },
};
