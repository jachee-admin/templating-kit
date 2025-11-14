###### Oracle PL/SQL
### Helpful Packages — daily drivers & greatest hits (Oracle 19c)
Practical, minimal snippets you’ll actually reuse.

---

## 1) `DBMS_OUTPUT` — dev prints (enable with `SET SERVEROUTPUT ON`)
```sql
BEGIN
  DBMS_OUTPUT.PUT_LINE('Hello from PL/SQL');
  DBMS_OUTPUT.PUT_LINE('Rows='||TO_CHAR(SQL%ROWCOUNT));
END;
/
````

---

## 2) `DBMS_APPLICATION_INFO` — instrument sessions (shows in v$session)

```sql
BEGIN
  DBMS_APPLICATION_INFO.SET_MODULE(module_name => 'APEX:Onboard', action_name => 'Step 1');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('acct=1001');
  -- work...
  DBMS_APPLICATION_INFO.SET_ACTION('Step 2');
END;
/
```

---

## 3) `DBMS_UTILITY` — rich errors & helpers

```sql
BEGIN
  -- simulate error
  RAISE_APPLICATION_ERROR(-20001,'Boom');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_stack);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_error_backtrace);
    DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.format_call_stack);
END;
/
```

---

## 4) `DBMS_LOCK` — sleep / advisory locking

```sql
BEGIN
  DBMS_LOCK.SLEEP(0.5); -- seconds (fractional ok)
END;
/
```

Advisory lock (serialize a critical section):

```sql
DECLARE
  v_status  PLS_INTEGER;
  v_lock_id PLS_INTEGER := DBMS_UTILITY.get_hash_value('my:critical:section',0,2**30);
BEGIN
  v_status := DBMS_LOCK.REQUEST(v_lock_id, lockmode => 6, timeout => 5, release_on_commit => TRUE);
  IF v_status=0 THEN
    -- critical work...
    COMMIT; -- releases lock
  ELSE
    RAISE_APPLICATION_ERROR(-20090,'Could not obtain lock (status='||v_status||')');
  END IF;
END;
/
```

---

## 5) `DBMS_RANDOM` — test data (seed/value/string)

```sql
BEGIN
  DBMS_RANDOM.SEED(TO_CHAR(SYSTIMESTAMP,'FF')); -- optional
  DBMS_OUTPUT.PUT_LINE( ROUND(DBMS_RANDOM.VALUE(1,100)) );   -- number
  DBMS_OUTPUT.PUT_LINE( DBMS_RANDOM.STRING('A', 12) );       -- letters
  DBMS_OUTPUT.PUT_LINE( DBMS_RANDOM.STRING('X', 16) );       -- hex
END;
/
```

---

## 6) `DBMS_SCHEDULER` — create/run/monitor jobs

```sql
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'job_nightly_refresh',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[
      BEGIN
        -- your procedure(s)
        NULL;
      END;]',
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
    enabled         => TRUE,
    comments        => 'Nightly refresh at 02:00');
END;
/
```

Run now & check:

```sql
BEGIN
  DBMS_SCHEDULER.RUN_JOB('job_nightly_refresh', use_current_session => FALSE);
END;
/

SELECT job_name, state, last_start_date, run_count
FROM   user_scheduler_jobs
WHERE  job_name = 'JOB_NIGHTLY_REFRESH';
```

---

## 7) `UTL_FILE` — file I/O (requires DIRECTORY object + grants)

Create directory (DBA once):

```sql
CREATE OR REPLACE DIRECTORY app_out AS '/u01/app/out';
GRANT READ, WRITE ON DIRECTORY app_out TO YOUR_SCHEMA;
```

Write a file:

```sql
DECLARE
  f UTL_FILE.FILE_TYPE;
BEGIN
  f := UTL_FILE.FOPEN('APP_OUT','example.txt','w', 32767);
  UTL_FILE.PUT_LINE(f, 'hello file');
  UTL_FILE.FCLOSE(f);
END;
/
```

---

## 8) `DBMS_XPLAN` — show execution plans (after running a statement)

```sql
-- In SQL*Plus/SQLcl: set statistics first, then run your query with hint
-- SELECT /*+ gather_plan_statistics */ ... ;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

---

## 9) `DBMS_ASSERT` — SQL injection defense for identifiers

```sql
DECLARE
  p_owner VARCHAR2(30) := DBMS_ASSERT.SCHEMA_NAME('APP');
  p_tab   VARCHAR2(30) := DBMS_ASSERT.SIMPLE_SQL_NAME('ACCOUNTS');
  p_col   VARCHAR2(30) := DBMS_ASSERT.SIMPLE_SQL_NAME('EMAIL');
  stmt    VARCHAR2(4000);
BEGIN
  stmt := 'SELECT '||p_col||' FROM '||p_owner||'.'||p_tab||' WHERE ROWNUM<=1';
  EXECUTE IMMEDIATE stmt;
END;
/
```

---

## 10) `DBMS_METADATA` — extract DDL (handy for migrations/backups)

```sql
SET LONG 100000
SELECT DBMS_METADATA.GET_DDL('TABLE','ACCOUNTS',USER) AS ddl FROM dual;
```

---

## 11) `DBMS_STATS` — gather stats (modern way)

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname          => USER,
    tabname          => 'ACCOUNTS',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    cascade          => TRUE
  );
END;
/
```

---

## 12) `DBMS_ERRLOG` — log bad rows on bulk DML instead of failing

```sql
BEGIN
  DBMS_ERRLOG.CREATE_ERROR_LOG('ACCOUNTS'); -- creates ERR$_ACCOUNTS
END;
/
INSERT INTO accounts(email)
SELECT email FROM staging_accounts
LOG ERRORS INTO ERR$_ACCOUNTS ('LOAD') REJECT LIMIT UNLIMITED;
```

---

## 13) `DBMS_SQL` — truly dynamic queries (unknown column list)

```sql
DECLARE
  c        INTEGER;
  cnt      INTEGER;
  desc_tab DBMS_SQL.DESC_TAB2;
  v_vc     VARCHAR2(4000);
BEGIN
  c := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(c, 'SELECT * FROM accounts WHERE email LIKE :x', DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':x', 'a%');
  DBMS_SQL.DESCRIBE_COLUMNS2(c, cnt, desc_tab);
  FOR i IN 1..cnt LOOP DBMS_SQL.DEFINE_COLUMN(c, i, v_vc, 4000); END LOOP;
  DBMS_SQL.EXECUTE(c);
  WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
    DBMS_SQL.COLUMN_VALUE(c, 1, v_vc);
    NULL; -- consume row
  END LOOP;
  DBMS_SQL.CLOSE_CURSOR(c);
END;
/
```

---

## 14) `UTL_HTTP` — quick HTTP calls (e.g., webhook, REST)

```sql
DECLARE
  req  UTL_HTTP.req;
  resp UTL_HTTP.resp;
  line VARCHAR2(32767);
BEGIN
  UTL_HTTP.set_wallet('file:/u01/app/wallet', 'wallet_password'); -- if HTTPS & wallet needed
  req := UTL_HTTP.BEGIN_REQUEST('https://httpbin.org/get', 'GET', 'HTTP/1.1');
  UTL_HTTP.SET_HEADER(req, 'User-Agent', 'plsql/19c');
  resp := UTL_HTTP.GET_RESPONSE(req);
  LOOP
    UTL_HTTP.READ_LINE(resp, line, TRUE);
    DBMS_OUTPUT.PUT_LINE(line);
  EXIT WHEN line IS NULL;
  END LOOP;
  UTL_HTTP.END_RESPONSE(resp);
END;
/
```

> For POST JSON, use `BEGIN_REQUEST(..., 'POST', ...)`, set `Content-Type: application/json`, and call `UTL_HTTP.WRITE_TEXT`.

---

## 15) Small “glue” combos you’ll use a lot

### 15.1) Log + tag a unit of work

```sql
BEGIN
  DBMS_APPLICATION_INFO.SET_MODULE('APEX:Import','Stage CSV');
  DBMS_OUTPUT.PUT_LINE('Start import at '||TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'));
  -- work...
  DBMS_OUTPUT.PUT_LINE('Done. Rows='||SQL%ROWCOUNT);
END;
/
```

### 15.2) Plan + stats check

```sql
-- Run your statement with /*+ gather_plan_statistics */, then:
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST +PEEKED_BINDS'));
```

### 15.3) Safe dynamic DDL with `DBMS_ASSERT`

```sql
DECLARE
  t VARCHAR2(30) := DBMS_ASSERT.SIMPLE_SQL_NAME('TMP_'||TO_CHAR(SYSDATE,'YYYYMMDD'));
BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE '||t||'(id NUMBER)';
END;
/
```

---

## 16) Honorable mentions (look up when needed)

* **`DBMS_CRYPTO`** — hashing & encryption (be mindful of key mgmt/PCI rules).
* **`UTL_ENCODE`** — base64 etc.
* **`DBMS_ALERT`** / **`DBMS_AQ`** — lightweight pub/sub & queues.
* **`DBMS_XMLGEN`** / **`DBMS_JSON`** — serialize SQL to XML/JSON (alt to SQL JSON funcs).
* **`DBMS_SESSION`** — set client identifier, NLS, kill session (admin).
* **`DBMS_ROLLING`/`DBMS_REDEFINITION`** — online maintenance (DBA).

---

## 17) Quick cheats

```sql
-- Enable prints
SET SERVEROUTPUT ON SIZE UNLIMITED

-- One-off job run
BEGIN DBMS_SCHEDULER.RUN_JOB('JOB_NAME'); END; /

-- Show last cursor plan
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL,NULL,'ALLSTATS LAST'));
```
```yaml
---
id: docs/sql/oracle/290-packages-useful.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.14"
tested_on: "Oracle 19c"
tags: [plsql, packages, dbms_output, dbms_application_info, dbms_utility, dbms_lock, dbms_random, dbms_scheduler, utl_file, dbms_xplan, dbms_assert, dbms_metadata, dbms_stats, dbms_errlog, dbms_sql, utl_http]
description: "Daily-driver PL/SQL packages with concise, copy-pasteable examples. Includes: DBMS_OUTPUT, DBMS_APPLICATION_INFO, DBMS_UTILITY, DBMS_LOCK, DBMS_RANDOM, DBMS_SCHEDULER, UTL_FILE, DBMS_XPLAN, plus high-value extras: DBMS_ASSERT, DBMS_METADATA, DBMS_STATS, DBMS_ERRLOG, DBMS_SQL, UTL_HTTP."
---
```