---
id: sql/oracle/explain-plan-all-in-one
lang: sql
platform: oracle
scope: tuning
since: "v0.4"
tested_on: "Oracle 19c"
tags: [explain-plan, dbms_xplan, display_cursor, sql-monitor, autotrace, performance]
description: "All-in-one guide to preparing, running, and reading Oracle 19c execution plans with EXPLAIN PLAN, DBMS_XPLAN, DISPLAY_CURSOR (actuals), AUTOTRACE, and SQL Monitor."
---
###### Oracle PL/SQL
## EXPLAIN PLAN (Oracle 19c+)
Concise, practical reference for estimating plans, capturing actuals, and understanding what the plan is saying.

---

## 0) Prepare once (plan table + permissions)

```sql
-- Create PLAN_TABLE in your schema if missing
@?/rdbms/admin/utlxplan.sql

-- Optional: grant select on V$ views if you’ll use DISPLAY_CURSOR/SQL Monitor via a restricted account
-- (Typically not needed for normal developer accounts in non-prod.)
````

---

## 1) The three core ways to get a plan

### A) **Estimated plan** (static, optimizer estimate)

```sql
EXPLAIN PLAN FOR
SELECT /* test-estimate */ *
FROM   accounts
WHERE  email = :b1;

SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY(
  table_name => 'PLAN_TABLE',
  format     => 'BASIC +PREDICATE +PROJECTION +ALIAS'
));
```

**Use when:** sanity-checking join order, index usage, or hint effect **without** running the SQL.

---

### B) **Actual plan with runtime stats** (after executing the SQL)

```sql
-- 1) Ask Oracle to collect row source stats while you run the SQL:
SELECT /*+ GATHER_PLAN_STATISTICS */ *
FROM   accounts
WHERE  email = :b1;

-- 2) Immediately display the *executed* plan with A-Rows (actual rows):
SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
  sql_id    => NULL,   -- last statement in this session
  cursor_child_no => NULL,
  format    => 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +NOTE'
));
```

**Use when:** you need to see *A-Rows* (actual rows per step) and compare them to *E-Rows* (estimated rows).

> Tip: If the SQL already ran earlier (e.g., from your app), find its `SQL_ID`:

```sql
SELECT sql_id, child_number, plan_hash_value, executions, fetches, module
FROM   v$sql
WHERE  sql_text LIKE '%FROM   accounts%';
```

Then plug `sql_id` and `child_number` into `DISPLAY_CURSOR`.

---

### C) **SQL Monitor (active or recent execution)** — requires Tuning Pack

```sql
-- Show a text report for the most recent monitored statement in your session:
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
         sql_id => NULL, report_level => 'ALL') AS rpt
FROM   dual;

-- Or target a specific SQL_ID:
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
         sql_id => '&&sql_id', report_level => 'ALL') AS rpt
FROM   dual;

-- HTML (paste into a file if desired):
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(
         sql_id => '&&sql_id', type => 'HTML', report_level => 'ALL') AS html
FROM   dual;
```

**Use when:** a statement is long-running or parallel; you want timing per step, waits, and real-time progress.

> Hint to force monitoring on short statements:

```sql
SELECT /*+ MONITOR */ COUNT(*) FROM accounts;
```

---

## 2) Reading plans quickly: what to look for

* **Access method**: TABLE ACCESS FULL vs INDEX RANGE/UNIQUE SCAN vs INDEX FAST FULL SCAN.
* **Join method**: NESTED LOOPS (good for selective inner lookups), HASH JOIN (good for big sets), MERGE JOIN (sorted inputs).
* **Join order**: bottom-up in the tree; inner children feed parent ops.
* **Cardinality**: `E-Rows` (estimate) vs `A-Rows` (actual, with `ALLSTATS LAST`). Big mismatches ⇒ stats issues, skew, missing histograms, complex predicates.
* **Filters vs Access predicates**: Access narrows rows during lookup; Filter applies after fetch. Prefer pushing predicates into access.
* **Projection**: Columns carried forward; wide projections can increase temp usage.
* **Temp/Spill**: HASH JOIN/AGG may use TEMP; large `PGA/TEMP` footprints hint at memory sizing or missing stats.
* **Parallel**: Look for `PX` operators (QC/producer/consumer). Ensure DOP is intentional.

---

## 3) Common formats for `DBMS_XPLAN`

```sql
-- Lightweight
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL,NULL,'BASIC +PREDICATE'));

-- Rich (estimates only):
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL,NULL,'TYPICAL +PREDICATE +PROJECTION +ALIAS'));

-- Executed plan (actuals):
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST +PEEKED_BINDS'));

-- Include hint outline and notes (why the optimizer chose this)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST +OUTLINE +NOTE'));
```

---

## 4) AUTOTRACE (SQL*Plus / SQLcl convenience)

```sql
-- Show plan (estimate) only:
SET AUTOTRACE ON EXPLAIN

-- Show plan + statistics after execution:
SET AUTOTRACE ON

-- Turn off:
SET AUTOTRACE OFF
```

**Note:** AUTOTRACE doesn’t show `A-Rows` per step. Use `GATHER_PLAN_STATISTICS` + `DISPLAY_CURSOR` for that.

---

## 5) End-to-end example

```sql
-- 1) Estimate the plan
EXPLAIN PLAN FOR
SELECT /* demo */ o.order_id, o.account_id, a.email
FROM   orders o
JOIN   accounts a ON a.account_id = o.account_id
WHERE  a.email LIKE :email_prefix || '%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL,NULL,'BASIC +PREDICATE +PROJECTION'));

-- 2) Execute with runtime stats
VAR email_prefix VARCHAR2(50);
EXEC :email_prefix := 'jane';
SELECT /*+ GATHER_PLAN_STATISTICS */ o.order_id, o.account_id, a.email
FROM   orders o
JOIN   accounts a ON a.account_id = o.account_id
WHERE  a.email LIKE :email_prefix || '%';

-- 3) Read the *executed* plan (A-Rows)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST +PEEKED_BINDS +NOTE'));
```

**Interpretation checklist**

* Are join methods reasonable for the row counts?
* Do `A-Rows` roughly match `E-Rows` at each step? If not, suspect stats/histograms or non-sargable predicates.
* Are predicates pushed into index access (ACCESS) or evaluated later (FILTER)?
* Any unnecessary sorts? Missing index for ORDER BY or JOIN?
* Any HASH steps spilling to TEMP? Consider memory/degree/indexes.

---

## 6) Getting the **right** plan: stats, binds, and features

* **Table/column stats**: stale stats ⇒ bad cardinality. Use `DBMS_STATS` (auto-gather usually sufficient).

  ```sql
  BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(ownname => USER, tabname => 'ACCOUNTS', method_opt => 'FOR ALL COLUMNS SIZE AUTO');
  END;
  /
  ```
* **Histograms** help on skewed columns referenced in predicates.
* **Bind peeking** & **adaptive cursor sharing** can create multiple child cursors for different bind values. Use `DISPLAY_CURSOR` with `PEEKED_BINDS` to see what was peeked.
* **Sargability**: ensure functions are on constants, not columns (`email LIKE :b1 || '%'` is good; `LOWER(email) = :b1` needs `function-based index` or rewrite).
* **Hints**: use sparingly to test alternatives:

  * `/*+ LEADING(t1 t2) USE_NL(t2) */`
  * `/*+ INDEX(a idx_accounts_email) */`
  * `/*+ FULL(a) */` (to force full scan)
  * `/*+ NO_MERGE */` (block subquery flattening)
* **Outlines/Baselines**: for plan stability when needed (DBA-level topic).

---

## 7) Parallel and monitoring

```sql
-- Parallel query (example; ensure it’s warranted):
SELECT /*+ MONITOR PARALLEL(a 4) */ COUNT(*)
FROM   accounts a
WHERE  created_at >= SYSDATE - 7;

-- Inspect via SQL Monitor (Tuning Pack):
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => NULL, report_level => 'ALL') AS rpt
FROM   dual;
```

---

## 8) Troubleshooting quick hits

* **Plan changes after deployment**: check stats freshness, bind sniffing, different session settings (NLS, optimizer features), missing histograms in prod.
* **Estimate wildly off vs actual**: gather stats; consider extended stats (column correlation) or histograms; review predicates.
* **Index ignored**: low selectivity, function on column, stale stats, incompatible NLS sort, or optimizer prefers full scan due to cost.
* **TEMP spikes**: large HASH JOIN/AGG/SORT. Add/selective indexes, increase workarea size (DBA), or rewrite.
* **Adaptive features**: 12c+ can adapt join methods at runtime; view with `+NOTE` in `DISPLAY_CURSOR`.

---

## 9) Minimal cheat-sheet (copy next to your query)

```sql
-- Run with real stats:
SELECT /*+ GATHER_PLAN_STATISTICS */ ... FROM ... WHERE ...;

-- Show actual plan for last statement in this session:
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST +PEEKED_BINDS +NOTE'));

-- Estimate without running:
EXPLAIN PLAN FOR SELECT ...;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL,NULL,'BASIC +PREDICATE +PROJECTION'));

-- SQL Monitor (if licensed):
SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => NULL, report_level => 'ALL') AS rpt
FROM   dual;
```



