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
if(!['create-staff','reset-password','reset-staff-mfa','disable-account'].includes(request.action??''))throw new Error('Unsupported admin action')
const email=(request.email??'').trim().toLowerCase()
if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Error('Valid staff email required')
if(request.action==='create-staff'&&!['owner','sales','inventory','dispatch','pharmacist'].includes(request.role??''))throw new Error('Valid staff role required')
const passwordHash=['create-staff','reset-password'].includes(request.action??'')?await hashPassword(request.password??''):null

const client=new Client({connectionString:databaseUrl})
await client.connect()
try{
  await client.query('begin')
  if(request.action!=='create-staff'){
    const found=await client.query<{id:string;account_type:string}>('select id,account_type from private.users where email=$1 for update',[email])
    const target=found.rows[0];if(!target)throw new Error('Account not found')
    if(request.action==='reset-staff-mfa'){
      if(target.account_type!=='staff')throw new Error('Staff account required')
      await client.query('delete from private.staff_mfa where user_id=$1',[target.id])
    }
    if(request.action==='reset-password')await client.query('update private.users set password_hash=$1 where id=$2',[passwordHash,target.id])
    if(request.action==='disable-account')await client.query('update private.users set disabled=true where id=$1',[target.id])
    await client.query('delete from private.sessions where user_id=$1',[target.id])
    await client.query(`insert into public.audit_events(event_type,subject_type,subject_id,details)
      values($1,'user',$2,jsonb_build_object('operator',$3::text,'reason',$4::text))`,
      [`account.${request.action}`,target.id,request.operator?.trim(),request.reason?.trim()])
    await client.query('commit');stdout.write('Account security updated; all sessions revoked.\n')
  }else{
  const saved=await client.query<{id:string}>(
    `insert into private.users(email,password_hash,account_type) values($1,$2,'staff') returning id`,[email,passwordHash])
  await client.query(`insert into public.staff_members(user_id,role,can_review_buyers)
    values($1,$2,$2=any(array['owner','sales','pharmacist']))`,[saved.rows[0].id,request.role])
  await client.query(`insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
    values(null,'staff.created','user',$1,jsonb_build_object('operator',$2::text,'reason',$3::text,'role',$4::text))`,
    [saved.rows[0].id,request.operator?.trim(),request.reason?.trim(),request.role])
  await client.query('commit')
  stdout.write('Staff account created.\n')
  }
}catch(error){await client.query('rollback');throw error}finally{await client.end()}
