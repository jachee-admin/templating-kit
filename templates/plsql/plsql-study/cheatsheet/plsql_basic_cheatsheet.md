# PL/SQL Cheatsheet — Basic → Intermediate

> Target: solid day-to-day PL/SQL (Oracle 12c+). Notion-friendly Markdown.
> Tip: In Oracle, empty string `''` is **NULL** for `CHAR/VARCHAR2`.

---

## 1) Block anatomy (hello, world → structured)

```sql
DECLARE
  v_msg VARCHAR2(50) := 'Hello';
BEGIN
  DBMS_OUTPUT.PUT_LINE(v_msg);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

### Variables & constants

```sql
DECLARE
  c_limit CONSTANT PLS_INTEGER := 100;
  v_total NUMBER(12,2) := 0;
  v_name  VARCHAR2(100);
  v_when  TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;
BEGIN
  NULL;
END;
/
```

### Anchored types (stay schema-safe)

```sql
DECLARE
  v_empno   emp.empno%TYPE;
  r_emp     emp%ROWTYPE;
BEGIN
  SELECT * INTO r_emp FROM emp WHERE empno = 7369;
END;
/
```

---

## 2) Control flow

```sql
IF v_total > 1000 THEN
  -- ...
ELSIF v_total > 0 THEN
  -- ...
ELSE
  NULL;
END IF;

-- All 3 CASE variations
DECLARE
  c_limit     CONSTANT PLS_INTEGER := 2;
  v_ust_name stage_orders_csv.customer_name%TYPE;
  r_cust      stage_orders_csv%ROWTYPE;
  v_var       NUMBER;
BEGIN
  -- BARE case
  CASE c_limit
    WHEN 1 THEN
      DBMS_OUTPUT.PUT_LINE('ONE');
    WHEN 2 THEN
      DBMS_OUTPUT.PUT_LINE('TWO');
    ELSE
      DBMS_OUTPUT.PUT_LINE('ELSE');
  END CASE;

  -- SELECT case
  SELECT CASE WHEN c_limit > 1 THEN 1 ELSE 2 END into v_var FROM dual; 
  DBMS_OUTPUT.PUT_LINE(v_var);

  -- VAR ASSIGNMENT case
  v_var := CASE c_limit
     WHEN 2 THEN
       222
  END;
  DBMS_OUTPUT.PUT_LINE(v_var);       
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || sqlerrm);
END;
```

```sql
-- FOR, WHILE, LABELS

DECLARE 
    c_limit CONSTANT PLS_INTEGER := 10;
    c_max   CONSTANT PLS_INTEGER := 10;
    v_curr  INT;
    v_retry INT;
    v_count INT;
BEGIN
    -- FOR SEQ LOOP
    FOR i IN 1..c_limit LOOP
      DBMS_OUTPUT.PUT_LINE('Line: '|| i);
    END LOOP;

    -- WHILE VALUE < MAX
    v_curr := 1;
    WHILE v_curr <= c_max LOOP
      v_curr := v_curr + 1;
      DBMS_OUTPUT.PUT_LINE('While Line: '|| v_curr);
    END LOOP;
    v_retry := 1;

    -- GOTO LABEL
    <<retry>>
    BEGIN
      IF v_retry <= 1 THEN
        v_retry := v_retry + 1;
        SELECT 1 INTO v_count FROM orders;
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN GOTO retry;
    END;
    DBMS_OUTPUT.PUT_LINE('Retry: '|| v_retry);
END;
```

---

## 3) Records & cursors

### Implicit cursor attributes

* `SQL%ROWCOUNT`, `SQL%FOUND`, `SQL%NOTFOUND`, `SQL%ISOPEN`

```sql
BEGIN
  UPDATE emp SET sal = sal*1.1 WHERE deptno = 10;
  DBMS_OUTPUT.PUT_LINE('Rows: ' || SQL%ROWCOUNT);
END;
/
```

### Explicit cursor loop

```sql
DECLARE
  CURSOR c_emp (p_deptno emp.deptno%TYPE) IS
    SELECT empno, ename, sal FROM emp WHERE deptno = p_deptno;
  r c_emp%ROWTYPE;
BEGIN
  OPEN c_emp(10);
  LOOP
    FETCH c_emp INTO r;
    EXIT WHEN c_emp%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(r.empno || ' ' || r.ename);
  END LOOP;
  CLOSE c_emp;
END;
/
```

### Cursor FOR loop (preferred)

```sql
BEGIN
  FOR r IN (SELECT empno, ename FROM emp WHERE deptno = 10) LOOP
    DBMS_OUTPUT.PUT_LINE(r.empno || ' ' || r.ename);
  END LOOP;
END;
/
```

---

## 4) DML from PL/SQL

```sql
-- INSERT ... RETURNING
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO dept (deptno, dname, loc)
  VALUES (dept_seq.NEXTVAL, 'ENG', 'RDU')
  RETURNING deptno INTO v_id;

  UPDATE emp SET sal = sal + 500 WHERE deptno = v_id;

  DELETE FROM emp WHERE sal < 1000;
END;
/
```

### MERGE (upsert)

```sql
MERGE INTO emp t
USING (SELECT :empno empno, :ename ename, :sal sal FROM dual) s
   ON (t.empno = s.empno)
 WHEN MATCHED THEN UPDATE SET t.ename = s.ename, t.sal = s.sal
 WHEN NOT MATCHED THEN INSERT (empno, ename, sal) VALUES (s.empno, s.ename, s.sal);
```

---

## 5) Exceptions

### Common predefined

* `NO_DATA_FOUND`, `TOO_MANY_ROWS`, `DUP_VAL_ON_INDEX`, `ZERO_DIVIDE`, `VALUE_ERROR`

```sql
BEGIN
  SELECT sal INTO v_sal FROM emp WHERE empno = 9999;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No such emp');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(SQLCODE || ' ' || SQLERRM);
END;
/
```

### Map ORA- codes → named exceptions

```sql
DECLARE
  e_fk EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_fk, -2292); -- ORA-02292 child records found
BEGIN
  DELETE FROM dept WHERE deptno = 10;
EXCEPTION
  WHEN e_fk THEN
    DBMS_OUTPUT.PUT_LINE('Cannot delete; child rows exist');
END;
/
```

### Raise your own

```sql
RAISE_APPLICATION_ERROR(-20001, 'Business rule violated');
```

---

## 6) Procedures, functions, packages

### Procedure & function

```sql
CREATE OR REPLACE PROCEDURE give_raise(p_empno IN emp.empno%TYPE, p_pct IN NUMBER)
IS
BEGIN
  UPDATE emp SET sal = sal * (1 + p_pct) WHERE empno = p_empno;
END;
/

CREATE OR REPLACE FUNCTION annual_pay(p_empno IN emp.empno%TYPE)
  RETURN NUMBER DETERMINISTIC
IS
  v NUMBER;
BEGIN
  SELECT sal*12 INTO v FROM emp WHERE empno = p_empno;
  RETURN v;
END;
/
```

### Package skeleton

```sql
CREATE OR REPLACE PACKAGE hr_api AS
  PROCEDURE hire(p_name IN VARCHAR2, p_deptno IN NUMBER);
  FUNCTION  exists_emp(p_empno IN NUMBER) RETURN BOOLEAN;
END hr_api;
/

CREATE OR REPLACE PACKAGE BODY hr_api AS
  g_calls PLS_INTEGER := 0; -- session-scoped state, use carefully

  PROCEDURE hire(p_name IN VARCHAR2, p_deptno IN NUMBER) IS
  BEGIN
    INSERT INTO emp(empno, ename, deptno)
    VALUES (emp_seq.NEXTVAL, p_name, p_deptno);
    g_calls := g_calls + 1;
  END;

  FUNCTION exists_emp(p_empno IN NUMBER) RETURN BOOLEAN IS
    v_dummy NUMBER;
  BEGIN
    SELECT 1 INTO v_dummy FROM emp WHERE empno = p_empno;
    RETURN TRUE;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
  END;
END hr_api;
/
```

> Note: package variables persist per session. Avoid unintended state.

---

## 7) Collections (index-by, nested tables, varrays)

```sql
DECLARE
  TYPE num_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER; -- associative (index-by)
  l_idx PLS_INTEGER := 0;
  l_map num_tab;

  TYPE name_nt IS TABLE OF VARCHAR2(50); -- nested table
  l_names name_nt := name_nt('a','b');

  TYPE code_va IS VARRAY(5) OF VARCHAR2(10); -- varray (fixed upper bound)
  l_codes code_va := code_va();
BEGIN
  l_idx := l_idx + 1;
  l_map(l_idx) := 42;

  l_names.EXTEND; l_names(3) := 'c';
  FOR i IN 1..l_names.COUNT LOOP DBMS_OUTPUT.PUT_LINE(l_names(i)); END LOOP;

  l_codes.EXTEND; l_codes(1) := 'X1';
END;
/
```

### BULK COLLECT & FORALL (reduce context switches)

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp%ROWTYPE;
  l_rows t_emp;
BEGIN
  SELECT * BULK COLLECT INTO l_rows
  FROM emp WHERE deptno = 10;

  FORALL i IN l_rows.FIRST..l_rows.LAST SAVE EXCEPTIONS
    UPDATE emp
       SET sal = sal * 1.05
     WHERE empno = l_rows(i).empno;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -24381 THEN -- bulk errors
      FOR i IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Err #' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX
          || ': ' || SQLERRM(SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
      END LOOP;
    ELSE
      RAISE;
    END IF;
END;
/
```

> Use `LIMIT` when fetching huge sets: `BULK COLLECT INTO l_rows LIMIT 1000;` inside a loop.

---

## 8) Dynamic SQL (binds or die)

```sql
DECLARE
  v_sql   VARCHAR2(4000);
  v_empno NUMBER := 7369;
  v_name  VARCHAR2(50);
BEGIN
  v_sql := 'SELECT ename FROM emp WHERE empno = :1';
  EXECUTE IMMEDIATE v_sql INTO v_name USING v_empno;

  v_sql := 'UPDATE emp SET sal = sal + :inc WHERE empno = :id';
  EXECUTE IMMEDIATE v_sql USING 500, v_empno;
END;
/
```

* `RETURNING BULK COLLECT INTO` works with `FORALL … EXECUTE IMMEDIATE`.
* Prefer `DBMS_SQL` only for truly dynamic column lists.

---

## 9) Transactions & locking (be explicit)

* **Usually** let the caller (app) `COMMIT`/`ROLLBACK`.
* Avoid commit/rollback in library code; if you must log from exceptions, use **autonomous transaction**:

```sql
CREATE OR REPLACE PROCEDURE log_error(p_msg IN VARCHAR2) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO err_log(ts, msg) VALUES (SYSTIMESTAMP, p_msg);
  COMMIT;
END;
/
```

* Row locks: `SELECT ... FOR UPDATE NOWAIT/SKIP LOCKED;`

---

## 10) Triggers (use sparingly)

```sql
CREATE OR REPLACE TRIGGER emp_biu
BEFORE INSERT OR UPDATE ON emp
FOR EACH ROW
BEGIN
  IF INSERTING AND :NEW.empno IS NULL THEN
    :NEW.empno := emp_seq.NEXTVAL;
  END IF;
  IF UPDATING ('sal') THEN
    :NEW.sal := GREATEST(:NEW.sal, 0);
  END IF;
END;
/
```

> No commits in triggers. Prefer constraints/defaults/virtual columns when possible. For multi-row logic, consider **compound triggers**.

---

## 11) Dates/times & null helpers

```sql
v_when TIMESTAMP WITH LOCAL TIME ZONE := SYSTIMESTAMP;
-- CURRENT_DATE uses session time zone; SYSTIMESTAMP is DB host clock.

-- Null helpers
v1 := NVL(p_in, 'fallback');
v2 := COALESCE(p1, p2, p3);      -- first non-null
x  := NULLIF(a, b);              -- null if equal
```

---

## 12) Helpful packages (daily drivers)

* `DBMS_OUTPUT.PUT_LINE` – dev prints (enable: `SET SERVEROUTPUT ON`)
* `DBMS_APPLICATION_INFO.SET_MODULE/SET_ACTION` – instrument sessions
* `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE/FORMAT_CALL_STACK` – rich errors
* `DBMS_LOCK.SLEEP` – sleep seconds
* `DBMS_RANDOM.VALUE/STRING` – test data
* `DBMS_SCHEDULER` – jobs
* `UTL_FILE` – file I/O (dir objects)
* `DBMS_XPLAN.DISPLAY_CURSOR` – show execution plans (SQL\*Plus/SQLcl)

---

## 13) Performance & safety tips

* Push work into **single SQL statements** where feasible; PL/SQL loops over rows are slow → use **BULK COLLECT + FORALL**.

* Use `PLS_INTEGER` in tight loops; avoid implicit conversions.

* Beware **implicit commits** (DDL like `CREATE/ALTER` commit).

* Use `NOCOPY` for large OUT params to reduce copies:
  
  ```sql
  PROCEDURE fill(p_tab IN OUT NOCOPY t_tab);
  ```

* Mark pure functions `DETERMINISTIC` (enables function-based indexes).

* Prefer bind variables; never string-concatenate user input.

---

## 14) Mini-recipes

### Pagination fetch (LIMIT-like)

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp.empno%TYPE;
  l_ids t_emp;
  v_last_id NUMBER := 0;
BEGIN
  LOOP
    SELECT empno BULK COLLECT INTO l_ids
    FROM emp
    WHERE empno > v_last_id
    ORDER BY empno
    FETCH FIRST 100 ROWS ONLY;

    EXIT WHEN l_ids.COUNT = 0;
    v_last_id := l_ids(l_ids.LAST);
    -- process batch...
  END LOOP;
END;
/
```

### Audit on change (row-level)

```sql
CREATE OR REPLACE TRIGGER emp_audit_trg
AFTER UPDATE OF sal ON emp
FOR EACH ROW
BEGIN
  INSERT INTO emp_audit(empno, old_sal, new_sal, ts)
  VALUES (:NEW.empno, :OLD.sal, :NEW.sal, SYSTIMESTAMP);
END;
/
```

### Safe “upsert list” with FORALL

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp%ROWTYPE;
  l_rows t_emp;
BEGIN
  SELECT * BULK COLLECT INTO l_rows FROM staging_emp;

  FORALL i IN l_rows.FIRST..l_rows.LAST
    MERGE INTO emp t
    USING (SELECT l_rows(i).empno empno,
                  l_rows(i).ename ename,
                  l_rows(i).sal   sal
             FROM dual) s
      ON (t.empno = s.empno)
    WHEN MATCHED THEN UPDATE SET t.sal = s.sal, t.ename = s.ename
    WHEN NOT MATCHED THEN INSERT (empno, ename, sal)
                         VALUES (s.empno, s.ename, s.sal);
END;
/
```

---

## 15) Quick tables

### Cursor attributes

| Attribute                | Meaning                               |
| ------------------------ | ------------------------------------- |
| `SQL%ROWCOUNT`           | Rows affected by last DML/SELECT INTO |
| `SQL%FOUND` / `NOTFOUND` | True if ≥1 row / 0 rows               |
| `SQL%ISOPEN`             | Always FALSE for implicit cursor      |

### Collection types

| Type              | Indexing                    | DB column? | Notes                              |
| ----------------- | --------------------------- | ---------- | ---------------------------------- |
| Associative array | PLS\_INTEGER / VARCHAR2 key | No         | In-memory map; fastest for lookups |
| Nested table      | Dense, unbounded            | Yes        | Use `TABLE()` to query             |
| VARRAY            | Dense, bounded              | Yes        | Preserves order; size limit        |

### Common exceptions

| Name               | ORA   | Meaning                  |
| ------------------ | ----- | ------------------------ |
| `NO_DATA_FOUND`    | 01403 | SELECT INTO found no row |
| `TOO_MANY_ROWS`    | 01422 | SELECT INTO returned >1  |
| `DUP_VAL_ON_INDEX` | 00001 | Unique/PK violation      |
| `ZERO_DIVIDE`      | 01476 | Divide by zero           |
| `VALUE_ERROR`      | 06502 | Conversion/overflow      |

---

## 16) Identity vs sequence (12c+)

```sql
-- Identity column
CREATE TABLE t_demo (
  id NUMBER GENERATED BY DEFAULT AS IDENTITY,
  name VARCHAR2(50)
);

INSERT INTO t_demo(name) VALUES ('x'); -- id auto-filled
-- Classic sequence
CREATE SEQUENCE demo_seq START WITH 1 INCREMENT BY 1;
INSERT INTO t_demo(id, name) VALUES (demo_seq.NEXTVAL, 'y');
```

---

If you want this as **CSV flashcards** (term\:definition) or a **printable PDF**, say the word and I’ll generate it.
Ready for the next language when you are.
