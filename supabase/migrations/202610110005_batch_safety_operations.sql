-- Staff batch safety operations. These are shadow-ledger tools until controlled cutover.
create or replace function public.adjust_inventory_batch(
 target_batch uuid, quantity_change integer, adjustment_reason text, source_ref text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare batch public.inventory_batches%rowtype;
begin
 if not public.has_staff_role(array['owner','inventory']) then raise exception 'Inventory role required'; end if;
 if quantity_change is null or quantity_change=0 or abs(quantity_change)>999999
   or length(trim(coalesce(adjustment_reason,'')))<10 or length(trim(adjustment_reason))>500
   or length(trim(coalesce(source_ref,'')))<3 or length(trim(source_ref))>200
 then raise exception 'Invalid audited adjustment'; end if;
 select * into batch from public.inventory_batches where id=target_batch for update;
 if not found then raise exception 'Unknown batch'; end if;
 if batch.on_hand::bigint+quantity_change<batch.reserved
    or batch.on_hand::bigint+quantity_change>2147483647 then
    raise exception 'Adjustment would invalidate reserved stock or overflow'; end if;
 update public.inventory_batches set on_hand=on_hand+quantity_change,updated_at=now()
 where id=target_batch;
 insert into public.batch_inventory_movements(batch_id,quantity_delta,reason,source_reference,actor_id)
 values(target_batch,quantity_change,trim(adjustment_reason),trim(source_ref),auth.uid());
end;
$$;
revoke all on function public.adjust_inventory_batch(uuid,integer,text,text) from public,anon;
grant execute on function public.adjust_inventory_batch(uuid,integer,text,text) to authenticated;

-- Returned goods always enter a new quarantined receipt identity, never sellable.
create or replace function public.receive_quarantined_return(
 target_product uuid, lot_number text, expires_on date, returned_quantity integer,
 return_reference text, return_reason text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.has_staff_role(array['owner','inventory']) then raise exception 'Inventory role required'; end if;
 if length(trim(coalesce(return_reason,'')))<10 then raise exception 'Return reason required'; end if;
 return public.receive_inventory_batch(target_product,lot_number,expires_on,
   returned_quantity,'RETURN:'||trim(return_reference),'Return quarantine: '||trim(return_reason));
end;
$$;
revoke all on function public.receive_quarantined_return(uuid,text,date,integer,text,text) from public,anon;
grant execute on function public.receive_quarantined_return(uuid,text,date,integer,text,text) to authenticated;

-- Read-only operational report; non-sellable batches are included for staff action.
create or replace function public.staff_batch_alerts(days_ahead integer default 90)
returns table(product_id uuid,sku text,batch_id uuid,batch_number text,expiry_date date,
 status text,on_hand integer,reserved integer,alert_type text)
language sql stable security definer set search_path=public,pg_temp as $$
 select b.product_id,p.sku,b.id,b.batch_number,b.expiry_date,b.status,b.on_hand,b.reserved,
 case when b.expiry_date<=current_date then 'expired'
      when b.status in ('recalled','disputed','damaged','quarantined') then b.status
      else 'near_expiry' end
 from public.inventory_batches b join public.products p on p.id=b.product_id
 where public.has_staff_role(array['owner','inventory','pharmacist'])
 and b.on_hand>0 and
 (b.expiry_date<=current_date+least(greatest(days_ahead,0),365)
  or b.status in ('recalled','disputed','damaged','quarantined'))
 order by b.expiry_date,b.id;
$$;
revoke all on function public.staff_batch_alerts(integer) from public,anon;
grant execute on function public.staff_batch_alerts(integer) to authenticated;
