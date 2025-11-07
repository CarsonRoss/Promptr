import React, { useEffect, useState } from 'react'
import ReactDOM from 'react-dom/client'
import ChatInput from './components/ReactChatInput.tsx'
import ManageSubscription from './components/ManageSubscription.tsx'
import './style.css'

function AppRouter() {
  const [route, setRoute] = useState<string>(() => window.location.hash || '#/')

  useEffect(() => {
    const handler = () => setRoute(window.location.hash || '#/')
    window.addEventListener('hashchange', handler)
    return () => window.removeEventListener('hashchange', handler)
  }, [])

  if (route.startsWith('#/manage-subscription')) {
    return <ManageSubscription />
  }
  return <ChatInput />
}

const rootEl = document.getElementById('root')!
ReactDOM.createRoot(rootEl).render(
  <React.StrictMode>
    <AppRouter />
  </React.StrictMode>
)


