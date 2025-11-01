###### Oracle PL/SQL
## Explain Plan - Build

### 1) Setup: PLAN_TABLE + minimal grants

### 1A) Create `PLAN_TABLE` (run in each schema that will use EXPLAIN PLAN)

```sql
-- If it already exists, you can skip this.
-- This mirrors the table created by Oracle’s utlxplan.sql (works 12c–23ai).
CREATE TABLE plan_table AS
SELECT
  sysdate           AS timestamp,
  0                 AS statement_id,
  0                 AS plan_id,
  NULL              AS parent_id,
  NULL              AS id,
  NULL              AS operation,
  NULL              AS options,
  NULL              AS object_node,
  NULL              AS object_owner,
  NULL              AS object_name,
  NULL              AS object_alias,
  NULL              AS object_type,
  NULL              AS optimizer,
  NULL              AS search_columns,
  NULL              AS cost,
  NULL              AS cardinality,
  NULL              AS bytes,
  NULL              AS other_tag,
  NULL              AS partition_start,
  NULL              AS partition_stop,
  NULL              AS partition_id,
  NULL              AS other,
  NULL              AS distribution,
  NULL              AS cpu_cost,
  NULL              AS io_cost,
  NULL              AS temp_space,
  NULL              AS access_predicates,
  NULL              AS filter_predicates,
  NULL              AS projection,
  NULL              AS time,
  NULL              AS qblock_name,
  NULL              AS remarks
FROM dual WHERE 1=0;
```

(If you prefer the official script: ask your DBA where `utlxplan.sql` is, usually in `$ORACLE_HOME/rdbms/admin/`, and run it in your schema.)

## 1B) Optional: let another user read your plan table

```sql
GRANT SELECT ON plan_table TO some_other_user;
```

## 1C) Grants for runtime plans (`DBMS_XPLAN.DISPLAY_CURSOR`)

These are **DBA-side**; ask a DBA to run **one** of the following options.

### Minimal object grants

```sql
GRANT SELECT ON v_$sql                     TO your_user;
GRANT SELECT ON v_$sql_plan                TO your_user;
GRANT SELECT ON v_$sql_plan_statistics_all TO your_user;
```

### Or, role-based (broader)

```sql
GRANT SELECT_CATALOG_ROLE TO your_user;     -- includes read on dynamic performance views
```

`DBMS_XPLAN` is normally PUBLIC EXECUTE, so no extra grant needed.
If you want AWR history (`DISPLAY_AWR`), you also need one of:

```sql
GRANT SELECT ANY DICTIONARY TO your_user;   -- broad
-- or the more targeted:
GRANT SELECT ON sys.dba_hist_sqlstat TO your_user;
GRANT SELECT ON sys.dba_hist_sqltext TO your_user;
GRANT SELECT ON sys.dba_hist_sql_plan TO your_user;
```

# 2) Best-practice workflow (side-by-side)

## 2A) Get a **theoretical** plan (EXPLAIN PLAN)

```sql
EXPLAIN PLAN FOR
SELECT /* your query */ *
FROM   orders
WHERE  customer_id = 123;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(
  table_name => 'PLAN_TABLE',
  statement_id => NULL,   -- most recent
  format => 'BASIC +OUTLINE +ALIAS'
));
```

## 2B) Get the **actual** executed plan (DISPLAY_CURSOR)

First, make Oracle capture runtime stats (one of these):

```sql
-- Option 1 (per statement, safer):
SELECT /*+ GATHER_PLAN_STATISTICS */ *
FROM   orders
WHERE  customer_id = 123;

-- Option 2 (session-wide):
ALTER SESSION SET statistics_level = ALL;
-- then run your query normally
SELECT * FROM orders WHERE customer_id = 123;
```

Now show the plan used by the **last** statement in this session:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
  sql_id      => NULL,
  child_number=> NULL,
  format      => 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ADAPTIVE'
));
```

Or, find a specific SQL in the library cache and display its plan:

```sql
-- locate by text pattern (trim this to something selective!)
SELECT sql_id, child_number, parsing_schema_name, substr(sql_text,1,80) AS sql_sample
FROM   v$sql
WHERE  sql_text LIKE '%orders%customer_id%';

-- then:
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
  sql_id      => '&&sql_id',
  child_number=> 0,
  format      => 'ALLSTATS LAST +PEEKED_BINDS +OUTLINE +ADAPTIVE'
));
```

For historical plans (AWR):

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_AWR(
  sql_id => '&&sql_id',
  format => 'TYPICAL +OUTLINE'
));
```

# 3) Reading the output (what to compare)

* **E-Rows vs A-Rows**: estimated vs actual row counts per step. Big mismatches → stats/skew/filters off.
* **Access path**: `INDEX RANGE SCAN` vs `FULL`—did Oracle follow your expectation?
* **Join method**: `NESTED LOOPS` vs `HASH JOIN`. For large joins, hash is often better.
* **Outline**: shows the hints Oracle effectively used (join order, access paths).
* **Peeked binds**: confirms bind values that influenced the plan.

# 4) Handy snippets

## Reset plan_table (quick clean)

```sql
TRUNCATE TABLE plan_table;
```

## Force plan capture without changing code

```sql
ALTER SESSION SET statistics_level = ALL;
-- run the query
ALTER SESSION SET statistics_level = TYPICAL;  -- restore
```

## Show just the plan for the very last statement (super quick)

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'BASIC'));
```

