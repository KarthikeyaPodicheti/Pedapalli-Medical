import { useEffect, useRef } from 'react'

declare global {
  interface Window {
    turnstile?: {
      render:(element:HTMLElement,options:Record<string,unknown>)=>string
      remove:(widgetId:string)=>void
    }
  }
}

let loader:Promise<void>|null=null
function loadTurnstile(){
  if(window.turnstile)return Promise.resolve()
  if(loader)return loader
  loader=new Promise((resolve,reject)=>{
    const existing=document.querySelector<HTMLScriptElement>('script[data-pm-turnstile]')
    if(existing){existing.addEventListener('load',()=>resolve(),{once:true});existing.addEventListener('error',()=>reject(new Error('Turnstile could not load.')),{once:true});return}
    const script=document.createElement('script')
    script.src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
    script.async=true;script.defer=true;script.dataset.pmTurnstile='true'
    script.onload=()=>resolve();script.onerror=()=>reject(new Error('Turnstile could not load.'))
    document.head.appendChild(script)
  })
  return loader
}

export default function Turnstile({siteKey,action,onToken}:{siteKey:string;action:string;onToken:(token:string)=>void}){
  const container=useRef<HTMLDivElement>(null)
  useEffect(()=>{
    let widgetId:string|undefined,cancelled=false
    onToken('')
    void loadTurnstile().then(()=>{
      if(cancelled||!container.current||!window.turnstile)return
      widgetId=window.turnstile.render(container.current,{
        sitekey:siteKey,action,theme:'light',size:'flexible',
        callback:(token:string)=>onToken(token),
        'expired-callback':()=>onToken(''),
        'error-callback':()=>onToken(''),
      })
    }).catch(()=>onToken(''))
    return()=>{cancelled=true;if(widgetId&&window.turnstile)window.turnstile.remove(widgetId)}
  },[siteKey,action,onToken])
  return <div className="turnstile-field" ref={container} aria-label="Security verification"/>
}
