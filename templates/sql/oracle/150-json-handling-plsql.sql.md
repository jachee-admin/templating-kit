###### Oracle PL/SQL
### JSON in PL/SQL (object API)
Cleanly parse, access, and emit JSON without string hacks.
```sql
DECLARE
  j   json_object_t := json_object_t('{"id":1,"tags":["a","b"]}');
  arr json_array_t;
BEGIN
  DBMS_OUTPUT.PUT_LINE('id='|| j.get_Number('id'));
  arr := j.get_Array('tags');
  arr.append('c');
  j.put('tags', arr);
  DBMS_OUTPUT.PUT_LINE(j.stringify);
END;
/
```

```yaml
---
id: stemplates/sql/oracle/150-json-handling-plsql.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, json, json_object_t]
description: "Use JSON_OBJECT_T/JSON_ARRAY_T to parse and build JSON"
---
```