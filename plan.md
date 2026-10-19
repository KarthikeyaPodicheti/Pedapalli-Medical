# Peddapalli Pharmaceutical Wholesale Portal — Production Plan

## 1. Product goal

Build a production-ready B2B ordering portal for one pharmaceutical wholesaler in Peddapalli, Telangana. Approved medical stores will use it to browse a verified wholesale catalog, check availability, order in valid wholesale quantities, choose an offline payment method, and track fulfilment.

This is a B2B-first product. Individual consumers, consumer prescriptions, retail checkout, and B2C delivery are explicitly deferred to a later phase. The current deployed storefront is a demonstration and must remain clearly labelled as such until every launch gate in this plan is satisfied.

The commercial goal is a reliable product that can be sold to the client, configured for the client’s real business, and operated safely in production—not merely a visual prototype.

## 2. Confirmed business decisions

- Buyers are medical stores and other eligible medicine-retail businesses.
- Wholesale prices and ordering are available only to approved buyer accounts.
- Registration collects business details, an optional GSTIN, and a required drug-licence number. Verification happens outside the website initially; document upload is not required in version one.
- Staff must approve the buyer before catalog prices and ordering unlock.
- Version one uses fixed wholesale pricing rather than negotiated or buyer-tier pricing.
- Each product defines its wholesale unit, units per case where relevant, minimum order quantity, and allowed quantity step.
- Initial payments are COD or bank transfer. There is no online gateway or credit-account ledger in version one.
- Every submitted order is a request pending wholesaler confirmation.
- Fulfilment supports configurable own delivery, transporter delivery, and store pickup.
- Inventory and price updates start with validated Excel/CSV imports and staff reconciliation.
- Only a responsible-pharmacist-approved catalog may be published or ordered.
- Order and account notifications use transactional email plus an approved WhatsApp provider.
- Exact legal branding, licences, contact details, delivery rules, and service areas will be collected from the client.
- The GST invoice workflow will be decided after reviewing the client’s existing billing process. Export to an existing billing system is the preferred first option.

## 3. Product experience

### Public experience

The public site explains the wholesaler, service area, product categories, buyer benefits, verification process, and contact route. It may show general catalog categories, but wholesale prices, detailed availability, and ordering stay locked until buyer approval.

Public actions:

1. Learn about the wholesaler and B2B service.
2. Register a medical-store business.
3. Sign in.
4. Check application status or contact support.

### Buyer onboarding and approval

Registration collects:

- Legal business/trading name.
- Proprietor or authorized-contact name.
- Business email and verified Indian mobile number.
- GSTIN, when the buyer has one (optional).
- Retail/wholesale drug-licence number or numbers and expiry dates where applicable.
- Billing and shipping addresses.
- Preferred fulfilment method.
- Agreement to business terms and privacy notice.

Account states are `submitted`, `under_review`, `approved`, `rejected`, `suspended`, and `expired`. Only approved, non-expired accounts may view wholesale prices or submit orders. Approval records who reviewed the account, when, and any internal reason. Licence expiry must trigger alerts and prevent ordering after the configured grace policy.

### Approved buyer journey

1. Sign in and view the wholesale catalog.
2. Search by product name, brand/manufacturer, composition, SKU, or category.
3. See verified product identity, pack/case details, wholesale price, MRP where appropriate, MOQ, quantity step, availability, and fulfilment restrictions.
4. Add quantities that satisfy MOQ and step rules.
5. Review subtotal, tax presentation when decided, fulfilment method, delivery/freight treatment, and payment method.
6. Submit the order request with an idempotency key.
7. Receive a reference and an honest `Awaiting wholesaler confirmation` state.
8. Receive email and WhatsApp updates and view order history/status in the portal.
9. Reorder from a previous confirmed order, subject to current price, stock, MOQ, and buyer eligibility.

### Staff experience and roles

Buyer and staff identities are separate security realms. A buyer account cannot
be assigned a staff role or open the admin workspace; staff use distinct,
individually assigned accounts. Hiding the staff link is only a UX measure—the
database must enforce this boundary for every protected read and mutation.

- **Owner/admin:** staff access, buyer approval policy, store settings, integrations, and all reports.
- **Sales:** buyer review, order review, customer support, confirmation, and rejection.
- **Inventory:** catalog, price, MOQ, stock imports, reconciliation, batch/expiry visibility, and availability.
- **Dispatch:** packing, fulfilment method, transporter/reference information, dispatch, and completion.
- **Pharmacist/compliance:** catalog eligibility, regulatory classification, licence review outcome, and restricted-product approval.

The backend—not just the interface—must enforce these permissions.

## 4. Catalog and inventory

Each product should support:

- Stable product/SKU identifier.
- Product and brand name.
- Manufacturer, composition, strength, and dosage form.
- Pack description, wholesale unit, units per case, MOQ, and quantity step.
- MRP and fixed wholesale price in integer paise.
- HSN code and GST/tax classification when the invoice workflow requires them.
- Regulatory/schedule classification and pharmacist approval status.
- Active, blocked, and orderable states.
- Available stock and inventory freshness timestamp.
- Optional licensed product image.

The operational source of truth must also account for batch number, expiry date, batch quantity, blocked/recalled batches, and FEFO handling. If the website does not own batch data, the client’s existing inventory system must enforce it and expose only safe available quantities to the portal.

### Excel/CSV workflow

Version one may use spreadsheet imports, but it must behave like a controlled business process:

- Downloadable, versioned template.
- Maximum file size and row limits.
- Stable SKU matching; no name-based silent matching.
- Strict field, price, quantity, MOQ, and category validation.
- Preview of creates, updates, blocked rows, and errors.
- Atomic confirmation: either the accepted batch applies completely or none of it does.
- Optimistic version/conflict checking.
- Audit record containing uploader, timestamps, source-file checksum, row outcomes, and before/after values.
- Reconciliation status and `inventory last updated` visibility.
- A documented schedule for reconciling website stock with counter, phone, and field-sales orders.

Before launch, confirm whether the client’s billing/POS/ERP system can replace spreadsheet imports with an automated integration.

## 5. Pricing, orders, payment, and fulfilment

- Server-side code is authoritative for buyer eligibility, current price, MOQ, quantity step, availability, tax inputs, freight, and totals.
- Client-submitted prices, discounts, eligibility flags, and statuses are never trusted.
- Order creation locks requested inventory deterministically and prevents overselling.
- Idempotency prevents retry duplication.
- Reservations expire automatically if the wholesaler does not confirm them within the configured window; stock is released exactly once.
- Staff can confirm, reject, pack, mark ready for pickup, assign transporter/delivery details, dispatch, complete, or cancel only through allowed transitions.
- Every order-state transition is recorded in an immutable audit history.
- COD and bank-transfer orders record the selected method. Bank transfer may record a reference and staff verification, but version one does not automatically settle or reconcile a bank account.
- Fulfilment rules support pickup, own delivery, and transporter delivery. Serviceability, freight responsibility, minimum order value, and cut-off times remain configurable.
- Buyer notifications are event-driven and recorded so failed email/WhatsApp delivery can be retried.

## 6. GST invoicing decision

Production launch requires a confirmed invoice workflow.

Preferred version-one option:

1. Staff confirms an order.
2. The portal exports a clean order payload/CSV/PDF summary for the client’s existing billing software.
3. The official GST invoice is created in that system.
4. The portal records the external invoice number and optionally stores or links the final PDF.

If the client requires website-generated invoices, scope must expand to cover invoice sequences, supplier and buyer GST details, HSN and tax rates, intra/inter-state tax handling, rounding, PDFs, cancellations, credit/debit notes, immutable audit records, and accountant/legal validation. Do not implement or claim compliant GST invoicing until this decision and its rules are confirmed.

## 7. Selected architecture — self-hosted local runtime

The current decision is to use repository code only, without an external application API.

- **Frontend:** React, TypeScript and Vite; GitHub Pages remains a synthetic demo.
- **Application:** a Node.js HTTP API behind same-origin Nginx, using HTTP-only
  sessions, exact-origin mutation checks and server-side authorization.
- **Database:** self-hosted PostgreSQL 17 with reviewed immutable migrations,
  least-privilege runtime credentials, transactional business functions and a
  persistent Docker volume.
- **Deployment:** Docker Compose is the development and production-candidate
  packaging baseline. Production still needs a client-controlled host, HTTPS,
  separate staging, encrypted off-host backups, monitoring and tested recovery.
- **Files/imports:** controlled local Excel/CSV import with checksum, preview,
  atomic apply and reconciliation; do not mount arbitrary spreadsheets directly.
- **Notifications:** manual operational fallback initially. Email or WhatsApp
  automation remains blocked until the client approves a provider and budget.

### Local implementation phases

1. **Runtime and inventory core:** local authentication, buyer approval, batch
   quarantine/release, authoritative FEFO reservations and hardened containers.
2. **Connected portal:** connect buyer and staff screens to the local API, add
   staff MFA and complete role-specific navigation and denial states.
3. **Controlled import/cutover:** validate the client Excel format, preview and
   atomically import catalog/batches, reconcile opening stock, and record sign-off.
4. **Operations:** implement assisted orders, picking/packing/dispatch, billing
   export, payment references, returns, reports and notification history.
5. **Hardening and pilot:** encrypted backup/restore rehearsal, monitoring,
   security/accessibility tests, staff training and controlled buyer pilot.

### Core data model

- `buyer_businesses`: identity, optional GSTIN, licence numbers/expiry, addresses, verification state, suspension state, timestamps.
- `buyer_users`: authenticated users linked to a business with buyer-side roles.
- `staff_members`: authenticated users with explicit operational roles.
- `products`: verified catalog and wholesale-ordering fields.
- `inventory_batches` or an external inventory reference: batch, expiry, quantity, blocked/recall status.
- `inventory_imports` and `inventory_import_rows`: immutable import audit and row outcomes.
- `store_settings`: ordering, fulfilment, payment, reservation, serviceability, and notification settings.
- `orders`: buyer business, snapshot addresses, payment/fulfilment method, authoritative totals, reservation expiry, status, invoice reference, timestamps.
- `order_items`: immutable SKU/name/pack/price/MOQ/tax snapshots.
- `order_status_events`: actor, previous/next state, reason, timestamp.
- `inventory_events`: all reservations, releases, adjustments, and fulfilment movements.
- `notification_deliveries`: channel, template, destination reference, status, retries, provider reference, timestamp.
- `audit_events`: sensitive approvals, access changes, setting changes, and exports.

## 8. Security and privacy requirements

- Prices and availability are not exposed to unapproved buyers.
- RLS scopes buyer users to their own business and orders.
- Operational roles are enforced in database functions and policies.
- Staff MFA is required before production.
- Authentication, registration, and write endpoints have rate limits and abuse protection.
- Service-role keys, notification tokens, and provider credentials exist only in backend secrets.
- GSTIN, licence information, contacts, addresses, and order history have a documented retention/deletion policy.
- Logs and analytics do not contain raw business contact information, licences, addresses, or order contents.
- Sensitive actions are auditable and export access is controlled.
- Backups, point-in-time recovery where available, and a tested restore runbook are configured.
- Dependencies, secrets, and source are scanned in CI; critical findings block release.
- Production changes use reviewed migrations, deployment evidence, and a rollback plan.

## 9. Regulatory and operational requirements

A responsible pharmacist and qualified Indian legal/tax professionals must confirm the applicable wholesale sale, buyer-licence, product-classification, recordkeeping, GST, delivery, and data-protection requirements. Engineering must encode the approved process but must not invent it.

At minimum, launch requires:

- Verified wholesaler legal identity, licences, pharmacist/compliance owner, contact details, and service terms.
- A defined buyer-licence verification and renewal process.
- A pharmacist-approved catalog and restricted-product policy.
- Batch/expiry/recall responsibility defined between the portal and existing inventory system.
- Privacy policy, B2B terms, cancellation/return policy, fulfilment policy, and support/grievance contact.
- Staff training for approval, inventory reconciliation, order confirmation, dispatch, cancellation, and incident handling.

## 10. Design direction

Use ApolloPharmacy.in only as a quality and usability reference: professional pharmacy trust signals, strong search, dense but readable catalog browsing, clear categories, polished cards, reliable responsive behavior, and obvious account/cart actions.

Do not copy Apollo’s trademark, logo, written content, images, illustrations, exact component layout, or proprietary interaction patterns. The portal needs its own brand system using verified client details, licensed stock photography, Phosphor icons, accessible color contrast, keyboard support, and mobile-first layouts.

## 11. Engineering and verification strategy

Automated coverage must include:

- Unit tests for pricing, MOQ/step rules, imports, GST inputs once defined, and validation.
- Database tests for RLS, role boundaries, buyer isolation, transitions, idempotency, reservation expiry, inventory release, and concurrent last-stock orders.
- Local API integration tests for origin checks, rate limits, malformed payloads, and authorization failures.
- End-to-end tests for registration, approval, sign-in, locked/unlocked catalog, wholesale cart, COD/bank-transfer order, status updates, inventory imports, and notifications.
- Desktop and real-device mobile review with accessibility checks and no horizontal overflow.
- Security review, production dependency audit, secret scan, and permission review.
- Staging data migration, backup restore drill, notification-provider sandbox tests, and post-deployment smoke tests.
- A small client pilot using verified synthetic or controlled products before general buyer onboarding.

CI must block merge/deployment when tests, builds, audits, migrations, or required checks fail. Production deployment should be reproducible, observable, and reversible.

## 12. Delivery phases

1. **Client discovery and compliance:** collect legal brand details, sample spreadsheet, licence-verification procedure, billing workflow, delivery rules, policies, staff roles, and approved catalog rules.
2. **B2B foundation:** redesign schema and navigation around buyer businesses, approval, authentication, locked pricing, RBAC, and audit history.
3. **Wholesale catalog and inventory:** product-specific MOQ/steps, verified catalog, spreadsheet import/audit, freshness, reconciliation, and batch/expiry integration decision.
4. **Ordering and fulfilment:** server-authoritative checkout, COD/bank transfer, reservations/expiry, order workflow, pickup/delivery/transporter options, and buyer order history.
5. **Notifications and billing handoff:** email/WhatsApp, retries/audit, billing export, and invoice reference handling.
6. **Hardening:** security, privacy, monitoring, backups, integration/concurrency tests, accessibility, performance, and operational runbooks.
7. **Staging acceptance and pilot:** client sign-off, staff training, controlled pilot orders, issue resolution, restore test, and final launch review.
8. **Production launch:** custom domain/configuration, verified production data, monitored rollout, and checkout enabled only after written acceptance.
9. **Future B2C phase:** separately design consumer catalog, prescription intake, consumer payments, delivery, and compliance without weakening B2B isolation.

## 13. Production acceptance gates

Do not enable real B2B ordering until all of these are evidenced:

- Client has approved exact business identity, branding, contacts, operating hours, and service area.
- Compliance owner has approved buyer verification and the orderable catalog.
- Invoice/billing handoff is confirmed and tested.
- Staging and production backends are provisioned separately.
- Buyer approval, authentication, RLS, and staff RBAC tests pass.
- Real product fields, wholesale prices, MOQ/steps, and availability are verified.
- Inventory reconciliation and batch/expiry responsibility are operational.
- Reservation expiry and idempotent stock release are tested.
- COD/bank transfer and all fulfilment paths are tested.
- Email and WhatsApp delivery, retries, and failure alerts are tested.
- Privacy, B2B terms, cancellation/return, and fulfilment policies are published.
- Monitoring, backups, recovery, incident response, and staff access removal are tested.
- No critical dependency or security findings remain.
- Client staff complete training and controlled pilot orders successfully.
- Final production smoke test passes and the client signs off before checkout is enabled.

## 14. Open client-discovery items

- Exact legal/trading name, logo, licences, pharmacist/compliance contact, support details, and domain.
- Existing billing/POS/ERP software and available integration/export formats.
- Official GST invoice owner and workflow.
- Spreadsheet column structure, update frequency, and stock reconciliation owner.
- Delivery PIN codes/areas, freight rules, pickup location, transporter process, order cut-off times, and minimum order value.
- Buyer licence types, expiry/grace policy, rejection reasons, and periodic reverification.
- Product regulatory classes and items excluded from online B2B ordering.
- Final cancellation, returns, damaged/short shipment, payment verification, privacy, and retention policies.

Until these decisions and the production gates are complete, keep the existing deployment in explicit demo mode and do not accept real business orders or real buyer data.

## 15. Current implementation status

### Local runtime execution — 19 October 2026

- Added the self-hosted Node.js/PostgreSQL container foundation and immutable
  migration runner.
- Added separate buyer/staff identities, pending buyer applications, protected
  catalog data and transactional buyer review.
- Made quarantined batches the inventory source of truth, with pharmacist
  release, minimum shelf life, FEFO reservation, idempotency, concurrency
  protection and exactly-once release.
- Added the connected React buyer/staff portal and staff TOTP MFA; checkout
  remains disabled.
- Added disposable database, API, MFA and desktop/mobile whole-stack tests.
- Retired the unused hosted-backend prototype, its deployment jobs and legacy
  tests. The public site is now browser-only demo code; the connected local
  runtime is the sole backend implementation.
- Next phase: build the controlled Excel import and opening-stock reconciliation
  workflow.
