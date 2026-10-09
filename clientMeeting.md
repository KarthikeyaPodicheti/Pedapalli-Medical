# Client Meeting — Pharmaceutical Wholesale Portal

Use this document during client meetings. Record exact answers, avoid assumptions, and obtain approval for launch-critical decisions.

## Current product understanding

- The client is a pharmaceutical wholesaler in Peddapalli, Telangana.
- The first release is B2B for medical-store buyers; B2C is deferred.
- Only approved medical stores may see wholesale prices and order.
- Buyer verification initially uses GSTIN and drug-licence numbers without document upload.
- Version one uses fixed wholesale prices and product-specific MOQ/quantity steps.
- Payments are COD or bank transfer; every order requires wholesaler confirmation.
- Fulfilment should support own delivery, transporter delivery, and pickup.
- Inventory starts with validated Excel/CSV imports.
- Only a responsible-pharmacist-approved catalog is orderable.
- Notifications should use email and an approved WhatsApp provider.
- GST invoicing is undecided; export to existing billing software is preferred if available.
- Final branding and legal business details have not been provided.

## Ask the client

### Business and branding

- [ ] Exact legal business name and trading name?
- [ ] Logo, brand colors, tagline, and preferred domain?
- [ ] Office/warehouse address, phone, email, hours, and support contact?
- [ ] Wholesale drug-licence details, GSTIN, and responsible pharmacist/compliance contact?
- [ ] Which verified business details must appear publicly?

### Buyers and approval

- [ ] Which buyer types are eligible: retail pharmacies, hospitals, clinics, distributors, or others?
- [ ] Which licence numbers and expiry dates must buyers provide?
- [ ] Who verifies and approves buyers, and how is verification performed?
- [ ] How often must licences be reverified? What happens after expiry?
- [ ] May one medical store have multiple users, branches, billing addresses, or shipping addresses?
- [ ] What are valid rejection, suspension, and reactivation reasons?

### Catalog, pricing, and inventory

- [ ] Obtain a sanitized sample of the real inventory spreadsheet and column definitions.
- [ ] What is the stable product identifier: internal SKU, barcode, product code, or combination?
- [ ] Which product fields are available: brand, manufacturer, composition, strength, dosage form, pack, case size, MRP, HSN, GST, batch, and expiry?
- [ ] How are wholesale unit, MOQ, and quantity step defined per product?
- [ ] Are prices tax-inclusive or tax-exclusive? Are any buyer-specific rates or schemes required later?
- [ ] Who approves products for online ordering and which regulatory classes must remain blocked?
- [ ] How often will Excel be uploaded and who reconciles website stock with counter/phone sales?
- [ ] Does existing POS/ERP/billing software expose an API or export format?
- [ ] Who owns batch, expiry, recall, and near-expiry controls?

### Orders and fulfilment

- [ ] Minimum order value and maximum order limits?
- [ ] Order confirmation SLA, cut-off times, holidays, and cancellation window?
- [ ] Exact order statuses used by staff?
- [ ] Delivery areas/PIN codes and own-delivery rules?
- [ ] Pickup location and pickup procedure?
- [ ] Transporter partners, freight calculation/responsibility, tracking reference, and proof of delivery?
- [ ] Process for shortages, substitutions, damaged goods, returns, and rejected COD orders?
- [ ] Should buyers be able to reorder, download order history, or save frequent-order lists?

### Payments and invoicing

- [ ] Which bank-transfer details may be shown and how does staff verify payment?
- [ ] Is COD available for every buyer/order/area?
- [ ] What billing, POS, ERP, or accounting software does the client currently use?
- [ ] Should confirmed orders be exported by CSV/API, manually entered, or invoiced by the website?
- [ ] Who owns official GST invoice numbering and tax compliance?
- [ ] If the website stores invoices, what PDF, cancellation, credit-note, and retention rules apply?
- [ ] Are credit accounts, credit limits, outstanding balances, or payment terms planned for a later release?

### Notifications and support

- [ ] Which events require buyer and staff notifications?
- [ ] Approved sender email/domain and WhatsApp Business provider/account?
- [ ] Required message language: English, Telugu, Hindi, or multiple languages?
- [ ] Which team receives new-order, failed-payment, stale-order, and low-stock alerts?
- [ ] Support and grievance-escalation process?

### Policies, security, and operations

- [ ] Approved B2B terms, privacy policy, fulfilment policy, and cancellation/return policy?
- [ ] Required data-retention and deletion periods?
- [ ] Staff roles and the named people assigned to owner, sales, inventory, dispatch, and pharmacist/compliance roles?
- [ ] Is staff MFA acceptable and who manages access removal?
- [ ] Required reports, exports, and audit history?
- [ ] Backup/recovery expectations and acceptable downtime?
- [ ] Who signs off staging, pilot orders, staff training, and final production launch?

## Decisions log

Add confirmed client answers here using this format:

| Date | Topic | Confirmed decision | Implementation impact | Follow-up |
| --- | --- | --- | --- | --- |
| Pending | GST invoicing | Awaiting client billing-workflow review | Production launch remains blocked | Identify current billing software |
| Pending | Brand identity | Collect verified legal and public brand details | Continue using demo placeholders | Obtain logo and licence/contact details |

## Materials to request

- [ ] Logo and brand assets.
- [ ] Sanitized inventory spreadsheet.
- [ ] Product/category list and restricted-product rules.
- [ ] Buyer registration/verification form currently used.
- [ ] Sample order, invoice, credit note, and delivery document.
- [ ] Delivery area/rate list and transporter process.
- [ ] Existing policies and terms.
- [ ] Billing/POS/ERP product name and integration documentation.

## Launch-critical unresolved items

Do not enable production ordering until legal identity, buyer verification, approved catalog, inventory reconciliation, batch/expiry responsibility, delivery rules, invoice workflow, policies, staff roles, notification providers, backups, pilot testing, and client sign-off are confirmed and recorded.

## Engineering status — 9 October 2026

- The repository now contains the authenticated B2B ordering foundation: buyer application/approval, protected catalog pricing, MOQ/step validation, atomic stock reservation, idempotency, reservation release, buyer-scoped records and staff order transitions.
- Production remains intentionally disabled because no Supabase project/credentials or verified client operating data are available in the build environment.
- At the next client meeting, prioritize legal identity, catalog spreadsheet, delivery/payment rules, billing/GST handoff, staff assignments, policies and launch sign-off. Record answers above before activation.
