create table public.inventory_imports (
  id uuid primary key default gen_random_uuid(),
  source_reference text not null unique check(length(source_reference) between 3 and 120),
  checksum text not null unique check(checksum ~ '^[0-9a-f]{64}$'),
  mode text not null check(mode in ('opening','receipt')),
  rows jsonb not null,
  preview_version uuid not null default gen_random_uuid(),
  status text not null default 'preview' check(status in ('preview','applied','reconciled')),
  created_by uuid not null references private.users(id),
  created_at timestamptz not null default now(),
  applied_by uuid references private.users(id),
  applied_at timestamptz,
  reconciled_by uuid references private.users(id),
  reconciled_at timestamptz,
  reconciliation_note text
);
revoke all on public.inventory_imports from public;
grant select on public.inventory_imports to medical_api;

create function public.import_snapshot(product uuid,batch text,expiry date)
returns jsonb language sql stable security definer set search_path=public,private,pg_temp as $$
  select jsonb_build_object('price_paise',p.price_paise,'mrp_paise',p.mrp_paise,
    'wholesale_unit',p.wholesale_unit,'product_updated_at',p.updated_at,'batch',to_jsonb(b))
  from public.products p left join public.inventory_batches b
    on b.product_id=p.id and b.batch_number=batch and b.expiry_date=expiry where p.id=product;
$$;

create function public.preview_inventory_import(actor uuid,source text,file_checksum text,import_mode text,input_rows jsonb)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare line jsonb; p public.products%rowtype; snapshot jsonb; staged jsonb:='[]'; saved public.inventory_imports%rowtype; result uuid;
begin
  if not public.has_staff_role(actor,array['owner','inventory']) then raise exception 'Inventory role required'; end if;
  if import_mode is null or import_mode not in ('opening','receipt') then raise exception 'Invalid import mode'; end if;
  if import_mode='opening' and (select checkout_enabled from public.store_settings where id=1) then raise exception 'Opening stock requires checkout disabled'; end if;
  if length(trim(source)) not between 3 and 120 then raise exception 'Source reference must be 3 to 120 characters'; end if;
  if jsonb_typeof(input_rows) is distinct from 'array' or jsonb_array_length(input_rows) not between 1 and 500 then raise exception 'Import needs 1 to 500 rows'; end if;
  select * into saved from public.inventory_imports where source_reference=trim(source) or checksum=file_checksum for update;
  if found then
    if saved.source_reference<>trim(source) or saved.checksum<>file_checksum then raise exception 'Source reference or file already used'; end if;
    if saved.status<>'preview' then return saved.id; end if;
  end if;
  if exists(select 1 from jsonb_array_elements(input_rows) x group by x->>'sku',x->>'batch_number',x->>'expiry_date' having count(*)>1) then raise exception 'Duplicate SKU/batch/expiry row'; end if;
  if exists(select 1 from jsonb_array_elements(input_rows) x group by x->>'sku' having count(distinct (x->>'price_paise',x->>'mrp_paise'))>1) then raise exception 'Conflicting prices for the same SKU'; end if;
  for line in select value from jsonb_array_elements(input_rows) loop
    select * into p from public.products where sku=line->>'sku';
    if not found then raise exception 'Unknown SKU: %',line->>'sku'; end if;
    if line->>'wholesale_unit' is distinct from p.wholesale_unit then raise exception 'Unit mismatch for SKU: %',p.sku; end if;
    if coalesce(line->>'quantity','')!~'^[1-9][0-9]{0,5}$' or length(coalesce(line->>'batch_number','')) not between 1 and 100
      or coalesce(line->>'expiry_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      or coalesce(line->>'price_paise','')!~'^[1-9][0-9]{0,7}$' or coalesce(line->>'mrp_paise','')!~'^[1-9][0-9]{0,7}$'
    then raise exception 'Invalid import row for SKU: %',p.sku; end if;
    if (line->>'price_paise')::integer>(line->>'mrp_paise')::integer then raise exception 'Wholesale price exceeds MRP: %',p.sku; end if;
    if (line->>'expiry_date')::date<=current_date then raise exception 'Expired batch: %',p.sku; end if;
    snapshot:=public.import_snapshot(p.id,line->>'batch_number',(line->>'expiry_date')::date);
    if snapshot->'batch'<>'null'::jsonb and (import_mode='opening' or snapshot->'batch'->>'status'<>'quarantined') then
      raise exception 'Existing batch must be quarantined for a receipt; opening stock requires a new batch: %',p.sku;
    end if;
    staged:=staged||jsonb_build_array(line||jsonb_build_object('product_id',p.id,'name',p.name,'before',snapshot));
  end loop;
  if saved.id is null then
    insert into public.inventory_imports(source_reference,checksum,mode,rows,created_by)
      values(trim(source),file_checksum,import_mode,staged,actor) returning id into result;
  else
    result:=saved.id;
    update public.inventory_imports set rows=staged,preview_version=gen_random_uuid(),created_by=actor,created_at=now() where id=result;
  end if;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
    values(actor,'inventory.import_preview','import',result::text,jsonb_build_object('checksum',file_checksum,'rows',staged,'previous_rows',saved.rows));
  return result;
end;
$$;

create function public.apply_inventory_import(actor uuid,target uuid,expected_version uuid)
returns uuid language plpgsql security definer set search_path=public,private,pg_temp as $$
declare saved public.inventory_imports%rowtype; line jsonb; receipts jsonb:='[]'; sequence integer:=0;
begin
  if not public.has_staff_role(actor,array['owner','inventory']) then raise exception 'Inventory role required'; end if;
  select * into saved from public.inventory_imports where id=target for update;
  if not found then raise exception 'Import not found'; end if;
  if saved.preview_version is distinct from expected_version then raise exception 'Preview changed; review the latest version before applying'; end if;
  if saved.status in ('applied','reconciled') then return saved.id; end if;
  if saved.mode='opening' and (select checkout_enabled from public.store_settings where id=1) then raise exception 'Opening stock requires checkout disabled'; end if;
  if saved.created_at<now()-interval '24 hours' then raise exception 'Preview expired; upload the same file and reference to refresh it'; end if;
  perform id from public.products where id in (select (value->>'product_id')::uuid from jsonb_array_elements(saved.rows)) order by id for update;
  perform id from public.inventory_batches where product_id in (select (value->>'product_id')::uuid from jsonb_array_elements(saved.rows)) order by id for update;
  for line in select value from jsonb_array_elements(saved.rows) loop
    if public.import_snapshot((line->>'product_id')::uuid,line->>'batch_number',(line->>'expiry_date')::date) is distinct from line->'before' then raise exception 'Inventory or price changed since preview; create a fresh preview'; end if;
    if (line->>'expiry_date')::date<=current_date then raise exception 'Batch expired since preview'; end if;
    sequence:=sequence+1;
    receipts:=receipts||jsonb_build_array(jsonb_build_object('line_key',sequence::text,'product_id',line->>'product_id',
      'batch_number',line->>'batch_number','expiry_date',line->>'expiry_date','quantity',(line->>'quantity')::integer));
  end loop;
  perform public.record_batch_receipt(actor,'import:'||target::text,receipts);
  for line in select value from jsonb_array_elements(saved.rows) loop
    update public.products set price_paise=(line->>'price_paise')::integer,mrp_paise=(line->>'mrp_paise')::integer,updated_at=now()
      where id=(line->>'product_id')::uuid;
  end loop;
  update public.inventory_imports set status='applied',applied_by=actor,applied_at=now() where id=target;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
    values(actor,'inventory.import_applied','import',target::text,jsonb_build_object('rows',saved.rows,'mode',saved.mode));
  return target;
end;
$$;

create function public.reconcile_inventory_import(actor uuid,target uuid,counts jsonb,note text)
returns void language plpgsql security definer set search_path=public,private,pg_temp as $$
declare saved public.inventory_imports%rowtype; line jsonb; batch public.inventory_batches%rowtype; position integer:=0;
begin
  if not public.has_staff_role(actor,array['owner']) then raise exception 'Owner role required'; end if;
  select * into saved from public.inventory_imports where id=target for update;
  if not found or saved.status<>'applied' then raise exception 'An applied import is required'; end if;
  if saved.applied_by=actor then raise exception 'A different owner must independently reconcile this import'; end if;
  if length(trim(note)) not between 10 and 500 or note is null then raise exception 'Reconciliation note must be 10 to 500 characters'; end if;
  if jsonb_typeof(counts) is distinct from 'array' or jsonb_array_length(counts)<>jsonb_array_length(saved.rows) then raise exception 'Enter every physical batch count'; end if;
  perform id from public.inventory_batches where product_id in (select (value->>'product_id')::uuid from jsonb_array_elements(saved.rows)) order by id for update;
  for line in select value from jsonb_array_elements(saved.rows) loop
    select * into batch from public.inventory_batches where product_id=(line->>'product_id')::uuid and batch_number=line->>'batch_number' and expiry_date=(line->>'expiry_date')::date;
    if not found or coalesce(counts->>position,'')!~'^[0-9]{1,6}$' or (counts->>position)::integer<>batch.on_hand then raise exception 'Physical count differs from ledger; investigate before reconciliation'; end if;
    position:=position+1;
  end loop;
  update public.inventory_imports set status='reconciled',reconciled_by=actor,reconciled_at=now(),reconciliation_note=trim(note) where id=target;
  insert into public.audit_events(actor_id,event_type,subject_type,subject_id,details)
    values(actor,'inventory.import_reconciled','import',target::text,jsonb_build_object('counts',counts,'note',trim(note)));
end;
$$;
revoke all on function public.import_snapshot(uuid,text,date),public.preview_inventory_import(uuid,text,text,text,jsonb),public.apply_inventory_import(uuid,uuid,uuid),public.reconcile_inventory_import(uuid,uuid,jsonb,text) from public;
grant execute on function public.preview_inventory_import(uuid,text,text,text,jsonb),public.apply_inventory_import(uuid,uuid,uuid),public.reconcile_inventory_import(uuid,uuid,jsonb,text) to medical_api;
