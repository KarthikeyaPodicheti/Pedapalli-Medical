# Production activation runbook

The selected production-candidate stack is the self-hosted local Node.js,
PostgreSQL and Nginx runtime in `compose.yaml`. The GitHub Pages site is a
synthetic demo and must never receive real orders. Checkout stays disabled until
every applicable gate below is evidenced.

## 1. Current boundary

Implemented: local password authentication, separate buyer/staff realms,
permission-checked buyer review, protected prices/stock, quarantined batch
receiving, pharmacist release, minimum shelf-life eligibility, atomic FEFO
reservation, idempotency, cancellation/expiry release and audit records.

Controlled CSV/XLSX import for existing SKUs, audited recovery/session revocation
and independent import reconciliation are implemented and require client staging
acceptance. See `docs/CONTROLLED_IMPORTS.md` for the supported template and limits.

Not implemented: catalog onboarding/approval UI, stock discrepancy adjustments, complete order
fulfilment, billing handoff, notifications, operational monitoring or a
rehearsed backup/restore process. This means the application is not ready for
real orders.

## 2. Provision staging and production

1. Create separate client-controlled hosts for staging and production.
2. Install a supported Docker Engine/Compose release and restrict host access.
3. Generate different high-entropy database/API passwords for each environment;
   store them in a client-controlled secrets manager, never in Git or shell history.
4. Terminate HTTPS at a maintained reverse proxy. Set `APP_ORIGIN` to the exact
   public HTTPS origin and expose only ports 80/443. PostgreSQL must stay private.
5. Pin reviewed image digests, apply migrations through the one-shot migration
   service, and record deployment/migration evidence.
6. Create individually assigned staff accounts. Staff MFA is a launch blocker.
7. Configure encrypted off-host backups, monitoring and a named incident owner.

See `docs/LOCAL_RUNTIME.md` for development startup. Its localhost configuration
is not a complete internet deployment.

## 3. Backup and recovery

- Take encrypted daily PostgreSQL backups to a physically separate destination.
- Keep credentials and encryption keys outside the host and repository.
- Define client-approved retention, recovery-point and recovery-time objectives.
- Restore the newest backup into a disposable staging database at least monthly;
  verify users, products, batches, orders, allocations and audit history.
- Record checksum, start/end time, result and operator. A backup that has not been
  restored successfully is not considered valid.
- Document a manual phone/WhatsApp order fallback and later reconciliation.

## 4. Configure the business

Before enabling checkout, staff must:

1. Publish verified legal identity, contacts, policies and approved branding.
2. Confirm buyer-licence verification, responsible pharmacist and restricted
   product rules with qualified legal/compliance owners.
3. Import the pharmacist-approved real catalog and verify SKU, price, MRP, batch,
   expiry, wholesale unit, case size, MOQ, step and regulatory class.
4. Reconcile opening website stock against the client source and all outstanding
   counter, phone, driver and field-sales orders.
5. Confirm payment, fulfilment, delivery, cancellation/return and shortage rules.
6. Confirm and test the GST invoice/billing-software handoff.
7. Keep `store_settings.checkout_enabled=false` until controlled pilot acceptance.

## 5. Acceptance and launch gates

Test with synthetic or controlled records:

1. An unapproved buyer cannot see prices/stock or order; approval unlocks only
   that buyer. A buyer can never access staff endpoints or the staff workspace.
2. Staff MFA, least-privilege roles, removal/suspension and audit evidence pass.
3. MOQ/step, current price, shelf life, payment and fulfilment are server-enforced.
4. Competing last-stock orders cannot oversell; retries create one order.
5. Cart failure rolls back fully; cancellation and expiry restore stock once.
6. Receipt replay cannot duplicate stock; only a pharmacist releases quarantine.
7. Controlled Excel import preview/apply/reconciliation passes with client data.
8. The connected buyer/staff UI passes desktop, mobile and accessibility review.
9. Picking, packing, dispatch, payment references, billing export and manual
   fallback are tested by the actual staff who will operate them.
10. Monitoring alerts reach the named owner and the newest backup restores.
11. Client, pharmacist/compliance and operations owners approve the pilot in writing.

Required repository checks:

```sh
npm run build
npm test -- --run
npm run test:local-db
npm run test:e2e
npm run test:server
npm run test:local-db
npm run test:local-stack
```

Only after every applicable gate passes may an owner enable checkout through a
reviewed, audited operational action. Never edit the database ad hoc to bypass it.

## 6. Still required outside this repository

- Verified client legal data, catalog, operating rules and policies.
- Client-controlled staging/production hosts, domain, TLS and secret storage.
- Named security, inventory, backup, incident and launch owners.
- Off-host encrypted backup destination and restore-drill evidence.
- Approved notification provider if automated email/WhatsApp is required.
- Controlled pilot evidence, staff training and written launch sign-off.
