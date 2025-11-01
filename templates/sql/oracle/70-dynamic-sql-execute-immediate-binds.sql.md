###### Oracle PL/SQL
### Dynamic SQL with binds (+ RETURNING)
Avoid concatenation; bind both inputs and outputs.

#### Oracle PL/SQL
```sql
DECLARE
  v_sql   VARCHAR2(4000) := 'INSERT INTO t(pk,val) VALUES (:1,:2) RETURNING val INTO :3';
  v_new   VARCHAR2(100);
BEGIN
  EXECUTE IMMEDIATE v_sql
    USING 1001, 'hello'
    RETURNING INTO v_new;

  DBMS_OUTPUT.PUT_LINE('Inserted val='||v_new);
END;
/
```

```yaml
---
id: templates/sql/oracle/70-dynamic-sql-execute-immediate-binds.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, dynamic-sql, execute-immediate, binds]
description: "Use EXECUTE IMMEDIATE with proper bind variables and RETURNING INTO"
---
```