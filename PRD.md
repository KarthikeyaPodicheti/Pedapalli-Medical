# Pedapalli Medical — Product Requirements Document

**Version:** 1.0 — comprehensive discovery baseline  
**Date:** 11 October 2026  
**Product:** Single-distributor B2B pharmaceutical wholesale ordering and inventory platform  
**Location:** Peddapalli, Telangana, India  
**Repository:** `KarthikeyaPodicheti/Pedapalli-Medical` (`main`)  
**Status:** **Draft for client validation; NOT approved for production**  
**Sources:** 30-round product discovery; project discussions; `clientMeeting.md`; `PRODUCTION.md`; `UX_AUDIT.md`; current `src/App.tsx`, `src/Admin.tsx`, `src/api.ts`, `src/types.ts`, `src/validation.ts`, and Supabase SQL migrations reviewed 11 October 2026.

> **Decision provenance:** The user/developer selected a proposed design during discovery. These selections are not proof that the wholesaler has accepted the business process. The current code is not proof of runtime correctness. Each requirement below is marked **D** (discovery decision), **R** (existing repository behavior), **P** (proposed design elaboration), or **C** (client confirmation required). When a decision is both D and C, implement only after operational validation.

---

## 1. Executive summary

Pedapalli Medical is a B2B ordering and inventory platform for **one pharmaceutical wholesaler/distributor**, not a marketplace, multi-tenant SaaS platform, or consumer pharmacy. Today, a van driver visits medical stores, writes down medicine requirements, returns to the warehouse, and discovers that some requested medicines are unavailable. This wastes visits and creates incomplete orders, delays, callbacks, and customer dissatisfaction. The wholesaler currently tracks inventory in Excel.

The product will give **approved medical-store buyers** visibility into **exact sellable stock**, permit ordering in valid wholesale units, and reserve inventory atomically when an order is placed. The same inventory must also account for phone, counter, driver-assisted, and staff-created orders. Warehouse users will receive stock, control batches and expiry, resolve discrepancies, and manage order fulfilment. A controlled pilot will precede broader rollout.

**North-star outcome:** reduce the proportion of orders affected by stock unavailability, measured as `orders affected by stock shortage / total orders × 100`, with a baseline collected before rollout. Product success depends on inventory discipline and buyer adoption, not just launching a website.

**Release principle:** operational MVP first; offline driver workflows, signed proof of delivery, sophisticated returns, and payment reconciliation later. No fixed launch date has been committed. Go live only when agreed launch gates pass.

## 2. Problem, context, and hypotheses

### 2.1 Current workflow (observed through discovery; client walkthrough pending)
1. Medical stores need medicines from the distributor.
2. The distributor's van driver visits stores and manually records requested items and quantities.
3. The driver returns to the warehouse; staff check stock after collecting the order.
4. Requested medicines may be unavailable, so the order cannot be fulfilled as expected.
5. The distributor must communicate shortages, adjust orders, or defer supply; the precise real-life policy is **not yet confirmed**.

### 2.2 Core problems
- Buyers do not know real availability before ordering.
- Offline/phone/driver sales can make displayed stock stale.
- Excel stock changes are difficult to reconcile with live reservations.
- Manual transcription causes delays and errors.
- Unclear ownership of inventory updates and shortage resolution creates operational risk.
- Pharmaceutical batches, expiry, quarantines, and compliance require stricter controls than ordinary retail inventory.

### 2.3 Product hypotheses
- Showing exact *sellable* stock to verified stores will reduce shortage-related order failures.
- A single reservation ledger for online and staff-assisted orders will prevent overselling.
- A named inventory owner and audited stock movements will improve accuracy.
- Gradual onboarding plus assisted ordering will preserve access for less digitally active stores.

### 2.4 Goals
**G1:** Reduce stock-related order failures.  
**G2:** Let approved stores discover and order medicines without unnecessary driver visits.  
**G3:** Make inventory accurate, batch-aware, and auditable.  
**G4:** Preserve existing customer relationships and support offline ordering channels.  
**G5:** Give staff a manageable order-to-dispatch workflow.  
**G6:** Launch a secure, legally reviewed, low-cost controlled pilot.

### 2.5 Non-goals
- No B2C/direct-to-patient retail ordering.
- No multi-distributor marketplace or general SaaS onboarding.
- No assumption that the platform replaces the existing GST billing software.
- No automatic medicine substitution or silent quantity reduction.
- No guaranteed offline driver application, proof-of-delivery capture, or automated financial reconciliation in MVP.
- No unrestricted access to regulated products or unapproved buyers.

## 3. Stakeholders, users, and permissions

| Persona | Need | Proposed authority / limits |
| --- | --- | --- |
| Distributor owner/admin | See operations, approve buyers, manage policy | Broad configuration and audit access; cannot bypass compliance controls without recorded authority |
| Medical-store owner/buyer | Search stock, order, review history | Only approved business account, its own orders, approved pricing, and permitted delivery addresses |
| Inventory manager | Receive and reconcile inventory | Batch receipt, quarantine, expiry and adjustments with reasons and audit trail |
| Authorized backup warehouse staff | Keep operations moving during absence | Limited delegated stock changes, all attributed to individual account |
| Order manager/sales | Enter phone/driver orders and fulfil orders | Assisted order entry, confirmation, shortage resolution, picking/packing |
| Dispatch/driver | See assigned deliveries and outcomes | Basic MVP delivery status; advanced offline workflow deferred |
| Pharmacist/compliance authority | Approve eligible catalog and regulated handling | Independent product eligibility, prescription/other evidence rules subject to legal review |
| Developer/operations owner | Maintain platform | Infrastructure, monitoring, backup, deployment; no routine access to unnecessary customer data |

**D:** individual staff accounts and role-based access; **R:** database roles currently include `owner`, `sales`, `inventory`, `dispatch`, `pharmacist`, and `staff`. **Gap:** current admin UI largely checks staff membership, not a complete role-specific menu/action matrix. Product approval must be separated from inventory editing.

## 4. Release scope and prioritization

| Capability | MVP / Phase 1 | Later phase | Notes |
| --- | --- | --- | --- |
| Verified business onboarding | Yes | Multi-branch enhancements | Manual approval and licence checks |
| Gated catalog, search, stock, pricing | Yes | Personalized recommendations | Exact sellable stock for approved buyers |
| Product-specific MOQ/units/steps | Yes | Advanced case/pack handling | Actual selling units require client confirmation |
| Atomic orders and reservations | Yes | More advanced allocation | One authoritative inventory system |
| Assisted staff/driver order entry | Yes | Offline mobile capture | Must share reservation transaction |
| Batch/expiry, quarantine, FEFO | Yes | Recall automation and deeper traceability | Compliance-reviewed rules |
| Excel import and manual receipts | Yes | ERP/POS integration | Additive receipts; no blind overwrites |
| Staff order workflow and basic dispatch | Yes | Route optimization | Delivery SLA still open |
| Basic notifications and history | Yes | Rich automation | Providers and language open |
| Customer cancellation before packing | Yes | Rich self-service changes | Staff approval once packing begins |
| Advanced search | Yes | Saved lists / quick reorder enhancements | Quick reorder valuable; advanced saved lists can follow |
| Driver offline sync and POD | No | Yes | Explicitly deferred from MVP |
| Full returns/reconciliation | Basic quarantine safety | Yes | Financial and delivery integration later |
| Native GST invoice engine | Not assumed | Possible | Existing billing handoff pending |
| Credit accounts/customer pricing | Not assumed | Possible | Client decisions outstanding |

**MVP boundaries:** buyer access, accurate sellable stock, reservation, assisted ordering, batch/expiry, inventory updates, essential staff operations, basic delivery status, and RBAC must work reliably together. Avoid adding complex driver and finance features before this is proven.

## 5. End-to-end journeys

### J1. Buyer onboarding
1. Buyer signs in through approved authentication and submits legal business name, contact, phone, email, registered address/PIN, an optional GSTIN, and required drug-licence information.
2. Account remains **pending**; no wholesale prices, sellable stock quantities, or ordering until approved.
3. Authorized reviewer checks the business and applicable licences using a client-approved verification process, records reviewer, date, outcome, and reason.
4. Approve, reject, suspend, or reactivate through auditable transitions. Define licence re-verification/expiry handling with the client.
5. An approved business sees only its own data. Multi-user/multi-branch permissions remain a follow-up decision.

### J2. Buyer searches and places order
1. Buyer searches by brand/name, generic/composition, manufacturer, strength, dosage form, SKU, and availability; selects quantity in the product's allowed selling unit.
2. Catalog displays exact **sellable** quantity (not gross physical stock), MOQ, step, pack information, current approved price and restrictions.
3. Cart shows items, quantity, current pricing, minimum order shortfall, delivery/pickup availability, fees, address, and estimated total.
4. On submit, the database revalidates account, product eligibility, quantities, current price, fulfilment, and stock; it reserves atomically and returns one order reference. Idempotency protects retries.
5. If stock has changed, reject the affected request without partial silent fulfilment; show actual remaining stock and invite the buyer to revise.
6. Pending order awaits wholesaler confirmation; notification and history reflect current status.

### J3. Assisted order
1. Authorized staff identifies an existing approved medical-store business.
2. Staff records phone/van/counter order with order origin, staff actor, buyer, items, and agreed delivery details.
3. Same pricing, unit, eligibility, stock, and atomic reservation rules apply as online checkout.
4. Buyer can see assisted orders in their history; any offline sales not yet entered must be reconciled promptly under a defined SLA.
5. Every assisted order is attributable to staff; no shared accounts or silent stock deductions.

### J4. Warehouse receipt and stock adjustment
1. Inventory manager receives stock against a delivery/receipt reference, identifying SKU, batch, expiry, unit, quantity, and supplier/source as required.
2. System validates product identity, pack conversion, expiry, duplicates, and permissible status before posting a **positive receipt movement**.
3. Excel import has preview, row-level validation, duplicate detection, explicit import mode, and a summary of proposed changes. Receipts **add** to stock; a reconciliation adjustment must be a separate explicit, approved action.
4. Quarantine, damage, expiry, recalls, or discrepancies move quantity out of sellable stock without deleting history.
5. Backup staff may record only delegated actions, with reason and actor logged.

### J5. Pick, pack, dispatch, deliver
1. Staff confirms a pending order before its defined expiry deadline.
2. Warehouse picks eligible batches using FEFO where appropriate, subject to client-approved minimum remaining shelf-life and any buyer-specific restrictions.
3. Picking/packing status is recorded; quantities and batch allocations are reconciled.
4. Dispatch records delivery mode, assignment/reference where available, and basic outcome; payment collection is not automatically assumed from delivery success.
5. Complete the order only through an allowed transition; maintain history and evidence.

### J6. Shortage or discrepancy
1. A physical count or batch issue reveals a shortage after reservation.
2. Immediately stop advertising the disputed quantity; protect other valid reservations from accidental release.
3. Notify authorized staff; buyer must choose to **wait** or **revise** the affected order. No automatic substitutions or silent reductions.
4. If revision is selected, recompute price, reservation and fulfilment eligibility transactionally, record consent and audit history.
5. If waiting is selected, hold the order under an explicit policy and escalate stale orders; do not fabricate available stock.

### J7. Cancellation and expiry
1. Buyer may cancel directly **before packing begins**; after packing starts, staff approval is required.
2. Unconfirmed pending orders may expire after a **configurable client-approved** deadline; confirmed orders must not expire arbitrarily.
3. Cancellation/expiry releases eligible reservations **exactly once**, with atomic state transitions and audit records.
4. Any picked/packed physical goods require reconciliation before stock becomes sellable again; cancelled does not automatically mean physically returned.
5. Buyer is informed of cancellation/expiry and reason; retry/reorder is available when eligible.

### J8. Return or rejected delivery
1. Returned/rejected medicines are recorded with order/batch/quantity/reason and moved into **quarantine**, not directly to available stock.
2. Authorized inspector determines disposition: return to sellable, damaged, expired, supplier return, or disposal as permitted.
3. Decision, actor, time, evidence, and inventory movement are auditable. Full financial credit-note handling is deferred pending billing decisions.

## 6. Functional requirements

Each item uses **FR-ID**, priority (`Must`, `Should`, `Later`), provenance, and acceptance expectation.

### 6.1 Identity, buyer verification, and access
- **FR-001 (Must; D/R):** Business-only account registration; collect legal identity, optional GSTIN, required drug licence, contact, and address. Reject malformed inputs; verification is manual, not just a regex check.
- **FR-002 (Must; D/R):** Pending/rejected/suspended businesses cannot see protected prices, exact stock, or create orders; enforce via backend/RLS, not only hidden UI.
- **FR-003 (Must; P/C):** Review records must include reviewer, verification checklist, timestamp, and rejection/suspension reason; licence re-verification policy is client-defined.
- **FR-004 (Must; D/R):** Individual staff identities with least privilege, role-scoped APIs and audit trails; require MFA for production staff as specified in runbook.
- **FR-005 (Should; C):** Support approved branch users and multiple shipping addresses only after ownership/verification rules are confirmed.

### 6.2 Catalog and search
- **FR-010 (Must; D/R):** Approved catalog fields: SKU, brand/name, generic/composition, strength, manufacturer, dosage form, pack, category, regulatory eligibility, MRP, wholesale price, MOQ, step, unit and available quantity; field availability depends on actual Excel data.
- **FR-011 (Must; D):** Search across brand/name, generic, manufacturer, strength, form, and SKU; filter by orderable stock; handle spelling/alias needs as a usability enhancement.
- **FR-012 (Must; D):** Display **exact sellable quantity** to approved stores; never display total physical quantity as orderable quantity.
- **FR-013 (Must; D/R):** Validate per-product selling unit, case conversion, MOQ and increments on both client and server; no fractional or ambiguous pack conversions.
- **FR-014 (Must; P/C):** Prevent sale of inactive, unapproved, expired, quarantined, recalled, or otherwise ineligible products/batches.
- **FR-015 (Should; D):** Buyer order history and quick reorder; saved shopping lists may be post-MVP.
- **FR-016 (Should; P):** Paginate/search server-side as real SKU volume grows; browser-side filtering is a pilot limitation.

### 6.3 Inventory, batches, and movements
- **FR-020 (Must; D):** Portal is the primary inventory ledger after controlled cutover; Excel seeds and supplements imports, not a competing live master.
- **FR-021 (Must; D):** Record SKU + batch + expiry + on-hand + status/location as applicable; preserve provenance of each stock movement.
- **FR-022 (Must; D/P):** `sellable = eligible on-hand − active reservations − other eligible holds`, computed without double-counting. Expired, quarantined, damaged, recalled and disputed quantities are ineligible. Never allow negative sellable stock.
- **FR-023 (Must; D):** Manual receipts and Excel imports; receipts are additive; adjustment/reconciliation is explicit and audited. Import must not blindly overwrite stock or consume existing reservations.
- **FR-024 (Must; D):** Inventory manager owns accuracy; authorized backup staff may act under scoped permissions; each mutation captures actor, reason, source, timestamp, and before/after or delta.
- **FR-025 (Must; D):** Near-expiry alerts, expired-stock blocks, quarantines, and FEFO picking where appropriate. Thresholds and exceptions require client/compliance sign-off.
- **FR-026 (Must; D):** Safety-first discrepancy handling: stop offering disputed quantity, investigate, and use authorized audited adjustments without invalidating reservations silently.
- **FR-027 (Must; D):** Returned goods enter quarantine; inspection and authorization precede re-entry to sellable stock.
- **FR-028 (Should; P):** Stock ledger reporting: receipts, adjustments, reservations, release, pick, dispatch, return, quarantine, expiry and actor filters.
- **FR-029 (Must; P):** Migration from product-level `stock` to batch-level ledger must preserve existing products, audit history and open orders; reconcile and freeze stock changes during controlled cutover as needed.

### 6.4 Orders, reservations, and shortages
- **FR-030 (Must; D/R):** All online and assisted orders use one authoritative atomic reservation process; no overselling under concurrent checkout.
- **FR-031 (Must; D/R):** Use stable idempotency keys and request fingerprints; retries return the same order, not duplicate reservations.
- **FR-032 (Must; D):** Do not partially accept an order or silently reduce quantity. On shortage, explain affected item(s) and remaining quantity; buyer decides whether to revise or wait after a post-order shortage.
- **FR-033 (Must; D):** Pending unconfirmed orders can expire on a configurable deadline; confirmed orders are protected from arbitrary automatic expiry.
- **FR-034 (Must; D):** Buyer cancellation is self-service until packing starts; thereafter staff approval. Cancellation must reconcile batch reservations and physical goods.
- **FR-035 (Must; P):** Explicit order states at least `pending`, `accepted`, `picking`, `packing`, `ready_for_dispatch`, `out_for_delivery`, `completed`, `cancelled`, `expired`, plus `shortage_review` if workflow requires; final state machine subject to warehouse walkthrough.
- **FR-036 (Must; D):** Staff-assisted order entry for approved businesses with source/actor attribution and identical inventory safeguards.
- **FR-037 (Must; P):** Price, taxes/fees, quantities, unit and business identity are snapshotted at order creation; later catalog edits cannot silently change historical orders.
- **FR-038 (Should; P):** Buyers and staff can view time-stamped order events, reasons, and buyer decisions.

### 6.5 Fulfilment, delivery, and payments
- **FR-040 (Must; D/C):** Basic order management and delivery status; exact delivery route, cutoff, pickup, transporter, and service PIN rules are client decisions.
- **FR-041 (Must; D/C):** Initial payment assumption is payment on delivery; current code also offers bank transfer. Credit accounts, UPI collection and reconciliation must be confirmed before enabling them.
- **FR-042 (Must; C):** GST invoice creation vs handoff to existing software is undecided. Do not generate an official invoice numbering system without accounting/compliance sign-off.
- **FR-043 (Should; P):** Delivery and payment status are distinct; `delivered` must not automatically imply `paid`.
- **FR-044 (Later; D):** Driver assignment, offline delivery list, status updates, sync on reconnect, conflict handling and idempotent replay.
- **FR-045 (Later; D):** Offline-capable proof of delivery via signed-invoice photo or recipient signature; preserve evidence independently of payment evidence.
- **FR-046 (Later; D):** Full return and collection reconciliation with audit and billing integration.

### 6.6 Notifications, reporting, administration
- **FR-050 (Must; R/P):** Notify relevant buyers/staff for application decisions, order creation, confirmation, cancellation, expiry, shortages, dispatch and delivery, according to approved templates/channels.
- **FR-051 (Must; C):** Production sender email, WhatsApp provider/templates, notification languages and support escalation require client approval.
- **FR-052 (Must; D):** Dashboard reports total orders, stock-affected orders, affected rate, order sources, reservation expiries, and inventory discrepancies; provide date range and buyer/channel breakdown where lawful.
- **FR-053 (Should; P):** Low-stock and near-expiry alerts; avoid alert fatigue through configurable thresholds.
- **FR-054 (Must; P):** Admin can disable checkout and invoke documented manual fallback during incidents.
- **FR-055 (Must; P):** Auditable role changes, buyer approvals, catalog eligibility changes, inventory movements and order transitions.

## 7. Stock and reservation model

### 7.1 Terminology
- **Physical/on-hand:** quantity physically held in a location/batch, including non-sellable stock.
- **Eligible:** physically held, unexpired, approved, not recalled/quarantined/disputed, and satisfying remaining-shelf-life rules.
- **Reserved:** eligible units committed to pending/confirmed orders, not yet consumed/released.
- **Sellable:** eligible on-hand less active reservations and other holds, in a consistent base unit.
- **Picked/packed:** physically allocated to an order; not available for other buyers.
- **Quarantined:** unavailable until authorized inspection/disposition.

**Illustration:** 100 strips physical, 40 reserved, 20 held due to near expiry, **40 strips displayed sellable**. This is a conceptual example; the exact hold threshold is configurable and must be confirmed.

### 7.2 Required invariant examples
- For each batch, `sellable >= 0`; no two orders can reserve the same units.
- Reserving a cart is all-or-nothing across products/batches within a database transaction.
- Reservation creation, cancellation, expiry and order-state changes are idempotent.
- Every change has a movement/event trail; no silent replacement of quantity.
- Product-level displayed sellable quantity equals the sum of eligible batch sellable quantities after unit conversion.
- Batch allocations remain traceable to orders and are revalidated at picking.

### 7.3 Proposed data entities (design, not existing schema)
`product`, `product_pack_conversion`, `inventory_batch`, `stock_movement`, `stock_hold`, `reservation`, `reservation_line`, `order`, `order_line`, `order_event`, `pick_line`, `buyer_business`, `buyer_user`, `staff_member`, `role_permission`, `receipt`, `import_job`, `return_case`, `delivery`, `payment_record`, `notification_outbox`, `audit_event`.

Recommended movement types: `opening_balance`, `receipt`, `adjustment_positive`, `adjustment_negative`, `reservation_created`, `reservation_released`, `pick`, `dispatch`, `return_to_quarantine`, `quarantine_released`, `expiry_block`, `recall_hold`, `writeoff`. Separate quantity changes from state-only events so reporting cannot double count stock.

### 7.4 Unit rules
Define **base inventory unit** per SKU and explicit conversions for strip, box, bottle, case or other packaging. A product may be sold only in allowed unit(s), with a configured MOQ and step. Validate conversions and rounding at import, order, receipt, and invoice handoff. Whether the wholesaler sells loose strips or whole packs is **C — unresolved**; never assume all medicines share a unit.

## 8. Proposed state machines and rules

### 8.1 Buyer status
`pending → approved | rejected`; `approved → suspended`; reactivation only through authorized review and evidence. Expired/revoked licences may require suspension under a client-approved rule.

### 8.2 Order status
`pending → accepted | cancelled | expired`; `accepted → picking → packing → ready_for_dispatch → out_for_delivery → completed`. Additional exception paths: `shortage_review`, `cancel_requested`, `failed_delivery`, `returned`. Final transition permissions and dispatch stages are **C**.

**Cancellation guard:** before `packing` begins, eligible buyer self-cancellation; at or after packing begins, staff authorization and stock reconciliation. For `pending` expiry, scheduled worker transitions once and releases reservation once. A shortage does not silently alter order lines.

### 8.3 Stock states
`received_pending_check → sellable | quarantine`; `sellable → reserved/picked | quarantine | expired | recalled`; `quarantine → sellable` only after authorized inspection, or `writeoff/supplier_return`. Expiry must be enforced by time-sensitive eligibility logic even if a scheduled job is delayed.

## 9. Business rules and edge cases

| ID | Scenario | Expected behavior |
| --- | --- | --- |
| BR-01 | Two stores order 40 and 30 while 50 are sellable | Atomic allocation permits no more than 50 total; losing request receives updated availability |
| BR-02 | Buyer double-clicks checkout or network retries | Same idempotency key returns one order/reference |
| BR-03 | 100 physical, 40 reserved, 20 held | Buyer sees 40 sellable, not 100 |
| BR-04 | Excel receipt adds 20 to an existing batch | Post +20 receipt movement; do not replace existing total with 20 |
| BR-05 | Staff detects disputed stock | Remove disputed quantity from new availability; protect existing commitments and escalate |
| BR-06 | Order pending beyond approved deadline | Expire once, release once, notify buyer |
| BR-07 | Buyer cancels before packing | Authorize cancellation, release reservation exactly once |
| BR-08 | Buyer cancels after packing begins | Request staff approval; reconcile picked goods before returning sellable |
| BR-09 | A reserved batch becomes expired or recalled | Stop fulfilment, trigger shortage/reallocation workflow and buyer choice; no silent substitution |
| BR-10 | Store rejects delivered medicines | Quarantine; inspect before any resale |
| BR-11 | Assisted order overlaps online checkout | Same transactional reservation; no bypass |
| BR-12 | Price changes after order | Preserve agreed order snapshot; changes to order require explicit approval/repricing policy |
| BR-13 | Internet fails during checkout | Retry with same idempotency key; show definitive server status before allowing a new order |
| BR-14 | Delivery recorded but cash not collected | Delivery and payment states remain separate |
| BR-15 | Product quantity is below MOQ | Not orderable; communicate below-MOQ status |
| BR-16 | Import contains duplicate SKU, invalid batch/expiry, or inconsistent units | Reject affected rows or whole job under explicit validated import policy; do not partially corrupt stock |
| BR-17 | Buyer is suspended while order pending | Prevent new orders; define treatment of existing orders with compliance owner |
| BR-18 | Driver reconnects with repeated offline event (later) | Deduplicate using event identity; no duplicate payment, return or delivery event |

## 10. User experience requirements

- Mobile-first for pharmacy buyers and warehouse users; simple high-contrast search, readable stock/pack units, large tap targets, and clear errors.
- Show buyer approval status and next steps; avoid exposing restricted catalog information to unapproved users.
- Search should prioritize brand/composition and allow quick adjustment to MOQ/step.
- Cart clearly shows order total, delivery fee, selected fulfilment, business address, and restrictions before submission.
- Explain changed stock with actionable next step rather than generic checkout failure.
- Orders page shows timeline, items, quantities, pending action, cancellation eligibility and support contact.
- Staff workspace has role-specific navigation and workflows rather than a single unrestricted admin surface.
- Excel import must preview changed rows and clearly distinguish **receipt**, **catalog update**, and **inventory adjustment**.
- Telugu/Hindi support is **C**; do not promise language localization until the client identifies the target languages.
- Accessibility: keyboard-operable controls, dialog labels, visible focus, sufficient contrast, 44px target guidance, useful error announcements.

## 11. Non-functional requirements

### 11.1 Security and privacy
- Supabase Auth, row-level security, backend-authoritative checks, least-privilege staff roles and production MFA.
- Turnstile on sign-in/application paths; verify sensitive requests server-side; keep service-role credentials out of browser/build variables.
- Separate buyer records and enforce business-scoped access at the database/API layer.
- HTTPS, secure secrets management, controlled access to licences/contact data, logs without unnecessary sensitive content, and documented access revocation.
- Preserve audit events for high-risk actions; retention periods and privacy notices require client/legal review.

### 11.2 Correctness and reliability
- Atomic multi-line reservation, safe concurrency, idempotent retries, monotonic audit history and no negative sellable stock.
- Database constraints and transactions must remain authoritative if UI state is stale.
- Scheduled expiry and notification jobs must tolerate retries and failures.
- Avoid irreversible quantity overwrites; every correction must be explainable and traceable.
- Separate staging and production; production checkout remains disabled until sign-off.

### 11.3 Performance and scalability
- Pilot should work on typical Android phones and local mobile connections; exact performance SLOs, SKU count, store count and peak order volume require measurement.
- Server-side search/pagination and indexes become necessary as real catalog grows.
- Avoid promising uptime/SLA on the proposed free-tier architecture.

### 11.4 Availability, backup, and disaster recovery
- Current runbook proposes Cloudflare Free + Supabase Free, encrypted daily PostgreSQL/Auth backups to private R2, checksum verification and monthly restore rehearsal.
- Named operations owner checks quotas, alerts and backup status; client must approve retention, recovery expectations, downtime tolerance and upgrade triggers.
- Fallback during outages: staff phone/WhatsApp, controlled manual/Excel capture, later reconciliation; prevent duplicate orders after recovery.
- Upgrade planning thresholds in existing runbook include 80% quota use and 400 MB/80% database capacity; verify current provider limits before production.

### 11.5 Regulatory and financial controls
- Wholesaler and buyer drug-licence verification, responsible pharmacist approval, restricted catalog rules, prescription-related evidence, expiry/recall handling, GST invoice numbering, tax treatment, returns/credit notes, and record retention require review by the client's qualified legal/compliance/accounting owners.
- The PRD does not itself determine Indian pharmaceutical law or certify compliance.

## 12. Metrics and analytics

**Primary KPI (D):** stock-affected order rate = `number of orders affected by unavailable stock / total submitted orders × 100`. Define affected orders consistently, including post-confirmation shortages, and collect a prelaunch baseline from manual records if possible.

**Secondary metrics (P):** first-attempt fill rate, cancelled/expired reservations, discrepancy count and age, order confirmation time, picking accuracy, time from order to dispatch, online vs assisted order share, weekly active approved stores, repeat ordering, out-of-stock search frequency, near-expiry writeoffs, notification failure rate, and incident recovery time.

**Measurement design:** every order has source (`buyer_portal`, `staff_phone`, `staff_driver`, `counter`), created/confirmed timestamps, shortage reason/event, final status and actor. Do not equate a failed browser submission with an accepted order; define denominators before reporting.

## 13. Current repository assessment (11 October 2026)

| Area | Existing evidence | Gap / action |
| --- | --- | --- |
| Frontend | React 19, TypeScript, Vite; buyer catalog, cart, checkout, order history | Expand shortage/cancellation UX, staff-assisted entry, role-aware views |
| Authentication | Supabase email-link buyer sign-in; staff login | Confirm production SMTP, MFA, role action gating |
| Buyer verification | `buyer_businesses`, buyer review, protected catalog | Verification evidence/checklist, licence lifecycle, reasons |
| Orders | `create_b2b_order` RPC validates, locks products, uses idempotency; `transition_order` manages basic statuses | Batch-aware reservation, expanded state machine, buyer cancellation, staff-assisted order API |
| Inventory | Product-level `stock`, `upsert_inventory`, inventory event log, Excel/CSV import | Batch/expiry, quarantine, additive receipts, protected reservations and reconciliation |
| Staff roles | DB roles `owner`, `sales`, `inventory`, `dispatch`, `pharmacist`, `staff` | UI currently largely authorizes staff membership; separate compliance approval permissions |
| Fulfilment | Basic accepted/out-for-delivery/completed; own delivery/transporter/pickup options | Client-defined workflow, picking/packing, dispatch assignment, delivery records |
| Notifications | Notification delivery/outbox history, maintenance workflow | Confirm provider, templates, buyer expiry/shortage messages |
| Payments | COD and bank transfer options in current UI/config | Confirm credit/UPI reality, separate collection records, invoice handoff |
| Testing | Vitest, Playwright, DB test scripts and deployment verification commands | Execute in configured staging; add batch/concurrency/expiry/returns/permissions tests |
| Deployment | Cloudflare Workers, Supabase, Turnstile, R2 backup runbook | Accounts, credentials, real data, pilot sign-off; currently not production-approved |

**Important technical mismatch:** current SQL `upsert_inventory` sets `products.stock = new_stock` and logs the difference. This is not the desired additive batch receipt process. Current order reservation decrements product-level `stock`, whereas the desired model needs physical/eligible/reserved distinctions and batch allocations. Migration must avoid double-subtracting previously reserved units.

**Additional known UX audit gaps:** prescription verification permissions need redesign; inventory staff can currently change pharmacist approval; expired reservations do not yet notify buyers; role-aware navigation, payment references, transporter assignment, pick lists and POD are incomplete. The October 10 audit reported improvements to checkout totals, buyer sign-out, stock filter, mobile targets, checkout detail and dialog accessibility; those improvements still require regression testing after inventory changes.

## 14. Implementation roadmap and dependencies

### Phase 0 — Discovery and sign-off
- Walk through a real order, delivery and stock receipt with the distributor.
- Obtain sanitized inventory spreadsheet, invoice, failed order example, and optional route sheet.
- Confirm legal identity, buyer eligibility, pricing, unit conversion, expiry thresholds, invoicing, payments, delivery and roles.
- Approve measurable pilot criteria and named decision owners.

### Phase 1 — Inventory foundation
- Design base units, batches, eligibility, movement ledger, holds and reservations.
- Migrate existing product stock and open reservations safely with reconciliation and rollback plan.
- Build additive receipt/import preview, audited adjustments, quarantine, expiry and FEFO logic.
- Add automated DB tests for stock invariants, multi-line concurrency, retries and stale reads.

### Phase 2 — Ordering and warehouse MVP
- Adapt checkout and assisted order API to batch reservations.
- Implement shortage review, customer cancellation before packing, expiry, staff approval and expanded states.
- Build picking/packing, basic dispatch, staff role-specific navigation, order events and buyer notifications.
- Add KPI dashboard and audit reports.

### Phase 3 — Controlled pilot
- Provision staging/production with approved credentials and policies; keep production checkout off until gates pass.
- Import verified catalog, train inventory owner and backup, reconcile physical stock.
- Pilot with approximately 5–10 consenting medical stores if client agrees; test online and assisted channels.
- Measure stock-failure baseline and pilot results, fix critical issues, document acceptance.

### Phase 4 — Post-MVP
- Offline driver workflow with conflict-safe sync; photo/signature POD; returns, collection reconciliation; advanced saved lists; ERP/billing integration, multi-branch or negotiated pricing only if validated.

**Dependency order:** client unit/batch sample → inventory model → reservation transaction → assisted orders and fulfilment → pilot. Building delivery automation before inventory correctness is explicitly discouraged.

## 15. Acceptance test catalogue

| ID | Test | Pass criterion |
| --- | --- | --- |
| AT-01 | Unapproved buyer attempts catalog pricing/order API | Access denied at backend/RLS |
| AT-02 | Concurrent last-stock checkout | No oversell; one consistent result per order |
| AT-03 | Checkout retried with same key | One order and one reservation |
| AT-04 | Expired/quarantined/recalled batch in stock | Excluded from displayed sellable and reservation |
| AT-05 | FEFO pick with valid batches | Oldest eligible expiry selected unless approved exception |
| AT-06 | Import receipt for existing batch | Additive movement; reservation remains correct |
| AT-07 | Import invalid unit/expiry/duplicate | Clear validation error; no partial silent corruption |
| AT-08 | Assisted order competes with portal order | Same atomic reservation guarantees |
| AT-09 | Buyer cancels before packing | Allowed; stock released exactly once |
| AT-10 | Buyer attempts cancellation during packing | Staff approval required; no immediate sellable release |
| AT-11 | Pending order expires; worker retries | One expiry event and one release |
| AT-12 | Confirmed order passes pending timeout | Not automatically expired |
| AT-13 | Post-reservation shortage | Buyer offered wait/revise; no silent partial order |
| AT-14 | Return received | Quarantined until authorized inspection |
| AT-15 | Unauthorized staff attempts inventory/compliance change | Backend denies; audit/security logs record as appropriate |
| AT-16 | Buyer accesses another business's order | Denied |
| AT-17 | Order created at old price then catalog changes | Order snapshot unchanged |
| AT-18 | Delivered without collected payment | Separate payment state remains unpaid/unknown |
| AT-19 | Restore encrypted backup into disposable environment | Verified recovery and documented result |
| AT-20 | Mobile pilot end-to-end with real devices | Usable registration, search, cart, checkout, staff flow |
| AT-21 | Notification provider temporarily fails | Retry/outbox prevents duplicate business event and records failure |
| AT-22 | Checkout disabled due to incident | New online orders blocked; manual fallback documented |

## 16. Open questions and decision register

### 16.1 Launch-critical client decisions

| ID | Decision needed | Owner to consult | Impact if unresolved |
| --- | --- | --- | --- |
| O-01 | Legal/trading name, logo, contact, domain, licences, GSTIN | Distributor | Cannot publish verified business identity |
| O-02 | Eligible buyer types, licence verification and recheck cadence | Distributor/compliance | Buyer access and legal risk |
| O-03 | Real Excel fields, batch/expiry availability, SKU identity, unit conversions | Inventory manager | Cannot finalize data model/import |
| O-04 | Wholesale pricing uniform vs negotiated, schemes, tax inclusion | Owner/accountant | Pricing engine and invoice mismatch |
| O-05 | Current GST billing software, invoice handoff, credit notes | Accountant/owner | Production invoicing blocked |
| O-06 | Payment on delivery, bank transfer, UPI, credit terms | Owner/accounts | Collection rules and reconciliation |
| O-07 | Van routes, order cutoff, delivery/pickup/transporter SLA | Dispatch/owner | Fulfilment and customer promises |
| O-08 | Who packs, when packing officially starts, cancellation SLA | Warehouse | Cancellation boundary cannot be enforced accurately |
| O-09 | Pending order expiry minutes and confirmation SLA | Owner/order manager | Reservation lock duration uncertain |
| O-10 | Minimum remaining shelf-life, recall, prescription/compliance checks | Pharmacist/compliance | Stock eligibility and dispatch risk |
| O-11 | Named inventory owner, backup, adjustment approval matrix | Owner | Audit/operating model incomplete |
| O-12 | Rejected/returned medicines, inspection and disposal | Warehouse/compliance | Unsafe restocking risk |
| O-13 | Buyer shortage wait/revise workflow and escalation times | Owner/sales | Customer consent and fulfilment ambiguity |
| O-14 | Pilot stores, expected SKUs/order volume, languages | Owner/buyers | Pilot design and scale unknown |
| O-15 | Policies, data retention, backup period, downtime tolerance, sign-off | Owner/legal/operations | Cannot activate production |

### 16.2 Secondary open questions
- Product-specific selling units: strips versus whole boxes/cases; conversion, MOQ, increments and price per unit.
- Whether all online orders require staff confirmation, and whether stock should remain reserved during prolonged manual review.
- Multiple buyers per store, multiple branches, alternate delivery addresses and delegated purchasing.
- Near-expiry visibility versus automatic exclusion, acceptable remaining shelf-life by product/buyer.
- How staff record offline sales during network outages and reconcile duplicate submissions.
- Which order statuses are shown to buyers versus internal staff.
- Whether credit limits, special rates, downloadable invoices, or schemes belong to later releases.
- Language preferences, notification consent and WhatsApp provider.
- KPI baseline period and definition of a shortage-affected order.

### 16.3 Client meeting plan
**45 minutes:** 0–5 problem; 5–15 walk through real order; 15–25 inventory/Excel; 25–35 pricing/billing/payment/delivery; 35–45 MVP and owners. Ask specifically about routes/cutoffs, pricing, GST invoices, Excel batches, payment/credit, inventory staffing, returns, and 5–10 pilot stores. Collect redacted Excel, invoice, stock-failure example, and route sheet. Record every answer in `clientMeeting.md` with decision owner and date.

## 17. Decision log — all 30 discovery rounds

**Legend:** These are developer/user product-design choices, **not client-approved policies**.

| # | Selected decision | Implication / caveat |
| --- | --- | --- |
| 1 | **A:** One wholesaler, B2B only | No marketplace or multi-wholesaler tenancy |
| 2 | Driver collects requests, warehouse later finds shortages | Product problem and baseline workflow |
| 3 | **B:** Reserve online orders immediately; record offline sales | Shared inventory authority |
| 4 | Inventory currently in **Excel** | Import/cutover and reconciliation |
| 5 | **A:** Portal becomes primary inventory; Excel initial import | Client approval needed for operational cutover |
| 6 | **D:** Delivery fulfilment process not discussed | Open client question |
| 7 | **B+C:** Gradual store adoption and assisted ordering | Support both channels |
| 8 | **A:** Business registration, licence details, manual approval | Gated B2B access |
| 9 | **D:** Uniform vs customer-specific pricing unknown | Open client question |
| 10 | **A:** Payment on delivery initially | Verify actual bank/UPI/credit arrangements |
| 11 | **C:** No silent partial fulfilment; store chooses wait/revise on shortages | Preserve buyer consent |
| 12 | **C:** Batch, expiry, alerts, quarantine and FEFO | Pharmaceutical inventory controls |
| 13 | **C:** Manual receipts + Excel; additive receipts, audited adjustments | Avoid blind overwrite |
| 14 | **B:** Returns quarantined and inspected before resale | Controlled disposition |
| 15 | **C:** Individual role-based accounts | Scoped staff permissions and audit |
| 16 | **C:** Complete driver workflow eventually | Assigned deliveries, status, collections, POD, returns |
| 17 | **B:** Driver offline operation eventually | Idempotent reconnect/sync |
| 18 | **B:** Signed-invoice photo or signature POD | Offline evidence, distinct from payment |
| 19 | **D:** GST invoicing method unknown | Open client question |
| 20 | **B:** Operational MVP; advanced driver/POD/returns/payments later | Strict phase boundary |
| 21 | **C:** No fixed deadline; reliability first | Avoid uncontrolled scope expansion |
| 22 | **A:** KPI is stock-related order failures | Baseline and consistent denominator |
| 23 | **A:** Dedicated inventory manager | Named accountability |
| 24 | **B:** Authorized backup staff can update stock | Audited delegated permissions |
| 25 | **C:** Safety-first stock discrepancies | Stop offering disputed stock |
| 26 | **C:** Advanced search plus history/reorder/saved lists | Saved lists may be later |
| 27 | **B:** Show exact sellable stock | Not gross physical quantity |
| 28 | **B:** Atomic database reservation | Concurrency safety |
| 29 | **C:** Cancellation + expiry for unconfirmed reservations | Configurable timeout, release once |
| 30 | **B:** Self-cancel before packing; staff approval after | Packing start is cancellation boundary |

## 18. Risks and mitigations

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Stale Excel or unrecorded offline sales | Critical | Single inventory ledger, assisted entry, daily reconciliation, named owner |
| Batch/expiry data missing from client spreadsheet | Critical | Inspect sample before schema finalization; controlled data enrichment and quarantine |
| Overselling through concurrent orders | Critical | Atomic database locks/transactions and idempotency tests |
| Regulatory/product eligibility mistakes | Critical | Independent pharmacist approval, restricted catalog, compliance sign-off |
| Incorrect GST invoices/taxes | High | Integrate/handoff to approved billing process; accountant validation |
| Overengineering driver features | High | Defer offline/POD and complex reconciliation until MVP proves value |
| Weak adoption among stores | High | Gradual rollout, staff-assisted orders, simple mobile UX, training |
| Free-tier downtime/limits | High | Quota alerts, backups, manual fallback, written acceptance and upgrade trigger |
| Unauthorized stock edits | High | RBAC, separate approval, audit trail, periodic review |
| Duplicate orders after network failures | High | Stable idempotency keys and server status recovery |
| Near-expiry or returned goods sold accidentally | Critical | Batch eligibility enforcement, quarantine, independent inspection |
| Scope decisions mistaken for client sign-off | High | Explicit open-question register and signed acceptance gates |

## 19. Definition of ready, definition of done, and launch gates

**Ready for implementation:** relevant client policy confirmed; workflow diagram accepted; source data available; role and compliance owner identified; acceptance criteria and edge cases specified; data migration impact assessed.

**Done for a feature:** backend enforcement, unit/integration tests, permission tests, mobile UX, accessible errors, audit events, documentation, migration/rollback plan and staging verification complete.

**Production launch gate:** legal identity/policies verified; eligible catalog and buyer checks approved; stock reconciled; batch/expiry and recall responsibilities assigned; payment/delivery/invoicing process signed off; staff trained; atomic reservation/cancellation/expiry tested; MFA/RLS/Turnstile verified; notification provider tested; encrypted backup restored; pilot accepted; owner/compliance sign-off documented. Until then, **checkout remains disabled**.

## 20. References and document control

- GitHub repository: `https://github.com/KarthikeyaPodicheti/Pedapalli-Medical`
- Client interview checklist: `clientMeeting.md` (updated 11 October 2026)
- Production runbook: `PRODUCTION.md`
- UX review and known launch blockers: `UX_AUDIT.md` (10 October 2026)
- Source files reviewed: `src/App.tsx`, `src/Admin.tsx`, `src/api.ts`, `src/types.ts`, `src/validation.ts`, `supabase/migrations/202610090001_b2b_foundation.sql`
- This document is a **product specification**, not a legal/compliance certification, signed statement of work, implementation guarantee, or approval to activate live pharmaceutical ordering.

**Next revision trigger:** update to v1.1 after the distributor walkthrough and collection of a representative inventory Excel file and invoice. Convert all relevant `C` items to recorded decisions, then finalize data model and acceptance tests.
