# Inventory cutover and reconciliation plan

**Status:** Design proposal, not approved for production. The existing product-level stock and checkout remain authoritative. Do not switch to batch availability until every gate below is complete.

## Evidence required from the wholesaler

Request a sanitized real Excel export with SKU, item/pack, quantity, batch number, expiry, selling unit and any reserved or damaged quantities. Ask staff to demonstrate one receipt, one counter sale, one return, and a physical stock count. Confirm whether stock quantities are packs, strips, tablets or cases and how pack conversion works.

## Inventory accounting invariants

- Legacy product stock is currently the checkout-available balance, not necessarily physical on-hand.
- Batch on-hand represents physical units; batch reserved represents active order commitments.
- Eligible sellable = sum of unexpired, approved, non-quarantined batch (on_hand - reserved), with consistent units.
- Existing pending and accepted orders must be accounted for exactly once at cutover; they cannot be double-reserved or released twice.
- Never infer batch/expiry from aggregate product stock. Unknown provenance requires a physically verified batch or quarantine.
- Every receiving, reservation, release, adjustment and quarantine operation must have an actor and audit event.

## Controlled cutover sequence

1. **Stage and snapshot.** Export products, open orders/items, inventory events, settings and buyer state to a secured staging copy. Record a restore point and restore it successfully.
2. **Map units.** Validate SKU uniqueness, unit/pack conversion, batch, expiry, quantity and approval flags. Reject missing/ambiguous batch data; never manufacture expiry dates.
3. **Freeze mutations.** Disable checkout and pause Excel imports, phone/counter stock edits and order transitions for a short, communicated maintenance window. Record all incoming offline transactions for replay.
4. **Reconcile physical counts.** For each SKU, count eligible physical units, quarantined/expired units, and open reservations. Investigate differences from legacy available stock before proceeding.
5. **Allocate open orders.** Assign each open order item to eligible batches in FEFO order, preserving order identifiers and statuses. Mark physically picked units separately when packing is introduced. Reject cutover if any allocation cannot be reconciled.
6. **Verify invariants.** For each SKU, expected sellable equals reconciled eligible physical minus allocated active reservations and other holds. No negative quantities, duplicate allocations or orphaned reservations.
7. **Switch atomically.** Deploy the batch-aware reservation/release implementation, catalog read model, staff receiving workflow and tests as one versioned release. Do not allow legacy `upsert_inventory` to overwrite availability after the switch.
8. **Replay and monitor.** Replay logged offline sales idempotently, compare against the physical ledger, run two-person sign-off and enable checkout only after verification.
9. **Rollback.** If discrepancies appear, disable checkout immediately. Restore the last consistent backup into staging for investigation; do not blindly roll back a live DB after real orders have been accepted. Reconcile those orders before any controlled recovery.

## Required automated tests before enabling checkout

- Two simultaneous buyers competing for the last eligible batch: only one succeeds.
- Cart with one insufficient SKU: zero reservations are committed for the whole cart.
- Repeated idempotency key returns the same order and does not reserve twice.
- Buyer cancellation, staff cancellation and pending expiry release each batch reservation once.
- Confirmed orders do not auto-expire.
- Expired, quarantined, disputed and recalled batches never appear in sellable availability.
- FEFO chooses earliest eligible expiry, with documented exceptions.
- Staff-assisted orders and counter sales use the same transaction path.
- Receipt retries with the same source identity cannot duplicate stock.
- Excel import refuses blind stock overwrites and conflicting units.
- Returns enter quarantine; only authorized inspection can release them.
- Database RLS and RPC permissions prevent buyers or unprivileged staff from mutating inventory.
- Staging migration and rollback rehearsal passes with representative Excel and open orders.

## Decision gate

The owner, inventory manager, warehouse staff and authorized compliance reviewer must sign off on reconciled opening stock, expiry/eligibility rules, roles, invoice handoff and operational fallback. Until then, the batch tables remain **shadow data** and checkout must not be switched to them.
