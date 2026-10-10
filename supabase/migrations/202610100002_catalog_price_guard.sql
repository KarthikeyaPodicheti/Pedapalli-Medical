-- MRP below wholesale price is an invalid and misleading catalog state.
alter table public.products
  add constraint products_mrp_not_below_wholesale
  check (mrp_paise is null or mrp_paise >= price_paise);
