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
  }
})

import ChatInput from './ReactChatInput'
import * as api from '../lib/api'

describe('Paywall upgrade flow (unauthenticated -> signup -> checkout)', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.spyOn(window.history, 'replaceState').mockImplementation(() => {})
  })

  it('opens signup modal on Upgrade when unauthenticated, then proceeds to checkout after verification (onClose)', async () => {
    // Cause paywall to appear by making scoring return 402
    ;(api.scorePrompt as any).mockRejectedValueOnce({ status: 402, body: { remaining_uses: 0 } })

    render(<ChatInput />)
    // Type a message to enable send
    const textarea = await screen.findByPlaceholderText(/Type Anything/i)
    fireEvent.change(textarea, { target: { value: 'hello' } })
    const sendBtn = screen.getByRole('button', { name: /send/i })
    fireEvent.click(sendBtn)

    // Paywall upgrade button should appear
    const upgradeBtn = await screen.findByRole('button', { name: /upgrade/i })
    fireEvent.click(upgradeBtn)

    // Signup modal should be visible
    await screen.findByText(/Sign Up/i)

    // Simulate successful verification: when modal closes, session becomes authenticated
    ;(api.getSession as any).mockResolvedValueOnce({ authenticated: true, user: { id: 1, email: 'x@y.com', status: 'paid' } })

    // Click Cancel to trigger onClose() which runs the pendingUpgrade flow
    const cancelBtn = screen.getByRole('button', { name: /cancel/i })
    fireEvent.click(cancelBtn)

    await waitFor(() => {
      expect(api.createCheckout).toHaveBeenCalled()
    })
  })
})


