# Pedapalli Medical

A mobile-first B2B pharmaceutical wholesale portal for verified medical stores. The preview includes gated wholesale pricing, optional GSTIN and required drug-licence application details, product-specific MOQ and order steps, wholesale cart and fulfilment choices, a buyer-review workspace, and CSV/XLSX inventory tools.

Without Supabase environment variables, the site is a safe product preview and applications/orders are not transmitted. The selected ₹0 pilot architecture uses Cloudflare Workers Static Assets and Turnstile with Supabase Free for Postgres, Auth, RLS and Edge Functions. It supports email-link authentication, buyer approval, protected pricing, server-authoritative ordering, stock reservation, order transitions and buyer-isolated records. Follow [PRODUCTION.md](PRODUCTION.md) before activation.

## Local development

```sh
npm install
npm run dev
```

## Verification

```sh
npm test
npm run build
npm run test:e2e
npm run verify:cloudflare
```

Production publishing is intentionally manual through the `Publish Cloudflare Free` GitHub Actions workflow. Required setup, free-tier limits and backup/restore instructions are in [PRODUCTION.md](PRODUCTION.md).

The latest desktop/mobile buyer and staff review, before/after screenshots, completed fixes and remaining launch blockers are documented in [UX_AUDIT.md](UX_AUDIT.md).
