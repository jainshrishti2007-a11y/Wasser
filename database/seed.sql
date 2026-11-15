-- Fictional Indian demonstration data. Run ONCE after schema.sql.
-- No real credentials: seeded users have NULL password_hash and cannot log in.
USE wasser;
START TRANSACTION;
INSERT INTO Society(name,address,city,state,postal_code) VALUES
('WASSER Demo - Shantivan Heights','Survey 42, Baner Road','Pune','Maharashtra','411045');
SET @pune = LAST_INSERT_ID();
INSERT INTO Society(name,address,city,state,postal_code) VALUES
('WASSER Demo - Lakeview Residency','18, Whitefield Main Road','Bengaluru','Karnataka','560066');
SET @blr = LAST_INSERT_ID();

INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,is_active) VALUES
(@pune,'A-101','Aarav Deshmukh','9000000101','2026-01-01',TRUE);
SET @h1 = LAST_INSERT_ID();
INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,is_active) VALUES
(@pune,'A-102','Meera Kulkarni','9000000102','2026-01-01',TRUE);
SET @h2 = LAST_INSERT_ID();
INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,is_active) VALUES
(@pune,'B-201','Kabir Shah','9000000103','2026-06-01',TRUE);
SET @h3 = LAST_INSERT_ID();
INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,left_on,is_active) VALUES
(@pune,'B-202','Former Resident','9000000104','2026-01-01','2026-09-30',FALSE);
INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,is_active) VALUES
(@blr,'C-101','Ananya Rao','9000000201','2026-02-01',TRUE);
SET @h4 = LAST_INSERT_ID();
INSERT INTO Household(society_id,unit_number,resident_name,phone,joined_on,is_active) VALUES
(@blr,'C-102','Rohan Iyer','9000000202','2026-02-01',TRUE);
SET @h5 = LAST_INSERT_ID();

INSERT INTO Supplier(name,phone,address,gstin) VALUES
('Demo Sahyadri Water Supply','9000000301','Hinjawadi, Pune',NULL);
SET @s1 = LAST_INSERT_ID();
INSERT INTO Supplier(name,phone,address,gstin) VALUES
('Demo Kaveri Tanker Services','9000000302','KR Puram, Bengaluru',NULL);
SET @s2 = LAST_INSERT_ID();

INSERT INTO TankerBooking(society_id,supplier_id,scheduled_at,requested_litres,agreed_amount) VALUES
(@pune,@s1,'2026-10-05 08:00:00',12000,4500.00);
SET @b1 = LAST_INSERT_ID();
UPDATE TankerBooking SET status='CONFIRMED' WHERE booking_id=@b1;
UPDATE TankerBooking SET status='DISPATCHED' WHERE booking_id=@b1;
INSERT INTO Delivery(booking_id,delivered_at,delivered_litres,receipt_number) VALUES
(@b1,'2026-10-05 08:15:00',12000,'DEMO-PUNE-DEL-001');
SET @d1 = LAST_INSERT_ID();

INSERT INTO TankerBooking(society_id,supplier_id,scheduled_at,requested_litres,agreed_amount) VALUES
(@pune,@s1,'2026-10-20 08:00:00',12000,4500.01);
SET @b2 = LAST_INSERT_ID();
UPDATE TankerBooking SET status='CONFIRMED' WHERE booking_id=@b2;
UPDATE TankerBooking SET status='DISPATCHED' WHERE booking_id=@b2;
INSERT INTO Delivery(booking_id,delivered_at,delivered_litres,receipt_number) VALUES
(@b2,'2026-10-20 08:10:00',12000,'DEMO-PUNE-DEL-002');
SET @d2 = LAST_INSERT_ID();

INSERT INTO TankerBooking(society_id,supplier_id,scheduled_at,requested_litres,agreed_amount) VALUES
(@blr,@s2,'2026-10-10 07:00:00',10000,3200.00);
SET @b3 = LAST_INSERT_ID();
UPDATE TankerBooking SET status='CONFIRMED' WHERE booking_id=@b3;
UPDATE TankerBooking SET status='DISPATCHED' WHERE booking_id=@b3;
INSERT INTO Delivery(booking_id,delivered_at,delivered_litres,receipt_number) VALUES
(@b3,'2026-10-10 07:20:00',10000,'DEMO-BLR-DEL-001');
SET @d3 = LAST_INSERT_ID();

INSERT INTO TankerBooking(society_id,supplier_id,scheduled_at,requested_litres,agreed_amount) VALUES
(@pune,@s1,'2026-11-20 08:00:00',12000,4500.00);
-- This future booking is still REQUESTED and is not a confirmed expense.

INSERT INTO SupplierInvoice(delivery_id,invoice_number,invoice_date,due_date,amount,status) VALUES
(@d1,'DEMO-SW-001','2026-10-05','2026-11-05',4500.00,'CONFIRMED');
SET @i1 = LAST_INSERT_ID();
INSERT INTO SupplierInvoice(delivery_id,invoice_number,invoice_date,due_date,amount,status) VALUES
(@d2,'DEMO-SW-002','2026-10-20','2026-11-05',4500.01,'CONFIRMED'),
(@d3,'DEMO-KT-001','2026-10-10','2026-11-05',3200.00,'CONFIRMED');
INSERT INTO SupplierPayment(supplier_invoice_id,paid_on,amount,method,reference_number) VALUES
(@i1,'2026-10-25',2000.00,'NEFT','DEMO-NEFT-SW-001');

INSERT INTO WaterAllocation(delivery_id,household_id,allocated_litres) VALUES
(@d1,@h1,4000),(@d1,@h2,4000),(@d1,@h3,4000),
(@d2,@h1,4000),(@d2,@h2,4000),(@d2,@h3,4000),
(@d3,@h4,5000),(@d3,@h5,5000);
INSERT INTO `User`(society_id,household_id,full_name,email,role) VALUES
(@pune,NULL,'Priya Joshi','priya.admin@example.invalid','SOCIETY_ADMIN'),
(@pune,@h1,'Aarav Deshmukh','aarav@example.invalid','RESIDENT'),
(@blr,NULL,'Divya Rao','divya.accounts@example.invalid','ACCOUNTANT');
COMMIT;

-- Each call is its own transaction. The extra paise goes to the lowest household ID.
CALL GenerateMonthlyBills(@pune,'2026-10-01','2026-11-10');
CALL GenerateMonthlyBills(@blr,'2026-10-01','2026-11-10');

START TRANSACTION;
INSERT INTO Payment(bill_id,paid_on,amount,method,reference_number)
SELECT bill_id,'2026-11-02',1000.00,'UPI','DEMO-UPI-A101-001'
FROM Bill JOIN BillingPeriod USING(billing_period_id,society_id)
WHERE household_id=@h1 AND month_start='2026-10-01';
INSERT INTO Payment(bill_id,paid_on,amount,method,reference_number)
SELECT bill_id,'2026-11-03',500.00,'UPI','DEMO-UPI-A101-002'
FROM Bill JOIN BillingPeriod USING(billing_period_id,society_id)
WHERE household_id=@h1 AND month_start='2026-10-01';
INSERT INTO Payment(bill_id,paid_on,amount,method,reference_number)
SELECT bill_id,'2026-11-04',b.amount,'NEFT','DEMO-NEFT-C101-001'
FROM Bill b JOIN BillingPeriod bp USING(billing_period_id,society_id)
WHERE household_id=@h4 AND month_start='2026-10-01';
COMMIT;
