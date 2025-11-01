---
id: sql/oracle/plsql/loops-and-case-variations
lang: sql
platform: oracle
scope: plsql
since: "v0.4"
tested_on: "Oracle 19c"
tags: [plsql, loops, case, control-flow, forall, bulk-collect, collections]
description: "All loop forms in PL/SQL (LOOP, WHILE, numeric FOR, REVERSE, cursor FOR, collection iteration, BULK + FORALL, labels, CONTINUE/EXIT) and all CASE expression variants (simple, searched, in SQL and PL/SQL)."
---
###### Oracle PL/SQL
### PL/SQL Loops & CASE
Short, runnable fragments showing every loop flavor and CASE form you’ll realistically use in 19c.

---

## 1) Basic `LOOP ... EXIT WHEN` (manual control)
```sql
DECLARE
  i PLS_INTEGER := 0;
BEGIN
  LOOP
    i := i + 1;

    -- do work
    NULL;

    EXIT WHEN i >= 10; -- exit condition at the bottom
  END LOOP;
END;
/
````

---

## 2) `WHILE` loop (guard at the top)

```sql
DECLARE
  i PLS_INTEGER := 1;
BEGIN
  WHILE i <= 10 LOOP
    -- do work
    i := i + 1;
  END LOOP;
END;
/
```

---

## 3) Numeric `FOR` loop (inclusive range)

```sql
BEGIN
  FOR i IN 1 .. 10 LOOP
    NULL; -- work with i
  END LOOP;

  -- Reverse order
  FOR j IN REVERSE 1 .. 10 LOOP
    NULL; -- work with j
  END LOOP;
END;
/
```

---

## 4) Labeled loops + `EXIT`/`CONTINUE`

```sql
DECLARE
  i PLS_INTEGER := 0;
BEGIN
  <<outer_loop>>
  LOOP
    i := i + 1;

    -- Skip even numbers
    CONTINUE WHEN MOD(i,2) = 0;

    -- Quit early if i > 9
    EXIT outer_loop WHEN i > 9;
  END LOOP outer_loop;
END;
/
```

---

## 5) Cursor `FOR` loop (implicit open/fetch/close)

```sql
BEGIN
  FOR r IN (
    SELECT account_id, email
    FROM   accounts
    WHERE  created_at >= SYSDATE - 7
    ORDER  BY account_id
  ) LOOP
    -- r.account_id, r.email
    NULL;
  END LOOP;
END;
/
```

---

## 6) Explicit cursor loop (manual `OPEN/FETCH/CLOSE`)

Useful when you need `LIMIT` batching or fine-grained error handling per fetch.

```sql
DECLARE
  CURSOR c IS SELECT order_id FROM orders WHERE processed = 'N' ORDER BY order_id;
  v_order_id orders.order_id%TYPE;
BEGIN
  OPEN c;
  LOOP
    FETCH c INTO v_order_id;
    EXIT WHEN c%NOTFOUND;

    UPDATE orders SET processed = 'Y' WHERE order_id = v_order_id;
  END LOOP;
  CLOSE c;
END;
/
```

---

## 7) BULK COLLECT with `LIMIT` (row-by-row ≠ slow-by-slow)

```sql
DECLARE
  CURSOR c IS SELECT order_id FROM orders WHERE processed = 'N' ORDER BY order_id;
  TYPE t_orders IS TABLE OF c%ROWTYPE;
  v_rows t_orders;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_rows LIMIT 500;  -- tune batch size
    EXIT WHEN v_rows.COUNT = 0;

    FOR i IN 1 .. v_rows.COUNT LOOP
      UPDATE orders
      SET processed = 'Y'
      WHERE order_id = v_rows(i).order_id;
    END LOOP;

    COMMIT; -- safe batch commit
  END LOOP;
  CLOSE c;
END;
/
```

---

## 8) `FORALL` bulk DML (with `SAVE EXCEPTIONS`)

```sql
DECLARE
  TYPE t_ids IS TABLE OF orders.order_id%TYPE;
  v_ids t_ids := t_ids(1001,1002,1003,1004);
BEGIN
  BEGIN
    FORALL i IN v_ids.FIRST .. v_ids.LAST SAVE EXCEPTIONS
      UPDATE orders SET processed = 'Y', processed_at = SYSTIMESTAMP
      WHERE order_id = v_ids(i);

  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
          'Failed idx='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
          ' code='||SQL%BULK_EXCEPTIONS(j).ERROR_CODE||
          ' msg='||SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
  END;
  COMMIT;
END;
/
```

---

## 9) Iterating **collections**

### 9a) Dense collections (varray/nested table) — index 1..COUNT

```sql
DECLARE
  TYPE t_tab IS TABLE OF VARCHAR2(30);
  v_tab t_tab := t_tab('a','b','c');
BEGIN
  FOR i IN 1 .. v_tab.COUNT LOOP
    NULL; -- v_tab(i)
  END LOOP;
END;
/
```

### 9b) Associative array (INDEX BY) — `FIRST/NEXT` traversal

```sql
DECLARE
  TYPE t_map IS TABLE OF VARCHAR2(30) INDEX BY PLS_INTEGER;
  v_map t_map;
  k PLS_INTEGER;
BEGIN
  v_map(10) := 'ten';
  v_map(20) := 'twenty';

  k := v_map.FIRST;
  WHILE k IS NOT NULL LOOP
    NULL; -- v_map(k)
    k := v_map.NEXT(k);
  END LOOP;
END;
/
```

---

## 10) Nested loops with labels (classic join-style processing)

```sql
DECLARE
  CURSOR c_a IS SELECT account_id FROM accounts WHERE status = 'ACTIVE';
  CURSOR c_o(p_account_id accounts.account_id%TYPE) IS
    SELECT order_id FROM orders WHERE account_id = p_account_id AND processed = 'N';
BEGIN
  <<accounts_loop>>
  FOR a IN c_a LOOP
    <<orders_loop>>
    FOR o IN c_o(a.account_id) LOOP
      -- Do something with a.account_id + o.order_id
      NULL;
    END LOOP orders_loop;
  END LOOP accounts_loop;
END;
/
```

---

## 11) `CASE` expressions (PL/SQL and SQL)

### 11a) **Simple CASE** (compares to one expression)

```sql
DECLARE
  v_status VARCHAR2(10) := 'NEW';
  v_msg    VARCHAR2(50);
BEGIN
  v_msg :=
    CASE v_status
      WHEN 'NEW'     THEN 'queue'
      WHEN 'PENDING' THEN 'wait'
      WHEN 'DONE'    THEN 'complete'
      ELSE 'unknown'
    END;

  -- v_msg usable here
  NULL;
END;
/
```

### 11b) **Searched CASE** (boolean conditions)

```sql
DECLARE
  v_amt NUMBER := 125.00;
  v_bucket VARCHAR2(20);
BEGIN
  v_bucket :=
    CASE
      WHEN v_amt <   50 THEN 'small'
      WHEN v_amt <  500 THEN 'medium'
      WHEN v_amt < 5000 THEN 'large'
      ELSE               'xlarge'
    END;
  NULL;
END;
/
```

### 11c) CASE in **SQL SELECT** (computed column)

```sql
SELECT order_id,
       CASE
         WHEN total_cents >= 50000 THEN 'VIP'
         WHEN total_cents >= 10000 THEN 'PLUS'
         ELSE 'STANDARD'
       END AS tier
FROM   orders;
```

### 11d) CASE in **UPDATE** (branch assignment)

```sql
UPDATE accounts
SET    risk_flag =
       CASE
         WHEN last_login < SYSDATE-365 THEN 'COLD'
         WHEN failed_logins >= 5         THEN 'LOCK'
         ELSE 'OK'
       END
WHERE  status = 'ACTIVE';
```

### 11e) CASE in **ORDER BY** (custom sort)

```sql
SELECT status, created_at
FROM   tickets
ORDER  BY CASE status
            WHEN 'CRITICAL' THEN 1
            WHEN 'HIGH'     THEN 2
            WHEN 'MEDIUM'   THEN 3
            ELSE                4
          END,
          created_at DESC;
```

### 11f) CASE with **NULL** handling (vs NVL/COALESCE)

```sql
SELECT user_id,
       CASE WHEN email IS NULL THEN '(missing)' ELSE email END AS email_display
FROM   users;

-- Equivalent, shorter:
SELECT user_id, NVL(email, '(missing)') AS email_display
FROM   users;
```

---

## 12) `CONTINUE` and `CONTINUE WHEN` in numeric `FOR`

```sql
BEGIN
  FOR i IN 1 .. 10 LOOP
    CONTINUE WHEN MOD(i,2) = 0; -- skip evens
    -- do work with odd i
    NULL;
  END LOOP;
END;
/
```

---

## 13) Guarding loops with `SAVEPOINT` for partial rollback

```sql
DECLARE
  TYPE t_ids IS TABLE OF orders.order_id%TYPE;
  v_ids t_ids := t_ids(1001,1002,1003);
BEGIN
  FOR i IN 1 .. v_ids.COUNT LOOP
    SAVEPOINT each_row;
    BEGIN
      UPDATE orders SET processed='Y' WHERE order_id = v_ids(i);
      -- maybe other DML...
    EXCEPTION WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT each_row; -- undo just this iteration
      -- log and continue
    END;
  END LOOP;
  COMMIT;
END;
/
```

---

## 14) `CASE` vs `IF` quick rules

* Prefer **CASE** inside SQL; **IF** is PL/SQL-only.
* Use **searched CASE** when conditions aren’t simple equality.
* Keep CASE results type-consistent (e.g., all branches return `VARCHAR2(…)`).


