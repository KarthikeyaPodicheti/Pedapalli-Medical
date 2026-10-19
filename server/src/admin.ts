import { stdin, stdout } from 'node:process'
import pg from 'pg'
import { hashPassword } from './security.js'

const {Client}=pg
const databaseUrl=process.env.MIGRATION_DATABASE_URL
if(!databaseUrl)throw new Error('MIGRATION_DATABASE_URL is required')

let input=''
stdin.setEncoding('utf8')
for await(const chunk of stdin){input+=chunk;if(Buffer.byteLength(input)>8192)throw new Error('Admin input is too large')}
const request=JSON.parse(input) as {action?:string;email?:string;password?:string;role?:string;operator?:string;reason?:string}
if((request.operator??'').trim().length<3||(request.reason??'').trim().length<10)throw new Error('Operator and a meaningful reason are required')
if(request.action!=='create-staff')throw new Error('Unsupported admin action')
const email=(request.email??'').trim().toLowerCase()
if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Error('Valid staff email required')
if(!['owner','sales','inventory','dispatch','pharmacist'].includes(request.role??''))throw new Error('Valid staff role required')
const passwordHash=await hashPassword(request.password??'')

const client=new Client({connectionString:databaseUrl})
await client.connect()
try{
  await client.query('begin')
  const saved=await client.query<{id:string}>(
    `insert into private.users(email,password_hash,account_type) values($1,$2,'staff') returning id`,[email,passwordHash])
  await client.query(`insert into public.staff_members(user_id,role,can_review_buyers)
    values($1,$2,$2=any(array['owner','sales','pharmacist']))`,[saved.rows[0].id,request.role])
  await client.query(`insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
    values(null,'staff.created','user',$1,jsonb_build_object('operator',$2::text,'reason',$3::text,'role',$4::text))`,
    [saved.rows[0].id,request.operator?.trim(),request.reason?.trim(),request.role])
  await client.query('commit')
  stdout.write('Staff account created.\n')
}catch(error){await client.query('rollback');throw error}finally{await client.end()}
