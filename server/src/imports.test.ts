import assert from 'node:assert/strict'
import test from 'node:test'
import { importColumns, validateImportRows } from './imports.js'
const row=['SKU-1','pack','B-1','2030-12-31','12','1000','1200']
test('import accepts whole wholesale units and integer paise',()=>{
  const [value]=validateImportRows([importColumns,row]);assert.equal(value.quantity,12);assert.equal(value.price_paise,1000)
})
test('import rejects duplicate batches, formulas, ambiguous dates and fractional quantities',()=>{
  assert.throws(()=>validateImportRows([importColumns,row,row]),/Duplicate/)
  for(const [index,value] of [[0,'=HYPERLINK("bad")'],[3,'2030-02-30'],[3,'12/01/2030'],[4,'1.5'],[5,'1201'],[6,'0']] as const){
    const invalid=[...row];invalid[index]=value;assert.throws(()=>validateImportRows([importColumns,invalid]))
  }
  assert.throws(()=>validateImportRows([importColumns,...Array.from({length:501},()=>row)]))
  assert.throws(()=>validateImportRows([['sku'],row]))
  assert.throws(()=>validateImportRows(null))
})
