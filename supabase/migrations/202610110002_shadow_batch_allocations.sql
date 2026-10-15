-- PRD FR-030/031: staging-only batch allocation rehearsal.
-- This deliberately DOES NOT change create_b2b_order, product.stock or checkout.
-- Allocations are shadow reservations for cutover testing, not live fulfilment.
create table public.batch_order_allocations (
 id bigint generated always as identity primary key,
 order_item_id uuid not null references public.order_items(id) on delete cascade,
 batch_id uuid not null references public.inventory_batches(id),
 quantity integer not null check (quantity>0),
 created_at timestamptz not null default now(),
 unique(order_item_id,batch_id)
);
create index batch_order_allocations_batch_idx on public.batch_order_allocations(batch_id);
alter table public.batch_order_allocations enable row level security;
revoke all on public.batch_order_allocations from anon,authenticated;
grant select on public.batch_order_allocations to authenticated;
create policy batch_allocations_staff_read on public.batch_order_allocations
 for select to authenticated using (public.has_staff_role(array['owner','inventory','pharmacist']));
-- Rehearsal allocates all lines of an existing order in one DB transaction.
-- Locks product rows in stable order, then batches in stable order to avoid races.
-- Only service role can call; do not expose to the browser.
create or replace function public.rehearse_batch_allocation(target_order uuid)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare line record; lot record; remaining_units integer; take_units integer; total_lines integer:=0;
begin
 if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
 if target_order is null then raise exception 'Order required'; end if;
 perform 1 from public.orders where id=target_order and status in ('pending','accepted') for update;
 if not found then raise exception 'Only open orders can be rehearsed'; end if;
 if exists(select 1 from public.batch_order_allocations a
    join public.order_items oi on oi.id=a.order_item_id where oi.order_id=target_order) then
   raise exception 'Order already has a shadow allocation';
 end if;
 perform p.id from public.products p
   where p.id in (select oi.product_id from public.order_items oi where oi.order_id=target_order)
   order by p.id for update;
 for line in select oi.id,oi.product_id,oi.quantity from public.order_items oi
   where oi.order_id=target_order order by oi.product_id,oi.id loop
   remaining_units:=line.quantity;
   for lot in select b.id,b.on_hand,b.reserved from public.inventory_batches b
      where b.product_id=line.product_id and b.status='sellable'
        and b.expiry_date>current_date
      order by b.expiry_date,b.id for update loop
      take_units:=least(remaining_units,lot.on_hand-lot.reserved);
      if take_units>0 then
       update public.inventory_batches set reserved=reserved+take_units,updated_at=now()
         where id=lot.id and reserved+take_units<=on_hand;
       if not found then raise exception 'Concurrent batch change'; end if;
       insert into public.batch_order_allocations(order_item_id,batch_id,quantity)
         values(line.id,lot.id,take_units);
       insert into public.batch_inventory_movements(batch_id,quantity_delta,reserved_delta,reason,source_reference,actor_id)
         values(lot.id,0,take_units,'Shadow allocation rehearsal',target_order::text,
           (select user_id from public.staff_members where role='owner' order by user_id limit 1));
       remaining_units:=remaining_units-take_units;
      end if;
      exit when remaining_units=0;
   end loop;
   if remaining_units<>0 then raise exception 'Insufficient eligible batch stock for order item %',line.id; end if;
   total_lines:=total_lines+1;
 end loop;
 return total_lines;
end;
$$;
-- Release rehearsal holds exactly once; no effect on legacy order status.
create or replace function public.release_rehearsed_batch_allocation(target_order uuid)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare allocation record; released integer:=0;
begin
 if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
 if target_order is null then raise exception 'Order required'; end if;
 perform 1 from public.orders where id=target_order for update;
 if not found then raise exception 'Order not found'; end if;
 for allocation in select a.id,a.batch_id,a.quantity from public.batch_order_allocations a
   join public.order_items oi on oi.id=a.order_item_id
   where oi.order_id=target_order order by a.batch_id,a.id loop
   update public.inventory_batches set reserved=reserved-allocation.quantity,updated_at=now()
    where id=allocation.batch_id and reserved>=allocation.quantity;
   if not found then raise exception 'Shadow reservation mismatch'; end if;
   insert into public.batch_inventory_movements(batch_id,quantity_delta,reserved_delta,reason,source_reference,actor_id)
    values(allocation.batch_id,0,-allocation.quantity,'Shadow allocation rehearsal released',target_order::text,
      (select user_id from public.staff_members where role='owner' order by user_id limit 1));
   delete from public.batch_order_allocations where id=allocation.id;
   released:=released+allocation.quantity;
 end loop;
 return released;
end;
$$;
revoke all on function public.rehearse_batch_allocation(uuid) from public,anon,authenticated;
revoke all on function public.release_rehearsed_batch_allocation(uuid) from public,anon,authenticated;
grant execute on function public.rehearse_batch_allocation(uuid) to service_role;
grant execute on function public.release_rehearsed_batch_allocation(uuid) to service_role;
