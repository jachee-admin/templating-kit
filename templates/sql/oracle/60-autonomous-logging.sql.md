###### Oracle PL/SQL
### Autonomous transaction logger
Log errors even when the caller rolls back. Keep it tiny and safe.

#### Oracle PL/SQL
```sql
CREATE TABLE app_log
( ts TIMESTAMP DEFAULT SYSTIMESTAMP
, severity VARCHAR2(10)
, module   VARCHAR2(64)
, msg      CLOB );

CREATE OR REPLACE PROCEDURE log_err(p_module IN VARCHAR2, p_msg IN CLOB) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO app_log(severity, module, msg)
  VALUES ('ERROR', p_module, p_msg);
  COMMIT;
END;
/
```

```yaml
---
id: sql/oracle/plsql/autonomous-logging
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, logging, autonomous_transaction]
description: "Write durable logs from a failed transaction using PRAGMA AUTONOMOUS_TRANSACTION"
---
```