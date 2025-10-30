import React, { useState, useRef, useEffect } from 'react';
import AuthModal from './AuthModal';
import { scorePrompt, type ScoreResponse, createCheckout, getDeviceStatus, confirmCheckout, getSubscriptionStatus, cancelSubscription, type SubscriptionStatus, getSession, logout } from '../lib/api';

export default function ChatInput() {
  const [message, setMessage] = useState('');
  const [selectedModel, setSelectedModel] = useState('claude-sonnet-4.5');
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [llmScore, setLlmScore] = useState<number | null>(null);
  const [empiricalScore, setEmpiricalScore] = useState<number | null>(null);
  const [averageScore, setAverageScore] = useState<number | null>(null);
  const [isScoring, setIsScoring] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const [llmReasons, setLlmReasons] = useState<string[] | null>(null);
  const [llmRaw, setLlmRaw] = useState<string | null>(null);
  const [empiricalReasons, setEmpiricalReasons] = useState<string[] | null>(null);
  const [suggestedPrompt, setSuggestedPrompt] = useState<string | null>(null);
  const [suggestedText, setSuggestedText] = useState<string>('');
  const [paywallOpen, setPaywallOpen] = useState(false)
  const [remainingUses, setRemainingUses] = useState<number | null>(null)
  const [paid, setPaid] = useState<boolean | null>(null)
  const [subscriptionStatus, setSubscriptionStatus] = useState<SubscriptionStatus | null>(null)
  const [isUpgrading, setIsUpgrading] = useState(false)
  const [authOpen, setAuthOpen] = useState(false)
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [user, setUser] = useState<{ status: string } | null>(null)
  const [pendingUpgrade, setPendingUpgrade] = useState(false)
  

  // Typewriter display states
  const [llmText, setLlmText] = useState<string>('');
  const [empiricalText, setEmpiricalText] = useState<string>('');
  const typeIntervalsRef = useRef<{ llm?: number; empirical?: number; suggested?: number }>({});
  // Track last successfully evaluated prompt to avoid duplicate costly runs
  const lastEvaluatedPromptRef = useRef<string | null>(null);
  // Maintain a single-line baseline height; only grow when wrapping
  const baselineHeightRef = useRef<number>(40); // px; ~2.5rem with 16px root

  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    // Ensure baseline height is measured once
    if (!message.trim()) {
      el.style.height = '2.5rem';
      baselineHeightRef.current = Math.max(
        baselineHeightRef.current,
        Math.round(el.getBoundingClientRect().height)
      );
      return;
    }
    // For non-empty, grow only if needed beyond baseline
    el.style.height = 'auto';
    const target = Math.max(el.scrollHeight, baselineHeightRef.current);
    el.style.height = `${target}px`;
  }, [message]);

  // Load initial device status so the send button can show remaining uses immediately
  useEffect(() => {
    (async () => {
      try {
        const status = await getDeviceStatus()
        setRemainingUses(status.remaining_uses)
        setPaid(status.paid)
        // Also check session auth state
        try {
          const sess = await getSession()
          setIsAuthenticated(!!sess.authenticated)
          setUser(sess.user || null)
        } catch {}
        // If paid, fetch subscription status immediately so banner reflects
        // cancel-at-period-end state without waiting for the periodic refresher.
        if (status.paid) {
          try {
            const sub = await getSubscriptionStatus()
            setSubscriptionStatus(sub)
          } catch {}
        }
      } catch {}
    })()
  }, [])

  // Keep subscription banner stable after cancellation by periodically refreshing status
  useEffect(() => {
    if (paid === true) {
      let tries = 0
      // Fetch immediately once so UI reflects latest state on first render
      ;(async () => {
        try {
          const sub = await getSubscriptionStatus()
          setSubscriptionStatus(sub)
        } catch {}
      })()
      const iv = window.setInterval(async () => {
        tries += 1
        try {
          const sub = await getSubscriptionStatus()
          setSubscriptionStatus(sub)
          if (sub.cancel_at_period_end || tries >= 15) {
            window.clearInterval(iv)
          }
        } catch {
          if (tries >= 15) window.clearInterval(iv)
        }
      }, 3000)
      return () => window.clearInterval(iv)
    }
  }, [paid])

  // After Stripe success redirect, poll device status until paid, then unlock UI
  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    if (params.get('checkout') === 'success') {
      const sessionId = params.get('session_id')
      // Try server-side confirm immediately (works even if webhook is delayed)
      // Always try confirm; backend will fall back to last session via device cache
      confirmCheckout(sessionId || '').catch(() => {})
      let tries = 0
      const iv = window.setInterval(async () => {
        tries += 1
        try {
          const status = await getDeviceStatus()
          setRemainingUses(status.remaining_uses)
          if (status.paid) {
            window.clearInterval(iv)
            params.delete('checkout')
            const qs = params.toString()
            const newUrl = window.location.pathname + (qs ? `?${qs}` : '')
            window.history.replaceState({}, '', newUrl)
            showFlash('Purchase successful')
            setPaid(true)
          
            // Refresh session so user.status reflects 'paid' for UI driven by user
            try {
              const sess = await getSession()
              setIsAuthenticated(!!sess.authenticated)
              setUser(sess.user || null)
            } catch {}
          
            return
          }
        } catch {
          // ignore transient errors
        }
        if (tries >= 60) {
          window.clearInterval(iv)
          // If still not paid after ~60s, show paywall again so user can retry
          setPaywallOpen(true)
        }
      }, 1000)
      return () => window.clearInterval(iv)
    }
  }, [])

  // Reset scores if text is cleared
  useEffect(() => {
    if (!message.trim()) {
      if (abortRef.current) {
        abortRef.current.abort();
        abortRef.current = null;
      }
      setLlmScore(null);
      setEmpiricalScore(null);
      setAverageScore(null);
      setLlmReasons(null);
      setLlmRaw(null);
      setEmpiricalReasons(null);
      setSuggestedPrompt(null);
      setLlmText('');
      setEmpiricalText('');
      // Clear any typewriter timers
      if (typeIntervalsRef.current.llm) window.clearInterval(typeIntervalsRef.current.llm);
      if (typeIntervalsRef.current.empirical) window.clearInterval(typeIntervalsRef.current.empirical);
      if (typeIntervalsRef.current.suggested) window.clearInterval(typeIntervalsRef.current.suggested);
      typeIntervalsRef.current = {};
      setSuggestedText('');
    }
  }, [message]);

  async function handleSend(inputMessage?: string) {
    const promptToUse = (inputMessage ?? message).trim();
    if (!promptToUse || isScoring) return;
  
    if (lastEvaluatedPromptRef.current === promptToUse) return;
    if (import.meta.env.MODE === 'test') return;
  
    if (abortRef.current) abortRef.current.abort();
    const ac = new AbortController();
    abortRef.current = ac;
  
    try {
      if (typeIntervalsRef.current.llm) window.clearInterval(typeIntervalsRef.current.llm);
      if (typeIntervalsRef.current.empirical) window.clearInterval(typeIntervalsRef.current.empirical);
      if (typeIntervalsRef.current.suggested) window.clearInterval(typeIntervalsRef.current.suggested);
      typeIntervalsRef.current = {};

      setLlmText('');
      setEmpiricalText('');
      setLlmReasons(null);
      setEmpiricalReasons(null);
      setSuggestedPrompt(null);
      setSuggestedText('');
  
      setIsScoring(true);
  
      let res: ScoreResponse;
      try {
        res = await scorePrompt(promptToUse, ac.signal);
      } catch (err: any) {
        if (err && err.status === 402) {
          setIsScoring(false);
          setPaywallOpen(true);
          setPaid(false);
          setRemainingUses(err.body?.remaining_uses ?? 0);
          return;
        }
        throw err;
      }
  
      const l = res.llm?.score ?? null;
      const e = res.empirical?.score ?? null;

      setLlmScore(l);
      setEmpiricalScore(e);

      setLlmReasons(res.llm?.reasons ?? null);
      setLlmRaw(res.llm?.raw ?? null);
      setEmpiricalReasons(res.empirical?.reasons ?? null);
      setSuggestedPrompt(res.suggested_prompt ?? null);
  
      const nums = [l, e].filter((v): v is number => typeof v === 'number');
      setAverageScore(nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : null);
  
      try {
        const status = await getDeviceStatus();
        setRemainingUses(status.remaining_uses);
        setPaid(status.paid);

        // Fetch subscription status if user is paid
        if (status.paid) {
          try {
            const subStatus = await getSubscriptionStatus();
            setSubscriptionStatus(subStatus);
          } catch (error) {
            console.error('Failed to fetch subscription status:', error);
          }
        }
      } catch {}
  
      setIsScoring(false);
  
      const llmR = joinReasons(res.llm?.reasons);
      const empR = joinReasons(res.empirical?.reasons);

      await typeText(llmR, setLlmText, 'llm');
      await typeText(empR, setEmpiricalText, 'empirical');
      await typeText(res.suggested_prompt ?? '', setSuggestedText, 'suggested');
  
      lastEvaluatedPromptRef.current = promptToUse;
    } catch (_e) {
      // ignore for now
    } finally {
      setIsScoring(false);
    }
  }

  function showFlash(text: string) {
    const root = document.getElementById('flash-root')
    if (!root) return
    const el = document.createElement('div')
    el.className = 'flash-success'
    el.textContent = text
    root.appendChild(el)
    setTimeout(() => {
      el.classList.add('flash-success--hide')
      setTimeout(() => el.remove(), 300)
    }, 2000)
  }

  async function sendSuggestedPrompt() {
    if (!suggestedPrompt) return;
    try {
      await navigator.clipboard.writeText(suggestedPrompt);
    } catch {}
  
    // Update the text input to show the suggested prompt
    setMessage(suggestedPrompt);
  
    lastEvaluatedPromptRef.current = null;
  
    // Pass suggestedPrompt to handleSend
    await handleSend(suggestedPrompt);
  }

  function sendToChatGPT() {
    const promptToSend = suggestedPrompt || message
    if (!promptToSend) return
    try { navigator.clipboard.writeText(promptToSend) } catch {}
    const url = `https://chat.openai.com/?q=${encodeURIComponent(promptToSend)}`
    window.open(url, '_blank', 'noopener')
  }

  async function handleCancelSubscription() {
    if (!confirm('Are you sure you want to cancel your subscription? You will retain access until the end of your current billing period.')) {
      return
    }

    try {
      const result = await cancelSubscription()
      // Immediately update local UI to reflect cancellation
      setSubscriptionStatus({
        active: true, // still active until period end
        current_period_end: result.access_until,
        cancel_at_period_end: true,
        cancelled_at: new Date().toISOString()
      })
      // Re-fetch from server to avoid UI reverting on next render cycle
      try {
        const refreshed = await getSubscriptionStatus()
        setSubscriptionStatus(refreshed)
      } catch (e) {
        // Non-blocking; UI already updated locally
      }
      // Do not set paid=false here; user keeps access until period end
      showFlash('Subscription cancelled. Access continues until ' + new Date(result.access_until).toLocaleDateString())
    } catch (error) {
      showFlash('Failed to cancel subscription. Please try again.')
      console.error('Cancel subscription error:', error)
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      void handleSend();
    }
  }

  function joinReasons(reasons?: string[] | null) {
    if (!reasons || reasons.length === 0) return '';
    return reasons.join(' ');
  }

  async function typeText(
    text: string,
    setter: (v: string) => void,
    key: 'llm' | 'empirical' | 'suggested'
  ): Promise<void> {
    // Clear only this section's previous interval
    const prev = typeIntervalsRef.current[key];
    if (prev) window.clearInterval(prev);
    setter('');
    if (!text) {
      typeIntervalsRef.current[key] = undefined;
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => {
      let i = 0;
      const id = window.setInterval(() => {
        i += 1;
        setter(text.slice(0, i));
        if (i >= text.length) {
          window.clearInterval(id);
          resolve();
        }
      }, 8);
      typeIntervalsRef.current[key] = id;
    });
  }

  return (
    <div className="min-h-screen w-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-start justify-center p-6">
      <div className="w-full max-w-5xl relative flex gap-8 pt-16">
        {/* Flash area */}
        <div id="flash-root" className="absolute -top-8 left-1/2 -translate-x-1/2"></div>

        {/* Subscription Banner */}
        <div className="subscription-banner absolute top-0 left-0 right-0 z-40 bg-white border-b border-slate-200 shadow-sm">
          <div className="max-w-5xl mx-auto px-6 py-3 flex items-center justify-between">
            {/* Left: Subscription Status */}
            <div className="flex items-center gap-3">
              {paid === true ? (
                <div className="flex items-center gap-2 text-green-700">
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span className="text-sm font-medium">Active Subscription</span>
                </div>
              ) : (
                <div className="flex items-center gap-2 text-slate-600">
                  <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                  </svg>
                  <span className="text-sm">Free Trial</span>
                  {remainingUses != null && remainingUses <= 5 && (
                    <span className="text-xs text-slate-500">({remainingUses} uses left)</span>
                  )}
                </div>
              )}
            </div>

            {/* Right: Action Buttons */}
            <div className="flex items-center gap-3">
              {paid === true ? (
                subscriptionStatus?.cancel_at_period_end ? (
                  <span className="text-sm text-slate-600">
                    Cancelled — access until {subscriptionStatus.current_period_end ? new Date(subscriptionStatus.current_period_end).toLocaleDateString() : ''}
                  </span>
                ) : (
                  <button
                    className="px-3 py-1.5 text-sm border border-red-200 bg-white text-red-600 hover:bg-red-50 rounded-md transition-colors"
                    onClick={handleCancelSubscription}
                  >
                    Cancel Subscription
                  </button>
                )
              ) : (
                <div className="flex items-center gap-3">
                  {(!isAuthenticated || (user && user.status !== 'paid')) && (
                    <button
                      className="upgrade-now"
                      disabled={isUpgrading}
                      onClick={async () => {
                        if (isUpgrading) return
                        
                        // If not authenticated, show auth modal first
                        if (!isAuthenticated) {
                          setPendingUpgrade(true)
                          setAuthOpen(true)
                          return
                        }
                        
                        // Proceed with checkout for authenticated users
                        setIsUpgrading(true)
                        try {
                          const { url } = await createCheckout()
                          if (!url) throw new Error('Missing checkout URL')
                          window.location.href = url
                        } catch (e) {
                          showFlash('Upgrade failed. Please try again.')
                          console.error('Upgrade error:', e)
                        } finally {
                          setIsUpgrading(false)
                        }
                      }}
                    >
                      {isUpgrading ? 'Redirecting…' : 'Upgrade Now'}
                    </button>
                  )}
                  {!isAuthenticated ? (
                    <button
                      className="text-sm font-semibold"
                      style={{ color: '#2563eb' }}
                      onClick={() => setAuthOpen(true)}
                    >
                      Sign Up
                    </button>
                  ) : (
                    <button
                      className="text-sm text-slate-600 hover:underline"
                      onClick={async () => {
                        try { 
                          await logout() 
                        } catch {}
                        setIsAuthenticated(false)
                        setUser(null)
                        showFlash('Signed out')
                      }}
                    >
                      Sign out
                    </button>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
        {/* Left scoring panel (modal) */}
        <aside className="w-56 bg-white rounded-2xl shadow-lg border border-slate-200 p-6 flex flex-col items-center gap-6">
          <div className="flex flex-col items-center">
            <ScoreRing label="" value={averageScore} loading={isScoring} size={96} help={"Weighted average of LLM (60%) and Empirical (40%) scores. Indicates overall prompt quality based on AI evaluation and real-world testing."} />
            <div className="mt-2 text-[10px] uppercase tracking-wide text-slate-500">Overall Score</div>
          </div>
          <div className="flex flex-col items-center">
            <ScoreRing label="" value={llmScore} loading={isScoring} size={64} help={"Uses GPT-4o-mini to evaluate prompt quality based on clarity, specificity, feasibility, and completeness criteria."} />
            <div className="mt-2 text-[10px] uppercase tracking-wide text-slate-500">LLM</div>
          </div>
          <div className="flex flex-col items-center">
            <ScoreRing label="" value={empiricalScore} loading={isScoring} size={64} help={"Runs your prompt through GPT-4o-mini twice, then evaluates output consistency, quality, and structure. High scores indicate reliable, well-formatted results."} />
            <div className="mt-2 text-[10px] uppercase tracking-wide text-slate-500">Empirical</div>
          </div>
        </aside>

        {/* Main content (no modal/card wrapper) */}
        <div className="flex-1">

          {/* Input with inline send */}
          <div className="p-4 flex items-start gap-6">
            <div className="flex-1 relative">
              <textarea
                ref={textareaRef}
                value={message}
                onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setMessage(e.target.value)}
                onKeyDown={onKeyDown}
                placeholder="Type Anything..."
                rows={1}
                className="w-full resize-none overflow-hidden rounded-xl bg-slate-100/60 border border-slate-200 focus:outline-none text-slate-900 placeholder-slate-400 text-base leading-relaxed pr-12 pl-4 pt-2 pb-6"
                style={{ minHeight: '36px' }}
              />
              <button
                aria-label="Send"
                onClick={() => void handleSend()}
                disabled={!message.trim() || isScoring}
                className={`send-btn`}
              >
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className="h-4 w-4">
                  <path d="M12 19V5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  <path d="M7 10l5-5 5 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>

          {/* Loader directly under input, left-aligned */}
          {isScoring && (
            <div className="px-4 pt-0">
              <ThreeDotLoader />
            </div>
          )}

          {/* Paywall modal */}
          {paywallOpen && (
            <div className="px-4 pb-4">
              <div className="rounded-xl border border-amber-300 bg-amber-50 p-4">
                <div className="text-sm text-slate-800 mb-2">You are out of requests for the free trial. Upgrade for unlimited.</div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={async () => {
                      try {
                        const { url } = await createCheckout()
                        window.location.href = url
                      } catch {}
                    }}
                    className="upgrade-btn"
                  >
                    Upgrade
                  </button>
                  <button onClick={() => setPaywallOpen(false)} className="text-xs text-slate-600 hover:underline">Not now</button>
                </div>
              </div>
            </div>
          )}

          {/* LLM Insights (typewriter) - simplified, no modal/card */}
          {llmText && (
            <div className="px-4 pb-4">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-2">LLM Insights</div>
              <div className="text-slate-700 text-sm whitespace-pre-wrap">{llmText}</div>
            </div>
          )}

          {/* Empirical Insights (typewriter) - simplified */}
          {empiricalText && (
            <div className="px-4 pb-4">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-2">Empirical Insights</div>
              <div className="text-slate-700 text-sm whitespace-pre-wrap">{empiricalText}</div>
            </div>
          )}

          {/* Suggested Prompt with Copy (animates after empirical) - simplified */}
          {suggestedText && (
            <div className="px-4 pb-4">
              <div className="text-xs uppercase tracking-wide text-slate-500 mb-2">Suggested Prompt</div>
              {averageScore !== null && averageScore > 80 && (
                <div className="mb-3 p-2 bg-green-50 border border-green-200 rounded-md">
                  <div className="text-green-800 text-sm font-medium flex items-center gap-2">
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    Your prompt is sufficient
                  </div>
                </div>
              )}
              <div className="whitespace-pre-wrap break-words text-slate-700 text-sm">{suggestedText}</div>
              <div className="flex items-center gap-2 mt-3">
                <CopyButton text={suggestedPrompt ?? ''} />
                {suggestedPrompt && (
                  <button className="send-suggested-btn" onClick={sendSuggestedPrompt}>
                    Grade this prompt
                  </button>
                )}
                {paid === true && (
                  <button className="send-chatgpt-btn" onClick={sendToChatGPT}>
                    Send to ChatGPT
                  </button>
                )}
              </div>
            </div>
          )}

          {/* Footer hint */}
        </div>
      </div>
      <AuthModal open={authOpen} onClose={async () => {
        setAuthOpen(false)
        try {
          const s = await getSession()
          setIsAuthenticated(!!s.authenticated)
          setUser(s.user || null)
          // If user came from upgrade flow and is now authenticated, proceed to checkout
          if (pendingUpgrade && s.authenticated) {
            setPendingUpgrade(false)
            setIsUpgrading(true)
            try {
              const { url } = await createCheckout()
              if (!url) throw new Error('Missing checkout URL')
              window.location.href = url
            } catch (e) {
              showFlash('Upgrade failed. Please try again.')
              console.error('Upgrade error:', e)
            } finally {
              setIsUpgrading(false)
            }
          }
        } catch {}
      }} />
    </div>
  );
}

function ScoreRing({ label, value, loading, size = 56, color, help }: { 
  label: string; 
  value: number | null; 
  loading: boolean; 
  size?: number;
  color?: 'red' | 'yellow' | 'green';
  help?: string;
}) {
  const stroke = Math.round(size * 0.107);
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const pct = value == null ? 0 : Math.max(0, Math.min(100, value));
  const dash = circumference * (pct / 100);
  
  const getColor = () => {
    if (value == null) return '#94a3b8';
    const v = Math.max(0, Math.min(100, value));
    // Map 0->red (#ef4444), 50->yellow (#eab308), 100->green (#22c55e)
    // Interpolate in two segments: 0-50 (red->yellow), 50-100 (yellow->green)
    const lerp = (a: number, b: number, t: number) => Math.round(a + (b - a) * t);
    const hex = (r: number, g: number, b: number) => `#${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}`;
    const red = { r: 239, g: 68, b: 68 };    // #ef4444
    const yellow = { r: 234, g: 179, b: 8 };  // #eab308
    const green = { r: 34, g: 197, b: 94 };   // #22c55e
    if (v <= 50) {
      const t = v / 50;
      return hex(lerp(red.r, yellow.r, t), lerp(red.g, yellow.g, t), lerp(red.b, yellow.b, t));
    } else {
      const t = (v - 50) / 50;
      return hex(lerp(yellow.r, green.r, t), lerp(yellow.g, green.g, t), lerp(yellow.b, green.b, t));
    }
  };

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="rotate-[-90deg]">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke="#e2e8f0"
          strokeWidth={stroke}
          fill="none"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={getColor()}
          strokeWidth={stroke}
          fill="none"
          strokeDasharray={`${dash} ${circumference - dash}`}
          strokeLinecap="round"
          className="transition-[stroke-dasharray] duration-500 ease-out"
        />
      </svg>
      <div className={`absolute inset-0 grid place-items-center font-bold text-slate-700 ${size > 60 ? 'text-lg' : 'text-sm'}`}>
        {value == null ? (loading ? '…' : '—') : Math.round(value)}
      </div>
      <div className={`absolute -top-2 -right-2 rounded-full bg-white border border-slate-200 grid place-items-center text-slate-600 font-medium ${size > 60 ? 'h-6 w-6 text-xs' : 'h-5 w-5 text-[10px]'}`}>
        {label}
      </div>
      {help && (
        <div className="ring-help" aria-label="Help">
          <div className="ring-help__icon">?</div>
          <div className="ring-help__tooltip">{help}</div>
        </div>
      )}
    </div>
  );
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = React.useState(false)
  async function copy() {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
    } catch {}
  }
  return (
    <button
      aria-label={copied ? 'Copied' : 'Copy suggested prompt'}
      onClick={copy}
      className={`self-start inline-flex items-center h-8 px-3 rounded-md border text-xs transition-colors ${
        copied ? 'bg-green-100 text-green-700 border-green-200' : 'bg-slate-100 text-slate-700 border-slate-300 hover:bg-slate-200'
      }`}
    >
      <span>Copy</span>
      {copied && <span className="ml-1">✓</span>}
    </button>
  )
}

function ThreeDotLoader() {
  const size = 4;
  return (
    <div className="flex items-center justify-start gap-1.5 py-2 ml-4">
      <div className="bg-gray-400 rounded-full animate-bounce" style={{ width: size, height: size, animationDelay: '0ms', animationDuration: '600ms' }}></div>
      <div className="bg-gray-400 rounded-full animate-bounce" style={{ width: size, height: size, animationDelay: '150ms', animationDuration: '600ms' }}></div>
      <div className="bg-gray-400 rounded-full animate-bounce" style={{ width: size, height: size, animationDelay: '300ms', animationDuration: '600ms' }}></div>
    </div>
  );
}