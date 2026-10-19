# Local production-candidate runtime

This runtime uses only repository code, Node.js and PostgreSQL. It makes no
external application API calls. The public GitHub Pages build
remains a synthetic preview and is not this runtime.

## Start

Generate two different random passwords and one separate 32-byte MFA encryption key for the current shell:

```sh
export LOCAL_DB_PASSWORD="$(openssl rand -hex 24)"
export LOCAL_API_PASSWORD="$(openssl rand -hex 24)"
export LOCAL_MFA_KEY="$(openssl rand -hex 32)"
docker compose up --build -d
curl http://localhost:8080/api/health
```

The database has no host port. Nginx is the only published service and binds to
`127.0.0.1:8080`. API cookies are HTTP-only and same-site. Mutation requests
must have the exact configured Origin.

## Create the first staff account

Use a private JSON input file outside the repository, then pipe it to the
one-shot admin command. Never put a password on the command line or commit it.

```sh
docker compose run --rm -T migrate node dist/admin.js < /private/path/create-staff.json
```

Input shape:

```json
{
  "action": "create-staff",
  "email": "owner@example.in",
  "password": "replace-with-a-long-random-password",
  "role": "owner",
  "operator": "client owner",
  "reason": "Initial individually assigned owner account"
}
```

Supported roles are `owner`, `sales`, `inventory`, `dispatch` and
`pharmacist`. Buyer accounts cannot be turned into staff accounts. On first
staff sign-in, the portal shows a manual time-based one-time-password (TOTP)
key. Add it to an authenticator application and verify its six-digit code;
staff operations remain blocked until this is complete. Store the manual key
only in the authenticator app, not in a ticket, spreadsheet or chat.

## Implemented safety boundary

- New receipts are additive, idempotent and quarantined by default.
- Only a pharmacist role can release a quarantined batch to sellable stock.
- Catalog availability comes from eligible batch balances, not product stock.
- Reservations are atomic, cart-wide and allocated FEFO.
- Buyer cancellation and reservation expiry release each allocation once.
- The database serializes competing last-stock orders.
- The connected Docker portal supports buyer registration/application/status,
  approved catalogue/cart/order history and role-scoped staff operations.
- Staff must complete TOTP MFA before protected operations are available.
- Real checkout defaults to disabled.

The proposed default minimum shelf life is 180 days and remains configurable.
The client pharmacist/compliance owner must confirm it before real inventory is
released. This default is an operational proposal, not legal advice.

## Verification

```sh
npm run test:server
npm run test:local-db
npm run test:local-stack
docker compose build
```

`test:local-stack` builds the containers, migrates a disposable database,
checks buyer registration/application, protected catalogue access, the
disabled-checkout boundary, staff TOTP MFA enrollment/login and the connected
portal in desktop and mobile browsers, then removes the test volume.

Do not enable real ordering yet. Controlled Excel import, backup/restore
rehearsal, real inventory reconciliation, order fulfilment/billing handoff and
client acceptance remain launch gates.
