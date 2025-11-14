###### Oracle PL/SQL
### Bulk COLLECT + FORALL with per-row error capture
High‑throughput pattern: fetch rows in arrays, DML with `FORALL`, keep going on bad rows using `SAVE EXCEPTIONS`, then report which rows failed.

#### Oracle PL/SQL
```sql
DECLARE
  CURSOR c_src IS
    SELECT id, email FROM stage_accounts ORDER BY id;
  TYPE t_src IS TABLE OF c_src%ROWTYPE;
  v_rows t_src;
BEGIN
  OPEN c_src;
  LOOP
    FETCH c_src BULK COLLECT INTO v_rows LIMIT 1000;
    EXIT WHEN v_rows.COUNT = 0;

    BEGIN
      FORALL i IN 1 .. v_rows.COUNT SAVE EXCEPTIONS
        INSERT INTO accounts(id, email) VALUES (v_rows(i).id, v_rows(i).email);

    EXCEPTION
      WHEN OTHERS THEN
        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
          DBMS_OUTPUT.PUT_LINE(
            'ERR at index='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
            ' code='||SQL%BULK_EXCEPTIONS(j).ERROR_CODE||
            ' msg='||SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
        END LOOP;
    END;
  END LOOP;
  CLOSE c_src;
END;
/
```

```yaml
---
id: docs/sql/oracle/40-bulk-collect-forall-save-exceptions.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, bulk-collect, forall, performance]
description: "Bulk fetch + FORALL DML with SAVE EXCEPTIONS and per-row error reporting"
---
```