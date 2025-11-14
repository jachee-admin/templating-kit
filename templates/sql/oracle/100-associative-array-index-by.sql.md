###### Oracle PL/SQL
### Associative array (map) idiom
Hash‑map semantics for quick lookups and de‑dupe.

#### Oracle PL/SQL
```sql
DECLARE
  TYPE t_map IS TABLE OF NUMBER INDEX BY VARCHAR2(320);
  v_seen t_map;
BEGIN
  v_seen('alice@example.com') := 1;
  IF v_seen.EXISTS('alice@example.com') THEN
    DBMS_OUTPUT.PUT_LINE('seen');
  END IF;
  v_seen.DELETE('alice@example.com');
END;
/
```

```yaml
---
id: docs/sql/oracle/100-associative-array-index-by.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, collections, associative-array]
description: "INDEX BY (associative) arrays: fast in-memory maps keyed by VARCHAR2 or PLS_INTEGER"
---
```