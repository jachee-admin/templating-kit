---
id: sql/oracle/plsql/variables-constants-19c
lang: sql
platform: oracle
scope: plsql
since: "v0.3"
tested_on: "Oracle 19c"
tags: [plsql, variables, constants, datatypes]
description: "Examples of declaring variables and constants for the major Oracle 19c PL/SQL scalar datatypes."
---
###### Oracle PL/SQL
### Variables & Constants — Oracle 19c scalar datatypes
One-file tour of the usual suspects. Each declaration shows idiomatic defaults and constant forms. Prefer `PLS_INTEGER`/`SIMPLE_INTEGER` for loop counters, `VARCHAR2` over `CHAR`, and LOBs over legacy `LONG`/`LONG RAW`.

```sql
DECLARE
  --------------------------------------------------------------------
  -- Numeric family
  --------------------------------------------------------------------
  -- General-purpose exact numeric
  c_tax_rate   CONSTANT NUMBER(5,2) := 7.50;
  v_amount     NUMBER(12,2)         := 0;
  v_unscaled   NUMBER               := 42;              -- arbitrary precision

  -- Integer (PL/SQL-only) — fastest on PL/SQL engine
  v_count_pls  PLS_INTEGER          := 0;
  c_limit_pls  CONSTANT PLS_INTEGER := 100;

  -- SIMPLE_* are NOT NULL and overflow-checking can be optimized
  v_fast_i     SIMPLE_INTEGER       := 1;               -- implicitly NOT NULL
  v_fast_f     SIMPLE_FLOAT         := 3.14159;         -- binary float semantics
  v_fast_d     SIMPLE_DOUBLE        := 2.7182818284;    -- binary double semantics

  -- IEEE 754 binary floats (good for scientific/approx)
  v_bf         BINARY_FLOAT         := 1.5;
  v_bd         BINARY_DOUBLE        := 1.5;

  -- Legacy integer synonym (still valid, prefer PLS_INTEGER)
  v_binint     BINARY_INTEGER       := -7;

  --------------------------------------------------------------------
  -- Character & national character
  --------------------------------------------------------------------
  v_name       VARCHAR2(100);                             -- most common
  c_code       CONSTANT VARCHAR2(10) := 'NC-DPI';
  v_fixed      CHAR(10)              := RPAD('Y', 10);    -- fixed-width (avoid unless needed)

  -- National character set
  v_nname      NVARCHAR2(80);
  v_nfixed     NCHAR(10);

  --------------------------------------------------------------------
  -- RAW and byte-oriented
  --------------------------------------------------------------------
  v_raw        RAW(16);                                   -- e.g., GUID/bytes
  -- v_long_raw LONG RAW;                                 -- legacy; avoid in new code

  --------------------------------------------------------------------
  -- Date & time
  --------------------------------------------------------------------
  v_date       DATE                    := SYSDATE;        -- date + time (no TZ)
  v_ts         TIMESTAMP               := SYSTIMESTAMP;   -- fractional seconds
  v_tstz       TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;
  v_tslTZ      TIMESTAMP WITH LOCAL TIME ZONE := SYSTIMESTAMP; -- stored normalized to DB TZ

  -- Intervals
  v_iym        INTERVAL YEAR TO MONTH := INTERVAL '1-6' YEAR TO MONTH;   -- 1 year 6 months
  v_ids        INTERVAL DAY TO SECOND := INTERVAL '3 12:30:15.123' DAY TO SECOND;

  --------------------------------------------------------------------
  -- LOBs (large objects)
  --------------------------------------------------------------------
  v_text       CLOB;
  v_ntext      NCLOB;
  v_blob       BLOB;
  v_bfile      BFILE;                                     -- external read-only file

  --------------------------------------------------------------------
  -- Identifiers and locators
  --------------------------------------------------------------------
  v_rowid      ROWID;
  v_urowid     UROWID;

  --------------------------------------------------------------------
  -- Boolean (PL/SQL-only)
  --------------------------------------------------------------------
  v_flag       BOOLEAN                := TRUE;
  c_false      CONSTANT BOOLEAN       := FALSE;

  --------------------------------------------------------------------
  -- Anchored declarations (respect table/type changes)
  --------------------------------------------------------------------
  v_emp_id     employees.employee_id%TYPE;
  v_emp_row    employees%ROWTYPE;

  --------------------------------------------------------------------
  -- User-defined object & XML (commonly encountered built-ins)
  --------------------------------------------------------------------
  -- XMLTYPE is a SQL object type; useful for XML processing
  v_xml        XMLTYPE := XMLTYPE('<root/>');

  -- Example constant from expression
  c_zero   CONSTANT NUMBER := 0;
BEGIN
  NULL; -- demo block
END;
/
```

**Notes**
- `SIMPLE_INTEGER`, `SIMPLE_FLOAT`, and `SIMPLE_DOUBLE` are `NOT NULL` by design and can enable faster math in tight loops.
- `TIMESTAMP WITH LOCAL TIME ZONE` stores in DB time zone; clients see local time on fetch.
- Prefer `CLOB/BLOB` to `LONG/LONG RAW`. Keep LOB I/O inside transactions short and consider temporary LOBs via `DBMS_LOB.createtemporary` for staging.
- Use `%TYPE`/`%ROWTYPE` to avoid drift when schemas evolve.
