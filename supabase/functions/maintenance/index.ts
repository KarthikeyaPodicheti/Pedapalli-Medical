import { createClient } from 'npm:@supabase/supabase-js@2'

type Delivery = {
  id:number; channel:'email'|'whatsapp'; event_name:string; email:string; phone:string;
  legal_name:string; order_reference:string|null; order_status:string|null;
}

const encoder = new TextEncoder()
async function secureEqual(left:string,right:string) {
  const [a,b]=await Promise.all([crypto.subtle.digest('SHA-256',encoder.encode(left)),crypto.subtle.digest('SHA-256',encoder.encode(right))])
  const first=new Uint8Array(a),second=new Uint8Array(b);let difference=0
  for(let index=0;index<first.length;index++)difference|=first[index]^second[index]
  return difference===0
}
function escapeHtml(value:string){return value.replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]!))}
function message(delivery:Delivery){
  const order=delivery.order_reference?` Order ${delivery.order_reference}`:''
  const labels:Record<string,string>={
    buyer_application_submitted:'Your buyer application was received and is awaiting verification.',
    buyer_approved:'Your buyer account has been approved. Wholesale pricing and ordering are now available.',
    buyer_rejected:'Your buyer application could not be approved. Please contact the wholesaler.',
    buyer_suspended:'Your buyer access has been suspended. Please contact the wholesaler.',
    order_submitted:`${order.trim()} was received and is awaiting wholesaler confirmation.`,
    order_accepted:`${order.trim()} was accepted by the wholesaler.`,
    order_out_for_delivery:`${order.trim()} has been dispatched.`,
    order_completed:`${order.trim()} was completed.`,
    order_cancelled:`${order.trim()} was cancelled.`,
  }
  return labels[delivery.event_name]||`There is an update to your Pedapalli Medical buyer account.${order}`
}
async function sendEmail(delivery:Delivery){
  const key=Deno.env.get('RESEND_API_KEY'),from=Deno.env.get('EMAIL_FROM')
  if(!key||!from)throw new Error('Email provider is not configured')
  const content=message(delivery)
  const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({from,to:[delivery.email],subject:`Pedapalli Medical: ${delivery.event_name.replaceAll('_',' ')}`,html:`<p>Hello ${escapeHtml(delivery.legal_name)},</p><p>${escapeHtml(content)}</p><p>Sign in to the buyer portal for the current status.</p>`}),signal:AbortSignal.timeout(10000)})
  const result=await response.json().catch(()=>({})) as {id?:string}
  if(!response.ok)throw new Error(`Email provider returned ${response.status}`)
  return result.id||'accepted'
}
async function sendWhatsApp(delivery:Delivery){
  const token=Deno.env.get('WHATSAPP_ACCESS_TOKEN'),phoneId=Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')
  const template=Deno.env.get(`WHATSAPP_TEMPLATE_${delivery.event_name.toUpperCase()}`)
  if(!token||!phoneId||!template)throw new Error('WhatsApp provider or approved template is not configured')
  const response=await fetch(`https://graph.facebook.com/v21.0/${phoneId}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',to:`91${delivery.phone}`,type:'template',template:{name:template,language:{code:'en'}}}),signal:AbortSignal.timeout(10000)})
  const result=await response.json().catch(()=>({})) as {messages?:{id:string}[]}
  if(!response.ok)throw new Error(`WhatsApp provider returned ${response.status}`)
  return result.messages?.[0]?.id||'accepted'
}

Deno.serve(async(request:Request)=>{
  const headers={'Content-Type':'application/json','Cache-Control':'no-store'}
  if(request.method!=='POST')return new Response(JSON.stringify({error:'Use POST.'}),{status:405,headers})
  const secret=Deno.env.get('MAINTENANCE_SECRET')||'',provided=(request.headers.get('authorization')||'').replace(/^Bearer\s+/i,'')
  if(!secret||!provided||!await secureEqual(secret,provided))return new Response(JSON.stringify({error:'Unauthorized.'}),{status:401,headers})
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}})
  const {data:released,error:releaseError}=await db.rpc('release_expired_b2b_orders')
  if(releaseError)return new Response(JSON.stringify({error:'Reservation maintenance failed.'}),{status:503,headers})
  const {data,error}=await db.rpc('claim_notification_deliveries',{batch_size:20})
  if(error)return new Response(JSON.stringify({error:'Notification queue could not be claimed.'}),{status:503,headers})
  let sent=0,failed=0
  for(const delivery of (data||[]) as Delivery[]){
    try{
      const reference=delivery.channel==='email'?await sendEmail(delivery):await sendWhatsApp(delivery)
      const {error:completeError}=await db.rpc('complete_notification_delivery',{delivery_id:delivery.id,was_sent:true,provider_ref:reference,error_message:null})
      if(completeError)throw completeError
      sent++
    }catch(error){
      failed++
      await db.rpc('complete_notification_delivery',{delivery_id:delivery.id,was_sent:false,provider_ref:null,error_message:error instanceof Error?error.message:'Provider request failed'})
    }
  }
  return new Response(JSON.stringify({released_orders:released||0,notifications:{claimed:(data||[]).length,sent,failed}}),{status:200,headers})
})
