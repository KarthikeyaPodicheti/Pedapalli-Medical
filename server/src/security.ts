import { createHash, randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto'
const keyLength=64
function derive(password:string,salt:Buffer,length:number){
  return new Promise<Buffer>((resolve,reject)=>scryptCallback(password,salt,length,{N:32768,r:8,p:1,maxmem:64*1024*1024},
    (error,key)=>error?reject(error):resolve(key as Buffer)))
}

export function validatePassword(password:string){
  if(password.length<12)throw new Error('Password must contain at least 12 characters.')
  if(Buffer.byteLength(password,'utf8')>256)throw new Error('Password is too long.')
}

export async function hashPassword(password:string){
  validatePassword(password)
  const salt=randomBytes(24)
  const key=await derive(password,salt,keyLength)
  return `scrypt$${salt.toString('base64url')}$${key.toString('base64url')}`
}

export async function verifyPassword(password:string,stored:string){
  const [algorithm,saltText,keyText]=stored.split('$')
  if(algorithm!=='scrypt'||!saltText||!keyText)return false
  try{
    const expected=Buffer.from(keyText,'base64url')
    const actual=await derive(password,Buffer.from(saltText,'base64url'),expected.length)
    return actual.length===expected.length&&timingSafeEqual(actual,expected)
  }catch{return false}
}

export function createToken(){return randomBytes(32).toString('base64url')}
export function digestToken(token:string){return createHash('sha256').update(token).digest('hex')}
