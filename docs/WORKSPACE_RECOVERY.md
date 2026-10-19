# Workspace recovery — 17 October 2026

The execution workspace was empty on resume. The repository was cloned again
from `KarthikeyaPodicheti/Pedapalli-Medical`; remote main is `f012bd5`.

The previously reported local commit `a455926` on
`feat/local-runtime-and-staff-auth` could not be recovered. GitHub reports
that this commit does not exist remotely; that branch is not listed. No local
checkout or Docker image containing it was found. Do not describe that work as
present in this checkout, pushed, deployed, or currently verified.

## Required recovery scope

The earlier implementation notes describe a local Node/TypeScript API,
PostgreSQL, cookie sessions, password hashing, staff TOTP MFA, offline account
recovery, assigned buyer reviewers, pharmacist-only approvals, a React local
portal and Docker Compose. Those notes are not a replacement for source code
or current test evidence. Restore the actual commit if a copy exists; otherwise
reimplement and independently verify these features before integrating orders.

The user's current architecture decision remains **local code only, no external
runtime APIs**. Earlier hosted-backend instructions were retired. GSTIN stays optional; drug-licence
details and manual business verification remain required.

On 19 October 2026, the first independently verified replacement foundation was
rebuilt in `server/` and `compose.yaml`: local password authentication, separate
buyer/staff identities, transactional buyer review, quarantined batch receiving,
pharmacist release, authoritative FEFO reservation, idempotent orders, and
exactly-once cancellation/expiry release. This is new work, not recovery of the
missing commit. The connected local buyer/staff portal and TOTP MFA enrollment
were then added and independently tested.

Next complete controlled import/reconciliation, assisted orders,
picking/packing/dispatch, payment records, billing export, reporting and tested
backup/restore. Keep real ordering disabled pending verified stock, operational
acceptance and owner/compliance sign-off. Never fabricate client data.

## Recovered baseline checks

- `npm ci`: exit 0.
- `npm run build`: exit 0 (bundle-size warning).
- `npm test -- --run`: exit 0; 11 tests passed.
- The earlier SQL suite and concurrent last-stock test passed before the hosted prototype was retired; use `npm run test:local-db` for the current runtime.
- `npm run test:e2e`: initially blocked by missing Playwright Chromium executable.
- `npx playwright install --with-deps chromium`: exit 1; the environment cannot
  authenticate `su` to install system packages.
- `npx playwright install chromium`: exit 0; existing system libraries suffice.
- `npm run test:e2e` retry: exit 0; all 8 desktop/mobile tests passed.

These checks apply only to recovered remote main, not the missing local backend.
