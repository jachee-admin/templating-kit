# PL/SQL Cheatsheet — Advanced

> Target: Oracle 12c–19c+ (version notes where relevant). Focus on performance, correctness, maintainability, and production patterns. Reminder: in Oracle, empty string `''` is **NULL** for `CHAR/VARCHAR2`.

---

## 1) Advanced program-unit design

### Definer vs Invoker rights

```sql
-- Definer (default): runs with owner’s privileges; roles disabled.
CREATE OR REPLACE PROCEDURE p_def AUTHID DEFINER AS BEGIN NULL; END;
-- Invoker: runs with caller’s privileges; roles enabled.
CREATE OR REPLACE PROCEDURE p_inv AUTHID CURRENT_USER AS BEGIN NULL; END;
```

**Use invoker rights** for shared utilities that should respect caller’s schema/privileges; **definer rights** for secured APIs.

### Deterministic, result cache, SQL UDF

```sql
CREATE OR REPLACE FUNCTION norm_email(p IN VARCHAR2)
  RETURN VARCHAR2 DETERMINISTIC RESULT_CACHE
IS
BEGIN
  RETURN LOWER(TRIM(p));
END;
/
```

* `DETERMINISTIC` enables function-based indexes.
* `RESULT_CACHE` (12c+) caches results by arguments (great for small pure functions).
* `PRAGMA UDF;` (12cR1+) speeds SQL calls to PL/SQL:

```sql
CREATE OR REPLACE FUNCTION f_udf(p NUMBER) RETURN NUMBER AS
  PRAGMA UDF;
BEGIN RETURN p*p; END;
/
```

### Inlining & copying

```sql
CREATE OR REPLACE FUNCTION f(x PLS_INTEGER) RETURN PLS_INTEGER AS
  PRAGMA INLINE(f) -- hint, not a guarantee
BEGIN RETURN x+1; END;
/
```

Use `IN OUT NOCOPY` on large params to reduce copying.

---

## 2) Bulk processing mastery

### BULK COLLECT with LIMIT

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp%ROWTYPE;
  l_rows t_emp;
BEGIN
  FOR r IN (SELECT * FROM emp WHERE deptno=10) LOOP NULL; END LOOP; -- (avoid row-by-row)

  OPEN :cur FOR SELECT * FROM emp; -- app pattern
  LOOP
    FETCH :cur BULK COLLECT INTO l_rows LIMIT 1000;
    EXIT WHEN l_rows.COUNT=0;
    -- process l_rows in PL/SQL or FORALL DML
  END LOOP;
END;
/
```

### FORALL with `SAVE EXCEPTIONS`, `INDICES OF`, `VALUES OF`

```sql
DECLARE
  TYPE t_ids IS TABLE OF emp.empno%TYPE INDEX BY PLS_INTEGER;
  l_ids t_ids;  valid_idx t_ids;  -- sparse allowed
BEGIN
  -- populate sparse l_ids and valid_idx

  FORALL i IN INDICES OF valid_idx SAVE EXCEPTIONS
    UPDATE emp SET sal = sal*1.05 WHERE empno = valid_idx(i);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -24381 THEN
      FOR i IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
          SQL%BULK_EXCEPTIONS(i).ERROR_INDEX||' -> '||
          SQLERRM(SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
      END LOOP;
    ELSE RAISE; END IF;
END;
/
```

### RETURNING BULK COLLECT

```sql
DECLARE
  TYPE t_nums IS TABLE OF NUMBER;
  ids t_nums;
BEGIN
  FORALL i IN 1..10
    INSERT INTO dept(deptno,dname,loc)
    VALUES (dept_seq.NEXTVAL,'ENG','RDU')
    RETURNING deptno BULK COLLECT INTO ids;
END;
/
```

---

## 3) Dynamic SQL: native vs `DBMS_SQL`

* **Native `EXECUTE IMMEDIATE`**: fastest for known shapes, supports binds & `RETURNING`.
* **`DBMS_SQL`**: use when **column list is unknown at compile time** (describe-columns, fetch by position), or to parse once/execute many with changing metadata.

```sql
DECLARE
  c INTEGER := DBMS_SQL.OPEN_CURSOR;
  col_cnt INTEGER;
  desc_tab DBMS_SQL.DESC_TAB2;
  v ANYDATA;
BEGIN
  DBMS_SQL.PARSE(c, 'select * from emp where deptno = :d', DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':d', 10);
  DBMS_SQL.DESCRIBE_COLUMNS2(c, col_cnt, desc_tab);
  DBMS_SQL.DEFINE_COLUMN(c, 1, v); -- generic define
  IGNORE := DBMS_SQL.EXECUTE(c);
  -- fetch rows by position...
  DBMS_SQL.CLOSE_CURSOR(c);
END;
/
```

---

## 4) Ref cursors & pipelined / polymorphic table functions

### Ref cursors

```sql
CREATE OR REPLACE PACKAGE api AS
  TYPE refcur IS REF CURSOR RETURN emp%ROWTYPE; -- strong
  PROCEDURE list_emp(p OUT refcur, p_dept IN NUMBER);
END;
/
CREATE OR REPLACE PACKAGE BODY api AS
  PROCEDURE list_emp(p OUT refcur, p_dept IN NUMBER) IS
  BEGIN
    OPEN p FOR SELECT * FROM emp WHERE deptno = p_dept;
  END;
END;
/
```

### Pipelined functions (stream rows)

```sql
CREATE OR REPLACE TYPE t_emp_row AS OBJECT(empno NUMBER, ename VARCHAR2(50));
/
CREATE OR REPLACE TYPE t_emp_tab AS TABLE OF t_emp_row;
/
CREATE OR REPLACE FUNCTION f_emp_pipe(p_dept NUMBER)
  RETURN t_emp_tab PIPELINED
IS
BEGIN
  FOR r IN (SELECT empno, ename FROM emp WHERE deptno=p_dept) LOOP
    PIPE ROW(t_emp_row(r.empno, r.ename));
  END LOOP;
  RETURN;
END;
/
-- Usage:
SELECT * FROM TABLE(f_emp_pipe(10));
```

### Polymorphic table functions (18c+) — shape adapts to input

```sql
-- Outline only; implement DESCRIBE / FETCH_ROWS handlers
CREATE OR REPLACE PACKAGE ptf_pkg AUTHID DEFINER AS
  FUNCTION add_hash(tab TABLE, cols COLUMNS) RETURN TABLE
    POLYMORPHIC USING add_hash_impl;
END;
/
```

Use PTFs to add derived columns, filter, mask—without fixed types.

---

## 5) Compound triggers (solve mutating-table, batch work)

```sql
CREATE OR REPLACE TRIGGER emp_ct
FOR INSERT OR UPDATE OR DELETE ON emp
COMPOUND TRIGGER
  TYPE t_keys IS TABLE OF emp.empno%TYPE;
  g_keys t_keys := t_keys();

  BEFORE STATEMENT IS BEGIN g_keys.DELETE; END;
  AFTER EACH ROW IS
  BEGIN
    IF INSERTING OR UPDATING THEN g_keys.EXTEND; g_keys(g_keys.LAST) := :NEW.empno; END IF;
  END;
  AFTER STATEMENT IS
  BEGIN
    -- single DML against audit table for all rows
    INSERT INTO emp_audit(empno, ts) SELECT COLUMN_VALUE, SYSTIMESTAMP FROM TABLE(g_keys);
  END;
END emp_ct;
/
```

---

## 6) Concurrency & locks

```sql
-- Row locks
SELECT * FROM emp WHERE empno=:id FOR UPDATE WAIT 5;
-- Skip locked rows to build job queues
SELECT * FROM tasks WHERE status='READY' FOR UPDATE SKIP LOCKED;
```

**Application locks**

```sql
DECLARE
  l_res NUMBER;
BEGIN
  l_res := DBMS_LOCK.REQUEST(lockhandle=>DBMS_LOCK.ALLOCATE_UNIQUE('my.lock'), timeout=>5, release_on_commit=>TRUE);
  IF l_res <> 0 THEN RAISE_APPLICATION_ERROR(-20000,'busy'); END IF;
  -- critical section
END;
/
```

---

## 7) Error handling you can trust

```sql
BEGIN
  -- work
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(
      'Code='||SQLCODE||CHR(10)||
      DBMS_UTILITY.FORMAT_ERROR_STACK||CHR(10)||
      DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    RAISE; -- always re-raise unless you truly handled it
END;
/
```

**Autonomous logger**

```sql
CREATE OR REPLACE PROCEDURE log_err(p_msg IN CLOB) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO err_log(ts, msg) VALUES (SYSTIMESTAMP, p_msg);
  COMMIT;
END;
/
```

---

## 8) Instrumentation & tracing (prod observability)

```sql
BEGIN
  DBMS_APPLICATION_INFO.SET_MODULE('billing', 'cycle_2025_09');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('job:42');
END;
/
```

* Enable SQL Trace (`ALTER SESSION SET sql_trace = TRUE`) and analyze with **TKPROF**.
* `DBMS_MONITOR.SESSION_TRACE_ENABLE(waits=>TRUE, binds=>TRUE);`
* `DBMS_XPLAN.DISPLAY_CURSOR` for live execution plans.

---

## 9) Collections deep-dive

* **Associative arrays**: fast in-memory maps; index by `PLS_INTEGER` or `VARCHAR2`.
* **Nested tables**: set semantics; **MULTISET** ops.
* **VARRAY**: bounded, order-preserving.

```sql
DECLARE
  TYPE t_vc IS TABLE OF VARCHAR2(30);
  a t_vc := t_vc('a','b','c');
  b t_vc := t_vc('b','c','d');

  inter t_vc := a MULTISET INTERSECT b;  -- {'b','c'}
  union t_vc := a MULTISET UNION DISTINCT b;
  minus t_vc := a MULTISET EXCEPT b;
BEGIN NULL; END;
/
```

---

## 10) JSON in PL/SQL (12.2+ objects) & SQL/JSON

```sql
DECLARE
  obj JSON_OBJECT_T := JSON_OBJECT_T.parse('{"a":1,"b":"x"}');
BEGIN
  obj.put('c', 3);
  DBMS_OUTPUT.PUT_LINE( obj.get_Number('a') );
  DBMS_OUTPUT.PUT_LINE( obj.to_string );
END;
/
-- SQL/JSON:
SELECT JSON_VALUE(payload, '$.user.id') uid
FROM events
WHERE JSON_EXISTS(payload, '$?(@.type=="signup")');
```

(Without JSON types, use APEX\_JSON or plain SQL/JSON functions.)

---

## 11) Parallel & partition-wise operations

* **Parallel DML**: `ALTER SESSION ENABLE PARALLEL DML;` then:

```sql
INSERT /*+ APPEND PARALLEL(4) */ INTO big_t SELECT * FROM src;
```

* Partition-wise joins/aggregations when tables are equally partitioned → massive speedups.

---

## 12) Security hardening

* Expose APIs via **packages**; **grant execute** on package, not tables.
* Use **invoker rights** packages and **views** to enforce row filters.
* Fine-grained access control: `DBMS_RLS.ADD_POLICY` (predicate-based).
* Avoid dynamic SQL built from user input; always **bind**.

---

## 13) Edition-Based Redefinition (EBR) highlights

* Mark objects **EDITIONABLE** (default for PL/SQL). Use **editioning views** to preserve table structure while evolving columns. Swap synonyms between editions for hot-deploy without downtime.

---

## 14) Testing & CI

* **utPLSQL** for unit tests.
* Seed with deterministic data; assert rowsets via `DBMS_SQLTUNE.REPORT_SQL_MONITOR` or golden tables.
* Static analysis: **PL/Scope** (`ALTER SESSION SET plscope_settings='IDENTIFIERS:ALL'`) → query `USER_IDENTIFIERS`.

---

## 15) Performance playbook (quick hits)

* Prefer **single SQL** over row loops; when not possible → **BULK COLLECT + FORALL**.
* Bind variables; avoid implicit conversions (match datatypes/lengths).
* Use `PLS_INTEGER` in tight arithmetic loops.
* Mark pure functions `DETERMINISTIC` (with function-based indexes) or `RESULT_CACHE`.
* Avoid COMMIT in library code; let callers manage transactions.
* Collect stats on staging tables after big loads; use `DBMS_STATS.GATHER_TABLE_STATS`.

---

## 16) Mini-recipes

### Idempotent upsert with error capture

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp%ROWTYPE;
  rows t_emp;
BEGIN
  SELECT * BULK COLLECT INTO rows FROM staging_emp;

  FORALL i IN 1..rows.COUNT SAVE EXCEPTIONS
    MERGE INTO emp t
    USING (SELECT rows(i).empno empno, rows(i).ename ename, rows(i).sal sal FROM dual) s
       ON (t.empno = s.empno)
     WHEN MATCHED THEN UPDATE SET t.ename = s.ename, t.sal = s.sal
     WHEN NOT MATCHED THEN INSERT (empno, ename, sal) VALUES (s.empno, s.ename, s.sal);
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -24381 THEN
      -- iterate SQL%BULK_EXCEPTIONS
    ELSE RAISE; END IF;
END;
/
```

### Skip-locked job queue

```sql
DECLARE
  CURSOR c IS
    SELECT id FROM jobs WHERE status='READY' FOR UPDATE SKIP LOCKED;
BEGIN
  FOR r IN c LOOP
    UPDATE jobs SET status='RUNNING' WHERE CURRENT OF c;
    -- do work; mark DONE/FAILED
  END LOOP;
END;
/
```

### Compound trigger to aggregate per-statement work

(see §5)

---

## 17) Gotchas (advanced)

* Package state is **session-scoped**. Connection pools can leak state between logical users; clear/reset explicitly.
* Roles are **disabled** in definer-rights units → grant object privileges directly.
* `NULL` vs `''`: string comparisons can surprise; use `NVL`/`COALESCE`.
* `SELECT … FOR UPDATE` across distributed links can escalate/behave differently—test in env.
* Beware **implicit commits** on DDL (including `TRUNCATE`, `ALTER`).

