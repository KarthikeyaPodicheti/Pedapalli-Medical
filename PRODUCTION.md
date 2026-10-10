# Production activation runbook

The selected zero-cost pilot stack is Cloudflare Free + Supabase Free. It can accept controlled real orders only after every launch gate below passes. It has no uptime SLA and is not equivalent to a paid production platform.

## 1. Provision staging and production

Create separate Supabase projects. For each project:

1. Apply every migration in `supabase/migrations` in filename order.
2. Enable email magic links, set the exact Site URL and allow only the Cloudflare production/staging callback URLs.
3. Enable Supabase Auth CAPTCHA with the Cloudflare Turnstile secret. Never expose that secret in the frontend.
4. Create staff Auth accounts, require MFA, and assign least-privilege `staff_members` roles.
5. Deploy `checkout`, `buyer-application`, and `maintenance`. Keep legacy `checkout` disabled.
6. Set Edge Function secrets: `TURNSTILE_SECRET_KEY`, exact comma-separated `ALLOWED_ORIGINS`, and `TURNSTILE_ALLOWED_HOSTNAMES`.
7. Configure a real transactional email provider for Auth. Supabase’s default SMTP is not a production delivery service.
8. Set maintenance secrets/providers and invoke `maintenance` at least every five minutes: `MAINTENANCE_SECRET`, `RESEND_API_KEY`, `EMAIL_FROM`, and optional approved WhatsApp credentials/templates.

The manual `Deploy Supabase Staging` workflow needs a protected `staging` GitHub environment with variable `SUPABASE_PROJECT_REF` and secrets `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD`.

## 2. Publish on Cloudflare Free

Create a Cloudflare Turnstile widget for the final hostnames. In the protected `cloudflare-production` GitHub environment configure:

- Variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_TURNSTILE_SITE_KEY`.
- Secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

Give the API token only Workers Scripts edit permission for the intended account. Run `Publish Cloudflare Free`, connect the client domain, enforce HTTPS, and confirm the site says `SECURE B2B PORTAL` rather than `B2B PREVIEW`. The Supabase anon key is public by design; the service-role key must never enter GitHub build variables or browser code.

For the scheduled health check, add repository variables `STOREFRONT_URL`, `VITE_SUPABASE_URL`, and `VITE_SUPABASE_ANON_KEY`. A failed run must alert the named operations owner through GitHub Actions notifications or an attached incident channel.

## 3. Encrypted backups on the free tier

Create a private R2 bucket with no public access and a lifecycle rule that matches the client-approved retention period. Configure the protected `production-backup` environment:

- Variable: `R2_BACKUP_BUCKET`.
- Secrets: `SUPABASE_DB_URL`, `BACKUP_ENCRYPTION_PASSPHRASE`, `CLOUDFLARE_R2_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

The daily workflow dumps `public` schema/data and Auth data, encrypts the archive with AES-256, verifies it, and uploads it with a SHA-256 checksum. Store the passphrase in a separate client-controlled password manager. Once per month, download the latest archive, verify its checksum, decrypt it offline, restore into a disposable PostgreSQL/Supabase staging project, and record recovery time and evidence. Never test a restore against production.

Supabase Free does not provide the same backup/PITR guarantees as paid plans. A backup that has not been restored successfully is not considered valid.

## 4. Free-tier operating limits

The owner must check Supabase and Cloudflare usage weekly. Start upgrade planning when any of these occurs:

- Database reaches 400 MB or 80% of the current project limit.
- Egress, Edge Function, Worker, Turnstile, Auth, storage or R2 usage reaches 80% of its current allowance.
- The store cannot tolerate a Supabase inactivity pause, platform outage, delayed email, or manual recovery.
- Order volume makes spreadsheet inventory reconciliation unsafe.
- The client requires an uptime SLA, PITR, formal support, longer logs or faster recovery.

Do not add a payment card or enable usage-based billing without client approval. Maintain a written fallback: staff phone/WhatsApp contact, read-only catalog message, paper/Excel order capture, and later reconciliation. Free-plan quotas and terms can change; verify the provider dashboards before launch and monthly thereafter.

## 5. Configure the business

Before enabling checkout, staff must:

1. Publish verified legal identity, contact information, policies and approved branding.
2. Import the pharmacist-approved real catalog and verify SKU, price, MRP, stock, wholesale unit, case size, MOQ, step and regulatory class.
3. Confirm payment methods, fulfilment methods, delivery PIN codes, fee, minimum order and manual fallback.
4. Confirm GST/billing handoff, batch/expiry ownership, recall handling and daily stock reconciliation.
5. Keep `checkout_enabled=false` until controlled staging and pilot orders pass.

## 6. Acceptance and launch gates

Test with synthetic or controlled records:

1. Turnstile protects sign-in and buyer application; direct browser invocation of the application SQL function is denied.
2. An unapproved account cannot see prices/stock or order; staff approval unlocks only that buyer.
3. MOQ/step, current price, service area, payment and fulfilment rules are enforced on the server.
4. Concurrent last-stock orders cannot oversell; retries create one order.
5. Cancellation and reservation expiry restore stock exactly once.
6. Staff roles, MFA, buyer isolation, notification retries and audit records pass.
7. The encrypted backup is restored successfully into a disposable environment.
8. Mobile flows work on the client’s actual devices and network.
9. Client/compliance owners approve the catalog, policies, fallback, training and launch in writing.

Only then may an owner enable `Accept online order requests`. Run locally with `npm test`, `npm run build`, `npm run test:db`, `npm run test:e2e`, and `npm run verify:cloudflare`.

## Still required outside this repository

- Supabase/Cloudflare accounts, custom domain and correctly scoped credentials.
- Verified client legal data, catalog, operating rules and policies.
- Production SMTP and any approved WhatsApp provider.
- Named incident, inventory, security, backup and launch owners.
- Controlled pilot evidence and written client/compliance sign-off.
