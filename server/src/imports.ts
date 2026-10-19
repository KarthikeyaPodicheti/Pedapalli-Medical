export const importColumns=['sku','wholesale_unit','batch_number','expiry_date','quantity','price_paise','mrp_paise'] as const
export function validateImportRows(input:unknown){
  if(!Array.isArray(input)||input.length<2||input.length>501)throw new Error('Use the header and 1–500 data rows.')
  if(JSON.stringify(input[0])!==JSON.stringify(importColumns))throw new Error(`Use template v1 columns: ${importColumns.join(', ')}`)
  const keys=new Set<string>()
  return input.slice(1).map((raw:unknown,index:number)=>{
    const fail=(message:string):never=>{throw new Error(`Row ${index+2}: ${message}`)}
    if(!Array.isArray(raw)||raw.length!==importColumns.length||raw.some(v=>typeof v!=='string'))return fail('Use plain text values in every template column.')
    const cells=(raw as string[]).map(v=>v.trim())
    const [sku,unit,batch,expiry,quantity,price,mrp]=cells
    if(!sku||sku.length>80||!unit||unit.length>40||!batch||batch.length>100)return fail('SKU, wholesale unit or batch is missing/too long.')
    if(cells.some(v=>/^[=+@\-]/.test(v)||/[\u0000-\u001f]/.test(v)))return fail('Formulas and control characters are not accepted.')
    if(!/^\d{4}-\d{2}-\d{2}$/.test(expiry)||!Number.isFinite(Date.parse(expiry))||new Date(expiry).toISOString().slice(0,10)!==expiry)return fail('Expiry must be a real YYYY-MM-DD date.')
    if(!/^[1-9]\d{0,5}$/.test(quantity))return fail('Quantity must be 1–999999 whole wholesale units.')
    if(!/^[1-9]\d{0,7}$/.test(price)||!/^[1-9]\d{0,7}$/.test(mrp)||Number(price)>Number(mrp))return fail('Prices must be integer paise; wholesale price cannot exceed MRP.')
    const key=JSON.stringify([sku,batch,expiry]);if(keys.has(key))return fail('Duplicate SKU, batch and expiry.');keys.add(key)
    return {sku,wholesale_unit:unit,batch_number:batch,expiry_date:expiry,quantity:Number(quantity),price_paise:Number(price),mrp_paise:Number(mrp)}
  })
}
