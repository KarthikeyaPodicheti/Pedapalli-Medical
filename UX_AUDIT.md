# User experience audit — 10 October 2026

This audit tested the application as a guest buyer, approved medical-store buyer, checkout user and staff user on desktop and mobile. Three independent reviews covered desktop UX, mobile/accessibility and B2B order operations. Automated journeys were then repeated after the fixes.

## Screenshot evidence

| Journey | Before | After |
| --- | --- | --- |
| Order confirmation | [₹0 confirmation](docs/ux-audit/before-desktop-confirmation.png) | [Correct ₹110 confirmation](docs/ux-audit/after-desktop-confirmation.png) |
| Checkout | [Original checkout](docs/ux-audit/before-desktop-checkout.png) | [Address, delivery charge and estimated total](docs/ux-audit/after-desktop-checkout.png) |
| Mobile catalog | [Original mobile catalog](docs/ux-audit/before-mobile-home.png) | [Improved mobile catalog](docs/ux-audit/after-mobile-home.png) |
| Mobile checkout | — | [Improved mobile checkout](docs/ux-audit/after-mobile-checkout.png) |

Additional reproducible screenshots are stored in `docs/ux-audit` and can be regenerated with `node scripts/capture-ux-audit.mjs current` while the development server is running.

## Improvements made

| Disadvantage found | Improvement |
| --- | --- |
| A completed order displayed ₹0 because the cart was cleared before rendering confirmation. | Confirmation now preserves the server-returned reference and total before clearing the cart. The exact ₹110 result is regression-tested. |
| A cart survived buyer sign-out and could pass to another buyer on a shared device. | Sign-out now explicitly clears cart and confirmation state; production Auth sign-out also clears the cart. |
| Clicking a button labelled as the buyer identity silently signed the user out. | The control now explicitly says “Sign out buyer” on desktop and “Sign out” on mobile. |
| “MOQ available” actually filtered `stock > 0`, allowing stock below MOQ. | It is renamed “Orderable stock only” and checks `stock >= MOQ`. |
| Empty searches left a blank catalog. | A no-results explanation and one-click filter reset are shown. |
| Checkout hid the registered address, configured delivery fee and actual estimated total. | The review shows the buyer address/PIN, product subtotal, delivery charge and estimated order total. |
| An unserviceable PIN could choose wholesaler delivery and fail only after submission. | Wholesaler delivery is disabled with a PIN-specific explanation while transporter/pickup remain available. |
| Disabled payment/fulfilment settings could leave a stale hidden default selected. | Selection automatically moves to the first currently allowed option. |
| Minimum-order failure appeared only after the server rejected the order. | The cart shows the exact shortfall and blocks review until the minimum is met. Server validation remains authoritative. |
| Dialogs were announced to assistive technology only as an unnamed “dialog.” | Every dialog is linked to its visible heading with `aria-labelledby`. |
| Keyboard focus disappeared on visually styled checkout radio cards. | The entire option card now receives a visible focus ring. |
| Several mobile actions were below a comfortable touch size and the sign-out action was icon-only. | Core header, catalog and quantity controls now use at least 44px targets; sign-out has visible text. |
| Staff pages retained buyer search, cart and category navigation. | Buyer-commerce controls are hidden in the staff workspace shell. |
| Staff order cards always said COD and showed a fake “Registered business address” locality. | Cards now use actual payment/fulfilment fields, delivery fee and a method-aware dispatch label; the placeholder locality is suppressed. |
| Inventory allowed MRP below wholesale price. | CSV/editor validation and a database constraint now reject this invalid pricing state. |

## Remaining disadvantages and launch blockers

These were not guessed or silently changed because they require client, pharmacist or operating decisions:

- Buyer approval needs full contact/address details, a verification checklist, confirmation and mandatory rejection/suspension reasons.
- The prescription-verification workflow is mismatched to licensed B2B ordering: dispatch roles can record verification while the pharmacist role cannot. The client/pharmacist must define the lawful evidence and responsibility before this is redesigned.
- Inventory staff can currently set pharmacist approval in the same update. Production needs separate approval authority and audit events.
- The staff interface still needs role-aware navigation, payment-reference handling, transporter assignment/tracking, pick lists and proof-of-delivery operations.
- Inventory has no batch, expiry, recall, reserved/on-hand split or live POS/ERP reconciliation.
- Expired reservations restore stock but do not yet notify the buyer.
- Large real catalogs need server-side search and pagination; the current browser-side catalog is suitable only for a limited pilot dataset.
- Legal identity, support contact, licences, policies, tax/GST presentation, invoice workflow, delivery SLA and cancellation/return rules are still client inputs.
- Demo orders are deliberately not persisted. The revised confirmation now calls them “simulated” and clearly says they were not saved.

The application is materially safer and clearer after this pass, but these remaining items keep real ordering behind the production launch gates in `PRODUCTION.md`.
