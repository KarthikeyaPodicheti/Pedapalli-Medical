-- B2B wholesale foundation. Apply only after reviewing client policy and taking a database backup.
-- The public preview remains fail-closed: no production buyer approval or order submission is enabled yet.

alter table public.store_settings alter column store_name set default 'Pedapalli Medical';
update public.store_settings set store_name = 'Pedapalli Medical' where store_name = 'Petapali Medical';

create table public.buyer_businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete set null,
  legal_name text not null check (length(legal_name) between 2 and 120),
  contact_name text not null check (length(contact_name) between 2 and 100),
  email text not null check (length(email) between 3 and 254),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  gstin text not null unique check (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$'),
  drug_licence_number text not null unique check (length(drug_licence_number) between 5 and 60),
  registered_address text not null check (length(registered_address) between 10 and 400),
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_note text check (length(review_note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'pending' and reviewed_at is null) or status <> 'pending')
);

alter table public.products
  add column mrp_paise integer check (mrp_paise between 1 and 99999999),
  add column wholesale_unit text not null default 'pack' check (length(wholesale_unit) between 1 and 40),
  add column units_per_case integer not null default 1 check (units_per_case between 1 and 999999),
  add column minimum_order_quantity integer not null default 1 check (minimum_order_quantity between 1 and 999999),
  add column quantity_step integer not null default 1 check (quantity_step between 1 and 999999),
  add column regulatory_class text not null default 'Unclassified' check (length(regulatory_class) between 1 and 80),
  add column pharmacist_approved boolean not null default false;

alter table public.orders
  add column buyer_id uuid references public.buyer_businesses(id),
  add column fulfilment_method text check (fulfilment_method in ('own_delivery','transporter','pickup')),
  add column transporter_note text check (length(transporter_note) <= 300),
  add column reservation_expires_at timestamptz;

alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check
  check (payment_method in ('cod','bank_transfer'));
alter table public.order_items drop constraint if exists order_items_quantity_check;
alter table public.order_items add constraint order_items_quantity_check
  check (quantity between 1 and 999999);

create index buyer_businesses_owner_idx on public.buyer_businesses(owner_user_id);
create index buyer_businesses_status_idx on public.buyer_businesses(status, created_at desc);
create index orders_buyer_idx on public.orders(buyer_id, created_at desc);

alter table public.buyer_businesses enable row level security;
create policy buyer_read_own on public.buyer_businesses for select to authenticated
  using (owner_user_id = auth.uid() or public.is_staff());
create policy buyer_staff_update on public.buyer_businesses for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

revoke all on public.buyer_businesses from anon, authenticated;
grant select on public.buyer_businesses to authenticated;
grant update on public.buyer_businesses to authenticated;

-- Buyer application creation and wholesale order placement must be exposed through
-- rate-limited server-side endpoints/RPCs after the client approves verification,
-- tax, fulfilment, cancellation and inventory-reservation rules.
