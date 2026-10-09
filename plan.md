# Peddapalli Medical Store Website — Build Plan

## Goal and current status

Build a mobile-first ordering website for one medical store serving Peddapalli/Pedapalli, Telangana. Customers can browse a public medicine catalog, check availability, and submit cash-on-delivery order requests. Staff can securely maintain inventory and manage incoming orders.

The GitHub repository is [KarthikeyaPodicheti/Pedapalli-Medical](https://github.com/KarthikeyaPodicheti/Pedapalli-Medical), verified private. The MVP frontend, admin interface, Supabase migration and checkout function, tests, and GitHub workflows are implemented in the repository. The hosted backend and real store configuration are not yet provisioned, so the application remains in explicit demo mode. The displayed store name is **Peddapalli Pharmacy** provisionally; the actual licensed business name is still to be confirmed.

This plan separates a working demonstration from a real ordering service. Demo checkout must plainly say that no order was sent to the store. Real orders must remain disabled until the backend, store settings, catalog, and operating procedures are configured and verified.

## Customer experience

The public storefront will use a clean green-and-white pharmacy style based on the supplied reference description: a slim dark-green information strip, pharmacy identity and search in the header, a visible cart, horizontal category navigation, a pale mint promotional/healthcare banner, category shortcuts, product cards, and a simple footer. It will not include invented reviews, customer counts, discounts, contact details, licensing claims, delivery promises, Google/dealer login, or prescription upload.

Customer journey:

1. Browse categories or search by medicine name, brand, or composition when catalog data is available.
2. Open a product detail view showing name, strength/composition, dosage form, pack size, manufacturer/brand, INR price, availability, and prescription-required status where applicable.
3. Add only available products to a cart. Change quantities or remove items; quantities cannot exceed current available stock. Out-of-stock products remain visible and cannot be added.
4. Check out as a guest with customer name, mobile number, and delivery address. Show COD as the payment method, validate the configured delivery area and minimum, and show the server-calculated total before submission.
5. On successful submission, show a unique order reference and the actual state, initially **Awaiting store confirmation**. Do not say an order is confirmed until staff confirms it.

Planned customer views are the storefront/home and category/search results, product details, cart, guest checkout, and order confirmation/status. The cart may be stored in browser storage; customer details and orders must not be stored there as the order system of record. Cart contents must be refreshed against current price and stock before checkout.

## Staff experience

Staff use a sign-in page backed by hosted authentication. There is no public staff registration, shared client-side password, or security based on hiding an admin URL. Staff can search/filter inventory; add and edit products, prices, stock, and prescription flags; deactivate products without deleting historical records; review orders and update their states; and configure delivery settings.

The inventory import view will provide a downloadable CSV template, upload, validation, a preview of additions/updates/rejections, row-level error details, and an explicit apply step. The template headers are `sku,name,category,brand,composition,strength,dosage_form,pack_size,price_inr,stock_quantity,prescription_required,active`. SKU, name, category, price, quantity, prescription flag, and active flag are required. Descriptive fields may be blank. SKU is the stable product identifier: existing rows update by SKU, new SKUs create products, duplicate SKUs in one file are rejected, and missing SKUs never cause name-based matching. Rows absent from an import do not delete or deactivate products.

Prices must be valid nonnegative INR amounts and quantities nonnegative whole numbers. Boolean fields accept only documented true/false values. Validation also checks duplicate rows, required values, and stock edits that would put on-hand quantity below already reserved quantity. Preview labels each row as create, update, or reject and shows the proposed values. On confirmation, valid rows apply together in one database transaction; rejected rows remain unchanged and are reported. If the transaction fails, none of the valid rows are applied. Each import records who applied it, when, and its row outcomes.

## Architecture and hosting

Use **React, TypeScript, and Vite** for a static storefront and staff interface. This is a practical fit for a responsive shopping UI and the requested GitHub Pages hosting. Use **Supabase** as the proposed hosted backend for PostgreSQL, staff authentication, row-level security (RLS), and Edge Functions. No Supabase project or credentials are currently configured; this choice should be revisited only if an existing business backend is discovered.

GitHub Pages serves the built frontend only. It does not host the database, private staff authorization, or transactional order logic. Configure the Vite base path for `/<repository-name>/` and use hash-based client routing so direct navigation works on project Pages without server rewrite support. The frontend may contain the Supabase public/anon key only when RLS is correctly enforced. Service-role and other privileged credentials stay in backend secrets and never enter the bundle or repository. Add `.env.example` with names and explanations, no real values.

The repo is private. GitHub’s current documentation says Pages is available from public repositories on GitHub Free and from private repositories on Pro, Team, or Enterprise plans. A Pages site built from a private repository is still publicly available on plans that permit it; private source does not make the store website private. The authenticated account plan was not exposed by the GitHub API, and Pages is not configured on the repo, so eligibility remains unverified. Before deployment, confirm the account plan and Pages settings. If private-repository Pages is unavailable, keep the repository private and ask the owner to choose a supported hosting/visibility option; do not make it public silently. References: [GitHub Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site), [GitHub Pages and custom domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-github-pages/about-custom-domains-and-github-pages).

Provide two deliberate modes. **Demo mode** uses synthetic sample products and clearly marked demo data; checkout can demonstrate field validation and cart totals but must explicitly state no order was transmitted. **Connected mode** requires configured backend endpoints and must fail closed if they are missing. Real customer orders are accepted only through the connected backend.

## Data model and access control

Initial PostgreSQL tables:

- `products`: immutable UUID, unique SKU, name, category, brand/manufacturer, composition, strength, dosage form, pack size, integer price in paise, on-hand quantity, reserved quantity, prescription-required flag, active flag, optional image reference, and timestamps.
- `orders`: UUID, customer-facing unique reference, customer name/mobile/address, order state, COD method, item/subtotal/delivery/total snapshots in paise, idempotency key, reservation expiry, timestamps, and state-change metadata.
- `order_items`: order and product references plus immutable SKU, product name, pack/strength description, prescription flag, unit-price snapshot, and quantity.
- `staff_profiles`: Supabase user ID and assigned role (owner or staff); role changes are owner-controlled.
- `delivery_settings`: enabled service area/pincodes, delivery charge, minimum order, and reservation duration. Defaults do not promise service: with no verified coverage configured, real checkout is disabled.
- `inventory_imports` and `inventory_import_rows`: import audit metadata and row outcomes. Add an inventory movement/audit table for staff stock corrections and order reservation/release/fulfilment events.

Public access is limited to active catalog fields needed by the storefront. RLS denies anonymous access to customer/order data and all staff mutations. Staff permissions are checked against authenticated backend roles and enforced by the database/functions, not only by frontend route guards. Do not collect or store medical history. Protect mobile numbers, addresses, and order history through least-privilege policies and a documented retention/backup policy before launch.

## Order and inventory lifecycle

Order submission goes through a server-side Edge Function and a single transactional database operation. The backend validates fields and serviceability, reloads current prices, validates quantities, calculates all totals in integer paise, checks available stock (`on_hand - reserved`), and applies an idempotency key to prevent duplicate submissions. If any line fails, no order or reservation is committed. On success, create the order and snapshots and reserve every line atomically. Return the order reference and its real state.

New orders are **Awaiting store confirmation**. Staff may confirm, reject, prepare, mark out for delivery, deliver, or cancel according to allowed transitions. Reservation release is an idempotent state transition: rejection, cancellation, or expiry releases a reservation exactly once; delivery converts reserved quantity into fulfilled/on-hand reduction exactly once. Configure a 24-hour default reservation expiry, adjustable by the owner; show expiring orders to staff and provide a scheduled backend job to expire and release them. Staff stock edits and imports cannot reduce on-hand quantity below outstanding reservations. All transitions and stock movements are auditable.

Orders containing prescription-required products are booking requests, not dispensing authorization. Do not request prescription uploads. The website gives no dosage advice or substitution recommendations. Where applicable, a pharmacist reviews the request outside the website before dispensing. Staff record the out-of-band review outcome and reviewer identity in the order workflow; fulfillment of such items is blocked until review is recorded as verified. Applicable legal and operating requirements, including what review record is appropriate, must be confirmed by the responsible pharmacist before real launch.

## Delivery and business settings

Delivery coverage, charge, minimum order, store contact/hours, licensed business name, pharmacist details, product catalog, prices, inventory, and product imagery are not yet confirmed. Keep coverage and charges configurable and do not invent values. Coverage should use an owner-maintained list of supported postal codes or areas; if no area is configured, disable real checkout rather than imply serviceability. Display contact and hours only after the store supplies verified details. Decide expiry/batch tracking with the pharmacist before launch; it is outside the initial catalog model until requirements are confirmed.

## Implementation milestones

1. **Foundation and demo storefront:** initialize the frontend, repository documentation, design tokens, responsive shell, search/category navigation, synthetic catalog, product detail, out-of-stock behavior, cart, and explicit demo checkout.
2. **Backend foundation:** provision Supabase outside the repository, add schema/migrations, RLS, staff roles, secure environment setup, and server-side catalog/order functions.
3. **Real checkout and lifecycle:** implement server-authoritative totals, idempotent transactional order creation, stock reservation/release/fulfilment, order confirmation/status views, and out-of-band pharmacist review gate.
4. **Staff tools:** implement secure sign-in, inventory CRUD/search, deactivation/history behavior, order management, delivery settings, and audited CSV preview/apply flow.
5. **Deployment and launch readiness:** build/deploy the static site using Pages base-path configuration if the private repository/account plan permits; otherwise pause for an explicit hosting/visibility decision. Add setup and operations documentation, environment examples, and complete the launch checklist before accepting real orders.

## Acceptance checks

- Search matches name, brand, and composition; category filters work on mobile and desktop.
- Out-of-stock items remain visible, are clearly labeled, and cannot be added. Cart edits/removal work, stock limits are enforced, and current server prices replace stale browser totals.
- Checkout validates name, Indian mobile number, address, configured delivery coverage, and minimum order. Demo mode plainly says no order was sent. Connected mode returns a unique reference and correct initial status.
- Concurrent submissions for the last units cannot oversell. Repeated submission with the same idempotency key creates one order. Rejected/cancelled/expired orders release stock once; delivered orders decrement on-hand once.
- Anonymous users cannot view or mutate orders, customer details, or inventory. Unauthorized staff roles cannot perform owner-only actions. Staff can edit price/quantity and deactivate products while old order snapshots remain intact.
- CSV template downloads; invalid prices, quantities, IDs/SKUs, duplicate rows, and reserved-stock conflicts are reported before apply. Valid rows are previewed; confirmation applies the valid batch atomically; failed commits change nothing.
- Prescription orders require a recorded pharmacist verification before fulfillment, with no upload control or automated medical advice.
- Mobile layouts have readable product details, large touch controls, one-column checkout and import review, keyboard navigation, visible focus, sufficient contrast, and no horizontal overflow.
- Production build loads assets from the Pages project base path and hash routes work on refresh/direct links.
- Deployment check confirms the site is reachable and public by design, repo remains private, and no secrets or real customer data are committed.

## Launch blockers and checklist

Before real orders are enabled: verify the business’s licensed name and contact details; obtain an approved product catalog with verified identifiers, pricing, availability, images, and prescription flags; configure delivery area/charges/minimum; provision and secure the hosted backend; create owner/staff accounts; confirm pharmacist review and applicable operating requirements; decide batch/expiry handling and privacy/retention procedures; test backup and recovery; confirm private-repository Pages eligibility or obtain an explicit alternative hosting/visibility decision; and complete a real-device checkout and staff workflow review.

Until those items are complete, use synthetic data, label the site as a demonstration, and do not accept or claim to transmit real orders.
