import { render, screen, fireEvent } from '@testing-library/react'
import ChatInput from './components/ReactChatInput'

it('sends on button click without crashing (test mode skips network)', async () => {
  render(<ChatInput />)
  const textarea = screen.getByPlaceholderText(/message\.{3}/i)
  fireEvent.change(textarea, { target: { value: 'hello' } })
  const btn = screen.getByRole('button', { name: /send/i })
  fireEvent.click(btn)
})
