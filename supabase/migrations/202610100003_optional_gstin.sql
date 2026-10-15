-- GST registration is not mandatory for every eligible buyer. Keep GSTIN
-- validated and unique when supplied, while retaining drug-licence checks.

alter table public.buyer_businesses alter column gstin drop not null;
alter table public.buyer_businesses drop constraint if exists buyer_businesses_gstin_check;
alter table public.buyer_businesses add constraint buyer_businesses_gstin_check
  check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$');
alter table public.buyer_businesses drop constraint if exists buyer_businesses_gstin_key;
create unique index buyer_businesses_gstin_unique_when_present
  on public.buyer_businesses(gstin) where gstin is not null;

create or replace function public.submit_buyer_application(application jsonb) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare saved_id uuid;
begin
  if auth.uid() is null then raise exception 'Sign in before applying'; end if;
  if exists(select 1 from public.buyer_users where user_id=auth.uid()) then raise exception 'This account already has a buyer application'; end if;
  if coalesce(length(trim(application->>'businessName')),0) not between 2 and 120
    or coalesce(length(trim(application->>'contactName')),0) not between 2 and 100
    or lower(coalesce(application->>'email','')) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or lower(application->>'email')<>lower(coalesce(auth.jwt()->>'email',''))
    or coalesce(application->>'phone','') !~ '^[6-9][0-9]{9}$'
    or (nullif(upper(trim(coalesce(application->>'gstin',''))),'') is not null
      and upper(trim(application->>'gstin')) !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$')
    or coalesce(length(trim(application->>'drugLicence')),0) not between 5 and 60
    or coalesce(length(trim(application->>'address')),0) not between 10 and 400
    or coalesce(application->>'pincode','') !~ '^[1-9][0-9]{5}$'
  then raise exception 'Invalid buyer application'; end if;
  insert into public.buyer_businesses(legal_name,contact_name,email,phone,gstin,drug_licence_number,registered_address,pincode)
  values(trim(application->>'businessName'),trim(application->>'contactName'),lower(trim(application->>'email')),application->>'phone',nullif(upper(trim(application->>'gstin')),''),trim(application->>'drugLicence'),trim(application->>'address'),application->>'pincode')
  returning id into saved_id;
  insert into public.buyer_users(user_id,buyer_id,role) values(auth.uid(),saved_id,'owner');
  insert into public.notification_deliveries(buyer_id,channel,event_name) values(saved_id,'email','buyer_application_submitted'),(saved_id,'whatsapp','buyer_application_submitted');
  return saved_id;
exception when unique_violation then
  raise exception 'A buyer application already uses the supplied GSTIN or drug-licence number';
end;
$$;

create or replace function public.submit_buyer_application_verified(
  application jsonb,
  target_user uuid,
  target_email text
) returns uuid
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare saved_id uuid;
begin
  if target_user is null or target_email is null
    or not exists(select 1 from auth.users where id=target_user and lower(email)=lower(target_email))
  then raise exception 'Verified account is invalid'; end if;
  if exists(select 1 from public.buyer_users where user_id=target_user) then
    raise exception 'This account already has a buyer application';
  end if;
  if coalesce(length(trim(application->>'businessName')),0) not between 2 and 120
    or coalesce(length(trim(application->>'contactName')),0) not between 2 and 100
    or lower(coalesce(application->>'email','')) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or lower(application->>'email')<>lower(target_email)
    or coalesce(application->>'phone','') !~ '^[6-9][0-9]{9}$'
    or (nullif(upper(trim(coalesce(application->>'gstin',''))),'') is not null
      and upper(trim(application->>'gstin')) !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$')
    or coalesce(length(trim(application->>'drugLicence')),0) not between 5 and 60
    or coalesce(length(trim(application->>'address')),0) not between 10 and 400
    or coalesce(application->>'pincode','') !~ '^[1-9][0-9]{5}$'
  then raise exception 'Invalid buyer application'; end if;

  insert into public.buyer_businesses(legal_name,contact_name,email,phone,gstin,drug_licence_number,registered_address,pincode)
  values(trim(application->>'businessName'),trim(application->>'contactName'),lower(trim(application->>'email')),application->>'phone',nullif(upper(trim(application->>'gstin')),''),trim(application->>'drugLicence'),trim(application->>'address'),application->>'pincode')
  returning id into saved_id;
  insert into public.buyer_users(user_id,buyer_id,role) values(target_user,saved_id,'owner');
  insert into public.notification_deliveries(buyer_id,channel,event_name)
  values(saved_id,'email','buyer_application_submitted'),(saved_id,'whatsapp','buyer_application_submitted');
  return saved_id;
exception when unique_violation then
  raise exception 'A buyer application already uses the supplied GSTIN or drug-licence number';
end;
$$;

revoke execute on function public.submit_buyer_application(jsonb) from authenticated;
revoke all on function public.submit_buyer_application_verified(jsonb,uuid,text) from public,anon,authenticated;
grant execute on function public.submit_buyer_application_verified(jsonb,uuid,text) to service_role;
