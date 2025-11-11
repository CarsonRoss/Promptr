import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import React from 'react'

vi.mock('../lib/api', async () => {
  return {
    scorePrompt: vi.fn(),
    getDeviceStatus: vi.fn().mockResolvedValue({ paid: false, remaining_uses: 10 }),
    getSession: vi.fn().mockResolvedValue({ authenticated: false }),
    getSubscriptionStatus: vi.fn().mockResolvedValue({ active: false, current_period_end: '', cancel_at_period_end: false }),
    createCheckout: vi.fn().mockResolvedValue({ url: 'https://checkout.stripe.com/test' }),
    cancelSubscription: vi.fn(),
    signup: vi.fn().mockResolvedValue({}),
    login: vi.fn().mockResolvedValue({}),
    verifyEmailWithCode: vi.fn().mockResolvedValue({}),
    resendVerification: vi.fn().mockResolvedValue({}),
  }
})

import ChatInput from './ReactChatInput'
import * as api from '../lib/api'

describe('Paywall upgrade flow (unauthenticated -> signup -> checkout)', () => {
  beforeEach(() => {
    vi.useRealTimers()
    vi.spyOn(window.history, 'replaceState').mockImplementation(() => {})
  })

  it('opens signup modal on Upgrade, completes signup flow, then proceeds to checkout', async () => {
    render(<ChatInput />)
    // Click the global Upgrade Now button (top-center)
    const upgradeBtn = await screen.findByRole('button', { name: /upgrade now/i })
    fireEvent.click(upgradeBtn)

    // Step 1: Email (modal heading)
    await screen.findByRole('heading', { name: /sign up/i })
    const emailInput = screen.getByPlaceholderText(/email address/i)
    fireEvent.change(emailInput, { target: { value: 'x@y.com' } })
    const nextBtn1 = screen.getByRole('button', { name: /next/i })
    fireEvent.click(nextBtn1)

    // Step 2: Password
    const pwdInput = await screen.findByPlaceholderText(/^password$/i)
    const confirmInput = screen.getByPlaceholderText(/confirm password/i)
    fireEvent.change(pwdInput, { target: { value: 'password123' } })
    fireEvent.change(confirmInput, { target: { value: 'password123' } })
    const nextBtn2 = screen.getByRole('button', { name: /next/i })
    fireEvent.click(nextBtn2)

    // Step 3: Code
    const codeInput = await screen.findByPlaceholderText(/______/)
    fireEvent.change(codeInput, { target: { value: '123456' } })
    ;(api.getSession as any).mockResolvedValue({ authenticated: true, user: { id: 1, email: 'x@y.com', status: 'trial' } })
    const verifyBtn = screen.getByRole('button', { name: /verify/i })
    fireEvent.click(verifyBtn)

    await waitFor(() => {
      expect(api.createCheckout).toHaveBeenCalled()
    })
  })
})


