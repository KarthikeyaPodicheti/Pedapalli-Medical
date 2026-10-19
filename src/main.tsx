import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import LocalPortal from './LocalPortal'
import './styles.css'

const Root=import.meta.env.VITE_LOCAL_API==='true'?LocalPortal:App
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><Root /></React.StrictMode>)
