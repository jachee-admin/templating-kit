---
id: sql/oracle/append-errlog
lang: sql
platform: oracle
scope: dml
since: "v0.1"
tested_on: "Oracle 19c"
tags: [direct-path, error-logging]
description: "High-throughput insert with DML error logging"
---
###### Oracle PL/SQL
### Errlog: Setup once
```sql
BEGIN
  DBMS_ERRLOG.CREATE_ERROR_LOG(dml_table_name => 'STAGE_ORDERS_CSV');
END;
/
```

### Primary snippet
```sql
INSERT /*+ APPEND */ INTO stage_orders_csv (col1, col2, ...)
SELECT col1, col2, ...
FROM   ext_table
LOG ERRORS INTO err$_stage_orders_csv ('LOAD') REJECT LIMIT UNLIMITED;
```
