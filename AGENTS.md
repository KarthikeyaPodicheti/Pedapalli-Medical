Use a prd.md to gain more context.

# Codex startup and verification instructions

When opening this repository in Codex, first read `PRD.md`, `docs/PRD_IMPLEMENTATION_STATUS.md`, `docs/INVENTORY_CUTOVER_PLAN.md`, and `PRODUCTION.md`. Treat the PRD as draft: do not fabricate client approval, medicine inventory, GST rules, or legal sign-off.

Before making changes, check availability of Node.js, npm, Docker, and the Docker daemon (`node --version`, `npm --version`, `docker --version`, `docker info`). The database test runner uses `postgres:17-alpine` in Docker; a standalone local PostgreSQL installation is not required when Docker works. If Docker is unavailable, install or start it **only when environment permissions allow**, otherwise report the blocker explicitly. Never claim tests passed unless their commands actually ran successfully.

At the start of a Codex implementation session, install dependencies with `npm ci` if needed and run `npm run build`, `npm test -- --run`, `npm run test:server`, and `npm run test:local-db`. If Playwright browser dependencies are available, run `npm run test:e2e`; otherwise run `npx playwright install --with-deps chromium` only when permitted and rerun the tests. Re-run relevant tests after every code change and all suites before marking a PR ready for review. Record the exact command, exit status, failing assertion, and environment blocker in `docs/PRD_IMPLEMENTATION_STATUS.md`.

Pay particular attention to: receipt idempotency, concurrent last-stock orders, full-cart atomicity, FEFO eligibility, cancellation/expiry exactly-once release, role-based security, Excel import safeguards, and reconciliation of real stock against the batch ledger. The local runtime has a batch-aware reservation path, but live checkout is disabled. Do not enable `checkout_enabled` or apply a production cutover without staging rehearsal, reconciliation, tested recovery, and documented owner/compliance sign-off.

Use any stock images and i need you to start using phosphor icons

# Project brief

Build a production-ready, sellable B2B pharmaceutical wholesale portal for one medicine wholesaler in Peddapalli, Telangana. The first customers are medical-store businesses—not individual consumers. B2C is a separate future phase and must not shape or weaken the first B2B release.

Only approved medical stores may see wholesale prices or place orders. A buyer registers with business identity, contact and address details, an optional GSTIN, and a required drug-licence number. Documents are verified outside the website for the first version; staff approves or rejects the account before catalog access is unlocked.

The first commercial model uses fixed wholesale prices, product-specific wholesale units, minimum order quantities, and quantity steps. Buyers may choose COD or bank transfer, and every order remains subject to wholesaler confirmation. Fulfilment must support configurable local delivery, transporter delivery, and store pickup. Buyers and staff receive email and approved-provider WhatsApp notifications.

Only a responsible-pharmacist-approved catalog may be orderable. Products need regulatory classification and verified identity, manufacturer, composition, strength, dosage form, pack/case information, MRP, wholesale price, MOQ, quantity step, availability, tax/HSN fields where required, and batch/expiry controls in the operational source of truth. Do not automatically publish every spreadsheet row.

Use validated Excel/CSV import as the initial inventory and pricing workflow, with preview, atomic apply, audit history, reconciliation status, and clear freshness indicators. Plan for later POS/ERP or billing-software integration. The official GST invoice workflow is still a client-discovery decision; prefer exporting confirmed orders to the client’s existing billing software unless requirements show that compliant website-generated invoicing is necessary.

The staff workspace needs role-based access for owner/admin, sales, inventory, dispatch, and pharmacist/compliance responsibilities; buyer approval; catalog/inventory management; order confirmation and status management; payment-reference recording; fulfilment assignment; notification history; and auditable changes. Staff authentication should support MFA. Customer-business data must be protected with least privilege, retention rules, backups, monitoring, and tested recovery.

The visual benchmark is the polish, clarity, trust, search-led navigation, and responsive commerce experience of ApolloPharmacy.in. Do not copy Apollo’s logo, trademarks, text, imagery, or exact layouts. Use suitable licensed stock photography, Phosphor icons, the project’s own identity, and a mobile-first green-and-white design.

The end goal is not a demonstration: it is a stable production product that can be sold to the wholesaler and used daily. Keep the current public site in explicit demo mode until the B2B backend, verified catalog, buyer approval, inventory operations, compliance workflow, notifications, policies, monitoring, and launch acceptance tests are complete. Never invent legal business details, licences, delivery promises, prices, stock, tax rules, or medical claims.

Use `clientMeeting.md` as the living client-discovery record. Before making assumptions about the wholesaler’s business, compliance, billing, inventory, delivery, branding, or operating workflow, add the needed question there. After the user provides a client answer, record the decision, date/status if known, implementation impact, and any follow-up. Keep confirmed decisions separate from unanswered questions, and update `plan.md` when a confirmed answer changes product scope or architecture.

Use `PRODUCTION.md` as the activation and operations runbook. Never enable real ordering merely because the code builds: require the configured backend, verified client data, acceptance evidence, operational ownership, and client/compliance sign-off described there.

The current architecture decision is a self-hosted local Node.js/PostgreSQL runtime using only repository code and no external application API. The GitHub Pages site is a synthetic demo only. Use `docs/LOCAL_RUNTIME.md` for the container stack. Keep checkout disabled until controlled import/reconciliation, backup/restore drill, verified client data, complete fulfilment/billing operations, and launch gates in `PRODUCTION.md` are complete. The connected local portal enforces buyer/staff separation; staff must enroll and verify TOTP MFA before protected operations are available.
