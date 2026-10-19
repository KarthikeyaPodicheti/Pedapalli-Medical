# Client Meeting — Pharmaceutical Wholesale Portal

Use this document during client meetings. Record exact answers, avoid assumptions, and obtain approval for launch-critical decisions.

## Current product understanding

- The client is a pharmaceutical wholesaler in Peddapalli, Telangana.
- The first release is B2B for medical-store buyers; B2C is deferred.
- Only approved medical stores may see wholesale prices and order.
- Buyer verification requires a drug-licence number; GSTIN is optional. Documents are not uploaded in version one.
- Version one uses fixed wholesale prices and product-specific MOQ/quantity steps.
- Payments are COD or bank transfer; every order requires wholesaler confirmation.
- Fulfilment should support own delivery, transporter delivery, and pickup.
- Inventory starts with validated Excel/CSV imports.
- Only a responsible-pharmacist-approved catalog is orderable.
- Notifications should use email and an approved WhatsApp provider.
- GST invoicing is undecided; export to existing billing software is preferred if available.
- Final branding and legal business details have not been provided.
- Buyer and wholesaler-staff identities must be separate; buyer accounts cannot access the staff/admin portal.

## Ask the client

### Production sale and handover

- [ ] Who pays for and owns the production host, domain and off-host backup storage?
- [ ] Agree recovery targets: maximum acceptable data loss and restoration time.
- [ ] Who handles incidents, security updates, staff account recovery and ongoing maintenance?
- [ ] Agree acceptance scenarios, pilot participants, support hours and handover owner.
- [ ] Confirm manual notification procedures while external application APIs remain deferred.

The user confirmed the target is a sellable production product, not an MVP.
These operational details still require client answers; do not invent commitments.

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

- [ ] Map the real spreadsheet to template v1 (`docs/CONTROLLED_IMPORTS.md`),
  especially stock units, text expiry dates and integer-paise prices.
- [ ] Name the inventory operator and independent owner who will physically count
  imported batches; confirm the discrepancy investigation/adjustment process.
- [ ] Confirm account-recovery identity checks, authorized host operators and
  how temporary replacement passwords are handed over securely.

- [ ] Obtain a sanitized sample of the real inventory spreadsheet and column definitions.
- [ ] What is the stable product identifier: internal SKU, barcode, product code, or combination?
- [ ] Which product fields are available: brand, manufacturer, composition, strength, dosage form, pack, case size, MRP, HSN, GST, batch, and expiry?
- [ ] How are wholesale unit, MOQ, and quantity step defined per product?
- [ ] Are prices tax-inclusive or tax-exclusive? Are any buyer-specific rates or schemes required later?
- [ ] Who approves products for online ordering and which regulatory classes must remain blocked?
- [ ] How often will Excel be uploaded and who reconciles website stock with counter/phone sales?
- [ ] Does existing POS/ERP/billing software expose an API or export format?
- [ ] Who owns batch, expiry, recall, and near-expiry controls?
- [ ] For prescription-class products sold B2B, what evidence must be checked before dispatch, who is legally responsible, and what must the system record?
- [ ] What are the expected launch and 12-month counts for SKUs, approved buyers and orders per day?

### Orders and fulfilment

- [ ] Minimum order value and maximum order limits?
- [ ] Order confirmation SLA, cut-off times, holidays, and cancellation window?
- [ ] Exact order statuses used by staff?
- [ ] Delivery areas/PIN codes and own-delivery rules?
- [ ] Is delivery always to the registered business address, or may a verified buyer use branch/shipping addresses? Who approves changes?
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
- [ ] Confirm the exact screen/action permissions for each staff role, including catalog approval and prescription/compliance evidence.
- [ ] Is staff MFA acceptable and who manages access removal?
- [ ] Required reports, exports, and audit history?
- [ ] Backup/recovery expectations and acceptable downtime?
- [ ] Is the client accepting a monitored free-tier pilot that can pause or hit quotas, or is guaranteed availability required?
- [ ] Who monitors usage/uptime, runs the manual fallback, and authorizes a paid upgrade when a trigger is reached?
- [ ] What phone/WhatsApp/manual process should buyers use if the portal is unavailable?
- [ ] How many days of encrypted backups must be retained, and who holds the recovery passphrase?
- [ ] Who signs off staging, pilot orders, staff training, and final production launch?

## Decisions log

Add confirmed client answers here using this format:

| Date | Topic | Confirmed decision | Implementation impact | Follow-up |
| --- | --- | --- | --- | --- |
| Pending | GST invoicing | Awaiting client billing-workflow review | Production launch remains blocked | Identify current billing software |
| Pending | Brand identity | Collect verified legal and public brand details | Continue using demo placeholders | Obtain logo and licence/contact details |
| 19 October 2026 | Runtime architecture | Build a self-hosted local Node.js/PostgreSQL runtime using repository code only; no external application API for now | The earlier hosted proposal is retired; production needs a client-controlled host, HTTPS, backups and monitoring | Confirm who owns the host, network, domain, backup destination and uptime response |
| 15 October 2026 | Buyer GSTIN | GSTIN is optional; the drug-licence number remains required | Registration, database validation and staff review accept a missing GSTIN | Confirm whether non-GST buyers need invoice or ordering restrictions |
| 19 October 2026 | Admin access | Medical-store buyer accounts must never access the staff/admin portal | Separate buyer and staff identities; enforce the boundary in database roles, policies and UI routing | Confirm named staff accounts and least-privilege roles before launch |

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
- Production remains intentionally disabled because verified client operating data, stock reconciliation, workflow acceptance, and recovery evidence are still missing.
- The client must approve hosting ownership, backup destination, retention, downtime tolerance, and manual-fallback ownership.
- At the next client meeting, prioritize legal identity, catalog spreadsheet, delivery/payment rules, billing/GST handoff, staff assignments, policies and launch sign-off. Record answers above before activation.

## Next client meeting — priority discovery questions (2026-10-11)

> Ask the distributor to demonstrate one real order from request to delivery. Record actual practice, named owner, decision, and follow-up for each answer. These questions are **open** until the client confirms them; previous product-design discussions are not client sign-off.

### 45-minute meeting agenda

| Time | Topic | Intended outcome |
| --- | --- | --- |
| 0–5 min | Current ordering and stock-shortage problem | Confirm the main business objective |
| 5–15 min | Trace a real order through packing and delivery | Map operational workflow and handoffs |
| 15–25 min | Excel stock, receipts, and shortages | Establish inventory source of truth and ownership |
| 25–35 min | Pricing, GST billing, payments, delivery | Confirm commercial and legal handoffs |
| 35–45 min | Pilot scope, staff responsibilities, sign-off | Agree on MVP and next actions |

### Questions to ask the distributor

- [ ] **Order fulfilment:** Does the delivery van follow fixed routes? Who picks and packs orders? What are the daily order cutoffs, delivery schedules, and confirmation times?
- [ ] **Pricing:** Does every medical store receive the same wholesale price, or do stores have negotiated/customer-specific prices? Who maintains price changes?
- [ ] **Invoicing:** How are GST invoices currently generated? Which billing software or manual process is used? Can you show a real, redacted invoice? Should the portal integrate with billing or only hand off confirmed orders?
- [ ] **Inventory:** Can you share a representative Excel inventory file? Does it contain SKU, batch number, expiry date, units, and stock quantity? Who enters new receipts, and how are counter/phone/driver sales deducted?
- [ ] **Payments:** Are all orders paid on delivery, or do some stores use credit accounts, bank transfer, or UPI? Who records collections and reconciles unpaid orders?
- [ ] **Staffing and permissions:** Who is the daily inventory owner? Who can enter stock, approve corrections, confirm orders, pack orders, and act as backup when the owner is absent?
- [ ] **Returns and rejected deliveries:** What happens when a medical store rejects, returns, or reports damaged medicines? Who inspects and authorizes stock to become sellable again?
- [ ] **Pilot rollout:** Which 5–10 medical stores can test the portal first? Who will train them, collect feedback, and approve going live?

### Evidence to collect

- [ ] A sample inventory spreadsheet (remove sensitive information if necessary).
- [ ] A redacted wholesale GST invoice and the name of the existing billing system.
- [ ] An example of an order that could not be fulfilled because the requested medicine was out of stock.
- [ ] If available, a typical delivery route sheet or dispatch note.

### Record the outcome

| Question | Client answer / current practice | Decision owner | Follow-up / deadline |
| --- | --- | --- | --- |
| Order fulfilment | Pending | | |
| Pricing | Pending | | |
| Invoicing | Pending | | |
| Inventory and Excel | Pending | | |
| Payments and credit | Pending | | |
| Staff ownership | Pending | | |
| Returns | Pending | | |
| Pilot stores | Pending | | |

**Important:** Do not treat suggested MVP workflows as approved until the distributor validates them and the launch-critical decisions are signed off.
