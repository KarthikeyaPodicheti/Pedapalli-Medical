# Pedapalli Medical

A mobile-first B2B pharmaceutical wholesale portal for verified medical stores. The public site is a synthetic product preview. The repository also contains a self-hosted Node.js/PostgreSQL production candidate with separate buyer/staff identities, protected pricing, buyer review, quarantined batch receiving, pharmacist release, FEFO reservations, and idempotent ordering.

The connected runtime uses repository code and PostgreSQL only. Its Docker build serves the buyer/staff portal, while GitHub Pages remains a synthetic preview. Real checkout is disabled by default. Follow [the local runtime guide](docs/LOCAL_RUNTIME.md) and [PRODUCTION.md](PRODUCTION.md); do not use the GitHub Pages preview for real orders.

## GitHub Pages preview

[Open the live preview](https://karthikeyapodicheti.github.io/Pedapalli-Medical/). This is browser-only sample data; no buyer application or order is sent to the wholesaler.

Staff demo: open [the staff portal](https://karthikeyapodicheti.github.io/Pedapalli-Medical/#admin) and use username `staff-demo` with password `Peddapalli-Staff-Demo-2026`. If a buyer demo is active, choose **Sign out buyer and continue to staff login** first. These public credentials unlock synthetic preview data only; they are not production authentication.

## Local development

```sh
npm install
npm run dev
```

For the isolated local stack:

```sh
export LOCAL_DB_PASSWORD="$(openssl rand -hex 24)"
export LOCAL_API_PASSWORD="$(openssl rand -hex 24)"
export LOCAL_MFA_KEY="$(openssl rand -hex 32)"
docker compose up --build -d
```

## Verification

```sh
npm test
npm run build
npm run test:server
npm run test:local-db
npm run test:local-stack
npm run test:e2e
```

The local-stack test creates and then removes a disposable database volume. Production activation requirements are in [PRODUCTION.md](PRODUCTION.md).

The latest desktop/mobile buyer and staff review, before/after screenshots, completed fixes and remaining launch blockers are documented in [UX_AUDIT.md](UX_AUDIT.md).
