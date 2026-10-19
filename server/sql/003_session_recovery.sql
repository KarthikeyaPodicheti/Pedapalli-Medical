-- Serialize session issuance against privileged password/MFA recovery.
create function public.issue_session(actor uuid,expected_hash text,token text,verified boolean,expected_secret text)
returns boolean language plpgsql security definer set search_path=public,private,pg_temp as $$
declare account private.users%rowtype; mfa private.staff_mfa%rowtype;
begin
  select * into account from private.users where id=actor for update;
  if not found or account.disabled or account.password_hash<>expected_hash then return false; end if;
  select * into mfa from private.staff_mfa where user_id=actor;
  if account.account_type='staff' and
    (coalesce(mfa.enabled,false)<>verified or mfa.encrypted_secret is distinct from expected_secret)
  then return false; end if;
  if account.account_type='buyer' and verified then return false; end if;
  insert into private.sessions(token_hash,user_id,expires_at,mfa_verified)
    values(token,actor,now()+interval '8 hours',verified);
  return true;
end;
$$;
revoke all on function public.issue_session(uuid,text,text,boolean,text) from public;
grant execute on function public.issue_session(uuid,text,text,boolean,text) to medical_api;
