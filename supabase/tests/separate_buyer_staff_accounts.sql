\set ON_ERROR_STOP on

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);

do $$
begin
  if public.is_staff() then
    raise exception 'Buyer account passed the general staff check';
  end if;
  if public.has_staff_role(array['owner','sales','inventory','dispatch','pharmacist','staff']) then
    raise exception 'Buyer account passed a staff role check';
  end if;
  if (select count(*) from public.staff_members) <> 0 then
    raise exception 'Buyer account can read staff membership records';
  end if;
end;
$$;

reset role;

do $$
begin
  begin
    insert into public.staff_members(user_id,role)
    values('11111111-1111-4111-8111-111111111111','owner');
    raise exception 'Buyer account was assigned a staff role';
  exception when others then
    if sqlerrm = 'Buyer account was assigned a staff role' then raise; end if;
    if sqlerrm <> 'Buyer accounts cannot be assigned staff access' then raise; end if;
  end;

  begin
    insert into public.buyer_users(user_id,buyer_id,role)
    values(
      '33333333-3333-4333-8333-333333333333',
      (select buyer_id from public.buyer_users where user_id='11111111-1111-4111-8111-111111111111'),
      'buyer'
    );
    raise exception 'Staff account was assigned buyer access';
  exception when others then
    if sqlerrm = 'Staff account was assigned buyer access' then raise; end if;
    if sqlerrm <> 'Staff accounts cannot be assigned buyer access' then raise; end if;
  end;
end;
$$;

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$
begin
  if not public.is_staff() or not public.has_staff_role(array['owner']) then
    raise exception 'Valid owner lost staff access';
  end if;
  if (select count(*) from public.staff_members) <> 1 then
    raise exception 'Valid staff member cannot read their assignment';
  end if;
end;
$$;
reset role;

select 'Buyer/staff account separation checks passed' as result;
