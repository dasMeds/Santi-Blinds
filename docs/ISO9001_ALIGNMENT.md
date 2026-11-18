# ISO 9001:2015 alignment — Santi Blinds website and admin system

## Scope and honest limits

ISO 9001 certifies an organisation's quality management system. It does not certify a website. No code change can make this site "ISO 9001 compliant" on its own. What the software can do is produce the records and enforce the controls that an auditor expects to see for the order-to-delivery process. This document lists what the system now provides, and what only the owner can supply.

## Controls the system now provides

| Clause | Requirement | What the system does | Where |
|---|---|---|---|
| 7.5.3 | Control of documented information | Admin audit log, customer activity log and order status history are append-only. Database triggers reject UPDATE and DELETE. | `database/schema.sql` |
| 7.5.2 | Documented information is accurate | README and SETUP no longer claim field encryption that is not active. Dead code that targeted missing tables is isolated in `legacy/`. | `README.md`, `SETUP.md`, `legacy/` |
| 8.2.1 | Customer communication | Contact enquiries are saved to `inquiry` with contact preference, rooms, budget and consent, and emailed to the owner. | `enquiries.php`, `portal/inquiry.php` |
| 8.2.3 | Review of requirements before commitment | A customer quotation starts as Pending. The owner reviews and prices it, then returns it. Only a Returned quotation can become an order. The reviewer and review time are recorded. | `portal/quotation.php`, `admin/api/quotations.php`, `quotation.reviewed_by/at` |
| 8.5.2 | Identification and traceability | Quotations (QT-nnnnn) and orders (SB-nnnnn) have fixed references. Every order status change records old status, new status, who and when. | `order_status_history` |
| 8.5.2 | Prevent mix-ups | A quotation that produced an order cannot be reopened or reused. Stock is reserved by trigger and restored on cancellation. | `admin/api/config.php`, `portal/order.php`, order triggers |
| 8.5.3 | Customer property | Customer contact data is held in one `customer` table, with guest rows merged into accounts by email. | `portal/config.php` |
| 8.7 | Nonconforming outputs | Cancelled orders are kept and marked, not deleted. Archive hides records without removing them. | `admin/api/order_archive.php` |
| 9.1.1 | Monitoring and measurement | Dashboard, counts, sales and reports read live data. The `is_archived` column they depend on now exists. | `admin/api/dashboard.php` |

## Open items only the owner can close

These need decisions, people or documents, not code.

1. Quality policy and measurable quality objectives (5.2, 6.2). Write them and publish them where staff can see them.
2. Documented procedures and document control (7.5.2): who approves, reviews and revises the ordering, quotation, installation and complaints procedures. Keep revision history.
3. Customer feedback and complaints (9.1.2, 10.2): there is no complaints or satisfaction record yet. Needs a procedure first, then a form and a log with corrective-action tracking.
4. Internal audit programme (9.2) and management review (9.3). Schedule them and keep minutes.
5. Competence and training records (7.2) for staff who price quotations and install.
6. Supplier and subcontractor evaluation (8.4) for fabric, motors and installers.
7. Record retention periods (7.5.3). The append-only triggers block deletion, so decide how long records are kept and how they are archived.
8. Change the default owner password. `schema.sql`, `SETUP.md` and this repository publish `owner@santiblinds.com` / `santiowner`. Create a named account for each person who uses the admin panel. The audit log only supports accountability if each person signs in as themselves.
9. Backups: schedule them and test a restore. Record the test.
10. Data protection: customer data is stored as plain text. Decide on encryption at rest, a privacy notice, and a retention rule.

## Known limitations

- Login throttling counts failures per email address (5 in 15 minutes). A third party can lock a known customer out for 15 minutes by submitting wrong passwords. Combining email and IP address would reduce this at the cost of weaker protection against distributed guessing.
- There is a single admin role. Separation of duties (one person prices, another approves) is not enforced.
- `database/warehouse.sql` is a separate reporting schema. It was not reviewed or changed.

## Test specification change: TC051

The implementation is correct and should not change. A customer request creates a Pending quotation. The owner returns it with reviewed prices. Only then can the customer order. This review step is the control that satisfies clause 8.2.3. The test case wording does not match it. Suggested wording:

- Precondition: Customer is logged in and has a Returned quotation that has not been ordered.
- Step 1 expected: An order is created from the customer's own Returned quotation if its items, address and stock checks pass. The quotation is then treated as ordered.
- Add a step: Ordering from a Pending quotation is rejected with "This quotation is waiting for Santi Blinds to review and return it."
- Step 2 expected: unchanged. "An order has already been placed from this quotation."
