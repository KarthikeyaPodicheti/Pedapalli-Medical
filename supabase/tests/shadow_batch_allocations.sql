\set ON_ERROR_STOP on
-- Rehearsal is separate from live checkout. The existing order is reserved in
-- products.stock, while batch reservations remain shadow-only.
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.create_b2b_order(
 jsonb_build_array(jsonb_build_object(
  'product_id',(select id from public.get_b2b_catalog() where sku='TEST-1'),'quantity',5)),
 'cod','pickup','aaaaaaaa-1111-4111-8111-111111111111');
reset role;
select set_config('test.target_order',(select id from public.orders
 where idempotency_key='aaaaaaaa-1111-4111-8111-111111111111')::text,false);
set role service_role;
select set_config('request.jwt.claim.role','service_role',false);
select public.rehearse_batch_allocation(current_setting('test.target_order')::uuid);
reset role;
do $$
declare target uuid:=current_setting('test.target_order')::uuid;
begin
 if (select sum(a.quantity) from public.batch_order_allocations a
  join public.order_items i on i.id=a.order_item_id where i.order_id=target)<>5 then
  raise exception 'Shadow allocation quantity incorrect'; end if;
 if (select on_hand-reserved from public.inventory_batches where batch_number='LOT-A')<>5 then
  raise exception 'Batch stock was not reserved'; end if;
end $$;
set role service_role;
select set_config('request.jwt.claim.role','service_role',false);
select public.release_rehearsed_batch_allocation(current_setting('test.target_order')::uuid);
select public.release_rehearsed_batch_allocation(current_setting('test.target_order')::uuid);
reset role;
do $$
begin
 if (select on_hand-reserved from public.inventory_batches where batch_number='LOT-A')<>10 then
  raise exception 'Released stock not restored'; end if;
 if (select coalesce(sum(reserved_delta),0) from public.batch_inventory_movements
     where source_reference=current_setting('test.target_order'))<>0 then
  raise exception 'Shadow allocation movement ledger did not balance'; end if;
end $$;
select 'Shadow allocation rehearsal passed';
