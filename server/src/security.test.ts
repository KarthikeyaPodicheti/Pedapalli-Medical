import assert from 'node:assert/strict'
import test from 'node:test'
import { createMfaSecret, createToken, decryptMfaSecret, digestToken, encodeBase32, encryptMfaSecret, hashPassword, parseMfaKey, totpCode, validatePassword, verifyPassword, verifyTotp } from './security.js'

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

test('TOTP matches the RFC vector and accepts only the current time window',()=>{
  const secret=encodeBase32(Buffer.from('12345678901234567890'))
  assert.equal(totpCode(secret,59_000),'287082')
  assert.equal(verifyTotp(secret,'287082',59_000),true)
  assert.equal(verifyTotp(secret,'287082',180_000),false)
})

test('MFA secrets are encrypted with authenticated encryption',()=>{
  const key=parseMfaKey('11'.repeat(32)),secret=createMfaSecret()
  const encrypted=encryptMfaSecret(secret,key)
  assert.equal(encrypted.includes(secret),false)
  assert.equal(decryptMfaSecret(encrypted,key),secret)
  assert.throws(()=>decryptMfaSecret(`${encrypted}x`,key))
})
