import { describe, it, expect, vi, beforeEach } from 'vitest'

// Use dynamic import so our mocked fetch is picked up
const importApi = async () => await import('./api')

describe('api.ts', () => {
  beforeEach(() => {
    // @ts-ignore
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({}),
      status: 200,
    })
    // Ensure BASE_URL default path is used
    // @ts-ignore
    global.importMeta = { env: { VITE_API_BASE_URL: '' } }
  })

  it('getSubscriptionStatus includes credentials: include', async () => {
    const { getSubscriptionStatus } = await importApi()
    await getSubscriptionStatus()
    expect(global.fetch).toHaveBeenCalledTimes(1)
    const [, opts] = (global.fetch as any).mock.calls[0]
    expect(opts.credentials).toBe('include')
    expect(opts.method).toBe('GET')
  })
})


