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
