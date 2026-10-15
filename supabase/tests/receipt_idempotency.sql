\set ON_ERROR_STOP on
set role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
do $$
declare target uuid; before_qty integer; after_qty integer; before_events integer;
begin
 select id into target from public.products where sku='TEST-1';
 select coalesce(sum(on_hand),0) into before_qty from public.inventory_batches where product_id=target;
 select count(*) into before_events from public.batch_inventory_movements;
 perform public.receive_inventory_batch(target,'RETRY-LOT',current_date+180,7,'RETRY-GRN-001','Verified delivery');
 perform public.receive_inventory_batch(target,'RETRY-LOT',current_date+180,7,'RETRY-GRN-001','Verified delivery');
 select coalesce(sum(on_hand),0) into after_qty from public.inventory_batches where product_id=target;
 if after_qty<>before_qty+7 then raise exception 'Duplicate receipt increased stock'; end if;
 if (select count(*) from public.batch_inventory_movements)<>before_events+1 then
  raise exception 'Duplicate receipt created a second movement';
 end if;
 perform public.receive_inventory_batch(target,'RETRY-LOT-B',current_date+180,4,'RETRY-GRN-001','Verified delivery');
 if (select coalesce(sum(on_hand),0) from public.inventory_batches where product_id=target)<>after_qty+4 then
  raise exception 'A second batch on the same receipt was rejected';
 end if;
 begin
  perform public.receive_inventory_batch(target,'RETRY-LOT',current_date+180,8,'RETRY-GRN-001','Verified delivery');
  raise exception 'Conflicting receipt accepted';
 exception when others then
  if sqlerrm='Conflicting receipt accepted' then raise; end if;
 end;
end $$;
reset role;
select 'Receipt idempotency checks passed';
