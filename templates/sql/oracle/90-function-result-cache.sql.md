---
id: sql/oracle/plsql/function-result-cache
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, cache, performance, function]
description: "Use FUNCTION RESULT_CACHE for fast repeat lookups of immutable data"
---
###### Oracle PL/SQL
### FUNCTION ... RESULT_CACHE
Cache pure function results by arguments. Perfect for small reference lookups.

#### Oracle PL/SQL
```sql
CREATE OR REPLACE FUNCTION get_country_name(p_id IN NUMBER)
  RETURN VARCHAR2
  RESULT_CACHE RELIES_ON (countries)  -- optional dependency
IS
  v_name countries.name%TYPE;
BEGIN
  SELECT name INTO v_name FROM countries WHERE id = p_id;
  RETURN v_name;
END;
/
```
