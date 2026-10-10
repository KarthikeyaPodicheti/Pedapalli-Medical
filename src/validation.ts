import { categories, type Customer, type Product } from './types'

export function parsePrice(value: string): number | null {
  if (!/^\d{1,6}(\.\d{1,2})?$/.test(value.trim())) return null
  const [whole, decimals = ''] = value.trim().split('.')
  return Number(whole) * 100 + Number(decimals.padEnd(2, '0'))
}
export function customerErrors(customer: Customer): string[] {
  const errors: string[] = []
  if (customer.name.trim().length < 2 || customer.name.trim().length > 100) errors.push('Enter your full name (2–100 characters).')
  if (!/^[6-9]\d{9}$/.test(customer.phone)) errors.push('Enter a valid 10-digit Indian mobile number.')
  if (customer.address.trim().length < 10 || customer.address.length > 400) errors.push('Enter a complete address (10–400 characters).')
  if (customer.locality.trim().length < 2 || customer.locality.length > 100) errors.push('Enter your locality (2–100 characters).')
  if (!/^[1-9]\d{5}$/.test(customer.pincode)) errors.push('Enter a valid 6-digit PIN code.')
  return errors
}
export const importColumns = ['sku','name','composition','strength','pack_size','manufacturer','category','price','mrp','stock','wholesale_unit','units_per_case','minimum_order_quantity','quantity_step','regulatory_class','prescription_required','pharmacist_approved','active']
export interface ImportPreview { products: Product[]; errors: string[]; creates: number; updates: number }
export function validateRows(rows: string[][], existing: Product[]): ImportPreview {
  const result: ImportPreview = { products:[], errors:[], creates:0, updates:0 }
  if (rows.length < 2) return { ...result, errors:['The file needs a header and at least one product row.'] }
  if (rows.length > 501) return { ...result, errors:['Import a maximum of 500 products at a time.'] }
  const headers = rows[0].map(v => v.trim().replace(/^\uFEFF/, '').toLowerCase())
  if (headers.length !== importColumns.length || new Set(headers).size !== headers.length || importColumns.some(v => !headers.includes(v))) return { ...result, errors:[`Use exactly these columns: ${importColumns.join(', ')}.`] }
  const seen = new Set<string>()
  rows.slice(1).forEach((cells,index) => {
    if (cells.every(c => !c.trim())) return
    const label = `Row ${index+2}`
    if (cells.length !== headers.length) { result.errors.push(`${label}: column count does not match the header.`); return }
    const row = Object.fromEntries(headers.map((key,i) => [key,cells[i].trim()]))
    const errors: string[] = []
    if (!/^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$/.test(row.sku)) errors.push('SKU must be 1–40 letters, numbers, hyphens or underscores')
    const sku = row.sku.toUpperCase()
    if (seen.has(sku)) errors.push('duplicate SKU')
    seen.add(sku)
    for (const key of ['name','pack_size','manufacturer']) if (!row[key] || row[key].length > 160) errors.push(`${key} is required (max 160 characters)`)
    for (const key of ['composition','strength']) if (row[key].length > 160) errors.push(`${key} exceeds 160 characters`)
    if (!categories.includes(row.category as Product['category'])) errors.push('unknown category')
    const price = parsePrice(row.price)
    if (price === null || price <= 0) errors.push('price must be positive rupees with at most 2 decimal places')
    const mrp = parsePrice(row.mrp)
    if (mrp === null || mrp <= 0) errors.push('mrp must be positive rupees with at most 2 decimal places')
    if (price !== null && mrp !== null && mrp < price) errors.push('mrp cannot be lower than the wholesale price')
    for (const key of ['stock','units_per_case','minimum_order_quantity','quantity_step']) if (!/^\d{1,6}$/.test(row[key])) errors.push(`${key} must be a nonnegative whole number up to 999999`)
    if(Number(row.units_per_case)<1||Number(row.minimum_order_quantity)<1||Number(row.quantity_step)<1)errors.push('case size, MOQ and quantity step must be at least 1')
    if(!row.wholesale_unit||row.wholesale_unit.length>40)errors.push('wholesale_unit is required (max 40 characters)')
    if(!row.regulatory_class||row.regulatory_class.length>80)errors.push('regulatory_class is required (max 80 characters)')
    for (const key of ['prescription_required','pharmacist_approved','active']) if (!['true','false'].includes(row[key].toLowerCase())) errors.push(`${key} must be true or false`)
    if (errors.length) { result.errors.push(`${label}: ${errors.join('; ')}.`); return }
    const old = existing.find(p => p.sku.toUpperCase() === sku)
    if (old) result.updates++; else result.creates++
    result.products.push({id:old?.id || crypto.randomUUID(),sku,name:row.name,composition:row.composition,strength:row.strength,pack_size:row.pack_size,manufacturer:row.manufacturer,category:row.category as Product['category'],price_paise:price!,mrp_paise:mrp!,stock:Number(row.stock),wholesale_unit:row.wholesale_unit,units_per_case:Number(row.units_per_case),minimum_order_quantity:Number(row.minimum_order_quantity),quantity_step:Number(row.quantity_step),regulatory_class:row.regulatory_class,prescription_required:row.prescription_required.toLowerCase()==='true',pharmacist_approved:row.pharmacist_approved.toLowerCase()==='true',active:row.active.toLowerCase()==='true',version:old?.version || 0})
  })
  if (!result.products.length && !result.errors.length) result.errors.push('No product rows found.')
  return result
}
export function parseCsv(text: string): string[][] {
  const rows: string[][] = []; let row: string[] = [], cell = '', quoted = false, closed = false
  for (let i=0;i<text.length;i++) {
    const c = text[i]
    if (c==='"') {
      if (quoted && text[i+1]==='"') { cell+='"'; i++ }
      else if (quoted) { quoted=false; closed=true }
      else if (!cell && !closed) quoted=true
      else throw new Error('Invalid quote in CSV cell.')
    } else if (c===',' && !quoted) { row.push(cell); cell=''; closed=false }
    else if ((c==='\n'||c==='\r')&&!quoted) { if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);rows.push(row);row=[];cell='';closed=false }
    else { if(closed) throw new Error('Unexpected text after a quoted CSV cell.');cell+=c }
  }
  if(quoted)throw new Error('CSV has an unclosed quoted cell.')
  if(cell||row.length){row.push(cell);rows.push(row)}
  return rows
}
