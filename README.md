# Pedapalli Medical

A mobile-first B2B pharmaceutical wholesale portal for verified medical stores. The preview includes gated wholesale pricing, GSTIN and drug-licence application, product-specific MOQ and order steps, wholesale cart and fulfilment choices, a buyer-review workspace, and CSV/XLSX inventory tools.

Without Supabase environment variables, the deployed site is a safe product preview and applications/orders are not transmitted. With the reviewed migrations and Supabase configuration, it supports email-link authentication, buyer approval, protected pricing, server-authoritative ordering, stock reservation, order transitions and buyer-isolated records. Follow [PRODUCTION.md](PRODUCTION.md) before activation.

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
```
