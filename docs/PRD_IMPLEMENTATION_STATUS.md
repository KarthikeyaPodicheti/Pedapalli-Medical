# PRD implementation status

## Local authoritative runtime — 19 October 2026

The repository contains a self-hosted Node.js/PostgreSQL foundation in
`server/` and `compose.yaml`, following the current local-only architecture decision.

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
- Connected buyer registration, sign-in, business application/status, protected
  catalogue/cart/order-history screens and a distinct staff workspace.
- TOTP MFA enrollment on the first staff sign-in; staff API endpoints reject a
  session until the current six-digit authenticator code is verified.
- Role-scoped buyer review, batch receipt/quarantine, pharmacist release and
  order visibility in the local staff workspace.
- Disposable database and whole-stack integration tests. `npm run test:server`,
  `npm run test:local-db`, and `npm run test:local-stack` pass locally.

Previous local verification covered the build, frontend unit tests, demo and
connected-portal browser journeys, server security tests, authoritative batch
SQL checks, and disposable container-stack checks. See the current results
below before relying on any past test claim.

This is not a production release. Checkout is disabled by default. The Docker
web image now serves the connected local portal, while GitHub Pages remains the
synthetic preview. Controlled Excel import and reconciliation, workflow
completion, backup/restore rehearsal, real client data, compliance acceptance and
pilot sign-off remain launch blockers.

## Current verification and launch boundary

The hosted prototype and its shadow inventory ledger have been retired from this branch. The connected `server/` and `server/sql/` code is the only backend implementation; GitHub Pages is a browser-only sample preview. Do not use preview credentials or sample catalog data for real business.

Buyer and staff identities remain separate in the connected portal. Staff must pass TOTP MFA before protected operations. The website still needs controlled Excel import/reconciliation, staff-assisted orders, complete fulfilment and billing workflow, notifications, monitored off-host backups with a restore drill, verified client data, and a signed pilot before real ordering can be enabled.

The latest cleanup removed the unused hosted backend integration, obsolete deployment jobs, and legacy SQL test runner. Current verification on 19 October 2026:

| Command | Exit | Result |
| --- | --- | --- |
| `npm ci` | 0 | Root dependencies installed from lockfile before edits; Docker build also completed `npm ci` with the updated lockfile. |
| `npm run build` | 0 | TypeScript and Vite build passed; ExcelJS still triggers a chunk-size warning. |
| `npm test -- --run` | 0 | 11 frontend tests passed. |
| `npm run test:server` | 0 | 5 server security tests passed. |
| `npm run test:local-db` | 0 | Batch SQL checks and concurrent last-stock test passed. |
| `npm run test:local-stack` | 0 | Docker build, buyer/staff/MFA checks and 2 connected-portal browser journeys passed. |
| `npm run test:e2e` | 0 on rerun | 8 preview desktop/mobile journeys passed. The first run exited 1: desktop buyer-application test timed out while waiting for the Batch alerts button to become stable during a concurrent Docker build; the same test and full suite passed on an isolated rerun. |
| `npm audit --audit-level=high` and `npm --prefix server audit --audit-level=high` | 0 each | No known vulnerabilities reported. |

This evidence does not clear the production launch gates. Checkout remains disabled.

The first GitHub run of the new local-stack CI job failed before compiling the
containers: Docker Buildx blocked reading `/etc/ssl/certs/ca-certificates.crt`
from outside the workflow checkout. The runner now copies the public CA bundle
into its workspace and passes that path to the existing build secret. The other
GitHub jobs (preview, server and local database) passed in that first run; the
full-stack job passed in follow-up run 39272347570.

## Production security increment — 19 October 2026

Closed an MFA enrollment authorization gap: a password-only session created
before MFA enrollment could previously call verify-setup after enrollment and
become MFA-verified without supplying a code. Already-enabled enrollment now
returns 409 and leaves that session unverified. Staff catalog prices and stock
also require verified MFA. Setup uses an atomic conditional upsert so concurrent
requests cannot overwrite the pending secret or retrieve an already-enabled
secret through that query. Setup and verification have per-account rate limits.

Added API regression checks for pre-MFA catalog denial, buyer/staff isolation,
stale-session enrollment rejection, continued staff denial, enabled setup
rejection and HTTP 429 after the enrollment attempt limit. Existing successful
enrollment and subsequent MFA login checks still pass.

| Command | Exit | Result |
| --- | --- | --- |
| `npm run build` | 0 | Passed; existing ExcelJS chunk-size and mixed-import warnings remain. |
| `npm test -- --run` | 0 | 11 tests passed. |
| `npm run test:server` | 0 | 5 tests passed. |
| `npm run test:local-db` | 0 | Batch ledger and concurrent last-stock checks passed. |
| `npm run test:e2e` | 0 | 8 desktop/mobile demo journeys passed. |
| `npm run test:local-stack` | 0 | New authorization/rate-limit checks and 2 connected browser journeys passed. |
| `git diff --check` | 0 | No whitespace errors. |

No failing assertions or environment blockers occurred in these runs. This is
one security increment, not completion of the security phase or a production
release. Login abuse controls, recovery/session lifecycle review, controlled
imports and the remaining production roadmap still require implementation and
acceptance. Checkout remains disabled; no production data or settings changed.
