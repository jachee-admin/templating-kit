###### Oracle PL/SQL
### Performance & safety tips

- Push work into **single SQL statements** where feasible; PL/SQL loops over rows are slow → use **BULK COLLECT + FORALL**.

- Use `PLS_INTEGER` in tight loops; avoid implicit conversions.

- Beware **implicit commits** (DDL like `CREATE/ALTER` commit).

- Use `NOCOPY` for large OUT params to reduce copies:

  ```sql
  PROCEDURE fill(p_tab IN OUT NOCOPY t_tab);
  ```

- Mark pure functions `DETERMINISTIC` (enables function-based indexes).

- Prefer bind variables; never string-concatenate user input.
```yaml
---
id: templates/sql/oracle/300-perf.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.14"
tested_on: "Oracle 19c"
tags: [plsql, packages, dbms_output, dbms_application_info, dbms_utility, dbms_lock, dbms_random, dbms_scheduler, utl_file, dbms_xplan, dbms_assert, dbms_metadata, dbms_stats, dbms_errlog, dbms_sql, utl_http]
description: "Daily-driver PL/SQL packages with concise, copy-pasteable examples. Includes: DBMS_OUTPUT, DBMS_APPLICATION_INFO, DBMS_UTILITY, DBMS_LOCK, DBMS_RANDOM, DBMS_SCHEDULER, UTL_FILE, DBMS_XPLAN, plus high-value extras: DBMS_ASSERT, DBMS_METADATA, DBMS_STATS, DBMS_ERRLOG, DBMS_SQL, UTL_HTTP."
---
```