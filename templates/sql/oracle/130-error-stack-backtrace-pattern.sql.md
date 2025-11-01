###### Oracle PL/SQL
### Re-raise with context, keep stack
Never swallow the stack; attach context then re-raise.
```sql
BEGIN
  -- some code
  RAISE_APPLICATION_ERROR(-20001, 'oops');
EXCEPTION
  WHEN OTHERS THEN
    log_err('my_module',
      DBMS_UTILITY.format_error_stack || CHR(10) ||
      DBMS_UTILITY.format_error_backtrace);
    RAISE;
END;
/
```

```yaml
---
id: templates/sql/oracle/130-error-stack-backtrace-pattern.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, error-handling, backtrace]
description: "Preserve stack and show where it failed using FORMAT_ERROR_BACKTRACE"
---
```