import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto'
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

const base32Alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
export function encodeBase32(input:Buffer){
  let bits='',output=''
  for(const byte of input)bits+=byte.toString(2).padStart(8,'0')
  for(let index=0;index<bits.length;index+=5)output+=base32Alphabet[Number.parseInt(bits.slice(index,index+5).padEnd(5,'0'),2)]
  return output
}
function decodeBase32(input:string){
  let bits=''
  for(const character of input.toUpperCase().replace(/=|\s|-/g,'')){
    const value=base32Alphabet.indexOf(character)
    if(value<0)throw new Error('Invalid base32 secret')
    bits+=value.toString(2).padStart(5,'0')
  }
  const bytes=[]
  for(let index=0;index+8<=bits.length;index+=8)bytes.push(Number.parseInt(bits.slice(index,index+8),2))
  return Buffer.from(bytes)
}
export function createMfaSecret(){return encodeBase32(randomBytes(20))}
export function totpCode(secret:string,time=Date.now(),digits=6){
  const counter=Math.floor(time/30_000),buffer=Buffer.alloc(8)
  buffer.writeBigUInt64BE(BigInt(counter))
  const digest=createHmac('sha1',decodeBase32(secret)).update(buffer).digest()
  const offset=digest[digest.length-1]&15
  const value=(digest.readUInt32BE(offset)&0x7fffffff)%(10**digits)
  return value.toString().padStart(digits,'0')
}
export function verifyTotp(secret:string,code:string,time=Date.now()){
  if(!/^\d{6}$/.test(code))return false
  return [-30_000,0,30_000].some(offset=>{
    const expected=Buffer.from(totpCode(secret,time+offset)),actual=Buffer.from(code)
    return expected.length===actual.length&&timingSafeEqual(expected,actual)
  })
}
export function parseMfaKey(value:string){
  if(!/^[0-9a-f]{64}$/i.test(value))throw new Error('LOCAL_MFA_KEY must be 64 hexadecimal characters')
  return Buffer.from(value,'hex')
}
export function encryptMfaSecret(secret:string,key:Buffer){
  const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key,iv)
  const encrypted=Buffer.concat([cipher.update(secret,'utf8'),cipher.final()])
  return `v1$${iv.toString('base64url')}$${cipher.getAuthTag().toString('base64url')}$${encrypted.toString('base64url')}`
}
export function decryptMfaSecret(value:string,key:Buffer){
  const [version,iv,tag,encrypted]=value.split('$')
  if(version!=='v1'||!iv||!tag||!encrypted)throw new Error('Invalid encrypted MFA secret')
  const decipher=createDecipheriv('aes-256-gcm',key,Buffer.from(iv,'base64url'))
  decipher.setAuthTag(Buffer.from(tag,'base64url'))
  return Buffer.concat([decipher.update(Buffer.from(encrypted,'base64url')),decipher.final()]).toString('utf8')
}
