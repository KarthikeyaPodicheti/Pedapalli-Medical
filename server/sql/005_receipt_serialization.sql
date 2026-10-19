-- All receiving paths share the product locks used by orders and imports.
alter function public.record_batch_receipt(uuid,text,jsonb) set schema private;
revoke all on function private.record_batch_receipt(uuid,text,jsonb) from public,medical_api;
create function public.record_batch_receipt(actor uuid,source_reference text,lines jsonb)
returns integer language plpgsql security definer set search_path=public,private,pg_temp as $$
declare line jsonb;
begin
  if not public.has_staff_role(actor,array['owner','inventory']) then raise exception 'Inventory role required'; end if;
  if jsonb_typeof(lines) is distinct from 'array' or jsonb_array_length(lines) not between 1 and 500 then raise exception 'Receipt needs 1 to 500 lines'; end if;
  perform id from public.products where id in (select (value->>'product_id')::uuid from jsonb_array_elements(lines)) order by id for update;
  for line in select value from jsonb_array_elements(lines) loop
    if not exists(select 1 from public.inventory_receipt_lines r where r.source_reference=trim(record_batch_receipt.source_reference) and r.line_key=line->>'line_key')
      and exists(select 1 from public.inventory_batches b where b.product_id=(line->>'product_id')::uuid
        and b.batch_number=trim(line->>'batch_number') and b.expiry_date=(line->>'expiry_date')::date and b.status<>'quarantined')
    then raise exception 'Additional receipts require a quarantined batch; never add uninspected stock to released stock'; end if;
  end loop;
  return private.record_batch_receipt(actor,source_reference,lines);
end;
$$;
revoke all on function public.record_batch_receipt(uuid,text,jsonb) from public;
grant execute on function public.record_batch_receipt(uuid,text,jsonb) to medical_api;
