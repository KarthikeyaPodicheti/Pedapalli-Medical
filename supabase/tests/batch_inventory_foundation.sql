\set ON_ERROR_STOP on
-- Batch inventory integration checks. Run after existing B2B fixtures and batch migration.
set role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
select public.receive_inventory_batch(
 (select id from public.products where sku='TEST-1'),
 'LOT-A', current_date + 180, 5, 'GRN-1', 'First stock receipt');
select public.receive_inventory_batch(
 (select id from public.products where sku='TEST-1'),
 'LOT-A', current_date + 180, 5, 'GRN-2', 'Second stock receipt');
do $$
begin
 if (select count(*) from public.inventory_batches where batch_number='LOT-A')<>1 then
  raise exception 'Duplicate batch created';
 end if;
 if (select on_hand from public.inventory_batches where batch_number='LOT-A')<>10 then
  raise exception 'Receipts did not add to ten';
 end if;
 if (select sellable from public.staff_batch_stock_summary() where batch_number='LOT-A')<>0 then
  raise exception 'Quarantine leaked to sellable';
 end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select public.set_inventory_batch_status(
 (select id from public.inventory_batches where batch_number='LOT-A'),
 'sellable','Owner inspected the batch');
do $$
begin
 if (select sellable from public.staff_batch_stock_summary() where batch_number='LOT-A')<>10 then
  raise exception 'Approved batch not sellable';
 end if;
end $$;
reset role;
do $$
begin
 if (select stock from public.products where sku='TEST-1')<>20 then
  raise exception 'Shadow inventory unexpectedly changed legacy stock';
 end if;
end $$;
select 'Batch inventory checks passed';
