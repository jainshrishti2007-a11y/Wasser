-- Read-only demonstrations; no credentials or password hashes selected.
USE wasser;

-- INNER JOIN: delivered tankers and their suppliers/societies.
SELECT s.name AS society, sp.name AS supplier, b.booking_id,
       d.delivered_at, d.delivered_litres
FROM Delivery d INNER JOIN TankerBooking b USING(booking_id)
INNER JOIN Society s USING(society_id) INNER JOIN Supplier sp USING(supplier_id)
ORDER BY d.delivered_at;

-- LEFT JOIN: includes households with no bill (for example inactive B-202).
SELECT s.name AS society,h.unit_number,b.bill_id,b.amount
FROM Household h JOIN Society s USING(society_id)
LEFT JOIN Bill b USING(household_id,society_id)
ORDER BY h.household_id,b.bill_id;

-- GROUP BY + HAVING + aggregates: societies owing more than INR 2,000.
SELECT s.society_id,s.name,COUNT(*) AS bill_count,SUM(hb.amount) AS billed,
       SUM(hb.paid_amount) AS collected,SUM(hb.outstanding_amount) AS outstanding,
       MIN(hb.amount) AS smallest_bill,MAX(hb.amount) AS largest_bill,
       AVG(hb.amount) AS average_bill
FROM HouseholdBalance hb JOIN Bill b USING(bill_id)
JOIN Society s ON s.society_id=b.society_id
GROUP BY s.society_id,s.name HAVING SUM(hb.outstanding_amount)>2000;

-- Correlated subquery: households whose bills still have unpaid balances.
SELECT h.household_id,h.unit_number,h.resident_name
FROM Household h WHERE EXISTS
(SELECT 1 FROM HouseholdBalance hb WHERE hb.household_id=h.household_id AND hb.outstanding_amount>0);

-- Scalar subquery: invoices larger than the average confirmed invoice.
SELECT supplier_invoice_id,invoice_number,amount FROM SupplierInvoice
WHERE status='CONFIRMED' AND amount>
(SELECT AVG(amount) FROM SupplierInvoice WHERE status='CONFIRMED');

-- Supplier payables remain separate from household receivables.
SELECT s.name AS society,sp.name AS supplier,i.invoice_number,i.status,
       bal.amount,bal.paid_amount,bal.outstanding_amount
FROM SupplierInvoice i JOIN SupplierInvoiceBalance bal USING(supplier_invoice_id)
JOIN Delivery d USING(delivery_id) JOIN TankerBooking b USING(booking_id)
JOIN Society s USING(society_id) JOIN Supplier sp USING(supplier_id)
WHERE i.status='CONFIRMED' ORDER BY i.supplier_invoice_id;

-- Reconciliation: each difference must be 0.00; household count must match.
SELECT bp.billing_period_id,bp.month_start,bp.confirmed_expense,
       COUNT(b.bill_id) AS bill_count,bp.eligible_households,
       SUM(b.amount) AS total_billed,
       bp.confirmed_expense-SUM(b.amount) AS reconciliation_difference,
       MAX(b.amount)-MIN(b.amount) AS rounding_spread
FROM BillingPeriod bp JOIN Bill b USING(billing_period_id,society_id)
GROUP BY bp.billing_period_id,bp.month_start,bp.confirmed_expense,bp.eligible_households;

-- Delivery usage; unallocated water is permitted but over-allocation is rejected.
SELECT d.delivery_id,d.delivered_litres,COALESCE(SUM(w.allocated_litres),0) AS allocated,
       d.delivered_litres-COALESCE(SUM(w.allocated_litres),0) AS unallocated
FROM Delivery d LEFT JOIN WaterAllocation w USING(delivery_id)
GROUP BY d.delivery_id,d.delivered_litres;

SHOW TABLES;
