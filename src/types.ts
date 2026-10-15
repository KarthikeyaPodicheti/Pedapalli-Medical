export const categories = ['Medicines', 'First aid', 'Personal care', 'Baby care', 'Health devices', 'Nutrition', 'Ayurveda'] as const
export type Category = typeof categories[number]
export interface Product {
  id: string; sku: string; name: string; composition: string; strength: string; pack_size: string;
  manufacturer: string; category: Category; price_paise: number; stock: number;
  prescription_required: boolean; active: boolean; version: number;
  mrp_paise?: number; wholesale_unit?: string; units_per_case?: number;
  minimum_order_quantity?: number; quantity_step?: number;
  regulatory_class?: string; pharmacist_approved?: boolean;
}
export interface CartItem { productId: string; quantity: number }
export interface Customer { name: string; phone: string; address: string; locality: string; pincode: string }
export interface StoreSettings { store_name: string; checkout_enabled: boolean; serviceable_pincodes: string[]; delivery_fee_paise: number; minimum_order_paise: number; allowed_payment_methods?: string[]; allowed_fulfilment_methods?: string[]; reservation_minutes?: number; order_confirmation_notice?: string }
export type BuyerStatus = 'pending' | 'approved' | 'rejected' | 'suspended'
export interface BuyerBusiness {
  id:string; legal_name:string; contact_name:string; email:string; phone:string; gstin:string|null;
  drug_licence_number:string; registered_address:string; pincode:string; status:BuyerStatus;
  reviewed_at:string|null; review_note:string|null; created_at:string;
}
export interface NotificationDelivery {
  id:number; channel:'email'|'whatsapp'; event_name:string; status:'pending'|'processing'|'sent'|'failed';
  attempts:number; last_error:string|null; created_at:string;
  buyer_businesses:{legal_name:string}|null; orders:{reference:string}|null;
}
export type OrderStatus = 'pending' | 'accepted' | 'out_for_delivery' | 'completed' | 'cancelled'
export interface Order {
  id: string; reference: string; customer_name: string; phone: string; address: string; locality: string; pincode: string;
  status: OrderStatus; total_paise: number; created_at: string; prescription_verified_at: string | null;
  subtotal_paise?:number; delivery_fee_paise?:number; payment_method?:'cod'|'bank_transfer'; fulfilment_method?:'own_delivery'|'transporter'|'pickup'; reservation_expires_at?:string|null;
  order_items: { name: string; pack_size: string; quantity: number; unit_price_paise: number; prescription_required: boolean }[];
}
