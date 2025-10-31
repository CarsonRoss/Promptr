import React from 'react'
import { login } from '../lib/api'

export default function LoginModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [email, setEmail] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [error, setError] = React.useState<string | null>(null)
  const [loading, setLoading] = React.useState(false)

  React.useEffect(() => {
    if (!open) {
      setEmail(''); setPassword(''); setError(null); setLoading(false)
    }
  }, [open])

  if (!open) return null

  async function handleLogin() {
    if (!email.trim()) { setError('Email is required'); return }
    if (password.length < 8) { setError('Password must be at least 8 characters'); return }
    setError(null); setLoading(true)
    try {
      await login(email.trim().toLowerCase(), password)
      onClose()
    } catch (e) {
      setError('Invalid email or password')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
      <div className="w-full max-w-sm rounded-2xl bg-white shadow-xl border border-slate-200 p-5">
        <h3 className="text-slate-900 text-lg font-semibold mb-2">Sign in</h3>
        <label className="block text-sm text-slate-600 mb-1">Email</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="you@example.com"
        />
        <label className="block text-sm text-slate-600 mb-1 mt-3">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Enter password"
        />
        {error && <div className="text-red-600 text-sm mt-2">{error}</div>}
        <button
          onClick={handleLogin}
          className="w-full mt-4 h-10 rounded-full btn-primary disabled:opacity-60"
          disabled={loading}
        >Sign in</button>
        <button onClick={onClose} className="mt-2 w-full text-sm text-slate-600 hover:underline">Cancel</button>
      </div>
    </div>
  )
}


