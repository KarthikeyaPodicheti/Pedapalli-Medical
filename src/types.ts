export const categories = ['Medicines', 'First aid', 'Personal care', 'Baby care', 'Health devices', 'Nutrition', 'Ayurveda'] as const
export type Category = typeof categories[number]
export interface Product {
  id: string; sku: string; name: string; composition: string; strength: string; pack_size: string;
  manufacturer: string; category: Category; price_paise: number; stock: number;
  prescription_required: boolean; active: boolean; version: number;
}
export interface CartItem { productId: string; quantity: number }
export interface Customer { name: string; phone: string; address: string; locality: string; pincode: string }
export interface StoreSettings { store_name: string; checkout_enabled: boolean; serviceable_pincodes: string[]; delivery_fee_paise: number; minimum_order_paise: number }
export type OrderStatus = 'pending' | 'accepted' | 'out_for_delivery' | 'completed' | 'cancelled'
export interface Order {
  id: string; reference: string; customer_name: string; phone: string; address: string; locality: string; pincode: string;
  status: OrderStatus; total_paise: number; created_at: string; prescription_verified_at: string | null;
  order_items: { name: string; pack_size: string; quantity: number; unit_price_paise: number; prescription_required: boolean }[];
}
