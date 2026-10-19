create extension if not exists pgcrypto;
create schema if not exists private;

do $$
begin
  if not exists(select 1 from pg_roles where rolname='medical_api') then
    create role medical_api login noinherit nosuperuser nocreatedb nocreaterole nobypassrls;
  end if;
end;
$$;

create table private.users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check(email=lower(email) and length(email) between 3 and 254),
  password_hash text not null,
  account_type text not null check(account_type in ('buyer','staff')),
  disabled boolean not null default false,
  created_at timestamptz not null default now()
);

create table private.sessions (
  token_hash text primary key check(token_hash ~ '^[0-9a-f]{64}$'),
  user_id uuid not null references private.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index sessions_user_idx on private.sessions(user_id);
create index sessions_expiry_idx on private.sessions(expires_at);

create table private.rate_limits (
  key text primary key,
  attempts integer not null check(attempts>=0),
  reset_at timestamptz not null
);

create table public.store_settings (
  id integer primary key check(id=1),
  store_name text not null default 'Pedapalli Medical',
  checkout_enabled boolean not null default false,
  reservation_minutes integer not null default 1440 check(reservation_minutes between 15 and 10080),
  minimum_shelf_life_days integer not null default 180 check(minimum_shelf_life_days between 0 and 1825),
  allowed_payment_methods text[] not null default array['cod','bank_transfer'],
  allowed_fulfilment_methods text[] not null default array['own_delivery','transporter','pickup'],
  updated_at timestamptz not null default now()
);
insert into public.store_settings(id) values(1);

create table public.staff_members (
  user_id uuid primary key references private.users(id) on delete cascade,
  role text not null check(role in ('owner','sales','inventory','dispatch','pharmacist')),
  can_review_buyers boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.buyer_businesses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references private.users(id) on delete cascade,
  legal_name text not null check(length(legal_name) between 2 and 120),
  contact_name text not null check(length(contact_name) between 2 and 100),
  phone text not null check(phone ~ '^[6-9][0-9]{9}$'),
  gstin text unique check(gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$'),
  drug_licence_number text not null unique check(length(drug_licence_number) between 5 and 60),
  registered_address text not null check(length(registered_address) between 10 and 400),
  pincode text not null check(pincode ~ '^[1-9][0-9]{5}$'),
  status text not null default 'pending' check(status in ('pending','approved','rejected','suspended')),
  reviewed_by uuid references private.users(id),
  reviewed_at timestamptz,
  review_note text check(review_note is null or length(review_note) between 10 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index buyer_business_status_idx on public.buyer_businesses(status,created_at desc);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique check(length(sku) between 1 and 80),
  name text not null check(length(name) between 2 and 160),
  composition text not null default '',
  strength text not null default '',
  dosage_form text not null default '',
  pack_size text not null check(length(pack_size) between 1 and 120),
  manufacturer text not null check(length(manufacturer) between 1 and 160),
  category text not null default 'Medicines',
  wholesale_unit text not null default 'pack' check(length(wholesale_unit) between 1 and 40),
  units_per_case integer not null default 1 check(units_per_case between 1 and 999999),
  minimum_order_quantity integer not null default 1 check(minimum_order_quantity between 1 and 999999),
  quantity_step integer not null default 1 check(quantity_step between 1 and 999999),
  mrp_paise integer not null check(mrp_paise between 1 and 99999999),
  price_paise integer not null check(price_paise between 1 and 99999999 and price_paise<=mrp_paise),
  regulatory_class text not null default 'Unclassified',
  prescription_required boolean not null default true,
  pharmacist_approved boolean not null default false,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.inventory_batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  batch_number text not null check(length(batch_number) between 1 and 100),
  expiry_date date not null,
  received_on date not null default current_date,
  on_hand integer not null default 0 check(on_hand>=0),
  reserved integer not null default 0 check(reserved>=0 and reserved<=on_hand),
  status text not null default 'quarantined' check(status in ('quarantined','sellable','damaged','recalled','expired','disputed')),
  supplier_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id,batch_number,expiry_date)
);
create index inventory_batches_fefo_idx on public.inventory_batches(product_id,expiry_date,id) where status='sellable';

create table public.inventory_movements (
  id bigint generated always as identity primary key,
  batch_id uuid not null references public.inventory_batches(id),
  quantity_delta integer not null default 0,
  reserved_delta integer not null default 0,
  previous_status text,
  next_status text,
  reason text not null check(length(reason) between 3 and 300),
  source_reference text not null check(length(source_reference) between 1 and 160),
  actor_id uuid references private.users(id),
  created_at timestamptz not null default now(),
  check(quantity_delta<>0 or reserved_delta<>0 or previous_status is distinct from next_status)
);
create index inventory_movements_batch_idx on public.inventory_movements(batch_id,created_at);

create table public.inventory_receipt_lines (
  id bigint generated always as identity primary key,
  source_reference text not null,
  line_key text not null,
  product_id uuid not null references public.products(id),
  batch_id uuid not null references public.inventory_batches(id),
  batch_number text not null,
  expiry_date date not null,
  quantity integer not null check(quantity>0),
  actor_id uuid not null references private.users(id),
  created_at timestamptz not null default now(),
  unique(source_reference,line_key)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  buyer_id uuid not null references public.buyer_businesses(id),
  source text not null default 'buyer_portal' check(source in ('buyer_portal','staff_phone','staff_driver','counter')),
  created_by uuid not null references private.users(id),
  status text not null default 'pending' check(status in ('pending','confirmed','picking','packed','dispatched','delivered','cancelled','expired')),
  payment_method text not null check(payment_method in ('cod','bank_transfer')),
  fulfilment_method text not null check(fulfilment_method in ('own_delivery','transporter','pickup')),
  total_paise integer not null default 0 check(total_paise>=0),
  idempotency_key uuid not null,
  reservation_expires_at timestamptz not null,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(buyer_id,idempotency_key)
);
create index orders_buyer_idx on public.orders(buyer_id,created_at desc);
create index orders_expiry_idx on public.orders(reservation_expires_at) where status='pending';

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  sku text not null,
  name text not null,
  pack_size text not null,
  wholesale_unit text not null,
  quantity integer not null check(quantity>0),
  unit_price_paise integer not null check(unit_price_paise>0),
  line_total_paise integer not null check(line_total_paise>0),
  unique(order_id,product_id)
);

create table public.order_batch_allocations (
  id bigint generated always as identity primary key,
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  batch_id uuid not null references public.inventory_batches(id),
  quantity integer not null check(quantity>0),
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique(order_item_id,batch_id)
);
create index order_allocations_batch_idx on public.order_batch_allocations(batch_id) where released_at is null;

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references private.users(id),
  event_type text not null,
  subject_type text not null,
  subject_id text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.guard_account_realm()
returns trigger language plpgsql security definer set search_path=public,private,pg_temp as $$
declare expected text;
begin
  expected:=case when tg_table_name='staff_members' then 'staff' else 'buyer' end;
  if not exists(select 1 from private.users where id=new.user_id and account_type=expected and not disabled) then
    raise exception 'Account is not eligible for % access',expected;
  end if;
  return new;
end;
$$;
create trigger guard_staff_realm before insert or update of user_id on public.staff_members
for each row execute function public.guard_account_realm();
create trigger guard_buyer_realm before insert or update of user_id on public.buyer_businesses
for each row execute function public.guard_account_realm();

create or replace function public.has_staff_role(actor uuid,allowed_roles text[])
returns boolean language sql stable security definer set search_path=public,private,pg_temp as $$
  select exists(
    select 1 from public.staff_members s join private.users u on u.id=s.user_id
    where s.user_id=actor and s.role=any(allowed_roles) and u.account_type='staff' and not u.disabled
  );
$$;

create or replace function public.review_buyer_business(actor uuid,target_buyer uuid,next_status text,note text)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
declare current_status text;
begin
  if not exists(
    select 1 from public.staff_members s join private.users u on u.id=s.user_id
    where s.user_id=actor and s.can_review_buyers and s.role=any(array['owner','sales','pharmacist'])
      and u.account_type='staff' and not u.disabled
  ) then raise exception 'Buyer review permission required'; end if;
  if next_status is null or next_status<>all(array['approved','rejected','suspended']) then raise exception 'Invalid buyer status'; end if;
  if note is null or length(trim(note)) not between 10 and 500 then raise exception 'Review note is invalid'; end if;

  select status into current_status from public.buyer_businesses where id=target_buyer for update;
  if not found then raise exception 'Buyer not found'; end if;
  update public.buyer_businesses set status=next_status,reviewed_by=actor,reviewed_at=now(),review_note=trim(note),updated_at=now()
    where id=target_buyer;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
  values(actor,'buyer.reviewed','buyer',target_buyer::text,
    jsonb_build_object('previous_status',current_status,'status',next_status,'note',trim(note)));
end;
$$;

create or replace function public.record_batch_receipt(actor uuid,source_reference text,lines jsonb)
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare line record; batch_id uuid; existing public.inventory_receipt_lines%rowtype; saved integer:=0;
begin
  if not public.has_staff_role(actor,array['owner','inventory']) then raise exception 'Inventory role required'; end if;
  if source_reference is null or length(trim(source_reference)) not between 1 and 160 then raise exception 'Receipt reference required'; end if;
  if jsonb_typeof(lines)<>'array' or jsonb_array_length(lines) not between 1 and 500 then raise exception 'Receipt must contain 1 to 500 lines'; end if;

  for line in select value,ordinality from jsonb_array_elements(lines) with ordinality loop
    if coalesce(line.value->>'line_key','')='' or coalesce(line.value->>'batch_number','')=''
      or coalesce(line.value->>'quantity','')!~ '^[1-9][0-9]*$'
      or coalesce(line.value->>'expiry_date','')!~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    then raise exception 'Invalid receipt line %',line.ordinality; end if;
    if not exists(select 1 from public.products where id=(line.value->>'product_id')::uuid) then raise exception 'Unknown product on receipt line %',line.ordinality; end if;

    select * into existing from public.inventory_receipt_lines
      where inventory_receipt_lines.source_reference=trim(record_batch_receipt.source_reference)
        and line_key=line.value->>'line_key';
    if found then
      if existing.product_id<>(line.value->>'product_id')::uuid or existing.batch_number<>trim(line.value->>'batch_number')
        or existing.expiry_date<>(line.value->>'expiry_date')::date or existing.quantity<>(line.value->>'quantity')::integer
      then raise exception 'Receipt key reused with different data: %',line.value->>'line_key'; end if;
      continue;
    end if;

    begin
      insert into public.inventory_batches(product_id,batch_number,expiry_date,on_hand,status,supplier_reference)
      values((line.value->>'product_id')::uuid,trim(line.value->>'batch_number'),(line.value->>'expiry_date')::date,
        (line.value->>'quantity')::integer,'quarantined',trim(record_batch_receipt.source_reference))
      on conflict(product_id,batch_number,expiry_date) do update
        set on_hand=inventory_batches.on_hand+excluded.on_hand,updated_at=now()
      returning id into batch_id;

      insert into public.inventory_receipt_lines(source_reference,line_key,product_id,batch_id,batch_number,expiry_date,quantity,actor_id)
      values(trim(record_batch_receipt.source_reference),line.value->>'line_key',(line.value->>'product_id')::uuid,batch_id,
        trim(line.value->>'batch_number'),(line.value->>'expiry_date')::date,(line.value->>'quantity')::integer,actor);
      insert into public.inventory_movements(batch_id,quantity_delta,reason,source_reference,actor_id)
      values(batch_id,(line.value->>'quantity')::integer,'Batch receipt',trim(record_batch_receipt.source_reference),actor);
      saved:=saved+1;
    exception when unique_violation then
      select * into existing from public.inventory_receipt_lines
        where inventory_receipt_lines.source_reference=trim(record_batch_receipt.source_reference)
          and line_key=line.value->>'line_key';
      if not found or existing.product_id<>(line.value->>'product_id')::uuid or existing.batch_number<>trim(line.value->>'batch_number')
        or existing.expiry_date<>(line.value->>'expiry_date')::date or existing.quantity<>(line.value->>'quantity')::integer
      then raise exception 'Receipt key reused with different data: %',line.value->>'line_key'; end if;
    end;
  end loop;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
  values(actor,'inventory.received','receipt',trim(source_reference),jsonb_build_object('new_lines',saved));
  return saved;
end;
$$;

create or replace function public.release_inventory_batch(actor uuid,target_batch uuid)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
declare batch public.inventory_batches%rowtype; shelf_days integer;
begin
  if not public.has_staff_role(actor,array['pharmacist']) then raise exception 'Pharmacist role required'; end if;
  select * into batch from public.inventory_batches where id=target_batch for update;
  if not found then raise exception 'Batch not found'; end if;
  if batch.status<>'quarantined' then raise exception 'Only quarantined batches can be released'; end if;
  select minimum_shelf_life_days into shelf_days from public.store_settings where id=1;
  if batch.expiry_date<current_date+shelf_days then raise exception 'Batch does not meet minimum shelf life'; end if;
  update public.inventory_batches set status='sellable',updated_at=now() where id=batch.id;
  insert into public.inventory_movements(batch_id,previous_status,next_status,reason,source_reference,actor_id)
  values(batch.id,batch.status,'sellable','Pharmacist release','batch-release:'||batch.id,actor);
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id)
  values(actor,'inventory.batch_released','batch',batch.id::text);
end;
$$;

create or replace view public.sellable_inventory as
select p.id as product_id,coalesce(sum(b.on_hand-b.reserved),0)::integer as sellable_quantity
from public.products p
left join public.inventory_batches b on b.product_id=p.id and b.status='sellable'
  and b.expiry_date>=current_date+(select minimum_shelf_life_days from public.store_settings where id=1)
group by p.id;

create or replace function public.create_batch_order(actor uuid,items jsonb,payment text,fulfilment text,request_key uuid,order_source text default 'buyer_portal')
returns table(order_id uuid,reference text,total_paise integer)
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare buyer public.buyer_businesses%rowtype; existing public.orders%rowtype; new_order public.orders%rowtype;
  line record; product public.products%rowtype; batch record; order_item uuid; remaining integer; take integer; running_total integer:=0;
  settings public.store_settings%rowtype;
begin
  select * into settings from public.store_settings where id=1;
  if not settings.checkout_enabled then raise exception 'Online ordering is disabled'; end if;
  select * into buyer from public.buyer_businesses where user_id=actor and status='approved';
  if not found then raise exception 'Approved buyer required'; end if;
  if payment is null or not(payment=any(settings.allowed_payment_methods)) then raise exception 'Payment method unavailable'; end if;
  if fulfilment is null or not(fulfilment=any(settings.allowed_fulfilment_methods)) then raise exception 'Fulfilment method unavailable'; end if;
  if request_key is null then raise exception 'Idempotency key required'; end if;
  if jsonb_typeof(items)<>'array' or jsonb_array_length(items) not between 1 and 100 then raise exception 'Order must contain 1 to 100 lines'; end if;
  if exists(select 1 from jsonb_array_elements(items) x group by x->>'product_id' having count(*)>1) then raise exception 'Duplicate product in order'; end if;

  select * into existing from public.orders where buyer_id=buyer.id and idempotency_key=request_key;
  if found then return query select existing.id,existing.reference,existing.total_paise; return; end if;

  insert into public.orders(reference,buyer_id,source,created_by,payment_method,fulfilment_method,idempotency_key,reservation_expires_at)
  values('PM-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),buyer.id,
    order_source,actor,payment,fulfilment,request_key,now()+make_interval(mins=>settings.reservation_minutes))
  returning * into new_order;

  for line in
    select value from jsonb_array_elements(items) order by value->>'product_id'
  loop
    if coalesce(line.value->>'quantity','')!~ '^[1-9][0-9]*$' then raise exception 'Invalid order quantity'; end if;
    select * into product from public.products where id=(line.value->>'product_id')::uuid for update;
    if not found or not product.active or not product.pharmacist_approved then raise exception 'Product is not orderable'; end if;
    remaining:=(line.value->>'quantity')::integer;
    if remaining<product.minimum_order_quantity or (remaining-product.minimum_order_quantity)%product.quantity_step<>0 then
      raise exception 'Quantity does not meet MOQ/step for %',product.sku;
    end if;
    insert into public.order_items(order_id,product_id,sku,name,pack_size,wholesale_unit,quantity,unit_price_paise,line_total_paise)
    values(new_order.id,product.id,product.sku,product.name,product.pack_size,product.wholesale_unit,remaining,product.price_paise,remaining*product.price_paise)
    returning id into order_item;
    running_total:=running_total+remaining*product.price_paise;

    for batch in select id,on_hand,reserved from public.inventory_batches
      where product_id=product.id and status='sellable' and expiry_date>=current_date+settings.minimum_shelf_life_days
        and on_hand>reserved order by expiry_date,id for update
    loop
      take:=least(remaining,batch.on_hand-batch.reserved);
      if take>0 then
        update public.inventory_batches set reserved=reserved+take,updated_at=now() where id=batch.id;
        insert into public.order_batch_allocations(order_item_id,batch_id,quantity) values(order_item,batch.id,take);
        insert into public.inventory_movements(batch_id,reserved_delta,reason,source_reference,actor_id)
        values(batch.id,take,'Order reservation',new_order.id::text,actor);
        remaining:=remaining-take;
      end if;
      exit when remaining=0;
    end loop;
    if remaining<>0 then raise exception 'Insufficient sellable stock for %',product.sku; end if;
  end loop;
  update public.orders set total_paise=running_total where id=new_order.id;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
  values(actor,'order.created','order',new_order.id::text,jsonb_build_object('source',order_source,'total_paise',running_total));
  return query select new_order.id,new_order.reference,running_total;
end;
$$;

create or replace function public.release_order_allocations(target_order uuid,event_reason text,actor uuid default null)
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare allocation record; released integer:=0;
begin
  for allocation in select a.id,a.batch_id,a.quantity from public.order_batch_allocations a
    join public.order_items i on i.id=a.order_item_id
    where i.order_id=target_order and a.released_at is null order by a.batch_id,a.id for update of a
  loop
    update public.inventory_batches set reserved=reserved-allocation.quantity,updated_at=now()
      where id=allocation.batch_id and reserved>=allocation.quantity;
    if not found then raise exception 'Reservation ledger mismatch'; end if;
    update public.order_batch_allocations set released_at=now() where id=allocation.id and released_at is null;
    insert into public.inventory_movements(batch_id,reserved_delta,reason,source_reference,actor_id)
    values(allocation.batch_id,-allocation.quantity,event_reason,target_order::text,actor);
    released:=released+allocation.quantity;
  end loop;
  return released;
end;
$$;

create or replace function public.cancel_my_batch_order(actor uuid,target_order uuid)
returns boolean language plpgsql security definer set search_path=public,private,pg_temp as $$
declare saved public.orders%rowtype; actor_buyer_id uuid;
begin
  select id into actor_buyer_id from public.buyer_businesses where user_id=actor;
  select * into saved from public.orders where id=target_order and orders.buyer_id=actor_buyer_id for update;
  if not found then raise exception 'Order not found'; end if;
  if saved.status='cancelled' then return false; end if;
  if saved.status<>'pending' then raise exception 'Only pending orders can be self-cancelled'; end if;
  perform public.release_order_allocations(saved.id,'Buyer cancellation',actor);
  update public.orders set status='cancelled',cancelled_at=now(),updated_at=now() where id=saved.id;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id) values(actor,'order.cancelled','order',saved.id::text);
  return true;
end;
$$;

create or replace function public.expire_pending_batch_orders()
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare saved record; expired integer:=0;
begin
  for saved in select id from public.orders where status='pending' and reservation_expires_at<=now() order by id for update skip locked loop
    perform public.release_order_allocations(saved.id,'Reservation expired',null);
    update public.orders set status='expired',cancelled_at=now(),updated_at=now() where id=saved.id and status='pending';
    if found then expired:=expired+1; end if;
  end loop;
  return expired;
end;
$$;

revoke all on schema private from public;
revoke all on all tables in schema private from public;
revoke all on all tables in schema public from public;
revoke all on all functions in schema public from public;
grant usage on schema private,public to medical_api;
grant select,insert on private.users to medical_api;
grant select,insert,delete on private.sessions to medical_api;
grant select,insert,update,delete on private.rate_limits to medical_api;
grant select on public.store_settings,public.staff_members,public.buyer_businesses,public.products,public.inventory_batches,
  public.inventory_movements,public.inventory_receipt_lines,public.orders,public.order_items,public.order_batch_allocations,public.audit_events,
  public.sellable_inventory to medical_api;
grant insert on public.buyer_businesses to medical_api;
grant usage,select on all sequences in schema public to medical_api;
grant execute on function public.has_staff_role(uuid,text[]),public.record_batch_receipt(uuid,text,jsonb),
  public.review_buyer_business(uuid,uuid,text,text),
  public.release_inventory_batch(uuid,uuid),public.create_batch_order(uuid,jsonb,text,text,uuid,text),
  public.cancel_my_batch_order(uuid,uuid),public.expire_pending_batch_orders() to medical_api;
revoke all on function public.release_order_allocations(uuid,text,uuid) from public,medical_api;
