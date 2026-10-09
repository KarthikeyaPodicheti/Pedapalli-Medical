import { createClient } from '@supabase/supabase-js'
import type { CartItem, Product, StoreSettings, Order, OrderStatus, BuyerBusiness } from './types'
const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY
export const supabase = url && key ? createClient(url,key) : null
export const isDemo = !supabase
export async function loadCatalog() {
  if (!supabase) throw new Error('Backend is not configured.')
  const [products,settings] = await Promise.all([supabase.rpc('get_b2b_catalog'),supabase.from('store_settings').select('*').eq('id',1).single()])
  if (products.error) throw products.error
  if (settings.error) throw settings.error
  return { products:products.data as Product[], settings:settings.data as StoreSettings }
}
export async function emailSignIn(email:string) {
  if(!supabase) throw new Error('Backend is not configured.')
  const redirect=`${location.origin}${import.meta.env.BASE_URL}`
  const {error}=await supabase.auth.signInWithOtp({email,options:{emailRedirectTo:redirect}})
  if(error) throw error
}
export async function signOutBuyer(){if(supabase){const {error}=await supabase.auth.signOut();if(error)throw error}}
export async function loadMyBuyer():Promise<BuyerBusiness|null>{
  if(!supabase)return null
  const {data:{session}}=await supabase.auth.getSession()
  if(!session)return null
  const {data,error}=await supabase.from('buyer_businesses').select('*').maybeSingle()
  if(error)throw error
  return data as BuyerBusiness|null
}
export async function submitBuyerApplication(application:Record<string,string>){
  const {data,error}=await supabase!.rpc('submit_buyer_application',{application})
  if(error)throw error
  return data as string
}
export async function submitB2BOrder(cart:CartItem[],payment:string,fulfilment:string,idempotencyKey:string){
  const {data,error}=await supabase!.rpc('create_b2b_order',{items:cart.map(i=>({product_id:i.productId,quantity:i.quantity})),payment,fulfilment,idempotency_key:idempotencyKey})
  if(error)throw new Error(error.message||'The order could not be submitted.')
  return data as {reference:string;total_paise:number}
}
export async function listBuyers(){const {data,error}=await supabase!.from('buyer_businesses').select('*').order('created_at',{ascending:false});if(error)throw error;return data as BuyerBusiness[]}
export async function reviewBuyer(id:string,status:'approved'|'rejected'|'suspended',note=''){const {error}=await supabase!.rpc('review_buyer',{target_buyer:id,next_status:status,note});if(error)throw error}
export async function listMyOrders(){const {data,error}=await supabase!.from('orders').select('*,order_items(*)').order('created_at',{ascending:false}).limit(100);if(error)throw error;return data as Order[]}
export async function saveProducts(products: Product[]) {
  const { error } = await supabase!.rpc('upsert_inventory',{ changes:products })
  if(error) throw error
}
export async function updateOrder(id:string,status:OrderStatus,verifyPrescription:boolean) {
  const {error}=await supabase!.rpc('transition_order',{order_id:id,next_status:status,verify_prescription:verifyPrescription})
  if(error) throw error
}
