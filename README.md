# Petapali Medical

A mobile-first pharmacy storefront for a single store in Peddapalli, Telangana. Customers can search stock, add available products to a cart, and complete a cash-on-delivery order request. Staff can update inventory, prices and stock levels, import CSV/XLSX files, configure delivery PIN codes, and manage orders.

## What works now

Without any environment variables the app starts in a clearly labelled browser-only preview:

- Sample medicine catalog with visible stock and prescription flags
- Search, category filters, cart and responsive guest checkout
- Demo checkout never sends an order or persists customer details
- Staff-preview inventory edits and validated CSV/XLSX import
- Mobile and desktop end-to-end tests

The preview is not a live ordering system. It intentionally keeps real checkout disabled until Supabase and delivery settings are configured.

## Run locally

```bash
npm install
npm run dev
```

Open the local URL printed by Vite. For a production build:

```bash
npm test
npm run test:e2e
npm run build
```

## Production setup

1. Create a Supabase project.
2. Apply [supabase/migrations/202610070001_store.sql](supabase/migrations/202610070001_store.sql).
3. Create the first staff user through Supabase Auth, then insert that user ID into `public.staff_members` with the `owner` role using the Supabase SQL editor.
4. Deploy the checkout Edge Function:

   ```bash
   supabase functions deploy checkout --no-verify-jwt
   ```

5. Set these Edge Function secrets. Do not commit any of them:

   ```bash
   supabase secrets set STOREFRONT_ORIGIN=https://YOUR-ACCOUNT.github.io
   supabase secrets set TURNSTILE_SECRET_KEY=your_secret
   ```

   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to Supabase Functions automatically.

6. Add these repository variables for the GitHub Pages build:

   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
   - `VITE_TURNSTILE_SITE_KEY`

7. In the staff workspace, add verified delivery PIN codes and delivery pricing. Only then enable “Accept online order requests.”
8. Configure GitHub Pages to deploy from **GitHub Actions**, then run the **Publish GitHub Pages** workflow. This action uses the repository name automatically as the Pages base path.

For a project Pages URL such as `https://ACCOUNT.github.io/REPOSITORY/`, set `STOREFRONT_ORIGIN` to the exact origin only (`https://ACCOUNT.github.io`). Cloudflare Turnstile should include the Pages hostname in its allowed hostnames.

## Inventory imports

Download [public/inventory-template.csv](public/inventory-template.csv) from the staff workspace or directly from this repository. Supported columns are:

```text
sku,name,composition,strength,pack_size,manufacturer,category,price,stock,prescription_required,active
```

SKU is the stable update key. Import previews flag errors before saving; valid and invalid rows are never mixed into a partial update. Products need verified medicine data, pricing and pharmacist classification before a real launch.

## Important operating rules

- Product price and stock are calculated and rechecked on the server at checkout.
- The database reserves stock transactionally and supports idempotent order retries.
- Prescription medicines still need pharmacist verification before fulfilment; the site does not provide medical advice or dosage recommendations.
- Do not turn on checkout until delivery coverage, store terms, customer privacy handling, licensed-pharmacist review, and stock reconciliation are in place.

See [plan.md](plan.md) for the complete MVP scope, data model, launch blockers and acceptance criteria.
