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
set role service_role;
select set_config('request.jwt.claim.role','service_role',false);
do $$
declare target uuid;
begin
 select id into target from public.orders where idempotency_key='aaaaaaaa-1111-4111-8111-111111111111';
 if public.rehearse_batch_allocation(target)<>1 then raise exception 'Expected one line allocation'; end if;
 if (select sum(quantity) from public.batch_order_allocations a
  join public.order_items i on i.id=a.order_item_id where i.order_id=target)<>5 then
  raise exception 'Shadow allocation quantity incorrect'; end if;
 if (select sellable from public.staff_batch_stock_summary() where batch_number='LOT-A')<>5 then
  raise exception 'Batch stock was not reserved'; end if;
 if public.release_rehearsed_batch_allocation(target)<>5 then
  raise exception 'First release incorrect'; end if;
 if public.release_rehearsed_batch_allocation(target)<>0 then
  raise exception 'Release was not idempotent'; end if;
 if (select sellable from public.staff_batch_stock_summary() where batch_number='LOT-A')<>10 then
  raise exception 'Released stock not restored'; end if;
end $$;
reset role;
select 'Shadow allocation rehearsal passed';
