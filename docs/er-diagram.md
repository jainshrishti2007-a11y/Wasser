# WASSER Entity Relationship Diagram

Source of truth: [`database/schema.sql`](../database/schema.sql). This document describes the SQL definitions, including nullable and unique constraints, without connecting to or changing the database. There are **12 base tables, 14 foreign-key constraints, and 2 derived views**. Views are described below and are not extra entities.

Open the [printable SVG](er-diagram.svg) in a browser and print in landscape (A3 recommended, fit to page). It is a vector diagram and stays sharp when enlarged. The [standalone Mermaid source](er-diagram.mmd) supports rendering in Mermaid tools. The SVG uses the same parsed attributes and relationships, with explicit endpoint multiplicities and a numbered relationship key.

## Complete Mermaid ER diagram

`PK` = primary key; `FK` = foreign-key component; `UK` = single-column unique constraint. Composite unique keys are listed separately below. Types retain SQL lengths, precision and scale; underscores represent spaces in Mermaid type tokens (for example `BIGINT_UNSIGNED`). Exact SQL types and nullability also appear in attribute comments. All primary keys are auto-incrementing.

`||` means exactly one, `o|` zero or one, and `o{` zero or many. Dotted lines are non-identifying relationships: each child has its own primary key, independent of the foreign key. A parent can have zero children unless SQL actually enforces their existence.

```mermaid
erDiagram
    direction TB
    Society ||..o{ Household : contains
    Society ||..o{ TankerBooking : requests
    Supplier ||..o{ TankerBooking : supplies
    TankerBooking ||..o| Delivery : fulfills
    Society ||..o{ BillingPeriod : defines_month
    Delivery ||..o| SupplierInvoice : supplier_invoice
    SupplierInvoice ||..o{ SupplierPayment : supplier_payment
    BillingPeriod ||..o{ Bill : household_bill
    Household ||..o{ Bill : owes
    Bill ||..o{ Payment : household_payment
    Delivery ||..o{ WaterAllocation : distributes
    Household ||..o{ WaterAllocation : receives_water
    Society ||..o{ User : authorizes
    Household o|..o{ User : optional_membership
    Society {
        BIGINT_UNSIGNED society_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        VARCHAR(150) name "VARCHAR(150); NOT NULL"
        VARCHAR(255) address "VARCHAR(255); NOT NULL"
        VARCHAR(80) city "VARCHAR(80); NOT NULL"
        VARCHAR(80) state "VARCHAR(80); NOT NULL"
        CHAR(6) postal_code "CHAR(6); NOT NULL"
    }
    Household {
        BIGINT_UNSIGNED household_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED society_id FK "BIGINT UNSIGNED; NOT NULL"
        VARCHAR(30) unit_number "VARCHAR(30); NOT NULL"
        VARCHAR(120) resident_name "VARCHAR(120); NOT NULL"
        VARCHAR(15) phone "VARCHAR(15); NOT NULL"
        DATE joined_on "DATE; NOT NULL"
        DATE left_on "DATE; NULL"
        BOOLEAN is_active "BOOLEAN; NOT NULL"
    }
    Supplier {
        BIGINT_UNSIGNED supplier_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        VARCHAR(150) name "VARCHAR(150); NOT NULL"
        VARCHAR(15) phone "VARCHAR(15); NOT NULL"
        VARCHAR(255) address "VARCHAR(255); NOT NULL"
        VARCHAR(15) gstin UK "VARCHAR(15); NULL"
    }
    TankerBooking {
        BIGINT_UNSIGNED booking_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED society_id FK "BIGINT UNSIGNED; NOT NULL"
        BIGINT_UNSIGNED supplier_id FK "BIGINT UNSIGNED; NOT NULL"
        DATETIME scheduled_at "DATETIME; NOT NULL"
        DECIMAL(12,2) requested_litres "DECIMAL(12,2); NOT NULL"
        DECIMAL(12,2) agreed_amount "DECIMAL(12,2); NOT NULL"
        VARCHAR(20) status "VARCHAR(20); NOT NULL"
    }
    Delivery {
        BIGINT_UNSIGNED delivery_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED booking_id FK,UK "BIGINT UNSIGNED; NOT NULL"
        DATETIME delivered_at "DATETIME; NOT NULL"
        DECIMAL(12,2) delivered_litres "DECIMAL(12,2); NOT NULL"
        VARCHAR(60) receipt_number UK "VARCHAR(60); NOT NULL"
    }
    BillingPeriod {
        BIGINT_UNSIGNED billing_period_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED society_id FK "BIGINT UNSIGNED; NOT NULL"
        DATE month_start "DATE; NOT NULL"
        DATE due_date "DATE; NOT NULL"
        DECIMAL(14,2) confirmed_expense "DECIMAL(14,2); NOT NULL"
        INT_UNSIGNED eligible_households "INT UNSIGNED; NOT NULL"
        TIMESTAMP generated_at "TIMESTAMP; NOT NULL"
    }
    SupplierInvoice {
        BIGINT_UNSIGNED supplier_invoice_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED delivery_id FK,UK "BIGINT UNSIGNED; NOT NULL"
        VARCHAR(60) invoice_number "VARCHAR(60); NOT NULL"
        DATE invoice_date "DATE; NOT NULL"
        DATE due_date "DATE; NOT NULL"
        DECIMAL(12,2) amount "DECIMAL(12,2); NOT NULL"
        VARCHAR(16) status "VARCHAR(16); NOT NULL"
    }
    SupplierPayment {
        BIGINT_UNSIGNED supplier_payment_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED supplier_invoice_id FK "BIGINT UNSIGNED; NOT NULL"
        DATE paid_on "DATE; NOT NULL"
        DECIMAL(12,2) amount "DECIMAL(12,2); NOT NULL"
        VARCHAR(16) method "VARCHAR(16); NOT NULL"
        VARCHAR(80) reference_number UK "VARCHAR(80); NOT NULL"
    }
    Bill {
        BIGINT_UNSIGNED bill_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED billing_period_id FK "BIGINT UNSIGNED; NOT NULL"
        BIGINT_UNSIGNED society_id FK "BIGINT UNSIGNED; NOT NULL"
        BIGINT_UNSIGNED household_id FK "BIGINT UNSIGNED; NOT NULL"
        DECIMAL(12,2) amount "DECIMAL(12,2); NOT NULL"
    }
    Payment {
        BIGINT_UNSIGNED payment_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED bill_id FK "BIGINT UNSIGNED; NOT NULL"
        DATE paid_on "DATE; NOT NULL"
        DECIMAL(12,2) amount "DECIMAL(12,2); NOT NULL"
        VARCHAR(16) method "VARCHAR(16); NOT NULL"
        VARCHAR(80) reference_number UK "VARCHAR(80); NOT NULL"
    }
    WaterAllocation {
        BIGINT_UNSIGNED water_allocation_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED delivery_id FK "BIGINT UNSIGNED; NOT NULL"
        BIGINT_UNSIGNED household_id FK "BIGINT UNSIGNED; NOT NULL"
        DECIMAL(12,2) allocated_litres "DECIMAL(12,2); NOT NULL"
    }
    User {
        BIGINT_UNSIGNED user_id PK "BIGINT UNSIGNED; NOT NULL; AUTO_INCREMENT"
        BIGINT_UNSIGNED society_id FK "BIGINT UNSIGNED; NOT NULL"
        BIGINT_UNSIGNED household_id FK "BIGINT UNSIGNED; NULL"
        VARCHAR(120) full_name "VARCHAR(120); NOT NULL"
        VARCHAR(254) email UK "VARCHAR(254); NOT NULL"
        VARCHAR(255) password_hash "VARCHAR(255); NULL"
        VARCHAR(20) role "VARCHAR(20); NOT NULL"
        BOOLEAN is_active "BOOLEAN; NOT NULL"
    }
```

## Relationships and cardinalities

| ID | Parent → child | Parent per child | Children per parent | Actual foreign key |
| --- | --- | --- | --- | --- |
| R1 | Society → Household | 1 | 0..* | `Household(society_id)` → `Society(society_id)` |
| R2 | Society → TankerBooking | 1 | 0..* | `TankerBooking(society_id)` → `Society(society_id)` |
| R3 | Supplier → TankerBooking | 1 | 0..* | `TankerBooking(supplier_id)` → `Supplier(supplier_id)` |
| R4 | TankerBooking → Delivery | 1 | 0..1 | `Delivery(booking_id)` → `TankerBooking(booking_id)` |
| R5 | Society → BillingPeriod | 1 | 0..* | `BillingPeriod(society_id)` → `Society(society_id)` |
| R6 | Delivery → SupplierInvoice | 1 | 0..1 | `SupplierInvoice(delivery_id)` → `Delivery(delivery_id)` |
| R7 | SupplierInvoice → SupplierPayment | 1 | 0..* | `SupplierPayment(supplier_invoice_id)` → `SupplierInvoice(supplier_invoice_id)` |
| R8 | BillingPeriod → Bill | 1 | 0..* | `Bill(billing_period_id, society_id)` → `BillingPeriod(billing_period_id, society_id)` |
| R9 | Household → Bill | 1 | 0..* | `Bill(household_id, society_id)` → `Household(household_id, society_id)` |
| R10 | Bill → Payment | 1 | 0..* | `Payment(bill_id)` → `Bill(bill_id)` |
| R11 | Delivery → WaterAllocation | 1 | 0..* | `WaterAllocation(delivery_id)` → `Delivery(delivery_id)` |
| R12 | Household → WaterAllocation | 1 | 0..* | `WaterAllocation(household_id)` → `Household(household_id)` |
| R13 | Society → User | 1 | 0..* | `User(society_id)` → `Society(society_id)` |
| R14 | Household → User | 0..1 | 0..* | `User(household_id, society_id)` → `Household(household_id, society_id)` |

## Unique constraints

| Table | Unique column sets (besides primary key) |
| --- | --- |
| Society | `(name, address)` |
| Household | `(society_id, unit_number)`; `(household_id, society_id)` |
| Supplier | `(gstin)` |
| TankerBooking | `(booking_id, society_id)` |
| Delivery | `(booking_id)`; `(receipt_number)` |
| BillingPeriod | `(society_id, month_start)`; `(billing_period_id, society_id)` |
| SupplierInvoice | `(delivery_id)` |
| SupplierPayment | `(reference_number)` |
| Bill | `(billing_period_id, household_id)` |
| Payment | `(reference_number)` |
| WaterAllocation | `(delivery_id, household_id)` |
| User | `(email)` |

## Supplier billing versus household billing

**Supplier billing (society pays the water supplier):** `Supplier → TankerBooking → Delivery → SupplierInvoice → SupplierPayment`. Each booking chooses one supplier and one society. A booking may have no delivery yet, or one delivery; a delivery may have no invoice yet, or one invoice. These optional one-to-one relationships come from the unique, non-null foreign keys on `Delivery.booking_id` and `SupplierInvoice.delivery_id`. An invoice may receive multiple partial supplier payments. Supplier and society are obtained through the booking; SupplierInvoice has no direct supplier_id or society_id.

**Household billing (resident pays the society):** `Society → BillingPeriod → Bill → Payment`, with `Household → Bill`. A period belongs to one society; each bill belongs to one period and one household. Multiple partial household payments can settle a bill. A household can receive bills over many periods, and a period can contain bills for many households. `Bill` associates those two entities, with one bill per household per period.

**How the two flows meet:** `GenerateMonthlyBills` sums CONFIRMED supplier invoice amounts for the society by invoice_date month, records the expense and eligibility snapshot in BillingPeriod, and divides the expense equally among eligible households. Integer-paise remainders go to ascending household IDs. Supplier payment dates and allocated litres do not determine household charges. This is a procedure-based calculation, **not a direct foreign-key relationship** between SupplierInvoice and BillingPeriod or Bill, so no such edge is drawn.

## Important constraints for the viva

- `Bill(billing_period_id, society_id)` references BillingPeriod, and `Bill(household_id, society_id)` references Household. Together they prevent billing a household from a different society. Bill.society_id is part of these two composite foreign keys; it has no separate foreign key to Society.
- User.society_id directly references Society. `(household_id, society_id)` also references Household. household_id may be NULL, so an account can belong to a society without a household; a CHECK requires RESIDENT accounts to have a household. A household can have many accounts because this foreign key is not unique. Any linked household must belong to the account's society.
- WaterAllocation connects deliveries and households, resolving a many-to-many relationship: each row stores the litres from one delivery allocated to one household, with at most one row per delivery/household pair. The insert trigger checks the same society and prevents allocating more than delivered. Unallocated water is allowed.
- BillingPeriod has at most one row per society/month. The billing procedure creates one bill per eligible household, but foreign keys alone allow a period with zero bills. Therefore the ER edge is `0..*`, not `1..*`.
- Every foreign key is mandatory except the optional household association on User. A mandatory child-to-parent link does not require a parent to have children.
- Supplier.gstin is nullable and unique; MySQL allows multiple NULL values in a unique column. SupplierInvoice.invoice_number is **not** unique. Household.phone, Supplier.phone and all payment method fields are included in the diagram.
- There are no cascading delete/update actions specified. InnoDB uses restrictive foreign-key behavior. Triggers additionally make receipts, payments, allocations, bills and billing periods immutable and enforce booking/invoice workflow rules. The ER diagram shows structural constraints; it does not claim workflow rules are foreign keys.
- HouseholdBalance derives each bill's paid and outstanding amounts from Bill and Payment. SupplierInvoiceBalance derives the corresponding supplier amounts from SupplierInvoice and SupplierPayment. These are views, not stored balance tables.

## Simple viva explanation

“A society has households and books water tankers from suppliers. A booking can produce one delivery receipt. That delivery can have one supplier invoice, which the society may pay in parts. WaterAllocation records how delivered water is distributed to households. Each month, the billing procedure totals confirmed supplier expenses and splits the cost equally among eligible households. It stores a billing period and individual household bills. Residents may pay their bills in parts. SupplierPayment records money going to suppliers; Payment records money collected from households. User stores society accounts and optionally links them to a household. Composite foreign keys ensure bills and linked accounts stay within the correct society.”

## Schema verification

Run `python docs/generate-er-diagram.py` from the repository root. The generator reads schema.sql only, checks the 12-table and 14-foreign-key inventory, validates referenced columns, and generates both diagrams from those definitions. It compares every Mermaid entity/attribute/type/key marker and every relationship with the parsed SQL before reporting success, and parses the SVG as XML. No SQL, credentials, network access, or database writes are involved. This verifies the documentation against the SQL file; it does not independently inspect the live MySQL server.

Reviewed corrections to the previous diagram: completed omitted attributes and type details; corrected BillingPeriod → Bill optionality; documented composite keys explicitly; and separated the two payment flows. All 12 actual base tables are represented, including BillingPeriod. No inferred direct invoice-to-period, supplier-to-invoice, or Society-to-Bill foreign key has been added.

## Official frontend palette: Aqua Mint

| Color | Hex | Intended use |
| --- | --- | --- |
| Deep Teal | `#073B4C` | Primary text and strong headings |
| Aqua | `#00A6A6` | Primary actions and accents |
| Mint | `#6EE7C8` | Supporting highlights |
| Mist | `#E8FFF8` | Soft backgrounds |
| White | `#FFFFFF` | Surfaces |

These five colors are the official frontend palette. This documentation does not change frontend styles. The printable diagram uses Aqua Mint colors and written labels to distinguish billing flows.
