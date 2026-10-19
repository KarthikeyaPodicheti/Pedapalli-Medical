alter table private.sessions
  add column mfa_verified boolean not null default false;

create table private.staff_mfa (
  user_id uuid primary key references private.users(id) on delete cascade,
  encrypted_secret text not null check(length(encrypted_secret) between 40 and 500),
  enabled boolean not null default false,
  enabled_at timestamptz,
  updated_at timestamptz not null default now()
);

revoke all on private.staff_mfa from public;
grant select,insert,update on private.staff_mfa to medical_api;
grant update(mfa_verified) on private.sessions to medical_api;

create or replace function public.enable_staff_mfa(actor uuid)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
begin
  if not exists(select 1 from private.users where id=actor and account_type='staff' and not disabled) then
    raise exception 'Staff account required';
  end if;
  update private.staff_mfa set enabled=true,enabled_at=coalesce(enabled_at,now()),updated_at=now()
    where user_id=actor;
  if not found then raise exception 'Start MFA setup first'; end if;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id)
    values(actor,'staff.mfa_enabled','user',actor::text);
end;
$$;

revoke all on function public.enable_staff_mfa(uuid) from public;
grant execute on function public.enable_staff_mfa(uuid) to medical_api;
