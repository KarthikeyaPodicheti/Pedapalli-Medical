import { createClient } from 'npm:@supabase/supabase-js@2'

type TurnstileResult={success:boolean;action?:string;hostname?:string;'error-codes'?:string[]}

function allowedOrigins(){return (Deno.env.get('ALLOWED_ORIGINS')||'').split(',').map(value=>value.trim()).filter(Boolean)}
function cors(origin:string){return {'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'}}
function json(status:number,body:unknown,headers:Record<string,string>={}){return new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json','Cache-Control':'no-store'}})}

Deno.serve(async(request:Request)=>{
  const origin=request.headers.get('origin')||''
  const origins=allowedOrigins()
  if(!origin||!origins.includes(origin))return json(403,{error:'Origin is not allowed.'})
  const headers=cors(origin)
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers})
  if(request.method!=='POST')return json(405,{error:'Use POST.'},headers)

  const authorization=request.headers.get('authorization')||''
  const jwt=authorization.replace(/^Bearer\s+/i,'')
  if(!jwt)return json(401,{error:'Sign in before applying.'},headers)
  const secret=Deno.env.get('TURNSTILE_SECRET_KEY')||''
  if(!secret)return json(503,{error:'Security verification is not configured.'},headers)

  let payload:{application?:Record<string,string>;turnstileToken?:string}
  try{payload=await request.json()}catch{return json(400,{error:'Invalid request.'},headers)}
  if(!payload.turnstileToken||!payload.application)return json(400,{error:'Complete the security check.'},headers)

  const verifyBody=new FormData()
  verifyBody.set('secret',secret);verifyBody.set('response',payload.turnstileToken)
  const remoteIp=(request.headers.get('cf-connecting-ip')||request.headers.get('x-forwarded-for')||'').split(',')[0].trim()
  if(remoteIp)verifyBody.set('remoteip',remoteIp)
  let verification:TurnstileResult
  try{
    const response=await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify',{method:'POST',body:verifyBody,signal:AbortSignal.timeout(8000)})
    verification=await response.json() as TurnstileResult
  }catch{return json(503,{error:'Security verification is temporarily unavailable.'},headers)}
  const hostnames=(Deno.env.get('TURNSTILE_ALLOWED_HOSTNAMES')||'').split(',').map(value=>value.trim()).filter(Boolean)
  if(!verification.success||verification.action!=='buyer_application'||(hostnames.length>0&&!hostnames.includes(verification.hostname||''))){
    return json(403,{error:'Security verification failed. Please retry.'},headers)
  }

  const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')!,serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const authClient=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false},global:{headers:{Authorization:authorization}}})
  const {data:{user},error:userError}=await authClient.auth.getUser(jwt)
  if(userError||!user?.email)return json(401,{error:'Your sign-in has expired. Sign in again.'},headers)

  const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}})
  const {data,error}=await admin.rpc('submit_buyer_application_verified',{application:payload.application,target_user:user.id,target_email:user.email})
  if(error)return json(400,{error:error.message||'Application could not be submitted.'},headers)
  return json(200,{id:data},headers)
})
