\set ON_ERROR_STOP on

insert into public.staff_members(user_id,role) values
  ('33333333-3333-4333-8333-333333333333','owner'),
  ('44444444-4444-4444-8444-444444444444','inventory');

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select set_config('request.jwt.claim.email','owner@example.in',false);
select public.upsert_inventory(jsonb_build_array(
  jsonb_build_object(
    'id','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','sku','TEST-1','name','Test medicine','composition','Test composition',
    'strength','500 mg','pack_size','10 tablets','manufacturer','Test manufacturer','category','Medicines',
    'price_paise',1000,'mrp_paise',1200,'stock',20,'wholesale_unit','pack','units_per_case',10,
    'minimum_order_quantity',5,'quantity_step',5,'regulatory_class','General trade',
    'prescription_required',false,'pharmacist_approved',true,'active',true,'version',0
  ),
  jsonb_build_object(
    'id','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','sku','RACE-1','name','Last stock medicine','composition','Test composition',
    'strength','100 mg','pack_size','5 tablets','manufacturer','Test manufacturer','category','Medicines',
    'price_paise',500,'mrp_paise',700,'stock',5,'wholesale_unit','pack','units_per_case',5,
    'minimum_order_quantity',5,'quantity_step',5,'regulatory_class','General trade',
    'prescription_required',false,'pharmacist_approved',true,'active',true,'version',0
  )
));
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select set_config('request.jwt.claim.email','buyer1@example.in',false);
select public.submit_buyer_application(jsonb_build_object(
  'businessName','Buyer One Medical Store','contactName','Buyer One','email','buyer1@example.in','phone','9876543210',
  'gstin','36ABCDE1234F1Z5','drugLicence','TG-TEST-001','address','Market Road Peddapalli','pincode','505172'
));
do $$ begin
  if (select price_paise from public.get_b2b_catalog() where sku='TEST-1')<>0 then raise exception 'Pending buyer saw a wholesale price'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
select set_config('request.jwt.claim.email','buyer2@example.in',false);
select public.submit_buyer_application(jsonb_build_object(
  'businessName','Buyer Two Medical Store','contactName','Buyer Two','email','buyer2@example.in','phone','9876543211',
  'gstin','36ABCDE5678G1Z2','drugLicence','TG-TEST-002','address','Station Road Peddapalli','pincode','505172'
));
do $$ begin
  if (select count(*) from public.buyer_businesses where gstin='36ABCDE1234F1Z5')<>0 then raise exception 'Buyer RLS isolation failed'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',false);
do $$ begin
  begin
    perform public.review_buyer((select id from public.buyer_businesses where gstin='36ABCDE1234F1Z5'),'approved','invalid inventory approval');
    raise exception 'Inventory role unexpectedly approved a buyer';
  exception when others then
    if sqlerrm='Inventory role unexpectedly approved a buyer' then raise; end if;
  end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select public.review_buyer((select id from public.buyer_businesses where gstin='36ABCDE1234F1Z5'),'approved','verified test buyer');
select public.review_buyer((select id from public.buyer_businesses where gstin='36ABCDE5678G1Z2'),'approved','verified test buyer');
reset role;

update public.store_settings set checkout_enabled=true,serviceable_pincodes=array['505172'];

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select set_config('request.jwt.claim.email','buyer1@example.in',false);
do $$ begin
  if (select price_paise from public.get_b2b_catalog() where sku='TEST-1')<>1000 then raise exception 'Approved buyer did not see the wholesale price'; end if;
end $$;
select public.create_b2b_order(
  jsonb_build_array(jsonb_build_object('product_id',(select id from public.get_b2b_catalog() where sku='TEST-1'),'quantity',5)),
  'cod','own_delivery','55555555-5555-4555-8555-555555555555'
);
select public.create_b2b_order(
  jsonb_build_array(jsonb_build_object('product_id',(select id from public.get_b2b_catalog() where sku='TEST-1'),'quantity',5)),
  'cod','own_delivery','55555555-5555-4555-8555-555555555555'
);
do $$ begin
  if (select count(*) from public.orders where idempotency_key='55555555-5555-4555-8555-555555555555')<>1 then raise exception 'Idempotency failed'; end if;
  if (select stock from public.products where sku='TEST-1')<>15 then raise exception 'Stock was not reserved exactly once'; end if;
  begin
    perform public.create_b2b_order(
      jsonb_build_array(jsonb_build_object('product_id',(select id from public.get_b2b_catalog() where sku='TEST-1'),'quantity',6)),
      'cod','pickup','66666666-6666-4666-8666-666666666666');
    raise exception 'Invalid MOQ quantity was accepted';
  exception when others then
    if sqlerrm='Invalid MOQ quantity was accepted' then raise; end if;
  end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select public.transition_order((select id from public.orders where idempotency_key='55555555-5555-4555-8555-555555555555'),'cancelled',false);
reset role;
do $$ begin
  if (select stock from public.products where sku='TEST-1')<>20 then raise exception 'Cancellation did not restore stock'; end if;
  if (select count(*) from public.inventory_imports)<>1 then raise exception 'Inventory import audit was not created'; end if;
  if (select count(*) from public.notification_deliveries)<8 then raise exception 'Notification outbox events are missing'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
select public.create_b2b_order(
  jsonb_build_array(jsonb_build_object('product_id',(select id from public.get_b2b_catalog() where sku='TEST-1'),'quantity',5)),
  'bank_transfer','pickup','77777777-7777-4777-8777-777777777777'
);
reset role;
update public.orders set reservation_expires_at=now()-interval '1 minute' where idempotency_key='77777777-7777-4777-8777-777777777777';
set role service_role;
select public.release_expired_b2b_orders();
reset role;
do $$ begin
  if (select stock from public.products where sku='TEST-1')<>20 then raise exception 'Expiration did not restore stock'; end if;
  if (select status from public.orders where idempotency_key='77777777-7777-4777-8777-777777777777')<>'cancelled' then raise exception 'Expired order was not cancelled'; end if;
end $$;

set role service_role;
select public.complete_notification_delivery((select id from public.claim_notification_deliveries(20) limit 1),true,'provider-test-id',null);
reset role;
do $$ begin
  if (select count(*) from public.notification_deliveries where status='sent' and provider_reference='provider-test-id')<>1 then raise exception 'Notification completion failed'; end if;
end $$;

select 'B2B database integration tests passed' as result;

