# Security and controlled-import release procedure

## Scope

Migrations 003–005 add serialized session issuance, import preview/audit tables,
atomic application/reconciliation functions and serialized quarantined receiving.
Existing migration files 001–002 are unchanged. No external application provider
or dependency was added. Checkout remains disabled.

## Staging rollout

1. Back up the existing database and verify a restore in an isolated environment.
2. Stop API writers during migration. Run the repository migration service with
   the new image; migration checksums must pass.
3. Deploy matching API and web images. Keep API port private behind Nginx;
   `TRUST_PROXY=true` requires the overwriting `X-Real-IP` configuration.
4. Smoke-test staff MFA, buyer denial, recovery session revocation, draft import,
   concurrent retry and independent reconciliation using synthetic records.
5. Record the image/commit, migration result and operator. Verify that stock and
   existing orders were unchanged by migration itself.

An already-running installation needs the updated images and migrations. A Git
push or GitHub Pages deployment does not deploy this connected backend.

## Rollback and recovery

The import schema is additive. Prefer a forward fix; do not delete migration
records, reverse an applied receipt by subtraction, or drop import audit data.
If import behavior is suspect, stop writers and keep checkout disabled while
investigating source references, movements and audit records.

Rolling back the API to a version before these fixes reintroduces known MFA and
receiving weaknesses. Use a reviewed maintenance response instead. Restore a
backup only into staging first and reconcile every post-backup transaction before
any approved production recovery. Actual restore-drill evidence is still a
production launch requirement, not supplied by these disposable tests.
