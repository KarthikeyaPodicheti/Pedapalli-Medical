-- Buyers may cancel their own pending orders before staff acceptance.
-- Uses the same order-row lock and legacy stock ledger as staff cancellation.
create or replace function public.cancel_my_pending_order(target_order uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare current_order public.orders%rowtype; item public.order_items%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select o.* into current_order from public.orders o
 join public.buyer_users u on u.buyer_id=o.buyer_id and u.user_id=auth.uid()
 where o.id=target_order for update of o;
 if not found then raise exception 'Order not found'; end if;
 if current_order.status='cancelled' then return; end if;
 if current_order.status<>'pending' then raise exception 'Only pending orders can be self-cancelled'; end if;
 perform p.id from public.products p where p.id in
   (select oi.product_id from public.order_items oi where oi.order_id=current_order.id)
   order by p.id for update;
 for item in select * from public.order_items oi where oi.order_id=current_order.id order by product_id loop
   update public.products set stock=stock+item.quantity,version=version+1,
     inventory_updated_at=now(),updated_at=now() where id=item.product_id;
   insert into public.inventory_events(product_id,quantity_delta,reason,order_id,actor_id)
     values(item.product_id,item.quantity,'buyer_order_cancelled',current_order.id,auth.uid());
 end loop;
 update public.orders set status='cancelled',updated_at=now() where id=current_order.id;
 insert into public.order_status_events(order_id,previous_status,next_status,actor_id,reason)
 values(current_order.id,'pending','cancelled',auth.uid(),'Buyer cancelled pending order');
 insert into public.notification_deliveries(order_id,buyer_id,channel,event_name)
 values(current_order.id,current_order.buyer_id,'email','order_cancelled'),
       (current_order.id,current_order.buyer_id,'whatsapp','order_cancelled');
end;
$$;
revoke all on function public.cancel_my_pending_order(uuid) from public,anon;
grant execute on function public.cancel_my_pending_order(uuid) to authenticated;
