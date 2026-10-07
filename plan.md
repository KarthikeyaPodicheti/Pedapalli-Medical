# Petapali Medical — MVP implementation plan

## Confirmed scope

One medical store serving Peddapalli, Telangana, India. Customers browse available medicines, see out-of-stock products, add stock to a cart, and complete guest checkout with cash on delivery. Staff maintain products, prices, quantities, and orders through an authenticated admin panel, including validated Excel/CSV bulk updates. Prescription uploads are excluded; required verification happens with the pharmacist before dispensing.

The user has created a private GitHub repository called “Petapali Medical.” Its exact URL and access are pending. This isolated local directory is provisional; no existing repository contents have been overwritten or reviewed yet.

## Product and visual direction

Use the supplied green-and-white pharmacy reference: dark emerald information strip, pharmacy wordmark, prominent search, category navigation, compact mint feature banner, product cards, and clear green cart actions. Prioritize the shopping surface on mobile. Omit invented ratings, customer counts, discounts, phone numbers, licensing statements, dealer login, Google login, and prescription upload.

## Architecture

- React, TypeScript, and Vite for an accessible static frontend compatible with GitHub Pages.
- Supabase PostgreSQL for inventory/orders, Supabase Auth for staff, and an Edge Function for public checkout.
- Row-level security restricts inventory writes and all order/customer data to staff.
- An explicit demo mode operates without external credentials. Demo inventory changes stay on the device; demo checkout never submits a real order and never persists customer contact details.
- Production checkout stays disabled until delivery rules, backend, verified inventory, and staff access are configured.
- A private source repository remains private. GitHub Pages is enabled only when the account supports private repositories; no visibility changes without approval.

## Customer journey

1. Search by medicine name, brand, composition, or SKU; filter by category or in-stock status.
2. Inspect name, strength, pack size, manufacturer, price, prescription status, and availability.
3. Add available packs to a cart, adjust quantity, remove items, and review totals.
4. Enter name, Indian mobile number, address, locality, and PIN code; review cash-on-delivery terms and prescription requirements.
5. Submit an order request. The server checks serviceability, prices, stock, and request idempotency before returning an order reference.
6. Store acceptance and pharmacist checks precede dispensing. Confirmation must describe the actual stage rather than claim delivery is guaranteed.

## Staff journey

- Staff sign in using Supabase email/password accounts authorized in a staff table; public sign-up does not grant access.
- Edit or add medicines with unique SKU, name, composition, strength, pack size, manufacturer, category, price in paise, available quantity, active flag, and prescription-required flag.
- Inventory edits use a version check to avoid silently overwriting concurrent sales or staff changes.
- Import .csv or .xlsx, validate headers/identifiers/values, preview creates and updates, and confirm a single transaction. Reject all changes if validation fails; do not silently apply partial batches.
- View pending orders, accept/reject, record pharmacist verification, mark out for delivery/completed, and cancel with controlled stock release.

## Data model

- products: UUID, unique SKU, name/composition/strength/pack/manufacturer/category, price_paise, stock, active, prescription_required, version, timestamps.
- staff_members: auth user ID, role; populated only by a privileged operator.
- store_settings: store name, checkout enabled, serviceable PIN codes, delivery_fee_paise, minimum_order_paise, timestamps.
- orders: UUID, opaque customer reference, idempotency key, customer contact/address, payment method COD, server-calculated totals, status, prescription_verified_at/by, created/updated timestamps.
- order_items: immutable name, pack size, SKU, prescription status, unit-price snapshots plus product ID and quantity.
- inventory_events: product, quantity delta, reason, order/staff actor, timestamp.

## Order and inventory correctness

- Compute all prices and totals on the server; never accept frontend prices as authoritative.
- Lock requested product rows in deterministic ID order and reserve stock atomically.
- Limit item count and quantity; reject inactive/out-of-stock products and nonserviceable addresses.
- Enforce idempotency so retries do not create duplicate orders or reserve stock twice.
- Releasing stock is an allowed one-time state transition; completed orders cannot be cancelled as if undelivered.
- Prescription orders require recorded pharmacist verification before fulfilment.
- Edge checkout requires an anti-abuse challenge, rejects oversized requests, and never logs customer details.
- No service-role secret is embedded in frontend assets. Anonymous clients can read only active public product data and safe store settings, never order/customer tables.

## Bulk import template

Columns: sku,name,composition,strength,pack_size,manufacturer,category,price,stock,prescription_required,active. Price is rupees with at most two decimal places; stored as integer paise. Quantity is a nonnegative integer; booleans accept true/false. SKU is the stable update key. Maximum 1 MB input and 500 rows. Unsupported columns, duplicate SKUs, blank required fields, invalid booleans and prices, and inconsistent spreadsheet cells are shown as row errors before confirmation.

## Delivery and operational decisions still needed

Exact business name/contact/hours, serviceable PIN codes, delivery charge/minimum, licensed-pharmacist workflow, actual inventory source, and expiry/batch controls remain unconfirmed. Delivery setup defaults to disabled rather than accepting orders everywhere. The pharmacist must verify prescription classifications and inventory before launch. Customer privacy policy, cancellation/refund terms, retention policy, backups, and responsibility for stock reconciliation must be agreed before processing real orders.

## Milestones

1. Confirm repository access and inspect its instructions/files. Preserve any existing work.
2. Build responsive catalog, search/filtering, product details, cart, and checkout.
3. Build staff inventory UI, import preview, order UI, and settings.
4. Add database migration, row-level policies, transactional RPCs, checkout Edge Function, and setup docs.
5. Test validation/imports/cart, browser flows and mobile layout; build production output.
6. Commit and push to the private repository. Configure GitHub Pages if supported and permitted; verify actual deployment status.

## Acceptance and verification

- Out-of-stock items stay visible and cannot enter the cart.
- Search, category changes, quantity limits, remove actions and empty states work.
- Invalid customer details are rejected; demo checkout explicitly says no order was sent.
- Inventory updates and import previews correctly report invalid/duplicate rows.
- Backend tests cover stock contention, idempotency, cancellation release, price authority, and unauthenticated/staff access boundaries when backend infrastructure is available.
- Test desktop and narrow mobile viewports, keyboard dialogs, and no page overflow.
- CI installs from lockfile, runs tests/type checks/build, and prepares Pages artifacts without secrets.
- Backend deployment and live-order tests must be reported as pending if no Supabase project is configured; frontend tests are not proof of production readiness.

## Handoff

Deliver source, this plan, README/setup instructions, import template, database migration/function, environment examples without secrets, CI/Pages workflow, test results, verified repository link, and an explicit list of launch blockers. Do not claim repository review, deployment, shared persistence, or live ordering before verification.
