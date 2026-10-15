\set ON_ERROR_STOP on
set role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
do $$
declare p uuid; b uuid; returned uuid; initial integer;
begin
 select id into p from public.products where sku='TEST-1';
 select id into b from public.inventory_batches where batch_number='LOT-A';
 select on_hand into initial from public.inventory_batches where id=b;
 perform public.adjust_inventory_batch(b,2,'Physical count correction','COUNT-001');
 if (select on_hand from public.inventory_batches where id=b)<>initial+2 then
  raise exception 'Audited adjustment did not change stock'; end if;
 begin
  perform public.adjust_inventory_batch(b,-999,'Attempt below reservations','COUNT-002');
  raise exception 'Invalid adjustment succeeded';
 exception when others then
  if sqlerrm='Invalid adjustment succeeded' then raise; end if;
 end;
 returned:=public.receive_quarantined_return(p,'LOT-A',current_date+180,3,
  'RETURN-001','Customer rejected sealed pack');
 if (select status from public.inventory_batches where id=returned)<>'quarantined' then
  raise exception 'Returned stock was not quarantined'; end if;
 if returned=b then raise exception 'Returned goods mixed with sellable stock'; end if;
 if not exists(select 1 from public.staff_batch_alerts(365) where batch_id=returned and alert_type='quarantined') then
  raise exception 'Quarantine alert missing'; end if;
end $$;
reset role;
select 'Batch safety checks passed';
