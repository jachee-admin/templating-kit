###### APEX / SQL Developer

# CSV Import via SQL Developer: Staging, Validation, and Safe Bulk Loads

Importing CSV data into Oracle should always be a **two-stage operation**:
(1) ingest raw data exactly as received, and
(2) transform → validate → merge into clean target tables.

---

## TL;DR

* Use SQL Developer’s **Import Data Wizard** for first-pass loads.
* Always import into a **staging (raw) table** first — never straight into production tables.
* Define **explicit datatypes and date masks** in the wizard to avoid implicit conversions.
* Validate, then transform, and finally load into target tables using `INSERT … SELECT` or `MERGE`.
* Use **`LOG ERRORS`** for bulk inserts/merges to capture bad rows without aborting the batch.

---

## 1️⃣ Prepare a Staging Table

Before touching the wizard, pre-create a table that mirrors the CSV layout *exactly as delivered* — strings as `VARCHAR2`, numeric columns as `NUMBER`, and all dates as `VARCHAR2(30)` until parsed.

```sql
create table stage_invoices (
  invoice_id     varchar2(40),
  invoice_date   varchar2(30),
  customer_name  varchar2(100),
  amount_raw     varchar2(30),
  raw_line       varchar2(4000)
);
```

This keeps ingestion tolerant of bad formatting, missing fields, or unexpected delimiters.

---

## 2️⃣ Run the SQL Developer Import Wizard

**Path:**
Right-click the staging table → *Import Data…* → select the CSV file.

**Settings to verify:**

| Option                | Recommended Setting                               |
| --------------------- | ------------------------------------------------- |
| File Encoding         | UTF-8                                             |
| Delimiter             | comma (or tab)                                    |
| Date Format           | match source (e.g. `DD-MON-YYYY` or `YYYY-MM-DD`) |
| Decimal Separator     | `.` (ensure consistency)                          |
| “First row is header” | ✅                                                 |
| “Commit after insert” | unchecked (you’ll commit manually)                |

Let the wizard preview data. Adjust datatypes if any column shows as “Unsupported”.

---

## 3️⃣ Normalize Data into Target Tables

Transform and validate inside the database:

```sql
insert /*+ append */ into invoices (invoice_id, invoice_date, customer_id, amount)
select
    trim(invoice_id),
    to_date(invoice_date, 'YYYY-MM-DD'),
    c.id,
    to_number(amount_raw)
from stage_invoices s
join customers c on c.name = s.customer_name
log errors into err$_invoices ('LOAD_STAGE') reject limit unlimited;

commit;
```

This separates **data wrangling** from ingestion and leverages `LOG ERRORS`.

---

## 4️⃣ Enable Error Logging Table

Create the logging table once per target:

```sql
begin
  dbms_errlog.create_error_log(dml_table_name => 'INVOICES');
end;
/
```

Later, inspect errors:

```sql
select ora_err_number$, ora_err_mesg$, ora_err_tag$, invoice_id
from err$_invoices
order by ora_err_number$;
```

---

## 5️⃣ Validate and Clean Up

* Count rows vs. CSV record count.
* Spot-check dates and numeric ranges (`is not null`, `is number`).
* Delete or archive the staging data once reconciled.
* If recurring, script this pipeline as a SQLcl or Scheduler job.

---

## 6️⃣ Advanced: Automating with SQLcl / APEX

In **SQLcl**, run:

```bash
sql -cloud user@tns_alias "load invoices from 'data/invoices.csv'"
```

Or in APEX, use a File Browse + `apex_data_parser` package for web-based ingestion:

```plsql
declare
  l_data apex_data_parser.t_data;
begin
  l_data := apex_data_parser.parse(
               p_content         => :P10_FILE_BLOB,
               p_file_name       => :P10_FILE_NAME,
               p_add_headers_row => 'Y');

  for i in 1 .. l_data.count loop
    insert into stage_invoices (invoice_id, invoice_date, customer_name, amount_raw)
    values (
      l_data(i).col001, l_data(i).col002, l_data(i).col003, l_data(i).col004 );
  end loop;
end;
```

---

## Notes

* Never rely on automatic type inference — explicit beats implicit.
* Stage → validate → merge is repeatable and rollback-safe.
* Always review the `LOG ERRORS` output — bad data almost always hides bigger issues upstream.
* For recurring feeds, wrap the pattern in a stored procedure and schedule via DBMS_SCHEDULER.

---

```yaml
---
id: docs/apex/05-csv-import-sql-developer.md
lang: sql
platform: oracle
scope: data-load
since: "v0.1"
tested_on: "Oracle 23ai / SQL Developer 24.1"
tags: [sql-developer, csv, import, staging, log-errors, data-quality]
description: "Robust CSV import workflow using SQL Developer wizard, staging tables, transformation layer, and LOG ERRORS for safe bulk loads."
---
```

