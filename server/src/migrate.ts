import { createHash } from 'node:crypto'
import { promises as fs } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import pg from 'pg'

const {Client}=pg
const databaseUrl=process.env.MIGRATION_DATABASE_URL
const apiPassword=process.env.LOCAL_API_PASSWORD
if(!databaseUrl)throw new Error('MIGRATION_DATABASE_URL is required')
if(!apiPassword||apiPassword.length<24)throw new Error('LOCAL_API_PASSWORD must contain at least 24 characters')

const sqlDirectory=resolve(dirname(fileURLToPath(import.meta.url)),'../sql')
const client=new Client({connectionString:databaseUrl})
await client.connect()
try{
  await client.query('select pg_advisory_lock($1)',[72421099])
  await client.query(`create table if not exists public.local_schema_migrations(
    name text primary key, sha256 text not null, applied_at timestamptz not null default now())`)
  const names=(await fs.readdir(sqlDirectory)).filter(name=>/^\d+.*\.sql$/.test(name)).sort()
  for(const name of names){
    const sql=await fs.readFile(resolve(sqlDirectory,name),'utf8')
    const sha256=createHash('sha256').update(sql).digest('hex')
    const applied=await client.query<{sha256:string}>('select sha256 from public.local_schema_migrations where name=$1',[name])
    if(applied.rowCount){
      if(applied.rows[0].sha256!==sha256)throw new Error(`Applied migration changed: ${name}`)
      continue
    }
    await client.query('begin')
    try{
      await client.query(sql)
      await client.query('insert into public.local_schema_migrations(name,sha256) values($1,$2)',[name,sha256])
      await client.query('commit')
      process.stdout.write(`Applied ${name}\n`)
    }catch(error){await client.query('rollback');throw error}
  }
  const passwordSql=await client.query<{sql:string}>("select format('alter role medical_api password %L',$1::text) as sql",[apiPassword])
  await client.query(passwordSql.rows[0].sql)
}finally{
  await client.query('select pg_advisory_unlock($1)',[72421099]).catch(()=>undefined)
  await client.end()
}
