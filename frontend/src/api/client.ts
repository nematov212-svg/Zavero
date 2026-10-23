const BASE_URL = import.meta.env.VITE_API_URL || '';

interface FetchOptions extends RequestInit {
  params?: Record<string, string | number | undefined>;
}

export async function request<T>(endpoint: string, options: FetchOptions = {}): Promise<T> {
  let url = `${BASE_URL}${endpoint}`;

  if (options.params) {
    const searchParams = new URLSearchParams();
    Object.entries(options.params).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        searchParams.append(key, String(value));
      }
    });
    const queryString = searchParams.toString();
    if (queryString) {
      url += (url.includes('?') ? '&' : '?') + queryString;
    }
  }

  const token = localStorage.getItem('zavero_token');
  const headers = new Headers(options.headers || {});

  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  const contentType = response.headers.get('content-type');
  const isJson = contentType && contentType.includes('application/json');
  const data = isJson ? await response.json() : await response.text();

  if (!response.ok) {
    const message = (data && typeof data === 'object' && (data as any).message) 
      ? (data as any).message 
      : `Xatolik: ${response.status} ${response.statusText}`;
    throw new Error(message);
  }

  return data as T;
}
