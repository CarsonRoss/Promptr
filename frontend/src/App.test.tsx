import { render, screen } from '@testing-library/react'
import ChatInput from './components/ReactChatInput'

it('renders chat input with placeholder', () => {
  render(<ChatInput />)
  expect(screen.getByPlaceholderText(/message\.{3}/i)).toBeInTheDocument()
})
