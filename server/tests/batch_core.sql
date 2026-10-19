\set ON_ERROR_STOP on

insert into private.users(id,email,password_hash,account_type) values
 ('10000000-0000-4000-8000-000000000001','owner@example.in','test-hash','staff'),
 ('10000000-0000-4000-8000-000000000002','inventory@example.in','test-hash','staff'),
 ('10000000-0000-4000-8000-000000000003','pharmacist@example.in','test-hash','staff'),
 ('20000000-0000-4000-8000-000000000001','buyer1@example.in','test-hash','buyer'),
 ('20000000-0000-4000-8000-000000000002','buyer2@example.in','test-hash','buyer');
insert into public.staff_members(user_id,role,can_review_buyers) values
 ('10000000-0000-4000-8000-000000000001','owner',true),
 ('10000000-0000-4000-8000-000000000002','inventory',false),
 ('10000000-0000-4000-8000-000000000003','pharmacist',true);
insert into public.buyer_businesses(id,user_id,legal_name,contact_name,phone,drug_licence_number,registered_address,pincode,status) values
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Buyer One Medical','Buyer One','9876543210','DL-TEST-001','Market Road Peddapalli','505172','approved'),
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','Buyer Two Medical','Buyer Two','9876543211','DL-TEST-002','Station Road Peddapalli','505172','approved');
insert into public.products(id,sku,name,pack_size,manufacturer,mrp_paise,price_paise,minimum_order_quantity,quantity_step,pharmacist_approved) values
 ('40000000-0000-4000-8000-000000000001','TEST-1','Test medicine','10 tablets','Test Pharma',1200,1000,1,1,true),
 ('40000000-0000-4000-8000-000000000002','EMPTY-1','Unavailable medicine','10 tablets','Test Pharma',900,700,1,1,true),
 ('40000000-0000-4000-8000-000000000003','RACE-1','Last stock medicine','5 tablets','Test Pharma',700,500,5,5,true);

select public.review_buyer_business('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','suspended','Synthetic access review');
do $$
begin
 if (select status from public.buyer_businesses where id='30000000-0000-4000-8000-000000000002')<>'suspended' then raise exception 'Buyer review did not update status'; end if;
 if not exists(select 1 from public.audit_events where subject_id='30000000-0000-4000-8000-000000000002' and details->>'previous_status'='approved') then raise exception 'Buyer review audit missing'; end if;
 begin
  perform public.review_buyer_business('10000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','approved','Unauthorized inventory review');
  raise exception 'Staff without review permission changed buyer';
 exception when others then
  if sqlerrm='Staff without review permission changed buyer' then raise; end if;
 end;
 update public.buyer_businesses set status='approved' where id='30000000-0000-4000-8000-000000000002';
end;
$$;

select public.record_batch_receipt(
 '10000000-0000-4000-8000-000000000002','GRN-100',
 jsonb_build_array(
  jsonb_build_object('line_key','1','product_id','40000000-0000-4000-8000-000000000001','batch_number','EARLY','expiry_date',(current_date+400)::text,'quantity',5),
  jsonb_build_object('line_key','2','product_id','40000000-0000-4000-8000-000000000001','batch_number','LATE','expiry_date',(current_date+500)::text,'quantity',5),
  jsonb_build_object('line_key','3','product_id','40000000-0000-4000-8000-000000000003','batch_number','RACE','expiry_date',(current_date+500)::text,'quantity',5)
 ));

do $$
begin
 if (select sellable_quantity from public.sellable_inventory where product_id='40000000-0000-4000-8000-000000000001')<>0 then
  raise exception 'Quarantined stock became sellable';
 end if;
 if public.record_batch_receipt(
   '10000000-0000-4000-8000-000000000002','GRN-100',
   jsonb_build_array(
    jsonb_build_object('line_key','1','product_id','40000000-0000-4000-8000-000000000001','batch_number','EARLY','expiry_date',(current_date+400)::text,'quantity',5),
    jsonb_build_object('line_key','2','product_id','40000000-0000-4000-8000-000000000001','batch_number','LATE','expiry_date',(current_date+500)::text,'quantity',5),
    jsonb_build_object('line_key','3','product_id','40000000-0000-4000-8000-000000000003','batch_number','RACE','expiry_date',(current_date+500)::text,'quantity',5)
   ))<>0 then raise exception 'Receipt replay was not idempotent'; end if;
 if (select sum(on_hand) from public.inventory_batches where product_id='40000000-0000-4000-8000-000000000001')<>10 then
  raise exception 'Receipt replay duplicated stock';
 end if;
 begin
  perform public.record_batch_receipt('10000000-0000-4000-8000-000000000002','GRN-100',
   jsonb_build_array(jsonb_build_object('line_key','1','product_id','40000000-0000-4000-8000-000000000001','batch_number','EARLY','expiry_date',(current_date+400)::text,'quantity',6)));
  raise exception 'Conflicting receipt replay was accepted';
 exception when others then
  if sqlerrm='Conflicting receipt replay was accepted' then raise; end if;
 end;
 begin
  perform public.release_inventory_batch('10000000-0000-4000-8000-000000000002',
   (select id from public.inventory_batches where batch_number='EARLY'));
  raise exception 'Inventory staff released quarantined stock';
 exception when others then
  if sqlerrm='Inventory staff released quarantined stock' then raise; end if;
 end;
end;
$$;

select public.release_inventory_batch('10000000-0000-4000-8000-000000000003',id)
from public.inventory_batches order by batch_number;

do $$
begin
 if (select sellable_quantity from public.sellable_inventory where product_id='40000000-0000-4000-8000-000000000001')<>10 then
  raise exception 'Released stock did not become sellable';
 end if;
end;
$$;

update public.store_settings set checkout_enabled=true where id=1;

select * from public.create_batch_order(
 '20000000-0000-4000-8000-000000000001',
 jsonb_build_array(jsonb_build_object('product_id','40000000-0000-4000-8000-000000000001','quantity',7)),
 'cod','pickup','50000000-0000-4000-8000-000000000001','buyer_portal');
select * from public.create_batch_order(
 '20000000-0000-4000-8000-000000000001',
 jsonb_build_array(jsonb_build_object('product_id','40000000-0000-4000-8000-000000000001','quantity',7)),
 'cod','pickup','50000000-0000-4000-8000-000000000001','buyer_portal');

do $$
declare saved_order uuid;
begin
 if (select count(*) from public.orders where idempotency_key='50000000-0000-4000-8000-000000000001')<>1 then raise exception 'Order retry was not idempotent'; end if;
 if (select reserved from public.inventory_batches where batch_number='EARLY')<>5
   or (select reserved from public.inventory_batches where batch_number='LATE')<>2 then raise exception 'FEFO allocation was incorrect'; end if;
 begin
  perform public.create_batch_order('20000000-0000-4000-8000-000000000001',
   jsonb_build_array(
    jsonb_build_object('product_id','40000000-0000-4000-8000-000000000001','quantity',1),
    jsonb_build_object('product_id','40000000-0000-4000-8000-000000000002','quantity',1)),
   'cod','pickup','50000000-0000-4000-8000-000000000002','buyer_portal');
  raise exception 'Insufficient multi-line order was accepted';
 exception when others then
  if sqlerrm='Insufficient multi-line order was accepted' then raise; end if;
 end;
 if (select sum(reserved) from public.inventory_batches where product_id='40000000-0000-4000-8000-000000000001')<>7 then
  raise exception 'Failed cart left partial reservations';
 end if;
 select id into saved_order from public.orders where idempotency_key='50000000-0000-4000-8000-000000000001';
 if not public.cancel_my_batch_order('20000000-0000-4000-8000-000000000001',saved_order) then raise exception 'First cancellation did not execute'; end if;
 if public.cancel_my_batch_order('20000000-0000-4000-8000-000000000001',saved_order) then raise exception 'Cancellation released twice'; end if;
 if (select sum(reserved) from public.inventory_batches where product_id='40000000-0000-4000-8000-000000000001')<>0 then raise exception 'Cancellation did not release inventory'; end if;
end;
$$;

select 'Local authoritative batch core checks passed' result;
