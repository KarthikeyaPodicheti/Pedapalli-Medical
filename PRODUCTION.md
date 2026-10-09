# Production activation runbook

The application code supports real authenticated B2B orders, but production must remain disabled until every item below is complete. Never enter real buyer or medicine data into the browser-only demo.

## 1. Provision isolated environments

Create separate Supabase projects for staging and production. In each project:

1. Apply `supabase/migrations/202610070001_store.sql` and then `202610090001_b2b_foundation.sql`.
2. Enable email magic-link authentication and set the exact Site URL/redirect URLs.
3. Create staff Auth users, enable MFA for them, and insert their user IDs and least-privilege roles into `staff_members`.
4. Deploy the disabled legacy `checkout` function so no old anonymous checkout endpoint remains active.
5. Schedule `select public.release_expired_b2b_orders();` at least every five minutes using Supabase Cron or an equivalent trusted scheduler.
6. Enable backups/PITR appropriate to the client’s recovery requirement.

## 2. Configure hosting

Set these GitHub repository Actions variables separately for the intended backend:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

The anon key is intended for browser use; never expose the service-role key. After setting variables, run the Pages workflow and verify the site displays `SECURE B2B PORTAL`, not `B2B PREVIEW`.

## 3. Configure the business

Before enabling checkout, staff must:

1. Replace sample branding and publish verified legal/contact information and approved policies.
2. Import the pharmacist-approved real catalog using the current template. Confirm SKU, wholesale price, MRP, stock, unit, case size, MOQ, step and regulatory class.
3. Configure payment methods, fulfilment methods, delivery PIN codes, fee and minimum order value.
4. Verify the billing/GST handoff, batch/expiry responsibility and stock-reconciliation process.
5. Keep `checkout_enabled=false` until controlled staging orders pass.

## 4. Acceptance test

Run a staging pilot with synthetic or controlled records:

1. Buyer requests a secure email link and submits GSTIN/licence details.
2. An unauthorized account cannot see price or stock and cannot create an order.
3. Staff verifies and approves the buyer.
4. The approved buyer sees current prices, adds only valid MOQ/step quantities, and submits COD and bank-transfer test orders across enabled fulfilment methods.
5. Simultaneous orders cannot oversell stock; retrying the same idempotency key creates only one order.
6. Staff accepts/cancels orders; cancellation and expiration restore stock exactly once.
7. Buyer isolation and staff roles are tested, backups are restored, and staff completes the operating runbook.

Only after client/compliance sign-off should an owner enable `Accept online order requests` in Store settings.

## Still required outside this repository

- Client-approved legal identity, policies, GST/billing process, delivery rules and real catalog.
- Production Supabase project, domain/email configuration, staff accounts and MFA.
- Email and approved WhatsApp notification providers with delivery/retry monitoring.
- Error monitoring, uptime alerts, inventory freshness alerts and incident ownership.
- A custom domain, client pilot and written launch approval.
