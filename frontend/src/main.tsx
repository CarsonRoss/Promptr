import React from 'react'
import ReactDOM from 'react-dom/client'
import ChatInput from './components/ReactChatInput.tsx'
import './style.css'

const rootEl = document.getElementById('root')!
ReactDOM.createRoot(rootEl).render(
  <React.StrictMode>
    <ChatInput />
  </React.StrictMode>
)


