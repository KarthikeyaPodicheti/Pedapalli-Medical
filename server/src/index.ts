import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'
import pg from 'pg'
import { createToken, digestToken, hashPassword, validatePassword, verifyPassword } from './security.js'

const {Pool}=pg
const databaseUrl=process.env.DATABASE_URL
const appOrigin=process.env.APP_ORIGIN
if(!databaseUrl)throw new Error('DATABASE_URL is required')
if(!appOrigin)throw new Error('APP_ORIGIN is required')
const originUrl=new URL(appOrigin)
if(originUrl.protocol!=='https:'&&!['localhost','127.0.0.1'].includes(originUrl.hostname))throw new Error('APP_ORIGIN must use HTTPS outside local development')

const pool=new Pool({connectionString:databaseUrl,max:10,connectionTimeoutMillis:10_000,idleTimeoutMillis:30_000})
const port=Number(process.env.PORT||3000)
const host=process.env.HOST||'127.0.0.1'
const secureCookie=originUrl.protocol==='https:'
const sessionCookie='pm_session'
const dummyPasswordHash=await hashPassword('Timing protection only 2026!')

type Session={id:string;email:string;accountType:'buyer'|'staff';staffRole:string|null;buyerId:string|null;buyerStatus:string|null}
type Json=Record<string,unknown>

function json(res:ServerResponse,status:number,body:unknown,cookies:string[]=[]){
  res.writeHead(status,{
    'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff',
    'content-security-policy':"default-src 'none'; frame-ancestors 'none'",...(cookies.length?{'set-cookie':cookies}:{}),
  });res.end(JSON.stringify(body))
}
function cookie(token:string,maxAge:number){return `${sessionCookie}=${token}; Path=/api; HttpOnly; SameSite=Strict; Max-Age=${maxAge}${secureCookie?'; Secure':''}`}
function cookies(req:IncomingMessage){return Object.fromEntries((req.headers.cookie??'').split(';').map(v=>v.trim()).filter(Boolean).map(v=>{const at=v.indexOf('=');return [v.slice(0,at),v.slice(at+1)]}))}
async function body(req:IncomingMessage){
  if(!(req.headers['content-type']??'').toLowerCase().startsWith('application/json'))throw new HttpError(415,'Use application/json.')
  let raw='';for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>64*1024)throw new HttpError(413,'Request is too large.')}
  try{return JSON.parse(raw||'{}') as Json}catch{throw new HttpError(400,'Invalid JSON.')}
}
class HttpError extends Error{constructor(public status:number,message:string){super(message)}}
function email(value:unknown){const normalized=String(value??'').trim().toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized))throw new HttpError(400,'Enter a valid email.');return normalized}
function text(value:unknown,min:number,max:number,label:string){const normalized=String(value??'').trim();if(normalized.length<min||normalized.length>max)throw new HttpError(400,`${label} is invalid.`);return normalized}

async function session(req:IncomingMessage):Promise<Session|null>{
  const token=cookies(req)[sessionCookie];if(!token)return null
  const result=await pool.query<Session>(`select u.id,u.email,u.account_type as "accountType",s.role as "staffRole",
    b.id as "buyerId",b.status as "buyerStatus" from private.sessions x join private.users u on u.id=x.user_id
    left join public.staff_members s on s.user_id=u.id left join public.buyer_businesses b on b.user_id=u.id
    where x.token_hash=$1 and x.expires_at>now() and not u.disabled`,[digestToken(token)])
  return result.rows[0]??null
}
async function requireSession(req:IncomingMessage){const saved=await session(req);if(!saved)throw new HttpError(401,'Sign in required.');return saved}
async function requireStaff(req:IncomingMessage,roles:string[]){const saved=await requireSession(req);if(saved.accountType!=='staff'||!saved.staffRole||!roles.includes(saved.staffRole))throw new HttpError(403,'Staff permission required.');return saved}

async function consumeRateLimit(key:string){
  const result=await pool.query<{attempts:number}>(`insert into private.rate_limits(key,attempts,reset_at) values($1,1,now()+interval '15 minutes')
    on conflict(key) do update set attempts=case when private.rate_limits.reset_at<=now() then 1 else private.rate_limits.attempts+1 end,
      reset_at=case when private.rate_limits.reset_at<=now() then now()+interval '15 minutes' else private.rate_limits.reset_at end
    returning attempts`,[digestToken(key)])
  if(result.rows[0].attempts>10)throw new HttpError(429,'Too many attempts. Try again later.')
}

async function route(req:IncomingMessage,res:ServerResponse){
  const url=new URL(req.url??'/',appOrigin)
  if(req.method==='GET'&&url.pathname==='/api/health'){json(res,200,{ok:true});return}
  if(!['GET','POST','DELETE'].includes(req.method??''))throw new HttpError(405,'Method not allowed.')
  if(req.method!=='GET'&&req.headers.origin!==appOrigin)throw new HttpError(403,'Origin rejected.')

  if(req.method==='POST'&&url.pathname==='/api/auth/register'){
    const data=await body(req),userEmail=email(data.email),password=String(data.password??'')
    await consumeRateLimit(`register:${req.socket.remoteAddress}:${userEmail}`)
    try{validatePassword(password)}catch{throw new HttpError(400,'Password must be 12 to 256 characters.')}
    const passwordHash=await hashPassword(password)
    await pool.query(`insert into private.users(email,password_hash,account_type) values($1,$2,'buyer') on conflict(email) do nothing`,[userEmail,passwordHash])
    json(res,202,{message:'If the email can be registered, the account is ready to sign in.'});return
  }
  if(req.method==='POST'&&url.pathname==='/api/auth/login'){
    const data=await body(req),userEmail=email(data.email),password=String(data.password??'')
    await consumeRateLimit(`login:${req.socket.remoteAddress}:${userEmail}`)
    const found=await pool.query<{id:string;password_hash:string;disabled:boolean}>('select id,password_hash,disabled from private.users where email=$1',[userEmail])
    const candidate=found.rows[0]
    const valid=await verifyPassword(password,candidate?.password_hash??dummyPasswordHash)
    if(!candidate||candidate.disabled||!valid)throw new HttpError(401,'Invalid email or password.')
    const token=createToken();await pool.query(`insert into private.sessions(token_hash,user_id,expires_at) values($1,$2,now()+interval '8 hours')`,[digestToken(token),candidate.id])
    json(res,200,{ok:true},[cookie(token,8*60*60)]);return
  }
  if(req.method==='POST'&&url.pathname==='/api/auth/logout'){
    const token=cookies(req)[sessionCookie];if(token)await pool.query('delete from private.sessions where token_hash=$1',[digestToken(token)])
    json(res,200,{ok:true},[cookie('',0)]);return
  }
  if(req.method==='GET'&&url.pathname==='/api/auth/session'){
    const saved=await session(req);json(res,200,{account:saved?{email:saved.email,accountType:saved.accountType,staffRole:saved.staffRole,buyerStatus:saved.buyerStatus}:null});return
  }
  if(req.method==='GET'&&url.pathname==='/api/catalog'){
    const saved=await session(req),canTrade=saved?.accountType==='staff'||saved?.buyerStatus==='approved'
    const result=await pool.query(`select p.id,p.sku,p.name,p.composition,p.strength,p.pack_size,p.manufacturer,p.category,
      p.wholesale_unit,p.units_per_case,p.minimum_order_quantity,p.quantity_step,p.mrp_paise,p.price_paise,
      p.regulatory_class,p.prescription_required,i.sellable_quantity from public.products p
      join public.sellable_inventory i on i.product_id=p.id where p.active and p.pharmacist_approved order by p.name`)
    json(res,200,{products:result.rows.map(row=>({...row,price_paise:canTrade?row.price_paise:null,sellable_quantity:canTrade?row.sellable_quantity:null})),canTrade});return
  }
  if(req.method==='GET'&&url.pathname==='/api/buyer'){
    const saved=await requireSession(req);if(saved.accountType!=='buyer')throw new HttpError(403,'Buyer account required.')
    const result=await pool.query('select * from public.buyer_businesses where user_id=$1',[saved.id]);json(res,200,{buyer:result.rows[0]??null});return
  }
  if(req.method==='POST'&&url.pathname==='/api/buyer'){
    const saved=await requireSession(req);if(saved.accountType!=='buyer')throw new HttpError(403,'Buyer account required.')
    const data=await body(req),gstin=String(data.gstin??'').trim().toUpperCase()||null
    if(gstin&&!/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$/.test(gstin))throw new HttpError(400,'GSTIN is invalid.')
    await pool.query(`insert into public.buyer_businesses(user_id,legal_name,contact_name,phone,gstin,drug_licence_number,registered_address,pincode)
      values($1,$2,$3,$4,$5,$6,$7,$8)`,[saved.id,text(data.legalName,2,120,'Business name'),text(data.contactName,2,100,'Contact name'),
      String(data.phone??''),gstin,text(data.drugLicence,5,60,'Drug licence'),text(data.address,10,400,'Address'),String(data.pincode??'')])
    json(res,201,{ok:true});return
  }
  if(req.method==='GET'&&url.pathname==='/api/orders'){
    const saved=await requireSession(req);if(saved.accountType!=='buyer'||!saved.buyerId)throw new HttpError(403,'Buyer account required.')
    const result=await pool.query(`select o.*,coalesce(jsonb_agg(jsonb_build_object('sku',i.sku,'name',i.name,'quantity',i.quantity,
      'unit_price_paise',i.unit_price_paise,'line_total_paise',i.line_total_paise) order by i.name) filter(where i.id is not null),'[]') items
      from public.orders o left join public.order_items i on i.order_id=o.id where o.buyer_id=$1 group by o.id order by o.created_at desc limit 100`,[saved.buyerId])
    json(res,200,{orders:result.rows});return
  }
  if(req.method==='POST'&&url.pathname==='/api/orders'){
    const saved=await requireSession(req);if(saved.accountType!=='buyer')throw new HttpError(403,'Buyer account required.')
    const data=await body(req)
    if(!Array.isArray(data.items)||data.items.length<1||data.items.length>100)throw new HttpError(400,'Order must contain 1 to 100 lines.')
    const payment=text(data.payment,1,40,'Payment method'),fulfilment=text(data.fulfilment,1,40,'Fulfilment method')
    const idempotencyKey=String(data.idempotencyKey??'')
    if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(idempotencyKey))throw new HttpError(400,'A valid idempotency key is required.')
    try{
      const result=await pool.query(`select * from public.create_batch_order($1,$2::jsonb,$3,$4,$5::uuid,'buyer_portal')`,
        [saved.id,JSON.stringify(data.items),payment,fulfilment,idempotencyKey])
      json(res,201,result.rows[0]);return
    }catch(error){if(error instanceof Error&&error.message==='Online ordering is disabled')throw new HttpError(503,'Ordering remains disabled until inventory acceptance is complete.');throw error}
  }
  const cancelMatch=url.pathname.match(/^\/api\/orders\/([0-9a-f-]+)$/)
  if(req.method==='DELETE'&&cancelMatch){const saved=await requireSession(req);const result=await pool.query('select public.cancel_my_batch_order($1,$2)',[saved.id,cancelMatch[1]]);json(res,200,{cancelled:result.rows[0].cancel_my_batch_order});return}

  if(req.method==='GET'&&url.pathname==='/api/staff/buyers'){
    await requireStaff(req,['owner','sales','pharmacist']);const result=await pool.query('select * from public.buyer_businesses order by created_at desc limit 100');json(res,200,{buyers:result.rows});return
  }
  const reviewMatch=url.pathname.match(/^\/api\/staff\/buyers\/([0-9a-f-]+)\/review$/)
  if(req.method==='POST'&&reviewMatch){
    const saved=await requireStaff(req,['owner','sales','pharmacist']);const data=await body(req),status=String(data.status),note=text(data.note,10,500,'Review note')
    if(!['approved','rejected','suspended'].includes(status))throw new HttpError(400,'Invalid buyer status.')
    try{await pool.query('select public.review_buyer_business($1,$2,$3,$4)',[saved.id,reviewMatch[1],status,note])}
    catch(error){if(error instanceof Error&&error.message==='Buyer not found')throw new HttpError(404,'Buyer not found.');throw error}
    json(res,200,{ok:true});return
  }
  if(req.method==='GET'&&url.pathname==='/api/staff/inventory'){
    await requireStaff(req,['owner','inventory','pharmacist']);const result=await pool.query(`select b.*,p.sku,p.name,(b.on_hand-b.reserved) available
      from public.inventory_batches b join public.products p on p.id=b.product_id order by p.name,b.expiry_date,b.batch_number`);json(res,200,{batches:result.rows});return
  }
  if(req.method==='POST'&&url.pathname==='/api/staff/inventory/receipts'){
    const saved=await requireStaff(req,['owner','inventory']);const data=await body(req)
    if(!Array.isArray(data.lines)||data.lines.length<1||data.lines.length>500)throw new HttpError(400,'Receipt must contain 1 to 500 lines.')
    const result=await pool.query('select public.record_batch_receipt($1,$2,$3::jsonb) saved',[saved.id,text(data.sourceReference,1,160,'Receipt reference'),JSON.stringify(data.lines)])
    json(res,200,result.rows[0]);return
  }
  const releaseMatch=url.pathname.match(/^\/api\/staff\/inventory\/batches\/([0-9a-f-]+)\/release$/)
  if(req.method==='POST'&&releaseMatch){const saved=await requireStaff(req,['pharmacist']);await pool.query('select public.release_inventory_batch($1,$2)',[saved.id,releaseMatch[1]]);json(res,200,{ok:true});return}
  throw new HttpError(404,'Not found.')
}

const server=createServer((req,res)=>{void route(req,res).catch(error=>{
  if(error instanceof HttpError){json(res,error.status,{error:error.message});return}
  const code=typeof error==='object'&&error&&'code' in error?String(error.code):'UNEXPECTED'
  process.stderr.write(`Request failed: ${code}\n`);json(res,500,{error:'The request could not be completed.'})
})})

const roleCheck=await pool.query<{rolsuper:boolean;rolbypassrls:boolean}>("select rolsuper,rolbypassrls from pg_roles where rolname=current_user")
if(!roleCheck.rowCount||roleCheck.rows[0].rolsuper||roleCheck.rows[0].rolbypassrls)throw new Error('API database role must not be privileged')
server.listen(port,host,()=>process.stdout.write(`Local API listening on ${host}:${port}\n`))
const cleanup=setInterval(()=>{void pool.query("delete from private.sessions where expires_at<=now(); delete from private.rate_limits where reset_at<=now()")},60_000)
cleanup.unref()
for(const signal of ['SIGINT','SIGTERM'] as const)process.on(signal,()=>{server.close(()=>{void pool.end().finally(()=>process.exit(0))})})
