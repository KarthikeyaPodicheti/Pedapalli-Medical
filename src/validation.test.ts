import { describe, expect, it } from 'vitest'
import { sampleProducts } from './data'
import { customerErrors, importColumns, parseCsv, parsePrice, validateRows } from './validation'

const valid=['PM-001','Paracetamol','Paracetamol','500 mg','10 tablets','Example Pharma','Medicines','12.35','15','false','true']
describe('inventory imports',()=>{
  it('parses quoted commas, multiline cells and escaped quotes',()=>{
    expect(parseCsv('sku,name\r\nA,"one, two"\r\nB,"line\nnext ""quote"""')).toEqual([['sku','name'],['A','one, two'],['B','line\nnext "quote"']])
  })
  it('rejects malformed quotes instead of shifting columns',()=>{
    expect(()=>parseCsv('a,"broken')).toThrow()
    expect(()=>parseCsv('a,"closed"garbage')).toThrow()
  })
  it('matches stable SKU and preserves version for conflict detection',()=>{
    const existing={...sampleProducts[0],version:7};const result=validateRows([importColumns,valid],[existing])
    expect(result.errors).toEqual([]);expect(result.updates).toBe(1);expect(result.products[0]).toMatchObject({id:existing.id,price_paise:1235,stock:15,version:7})
  })
  it('detects case-insensitive duplicate SKUs',()=>{
    const result=validateRows([importColumns,valid,['pm-001',...valid.slice(1)]],[])
    expect(result.errors.join(' ')).toContain('duplicate SKU')
  })
  it('rejects fractional stock, missing headers and formula-like price cells',()=>{
    expect(validateRows([importColumns,[...valid.slice(0,8),'1.2','false','true']],[]).errors.length).toBe(1)
    expect(validateRows([importColumns.slice(1),valid.slice(1)],[]).errors.length).toBe(1)
    const row=[...valid];row[7]='=1+2';expect(validateRows([importColumns,row],[]).errors.length).toBe(1)
  })
  it('accepts an empty stock value only when explicitly set to zero',()=>{
    const row=[...valid];row[8]='';expect(validateRows([importColumns,row],[]).errors.length).toBe(1)
    row[8]='0';expect(validateRows([importColumns,row],[]).products[0].stock).toBe(0)
  })
  it('rejects oversized imports',()=>expect(validateRows([importColumns,...Array.from({length:501},()=>valid)],[]).errors).toEqual(['Import a maximum of 500 products at a time.']))
})
describe('money and checkout validation',()=>{
  it('converts decimal prices exactly without floating point rounding',()=>{expect(parsePrice('0.29')).toBe(29);expect(parsePrice('19.9')).toBe(1990);expect(parsePrice('1e3')).toBeNull();expect(parsePrice('-1')).toBeNull();expect(parsePrice('1.001')).toBeNull()})
  it('rejects invalid contact/address details',()=>expect(customerErrors({name:'X',phone:'1234567890',address:'Short',locality:'A',pincode:'000000'})).toHaveLength(5))
  it('accepts a complete synthetic Indian delivery address',()=>expect(customerErrors({name:'Demo Customer',phone:'9876543210',address:'House 12, Example Street',locality:'Example locality',pincode:'505172'})).toEqual([]))
})
