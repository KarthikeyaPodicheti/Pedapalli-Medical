# Controlled inventory imports

The connected staff portal supports CSV and XLSX template v1 for **existing
SKUs**. The public Pages demo has a separate synthetic importer. Never use that
demo to maintain business inventory.

## Prepare the file

Download `public/batch-import-v1.csv` from the staff screen. Use exactly these
columns in this order:

`sku,wholesale_unit,batch_number,expiry_date,quantity,price_paise,mrp_paise`

- Match SKU and wholesale unit exactly to the catalog. Do not infer units or
  convert strips, packs, tablets or cases automatically.
- Dates must be real `YYYY-MM-DD` text values, including in Excel.
- Quantities are positive whole units; prices are integer paise, not rupees.
- Use at most 500 rows and a 1 MB file. XLSX must contain one worksheet and
  plain values; formulas, dates stored as Excel serials, rich cells and errors
  are rejected. Expanded workbook metadata is limited to 8 MB before parsing.
- An unknown SKU is rejected. Catalog creation/classification/approval is a
  separate workflow and is not inferred from a stock spreadsheet.

## Preview and apply

1. Owner or inventory staff signs in with MFA.
2. Open Batch inventory → Controlled stock import.
3. Enter the delivery/GRN reference. Choose additive receipt or opening stock.
   Opening stock requires disabled checkout and batches not already in the ledger.
4. Upload the file and review every row: existing on-hand/reserved balance,
   quantity to add, expiry, unit and price changes.
5. Confirm the reviewed preview version. The server rechecks catalog/batch state
   under locks. Any stale row aborts the entire transaction; no partial import.
6. If stale/expired, upload the same file and reference to refresh its preview,
   review it again, then confirm. Refreshes are audited and invalidate the old
   preview version. Previews expire after 24 hours.

The database stores a SHA-256 checksum of **validated canonical content and
mode**, not the original XLSX binary. Files are parsed in the browser, then all
values are validated again by the server and database. Raw files are not retained.
Changing format or filename cannot bypass duplicate-content detection. Keep the
original GRN/source file in the client's document records.

Applying the same import repeatedly or concurrently adds stock exactly once.
The same content under a different reference is rejected. Existing batches must
be quarantined to receive additional quantities; released, damaged, recalled or
disputed stock cannot receive uninspected additions through this workflow.
Neither import nor reconciliation grants pharmacist approval or enables checkout.

## Reconciliation

An owner other than the applying staff member opens the applied import and enters
an independently observed physical count for every batch. Counts must match the
current ledger and a meaningful evidence note is required. The actor, time,
counts and note are audited. Matching counts mark only that import reconciled;
they do not certify whole-store cutover or resolve outstanding offline orders.

Discrepancies block sign-off. This release does not offer an inventory adjustment
workflow: investigate and retain quarantine until an approved adjustment process
is implemented. A pharmacist remains responsible for release and shelf-life checks.

## Remaining client gate

Map a sanitized real spreadsheet to template v1; confirm the exact units, SKU
identity, stock ownership and named independent reviewer in `clientMeeting.md`.
Do not import real opening stock before the staging/recovery/cutover gates in
`INVENTORY_CUTOVER_PLAN.md`. No production migration was run by these tests.
