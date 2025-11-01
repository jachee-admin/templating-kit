###### Oracle PL/SQL
### Pipelined table function
Great for lightweight transforms without staging tables.

#### Oracle PL/SQL
```sql
-- Row type
CREATE OR REPLACE TYPE t_row AS OBJECT (id NUMBER, val VARCHAR2(100));
/
CREATE OR REPLACE TYPE t_row_tab AS TABLE OF t_row;
/

-- Function
CREATE OR REPLACE FUNCTION f_numbers(n IN PLS_INTEGER)
  RETURN t_row_tab PIPELINED IS
BEGIN
  FOR i IN 1..n LOOP
    PIPE ROW (t_row(i, 'val-'||i));
  END LOOP;
  RETURN;
END;
/
-- Use it
SELECT * FROM TABLE(f_numbers(5));
```

```yaml
---
id: sql/oracle/plsql/pipelined-function
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, pipelined, table-function]
description: "Stream rows from PL/SQL as if they were a table using a pipelined function"
---
```