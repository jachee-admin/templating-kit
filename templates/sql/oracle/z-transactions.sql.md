---
id: sql/oracle/plsql/transaction-management-19c
lang: sql
platform: oracle
scope: plsql
since: "v0.11"
tested_on: "Oracle 19c"
tags: [plsql, transactions, commit, rollback, savepoint, autonomous_transaction, for-update, nowait, skip-locked, wait, where-current-of, set-transaction, isolation, serializable, read-only, dbms_lock, retry, deadlock]
description: "End-to-end transaction management patterns: COMMIT/ROLLBACK/SAVEPOINT, PRAGMA AUTONOMOUS_TRANSACTION, row-level locking (FOR UPDATE, NOWAIT, WAIT n, SKIP LOCKED, WHERE CURRENT OF), SET TRANSACTION (READ ONLY / ISOLATION LEVEL SERIALIZABLE / NAME), advisory locks with DBMS_LOCK, and resilient retry patterns."
---
###### Oracle PL/SQL
### Transaction Management — commits, locks, isolation, and retries (Oracle 19c)
Practical, paste-ready patterns for safe concurrency and clean transaction boundaries.

---

## 0) Fundamentals (statement vs transaction)
- Each session runs in **READ COMMITTED** by default; queries see a **consistent snapshot** (SCN) as of statement start.
- DML changes become visible to others **after COMMIT**.
- Use **SAVEPOINT** for partial rollbacks inside a transaction.

```sql
-- Basics
SAVEPOINT before_batch;
-- … do work …
ROLLBACK TO SAVEPOINT before_batch;  -- undo just a portion
COMMIT;                               -- make all work durable
````

---

## 1) Row-level locks with `FOR UPDATE` family

### 1.1) Basic `FOR UPDATE` + `WHERE CURRENT OF`

Locks selected rows until COMMIT/ROLLBACK; prevents others from changing them.

```sql
DECLARE
  CURSOR c IS
    SELECT order_id
    FROM   orders
    WHERE  processed = 'N'
    FOR UPDATE OF processed;  -- lock target column(s)
BEGIN
  FOR r IN c LOOP
    UPDATE orders
       SET processed = 'Y', processed_at = SYSTIMESTAMP
     WHERE CURRENT OF c;   -- *exact row* we fetched
  END LOOP;
  COMMIT;
END;
/
```

### 1.2) Avoid blocking: `NOWAIT`, `WAIT n`, `SKIP LOCKED`

```sql
-- Raise immediately if any row is locked
SELECT * FROM orders
 WHERE processed = 'N'
 FOR UPDATE NOWAIT;

-- Wait up to 5 seconds for locks
SELECT * FROM orders
 WHERE processed = 'N'
 FOR UPDATE WAIT 5;

-- Job-queue style: skip locked rows (great for workers in parallel)
DECLARE
  CURSOR cq IS
    SELECT order_id
    FROM   orders
    WHERE  processed = 'N'
    FOR UPDATE SKIP LOCKED;
BEGIN
  FOR r IN cq LOOP
    UPDATE orders SET processed='Y', processed_at=SYSTIMESTAMP WHERE CURRENT OF cq;
  END LOOP;
  COMMIT;
END;
/
```

---

## 2) Transaction scoping with `SET TRANSACTION`

### 2.1) Read-only report (statement set sees a stable snapshot)

```sql
SET TRANSACTION READ ONLY;
-- run reporting queries here (can join, aggregate, etc.)
-- DML is disallowed in READ ONLY transaction
COMMIT;
```

### 2.2) Isolation level SERIALIZABLE (avoid phantom reads)

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- run business logic that must see a consistent DB state across multiple statements
-- May raise ORA-08177 (can't serialize access) → catch & retry
COMMIT;
```

### 2.3) Name your transaction (helps tracing in V$ views)

```sql
SET TRANSACTION NAME 'onboard_job_2025-11-01';
-- do work...
COMMIT;
```

---

## 3) Autonomous transactions (side effects that must survive)

Use **`PRAGMA AUTONOMOUS_TRANSACTION`** for logging/audit actions that must commit independently of the caller. Keep them **short** and **simple**.

```sql
CREATE OR REPLACE PROCEDURE log_event(p_level IN VARCHAR2, p_msg IN CLOB) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO log_event(level, msg) VALUES (p_level, p_msg);
  COMMIT;  -- required inside autonomous block
END;
/
```

**Guidelines**

* Do not perform business DML that the caller might expect to roll back.
* Avoid long-running work (no user locks; minimal latching).
* Catch errors locally—don’t let autonomous failures mask caller logic.

---

## 4) Savepoints for partial rollback inside loops

```sql
DECLARE
  TYPE t_ids IS TABLE OF orders.order_id%TYPE;
  v_ids t_ids := t_ids(1001,1002,1003,1004);
BEGIN
  FOR i IN 1 .. v_ids.COUNT LOOP
    SAVEPOINT row_i;
    BEGIN
      UPDATE orders SET processed='Y' WHERE order_id = v_ids(i);
      -- additional DML…
    EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK TO SAVEPOINT row_i;   -- undo only this iteration
        log_event('ERROR', 'Failed order_id='||v_ids(i)||' err='||SQLERRM);
    END;
  END LOOP;
  COMMIT;
END;
/
```

---

## 5) Locking whole tables (rare, maintenance windows)

```sql
LOCK TABLE accounts IN EXCLUSIVE MODE NOWAIT;   -- or SHARE/ROW SHARE/ROW EXCLUSIVE
-- perform DDL-compatible maintenance, then
COMMIT;  -- releases lock
```

Prefer **row-level** locks with `FOR UPDATE` over table locks in OLTP systems.

---

## 6) Advisory/application locks (`DBMS_LOCK`) — serialize critical sections

```sql
DECLARE
  v_status  PLS_INTEGER;
  v_lock_id PLS_INTEGER := DBMS_UTILITY.get_hash_value('accounts:reseq', 0, 2**30);
BEGIN
  -- Try to obtain user lock for up to 10 seconds (mode 6 = exclusive)
  v_status := DBMS_LOCK.request(id => v_lock_id, lockmode => 6, timeout => 10, release_on_commit => TRUE);

  IF v_status = 0 THEN
    -- critical section
    -- … do work that must be globally serialized …
    COMMIT;  -- releases the advisory lock (release_on_commit=TRUE)
  ELSIF v_status = 1 THEN
    RAISE_APPLICATION_ERROR(-20090, 'Timeout acquiring app lock');
  ELSE
    RAISE_APPLICATION_ERROR(-20091, 'Lock request failed code='||v_status);
  END IF;
END;
/
```

---

## 7) Deadlock & lock-timeout–safe retries

```sql
DECLARE
  e_deadlock  EXCEPTION; PRAGMA EXCEPTION_INIT(e_deadlock, -60);     -- ORA-00060
  e_timeout   EXCEPTION; PRAGMA EXCEPTION_INIT(e_timeout , -54);     -- resource busy (NOWAIT)
  attempts PLS_INTEGER := 0;
BEGIN
  <<again>>
  BEGIN
    attempts := attempts + 1;

    -- Try to lock target rows quickly; fail fast if busy
    UPDATE orders SET processed='Y'
    WHERE order_id IN (
      SELECT order_id FROM orders WHERE processed='N' FOR UPDATE NOWAIT
    );

    COMMIT;
  EXCEPTION
    WHEN e_deadlock OR e_timeout THEN
      IF attempts < 5 THEN
        DBMS_LOCK.SLEEP(0.1 * POWER(2, attempts)); -- backoff
        GOTO again;
      ELSE
        RAISE;
      END IF;
  END;
END;
/
```

---

## 8) Worker-friendly “queue table” using `SKIP LOCKED`

Multiple concurrent workers can safely consume pending work without stepping on each other.

```sql
DECLARE
  CURSOR cq IS
    SELECT id
    FROM   work_queue
    WHERE  status = 'PENDING'
    FOR UPDATE SKIP LOCKED;
BEGIN
  FOR r IN cq LOOP
    UPDATE work_queue
       SET status='RUNNING', started_at=SYSTIMESTAMP
     WHERE CURRENT OF cq;

    BEGIN
      -- do the actual work...
      UPDATE work_queue
         SET status='DONE', finished_at=SYSTIMESTAMP
       WHERE id = r.id;
    EXCEPTION
      WHEN OTHERS THEN
        UPDATE work_queue SET status='ERROR', error_msg=SUBSTR(SQLERRM,1,4000) WHERE id=r.id;
    END;
    COMMIT;  -- release lock and make result visible
  END LOOP;
END;
/
```

---

## 9) Serializable transactions — detect & retry `ORA-08177`

```sql
DECLARE
  e_ser EXCEPTION; PRAGMA EXCEPTION_INIT(e_ser, -8177); -- can't serialize access
  tries PLS_INTEGER := 0;
BEGIN
  <<try>>
  BEGIN
    tries := tries + 1;
    EXECUTE IMMEDIATE 'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE';

    -- read → decide → write logic that must be anomaly-free
    -- …

    COMMIT;
  EXCEPTION
    WHEN e_ser THEN
      ROLLBACK;
      IF tries < 3 THEN DBMS_LOCK.SLEEP(0.2 * tries); GOTO try; ELSE RAISE; END IF;
  END;
END;
/
```

---

## 10) Practical do/don’t checklist

* **Do** keep transactions **short**; hold locks only as long as needed.
* **Do** use `FOR UPDATE SKIP LOCKED` for parallel workers; **avoid** hot spots.
* **Do** use **SAVEPOINTS** for partial rollback in loops; **avoid** per-row COMMIT.
* **Do not** use autonomous transactions for business data; reserve for **logs/audit**.
* **Do** prefer `READ ONLY` or **SERIALIZABLE** only where required; default READ COMMITTED is fine for most OLTP.
* **Do** tag important work with **`SET TRANSACTION NAME`** + `DBMS_APPLICATION_INFO.SET_MODULE/ACTION` for traceability.
* **Do** implement **retry** for deadlocks/timeouts with jittered backoff.
* **Do** test concurrency paths with realistic parallel sessions and verify with `DBMS_XPLAN.DISPLAY_CURSOR` + ASH/AWR where available.

