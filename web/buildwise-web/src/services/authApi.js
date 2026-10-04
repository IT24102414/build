import { fetchOrThrow, API_BASE } from './apiTransport'

const STORAGE_KEY = 'buildwise.auth'

async function request(path, body) {
  const res = await fetchOrThrow(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  })

  if (!res.ok) {
    let message = `Request failed (${res.status})`
    let payload = null
    try {
      const data = await res.json()
      payload = data
      // `error` is the auth controller's key; `message` covers ValidationProblemDetails.
      message = data?.error || data?.message || message
    } catch {
      // no JSON body
    }
    const error = new Error(message)
    error.status = res.status
    error.payload = payload
    throw error
  }

  return res.json()
}

export const authApi = {
  login: (email, password) => request('/auth/login', { email, password }),
  register: (fullName, email, password, roleName) => request('/auth/register', { fullName, email, password, roleName }),

  loadSession: () => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  },
  saveSession: (session) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(session))
    } catch {
      // localStorage unavailable (private mode, etc.) — session just won't persist across reloads
    }
  },
  clearSession: () => {
    try {
      localStorage.removeItem(STORAGE_KEY)
    } catch {
      // ignore
    }
  }
}

export default authApi
