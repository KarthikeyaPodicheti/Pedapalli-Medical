export type LocalAccount={
  email:string;accountType:'buyer'|'staff';staffRole:string|null;buyerStatus:string|null;
  mfaVerified:boolean;mfaSetupRequired:boolean;
}
export type LocalSettings={store_name:string;checkout_enabled:boolean;reservation_minutes:number;minimum_shelf_life_days:number;allowed_payment_methods:string[];allowed_fulfilment_methods:string[]}
export type LocalProduct={id:string;sku:string;name:string;composition:string;strength:string;pack_size:string;manufacturer:string;category:string;wholesale_unit:string;units_per_case:number;minimum_order_quantity:number;quantity_step:number;mrp_paise:number;price_paise:number|null;regulatory_class:string;prescription_required:boolean;sellable_quantity:number|null}
export type LocalBuyer={id:string;legal_name:string;contact_name:string;phone:string;gstin:string|null;drug_licence_number:string;registered_address:string;pincode:string;status:string;review_note:string|null;created_at:string}
export type LocalOrder={id:string;reference:string;status:string;payment_method:string;fulfilment_method:string;total_paise:number;reservation_expires_at:string;created_at:string;legal_name?:string;contact_name?:string;phone?:string;items:{sku:string;name:string;pack_size?:string;quantity:number;unit_price_paise:number;line_total_paise:number}[]}
export type LocalBatch={id:string;product_id:string;sku:string;name:string;batch_number:string;expiry_date:string;on_hand:number;reserved:number;available:number;status:string;received_on:string;supplier_reference:string|null}
export type InventoryImport={id:string;preview_version:string;source_reference:string;checksum:string;mode:'opening'|'receipt';status:'preview'|'applied'|'reconciled';created_at:string;applied_at:string|null;reconciled_at:string|null;rows:{sku:string;name:string;wholesale_unit:string;batch_number:string;expiry_date:string;quantity:number;price_paise:number;mrp_paise:number;before:{price_paise:number;mrp_paise:number;batch:{on_hand:number;reserved:number;status:string}|null}}[]}

async function request<T>(path:string,options:RequestInit={}){
  const response=await fetch(path,{credentials:'same-origin',...options,headers:{...(options.body?{'Content-Type':'application/json'}:{}),...options.headers}})
  const payload=await response.json().catch(()=>({})) as T&{error?:string}
  if(!response.ok)throw new Error(payload.error||'The request could not be completed.')
  return payload
}
const post=<T>(path:string,data:unknown)=>request<T>(path,{method:'POST',body:JSON.stringify(data)})

export const localApi={
  session:()=>request<{account:LocalAccount|null}>('/api/auth/session'),
  register:(email:string,password:string)=>post<{message:string}>('/api/auth/register',{email,password}),
  login:(email:string,password:string,mfaCode='')=>post<{ok?:boolean;mfaRequired?:boolean;mfaSetupRequired?:boolean}>('/api/auth/login',{email,password,mfaCode}),
  logout:()=>post<{ok:boolean}>('/api/auth/logout',{}),
  logoutAll:()=>post<{ok:boolean}>('/api/auth/logout-all',{}),
  catalog:()=>request<{products:LocalProduct[];canTrade:boolean;settings:LocalSettings}>('/api/catalog'),
  buyer:()=>request<{buyer:LocalBuyer|null}>('/api/buyer'),
  apply:(data:Record<string,string>)=>post<{ok:boolean}>('/api/buyer',data),
  orders:()=>request<{orders:LocalOrder[]}>('/api/orders'),
  createOrder:(items:{product_id:string;quantity:number}[],payment:string,fulfilment:string)=>post<{order_id:string;reference:string;total_paise:number}>('/api/orders',{items,payment,fulfilment,idempotencyKey:crypto.randomUUID()}),
  cancelOrder:(id:string)=>request<{cancelled:boolean}>(`/api/orders/${id}`,{method:'DELETE'}),
  mfaSetup:()=>post<{manualKey:string;otpauthUri:string}>('/api/staff/mfa/setup',{}),
  mfaVerify:(code:string)=>post<{ok:boolean}>('/api/staff/mfa/verify-setup',{code}),
  staffBuyers:()=>request<{buyers:LocalBuyer[]}>('/api/staff/buyers'),
  reviewBuyer:(id:string,status:string,note:string)=>post<{ok:boolean}>(`/api/staff/buyers/${id}/review`,{status,note}),
  staffInventory:()=>request<{batches:LocalBatch[]}>('/api/staff/inventory'),
  receive:(sourceReference:string,lines:{line_key:string;product_id:string;batch_number:string;expiry_date:string;quantity:number}[])=>post<{saved:number}>('/api/staff/inventory/receipts',{sourceReference,lines}),
  releaseBatch:(id:string)=>post<{ok:boolean}>(`/api/staff/inventory/batches/${id}/release`,{}),
  staffOrders:()=>request<{orders:LocalOrder[]}>('/api/staff/orders'),
  inventoryImports:()=>request<{imports:InventoryImport[]}>('/api/staff/inventory/imports'),
  previewImport:(sourceReference:string,mode:string,rows:string[][])=>post<{import:InventoryImport}>('/api/staff/inventory/imports/preview',{sourceReference,mode,rows}),
  applyImport:(id:string,previewVersion:string)=>post<{ok:boolean}>(`/api/staff/inventory/imports/${id}/apply`,{previewVersion}),
  reconcileImport:(id:string,counts:number[],note:string)=>post<{ok:boolean}>(`/api/staff/inventory/imports/${id}/reconcile`,{counts,note}),
}
