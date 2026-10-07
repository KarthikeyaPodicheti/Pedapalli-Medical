import type { Product, StoreSettings } from './types'

const rows: [string, string, string, string, string, Product['category'], number, number, boolean][] = [
  ['Paracetamol', 'Paracetamol', '500 mg', 'Strip of 10 tablets', 'Example Pharma', 'Medicines', 2200, 32, false],
  ['Vitamin C', 'Ascorbic acid', '500 mg', 'Bottle of 30 tablets', 'Example Wellness', 'Nutrition', 14900, 18, false],
  ['Antiseptic solution', 'Povidone iodine', '5% w/v', '100 ml bottle', 'Example Care', 'First aid', 12500, 12, false],
  ['Digital thermometer', 'Digital temperature reader', '', '1 device', 'Example Health', 'Health devices', 19900, 8, false],
  ['Oral rehydration salts', 'Oral rehydration salts', '', '21 g sachet', 'Example Pharma', 'Medicines', 2100, 45, false],
  ['Baby gentle wash', 'Gentle cleansing wash', '', '200 ml bottle', 'Example Baby', 'Baby care', 18500, 14, false],
  ['Amoxicillin', 'Amoxicillin', '500 mg', 'Strip of 10 capsules', 'Example Pharma', 'Medicines', 9800, 0, true],
  ['Metformin', 'Metformin hydrochloride', '500 mg', 'Strip of 10 tablets', 'Example Pharma', 'Medicines', 3500, 22, true],
  ['Hand sanitiser', 'Alcohol-based sanitiser', '70%', '100 ml bottle', 'Example Care', 'Personal care', 6500, 25, false],
  ['Cotton crepe bandage', 'Elastic cotton bandage', '10 cm', '1 roll', 'Example Care', 'First aid', 8900, 16, false],
  ['Blood pressure monitor', 'Upper-arm digital monitor', '', '1 device', 'Example Health', 'Health devices', 149900, 0, false],
  ['Aloe vera gel', 'Aloe vera gel', '', '100 g tube', 'Example Botanicals', 'Ayurveda', 9900, 10, false],
]
export const sampleProducts: Product[] = rows.map((p, i) => ({ id: `demo-${i+1}`, sku: `PM-${String(i+1).padStart(3, '0')}`, name:p[0], composition:p[1], strength:p[2], pack_size:p[3], manufacturer:p[4], category:p[5], price_paise:p[6], stock:p[7], prescription_required:p[8], active:true, version:1 }))
export const initialSettings: StoreSettings = { store_name:'Petapali Medical', checkout_enabled:false, serviceable_pincodes:[], delivery_fee_paise:0, minimum_order_paise:0 }
export const money = (paise: number) => new Intl.NumberFormat('en-IN', { style:'currency', currency:'INR', maximumFractionDigits: paise % 100 ? 2 : 0 }).format(paise / 100)
