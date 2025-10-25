import React from 'react'
import { signup, login, verifyEmailWithCode, resendVerification } from '../lib/api'

type Step = 'email' | 'password' | 'code' | 'done'

export default function AuthModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [step, setStep] = React.useState<Step>('email')
  const [email, setEmail] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [confirm, setConfirm] = React.useState('')
  const [code, setCode] = React.useState('')
  const [error, setError] = React.useState<string | null>(null)
  const [loading, setLoading] = React.useState(false)

  React.useEffect(() => {
    if (!open) {
      setStep('email'); setEmail(''); setPassword(''); setConfirm(''); setCode(''); setError(null); setLoading(false)
    }
  }, [open])

  async function handleEmailNext() {
    if (!email.trim()) { setError('Email is required'); return }
    setError(null); setStep('password')
  }

  async function handlePasswordNext() {
    if (password.length < 8) { setError('Password must be at least 8 characters'); return }
    if (confirm && confirm !== password) { setError('Passwords do not match'); return }
    setError(null); setLoading(true)
    try {
      // Try signup first; if user exists, fall back to login
      try {
        await signup(email.trim().toLowerCase(), password, confirm || password)
      } catch {
        await login(email.trim().toLowerCase(), password)
      }
      // Move to verification code entry; backend sends email with code
      setStep('code')
    } catch (e) {
      setError('Sign in failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  async function handleVerify() {
    if (!/^[0-9]{6}$/.test(code)) { setError('Enter the 6-digit code'); return }
    setError(null); setLoading(true)
    try {
      await verifyEmailWithCode(email.trim().toLowerCase(), code, password, confirm || password)
      setStep('done')
      onClose()
    } catch {
      setError('Invalid or expired code. You can resend a new code.')
    } finally {
      setLoading(false)
    }
  }

  async function handleResend() {
    setError(null); setLoading(true)
    try {
      await resendVerification(email.trim().toLowerCase())
    } catch {
      setError('Failed to resend. Try again shortly.')
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
      <div className="w-full max-w-sm rounded-2xl bg-white shadow-xl border border-slate-200 p-5">
        {step === 'email' && (
          <div>
            <h3 className="text-slate-900 text-lg font-semibold mb-2">Sign in</h3>
            <label className="block text-sm text-slate-600 mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="you@example.com"
            />
            {error && <div className="text-red-600 text-sm mt-2">{error}</div>}
            <button
              onClick={handleEmailNext}
              className="w-full mt-4 h-10 rounded-full btn-primary disabled:opacity-60"
              disabled={loading}
            >Next</button>
            <button onClick={onClose} className="mt-2 w-full text-sm text-slate-600 hover:underline">Cancel</button>
          </div>
        )}

        {step === 'password' && (
          <div>
            <h3 className="text-slate-900 text-lg font-semibold mb-2">Welcome</h3>
            <div className="text-xs text-slate-500 mb-3">{email}</div>
            <label className="block text-sm text-slate-600 mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500 mb-3"
              placeholder="Enter password"
            />
            <label className="block text-sm text-slate-600 mb-1">Confirm password</label>
            <input
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              className="w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Confirm password"
            />
            {error && <div className="text-red-600 text-sm mt-2">{error}</div>}
            <button
              onClick={handlePasswordNext}
              className="w-full mt-4 h-10 rounded-full btn-primary disabled:opacity-60"
              disabled={loading}
            >Next</button>
            <button onClick={() => setStep('email')} className="mt-2 w-full text-sm text-slate-600 hover:underline">Back</button>
          </div>
        )}

        {step === 'code' && (
          <div>
            <h3 className="text-slate-900 text-lg font-semibold mb-2">Enter verification code</h3>
            <div className="text-xs text-slate-500 mb-3">We sent a 6‑digit code to {email}</div>
            <label className="block text-sm text-slate-600 mb-1">6‑digit code</label>
            <input
              inputMode="numeric"
              pattern="[0-9]*"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0,6))}
              className="tracking-widest text-center w-full border border-slate-300 rounded-xl px-3 py-2 text-slate-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="______"
            />
            {error && <div className="text-red-600 text-sm mt-2">{error}</div>}
            <button
              onClick={handleVerify}
              className="w-full mt-4 h-10 rounded-full btn-primary disabled:opacity-60"
              disabled={loading}
            >Verify</button>
            <button onClick={handleResend} className="mt-2 w-full text-sm text-blue-600 hover:underline disabled:opacity-60" disabled={loading}>Resend code</button>
            <button onClick={() => setStep('password')} className="mt-1 w-full text-sm text-slate-600 hover:underline">Back</button>
          </div>
        )}
      </div>
    </div>
  )
}


