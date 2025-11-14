---
id: sql/oracle/explain-plan-modern
lang: sql
platform: oracle
scope: tuning
since: "v0.1"
tested_on: "Oracle 19c"
tags: [explain-plan, dbms_xplan]
description: "Plan table setup and display helpers"
---

## Oracle: Explain plan

### Create plan table (once per schema if missing)
```sql
@?/rdbms/admin/utlxplan.sql
```

### Explain + display
```sql
EXPLAIN PLAN FOR
SELECT /* test */ * FROM accounts WHERE email = :b1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE +PROJECTION'));
```
### After execution: real stats
```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```
