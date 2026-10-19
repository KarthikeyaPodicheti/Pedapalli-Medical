import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
const [project,directory]=process.argv.slice(2)
function jar(file){return readFileSync(`${directory}/${file}`,'utf8').split('\n').filter(line=>line.includes('\tpm_session\t')).map(line=>`pm_session=${line.split('\t').at(-1)}`)[0]}
const staff=jar('staff-mfa-cookies.txt'),buyer=jar('cookies.txt')
async function api(path,expected,{cookie=staff,data,headers={}}={}){
  const response=await fetch(`http://127.0.0.1:8080/api${path}`,{method:data===undefined?'GET':'POST',headers:{Origin:'http://localhost:8080','Content-Type':'application/json',...(cookie?{Cookie:cookie}:{}),...headers},body:data===undefined?undefined:JSON.stringify(data)})
  const payload=await response.json();assert.equal(response.status,expected,`${path}: ${JSON.stringify(payload)}`)
  return {payload,cookie:response.headers.get('set-cookie')?.split(';')[0]}
}
function command(args,input){const result=spawnSync('docker',['compose','-p',project,...args],{input,encoding:'utf8'});assert.equal(result.status,0,result.stderr);return result.stdout}
function admin(action,email,password){command(['run','--rm','-T','migrate','node','dist/admin.js'],JSON.stringify({action,email,password,operator:'Integration operator',reason:'Verify audited recovery and session revocation'}))}
command(['exec','-T','db','psql','-U','postgres','-d','medical','-v','ON_ERROR_STOP=1'],"insert into public.products(sku,name,pack_size,manufacturer,mrp_paise,price_paise) values('IMPORT-API','Synthetic import product','10 units','Test manufacturer',1200,1000);")
await api('/auth/login',400,{cookie:'',data:null})
await api('/auth/login',403,{cookie:'',data:{},headers:{Origin:'https://wrong.example'}})
await api('/staff/inventory/imports',403,{cookie:buyer})
const header=['sku','wholesale_unit','batch_number','expiry_date','quantity','price_paise','mrp_paise']
const expiry=new Date(Date.now()+500*86400000).toISOString().slice(0,10)
const rows=[header,['IMPORT-API','pack','API-BATCH',expiry,'10','1000','1200']]
await api('/staff/inventory/imports/preview',400,{data:{sourceReference:'BAD-ROWS',mode:'opening',rows:[header,[...rows[1].slice(0,4),'0','1000','1200']]}})
const {payload:{import:preview}}=await api('/staff/inventory/imports/preview',200,{data:{sourceReference:'API-IMPORT',mode:'opening',rows}})
const apply=()=>api(`/staff/inventory/imports/${preview.id}/apply`,200,{data:{previewVersion:preview.preview_version}})
await Promise.all([apply(),apply()])
const {payload:{batches}}=await api('/staff/inventory',200)
assert.equal(batches.find(b=>b.batch_number==='API-BATCH').on_hand,10)
assert.equal(batches.find(b=>b.batch_number==='API-BATCH').status,'quarantined')
await api(`/staff/inventory/imports/${preview.id}/reconcile`,409,{data:{counts:[10],note:'Same operator must not approve own import'}})
const first=await api('/auth/login',200,{cookie:'',data:{email:'buyer@example.in',password:'Synthetic buyer password 2026!'}})
await api('/auth/logout-all',200,{cookie:first.cookie,data:{}})
assert.equal((await api('/auth/session',200,{cookie:buyer})).payload.account,null)
assert.equal((await api('/auth/session',200,{cookie:first.cookie})).payload.account,null)
const beforeReset=await api('/auth/login',200,{cookie:'',data:{email:'buyer@example.in',password:'Synthetic buyer password 2026!'}})
admin('reset-password','buyer@example.in','Recovered buyer password 2026!')
assert.equal((await api('/auth/session',200,{cookie:beforeReset.cookie})).payload.account,null)
await api('/auth/login',401,{cookie:'',data:{email:'buyer@example.in',password:'Synthetic buyer password 2026!'}})
const afterReset=await api('/auth/login',200,{cookie:'',data:{email:'buyer@example.in',password:'Recovered buyer password 2026!'}})
admin('disable-account','buyer@example.in')
assert.equal((await api('/auth/session',200,{cookie:afterReset.cookie})).payload.account,null)
await api('/auth/login',401,{cookie:'',data:{email:'buyer@example.in',password:'Recovered buyer password 2026!'}})
for(let i=0;i<11;i++)await api('/auth/login',i<10?401:429,{cookie:'',data:{email:'rate-test@example.in',password:'Incorrect password 2026!'},headers:{'X-Real-IP':`192.0.2.${i+1}`}})
console.log('Import API, concurrent apply, recovery, global logout, malformed body and login rate-limit checks passed')
