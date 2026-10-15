# PRD implementation — phase 1: batch inventory foundation

`main` now includes the first shadow-ledger increment for PRD FR-021, FR-023, FR-024, FR-025 and FR-027, plus buyer cancellation and a staff batch-alert view. It does **not** implement the full PRD.

## Implemented
- Batch number, expiry, status, on-hand and reserved columns with constraints.
- Additive stock receipt RPC, actor/source audit ledger, default quarantine on receipt.
- Authorized status transitions and release-to-sellable checks.
- Staff-only batch summary; RLS denies direct batch mutations.

## Explicitly not integrated
- Existing `products.stock`, `upsert_inventory`, `create_b2b_order`, reservation expiry and cancellation still operate on **product-level stock**.
- Batch ledger is a shadow ledger and is **not** the buyer-facing source of truth.
- No migration/backfill of existing product stock, live FEFO checkout allocation, assisted ordering, or batch receiving/quarantine editing screens.
- Existing production checkout remains blocked pending complete integration, client data and compliance sign-off.

## Next safe steps
1. Obtain sample client Excel with SKU, batch, expiry and selling-unit conversion; agree on stock cutover.
2. Build an explicit reconciliation/backfill plan, preserving active reservations and historical orders.
3. Implement one batch-aware atomic reservation and release path for online and assisted orders, then switch catalog availability.
4. Add batch receiving/quarantine admin screens, test all expiry and concurrency invariants, and pilot with real staff.

## Review and validation
The merged migrations and regression tests pass locally against disposable PostgreSQL 17, including additive/idempotent receipts, multiple batches per receipt, RLS checks, quarantine isolation, balanced shadow allocation/release, buyer cancellation, returns, alerts and the concurrent last-stock test. A configured Supabase staging rehearsal with representative client data is still required.

## Phase 1b — shadow FEFO allocation rehearsal (2026-10-11)

- Added `202610110002_shadow_batch_allocations.sql`: staff-private batch allocation rows and service-only allocation/release RPCs.
- Existing order items can be allocated atomically to eligible batches in expiry order; any shortage aborts the entire transaction.
- Added `supabase/tests/shadow_batch_allocations.sql` and connected both new migrations and test suites to `scripts/test-database.sh`.
- This is **not live checkout integration**. Product-level stock and reservation/expiry/cancellation remain authoritative; shadow allocations must not be used for real picking or buyer stock display.
- The rehearsal audit uses a designated owner account because the service actor is not a human; this attribution must be redesigned before production use.
- Verified locally after merge on 15 October 2026; the database suite and concurrent last-stock test pass. The feature remains shadow-only until staging reconciliation and operational sign-off.

## 2026-10-11 implementation continuation

Added migrations `202610110003_receipt_idempotency.sql`, `202610110004_buyer_pending_cancellation.sql`, and `202610110005_batch_safety_operations.sql`. Added corresponding database regression scripts and wired them into `scripts/test-database.sh`. The buyer UI now exposes pending-order cancellation, and the staff UI has a staff-only batch-alerts panel.

**Verification status — 15 October 2026:** `npm test`, `npm run build`, `npm run test:db`, and `npm run test:e2e` pass locally; browser coverage passes on desktop and mobile. Deno is unavailable in the local executor, so Edge Function type-checking remains delegated to GitHub Actions CI. Supabase staging deployment and reconciliation have not been performed.

**Still required to meet the PRD MVP:** live batch-aware atomic checkout and cancellation/expiry ledger; authoritative sellable catalog stock; controlled Excel cutover with representative client data and opening-order reconciliation; same-ledger staff-assisted orders; full picking/packing/dispatch and shortage review; proper staff RBAC UI and verified approval evidence; inventory import mode split and unit normalization; return disposition; reporting/KPIs; payment and billing handoff; notification templates/provider configuration; concurrency/security/E2E tests and actual CI evidence.

**Client sign-off blockers:** legal/regulatory and pharmacist rules, unit conversions, minimum shelf-life, exact Excel format, GST/invoice handoff, payment/fulfilment policy, notification sender/templates, staff identities, and acceptance of reconciled opening stock. Do not claim full PRD completion or enable checkout before these are resolved.
