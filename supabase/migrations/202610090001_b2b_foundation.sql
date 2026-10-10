-- Production B2B foundation. Monetary amounts are integer paise.
-- Apply in staging first, run the acceptance tests, then apply to production.

alter table public.store_settings alter column store_name set default 'Pedapalli Medical';
update public.store_settings set store_name = 'Pedapalli Medical' where store_name = 'Petapali Medical';
alter table public.store_settings
  add column allowed_payment_methods text[] not null default array['cod','bank_transfer'],
  add column allowed_fulfilment_methods text[] not null default array['own_delivery','transporter','pickup'],
  add column reservation_minutes integer not null default 1440 check (reservation_minutes between 15 and 10080),
  add column order_confirmation_notice text not null default 'Awaiting wholesaler confirmation.' check (length(order_confirmation_notice) <= 300);

alter table public.staff_members drop constraint if exists staff_members_role_check;
alter table public.staff_members add constraint staff_members_role_check
  check (role in ('owner','sales','inventory','dispatch','pharmacist','staff'));

create table public.buyer_businesses (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null check (length(legal_name) between 2 and 120),
  contact_name text not null check (length(contact_name) between 2 and 100),
  email text not null check (length(email) between 3 and 254),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  gstin text not null unique check (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$'),
  drug_licence_number text not null unique check (length(drug_licence_number) between 5 and 60),
  registered_address text not null check (length(registered_address) between 10 and 400),
  pincode text not null check (pincode ~ '^[1-9][0-9]{5}$'),
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text check (length(review_note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.buyer_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  buyer_id uuid not null references public.buyer_businesses(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','buyer')),
  created_at timestamptz not null default now(),
  unique (buyer_id,user_id)
);

create or replace function public.current_buyer_id() returns uuid language sql stable security definer
set search_path = public, pg_temp as $$
  select buyer_id from public.buyer_users where user_id = auth.uid();
$$;
create or replace function public.is_approved_buyer() returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists(
    select 1 from public.buyer_users u join public.buyer_businesses b on b.id=u.buyer_id
    where u.user_id=auth.uid() and b.status='approved'
  );
$$;
create or replace function public.has_staff_role(allowed_roles text[]) returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists(select 1 from public.staff_members where user_id=auth.uid() and role=any(allowed_roles));
$$;

alter table public.products
  add column mrp_paise integer check (mrp_paise between 1 and 99999999),
  add column wholesale_unit text not null default 'pack' check (length(wholesale_unit) between 1 and 40),
  add column units_per_case integer not null default 1 check (units_per_case between 1 and 999999),
  add column minimum_order_quantity integer not null default 1 check (minimum_order_quantity between 1 and 999999),
  add column quantity_step integer not null default 1 check (quantity_step between 1 and 999999),
  add column regulatory_class text not null default 'Unclassified' check (length(regulatory_class) between 1 and 80),
  add column pharmacist_approved boolean not null default false,
  add column inventory_updated_at timestamptz not null default now();

create table public.inventory_imports (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  row_count integer not null check (row_count between 1 and 500),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now()
);

create or replace function public.upsert_inventory(changes jsonb) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare c jsonb; old public.products%rowtype; saved_id uuid; new_stock integer;
begin
  if not public.has_staff_role(array['owner','inventory','pharmacist']) then raise exception 'Inventory role required'; end if;
  if jsonb_typeof(changes)<>'array' or jsonb_array_length(changes) not between 1 and 500 then raise exception 'Expected 1–500 product changes'; end if;
  if (select count(*) from jsonb_array_elements(changes))<>(select count(distinct upper(value->>'sku')) from jsonb_array_elements(changes)) then raise exception 'Duplicate SKU in import'; end if;
  perform pg_advisory_xact_lock(72421001);
  insert into public.inventory_imports(actor_id,row_count,payload_sha256) values(auth.uid(),jsonb_array_length(changes),encode(extensions.digest(changes::text,'sha256'),'hex'));
  perform id from public.products where sku in (select upper(value->>'sku') from jsonb_array_elements(changes)) order by id for update;
  for c in select value from jsonb_array_elements(changes) order by value->>'sku' loop
    if jsonb_typeof(c->'stock')<>'number' or (c->>'stock')!~'^[0-9]+$'
      or jsonb_typeof(c->'price_paise')<>'number' or (c->>'price_paise')!~'^[0-9]+$'
      or jsonb_typeof(c->'mrp_paise')<>'number' or (c->>'mrp_paise')!~'^[0-9]+$'
      or coalesce(c->>'units_per_case','')!~'^[1-9][0-9]*$'
      or coalesce(c->>'minimum_order_quantity','')!~'^[1-9][0-9]*$'
      or coalesce(c->>'quantity_step','')!~'^[1-9][0-9]*$'
      or jsonb_typeof(c->'active')<>'boolean' or jsonb_typeof(c->'prescription_required')<>'boolean'
      or jsonb_typeof(c->'pharmacist_approved')<>'boolean' or jsonb_typeof(c->'version')<>'number'
    then raise exception 'Invalid wholesale product values'; end if;
    select * into old from public.products where sku=upper(c->>'sku'); new_stock:=(c->>'stock')::integer;
    if found then
      if old.version<>(c->>'version')::integer then raise exception 'Product changed for %. Reload and retry.',old.sku; end if;
      update public.products set name=trim(c->>'name'),composition=coalesce(c->>'composition',''),strength=coalesce(c->>'strength',''),pack_size=trim(c->>'pack_size'),manufacturer=trim(c->>'manufacturer'),category=c->>'category',
        price_paise=(c->>'price_paise')::integer,mrp_paise=(c->>'mrp_paise')::integer,stock=new_stock,wholesale_unit=trim(c->>'wholesale_unit'),units_per_case=(c->>'units_per_case')::integer,
        minimum_order_quantity=(c->>'minimum_order_quantity')::integer,quantity_step=(c->>'quantity_step')::integer,regulatory_class=trim(c->>'regulatory_class'),
        prescription_required=(c->>'prescription_required')::boolean,pharmacist_approved=(c->>'pharmacist_approved')::boolean,active=(c->>'active')::boolean,
        version=version+1,inventory_updated_at=now(),updated_at=now() where id=old.id returning id into saved_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,actor_id) values(saved_id,new_stock-old.stock,'staff_adjustment',auth.uid());
    else
      if (c->>'version')::integer<>0 then raise exception 'Product no longer exists; reload inventory'; end if;
      insert into public.products(sku,name,composition,strength,pack_size,manufacturer,category,price_paise,mrp_paise,stock,wholesale_unit,units_per_case,minimum_order_quantity,quantity_step,regulatory_class,prescription_required,pharmacist_approved,active)
      values(upper(c->>'sku'),trim(c->>'name'),coalesce(c->>'composition',''),coalesce(c->>'strength',''),trim(c->>'pack_size'),trim(c->>'manufacturer'),c->>'category',(c->>'price_paise')::integer,(c->>'mrp_paise')::integer,new_stock,trim(c->>'wholesale_unit'),(c->>'units_per_case')::integer,(c->>'minimum_order_quantity')::integer,(c->>'quantity_step')::integer,trim(c->>'regulatory_class'),(c->>'prescription_required')::boolean,(c->>'pharmacist_approved')::boolean,(c->>'active')::boolean) returning id into saved_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,actor_id) values(saved_id,new_stock,'initial_inventory',auth.uid());
    end if;
  end loop;
end;
$$;

alter table public.orders
  add column buyer_id uuid references public.buyer_businesses(id),
  add column fulfilment_method text check (fulfilment_method in ('own_delivery','transporter','pickup')),
  add column transporter_note text check (length(transporter_note) <= 300),
  add column reservation_expires_at timestamptz;
alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check check (payment_method in ('cod','bank_transfer'));
alter table public.order_items drop constraint if exists order_items_quantity_check;
alter table public.order_items add constraint order_items_quantity_check check (quantity between 1 and 999999);

create table public.order_status_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  previous_status text,
  next_status text not null,
  actor_id uuid references auth.users(id),
  reason text check (length(reason) <= 500),
  created_at timestamptz not null default now()
);

create table public.notification_deliveries (
  id bigint generated always as identity primary key,
  order_id uuid references public.orders(id) on delete cascade,
  buyer_id uuid references public.buyer_businesses(id) on delete cascade,
  channel text not null check (channel in ('email','whatsapp')),
  event_name text not null check (length(event_name) between 1 and 80),
  status text not null default 'pending' check (status in ('pending','processing','sent','failed')),
  attempts integer not null default 0 check (attempts between 0 and 20),
  provider_reference text,
  last_error text check (length(last_error) <= 500),
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index buyer_businesses_status_idx on public.buyer_businesses(status,created_at desc);
create index buyer_users_buyer_idx on public.buyer_users(buyer_id);
create index orders_buyer_idx on public.orders(buyer_id,created_at desc);
create index order_status_events_order_idx on public.order_status_events(order_id,created_at);
create index notification_pending_idx on public.notification_deliveries(status,created_at) where status in ('pending','failed');

alter table public.buyer_businesses enable row level security;
alter table public.buyer_users enable row level security;
alter table public.order_status_events enable row level security;
alter table public.inventory_imports enable row level security;
alter table public.notification_deliveries enable row level security;
drop policy if exists catalog_read on public.products;
drop policy if exists settings_staff_update on public.store_settings;
drop policy if exists orders_staff_read on public.orders;
drop policy if exists items_staff_read on public.order_items;
drop policy if exists events_staff_read on public.inventory_events;
create policy settings_owner_update on public.store_settings for update to authenticated using (public.has_staff_role(array['owner'])) with check (public.has_staff_role(array['owner']));
create policy orders_staff_read on public.orders for select to authenticated using (public.has_staff_role(array['owner','sales','dispatch','pharmacist']));
create policy items_staff_read on public.order_items for select to authenticated using (public.has_staff_role(array['owner','sales','dispatch','pharmacist']));
create policy events_staff_read on public.inventory_events for select to authenticated using (public.has_staff_role(array['owner','inventory','pharmacist']));
create policy catalog_staff_read on public.products for select to authenticated using (public.has_staff_role(array['owner','inventory','pharmacist']));
create policy buyer_business_read on public.buyer_businesses for select to authenticated
  using (id=public.current_buyer_id() or public.has_staff_role(array['owner','sales','pharmacist']));
create policy buyer_users_read on public.buyer_users for select to authenticated
  using (user_id=auth.uid() or public.has_staff_role(array['owner','sales']));
create policy buyer_order_read on public.orders for select to authenticated
  using (buyer_id=public.current_buyer_id());
create policy buyer_item_read on public.order_items for select to authenticated
  using (exists(select 1 from public.orders o where o.id=order_id and o.buyer_id=public.current_buyer_id()));
create policy order_events_read on public.order_status_events for select to authenticated
  using (exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=public.current_buyer_id() or public.has_staff_role(array['owner','sales','dispatch','pharmacist']))));
create policy inventory_imports_staff_read on public.inventory_imports for select to authenticated using (public.has_staff_role(array['owner','inventory','pharmacist']));
create policy notifications_staff_read on public.notification_deliveries for select to authenticated using (public.has_staff_role(array['owner','sales']));

revoke all on public.buyer_businesses,public.buyer_users,public.order_status_events,public.inventory_imports,public.notification_deliveries from anon,authenticated;
grant select on public.buyer_businesses,public.buyer_users,public.order_status_events,public.inventory_imports,public.notification_deliveries to authenticated;
revoke select on public.products from anon;
grant select on public.products to authenticated;
revoke all on function public.current_buyer_id(),public.is_approved_buyer(),public.has_staff_role(text[]) from public;
grant execute on function public.current_buyer_id(),public.is_approved_buyer(),public.has_staff_role(text[]) to authenticated;

create or replace function public.submit_buyer_application(application jsonb) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare saved_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in before applying'; end if;
  if exists(select 1 from public.buyer_users where user_id=auth.uid()) then raise exception 'This account already has a buyer application'; end if;
  if coalesce(length(trim(application->>'businessName')),0) not between 2 and 120
    or coalesce(length(trim(application->>'contactName')),0) not between 2 and 100
    or lower(coalesce(application->>'email','')) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or lower(application->>'email')<>lower(coalesce(auth.jwt()->>'email',''))
    or coalesce(application->>'phone','') !~ '^[6-9][0-9]{9}$'
    or upper(coalesce(application->>'gstin','')) !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$'
    or coalesce(length(trim(application->>'drugLicence')),0) not between 5 and 60
    or coalesce(length(trim(application->>'address')),0) not between 10 and 400
    or coalesce(application->>'pincode','') !~ '^[1-9][0-9]{5}$'
  then raise exception 'Invalid buyer application'; end if;
  insert into public.buyer_businesses(legal_name,contact_name,email,phone,gstin,drug_licence_number,registered_address,pincode)
  values(trim(application->>'businessName'),trim(application->>'contactName'),lower(trim(application->>'email')),application->>'phone',upper(application->>'gstin'),trim(application->>'drugLicence'),trim(application->>'address'),application->>'pincode')
  returning id into saved_id;
  insert into public.buyer_users(user_id,buyer_id,role) values(auth.uid(),saved_id,'owner');
  insert into public.notification_deliveries(buyer_id,channel,event_name) values(saved_id,'email','buyer_application_submitted'),(saved_id,'whatsapp','buyer_application_submitted');
  return saved_id;
exception when unique_violation then
  raise exception 'A buyer application already uses this GSTIN or drug-licence number';
end;
$$;
revoke all on function public.submit_buyer_application(jsonb) from public;
grant execute on function public.submit_buyer_application(jsonb) to authenticated;

create or replace function public.review_buyer(target_buyer uuid,next_status text,note text default null) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.has_staff_role(array['owner','sales','pharmacist']) then raise exception 'Buyer-review role required'; end if;
  if next_status not in ('approved','rejected','suspended') then raise exception 'Invalid buyer status'; end if;
  if note is not null and length(note)>500 then raise exception 'Review note is too long'; end if;
  update public.buyer_businesses set status=next_status,reviewed_by=auth.uid(),reviewed_at=now(),review_note=nullif(trim(note),'') ,updated_at=now()
  where id=target_buyer;
  if not found then raise exception 'Buyer not found'; end if;
  insert into public.notification_deliveries(buyer_id,channel,event_name) values(target_buyer,'email','buyer_'||next_status),(target_buyer,'whatsapp','buyer_'||next_status);
end;
$$;
revoke all on function public.review_buyer(uuid,text,text) from public;
grant execute on function public.review_buyer(uuid,text,text) to authenticated;

create or replace function public.get_b2b_catalog()
returns table(id uuid,sku text,name text,composition text,strength text,pack_size text,manufacturer text,category text,
  price_paise integer,stock integer,prescription_required boolean,active boolean,version integer,mrp_paise integer,
  wholesale_unit text,units_per_case integer,minimum_order_quantity integer,quantity_step integer,regulatory_class text,
  pharmacist_approved boolean,inventory_updated_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
  select p.id,p.sku,p.name,p.composition,p.strength,p.pack_size,p.manufacturer,p.category,
    case when public.is_approved_buyer() or public.is_staff() then p.price_paise else 0 end,
    case when public.is_approved_buyer() or public.is_staff() then p.stock else 0 end,
    p.prescription_required,p.active,p.version,
    case when public.is_approved_buyer() or public.is_staff() then p.mrp_paise else null end,
    p.wholesale_unit,p.units_per_case,p.minimum_order_quantity,p.quantity_step,p.regulatory_class,
    p.pharmacist_approved,p.inventory_updated_at
  from public.products p where p.active and p.pharmacist_approved order by p.name;
$$;
revoke all on function public.get_b2b_catalog() from public;
grant execute on function public.get_b2b_catalog() to anon,authenticated;

create or replace function public.create_b2b_order(items jsonb,payment text,fulfilment text,idempotency_key uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare business public.buyer_businesses%rowtype; settings public.store_settings%rowtype; product public.products%rowtype;
  item jsonb; units integer; subtotal bigint:=0; created public.orders%rowtype; fingerprint text;
begin
  select b.* into business from public.buyer_businesses b join public.buyer_users u on u.buyer_id=b.id
    where u.user_id=auth.uid() for update of b;
  if not found or business.status<>'approved' then raise exception 'Approved buyer access required'; end if;
  if items is null or jsonb_typeof(items)<>'array' or jsonb_array_length(items) not between 1 and 100 or idempotency_key is null then raise exception 'Invalid order request'; end if;
  select * into settings from public.store_settings where id=1 for share;
  if not settings.checkout_enabled then raise exception 'Online order requests are not enabled'; end if;
  if not payment=any(settings.allowed_payment_methods) or not fulfilment=any(settings.allowed_fulfilment_methods) then raise exception 'Payment or fulfilment option is unavailable'; end if;
  if fulfilment='own_delivery' and cardinality(settings.serviceable_pincodes)>0 and not business.pincode=any(settings.serviceable_pincodes) then raise exception 'Delivery is unavailable for this PIN code'; end if;
  if jsonb_array_length(items)<>(select count(distinct value->>'product_id') from jsonb_array_elements(items)) then raise exception 'Duplicate product'; end if;
  fingerprint:=encode(extensions.digest(jsonb_build_object('buyer',business.id,'items',items,'payment',payment,'fulfilment',fulfilment)::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(idempotency_key::text,0));
  select * into created from public.orders o where o.idempotency_key=create_b2b_order.idempotency_key;
  if found then
    if created.request_hash<>fingerprint or created.buyer_id<>business.id then raise exception 'Request ID already used'; end if;
    return jsonb_build_object('reference',created.reference,'total_paise',created.total_paise);
  end if;
  if (select count(*) from public.orders where buyer_id=business.id and created_at>now()-interval '1 minute')>=5 then raise exception 'Too many order requests. Please wait.'; end if;
  for item in select value from jsonb_array_elements(items) loop
    if jsonb_typeof(item->'quantity')<>'number' or coalesce(item->>'quantity','')!~'^[0-9]+$' or (item->>'quantity')::integer not between 1 and 999999 then raise exception 'Invalid quantity'; end if;
    perform (item->>'product_id')::uuid;
  end loop;
  perform id from public.products where id in (select (value->>'product_id')::uuid from jsonb_array_elements(items)) order by id for update;
  for item in select value from jsonb_array_elements(items) loop
    select * into product from public.products p where p.id=(item->>'product_id')::uuid;
    units:=(item->>'quantity')::integer;
    if not found or not product.active or not product.pharmacist_approved or product.stock<units
      or units<product.minimum_order_quantity or mod(units-product.minimum_order_quantity,product.quantity_step)<>0
    then raise exception 'A cart item is unavailable or has an invalid wholesale quantity'; end if;
    subtotal:=subtotal+product.price_paise::bigint*units;
  end loop;
  if subtotal<settings.minimum_order_paise then raise exception 'Minimum order value has not been met'; end if;
  insert into public.orders(idempotency_key,request_hash,buyer_id,customer_name,phone,address,locality,pincode,payment_method,fulfilment_method,
    subtotal_paise,delivery_fee_paise,total_paise,reservation_expires_at)
  values(idempotency_key,fingerprint,business.id,business.legal_name,business.phone,business.registered_address,'Registered business address',business.pincode,
    payment,fulfilment,subtotal,case when fulfilment='own_delivery' then settings.delivery_fee_paise else 0 end,
    subtotal+case when fulfilment='own_delivery' then settings.delivery_fee_paise else 0 end,now()+make_interval(mins=>settings.reservation_minutes)) returning * into created;
  for item in select value from jsonb_array_elements(items) loop
    select * into product from public.products p where p.id=(item->>'product_id')::uuid;
    units:=(item->>'quantity')::integer;
    insert into public.order_items(order_id,product_id,sku,name,pack_size,unit_price_paise,quantity,prescription_required)
      values(created.id,product.id,product.sku,concat_ws(' ',product.name,nullif(product.strength,'')),product.pack_size,product.price_paise,units,product.prescription_required);
    update public.products set stock=stock-units,version=version+1,inventory_updated_at=now(),updated_at=now() where id=product.id;
    insert into public.inventory_events(product_id,quantity_delta,reason,order_id) values(product.id,-units,'b2b_order_reserved',created.id);
  end loop;
  insert into public.order_status_events(order_id,previous_status,next_status,actor_id,reason) values(created.id,null,'pending',auth.uid(),'Buyer submitted order request');
  insert into public.notification_deliveries(order_id,buyer_id,channel,event_name) values(created.id,business.id,'email','order_submitted'),(created.id,business.id,'whatsapp','order_submitted');
  return jsonb_build_object('reference',created.reference,'total_paise',created.total_paise);
end;
$$;
revoke all on function public.create_b2b_order(jsonb,text,text,uuid) from public;
grant execute on function public.create_b2b_order(jsonb,text,text,uuid) to authenticated;

create or replace function public.release_expired_b2b_orders() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare expired_order public.orders%rowtype; item public.order_items%rowtype; released integer:=0;
begin
  for expired_order in select * from public.orders where status='pending' and buyer_id is not null and reservation_expires_at<now() order by id for update skip locked loop
    perform id from public.products where id in (select product_id from public.order_items oi where oi.order_id=expired_order.id) order by id for update;
    for item in select * from public.order_items oi where oi.order_id=expired_order.id order by product_id loop
      update public.products set stock=stock+item.quantity,version=version+1,inventory_updated_at=now(),updated_at=now() where id=item.product_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,order_id) values(item.product_id,item.quantity,'b2b_reservation_expired',expired_order.id);
    end loop;
    update public.orders set status='cancelled',updated_at=now() where id=expired_order.id;
    insert into public.order_status_events(order_id,previous_status,next_status,reason) values(expired_order.id,'pending','cancelled','Reservation expired before confirmation');
    released:=released+1;
  end loop;
  return released;
end;
$$;
revoke all on function public.release_expired_b2b_orders() from public,anon,authenticated;
grant execute on function public.release_expired_b2b_orders() to service_role;

create or replace function public.claim_notification_deliveries(batch_size integer default 20)
returns table(id bigint,channel text,event_name text,email text,phone text,legal_name text,order_reference text,order_status text)
language sql security definer set search_path=public,pg_temp as $$
  with claimed as (
    select n.id from public.notification_deliveries n
    where n.status in ('pending','failed') and n.attempts<5 and n.next_attempt_at<=now()
    order by n.created_at,n.id for update skip locked limit least(greatest(batch_size,1),50)
  ), updated as (
    update public.notification_deliveries n set status='processing',attempts=attempts+1,updated_at=now()
    from claimed where n.id=claimed.id returning n.*
  )
  select u.id,u.channel,u.event_name,b.email,b.phone,b.legal_name,o.reference,o.status
  from updated u join public.buyer_businesses b on b.id=u.buyer_id
  left join public.orders o on o.id=u.order_id order by u.id;
$$;
revoke all on function public.claim_notification_deliveries(integer) from public,anon,authenticated;
grant execute on function public.claim_notification_deliveries(integer) to service_role;

create or replace function public.complete_notification_delivery(delivery_id bigint,was_sent boolean,provider_ref text default null,error_message text default null) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.notification_deliveries set status=case when was_sent then 'sent' else 'failed' end,
    provider_reference=case when was_sent then left(provider_ref,200) else provider_reference end,
    last_error=case when was_sent then null else left(coalesce(error_message,'Provider request failed'),500) end,
    next_attempt_at=case when was_sent then next_attempt_at else now()+make_interval(mins=>least(60,1<<least(attempts,6))) end,
    updated_at=now() where id=delivery_id and status='processing';
  if not found then raise exception 'Notification delivery is not processing'; end if;
end;
$$;
revoke all on function public.complete_notification_delivery(bigint,boolean,text,text) from public,anon,authenticated;
grant execute on function public.complete_notification_delivery(bigint,boolean,text,text) to service_role;

create or replace function public.transition_order(order_id uuid,next_status text,verify_prescription boolean default false) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare current_order public.orders%rowtype; item public.order_items%rowtype;
begin
  if not public.has_staff_role(array['owner','sales','dispatch']) then raise exception 'Order-management role required'; end if;
  select * into current_order from public.orders o where o.id=transition_order.order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if next_status not in ('accepted','out_for_delivery','completed','cancelled') then raise exception 'Invalid status'; end if;
  if verify_prescription then
    if current_order.status<>'accepted' or next_status<>'accepted' then raise exception 'Accept the order first'; end if;
    update public.orders set prescription_verified_at=coalesce(prescription_verified_at,now()),prescription_verified_by=coalesce(prescription_verified_by,auth.uid()),updated_at=now() where id=transition_order.order_id;
    return;
  end if;
  if current_order.status=next_status then return; end if;
  if not ((current_order.status='pending' and next_status in ('accepted','cancelled')) or (current_order.status='accepted' and next_status in ('out_for_delivery','cancelled')) or (current_order.status='out_for_delivery' and next_status='completed')) then raise exception 'Order transition is not allowed'; end if;
  if next_status='cancelled' then
    perform id from public.products where id in (select product_id from public.order_items oi where oi.order_id=current_order.id) order by id for update;
    for item in select * from public.order_items oi where oi.order_id=current_order.id order by product_id loop
      update public.products set stock=stock+item.quantity,version=version+1,inventory_updated_at=now(),updated_at=now() where id=item.product_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,order_id,actor_id) values(item.product_id,item.quantity,'b2b_order_cancelled',current_order.id,auth.uid());
    end loop;
  end if;
  update public.orders set status=next_status,updated_at=now() where id=current_order.id;
  insert into public.order_status_events(order_id,previous_status,next_status,actor_id) values(current_order.id,current_order.status,next_status,auth.uid());
  if current_order.buyer_id is not null then insert into public.notification_deliveries(order_id,buyer_id,channel,event_name) values(current_order.id,current_order.buyer_id,'email','order_'||next_status),(current_order.id,current_order.buyer_id,'whatsapp','order_'||next_status); end if;
end;
$$;
