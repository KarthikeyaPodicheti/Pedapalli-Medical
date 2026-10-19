# PRD implementation status

## Local authoritative runtime — 19 October 2026

The repository now contains a new self-hosted Node.js/PostgreSQL foundation in
`server/` and `compose.yaml`. It is independent of the older Supabase shadow
ledger described below and follows the current local-only architecture decision.

Implemented in this slice:

- Separate password-authenticated buyer and staff account realms with HTTP-only,
  same-site sessions, durable login/register rate limits and exact-origin checks.
- Pending buyer application with optional GSTIN; wholesale prices and stock stay
  hidden until staff approval.
- Transactional, permission-checked buyer review with an audit record.
- Additive/idempotent batch receipt into quarantine and pharmacist-only release.
- Authoritative sellable stock, minimum shelf-life filtering and FEFO allocation.
- Atomic full-cart reservation, idempotent order retry, concurrency protection,
  and exactly-once cancellation/reservation-expiry release.
- Least-privilege API database role, immutable migration hashes, hardened local
  containers and same-origin Nginx proxying.
- Disposable database and whole-stack integration tests. `npm run test:server`,
  `npm run test:local-db`, and `npm run test:local-stack` pass locally.

Final verification for this slice: `npm run build` passed; 11 frontend unit
tests passed; the complete legacy PostgreSQL/RLS/concurrency suite passed; all
8 desktop/mobile Playwright journeys passed; 3 server security tests passed;
the new authoritative batch SQL and concurrent last-stock checks passed; the
disposable container-stack registration/access/checkout-gate test passed; and
both root and server `npm audit` reported zero known vulnerabilities. The build
still reports the existing ExcelJS chunk-size warning; it is a performance item,
not a failed release gate for this disabled-checkout foundation.

This is not a production release. Checkout is disabled by default. The current
container web image still serves the synthetic preview rather than a UI connected
to this API. Staff MFA, controlled Excel import and reconciliation, workflow
completion, backup/restore rehearsal, real client data, compliance acceptance and
pilot sign-off remain launch blockers.

## Earlier Supabase shadow-ledger history

> **17 October workspace recovery:** this checkout was restored from remote
> `main` (`f012bd5`). The previously reported local-only backend commit
> `a455926` is unavailable here and on GitHub. Its implementation and earlier
> verification must not be treated as present in this checkout. See
> [WORKSPACE_RECOVERY.md](WORKSPACE_RECOVERY.md) for recovery scope and current
> baseline test results. The user's local-only architecture supersedes the
> older hosted-infrastructure references below.

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

## Buyer/admin access separation — 19 October 2026

- Buyer sessions no longer show staff-portal navigation, and direct access to
  `#admin` renders an explicit denial without loading the admin preview.
- PostgreSQL now rejects any Auth user assigned to both `buyer_users` and
  `staff_members`. Staff helper functions also deny privileges to a buyer
  identity, providing defense in depth for every existing RLS policy and RPC.
- Valid staff accounts retain access through individually assigned roles.
- The static GitHub Pages build now uses explicit public demo credentials for
  synthetic staff data. An active buyer must sign out before the staff login is
  shown. These credentials are deliberately not presented as production
  authentication; configured deployments still require backend password checks.
- Verification: `npm run build` (exit 0), `npm test -- --run` (exit 0; 11
  tests), `npm run test:db` (exit 0, including buyer/staff separation and
  concurrent last-stock checks), and `npm run test:e2e` (exit 0; 8 desktop and
  mobile tests). The first new database test run exited 3 because the test
  assertion directly referenced the private `auth` schema as `authenticated`;
  the assertion was corrected to use the RLS-visible row count and the full
  suite then passed.
- After adding the separate staff-demo login, all four commands were rerun and
  passed again: build, 11 unit tests, the full database suite, and 8 desktop/
  mobile browser tests.
