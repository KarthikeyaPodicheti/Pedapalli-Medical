\set ON_ERROR_STOP on

do $$
begin
  if has_function_privilege('authenticated','public.submit_buyer_application(jsonb)','execute') then
    raise exception 'Authenticated browser role can bypass the verified application boundary';
  end if;
  if not has_function_privilege('service_role','public.submit_buyer_application_verified(jsonb,uuid,text)','execute') then
    raise exception 'Service role cannot submit verified applications';
  end if;
end $$;

do $$
begin
  begin
    update public.products set mrp_paise=price_paise-1 where sku='TEST-1';
    raise exception 'MRP below wholesale price was accepted';
  exception when check_violation then null;
  end;
end $$;

set role service_role;
select public.submit_buyer_application_verified(jsonb_build_object(
  'businessName','Verified Medical Store','contactName','Verified Buyer','email','verified@example.in',
  'phone','9876543212','drugLicence','DL-VERIFIED-2',
  'address','Main Road Peddapalli Telangana','pincode','505172'
),'55555555-5555-4555-8555-555555555555','verified@example.in');
reset role;

do $$
begin
  if not exists(select 1 from public.buyer_users where user_id='55555555-5555-4555-8555-555555555555') then
    raise exception 'Verified buyer application was not stored';
  end if;
  if not exists(
    select 1 from public.buyer_businesses b
    join public.buyer_users u on u.buyer_id=b.id
    where u.user_id='55555555-5555-4555-8555-555555555555' and b.gstin is null
  ) then
    raise exception 'Buyer application without GSTIN was not stored as null';
  end if;
end $$;
