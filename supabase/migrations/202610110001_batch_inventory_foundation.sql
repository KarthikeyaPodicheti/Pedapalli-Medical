-- PRD FR-021/023/024/025/027: additive batch inventory foundation.
-- SHADOW MODE ONLY: existing checkout and product.stock remain authoritative until
-- batch-aware checkout, migration reconciliation and client sign-off are complete.
-- Do not enable production checkout on the strength of this migration alone.
create table public.inventory_batches (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  batch_number text not null check (length(trim(batch_number)) between 1 and 100),
  expiry_date date not null,
  received_on date not null default current_date,
  on_hand integer not null default 0 check (on_hand >= 0),
  reserved integer not null default 0 check (reserved >= 0 and reserved <= on_hand),
  status text not null default 'quarantined'
    check (status in ('quarantined','sellable','damaged','recalled','expired','disputed')),
  supplier_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id,batch_number,expiry_date)
);
create index inventory_batches_product_expiry_idx
  on public.inventory_batches(product_id,expiry_date,id);
create table public.batch_inventory_movements (
  id bigint generated always as identity primary key,
  batch_id uuid not null references public.inventory_batches(id),
  quantity_delta integer not null,
  reserved_delta integer not null default 0,
  previous_status text,
  next_status text,
  reason text not null check (length(trim(reason)) between 3 and 500),
  source_reference text,
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  check (quantity_delta <> 0 or reserved_delta <> 0 or previous_status is distinct from next_status)
);
create index batch_movements_batch_created_idx on public.batch_inventory_movements(batch_id,created_at desc);
alter table public.inventory_batches enable row level security;
alter table public.batch_inventory_movements enable row level security;
revoke all on public.inventory_batches,public.batch_inventory_movements from anon,authenticated;
grant select on public.inventory_batches,public.batch_inventory_movements to authenticated;
create policy batch_staff_read on public.inventory_batches for select to authenticated
  using (public.has_staff_role(array['owner','inventory','pharmacist']));
create policy batch_movements_staff_read on public.batch_inventory_movements for select to authenticated
  using (public.has_staff_role(array['owner','inventory','pharmacist']));
-- Newly received medicine is quarantined until an authorized release.
create or replace function public.receive_inventory_batch(
  target_product uuid, lot_number text, expires_on date, received_quantity integer,
  receipt_reference text, movement_reason text default 'Stock receipt'
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result_id uuid;
begin
  if not public.has_staff_role(array['owner','inventory']) then raise exception 'Inventory role required'; end if;
  if target_product is null or nullif(trim(lot_number),'') is null or length(trim(lot_number))>100
     or expires_on is null or expires_on<=current_date
     or received_quantity is null or received_quantity<=0 or received_quantity>999999
     or nullif(trim(receipt_reference),'') is null or length(receipt_reference)>200
     or nullif(trim(movement_reason),'') is null or length(movement_reason)>500
  then raise exception 'Invalid stock receipt'; end if;
  perform 1 from public.products where id=target_product for update;
  if not found then raise exception 'Unknown product'; end if;
  insert into public.inventory_batches(product_id,batch_number,expiry_date,on_hand,status,supplier_reference)
  values(target_product,trim(lot_number),expires_on,received_quantity,'quarantined',trim(receipt_reference))
  on conflict (product_id,batch_number,expiry_date) do update
    set on_hand=public.inventory_batches.on_hand+excluded.on_hand,updated_at=now()
  returning id into result_id;
  insert into public.batch_inventory_movements(batch_id,quantity_delta,reason,source_reference,actor_id)
  values(result_id,received_quantity,trim(movement_reason),trim(receipt_reference),auth.uid());
  return result_id;
end;
$$;
create or replace function public.set_inventory_batch_status(
  target_batch uuid, new_status text, movement_reason text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare previous public.inventory_batches%rowtype;
begin
  if not public.has_staff_role(array['owner','inventory','pharmacist']) then raise exception 'Inventory role required'; end if;
  if new_status not in ('quarantined','sellable','damaged','recalled','expired','disputed')
     or nullif(trim(movement_reason),'') is null or length(trim(movement_reason))>500
  then raise exception 'Invalid batch status change'; end if;
  select * into previous from public.inventory_batches where id=target_batch for update;
  if not found then raise exception 'Unknown batch'; end if;
  if previous.status=new_status then return; end if;
  if new_status='sellable' then
    if not public.has_staff_role(array['owner','pharmacist']) then
      raise exception 'Release to sellable requires owner or pharmacist approval';
    end if;
    if previous.expiry_date<=current_date then raise exception 'Expired batch cannot be released'; end if;
    if previous.reserved>previous.on_hand then raise exception 'Invalid batch reservation'; end if;
  end if;
  update public.inventory_batches set status=new_status,updated_at=now() where id=target_batch;
  insert into public.batch_inventory_movements(batch_id,quantity_delta,previous_status,next_status,reason,actor_id)
  values(target_batch,0,previous.status,new_status,trim(movement_reason),auth.uid());
end;
$$;
revoke all on function public.receive_inventory_batch(uuid,text,date,integer,text,text) from public,anon;
revoke all on function public.set_inventory_batch_status(uuid,text,text) from public,anon;
grant execute on function public.receive_inventory_batch(uuid,text,date,integer,text,text) to authenticated;
grant execute on function public.set_inventory_batch_status(uuid,text,text) to authenticated;
-- Separate read-only stock preview; not exposed to buyers until checkout integration.
create or replace function public.staff_batch_stock_summary()
returns table(product_id uuid,batch_id uuid,batch_number text,expiry_date date,status text,
  on_hand integer,reserved integer,sellable integer)
language sql stable security definer set search_path=public,pg_temp as $$
  select b.product_id,b.id,b.batch_number,b.expiry_date,b.status,b.on_hand,b.reserved,
    case when b.status='sellable' and b.expiry_date>current_date
      then greatest(0,b.on_hand-b.reserved) else 0 end
  from public.inventory_batches b
  where public.has_staff_role(array['owner','inventory','pharmacist']);
$$;
revoke all on function public.staff_batch_stock_summary() from public,anon;
grant execute on function public.staff_batch_stock_summary() to authenticated;
