\set ON_ERROR_STOP on
update public.store_settings set checkout_enabled=false where id=1;
do $$
declare owner_id uuid:='10000000-0000-4000-8000-000000000001'; inventory_id uuid:='10000000-0000-4000-8000-000000000002';
  buyer_id uuid:='20000000-0000-4000-8000-000000000001'; rows jsonb; target uuid; version uuid; original_version uuid; failure boolean;
begin
  rows:=jsonb_build_array(jsonb_build_object('sku','EMPTY-1','wholesale_unit','pack','batch_number','IMPORT-TEST',
    'expiry_date',(current_date+500)::text,'quantity',10,'price_paise',700,'mrp_paise',900));
  failure:=false;
  begin perform public.preview_inventory_import(buyer_id,'DENIED',repeat('a',64),'opening',rows); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Buyer preview was not denied'; end if;
  target:=public.preview_inventory_import(inventory_id,'TEST-IMPORT',repeat('b',64),'opening',rows);
  select preview_version into original_version from public.inventory_imports where id=target;
  if exists(select 1 from public.inventory_batches where batch_number='IMPORT-TEST') then raise exception 'Preview mutated inventory'; end if;
  update public.products set price_paise=701 where sku='EMPTY-1';
  failure:=false;
  begin perform public.apply_inventory_import(inventory_id,target,original_version); exception when raise_exception then failure:=true; end;
  if not failure or exists(select 1 from public.inventory_batches where batch_number='IMPORT-TEST') then raise exception 'Stale preview was not atomic'; end if;
  perform public.preview_inventory_import(inventory_id,'TEST-IMPORT',repeat('b',64),'opening',rows);
  select preview_version into version from public.inventory_imports where id=target;
  failure:=false;
  begin perform public.apply_inventory_import(inventory_id,target,original_version); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Old preview version applied'; end if;
  perform public.apply_inventory_import(inventory_id,target,version);
  perform public.apply_inventory_import(inventory_id,target,version);
  if not exists(select 1 from public.inventory_batches where batch_number='IMPORT-TEST' and on_hand=10 and reserved=0 and status='quarantined') then raise exception 'Import replay changed quantity or quarantine'; end if;
  if (select count(*) from public.inventory_movements where source_reference='import:'||target::text)<>1 then raise exception 'Duplicate import movement'; end if;
  failure:=false;
  begin perform public.reconcile_inventory_import(inventory_id,target,'[10]','Physical count matches'); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Inventory staff reconciled without owner role'; end if;
  failure:=false;
  begin perform public.reconcile_inventory_import(owner_id,target,'[9]','Incorrect physical count'); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Wrong count reconciled'; end if;
  perform public.reconcile_inventory_import(owner_id,target,'[10]','Independent physical count matches');
  if (select status from public.inventory_imports where id=target)<>'reconciled' then raise exception 'Reconciliation missing'; end if;
  failure:=false;
  begin perform public.preview_inventory_import(inventory_id,'DUPLICATE-FILE',repeat('b',64),'opening',rows); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'File replay with changed reference accepted'; end if;
  failure:=false;
  begin perform public.preview_inventory_import(inventory_id,'DUPLICATE-BATCH',repeat('c',64),'opening',rows); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Opening stock overwrote existing batch'; end if;
  failure:=false;
  begin perform public.preview_inventory_import(inventory_id,'WRONG-UNIT',repeat('d',64),'receipt',jsonb_set(rows,'{0,wholesale_unit}','"tablet"')); exception when raise_exception then failure:=true; end;
  if not failure then raise exception 'Unit mismatch accepted'; end if;
  -- Recovery/session issuance must reject stale credentials and disabled users.
  if public.issue_session(buyer_id,'wrong-hash',repeat('a',64),false,null) then raise exception 'Old password issued session'; end if;
  update private.users set disabled=true where id=buyer_id;
  if public.issue_session(buyer_id,'test-hash',repeat('a',64),false,null) then raise exception 'Disabled user issued session'; end if;
  update private.users set disabled=false where id=buyer_id;
  if not public.issue_session(buyer_id,'test-hash',repeat('a',64),false,null) then raise exception 'Valid buyer session rejected'; end if;
end;
$$;
update public.store_settings set checkout_enabled=true where id=1;
select 'Controlled import and session recovery checks passed' result;
