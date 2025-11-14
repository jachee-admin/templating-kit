###### Oracle PL/SQL

### MERGE upsert (clarity over cleverness)
Use a unique key and a straight MERGE; avoid racey SELECT+INSERT combos.


```sql
MERGE INTO accounts d
USING (SELECT :id id, :email email FROM dual) s
ON (d.id = s.id)
WHEN MATCHED THEN
  UPDATE SET d.email = s.email, d.updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN
  INSERT (id, email, created_at) VALUES (s.id, s.email, SYSTIMESTAMP);
```

```yaml
---
id: docs/sql/oracle/120-merge-upsert-plsql-locking.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, upsert, locking, merge]
description: "UPSERT pattern with MERGE; note locking semantics and unique keys"
---
```