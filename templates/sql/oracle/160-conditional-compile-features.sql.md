
###### Oracle PL/SQL
### Conditional compilation
Gate debug code or 12c+ features without branching files.
```sql
DECLARE
  $$debug CONSTANT BOOLEAN := TRUE;
BEGIN
  $IF $$debug $THEN
    DBMS_OUTPUT.PUT_LINE('Debug on');
  $END
END;
/
```

```yaml
---
id: templates/sql/oracle/160-conditional-compile-features.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, conditional-compilation, $$plsql_pragma]
description: "Use conditional compilation for version-specific features or debug toggles"
---
```