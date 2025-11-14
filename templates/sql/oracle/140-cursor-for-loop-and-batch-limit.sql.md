###### Oracle PL/SQL
### Cursor FOR loop with commit interval
Maintainable batching without full BULK COLLECT.
```sql
DECLARE
  c_batch CONSTANT PLS_INTEGER := 500;
  i PLS_INTEGER := 0;
BEGIN
  FOR r IN (SELECT id FROM t WHERE processed = 'N' ORDER BY id) LOOP
    UPDATE t SET processed = 'Y' WHERE id = r.id;
    i := i + 1;
    IF MOD(i, c_batch) = 0 THEN
      COMMIT; -- safe commit boundary
    END IF;
  END LOOP;
  COMMIT;
END;
/
```


```yaml
---
id: docs/sql/oracle/140-cursor-for-loop-and-batch-limit.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, cursors, batching]
description: "Cursor FOR loop in batches; commit safely after chunks"
---
```