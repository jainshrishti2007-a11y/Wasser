-- WASSER Phase 2; MySQL 8.0.16+ (enforced CHECK constraints).
-- Additive installation into the selected database. No DROP, TRUNCATE or ALTER.
-- Deliberately fails if objects already exist: do not rerun over a live schema.
USE wasser;

CREATE TABLE Society (
  society_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address VARCHAR(255) NOT NULL,
  city VARCHAR(80) NOT NULL,
  state VARCHAR(80) NOT NULL,
  postal_code CHAR(6) NOT NULL,
  UNIQUE KEY uq_society_address (name, address),
  CHECK (postal_code REGEXP '^[1-9][0-9]{5}$')
) ENGINE=InnoDB;

CREATE TABLE Household (
  household_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  society_id BIGINT UNSIGNED NOT NULL,
  unit_number VARCHAR(30) NOT NULL,
  resident_name VARCHAR(120) NOT NULL,
  phone VARCHAR(15) NOT NULL,
  joined_on DATE NOT NULL,
  left_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_household_unit (society_id, unit_number),
  UNIQUE KEY uq_household_society (household_id, society_id),
  KEY ix_household_eligible (society_id, is_active, joined_on),
  FOREIGN KEY (society_id) REFERENCES Society(society_id),
  CHECK (is_active IN (0,1)),
  CHECK (left_on IS NULL OR left_on >= joined_on)
) ENGINE=InnoDB;

CREATE TABLE Supplier (
  supplier_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(15) NOT NULL,
  address VARCHAR(255) NOT NULL,
  gstin VARCHAR(15) NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE TankerBooking (
  booking_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  society_id BIGINT UNSIGNED NOT NULL,
  supplier_id BIGINT UNSIGNED NOT NULL,
  scheduled_at DATETIME NOT NULL,
  requested_litres DECIMAL(12,2) NOT NULL,
  agreed_amount DECIMAL(12,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'REQUESTED',
  UNIQUE KEY uq_booking_society (booking_id, society_id),
  KEY ix_booking_schedule (society_id, scheduled_at),
  KEY ix_booking_supplier (supplier_id, status),
  FOREIGN KEY (society_id) REFERENCES Society(society_id),
  FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id),
  CHECK (requested_litres > 0), CHECK (agreed_amount > 0),
  CHECK (status IN ('REQUESTED','CONFIRMED','DISPATCHED','DELIVERED','CANCELLED'))
) ENGINE=InnoDB;

CREATE TABLE Delivery (
  delivery_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id BIGINT UNSIGNED NOT NULL UNIQUE,
  delivered_at DATETIME NOT NULL,
  delivered_litres DECIMAL(12,2) NOT NULL,
  receipt_number VARCHAR(60) NOT NULL UNIQUE,
  FOREIGN KEY (booking_id) REFERENCES TankerBooking(booking_id),
  CHECK (delivered_litres > 0)
) ENGINE=InnoDB;

CREATE TABLE BillingPeriod (
  billing_period_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  society_id BIGINT UNSIGNED NOT NULL,
  month_start DATE NOT NULL,
  due_date DATE NOT NULL,
  confirmed_expense DECIMAL(14,2) NOT NULL,
  eligible_households INT UNSIGNED NOT NULL,
  generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_period_month (society_id, month_start),
  UNIQUE KEY uq_period_society (billing_period_id, society_id),
  FOREIGN KEY (society_id) REFERENCES Society(society_id),
  CHECK (DAYOFMONTH(month_start) = 1),
  CHECK (due_date >= month_start),
  CHECK (confirmed_expense > 0), CHECK (eligible_households > 0)
) ENGINE=InnoDB;

CREATE TABLE SupplierInvoice (
  supplier_invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  delivery_id BIGINT UNSIGNED NOT NULL UNIQUE,
  invoice_number VARCHAR(60) NOT NULL,
  invoice_date DATE NOT NULL,
  due_date DATE NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
  KEY ix_invoice_month (status, invoice_date),
  FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id),
  CHECK (amount > 0), CHECK (due_date >= invoice_date),
  CHECK (status IN ('DRAFT','CONFIRMED','VOID'))
) ENGINE=InnoDB;

CREATE TABLE SupplierPayment (
  supplier_payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  supplier_invoice_id BIGINT UNSIGNED NOT NULL,
  paid_on DATE NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  method VARCHAR(16) NOT NULL,
  reference_number VARCHAR(80) NOT NULL UNIQUE,
  FOREIGN KEY (supplier_invoice_id) REFERENCES SupplierInvoice(supplier_invoice_id),
  KEY ix_supplier_payment_date (supplier_invoice_id, paid_on),
  CHECK (amount > 0), CHECK (method IN ('UPI','NEFT','IMPS','CASH','CHEQUE'))
) ENGINE=InnoDB;

CREATE TABLE Bill (
  bill_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  billing_period_id BIGINT UNSIGNED NOT NULL,
  society_id BIGINT UNSIGNED NOT NULL,
  household_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  UNIQUE KEY uq_bill_household_month (billing_period_id, household_id),
  FOREIGN KEY (billing_period_id, society_id) REFERENCES BillingPeriod(billing_period_id, society_id),
  FOREIGN KEY (household_id, society_id) REFERENCES Household(household_id, society_id),
  CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE Payment (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bill_id BIGINT UNSIGNED NOT NULL,
  paid_on DATE NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  method VARCHAR(16) NOT NULL,
  reference_number VARCHAR(80) NOT NULL UNIQUE,
  FOREIGN KEY (bill_id) REFERENCES Bill(bill_id),
  KEY ix_payment_date (bill_id, paid_on),
  CHECK (amount > 0), CHECK (method IN ('UPI','NEFT','IMPS','CASH','CHEQUE'))
) ENGINE=InnoDB;

CREATE TABLE WaterAllocation (
  water_allocation_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  delivery_id BIGINT UNSIGNED NOT NULL,
  household_id BIGINT UNSIGNED NOT NULL,
  allocated_litres DECIMAL(12,2) NOT NULL,
  UNIQUE KEY uq_allocation (delivery_id, household_id),
  FOREIGN KEY (delivery_id) REFERENCES Delivery(delivery_id),
  FOREIGN KEY (household_id) REFERENCES Household(household_id),
  CHECK (allocated_litres > 0)
) ENGINE=InnoDB;

CREATE TABLE `User` (
  user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  society_id BIGINT UNSIGNED NOT NULL,
  household_id BIGINT UNSIGNED NULL,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NULL COMMENT 'NULL disables login until securely provisioned',
  role VARCHAR(20) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (society_id) REFERENCES Society(society_id),
  FOREIGN KEY (household_id, society_id) REFERENCES Household(household_id, society_id),
  CHECK (role IN ('SOCIETY_ADMIN','ACCOUNTANT','RESIDENT')),
  CHECK (role <> 'RESIDENT' OR household_id IS NOT NULL),
  CHECK (is_active IN (0,1))
) ENGINE=InnoDB;

CREATE VIEW HouseholdBalance AS
SELECT b.bill_id, b.household_id, b.billing_period_id, b.amount,
       COALESCE(p.paid, 0.00) AS paid_amount,
       b.amount - COALESCE(p.paid, 0.00) AS outstanding_amount
FROM Bill b LEFT JOIN (SELECT bill_id, SUM(amount) paid FROM Payment GROUP BY bill_id) p
ON p.bill_id = b.bill_id;

CREATE VIEW SupplierInvoiceBalance AS
SELECT i.supplier_invoice_id, i.amount,
       COALESCE(p.paid, 0.00) AS paid_amount,
       i.amount - COALESCE(p.paid, 0.00) AS outstanding_amount
FROM SupplierInvoice i LEFT JOIN
(SELECT supplier_invoice_id, SUM(amount) paid FROM SupplierPayment GROUP BY supplier_invoice_id) p
ON p.supplier_invoice_id = i.supplier_invoice_id;

DELIMITER $$
CREATE TRIGGER booking_insert BEFORE INSERT ON TankerBooking FOR EACH ROW
BEGIN
  IF NEW.status <> 'REQUESTED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New bookings must start REQUESTED';
  END IF;
END$$

CREATE TRIGGER booking_transition BEFORE UPDATE ON TankerBooking FOR EACH ROW
BEGIN
  IF NEW.society_id <> OLD.society_id OR NEW.supplier_id <> OLD.supplier_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking society and supplier are immutable';
  END IF;
  IF NEW.status <> OLD.status AND NOT (
    (OLD.status = 'REQUESTED' AND NEW.status IN ('CONFIRMED','CANCELLED')) OR
    (OLD.status = 'CONFIRMED' AND NEW.status IN ('DISPATCHED','CANCELLED')) OR
    (OLD.status = 'DISPATCHED' AND NEW.status = 'DELIVERED')
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid booking status transition';
  END IF;
  IF NEW.status = 'DELIVERED' AND NOT EXISTS (SELECT 1 FROM Delivery WHERE booking_id = OLD.booking_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'DELIVERED requires a delivery receipt';
  END IF;
END$$

CREATE TRIGGER delivery_insert BEFORE INSERT ON Delivery FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  SELECT status INTO v_status FROM TankerBooking WHERE booking_id = NEW.booking_id FOR UPDATE;
  IF v_status <> 'DISPATCHED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delivery requires DISPATCHED booking';
  END IF;
END$$
CREATE TRIGGER delivery_complete AFTER INSERT ON Delivery FOR EACH ROW
BEGIN
  UPDATE TankerBooking SET status = 'DELIVERED' WHERE booking_id = NEW.booking_id;
END$$
CREATE TRIGGER delivery_update BEFORE UPDATE ON Delivery FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delivery receipts are immutable';
END$$
CREATE TRIGGER delivery_delete BEFORE DELETE ON Delivery FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delivery receipts are immutable';
END$$

-- Serialize invoice changes and monthly billing using the society row.
CREATE PROCEDURE AssertInvoicePeriodOpen(IN p_delivery BIGINT UNSIGNED, IN p_date DATE)
BEGIN
  DECLARE v_society BIGINT UNSIGNED;
  DECLARE v_lock BIGINT UNSIGNED;
  DECLARE v_period BIGINT UNSIGNED DEFAULT NULL;
  SELECT b.society_id INTO v_society FROM Delivery d JOIN TankerBooking b USING (booking_id)
  WHERE d.delivery_id = p_delivery;
  SELECT society_id INTO v_lock FROM Society WHERE society_id = v_society FOR UPDATE;
  SELECT billing_period_id INTO v_period FROM BillingPeriod WHERE society_id = v_society
    AND month_start = DATE_SUB(p_date, INTERVAL DAYOFMONTH(p_date)-1 DAY) FOR UPDATE;
  IF v_period IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice month is already billed';
  END IF;
END$$
CREATE TRIGGER invoice_insert BEFORE INSERT ON SupplierInvoice FOR EACH ROW
BEGIN
  CALL AssertInvoicePeriodOpen(NEW.delivery_id, NEW.invoice_date);
END$$
CREATE TRIGGER invoice_update BEFORE UPDATE ON SupplierInvoice FOR EACH ROW
BEGIN
  CALL AssertInvoicePeriodOpen(OLD.delivery_id, OLD.invoice_date);
  CALL AssertInvoicePeriodOpen(NEW.delivery_id, NEW.invoice_date);
  IF OLD.status <> 'DRAFT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Confirmed or void invoices are immutable';
  END IF;
END$$
CREATE TRIGGER invoice_delete BEFORE DELETE ON SupplierInvoice FOR EACH ROW
BEGIN
  CALL AssertInvoicePeriodOpen(OLD.delivery_id, OLD.invoice_date);
  IF OLD.status <> 'DRAFT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Confirmed or void invoices cannot be deleted';
  END IF;
END$$

CREATE TRIGGER payment_insert BEFORE INSERT ON Payment FOR EACH ROW
BEGIN
  DECLARE v_due DECIMAL(12,2);
  DECLARE v_paid DECIMAL(14,2);
  SELECT amount INTO v_due FROM Bill WHERE bill_id = NEW.bill_id FOR UPDATE;
  SELECT COALESCE(SUM(amount),0) INTO v_paid FROM Payment WHERE bill_id = NEW.bill_id FOR UPDATE;
  IF NEW.amount + v_paid > v_due THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds household outstanding balance';
  END IF;
END$$
CREATE TRIGGER supplier_payment_insert BEFORE INSERT ON SupplierPayment FOR EACH ROW
BEGIN
  DECLARE v_due DECIMAL(12,2);
  DECLARE v_paid DECIMAL(14,2);
  DECLARE v_status VARCHAR(16);
  SELECT amount, status INTO v_due, v_status FROM SupplierInvoice
  WHERE supplier_invoice_id = NEW.supplier_invoice_id FOR UPDATE;
  SELECT COALESCE(SUM(amount),0) INTO v_paid FROM SupplierPayment
  WHERE supplier_invoice_id = NEW.supplier_invoice_id FOR UPDATE;
  IF v_status <> 'CONFIRMED' OR NEW.amount + v_paid > v_due THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier payment requires confirmed invoice and sufficient balance';
  END IF;
END$$

-- Financial entries are append-only; corrections need a future audited credit-note workflow.
CREATE TRIGGER payment_update BEFORE UPDATE ON Payment FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments are immutable'; END$$
CREATE TRIGGER payment_delete BEFORE DELETE ON Payment FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments are immutable'; END$$
CREATE TRIGGER supplier_payment_update BEFORE UPDATE ON SupplierPayment FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments are immutable'; END$$
CREATE TRIGGER supplier_payment_delete BEFORE DELETE ON SupplierPayment FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments are immutable'; END$$
CREATE TRIGGER bill_update BEFORE UPDATE ON Bill FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bills are immutable'; END$$
CREATE TRIGGER bill_delete BEFORE DELETE ON Bill FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bills are immutable'; END$$
CREATE TRIGGER period_update BEFORE UPDATE ON BillingPeriod FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Billing periods are immutable'; END$$
CREATE TRIGGER period_delete BEFORE DELETE ON BillingPeriod FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Billing periods are immutable'; END$$

CREATE TRIGGER allocation_insert BEFORE INSERT ON WaterAllocation FOR EACH ROW
BEGIN
  DECLARE v_society BIGINT UNSIGNED;
  DECLARE v_household_society BIGINT UNSIGNED;
  DECLARE v_litres DECIMAL(12,2);
  DECLARE v_allocated DECIMAL(14,2);
  SELECT delivered_litres INTO v_litres FROM Delivery WHERE delivery_id = NEW.delivery_id FOR UPDATE;
  SELECT b.society_id INTO v_society FROM Delivery d JOIN TankerBooking b USING (booking_id)
  WHERE d.delivery_id = NEW.delivery_id;
  SELECT society_id INTO v_household_society FROM Household WHERE household_id = NEW.household_id;
  SELECT COALESCE(SUM(allocated_litres),0) INTO v_allocated FROM WaterAllocation
  WHERE delivery_id = NEW.delivery_id FOR UPDATE;
  IF v_society <> v_household_society OR v_allocated + NEW.allocated_litres > v_litres THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Allocation must belong to delivery society and fit delivered volume';
  END IF;
END$$
CREATE TRIGGER allocation_update BEFORE UPDATE ON WaterAllocation FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Allocations are immutable'; END$$
CREATE TRIGGER allocation_delete BEFORE DELETE ON WaterAllocation FOR EACH ROW
BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Allocations are immutable'; END$$

-- Call standalone, outside an existing transaction. Entire generation is atomic.
-- Expenses use invoice_date, not payment date. DRAFT/VOID invoices are excluded.
CREATE PROCEDURE GenerateMonthlyBills(IN p_society BIGINT UNSIGNED, IN p_month DATE, IN p_due DATE)
BEGIN
  DECLARE v_lock BIGINT UNSIGNED DEFAULT NULL;
  DECLARE v_count INT UNSIGNED;
  DECLARE v_total DECIMAL(14,2);
  DECLARE v_cents BIGINT;
  DECLARE v_period BIGINT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  IF p_month IS NULL OR DAYOFMONTH(p_month) <> 1 OR p_due IS NULL OR p_due < p_month THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Use first day of billing month and a valid due date';
  END IF;
  SELECT society_id INTO v_lock FROM Society WHERE society_id = p_society FOR UPDATE;
  IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Society does not exist'; END IF;
  IF EXISTS (SELECT 1 FROM BillingPeriod WHERE society_id = p_society AND month_start = p_month) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Monthly bills already generated';
  END IF;
  SELECT COUNT(*) INTO v_count FROM Household WHERE society_id = p_society AND is_active = TRUE
    AND joined_on <= LAST_DAY(p_month) AND (left_on IS NULL OR left_on >= p_month) FOR UPDATE;
  SELECT COALESCE(SUM(i.amount),0) INTO v_total FROM SupplierInvoice i
    JOIN Delivery d USING (delivery_id) JOIN TankerBooking b USING (booking_id)
    WHERE b.society_id = p_society AND i.status = 'CONFIRMED'
    AND i.invoice_date >= p_month AND i.invoice_date < DATE_ADD(p_month, INTERVAL 1 MONTH);
  IF v_count = 0 OR v_total = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Billing requires eligible active households and confirmed expenses';
  END IF;
  SET v_cents = v_total * 100;
  INSERT INTO BillingPeriod(society_id, month_start, due_date, confirmed_expense, eligible_households)
  VALUES(p_society, p_month, p_due, v_total, v_count);
  SET v_period = LAST_INSERT_ID();
  INSERT INTO Bill(billing_period_id, society_id, household_id, amount)
  SELECT v_period, p_society, household_id,
    ((v_cents DIV v_count) + IF(ROW_NUMBER() OVER (ORDER BY household_id) <= MOD(v_cents,v_count),1,0))/100
  FROM Household WHERE society_id = p_society AND is_active = TRUE
    AND joined_on <= LAST_DAY(p_month) AND (left_on IS NULL OR left_on >= p_month);
  COMMIT;
END$$
DELIMITER ;
