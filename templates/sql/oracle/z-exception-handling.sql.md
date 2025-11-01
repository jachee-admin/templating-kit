---
id: sql/oracle/plsql/exception-handling-19c
lang: sql
platform: oracle
scope: plsql
since: "v0.7"
tested_on: "Oracle 19c"
tags: [plsql, exceptions, error-handling, logging, pragma, exception_init, backtrace, sqlerrm, save-exceptions, dbms_errlog, validation]
description: "Everything PL/SQL exception handling: basics, named exceptions, PRAGMA EXCEPTION_INIT, validation patterns, re-raise vs RAISE_APPLICATION_ERROR, stack/ backtrace capture, partial rollbacks, bulk SAVE EXCEPTIONS, DBMS_ERRLOG, nested blocks, function defaults, and best practices."
---
###### Oracle PL/SQL
### PL/SQL Exception Handling — the kitchen sink (Oracle 19c)
Use these patterns as snap-ins. Prefer small try/handle scopes, preserve the stack, and log with context.

---

## 1) Basics — `EXCEPTION` block, common predefined exceptions
```sql
DECLARE
  v_num NUMBER := 0;
BEGIN
  v_num := 1/0;  -- raises ZERO_DIVIDE
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No row');
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('Too many rows');
  WHEN ZERO_DIVIDE THEN
    DBMS_OUTPUT.PUT_LINE('Cannot divide by zero');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Unexpected: '||SQLERRM||' (code='||SQLCODE||')');
END;
/
````

---

## 2) Named exceptions with `PRAGMA EXCEPTION_INIT` (readable handlers)

```sql
DECLARE
  e_dup_key   EXCEPTION; PRAGMA EXCEPTION_INIT(e_dup_key, -1);        -- ORA-00001
  e_timeout   EXCEPTION; PRAGMA EXCEPTION_INIT(e_timeout, -30006);    -- AQ timeout (example)
BEGIN
  INSERT INTO t(pk,val) VALUES (1,'x');
EXCEPTION
  WHEN e_dup_key THEN
    DBMS_OUTPUT.PUT_LINE('Duplicate key → switch to UPDATE');
  WHEN e_timeout THEN
    DBMS_OUTPUT.PUTLINE('Timed out');
END;
/
```

---

## 3) Validation & user errors — `RAISE_APPLICATION_ERROR` (-20000..-20999)

```sql
DECLARE
  PROCEDURE assert_email(p_email IN VARCHAR2) IS
  BEGIN
    IF p_email IS NULL OR INSTR(p_email,'@')=0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Invalid email');
    END IF;
  END;
BEGIN
  assert_email('not-an-email'); -- raises ORA-20001
END;
/
```

**Tip:** Use dedicated ranges per package/domain (e.g., `-20100..-20149` for accounts).

---

## 4) Preserve the original stack vs. replace it

```sql
BEGIN
  -- risky()
  RAISE_APPLICATION_ERROR(-20002, 'Outer wrap');  -- creates a **new** error at this site
EXCEPTION
  WHEN OTHERS THEN
    -- Good: add context, then **re-raise original** to preserve call stack
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_stack);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_backtrace);
    RAISE;  -- (no argument) → preserves the original error site
END;
/
```

**Rule:** Prefer `RAISE;` to keep backtrace. Only use `RAISE_APPLICATION_ERROR` to emit your own, domain-specific error.

---

## 5) Attach rich context when handling

```sql
DECLARE
  PROCEDURE do_work(p_id IN NUMBER) IS
  BEGIN
    UPDATE accounts SET email = email||'.x' WHERE account_id = p_id;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Account not found id='||p_id);
    END IF;
  END;
BEGIN
  BEGIN
    do_work(999999);
  EXCEPTION WHEN OTHERS THEN
    -- Add structured context (swap to your logger)
    DBMS_OUTPUT.PUT_LINE('STACK='||DBMS_UTILITY.format_error_stack);
    DBMS_OUTPUT.PUT_LINE('BT   ='||DBMS_UTILITY.format_error_backtrace);
    -- Rethrow to caller
    RAISE;
  END;
END;
/
```

---

## 6) Nested blocks — localize rescue, keep outer flow clean

```sql
BEGIN
  -- Part 1: best-effort
  BEGIN
    NULL; -- try something non-critical
  EXCEPTION WHEN OTHERS THEN
    -- log & continue; do not poison outer transaction
    NULL;
  END;

  -- Part 2: must succeed
  INSERT INTO audit(ts,msg) VALUES (SYSTIMESTAMP, 'Phase 2');
EXCEPTION
  WHEN OTHERS THEN
    -- critical failure
    RAISE;
END;
/
```

---

## 7) Partial rollback per iteration — `SAVEPOINT` pattern

```sql
DECLARE
  TYPE t_ids IS TABLE OF orders.order_id%TYPE;
  v_ids t_ids := t_ids(1001,1002,1003);
BEGIN
  FOR i IN 1 .. v_ids.COUNT LOOP
    SAVEPOINT each_row;
    BEGIN
      UPDATE orders SET processed='Y' WHERE order_id = v_ids(i);
      -- maybe more DML…
    EXCEPTION WHEN OTHERS THEN
      ROLLBACK TO SAVEPOINT each_row; -- undo just this one
      -- log exception here
    END;
  END LOOP;
  COMMIT;
END;
/
```

---

## 8) Bulk processing — `FORALL … SAVE EXCEPTIONS`

```sql
DECLARE
  TYPE t_pk IS TABLE OF NUMBER;
  v_pk t_pk := t_pk(1,2,3,4);
BEGIN
  BEGIN
    FORALL i IN v_pk.FIRST .. v_pk.LAST SAVE EXCEPTIONS
      INSERT INTO t(pk) VALUES (v_pk(i));  -- duplicates will raise
  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
          'idx='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
          ' code='||SQL%BULK_EXCEPTIONS(j).ERROR_CODE||' '||
          SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
  END;
  COMMIT;
END;
/
```

---

## 9) DML error logging table — `DBMS_ERRLOG` (set-and-forget)

```sql
BEGIN DBMS_ERRLOG.CREATE_ERROR_LOG('ACCOUNTS'); END; /
-- Use in DML; bad rows go to ERR$_ACCOUNTS instead of failing the statement
INSERT INTO accounts(email)
SELECT email FROM staging
LOG ERRORS INTO ERR$_ACCOUNTS ('LOAD') REJECT LIMIT UNLIMITED;
```

**When:** you want “best effort” set-based loads and a queue of rejects to inspect later.

---

## 10) Cursor attributes in exceptions — avoid swallowing useful info

```sql
BEGIN
  UPDATE accounts SET email = email WHERE 1=2;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'No rows updated');
  END IF;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('ROWCOUNT='||SQL%ROWCOUNT||' code='||SQLCODE||' msg='||SQLERRM);
  RAISE;
END;
/
```

---

## 11) Function defaults — return safe values on error (by policy)

```sql
CREATE OR REPLACE FUNCTION safe_get_name(p_id IN NUMBER)
  RETURN VARCHAR2
AS
  v_name VARCHAR2(200);
BEGIN
  SELECT full_name INTO v_name FROM accounts WHERE account_id = p_id;
  RETURN v_name;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL; -- policy: missing → NULL
  WHEN OTHERS THEN
    -- log, then either re-raise or return sentinel
    RETURN '<<error>>';
END;
/
```

---

## 12) Re-raising with more context — *and* preserving original site

```sql
DECLARE
  PROCEDURE wrap IS
  BEGIN
    BEGIN
      RAISE_APPLICATION_ERROR(-20030,'Inner fail');
    EXCEPTION WHEN OTHERS THEN
      -- Attach extra context via a new error; include old stack in message
      RAISE_APPLICATION_ERROR(
        -20031,
        'While syncing accounts: '||
        DBMS_UTILITY.format_error_stack||CHR(10)||
        DBMS_UTILITY.format_error_backtrace
      );
    END;
  END;
BEGIN
  wrap;
END;
/
```

**Note:** This emits a new error `-20031` (new site). If you want the *original* site preserved, prefer `RAISE;` after logging.

---

## 13) Defensive parse/convert — map to named exceptions

```sql
DECLARE
  e_bad_json EXCEPTION; PRAGMA EXCEPTION_INIT(e_bad_json, -40441); -- example code
  v_obj JSON_OBJECT_T;
BEGIN
  v_obj := JSON_OBJECT_T.parse('not json');  -- raises
EXCEPTION
  WHEN e_bad_json THEN
    RAISE_APPLICATION_ERROR(-20110,'Invalid JSON payload');
END;
/
```

---

## 14) Timeouts, locks, and retry — translate to retryable

```sql
DECLARE
  e_timeout EXCEPTION; PRAGMA EXCEPTION_INIT(e_timeout, -30006); -- AQ/lock timeout example
  attempt PLS_INTEGER := 0;
BEGIN
  <<try>>
  BEGIN
    attempt := attempt + 1;
    -- do work that may time out on locks…
  EXCEPTION
    WHEN e_timeout THEN
      IF attempt < 5 THEN
        DBMS_LOCK.SLEEP(0.25 * POWER(2, attempt)); -- backoff
        GOTO try; -- or wrap in a loop
      ELSE
        RAISE;
      END IF;
  END;
END;
/
```

---

## 15) Package-level “finally” using nested blocks

```sql
DECLARE
  v_need_cleanup BOOLEAN := TRUE;
BEGIN
  BEGIN
    -- work
    v_need_cleanup := TRUE;
    NULL;
  EXCEPTION
    WHEN OTHERS THEN
      -- handle / log
      RAISE;
  END;

  -- finally
  IF v_need_cleanup THEN
    NULL; -- cleanup action
  END IF;
END;
/
```

---

## 16) Handy snippets — copy as needed

### 16a) Error as JSON blob (for logs)

```sql
SELECT JSON_OBJECT(
         'code'  VALUE SQLCODE,
         'stack' VALUE DBMS_UTILITY.format_error_stack,
         'bt'    VALUE DBMS_UTILITY.format_error_backtrace
       ) AS err_json
FROM dual;
```

### 16b) Assert helpers

```sql
SUBTYPE t_email IS VARCHAR2(320);
PROCEDURE assert_nonnull(p_name IN VARCHAR2, p_val IN VARCHAR2) IS
BEGIN IF p_val IS NULL THEN RAISE_APPLICATION_ERROR(-20500, p_name||' is required'); END IF; END;
```

### 16c) “Retry on ORA-00060 (deadlock)” detector

```sql
DECLARE
  e_deadlock EXCEPTION; PRAGMA EXCEPTION_INIT(e_deadlock, -60);
BEGIN
  NULL; -- risky section
EXCEPTION
  WHEN e_deadlock THEN
    -- retry or queue for retry
    RAISE;
END;
/
```

---

## 17) Best practices (opinions that pay off)

* **Keep try-scopes small.** Rescue only what you can truly handle.
* **Preserve the stack.** Log context, then `RAISE;` unless you intentionally replace with a domain error.
* **Prefer named exceptions** with `PRAGMA EXCEPTION_INIT` over raw `-nnnnn` checks.
* **Use `SAVEPOINT`** for partial work; **`DBMS_ERRLOG`** for bulk loads; **`SAVE EXCEPTIONS`** for `FORALL`.
* **Don’t mask failures** with `WHEN OTHERS THEN NULL`. If you must, log loudly.
* **Centralize logging** (autonomous transaction) so errors survive rollbacks.
* **Allocate error code ranges** per package/domain for maintainability.

