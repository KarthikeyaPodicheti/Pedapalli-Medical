import { createClient } from 'npm:@supabase/supabase-js@2'

// Deploy with --no-verify-jwt: this is guest checkout. Abuse protection is
// mandatory; the service key is available only inside this server function.
Deno.serve(async (request: Request) => {
  const allowedOrigin = Deno.env.get('STOREFRONT_ORIGIN') || ''
  const origin = request.headers.get('origin') || ''
  const headers = { 'Content-Type':'application/json', 'Vary':'Origin', 'Cache-Control':'no-store', ...(origin === allowedOrigin && allowedOrigin ? {'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'} : {}) }
  const respond = (status:number,body:unknown) => new Response(JSON.stringify(body),{status,headers})
  if(!allowedOrigin || origin !== allowedOrigin) return respond(403,{error:'Storefront origin is not allowed.'})
  if(request.method === 'OPTIONS') return new Response(null,{status:204,headers})
  if(request.method !== 'POST') return respond(405,{error:'Use POST.'})
  if(!request.headers.get('content-type')?.startsWith('application/json')) return respond(415,{error:'Expected JSON.'})
  const secret=Deno.env.get('TURNSTILE_SECRET_KEY')
  if(!secret) return respond(503,{error:'Online ordering is not configured.'})
  try {
    // Enforce the limit while streaming; do not trust Content-Length.
    const reader=request.body?.getReader();if(!reader)return respond(400,{error:'Request body is missing.'})
    const chunks:Uint8Array[]=[];let size=0
    while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>16384){await reader.cancel();return respond(413,{error:'Order request is too large.'})}chunks.push(value)}
    const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length}
    const body=JSON.parse(new TextDecoder().decode(bytes))
    if(typeof body.challenge !== 'string' || !body.challenge || body.challenge.length>2048) return respond(400,{error:'Complete the verification before placing an order.'})
    if(typeof body.idempotency_key !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.idempotency_key)) return respond(400,{error:'Invalid request ID.'})
    if(!body.customer || !Array.isArray(body.items) || body.items.length<1 || body.items.length>50) return respond(400,{error:'Invalid order request.'})
    const challengeResponse=await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({secret,response:body.challenge}),signal:AbortSignal.timeout(10000)})
    if(!challengeResponse.ok)return respond(503,{error:'Verification is temporarily unavailable.'})
    const challenge=await challengeResponse.json()
    if(!challenge.success || challenge.hostname !== new URL(allowedOrigin).hostname) return respond(400,{error:'Verification expired or failed. Please try again.'})
    const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}})
    // Only pass customer fields used by the order function. Extra request fields,
    // including prices, discounts and status, are never trusted.
    const customer=Object.fromEntries(['name','phone','address','locality','pincode'].map(k=>[k,body.customer[k]]))
    if(Object.values(customer).some(v=>typeof v!=='string'))return respond(400,{error:'Invalid customer details.'})
    const items=body.items.map((item:Record<string,unknown>)=>({product_id:item.product_id,quantity:item.quantity}))
    const {data,error}=await db.rpc('create_cod_order',{customer,items,idempotency_key:body.idempotency_key})
    if(error) return respond(400,{error:error.code==='P0001'?error.message:'The order could not be saved. Check your cart and retry.'})
    return respond(200,data)
  } catch(error) {
    return respond(error instanceof SyntaxError?400:503,{error:error instanceof SyntaxError?'Invalid JSON.':'The store is temporarily unavailable. Please retry.'})
  }
})
