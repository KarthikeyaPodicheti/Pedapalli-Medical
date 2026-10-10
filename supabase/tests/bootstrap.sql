\set ON_ERROR_STOP on

create schema auth;
create schema extensions;
create table auth.users(id uuid primary key, email text not null);

create function auth.uid() returns uuid language sql stable as
  'select nullif(current_setting(''request.jwt.claim.sub'',true),'''')::uuid';
create function auth.jwt() returns jsonb language sql stable as
  'select jsonb_build_object(''email'',nullif(current_setting(''request.jwt.claim.email'',true),''''))';

create role anon nologin;
create role authenticated nologin;
create role service_role nologin;

insert into auth.users(id,email) values
  ('11111111-1111-4111-8111-111111111111','buyer1@example.in'),
  ('22222222-2222-4222-8222-222222222222','buyer2@example.in'),
  ('33333333-3333-4333-8333-333333333333','owner@example.in'),
  ('44444444-4444-4444-8444-444444444444','inventory@example.in'),
  ('55555555-5555-4555-8555-555555555555','verified@example.in');


-- Supabase Auth role helper used by service-only RPCs in local integration tests.
create or replace function auth.role() returns text language sql stable as $$
 select nullif(current_setting('request.jwt.claim.role',true),'');
$$;
