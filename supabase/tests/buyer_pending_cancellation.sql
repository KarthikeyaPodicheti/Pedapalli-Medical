\set ON_ERROR_STOP on
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
do $$
declare target uuid; before_stock integer;
begin
 select id into target from public.orders where idempotency_key='aaaaaaaa-1111-4111-8111-111111111111';
 select stock into before_stock from public.products where sku='TEST-1';
 perform public.cancel_my_pending_order(target);
 if (select stock from public.products where sku='TEST-1')<>before_stock+5 then
  raise exception 'Buyer cancellation failed to restore stock'; end if;
 perform public.cancel_my_pending_order(target);
 if (select stock from public.products where sku='TEST-1')<>before_stock+5 then
  raise exception 'Repeated buyer cancellation restored stock twice'; end if;
 if (select status from public.orders where id=target)<>'cancelled' then
  raise exception 'Buyer cancellation did not update status'; end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$
begin
 begin
  perform public.cancel_my_pending_order((select id from public.orders
    where idempotency_key='aaaaaaaa-1111-4111-8111-111111111111'));
  raise exception 'Other buyer could cancel an order';
 exception when others then
  if sqlerrm='Other buyer could cancel an order' then raise; end if;
 end;
end $$;
reset role;
select 'Buyer cancellation checks passed';
