###### Oracle PL/SQL
### Named exceptions via PRAGMA EXCEPTION_INIT
Give ORA‑codes human names so handlers read cleanly and self‑document intent.

#### Oracle PL/SQL
```sql
DECLARE
  e_dup_key EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_dup_key, -1); -- ORA-00001 unique constraint violated

  e_timeout  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_timeout, -30006); -- Advanced Queuing example
BEGIN
  INSERT INTO t(pk, val) VALUES (42, 'x');
EXCEPTION
  WHEN e_dup_key THEN
    DBMS_OUTPUT.PUT_LINE('Duplicate key, switching to update');
  WHEN e_timeout THEN
    DBMS_OUTPUT.PUT_LINE('Timed out on resource');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Unexpected: '||SQLERRM);
END;
/
```
```yaml
---
id: docs/sql/oracle/50-exception-mapping-pragmas.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, exceptions, pragma, exception_init]
description: "Map ORA- errors to named exceptions with PRAGMA EXCEPTION_INIT for readable handlers"
---
```