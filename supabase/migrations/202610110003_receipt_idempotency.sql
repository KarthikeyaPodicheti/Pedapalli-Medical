-- Every receipt identity is unique for a product, batch and expiry.
-- Repeating the same receipt with identical details is a no-op.
-- Reusing the identity with different quantities/details is rejected.
create table public.inventory_receipt_keys (
  product_id uuid not null references public.products(id),
  receipt_reference text not null,
  batch_id uuid not null references public.inventory_batches(id),
  received_quantity integer not null check(received_quantity>0),
  movement_reason text not null,
  created_at timestamptz not null default now(),
  primary key(product_id,receipt_reference,batch_id)
);
alter table public.inventory_receipt_keys enable row level security;
revoke all on public.inventory_receipt_keys from public,anon,authenticated;

create or replace function public.receive_inventory_batch(
 target_product uuid,lot_number text,expires_on date,received_quantity integer,
 receipt_reference text,movement_reason text default 'Stock receipt'
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result_id uuid; prior record;
begin
 if not public.has_staff_role(array['owner','inventory']) then raise exception 'Inventory role required'; end if;
 if target_product is null or nullif(trim(lot_number),'') is null or length(trim(lot_number))>100
    or expires_on is null or expires_on<=current_date
    or received_quantity is null or received_quantity<=0 or received_quantity>999999
    or nullif(trim(receipt_reference),'') is null or length(trim(receipt_reference))>200
    or nullif(trim(movement_reason),'') is null or length(trim(movement_reason))>500
 then raise exception 'Invalid stock receipt'; end if;
 perform 1 from public.products where id=target_product for update;
 if not found then raise exception 'Unknown product'; end if;
 select k.batch_id,k.received_quantity,k.movement_reason,b.batch_number,b.expiry_date
 into prior from public.inventory_receipt_keys k
 join public.inventory_batches b on b.id=k.batch_id
 where k.product_id=target_product and k.receipt_reference=trim($5)
   and b.batch_number=trim($2) and b.expiry_date=$3;
 if found then
  if prior.received_quantity<>received_quantity or prior.movement_reason<>trim(movement_reason)
    or prior.batch_number<>trim(lot_number) or prior.expiry_date<>expires_on then
    raise exception 'Receipt reference reused with conflicting details';
  end if;
  return prior.batch_id;
 end if;
 insert into public.inventory_batches(product_id,batch_number,expiry_date,on_hand,status,supplier_reference)
 values(target_product,trim(lot_number),expires_on,received_quantity,'quarantined',trim(receipt_reference))
 on conflict(product_id,batch_number,expiry_date) do update
 set on_hand=public.inventory_batches.on_hand+excluded.on_hand,updated_at=now()
 returning id into result_id;
 insert into public.inventory_receipt_keys(product_id,receipt_reference,batch_id,received_quantity,movement_reason)
 values(target_product,trim(receipt_reference),result_id,received_quantity,trim(movement_reason));
 insert into public.batch_inventory_movements(batch_id,quantity_delta,reason,source_reference,actor_id)
 values(result_id,received_quantity,trim(movement_reason),trim(receipt_reference),auth.uid());
 return result_id;
end;
$$;
