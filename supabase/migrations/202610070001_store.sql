-- Apply to a fresh Supabase project. All monetary amounts are integer paise.
create extension if not exists pgcrypto with schema extensions;

create table public.staff_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'staff' check (role in ('owner','staff'))
);
create or replace function public.is_staff() returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists(select 1 from public.staff_members where user_id = auth.uid());
$$;

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique check (sku ~ '^[A-Z0-9][A-Z0-9_-]{0,39}$'),
  name text not null check (length(name) between 1 and 160),
  composition text not null default '' check (length(composition) <= 160),
  strength text not null default '' check (length(strength) <= 160),
  pack_size text not null check (length(pack_size) between 1 and 160),
  manufacturer text not null check (length(manufacturer) between 1 and 160),
  category text not null check (category in ('Medicines','First aid','Personal care','Baby care','Health devices','Nutrition','Ayurveda')),
  price_paise integer not null check (price_paise between 1 and 99999999),
  stock integer not null default 0 check (stock between 0 and 999999),
  prescription_required boolean not null default true,
  active boolean not null default true,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.store_settings (
  id integer primary key default 1 check (id = 1),
  store_name text not null default 'Petapali Medical' check (length(store_name) between 2 and 80),
  checkout_enabled boolean not null default false,
  serviceable_pincodes text[] not null default '{}',
  delivery_fee_paise integer not null default 0 check (delivery_fee_paise between 0 and 99999999),
  minimum_order_paise integer not null default 0 check (minimum_order_paise between 0 and 99999999)
);
insert into public.store_settings (id) values (1);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique default ('PM-' || upper(encode(extensions.gen_random_bytes(8),'hex'))),
  idempotency_key uuid not null unique,
  request_hash text not null,
  customer_name text not null,
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  address text not null,
  locality text not null,
  pincode text not null check (pincode ~ '^[1-9][0-9]{5}$'),
  payment_method text not null default 'cod' check (payment_method = 'cod'),
  subtotal_paise bigint not null check (subtotal_paise > 0),
  delivery_fee_paise integer not null check (delivery_fee_paise >= 0),
  total_paise bigint not null check (total_paise = subtotal_paise + delivery_fee_paise),
  status text not null default 'pending' check (status in ('pending','accepted','out_for_delivery','completed','cancelled')),
  prescription_verified_at timestamptz,
  prescription_verified_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  product_id uuid not null references public.products(id),
  sku text not null,
  name text not null,
  pack_size text not null,
  unit_price_paise integer not null,
  quantity integer not null check (quantity between 1 and 99),
  prescription_required boolean not null,
  unique (order_id,product_id)
);
create table public.inventory_events (
  id bigint generated always as identity primary key,
  product_id uuid not null references public.products(id),
  quantity_delta integer not null,
  reason text not null,
  order_id uuid references public.orders(id),
  actor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index orders_created_idx on public.orders(created_at desc);
create index order_items_order_idx on public.order_items(order_id);
create index inventory_product_idx on public.inventory_events(product_id,created_at desc);

alter table public.staff_members enable row level security;
alter table public.products enable row level security;
alter table public.store_settings enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.inventory_events enable row level security;
create policy staff_self on public.staff_members for select to authenticated using (user_id = auth.uid());
create policy catalog_read on public.products for select to anon, authenticated using (active or public.is_staff());
create policy settings_read on public.store_settings for select to anon, authenticated using (true);
create policy settings_staff_update on public.store_settings for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy orders_staff_read on public.orders for select to authenticated using (public.is_staff());
create policy items_staff_read on public.order_items for select to authenticated using (public.is_staff());
create policy events_staff_read on public.inventory_events for select to authenticated using (public.is_staff());
-- Do not grant direct inventory/order writes; mutations go through checked RPCs.
revoke all on public.staff_members, public.products, public.orders, public.order_items, public.inventory_events, public.store_settings from anon, authenticated;
grant select on public.products, public.store_settings to anon, authenticated;
grant select on public.staff_members, public.orders, public.order_items, public.inventory_events to authenticated;
grant update on public.store_settings to authenticated;
revoke all on function public.is_staff() from public;
grant execute on function public.is_staff() to anon, authenticated;

create or replace function public.upsert_inventory(changes jsonb) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare c jsonb; old public.products%rowtype; saved_id uuid; new_stock integer;
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  if jsonb_typeof(changes) <> 'array' or jsonb_array_length(changes) not between 1 and 500 then raise exception 'Expected 1–500 product changes'; end if;
  if (select count(*) from jsonb_array_elements(changes)) <> (select count(distinct upper(value->>'sku')) from jsonb_array_elements(changes)) then raise exception 'Duplicate SKU in import'; end if;
  -- Serialize inventory imports. Checkout still uses independent per-product locks.
  perform pg_advisory_xact_lock(72421001);
  -- Use the same product-ID lock order as checkout and cancellation.
  perform id from public.products where sku in (select upper(value->>'sku') from jsonb_array_elements(changes)) order by id for update;
  for c in select value from jsonb_array_elements(changes) order by value->>'sku' loop
    if jsonb_typeof(c->'stock') <> 'number' or (c->>'stock') !~ '^[0-9]+$'
      or jsonb_typeof(c->'price_paise') <> 'number' or (c->>'price_paise') !~ '^[0-9]+$'
      or jsonb_typeof(c->'active') <> 'boolean' or jsonb_typeof(c->'prescription_required') <> 'boolean'
      or jsonb_typeof(c->'version') <> 'number' then raise exception 'Invalid product values'; end if;
    select * into old from public.products where sku = upper(c->>'sku');
    new_stock := (c->>'stock')::integer;
    if found then
      if old.version <> (c->>'version')::integer then raise exception 'Stock or product changed for %. Reload and retry.', old.sku; end if;
      update public.products set name=trim(c->>'name'),composition=coalesce(c->>'composition',''),strength=coalesce(c->>'strength',''),
        pack_size=trim(c->>'pack_size'),manufacturer=trim(c->>'manufacturer'),category=c->>'category',price_paise=(c->>'price_paise')::integer,
        stock=new_stock,prescription_required=(c->>'prescription_required')::boolean,active=(c->>'active')::boolean,
        version=version+1,updated_at=now() where id=old.id returning id into saved_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,actor_id) values(saved_id,new_stock-old.stock,'staff_adjustment',auth.uid());
    else
      if (c->>'version')::integer <> 0 then raise exception 'Product no longer exists; reload inventory'; end if;
      insert into public.products(sku,name,composition,strength,pack_size,manufacturer,category,price_paise,stock,prescription_required,active)
      values(upper(c->>'sku'),trim(c->>'name'),coalesce(c->>'composition',''),coalesce(c->>'strength',''),trim(c->>'pack_size'),trim(c->>'manufacturer'),c->>'category',
        (c->>'price_paise')::integer,new_stock,(c->>'prescription_required')::boolean,(c->>'active')::boolean) returning id into saved_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,actor_id) values(saved_id,new_stock,'initial_inventory',auth.uid());
    end if;
  end loop;
end;
$$;
revoke all on function public.upsert_inventory(jsonb) from public;
grant execute on function public.upsert_inventory(jsonb) to authenticated;

create or replace function public.create_cod_order(customer jsonb, items jsonb, idempotency_key uuid) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare s public.store_settings%rowtype; existing public.orders%rowtype; p public.products%rowtype;
  item jsonb; units integer; subtotal bigint := 0; created public.orders%rowtype; fingerprint text;
begin
  if customer is null or jsonb_typeof(customer) <> 'object' or items is null or jsonb_typeof(items) <> 'array' or idempotency_key is null then raise exception 'Invalid request'; end if;
  if jsonb_array_length(items) not between 1 and 50 then raise exception 'Expected 1–50 cart items'; end if;
  if coalesce(length(trim(customer->>'name')),0) not between 2 and 100
    or coalesce(customer->>'phone','') !~ '^[6-9][0-9]{9}$'
    or coalesce(length(trim(customer->>'address')),0) not between 10 and 400
    or coalesce(length(trim(customer->>'locality')),0) not between 2 and 100
    or coalesce(customer->>'pincode','') !~ '^[1-9][0-9]{5}$' then raise exception 'Invalid delivery details'; end if;
  fingerprint := encode(extensions.digest(jsonb_build_object('customer',customer,'items',items)::text,'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(idempotency_key::text,0));
  select * into existing from public.orders o where o.idempotency_key=create_cod_order.idempotency_key;
  if found then
    if existing.request_hash <> fingerprint then raise exception 'This request ID was already used for a different order'; end if;
    return jsonb_build_object('reference',existing.reference,'total_paise',existing.total_paise);
  end if;
  select * into s from public.store_settings where id=1 for share;
  if not found or not s.checkout_enabled then raise exception 'The store is not accepting online orders'; end if;
  if not ((customer->>'pincode') = any(s.serviceable_pincodes)) then raise exception 'Delivery is not available for this PIN code'; end if;
  if jsonb_array_length(items) <> (select count(distinct value->>'product_id') from jsonb_array_elements(items)) then raise exception 'Duplicate or missing product IDs'; end if;
  for item in select value from jsonb_array_elements(items) loop
    if jsonb_typeof(item->'quantity') <> 'number' or coalesce(item->>'quantity','') !~ '^[0-9]+$' or (item->>'quantity')::integer not between 1 and 99 then raise exception 'Invalid quantity'; end if;
    perform (item->>'product_id')::uuid;
  end loop;
  perform id from public.products where id in (select (value->>'product_id')::uuid from jsonb_array_elements(items)) order by id for update;
  for item in select value from jsonb_array_elements(items) loop
    select * into p from public.products where id=(item->>'product_id')::uuid;
    units := (item->>'quantity')::integer;
    if not found or not p.active or p.stock < units then raise exception 'A cart item is unavailable. Refresh your cart.'; end if;
    subtotal := subtotal + p.price_paise::bigint * units;
  end loop;
  if subtotal < s.minimum_order_paise then raise exception 'Minimum order value has not been met'; end if;
  insert into public.orders(idempotency_key,request_hash,customer_name,phone,address,locality,pincode,subtotal_paise,delivery_fee_paise,total_paise)
  values(idempotency_key,fingerprint,trim(customer->>'name'),customer->>'phone',trim(customer->>'address'),trim(customer->>'locality'),customer->>'pincode',subtotal,s.delivery_fee_paise,subtotal+s.delivery_fee_paise)
  returning * into created;
  for item in select value from jsonb_array_elements(items) loop
    select * into p from public.products where id=(item->>'product_id')::uuid;
    units := (item->>'quantity')::integer;
    insert into public.order_items(order_id,product_id,sku,name,pack_size,unit_price_paise,quantity,prescription_required)
    values(created.id,p.id,p.sku,concat_ws(' ',p.name,nullif(p.strength,'')),p.pack_size,p.price_paise,units,p.prescription_required);
    update public.products set stock=stock-units,version=version+1,updated_at=now() where id=p.id;
    insert into public.inventory_events(product_id,quantity_delta,reason,order_id) values(p.id,-units,'order_reserved',created.id);
  end loop;
  return jsonb_build_object('reference',created.reference,'total_paise',created.total_paise);
end;
$$;
revoke all on function public.create_cod_order(jsonb,jsonb,uuid) from public, anon, authenticated;
grant execute on function public.create_cod_order(jsonb,jsonb,uuid) to service_role;

create or replace function public.transition_order(order_id uuid, next_status text, verify_prescription boolean default false) returns void
language plpgsql security definer set search_path = public, pg_temp as $$
declare current_order public.orders%rowtype; item public.order_items%rowtype;
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  select * into current_order from public.orders o where o.id=transition_order.order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if next_status not in ('accepted','out_for_delivery','completed','cancelled') then raise exception 'Invalid status'; end if;
  if verify_prescription then
    if current_order.status <> 'accepted' or next_status <> 'accepted' then raise exception 'Accept the order before recording prescription verification'; end if;
    update public.orders set prescription_verified_at=coalesce(prescription_verified_at,now()),prescription_verified_by=coalesce(prescription_verified_by,auth.uid()),updated_at=now() where id=transition_order.order_id;
    return;
  end if;
  if current_order.status=next_status then return; end if;
  if not ((current_order.status='pending' and next_status in ('accepted','cancelled'))
    or (current_order.status='accepted' and next_status in ('out_for_delivery','cancelled'))
    or (current_order.status='out_for_delivery' and next_status='completed')) then raise exception 'This order transition is not allowed'; end if;
  if next_status='out_for_delivery' and current_order.prescription_verified_at is null
    and exists(select 1 from public.order_items oi where oi.order_id=transition_order.order_id and prescription_required) then raise exception 'Verify required prescriptions before dispensing'; end if;
  if next_status='cancelled' then
    perform id from public.products where id in (select product_id from public.order_items oi where oi.order_id=transition_order.order_id) order by id for update;
    for item in select * from public.order_items oi where oi.order_id=transition_order.order_id order by product_id loop
      update public.products set stock=stock+item.quantity,version=version+1,updated_at=now() where id=item.product_id;
      insert into public.inventory_events(product_id,quantity_delta,reason,order_id,actor_id) values(item.product_id,item.quantity,'order_cancelled',current_order.id,auth.uid());
    end loop;
  end if;
  update public.orders set status=next_status,updated_at=now() where id=transition_order.order_id;
end;
$$;
revoke all on function public.transition_order(uuid,text,boolean) from public;
grant execute on function public.transition_order(uuid,text,boolean) to authenticated;
