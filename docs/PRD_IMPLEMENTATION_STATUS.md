# PRD implementation — phase 1: batch inventory foundation

This branch introduces the first **database-only** increment for PRD FR-021, FR-023, FR-024, FR-025 and FR-027. It does **not** implement the full PRD.

## Implemented
- Batch number, expiry, status, on-hand and reserved columns with constraints.
- Additive stock receipt RPC, actor/source audit ledger, default quarantine on receipt.
- Authorized status transitions and release-to-sellable checks.
- Staff-only batch summary; RLS denies direct batch mutations.

## Explicitly not integrated
- Existing `products.stock`, `upsert_inventory`, `create_b2b_order`, reservation expiry and cancellation still operate on **product-level stock**.
- Batch ledger is a shadow ledger and is **not** the buyer-facing source of truth.
- No migration/backfill of existing product stock, batch allocation, FEFO, buyer cancellation UI, assisted ordering or staff batch screens.
- Existing production checkout remains blocked pending complete integration, client data and compliance sign-off.

## Next safe steps
1. Obtain sample client Excel with SKU, batch, expiry and selling-unit conversion; agree on stock cutover.
2. Build an explicit reconciliation/backfill plan, preserving active reservations and historical orders.
3. Implement one batch-aware atomic reservation and release path for online and assisted orders, then switch catalog availability.
4. Add batch receiving/quarantine admin screens, test all expiry and concurrency invariants, and pilot with real staff.

## Review and validation
Apply the new migration to a **disposable staging database** and test: receipt +5 twice yields +10, duplicate batch key does not duplicate rows, unauthorized writes fail, expired batches cannot be released, and staff-only summary excludes quarantined stock from sellable quantity. No tests have been executed in this change.

## Phase 1b — shadow FEFO allocation rehearsal (2026-10-11)

- Added `202610110002_shadow_batch_allocations.sql`: staff-private batch allocation rows and service-only allocation/release RPCs.
- Existing order items can be allocated atomically to eligible batches in expiry order; any shortage aborts the entire transaction.
- Added `supabase/tests/shadow_batch_allocations.sql` and connected both new migrations and test suites to `scripts/test-database.sh`.
- This is **not live checkout integration**. Product-level stock and reservation/expiry/cancellation remain authoritative; shadow allocations must not be used for real picking or buyer stock display.
- The rehearsal audit uses a designated owner account because the service actor is not a human; this attribution must be redesigned before production use.
- **Not executed**: database suite and concurrent-race tests; local Docker/Postgres binaries are unavailable. PR remains draft.
