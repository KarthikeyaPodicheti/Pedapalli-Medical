import { useEffect, useId, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react'
import {
  ArrowLeft, Baby, Bandaids as Bandage, Buildings, CaretDown, Check, CheckCircle,
  CircleNotch, ClipboardText, Cross, Heart, Leaf, List, MagnifyingGlass, MapPin,
  Minus, Package, Pill, Plus, Pulse, ShieldCheck, ShoppingBag, SlidersHorizontal,
  Sparkle, Stethoscope, Storefront, Trash, Truck, UserCircle, Warehouse, X,
} from '@phosphor-icons/react'
import { initialSettings, money, sampleProducts } from './data'
import { cancelMyPendingOrder, emailSignIn, isDemo, listMyOrders, loadCatalog, loadMyBuyer, signOutBuyer, submitB2BOrder, submitBuyerApplication, supabase } from './api'
import { categories, type CartItem, type Order, type Product, type StoreSettings } from './types'
import Admin from './Admin'
import Turnstile from './Turnstile'

const turnstileSiteKey=import.meta.env.VITE_TURNSTILE_SITE_KEY||''

const categoryIcons = {
  Medicines:Pill, 'First aid':Bandage, 'Personal care':Sparkle, 'Baby care':Baby,
  'Health devices':Pulse, Nutrition:Heart, Ayurveda:Leaf,
}
type BuyerState = 'guest' | 'pending' | 'approved' | 'rejected' | 'suspended'
interface BuyerProfile {
  businessName:string; contactName:string; email:string; phone:string;
  gstin:string; drugLicence:string; address:string; pincode:string;
}
const demoBuyer:BuyerProfile = {
  businessName:'Srinivasa Medical & General Stores', contactName:'Demo Buyer',
  email:'buyer@example.in', phone:'9876543210', gstin:'36ABCDE1234F1Z5',
  drugLicence:'TG/20B/DEMO-001', address:'Market Road, Peddapalli, Telangana', pincode:'505172',
}
const emptyBuyer:BuyerProfile = {businessName:'',contactName:'',email:'',phone:'',gstin:'',drugLicence:'',address:'',pincode:''}

function readLocal<T>(key:string,fallback:T):T {
  try { return JSON.parse(localStorage.getItem(key)||'null')??fallback } catch { return fallback }
}
function productRules(product:Product) {
  return {
    mrp:product.mrp_paise ?? Math.ceil(product.price_paise*1.2/100)*100,
    moq:product.minimum_order_quantity ?? 1,
    step:product.quantity_step ?? 1,
    unit:product.wholesale_unit ?? 'pack',
    caseSize:product.units_per_case ?? 1,
  }
}
function validWholesaleQuantity(product:Product,quantity:number) {
  const {moq,step}=productRules(product)
  return quantity>=moq && (quantity-moq)%step===0 && quantity<=product.stock
}

export function Modal({open,onClose,title,children,wide=false}:{open:boolean;onClose:()=>void;title:string;children:ReactNode;wide?:boolean}) {
  const ref=useRef<HTMLDialogElement>(null)
  const titleId=useId()
  useEffect(()=>{const d=ref.current;if(open&&!d?.open)d?.showModal();else if(!open&&d?.open)d.close()},[open])
  return <dialog ref={ref} aria-labelledby={titleId} className={`modal ${wide?'wide':''}`} onCancel={onClose} onClick={e=>{if(e.target===e.currentTarget)onClose()}}>
    <div className="modal-inner"><div className="modal-heading"><h2 id={titleId}>{title}</h2><button className="icon-button" onClick={onClose} aria-label="Close dialog"><X/></button></div>{children}</div>
  </dialog>
}
export function ProductIcon({product,large=false}:{product:Product;large?:boolean}) {
  const Icon=categoryIcons[product.category]||Package
  return <div className={`product-art art-${categories.indexOf(product.category)} ${large?'large':''}`}><Icon aria-hidden="true" weight="duotone"/><span>{product.strength||product.category}</span></div>
}

export default function App() {
  const [products,setProducts]=useState<Product[]>(()=>isDemo?readLocal('pm-demo-products',sampleProducts):[])
  const [settings,setSettings]=useState<StoreSettings>(()=>isDemo?readLocal('pm-b2b-settings',initialSettings):initialSettings)
  const [loading,setLoading]=useState(!isDemo),[error,setError]=useState(''),[notice,setNotice]=useState('')
  const [query,setQuery]=useState(''),[category,setCategory]=useState('All products'),[inStock,setInStock]=useState(false),[sort,setSort]=useState('recommended')
  const [cart,setCart]=useState<CartItem[]>(()=>readLocal('pm-b2b-cart',[]))
  const [buyerState,setBuyerState]=useState<BuyerState>(()=>readLocal('pm-b2b-buyer-state','guest'))
  const [buyer,setBuyer]=useState<BuyerProfile>(()=>readLocal('pm-b2b-buyer',demoBuyer))
  const [authenticated,setAuthenticated]=useState(isDemo),[authEmailSent,setAuthEmailSent]=useState(false),[submitting,setSubmitting]=useState(false)
  const [turnstileToken,setTurnstileToken]=useState('')
  const [turnstileNonce,setTurnstileNonce]=useState(0)
  const [applyOpen,setApplyOpen]=useState(false),[cartOpen,setCartOpen]=useState(false),[checkout,setCheckout]=useState(false)
  const [ordersOpen,setOrdersOpen]=useState(false),[buyerOrders,setBuyerOrders]=useState<Order[]>([]),[ordersLoading,setOrdersLoading]=useState(false)
  const [detail,setDetail]=useState<Product|null>(null),[confirmed,setConfirmed]=useState<{reference:string;total:number}|null>(null)
  const [fulfilment,setFulfilment]=useState('own_delivery'),[payment,setPayment]=useState('cod')
  const [admin,setAdmin]=useState(location.hash==='#admin')

  async function refresh(){setLoading(true);setError('');try{const result=await loadCatalog();setProducts(result.products);setSettings(result.settings)}catch{setError('The wholesale catalog could not be loaded.')}finally{setLoading(false)}}
  async function hydrateBuyer(){if(isDemo)return;try{const profile=await loadMyBuyer();if(profile){setBuyer({businessName:profile.legal_name,contactName:profile.contact_name,email:profile.email,phone:profile.phone,gstin:profile.gstin||'',drugLicence:profile.drug_licence_number,address:profile.registered_address,pincode:profile.pincode});setBuyerState(profile.status)}else setBuyerState('guest')}catch{setError('Your buyer account could not be loaded.')}}
  useEffect(()=>{if(!isDemo){void supabase!.auth.getSession().then(({data})=>{setAuthenticated(!!data.session);return hydrateBuyer()}).then(()=>refresh());const {data:{subscription}}=supabase!.auth.onAuthStateChange((_event,session)=>{setAuthenticated(!!session);if(!session)setCart([]);setTimeout(()=>void hydrateBuyer().then(refresh),0)});const change=()=>setAdmin(location.hash==='#admin');window.addEventListener('hashchange',change);return()=>{subscription.unsubscribe();window.removeEventListener('hashchange',change)}}const change=()=>setAdmin(location.hash==='#admin');window.addEventListener('hashchange',change);return()=>window.removeEventListener('hashchange',change)},[])
  useEffect(()=>{const methods=settings.allowed_payment_methods||['cod','bank_transfer'];if(!methods.includes(payment))setPayment(methods[0]||'')},[settings.allowed_payment_methods,payment])
  useEffect(()=>{const methods=settings.allowed_fulfilment_methods||['own_delivery','transporter','pickup'];const unavailable=methods.includes('own_delivery')&&settings.serviceable_pincodes.length>0&&!settings.serviceable_pincodes.includes(buyer.pincode);if(!methods.includes(fulfilment)||(fulfilment==='own_delivery'&&unavailable))setFulfilment(methods.find(value=>value!=='own_delivery'||!unavailable)||'')},[settings.allowed_fulfilment_methods,settings.serviceable_pincodes,buyer.pincode,fulfilment])
  useEffect(()=>{try{localStorage.setItem('pm-b2b-cart',JSON.stringify(cart))}catch{/* keep in memory */}},[cart])
  useEffect(()=>{if(!notice)return;const t=setTimeout(()=>setNotice(''),3500);return()=>clearTimeout(t)},[notice])
  function saveDemo(next:Product[]){setProducts(next);try{localStorage.setItem('pm-demo-products',JSON.stringify(next))}catch{/* keep in memory */}}
  function saveDemoSettings(next:StoreSettings){setSettings(next);try{localStorage.setItem('pm-b2b-settings',JSON.stringify(next))}catch{/* keep in memory */}}
  function setAccess(state:BuyerState,profile=buyer){setBuyerState(state);setBuyer(profile);if(isDemo)try{localStorage.setItem('pm-b2b-buyer-state',JSON.stringify(state));localStorage.setItem('pm-b2b-buyer',JSON.stringify(profile))}catch{/* keep in memory */}}
  async function leaveBuyer(){setCart([]);setConfirmed(null);if(isDemo)setAccess('guest');else await signOutBuyer()}

  const approved=buyerState==='approved'
  const filtered=useMemo(()=>{
    let list=products.filter(p=>p.active&&p.pharmacist_approved!==false&&(!inStock||p.stock>=productRules(p).moq)&&(category==='All products'||p.category===category)&&[p.name,p.composition,p.manufacturer,p.sku,p.strength].join(' ').toLowerCase().includes(query.toLowerCase().trim()))
    if(sort==='price-low')list=[...list].sort((a,b)=>a.price_paise-b.price_paise)
    if(sort==='price-high')list=[...list].sort((a,b)=>b.price_paise-a.price_paise)
    if(sort==='name')list=[...list].sort((a,b)=>a.name.localeCompare(b.name))
    return list
  },[products,inStock,category,query,sort])
  const lines=cart.flatMap(item=>{const product=products.find(p=>p.id===item.productId);return product?[{...item,product}]:[]})
  const subtotal=lines.reduce((sum,line)=>sum+line.product.price_paise*line.quantity,0)
  const itemCount=cart.reduce((sum,item)=>sum+item.quantity,0)
  const minimumShortfall=Math.max(0,settings.minimum_order_paise-subtotal)
  const deliveryUnavailable=settings.serviceable_pincodes.length>0&&!settings.serviceable_pincodes.includes(buyer.pincode)
  const deliveryFee=fulfilment==='own_delivery'?settings.delivery_fee_paise:0
  const orderTotal=subtotal+deliveryFee
  const invalidCart=!approved||minimumShortfall>0||cart.length!==lines.length||lines.some(line=>!line.product.active||!validWholesaleQuantity(line.product,line.quantity))

  function selectCategory(value:string){setCategory(value);document.getElementById('catalog')?.scrollIntoView({behavior:'smooth',block:'start'})}
  function add(product:Product){
    if(!approved){setNotice('Wholesale access is available after buyer approval.');setApplyOpen(true);return}
    const {moq}=productRules(product);if(product.stock<moq){setNotice('This item does not have enough stock for its MOQ.');return}
    setCart(old=>old.some(i=>i.productId===product.id)?old: [...old,{productId:product.id,quantity:moq}]);setNotice(`${product.name} added at its minimum wholesale quantity.`)
  }
  function changeQuantity(product:Product,direction:1|-1){
    const {moq,step}=productRules(product);const current=cart.find(i=>i.productId===product.id)?.quantity??moq
    const next=current+direction*step
    if(next<moq){setCart(old=>old.filter(i=>i.productId!==product.id));return}
    if(next>product.stock){setNotice('Available wholesale stock reached.');return}
    setCart(old=>old.map(i=>i.productId===product.id?{...i,quantity:next}:i))
  }
  async function requestSignIn(e:FormEvent<HTMLFormElement>){
    e.preventDefault();if(!turnstileSiteKey){setNotice('Security verification is not configured.');return}if(!turnstileToken){setNotice('Complete the security check first.');return}
    setSubmitting(true);try{await emailSignIn(String(new FormData(e.currentTarget).get('email')).trim(),turnstileToken);setAuthEmailSent(true)}catch{setNotice('The sign-in email could not be sent. Please retry.')}finally{setTurnstileToken('');setTurnstileNonce(value=>value+1);setSubmitting(false)}
  }
  async function submitApplication(e:FormEvent<HTMLFormElement>){
    e.preventDefault();const form=new FormData(e.currentTarget);const profile=Object.fromEntries(Object.keys(emptyBuyer).map(key=>[key,String(form.get(key)||'').trim()])) as unknown as BuyerProfile
    if(isDemo){setAccess('pending',profile);setApplyOpen(false);setNotice('Demo application saved. No information was sent to the wholesaler.');return}
    if(!turnstileSiteKey){setNotice('Security verification is not configured.');return}if(!turnstileToken){setNotice('Complete the security check first.');return}
    setSubmitting(true);try{await submitBuyerApplication(profile as unknown as Record<string,string>,turnstileToken);setAccess('pending',profile);setApplyOpen(false);setNotice('Application submitted for staff verification.')}catch(err){setNotice(err instanceof Error?err.message:'Application could not be submitted.')}finally{setTurnstileToken('');setTurnstileNonce(value=>value+1);setSubmitting(false)}
  }
  async function placeOrder(e:FormEvent){
    e.preventDefault();if(invalidCart)return
    setSubmitting(true);try{if(isDemo)setConfirmed({reference:`B2B-DEMO-${crypto.randomUUID().slice(0,8).toUpperCase()}`,total:orderTotal});else{const result=await submitB2BOrder(cart,payment,fulfilment,crypto.randomUUID());setConfirmed({reference:result.reference,total:result.total_paise})}setCart([]);setCheckout(false)}catch(err){setNotice(err instanceof Error?err.message:'The order request could not be submitted.')}finally{setSubmitting(false)}
  }
  async function cancelOrder(id:string){
    if(!window.confirm('Cancel this pending order and release its reserved stock?'))return
    setOrdersLoading(true)
    try{
      await cancelMyPendingOrder(id)
      setBuyerOrders(await listMyOrders())
      setNotice('Pending order cancelled.')
    }catch(err){setNotice(err instanceof Error?err.message:'Cancellation failed.')}
    finally{setOrdersLoading(false)}
  }
  async function openOrders(){setOrdersOpen(true);if(isDemo)return;setOrdersLoading(true);try{setBuyerOrders(await listMyOrders())}catch{setNotice('Order history could not be loaded.')}finally{setOrdersLoading(false)}}

  return <>
    <a className="skip-link" href="#main">Skip to content</a>
    <div className="topbar"><div className="container"><span><MapPin size={14}/> Peddapalli, Telangana</span><span className="topbar-center">Pharmaceutical wholesale for verified medical stores</span><span><ShieldCheck size={14}/> Verified buyers only</span></div></div>
    <header className={admin?'staff-mode':''}><div className="container header-row">
      <a className="brand" href="#" aria-label="Pedapalli Medical Wholesale home"><span className="brand-mark"><Cross size={27} weight="fill"/></span><span><strong>{settings.store_name}</strong><small>Wholesale partner portal</small></span></a>
      <form className="search" onSubmit={e=>{e.preventDefault();location.hash='';selectCategory(category)}}><label className="sr-only" htmlFor="search">Search wholesale medicines</label><input id="search" type="search" placeholder="Search medicines or SKU" value={query} onChange={e=>setQuery(e.target.value)}/><button aria-label="Search products"><MagnifyingGlass size={20}/></button></form>
      <div className="header-actions">{approved?<button className="buyer-chip" aria-label={`Sign out ${buyer.businessName}`} onClick={()=>void leaveBuyer()}><Storefront size={21}/><span><small>Sign out buyer</small>{buyer.businessName}</span><b>Sign out</b></button>:<button className="staff-link" aria-label={buyerState==='pending'?'Approval pending':'Buyer sign in'} onClick={()=>setApplyOpen(true)}><UserCircle size={21}/><span>{buyerState==='pending'?'Approval pending':'Buyer sign in'}</span></button>}<button className="cart-trigger" disabled={!approved} aria-label={`Open wholesale cart with ${itemCount} units`} onClick={()=>{setCartOpen(true);setConfirmed(null)}}><span className="cart-icon"><ShoppingBag size={24}/>{itemCount>0&&<b>{itemCount}</b>}</span><span aria-hidden="true">Wholesale cart<strong>{approved?money(subtotal):'Locked'}</strong></span></button></div>
    </div></header>
    <nav className="navigation container" aria-label="Wholesale categories"><button aria-pressed={category==='All products'} className={category==='All products'?'selected':''} onClick={()=>selectCategory('All products')}><List size={17}/> All products</button>{categories.slice(0,6).map(c=><button aria-pressed={category===c} key={c} className={category===c?'selected':''} onClick={()=>selectCategory(c)}>{c}</button>)}<a href="#admin">Staff portal</a></nav>
    <div className="demo-strip"><span>{isDemo?'B2B PREVIEW':'SECURE B2B PORTAL'}</span>{isDemo?' Sample wholesale catalog. Applications and orders are not sent to the business.':' Prices and ordering require an approved buyer account.'}</div>
    <main id="main">{admin?<Admin products={products} settings={settings} onProducts={saveDemo} onSettings={saveDemoSettings} refresh={refresh} notify={setNotice}/>:<>
      <section className="hero container b2b-hero"><div className="hero-copy"><div className="eyebrow"><span/> BUILT FOR LICENSED MEDICAL STORES</div><h1>Wholesale medicines.<br/><em>Ordered with clarity.</em></h1><p>Verified business access, case-aware quantities and dependable stock visibility—built for pharmacy procurement.</p><div className="hero-actions">{approved?<><button className="button primary" onClick={()=>selectCategory('All products')}>Browse wholesale catalog <ShoppingBag size={17}/></button><button className="button secondary" onClick={()=>void openOrders()}>My orders <ClipboardText size={17}/></button></>:<>{isDemo&&<button className="button primary" onClick={()=>setAccess('approved',demoBuyer)}>Explore approved buyer demo <Storefront size={17}/></button>}<button className={`button ${isDemo?'secondary':'primary'}`} onClick={()=>setApplyOpen(true)}>{isDemo?'Apply for access':authenticated?'Complete buyer application':'Buyer sign in / apply'}</button></>}</div><div className="hero-notes"><span><ShieldCheck size={17}/> Approved stores only</span><span><Package size={17}/> Product-specific MOQ</span><span><Truck size={17}/> Delivery, transport or pickup</span></div></div><div className="hero-panel"><img src="https://images.unsplash.com/photo-1580281658628-7f5b1a7f32c8?auto=format&fit=crop&w=1200&q=82" alt="Pharmacy shelves prepared for wholesale supply" onError={e=>{e.currentTarget.src='https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=1200&q=82'}}/><div className="hero-photo-card"><span className="hero-panel-kicker">PURCHASE WITH CONFIDENCE</span><h2>A professional ordering desk for your medical store.</h2><div className="hero-panel-tags"><span><Buildings size={16}/> Business accounts</span><span><ClipboardText size={16}/> Confirmed orders</span></div></div></div></section>

      <section className="container b2b-benefits"><article><ShieldCheck size={25}/><div><strong>Verified trade access</strong><p>Wholesale pricing stays private to approved medical stores.</p></div></article><article><Warehouse size={25}/><div><strong>Procurement-ready catalog</strong><p>MOQ, order steps, case sizes and stock in one view.</p></div></article><article><Truck size={25}/><div><strong>Flexible fulfilment</strong><p>Choose own delivery, transporter handling or pickup.</p></div></article></section>

      <section className="container categories-section"><div className="section-heading"><div><span className="eyebrow">WHOLESALE RANGE</span><h2>Shop by category</h2></div><button className="text-button" onClick={()=>selectCategory('All products')}>View all products</button></div><div className="category-list">{categories.map(c=>{const Icon=categoryIcons[c];return <button aria-pressed={category===c} key={c} className={`category ${category===c?'active':''}`} onClick={()=>selectCategory(c)}><span><Icon weight="duotone"/></span>{c}</button>})}</div></section>

      <section id="catalog" className="container catalog"><div className="section-heading catalog-heading"><div><span className="eyebrow">APPROVED WHOLESALE CATALOG</span><h2>{query?`Results for “${query}”`:category==='All products'?'Medicines and pharmacy essentials':category}</h2></div><span className="result-count">{filtered.length} products</span></div><div className="filterbar"><div className="filter-left"><SlidersHorizontal size={17}/><label className="checkbox-label"><input type="checkbox" checked={inStock} onChange={e=>setInStock(e.target.checked)}/> Orderable stock only</label></div><label className="sort"><span>Sort:</span><select value={sort} onChange={e=>setSort(e.target.value)}><option value="recommended">Featured</option><option value="price-low">Price: low to high</option><option value="price-high">Price: high to low</option><option value="name">Name: A to Z</option></select><CaretDown size={15}/></label></div>
        {loading?<div className="empty"><CircleNotch className="spin"/><h3>Loading wholesale catalog…</h3></div>:error?<div className="empty"><h3>{error}</h3><button className="button primary" onClick={()=>void refresh()}>Try again</button></div>:!filtered.length?<div className="empty catalog-empty"><MagnifyingGlass size={38}/><h3>No products match</h3><p>Try another medicine, brand, SKU or category.</p><button className="button secondary" onClick={()=>{setQuery('');setCategory('All products');setInStock(false)}}>Clear search and filters</button></div>:<div className="product-grid">{filtered.map(product=>{const rules=productRules(product);const line=cart.find(i=>i.productId===product.id);const available=product.stock>=rules.moq;return <article className={`product-card ${!available?'sold-out':''}`} key={product.id}><button className="product-image-button" onClick={()=>setDetail(product)} aria-label={`View ${product.name} wholesale details`}><ProductIcon product={product}/></button><div className="product-body"><div className="product-labels"><span>{product.manufacturer}</span><span className="rx">{product.regulatory_class||'Approved'}</span></div><button className="product-name" onClick={()=>setDetail(product)}>{product.name} {product.strength}</button><p className="pack-size">{product.pack_size} · {rules.caseSize} per case</p><div className="wholesale-rule"><span>MOQ <strong>{rules.moq}</strong></span><span>Order in <strong>{rules.step}s</strong></span></div>{approved?<><div className="mrp-line"><span>MRP {money(rules.mrp)}</span><small>per {rules.unit}</small></div><div className="price-line"><strong>{money(product.price_paise)}</strong><span className={available?'stock':'unavailable'}>{available?`${product.stock} available`:'Below MOQ'}</span></div>{line?<div className="quantity-control"><button aria-label={`Remove ${rules.step} ${product.name}`} onClick={()=>changeQuantity(product,-1)}><Minus size={16}/></button><span>{line.quantity} {rules.unit}s</span><button aria-label={`Add ${rules.step} ${product.name}`} disabled={line.quantity+rules.step>product.stock} onClick={()=>changeQuantity(product,1)}><Plus size={16}/></button></div>:<button className="add-button" disabled={!available} onClick={()=>add(product)}>{available?<><Plus size={17}/> Add MOQ to cart</>:'Wholesale stock unavailable'}</button>}</>:<button className="locked-price" onClick={()=>setApplyOpen(true)}><ShieldCheck size={16}/> Sign in to view wholesale price</button>}</div></article>})}</div>}
      </section>
      <section className="container b2b-cta"><div><span className="eyebrow">NEW TRADE CUSTOMER</span><h2>Run a licensed medical store?</h2><p>Submit your business details for wholesale access. Staff verifies every account before prices and ordering are enabled.</p></div><button className="button primary" onClick={()=>setApplyOpen(true)}>{buyerState==='pending'?'View application status':approved?'Buyer account active':'Apply for buyer access'}</button></section>
    </>}</main>

    <footer><div className="container footer-main"><div><a className="brand" href="#"><span className="brand-mark small"><Cross size={20} weight="fill"/></span><strong>{settings.store_name}</strong></a><p>B2B pharmaceutical wholesale for verified medical stores.<br/>Peddapalli, Telangana, India.</p></div><div><h3>Buyer portal</h3><button onClick={()=>setApplyOpen(true)}>Apply for access</button>{isDemo&&<button onClick={()=>setAccess('approved',demoBuyer)}>Approved buyer demo</button>}<a href="#admin">Staff portal</a></div><div className="footer-note"><h3>Trade access notice</h3><p>Catalog access and every order remain subject to business verification, product eligibility, current stock and wholesaler confirmation.</p></div></div><div className="container footer-bottom"><span>© {new Date().getFullYear()} {settings.store_name}</span><span>{isDemo?'B2B preview · Sample wholesale data':'Secure B2B buyer portal'}</span></div></footer>

    <div className={`toast ${notice?'visible':''}`} role="status" aria-live="polite">{notice&&<><CheckCircle size={18}/>{notice}</>}</div>
    <Modal open={applyOpen} onClose={()=>setApplyOpen(false)} title={buyerState==='pending'?'Application under review':'Medical store buyer access'} wide>
      {!isDemo&&!authenticated?<form onSubmit={requestSignIn}><p className="info-box">Sign in with your business email. We will send a secure one-time link; no password is required.</p><div className="form-grid"><label className="full-width">Business email<input name="email" type="email" autoComplete="email" required/></label></div>{turnstileSiteKey?<Turnstile key={turnstileNonce} siteKey={turnstileSiteKey} action="auth_signin" onToken={setTurnstileToken}/>:<p className="error-box">Security verification is unavailable. Contact the store.</p>} {authEmailSent&&<p className="application-success"><CheckCircle size={18}/> Check your email and open the secure sign-in link.</p>}<div className="form-actions"><button type="button" className="button secondary" onClick={()=>setApplyOpen(false)}>Cancel</button><button className="button primary" disabled={submitting||!turnstileToken}>{submitting?'Sending…':'Email secure sign-in link'}</button></div></form>:buyerState==='pending'?<div className="application-status"><ShieldCheck size={48} weight="duotone"/><span className="status-badge">Under review</span><h3>{buyer.businessName}</h3><p>{isDemo?'This demo application has not been sent anywhere. In production, staff will verify the drug-licence details and any GSTIN provided before unlocking wholesale prices.':'Your details were received. Staff must verify the drug-licence number and any GSTIN provided before wholesale prices and ordering are unlocked.'}</p>{isDemo&&<button className="button secondary" onClick={()=>{setAccess('guest',emptyBuyer);setApplyOpen(false)}}>Start over</button>}</div>:buyerState==='rejected'||buyerState==='suspended'?<div className="application-status"><ShieldCheck size={48}/><span className="status-badge pending">Access {buyerState}</span><h3>{buyer.businessName}</h3><p>Contact the wholesaler’s support team to review your buyer access.</p><button className="button secondary" onClick={()=>void signOutBuyer()}>Sign out</button></div>:<form onSubmit={submitApplication}><p className="info-box">{isDemo?'B2B preview: enter sample information only. Nothing is transmitted or reviewed.':'Enter the business details exactly as registered. Staff will verify them before enabling wholesale access.'}</p><div className="form-grid"><label className="full-width">Legal business name<input name="businessName" required minLength={2} maxLength={120}/></label><label>Authorized contact<input name="contactName" required minLength={2} maxLength={100}/></label><label>Business email<input name="email" type="email" required/></label><label>Mobile number<input name="phone" inputMode="tel" required pattern="[6-9][0-9]{9}" maxLength={10}/></label><label>GSTIN (optional)<input name="gstin" pattern="[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]" maxLength={15} autoCapitalize="characters" title="Enter a valid 15-character GSTIN or leave this field blank"/></label><label>Drug licence number<input name="drugLicence" required minLength={5} maxLength={60}/></label><label className="full-width">Registered business address<textarea name="address" required minLength={10} maxLength={400}/></label><label>PIN code<input name="pincode" inputMode="numeric" required pattern="[1-9][0-9]{5}" maxLength={6}/></label></div>{!isDemo&&(turnstileSiteKey?<Turnstile key={turnstileNonce} siteKey={turnstileSiteKey} action="buyer_application" onToken={setTurnstileToken}/>:<p className="error-box">Security verification is unavailable. Contact the store.</p>)}<div className="form-actions"><button type="button" className="button secondary" onClick={()=>setApplyOpen(false)}>Cancel</button><button className="button primary" disabled={submitting||Boolean(!isDemo&&!turnstileToken)}>{submitting?'Submitting…':'Submit for verification'}</button></div></form>}
      {!isDemo&&authenticated&&buyerState==='pending'&&<button className="button secondary center" onClick={()=>void leaveBuyer()}>Sign out</button>}
    </Modal>
    <Modal open={!!detail} onClose={()=>setDetail(null)} title="Wholesale product details">{detail&&<div className="product-detail"><ProductIcon product={detail} large/><span className="eyebrow">{detail.category} · {detail.regulatory_class||'Approved catalog'}</span><h3>{detail.name} {detail.strength}</h3><p>{detail.pack_size} · {detail.manufacturer}</p><dl><div><dt>Composition</dt><dd>{detail.composition||'Not provided'}</dd></div><div><dt>Wholesale unit</dt><dd>{productRules(detail).unit}</dd></div><div><dt>Units per case</dt><dd>{productRules(detail).caseSize}</dd></div><div><dt>MOQ / quantity step</dt><dd>{productRules(detail).moq} / {productRules(detail).step}</dd></div><div><dt>Availability</dt><dd>{detail.stock>=productRules(detail).moq?'MOQ available':'Wholesale stock unavailable'}</dd></div></dl>{approved?<div className="detail-bottom"><span><small>Wholesale price</small><strong>{money(detail.price_paise)}</strong></span><button className="button primary" disabled={detail.stock<productRules(detail).moq} onClick={()=>add(detail)}>Add MOQ to cart</button></div>:<button className="button primary full-width" onClick={()=>{setDetail(null);setApplyOpen(true)}}>Sign in for wholesale pricing</button>}</div>}</Modal>
    <Modal open={ordersOpen} onClose={()=>setOrdersOpen(false)} title="My wholesale orders" wide>{ordersLoading?<div className="empty"><CircleNotch className="spin"/><p>Loading orders…</p></div>:!buyerOrders.length?<div className="empty"><ClipboardText size={42}/><h3>No submitted orders yet</h3><p>{isDemo?'Demo orders are not stored.':'Your submitted order requests will appear here.'}</p></div>:<div className="order-history">{buyerOrders.map(order=><article key={order.id}><div className="section-heading"><div><strong>{order.reference}</strong><small>{new Date(order.created_at).toLocaleString('en-IN')}</small></div><span className="status-badge">{order.status.replaceAll('_',' ')}</span></div><div className="order-history-lines">{order.order_items.map((item,index)=><span key={index}>{item.quantity} × {item.name} · {item.pack_size}</span>)}</div><div className="section-heading"><span className="muted">Subject to wholesaler confirmation</span>{order.status==='pending'&&<button type="button" className="button secondary" onClick={()=>void cancelOrder(order.id)}>Cancel pending order</button>}<strong>{money(order.total_paise)}</strong></div></article>)}</div>}</Modal>
    <Modal open={cartOpen} onClose={()=>{setCartOpen(false);setCheckout(false)}} title={confirmed?(isDemo?'Demo order simulation':'Order request submitted'):checkout?'Review wholesale order':`Wholesale cart (${itemCount})`} wide={checkout}>
      {confirmed?<div className="confirmation"><span className="success-icon"><Check size={32}/></span><h3>{isDemo?'Demo order request simulated':'Order request received'}</h3><p>{isDemo?'This simulation was not sent or saved. A production order would now await staff confirmation.':settings.order_confirmation_notice||'Awaiting wholesaler confirmation.'}</p><div className="reference"><small>{isDemo?'Demo reference':'Order reference'}</small><strong>{confirmed.reference}</strong><span>{money(confirmed.total)}</span></div><button className="button primary" onClick={()=>setCartOpen(false)}>Continue browsing</button></div>:!lines.length?<div className="empty"><ShoppingBag size={40}/><h3>Your wholesale cart is empty</h3><p>Add products in their valid minimum quantities.</p><button className="button primary" onClick={()=>setCartOpen(false)}>Browse catalog</button></div>:checkout?<form onSubmit={placeOrder}><button type="button" className="text-button" onClick={()=>setCheckout(false)}><ArrowLeft size={15}/> Back to cart</button><div className="checkout-layout"><div><div className="buyer-summary"><Storefront size={24}/><div><small>Ordering as verified buyer</small><strong>{buyer.businessName}</strong><span>{buyer.gstin?`GSTIN ${buyer.gstin} · `:''}Drug licence {buyer.drugLicence}</span><span>{buyer.address} · {buyer.pincode}</span></div></div><h3>Fulfilment</h3><div className="choice-grid">{[['own_delivery','Wholesaler delivery'],['transporter','Transporter delivery'],['pickup','Store pickup']].filter(([value])=>(settings.allowed_fulfilment_methods||['own_delivery','transporter','pickup']).includes(value)).map(([value,label])=>{const unavailable=value==='own_delivery'&&deliveryUnavailable;return <label className={`${fulfilment===value?'selected':''} ${unavailable?'unavailable-choice':''}`} key={value}><input type="radio" name="fulfilment" value={value} checked={fulfilment===value} disabled={unavailable} onChange={()=>setFulfilment(value)}/><Truck size={20}/><span>{label}{unavailable&&<small>Not available for PIN {buyer.pincode}</small>}</span></label>})}</div><h3>Payment</h3><div className="choice-grid two">{[['cod','Cash on delivery'],['bank_transfer','Bank transfer']].filter(([value])=>(settings.allowed_payment_methods||['cod','bank_transfer']).includes(value)).map(([value,label])=><label className={payment===value?'selected':''} key={value}><input type="radio" name="payment" value={value} checked={payment===value} onChange={()=>setPayment(value)}/><ClipboardText size={20}/><span>{label}</span></label>)}</div><p className="info-box">Availability and acceptance are confirmed by the wholesaler. {isDemo&&'This preview does not create a real order.'}</p></div><aside className="checkout-summary"><h3>Order summary</h3>{lines.map(line=><div className="summary-item" key={line.productId}><span>{line.product.name}<small>{line.quantity} × {money(line.product.price_paise)}</small></span><strong>{money(line.quantity*line.product.price_paise)}</strong></div>)}<div className="total-row"><span>Product subtotal</span><strong>{money(subtotal)}</strong></div>{fulfilment==='own_delivery'&&<div className="total-row"><span>Delivery charge</span><strong>{money(deliveryFee)}</strong></div>}<div className="total-row grand-total"><strong>Estimated order total</strong><strong>{money(orderTotal)}</strong></div><p className="muted">Tax presentation follows the wholesaler’s confirmed billing workflow.</p><button className="button primary full-width" disabled={invalidCart||submitting||(!isDemo&&!settings.checkout_enabled)}>{submitting?'Submitting…':isDemo?'Submit demo order request':'Submit order request'}</button>{!isDemo&&!settings.checkout_enabled&&<p className="error-box">Online ordering is temporarily disabled by staff.</p>}</aside></div></form>:<><div className="cart-lines">{lines.map(line=>{const rules=productRules(line.product);return <div className="cart-line" key={line.productId}><ProductIcon product={line.product}/><div className="cart-line-info"><strong>{line.product.name} {line.product.strength}</strong><small>MOQ {rules.moq} · order in {rules.step}s</small><span>{money(line.product.price_paise)} per {rules.unit}</span><div className="quantity-control compact"><button onClick={()=>changeQuantity(line.product,-1)} aria-label={`Decrease ${line.product.name}`}><Minus size={14}/></button><span>{line.quantity}</span><button disabled={line.quantity+rules.step>line.product.stock} onClick={()=>changeQuantity(line.product,1)} aria-label={`Increase ${line.product.name}`}><Plus size={14}/></button></div></div><button className="icon-button" onClick={()=>setCart(old=>old.filter(i=>i.productId!==line.productId))} aria-label={`Remove ${line.product.name}`}><Trash size={17}/></button></div>})}</div><div className="total-row grand-total"><strong>Product subtotal</strong><strong>{money(subtotal)}</strong></div>{minimumShortfall>0&&<p className="error-box">Add {money(minimumShortfall)} more to meet the minimum order value.</p>}<button className="button primary full-width" disabled={invalidCart} onClick={()=>setCheckout(true)}>Review order request</button><button className="text-button center" onClick={()=>setCartOpen(false)}>Continue browsing</button></>}
    </Modal>
  </>
}
