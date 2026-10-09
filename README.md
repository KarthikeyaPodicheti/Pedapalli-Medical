# Pedapalli Medical

A mobile-first B2B pharmaceutical wholesale portal for verified medical stores. The preview includes gated wholesale pricing, GSTIN and drug-licence application, product-specific MOQ and order steps, wholesale cart and fulfilment choices, a buyer-review workspace, and CSV/XLSX inventory tools.

The deployed site is a safe product preview: applications and orders are not transmitted. Production activation requires the client decisions tracked in `clientMeeting.md`, a configured Supabase project, reviewed migrations, staff accounts, notification providers, legal content, real catalog data, and deployment verification.

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
