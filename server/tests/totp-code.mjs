import { createHmac } from 'node:crypto'

let input=''
for await(const chunk of process.stdin)input+=chunk
const secret=JSON.parse(input).manualKey
const alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
let bits=''
for(const character of secret){const value=alphabet.indexOf(character);if(value<0)throw new Error('Invalid secret');bits+=value.toString(2).padStart(5,'0')}
const bytes=[]
for(let index=0;index+8<=bits.length;index+=8)bytes.push(Number.parseInt(bits.slice(index,index+8),2))
const counter=Buffer.alloc(8)
counter.writeBigUInt64BE(BigInt(Math.floor(Date.now()/30_000)))
const digest=createHmac('sha1',Buffer.from(bytes)).update(counter).digest(),offset=digest[digest.length-1]&15
process.stdout.write(String((digest.readUInt32BE(offset)&0x7fffffff)%1_000_000).padStart(6,'0'))
