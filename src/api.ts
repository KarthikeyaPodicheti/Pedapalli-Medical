import { createClient } from '@supabase/supabase-js'
import type { CartItem, Customer, Product, StoreSettings, OrderStatus } from './types'
const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY
export const supabase = url && key ? createClient(url,key) : null
export const isDemo = !supabase
export async function loadCatalog() {
  if (!supabase) throw new Error('Backend is not configured.')
  const [products,settings] = await Promise.all([supabase.from('products').select('*').order('name'),supabase.from('store_settings').select('*').eq('id',1).single()])
  if (products.error) throw products.error
  if (settings.error) throw settings.error
  return { products:products.data as Product[], settings:settings.data as StoreSettings }
}
export async function saveProducts(products: Product[]) {
  const { error } = await supabase!.rpc('upsert_inventory',{ changes:products })
  if(error) throw error
}
export async function submitOrder(customer:Customer,cart:CartItem[],idempotencyKey:string,challenge:string) {
  const {data,error}=await supabase!.functions.invoke('checkout',{body:{customer,items:cart.map(i=>({product_id:i.productId,quantity:i.quantity})),idempotency_key:idempotencyKey,challenge}})
  if(error) throw new Error('The order could not be confirmed. Check your connection and retry; the same request will not be charged or reserved twice.')
  if(data.error) throw new Error(data.error)
  return data as {reference:string;total_paise:number}
}
export async function updateOrder(id:string,status:OrderStatus,verifyPrescription:boolean) {
  const {error}=await supabase!.rpc('transition_order',{order_id:id,next_status:status,verify_prescription:verifyPrescription})
  if(error) throw error
}
