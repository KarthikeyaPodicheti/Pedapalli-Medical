import assert from 'node:assert/strict'
import test from 'node:test'
import { createToken, digestToken, hashPassword, validatePassword, verifyPassword } from './security.js'

test('passwords are hashed and verified without storing plaintext',async()=>{
  const password='Correct Horse Battery 2026!'
  const encoded=await hashPassword(password)
  assert.match(encoded,/^scrypt\$/)
  assert.equal(encoded.includes(password),false)
  assert.equal(await verifyPassword(password,encoded),true)
  assert.equal(await verifyPassword('incorrect-password',encoded),false)
})

test('weak and oversized passwords are rejected',()=>{
  assert.throws(()=>validatePassword('too-short'))
  assert.throws(()=>validatePassword('x'.repeat(257)))
})

test('session tokens are random and only their digest needs persistence',()=>{
  const first=createToken(),second=createToken()
  assert.notEqual(first,second)
  assert.equal(digestToken(first).length,64)
  assert.notEqual(digestToken(first),digestToken(second))
})
