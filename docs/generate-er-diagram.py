"""Generate and validate documentation from schema.sql; never connects to MySQL.

Run from any directory: python docs/generate-er-diagram.py
Uses only the Python standard library. SVG uses explicit multiplicity labels.
"""
from pathlib import Path
import re
from html import escape
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / 'database/schema.sql').read_text(encoding='utf-8')
tables = {}
foreign_keys = []
unique_keys = {}
for match in re.finditer(r'CREATE TABLE `?(\w+)`? \((.*?)\) ENGINE=InnoDB;', SQL, re.S):
    name, body = match.groups()
    columns = []
    unique_keys[name] = []
    for raw in body.splitlines():
        line = raw.strip().rstrip(',')
        col = re.match(r'(\w+) (BIGINT UNSIGNED|INT UNSIGNED|VARCHAR\(\d+\)|CHAR\(\d+\)|DECIMAL\(\d+,\d+\)|DATE\b|DATETIME\b|TIMESTAMP\b|BOOLEAN\b)(.*)', line)
        if col:
            field, dtype, rest = col.groups()
            columns.append(dict(name=field, type=dtype, nullable='NOT NULL' not in rest and 'PRIMARY KEY' not in rest,
                                pk='PRIMARY KEY' in rest, uk='UNIQUE' in rest, auto='AUTO_INCREMENT' in rest))
            if 'UNIQUE' in rest:
                unique_keys[name].append((field,))
        uk = re.match(r'UNIQUE KEY (\w+) \(([^)]+)\)', line)
        if uk:
            unique_keys[name].append(tuple(x.strip() for x in uk[2].split(',')))
        fk = re.match(r'FOREIGN KEY \(([^)]+)\) REFERENCES (\w+)\(([^)]+)\)', line)
        if fk:
            foreign_keys.append((name, tuple(x.strip() for x in fk[1].split(',')), fk[2], tuple(x.strip() for x in fk[3].split(','))))
    tables[name] = columns

labels = {
    ('Household', 'Society'): 'contains', ('TankerBooking', 'Society'): 'requests',
    ('TankerBooking', 'Supplier'): 'supplies', ('Delivery', 'TankerBooking'): 'fulfills',
    ('BillingPeriod', 'Society'): 'defines_month', ('SupplierInvoice', 'Delivery'): 'supplier_invoice',
    ('SupplierPayment', 'SupplierInvoice'): 'supplier_payment', ('Bill', 'BillingPeriod'): 'household_bill',
    ('Bill', 'Household'): 'owes', ('Payment', 'Bill'): 'household_payment',
    ('WaterAllocation', 'Delivery'): 'distributes', ('WaterAllocation', 'Household'): 'receives_water',
    ('User', 'Society'): 'authorizes', ('User', 'Household'): 'optional_membership',
}
assert len(tables) == 12 and len(foreign_keys) == 14
relations = []
for child, fields, parent, refs in foreign_keys:
    assert all(any(c['name'] == f for c in tables[child]) for f in fields)
    assert all(any(c['name'] == f for c in tables[parent]) for f in refs)
    optional = any(c['nullable'] for c in tables[child] if c['name'] in fields)
    single = any(set(key).issubset(fields) for key in unique_keys[child])
    relations.append((parent, child, fields, refs, '0..1' if optional else '1', '0..1' if single else '0..*', labels[child, parent]))

mermaid = ['erDiagram', '    direction TB']
for parent, child, fields, refs, pcard, ccard, label in relations:
    mermaid.append(f'    {parent} {"o|" if pcard == "0..1" else "||"}..{"o|" if ccard == "0..1" else "o{"} {child} : {label}')
for table, columns in tables.items():
    mermaid.append(f'    {table} {{')
    for col in columns:
        keys = [k for k, yes in [('PK', col['pk']), ('FK', any(table == ch and col['name'] in fs for ch, fs, _, _ in foreign_keys)), ('UK', col['uk'])] if yes]
        # Mermaid's type token cannot contain spaces; exact SQL type is also in the comment.
        notes = col['type'] + ('; NULL' if col['nullable'] else '; NOT NULL') + ('; AUTO_INCREMENT' if col['auto'] else '')
        mermaid.append(f'        {col["type"].replace(" ", "_")} {col["name"]}{" " + ",".join(keys) if keys else ""} "{notes}"')
    mermaid.append('    }')
mermaid_text = '\n'.join(mermaid) + '\n'
(ROOT / 'docs/er-diagram.mmd').write_text(mermaid_text, encoding='utf-8')

intro = '''# WASSER Entity Relationship Diagram

Source of truth: [`database/schema.sql`](../database/schema.sql). This document describes the SQL definitions, including nullable and unique constraints, without connecting to or changing the database. There are **12 base tables, 14 foreign-key constraints, and 2 derived views**. Views are described below and are not extra entities.

Open the [printable SVG](er-diagram.svg) in a browser and print in landscape (A3 recommended, fit to page). It is a vector diagram and stays sharp when enlarged. The [standalone Mermaid source](er-diagram.mmd) supports rendering in Mermaid tools. The SVG uses the same parsed attributes and relationships, with explicit endpoint multiplicities and a numbered relationship key.

## Complete Mermaid ER diagram

`PK` = primary key; `FK` = foreign-key component; `UK` = single-column unique constraint. Composite unique keys are listed separately below. Types retain SQL lengths, precision and scale; underscores represent spaces in Mermaid type tokens (for example `BIGINT_UNSIGNED`). Exact SQL types and nullability also appear in attribute comments. All primary keys are auto-incrementing.

`||` means exactly one, `o|` zero or one, and `o{` zero or many. Dotted lines are non-identifying relationships: each child has its own primary key, independent of the foreign key. A parent can have zero children unless SQL actually enforces their existence.

```mermaid
'''
relationship_rows = ['| ID | Parent → child | Parent per child | Children per parent | Actual foreign key |', '| --- | --- | --- | --- | --- |']
for i, (parent, child, fields, refs, pcard, ccard, _) in enumerate(relations, 1):
    relationship_rows.append(f'| R{i} | {parent} → {child} | {pcard} | {ccard} | `{child}({", ".join(fields)})` → `{parent}({", ".join(refs)})` |')
unique_rows = ['| Table | Unique column sets (besides primary key) |', '| --- | --- |']
for table, keys in unique_keys.items():
    if keys:
        unique_rows.append(f'| {table} | ' + '; '.join('`(' + ', '.join(key) + ')`' for key in keys) + ' |')
notes = '''
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
'''
(ROOT / 'docs/er-diagram.md').write_text(intro + mermaid_text + '```\n\n## Relationships and cardinalities\n\n' + '\n'.join(relationship_rows) + '\n\n## Unique constraints\n\n' + '\n'.join(unique_rows) + '\n' + notes, encoding='utf-8')

# Deterministic printable SVG, independent of browser/Mermaid installations.
positions = {'Society': (0, 0), 'Household': (1, 0), 'User': (2, 0),
             'Supplier': (0, 1), 'TankerBooking': (1, 1), 'BillingPeriod': (2, 1),
             'Delivery': (0, 2), 'WaterAllocation': (1, 2), 'Bill': (2, 2),
             'SupplierInvoice': (0, 3), 'SupplierPayment': (1, 3), 'Payment': (2, 3)}
W, H, CW, CH = 2100, 2360, 510, 330
xy = {t: (100 + c * 690, 170 + r * 440) for t, (c, r) in positions.items()}
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
       '<title id="title">WASSER complete database ER diagram</title>',
       '<desc id="desc">12 tables with all attributes and 14 foreign keys. Supplier billing and household billing have separate labeled entities. Endpoint numbers and relationship key show actual multiplicities.</desc>',
       '<style>text{font-family:Arial,sans-serif;fill:#073B4C}.attr{font-family:Consolas,monospace;font-size:15px}.edge{fill:none;stroke:#073B4C;stroke-width:2}.tag{font-size:16px;font-weight:bold;paint-order:stroke;stroke:white;stroke-width:6;stroke-linejoin:round}</style>',
       f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>',
       '<text x="100" y="55" font-size="34" font-weight="bold">WASSER · Entity Relationship Diagram</text>',
       '<text x="100" y="90" font-size="21">12 tables · 14 foreign keys · Source: database/schema.sql · Aqua Mint</text>',
       '<text x="100" y="123" font-size="18">PK primary key | FK foreign-key component | UK single-column unique | ? nullable | U unsigned</text>',
       '<text x="100" y="149" font-size="18">Each line connects a parent to a child; endpoint labels give multiplicity. Full constraints appear in the key below.</text>']
for i, (parent, child, fields, refs, pc, cc, label) in enumerate(relations, 1):
    x1, y1 = xy[parent]; x2, y2 = xy[child]
    if y1 == y2:
        if x1 < x2:
            a, b = (x1 + CW, y1 + 90 + i * 3), (x2, y2 + 90 + i * 3)
        else:
            a, b = (x1, y1 + 150), (x2 + CW, y2 + 150)
        if abs(x2 - x1) > 690:
            a, b = (x1 + CW / 2, y1), (x2 + CW / 2, y2)
            path = f'M {a[0]} {a[1]} V {y1-12} H {b[0]} V {b[1]}'
        else:
            path = f'M {a[0]} {a[1]} L {b[0]} {b[1]}'
    elif x1 == x2:
        a, b = (x1 + 200, y1 + CH), (x2 + 200, y2)
        path = f'M {a[0]} {a[1]} L {b[0]} {b[1]}'
    else:
        # Use the horizontal and vertical gutters between cards.
        sign = 1 if x2 > x1 else -1
        a = (x1 + (CW if sign == 1 else 0), y1 + 230 + (i % 3) * 18)
        b = (x2 + CW / 2 + (i % 3) * 25, y2 if y2 > y1 else y2 + CH)
        gutter_x = a[0] + sign * (35 + i * 3)
        gutter_y = y2 - (30 + (i % 3) * 20) if y2 > y1 else y2 + CH + 30
        path = f'M {a[0]} {a[1]} H {gutter_x} V {gutter_y} H {b[0]} V {b[1]}'
    svg.append(f'<path class="edge" d="{path}"/>')
    def tag_position(point, box_x, box_y, parent_end=False):
        px, py = point
        if py == box_y:
            return px + 5, py - 7
        if py == box_y + CH:
            return px + 5, py + 23
        if px == box_x:
            return px - (105 if parent_end else 57), py - 7
        return px + 5, py - 7
    ax, ay = tag_position(a, x1, y1, True)
    bx, by = tag_position(b, x2, y2)
    svg.append(f'<text class="tag" x="{ax}" y="{ay}">R{i} · {pc}</text>')
    svg.append(f'<text class="tag" x="{bx}" y="{by}">{cc}</text>')
for table, columns in tables.items():
    x, y = xy[table]
    supplier = table in ('SupplierInvoice', 'SupplierPayment')
    household = table in ('BillingPeriod', 'Bill', 'Payment')
    subtitle = 'SUPPLIER BILLING' if supplier else 'HOUSEHOLD BILLING' if household else 'SUPPLY / MEMBERSHIP'
    svg += [f'<rect x="{x}" y="{y}" width="{CW}" height="{CH}" rx="9" fill="#E8FFF8" stroke="#073B4C" stroke-width="2"/>',
            f'<rect x="{x+1}" y="{y+1}" width="{CW-2}" height="65" rx="8" fill="{"#00A6A6" if supplier else "#6EE7C8"}"/>',
            f'<text x="{x+14}" y="{y+27}" font-size="23" font-weight="bold">{table}</text>',
            f'<text x="{x+14}" y="{y+51}" font-size="14">{subtitle}</text>']
    for j, col in enumerate(columns):
        keys = ','.join(k for k, yes in [('PK', col['pk']), ('FK', any(table == ch and col['name'] in fs for ch, fs, _, _ in foreign_keys)), ('UK', col['uk'])] if yes)
        dtype = col['type'].replace(' UNSIGNED', ' U')
        value = f'{col["name"]}{"?" if col["nullable"] else ""} : {dtype} {keys}'
        svg.append(f'<text class="attr" x="{x+13}" y="{y+90+j*25}">{escape(value)}</text>')
svg.append('<text x="100" y="1945" font-size="25" font-weight="bold">Relationship key · parent [multiplicity] → child [multiplicity]</text>')
for i, (parent, child, fields, refs, pc, cc, label) in enumerate(relations, 1):
    col, row = (i-1) // 7, (i-1) % 7
    svg.append(f'<text x="{100+col*1000}" y="{1980+row*33}" font-size="18">R{i}: {parent} [{pc}] → {child} [{cc}]</text>')
svg += ['<text x="100" y="2230" font-size="18">Composite FKs: Bill(period, society) → BillingPeriod; Bill(household, society) → Household;</text>',
        '<text x="100" y="2258" font-size="18">User(household, society) → Household. Exact column names and composite unique keys: docs/er-diagram.md.</text>',
        '<text x="100" y="2295" font-size="18">Supplier invoices feed monthly expense calculation through GenerateMonthlyBills; no direct invoice-to-period FK exists.</text>',
        '<text x="100" y="2325" font-size="18">Views (not tables): HouseholdBalance, SupplierInvoiceBalance. PKs auto-increment. SQL is unchanged.</text>', '</svg>']
svg_text = '\n'.join(svg)
ET.fromstring(svg_text)
(ROOT / 'docs/er-diagram.svg').write_text(svg_text, encoding='utf-8')

# Independently read the emitted Mermaid and compare its entities and attributes.
emitted = (ROOT / 'docs/er-diagram.mmd').read_text(encoding='utf-8')
blocks = dict(re.findall(r'^    (\w+) \{\n(.*?)^    \}', emitted, re.M | re.S))
assert set(blocks) == set(tables)
count = 0
for table, columns in tables.items():
    lines = blocks[table].strip().splitlines()
    assert len(lines) == len(columns)
    for line, col in zip(lines, columns):
        parts = line.strip().split(' ', 2)
        assert parts[:2] == [col['type'].replace(' ', '_'), col['name']]
        expected = [k for k, yes in [('PK', col['pk']), ('FK', any(table == ch and col['name'] in fs for ch, fs, _, _ in foreign_keys)), ('UK', col['uk'])] if yes]
        actual = parts[2].split(' ', 1)[0] if not parts[2].startswith('"') else ''
        assert actual == ','.join(expected)
        count += 1
edges = re.findall(r'^    (\w+) (\S+) (\w+) : (\w+)$', emitted, re.M)
expected_edges = [(p, ('o|' if pc == '0..1' else '||') + '..' + ('o|' if cc == '0..1' else 'o{'), ch, label) for p, ch, _, _, pc, cc, label in relations]
assert edges == expected_edges
assert f'```mermaid\n{emitted}```' in (ROOT / 'docs/er-diagram.md').read_text(encoding='utf-8')
print(f'PASS: {len(tables)} tables, {count} attributes/types/key markers, {len(edges)} FK relationships/cardinalities; SVG XML valid. No database access.')
