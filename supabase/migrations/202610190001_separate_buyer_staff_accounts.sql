-- Buyer identities and staff identities are separate security realms.
-- A medical-store buyer must never gain staff privileges, even if an erroneous
-- staff_members row is created for the same Auth user.

do $$
begin
  if exists (
    select 1
    from public.staff_members s
    join public.buyer_users b on b.user_id = s.user_id
  ) then
    raise exception 'Resolve accounts assigned to both buyer and staff roles before applying this migration';
  end if;
end;
$$;

create or replace function public.enforce_account_realm_separation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_table_name = 'staff_members' then
    if exists(select 1 from public.buyer_users where user_id = new.user_id) then
      raise exception 'Buyer accounts cannot be assigned staff access';
    end if;
  elsif exists(select 1 from public.staff_members where user_id = new.user_id) then
    raise exception 'Staff accounts cannot be assigned buyer access';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_staff_account_realm on public.staff_members;
create trigger enforce_staff_account_realm
before insert or update of user_id on public.staff_members
for each row execute function public.enforce_account_realm_separation();

drop trigger if exists enforce_buyer_account_realm on public.buyer_users;
create trigger enforce_buyer_account_realm
before insert or update of user_id on public.buyer_users
for each row execute function public.enforce_account_realm_separation();

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1 from public.staff_members s
    where s.user_id = auth.uid()
  ) and not exists(
    select 1 from public.buyer_users b
    where b.user_id = auth.uid()
  );
$$;

create or replace function public.has_staff_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1 from public.staff_members s
    where s.user_id = auth.uid() and s.role = any(allowed_roles)
  ) and not exists(
    select 1 from public.buyer_users b
    where b.user_id = auth.uid()
  );
$$;

drop policy if exists staff_self on public.staff_members;
create policy staff_self on public.staff_members
for select to authenticated
using (user_id = auth.uid() and public.is_staff());

revoke all on function public.enforce_account_realm_separation() from public, anon, authenticated;
revoke all on function public.is_staff() from public;
grant execute on function public.is_staff() to anon, authenticated;
revoke all on function public.has_staff_role(text[]) from public;
grant execute on function public.has_staff_role(text[]) to authenticated;
