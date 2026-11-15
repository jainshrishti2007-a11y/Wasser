// Verify installed rules and the supplied demo. Negative checks roll back their transaction.
import assert from 'node:assert/strict';
import { pool } from '../src/config/db.js';

let db;
try {
  db = await pool.getConnection();
  for (const [catalog, schema, type, expected] of [
    ['TABLES', 'TABLE_SCHEMA', "AND TABLE_TYPE='BASE TABLE'", 12],
    ['TABLES', 'TABLE_SCHEMA', "AND TABLE_TYPE='VIEW'", 2],
    ['TRIGGERS', 'TRIGGER_SCHEMA', '', 22],
    ['ROUTINES', 'ROUTINE_SCHEMA', '', 2],
  ]) {
    const [[row]] = await db.query(`SELECT COUNT(*) n FROM information_schema.${catalog} WHERE ${schema}=DATABASE() ${type}`);
    assert.equal(row.n, expected, `Incomplete schema: ${catalog} ${type} expected ${expected}, found ${row.n}`);
  }
  const [periods] = await db.query(`SELECT bp.*, COUNT(b.bill_id) n, SUM(b.amount) billed,
    MAX(b.amount)-MIN(b.amount) spread FROM BillingPeriod bp JOIN Bill b USING(billing_period_id,society_id)
    GROUP BY bp.billing_period_id`);
  assert.ok(periods.length, 'No monthly billing data; seed first');
  for (const period of periods) {
    assert.equal(period.billed, period.confirmed_expense, 'Billing total must reconcile');
    assert.equal(period.n, period.eligible_households, 'Eligible count must reconcile');
    assert.ok(Number(period.spread) <= 0.01, 'Equal shares differ by more than one paise');
  }
  const [[demo]] = await db.query(`SELECT bp.society_id, bp.billing_period_id FROM BillingPeriod bp
    JOIN Society s USING(society_id) WHERE s.name='WASSER Demo - Shantivan Heights'
    AND bp.month_start='2026-10-01'`);
  assert.ok(demo, 'Demo billing period missing');
  const [[bill]] = await db.query('SELECT bill_id FROM Bill WHERE billing_period_id=? ORDER BY bill_id LIMIT 1', [demo.billing_period_id]);
  const [[booking]] = await db.query("SELECT booking_id FROM TankerBooking WHERE society_id=? AND status='DELIVERED' LIMIT 1", [demo.society_id]);
  const [[invoice]] = await db.query(`SELECT i.supplier_invoice_id FROM SupplierInvoice i JOIN Delivery d USING(delivery_id)
    JOIN TankerBooking b USING(booking_id) WHERE b.society_id=? LIMIT 1`, [demo.society_id]);
  const reject = async (sql, params, expectedMessage) => {
    await db.beginTransaction();
    try {
      await assert.rejects(db.query(sql, params), error => error.code === 'ER_SIGNAL_EXCEPTION' && error.sqlMessage.includes(expectedMessage));
    } finally { await db.rollback(); }
  };
  await reject("UPDATE TankerBooking SET status='REQUESTED' WHERE booking_id=?", [booking.booking_id], 'Invalid booking status transition');
  await reject("INSERT INTO Payment(bill_id,paid_on,amount,method,reference_number) VALUES(?,CURRENT_DATE,999999,'UPI','VERIFY-ROLLBACK-PAYMENT')", [bill.bill_id], 'Payment exceeds');
  await reject("INSERT INTO SupplierPayment(supplier_invoice_id,paid_on,amount,method,reference_number) VALUES(?,CURRENT_DATE,999999,'NEFT','VERIFY-ROLLBACK-SUPPLIER')", [invoice.supplier_invoice_id], 'sufficient balance');
  await reject('UPDATE SupplierInvoice SET amount=amount+1 WHERE supplier_invoice_id=?', [invoice.supplier_invoice_id], 'already billed');
  // The procedure owns its transaction; duplicate-month rejection rolls it back itself.
  await assert.rejects(db.query("CALL GenerateMonthlyBills(?,'2026-10-01','2026-11-10')", [demo.society_id]),
    error => error.code === 'ER_SIGNAL_EXCEPTION' && error.sqlMessage.includes('already generated'));
  console.log('Phase 2 verification passed: schema inventory, reconciliation, equal shares, status transitions, overpayments, closed invoices and duplicate-month rejection.');
} catch (error) {
  console.error(`Phase 2 verification failed: ${error.message}`);
  process.exitCode = 1;
} finally {
  db?.release();
  await pool.end();
}
