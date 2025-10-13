export type ScoreResponse = {
  llm: { score: number; reasons?: string[]; raw?: string }
  empirical: { score: number; reasons?: string[]; details?: Record<string, unknown> }
  average: number
  suggested_prompt?: string
}

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000'

const DEVICE_KEY = 'ctx_device_id'

export function getDeviceId(): string {
  try {
    let id = localStorage.getItem(DEVICE_KEY)
    if (!id) {
      // Prefer crypto UUID; fallback to timestamp-rand
      // @ts-ignore - older browsers
      id = (globalThis.crypto?.randomUUID?.() as string) || `dev-${Date.now()}-${Math.random().toString(36).slice(2)}`
      localStorage.setItem(DEVICE_KEY, id)
      // also set a cookie for server logs/aux systems; 1 year
      document.cookie = `${DEVICE_KEY}=${id}; path=/; max-age=31536000; samesite=lax`
    }
    return id
  } catch {
    // No storage; ephemeral id
    return `dev-${Date.now()}-${Math.random().toString(36).slice(2)}`
  }
}

function authHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'X-Device-Id': getDeviceId(),
  }
}

export async function scorePrompt(prompt: string, signal?: AbortSignal): Promise<ScoreResponse> {
  const res = await fetch(`${BASE_URL}/api/v1/score`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ prompt }),
    signal,
  })
  if (res.status === 402) {
    const body = await res.json().catch(() => ({}))
    return Promise.reject({ status: 402, body })
  }
  if (!res.ok) throw new Error(`Score failed: ${res.status}`)
  return res.json()
}

export type DeviceStatus = { paid: boolean; remaining_uses: number }

export async function getDeviceStatus(signal?: AbortSignal): Promise<DeviceStatus> {
  const res = await fetch(`${BASE_URL}/api/v1/device/status`, {
    method: 'GET',
    headers: authHeaders(),
    signal,
  })
  if (!res.ok) throw new Error(`Status failed: ${res.status}`)
  return res.json()
}

export async function createCheckout(signal?: AbortSignal): Promise<{ url: string }> {
  const res = await fetch(`${BASE_URL}/api/v1/payments/checkout`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ device_id: getDeviceId() }),
    signal,
  })
  if (!res.ok) throw new Error(`Checkout failed: ${res.status}`)
  return res.json()
}

export async function confirmCheckout(sessionId: string, signal?: AbortSignal): Promise<{ paid: boolean }> {
  const res = await fetch(`${BASE_URL}/api/v1/payments/confirm`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ session_id: sessionId }),
    signal,
  })
  if (!res.ok) throw new Error(`Confirm failed: ${res.status}`)
  return res.json()
}

export type SubscriptionStatus = {
  active: boolean
  current_period_end: string
  cancel_at_period_end: boolean
  cancelled_at?: string | null
}

export async function getSubscriptionStatus(signal?: AbortSignal): Promise<SubscriptionStatus> {
  const res = await fetch(`${BASE_URL}/api/v1/subscription/status`, {
    method: 'GET',
    headers: authHeaders(),
    signal,
  })
  if (!res.ok) throw new Error(`Subscription status failed: ${res.status}`)
  return res.json()
}

export async function cancelSubscription(signal?: AbortSignal): Promise<{ cancelled: boolean; access_until: string }> {
  const res = await fetch(`${BASE_URL}/api/v1/subscription/cancel`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({}),
    signal,
  })
  if (!res.ok) throw new Error(`Cancel subscription failed: ${res.status}`)
  return res.json()
}


