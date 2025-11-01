---
id: sql/oracle/plsql/records-and-cursors
lang: sql
platform: oracle
scope: plsql
since: "v0.4"
tested_on: "Oracle 19c"
tags: [plsql, records, rowtype, cursors, ref-cursor, for-update, bulk-collect]
description: "Practical patterns for RECORD/%ROWTYPE, parameterized and FOR UPDATE cursors, cursor attributes, BULK COLLECT into record collections, RETURNING INTO records, and strong/weak REF CURSORs.---
###### Oracle PL/SQL
### Records & Cursors — intelligent patterns you’ll actually use
A tour of the idioms that make day-to-day PL/SQL clean, fast, and safe.

---

## 1) User-defined RECORD (anchored to table types)
Keep your declarations drift-proof by anchoring to column `%TYPE`. Add defaults where it helps.

```sql
DECLARE
  TYPE t_account_rec IS RECORD(
    account_id   accounts.account_id%TYPE,
    email        accounts.email%TYPE,
    created_at   accounts.created_at%TYPE := SYSTIMESTAMP,
    updated_at   accounts.updated_at%TYPE := SYSTIMESTAMP
  );
  r t_account_rec;
BEGIN
  r.account_id := 1001;
  r.email      := 'ada@nc.gov';
  INSERT INTO accounts(account_id, email, created_at, updated_at)
  VALUES (r.account_id, r.email, r.created_at, r.updated_at);
END;
/
````

---

## 2) Table `%ROWTYPE` for quick selects

Use a single variable to mirror a whole row. Great for “hydrate → tweak → write back”.

```sql
DECLARE
  r accounts%ROWTYPE;
BEGIN
  SELECT * INTO r
  FROM   accounts
  WHERE  account_id = 1001;

  r.updated_at := SYSTIMESTAMP;

  UPDATE accounts
  SET    ROW = r   -- shorthand for setting all columns from the record
  WHERE  account_id = r.account_id;
END;
/
```

> If you don’t want to overwrite every column, set them explicitly instead of `SET ROW = r`.

---

## 3) `UPDATE … RETURNING` straight into a RECORD

Handy for “change one thing, log the rest”.

```sql
DECLARE
  r accounts%ROWTYPE;
BEGIN
  UPDATE accounts
  SET    email = 'ada.lovelace@nc.gov',
         updated_at = SYSTIMESTAMP
  WHERE  account_id = 1001
  RETURNING account_id, email, created_at, updated_at
  INTO    r.account_id, r.email, r.created_at, r.updated_at;

  DBMS_OUTPUT.PUT_LINE('Updated: '||r.account_id||' -> '||r.email);
END;
/
```

---

## 4) Parameterized cursor + `%ROWTYPE`

Readable, reusable loops that auto-open/fetch/close.

```sql
DECLARE
  CURSOR c_active_accounts(p_since DATE) IS
    SELECT account_id, email, created_at, updated_at
    FROM   accounts
    WHERE  created_at >= p_since
    ORDER  BY account_id;

  r c_active_accounts%ROWTYPE;
BEGIN
  FOR r IN c_active_accounts(SYSDATE - 7) LOOP
    -- r.account_id, r.email, r.created_at, r.updated_at
    NULL;
  END LOOP;
END;
/
```

---

## 5) Explicit cursor with attributes `%FOUND`, `%ROWCOUNT`

When you need finer control (batch commits, conditional logic, etc.).

```sql
DECLARE
  CURSOR c_orders IS
    SELECT order_id, account_id FROM orders WHERE processed = 'N' ORDER BY order_id;

  r c_orders%ROWTYPE;
BEGIN
  OPEN c_orders;
  LOOP
    FETCH c_orders INTO r;
    EXIT WHEN c_orders%NOTFOUND;

    UPDATE orders
    SET    processed   = 'Y',
           processed_at = SYSTIMESTAMP
    WHERE  order_id = r.order_id;

    IF MOD(c_orders%ROWCOUNT, 500) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;
  CLOSE c_orders;
  COMMIT;
END;
/
```

---

## 6) `FOR UPDATE` + `WHERE CURRENT OF` (safe row-locking)

Avoid racy “lookup then update” by locking rows as you iterate.

```sql
DECLARE
  CURSOR cq IS
    SELECT order_id
    FROM   orders
    WHERE  processed = 'N'
    FOR UPDATE OF processed SKIP LOCKED;  -- optionally avoid contested rows
BEGIN
  FOR r IN cq LOOP
    UPDATE orders
    SET    processed = 'Y',
           processed_at = SYSTIMESTAMP
    WHERE  CURRENT OF cq;  -- the row we just fetched
  END LOOP;
  COMMIT;
END;
/
```

---

## 7) BULK COLLECT into a collection of `%ROWTYPE`

Pull rows in chunky batches, then operate in memory.

```sql
DECLARE
  CURSOR c IS
    SELECT account_id, email, created_at, updated_at
    FROM   accounts
    WHERE  status = 'PENDING'
    ORDER  BY account_id;

  TYPE t_rows IS TABLE OF c%ROWTYPE;
  v_rows t_rows;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_rows LIMIT 500;
    EXIT WHEN v_rows.COUNT = 0;

    FOR i IN 1 .. v_rows.COUNT LOOP
      -- example: bump updated_at in-memory then persist
      v_rows(i).updated_at := SYSTIMESTAMP;

      UPDATE accounts
      SET    updated_at = v_rows(i).updated_at
      WHERE  account_id = v_rows(i).account_id;
    END LOOP;

    COMMIT;
  END LOOP;
  CLOSE c;
END;
/
```

> `FORALL` doesn’t accept record variables directly—use parallel scalar arrays when you truly need set-DML speed.

---

## 8) Strongly-typed REF CURSOR (stream results to a client/caller)

Return a stream without materializing a collection.

```sql
-- 8a) Define a strong REF CURSOR type
CREATE OR REPLACE PACKAGE types_pkg AS
  TYPE rc_accounts IS REF CURSOR RETURN accounts%ROWTYPE;
END types_pkg;
/

-- 8b) Function returning that cursor
CREATE OR REPLACE FUNCTION open_accounts_since(p_since DATE)
  RETURN types_pkg.rc_accounts
AS
  rc types_pkg.rc_accounts;
BEGIN
  OPEN rc FOR
    SELECT * FROM accounts WHERE created_at >= p_since ORDER BY account_id;
  RETURN rc;
END;
/

-- 8c) Consume it
DECLARE
  rc types_pkg.rc_accounts;
  r  accounts%ROWTYPE;
BEGIN
  rc := open_accounts_since(SYSDATE - 30);
  LOOP
    FETCH rc INTO r;
    EXIT WHEN rc%NOTFOUND;
    -- use r.*
    NULL;
  END LOOP;
  CLOSE rc;
END;
/
```

---

## 9) Weak REF CURSOR (`SYS_REFCURSOR`) + dynamic SQL

When the shape varies at runtime.

```sql
DECLARE
  rc   SYS_REFCURSOR;
  v_id   accounts.account_id%TYPE;
  v_email accounts.email%TYPE;
  p_sql VARCHAR2(4000) := 'SELECT account_id, email FROM accounts WHERE email LIKE :1';
BEGIN
  OPEN rc FOR p_sql USING 'jane%';
  LOOP
    FETCH rc INTO v_id, v_email;
    EXIT WHEN rc%NOTFOUND;
    NULL; -- use v_id, v_email
  END LOOP;
  CLOSE rc;
END;
/
```

---

## 10) Cursor expression (nested results) — advanced, compact

Produce a parent row with a nested “child rows” cursor; iterate nested cursor per parent.

```sql
DECLARE
  CURSOR c_depts IS
    SELECT d.deptno,
           CURSOR(
             SELECT e.empno, e.ename
             FROM   emp e
             WHERE  e.deptno = d.deptno
             ORDER  BY e.empno
           ) AS emp_cur
    FROM   dept d
    ORDER  BY d.deptno;

  v_empno emp.empno%TYPE;
  v_ename emp.ename%TYPE;
BEGIN
  FOR r IN c_depts LOOP
    -- r.emp_cur is a cursor — fetch from it
    LOOP
      FETCH r.emp_cur INTO v_empno, v_ename;
      EXIT WHEN r.emp_cur%NOTFOUND;
      -- use v_empno, v_ename for this department
      NULL;
    END LOOP;
  END LOOP;
END;
/
```

---

## 11) Tiny utility pattern: `SELECT … INTO` with “not found → NULL”

Sometimes you want a single row or NULL without exceptions.

```sql
DECLARE
  r accounts%ROWTYPE;
BEGIN
  BEGIN
    SELECT * INTO r FROM accounts WHERE email = 'ghost@nc.gov';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      r.account_id := NULL; -- mark as missing
  END;

  IF r.account_id IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('no match');
  ELSE
    DBMS_OUTPUT.PUT_LINE('found '||r.account_id);
  END IF;
END;
/
```

---

## 12) PRO TIPS (why these patterns)

* Anchor record fields with `%TYPE` / `%ROWTYPE` to avoid schema drift.
* Prefer `FOR UPDATE … WHERE CURRENT OF` for safe row-by-row updates.
* Use `BULK COLLECT … LIMIT` to control PGA and avoid “row-by-row = slow-by-slow”.
* Strong `REF CURSOR` when the shape is fixed; `SYS_REFCURSOR` for dynamic shapes.
* For true bulk DML, switch to `FORALL` with parallel scalar arrays and `SAVE EXCEPTIONS`.

