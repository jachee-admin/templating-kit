###### Oracle PL/SQL
# Ref Cursors


## In SQL*Plus / SQLcl

```sql
VAR rc REFCURSOR
EXEC api.list_emp(:rc, 10);
PRINT rc
```

## From PL/SQL

```sql
DECLARE
  l_rc api.refcur;     -- strong
  l_emp emp%ROWTYPE;
BEGIN
  api.list_emp(l_rc, 10);
  LOOP
    FETCH l_rc INTO l_emp;
    EXIT WHEN l_rc%NOTFOUND;
    -- do something with l_emp
  END LOOP;
  CLOSE l_rc;          -- you opened it; you close it
END;
/
```

## Using `SYS_REFCURSOR` (common, avoids package type dependency)

```sql
CREATE OR REPLACE PACKAGE api AS
  PROCEDURE list_emp(p OUT SYS_REFCURSOR, p_dept IN NUMBER);
END;
/
CREATE OR REPLACE PACKAGE BODY api AS
  PROCEDURE list_emp(p OUT SYS_REFCURSOR, p_dept IN NUMBER) IS
  BEGIN
    OPEN p FOR SELECT empno, ename FROM emp WHERE deptno = p_dept;
  END;
END;
/
```

## Function variant (often simpler to call)

```sql
CREATE OR REPLACE PACKAGE api AS
  FUNCTION list_emp(p_dept IN NUMBER) RETURN SYS_REFCURSOR;
END;
/
CREATE OR REPLACE PACKAGE BODY api AS
  FUNCTION list_emp(p_dept IN NUMBER) RETURN SYS_REFCURSOR IS
    c SYS_REFCURSOR;
  BEGIN
    OPEN c FOR SELECT empno, ename FROM emp WHERE deptno = p_dept;
    RETURN c;
  END;
END;
/
-- SQL*Plus
VAR rc REFCURSOR
EXEC :rc := api.list_emp(10);
PRINT rc
```

## Language bindings (mini-snips)

**Python (cx_Oracle / oracledb)**

```python
import oracledb
conn = oracledb.connect(dsn="...", user="...", password="...")
with conn.cursor() as cur:
    out_cur = cur.var(oracledb.CURSOR)
    cur.callproc("api.list_emp", [out_cur, 10])
    for row in out_cur.getvalue():
        print(row)
```

**Java (JDBC)**

```java
try (Connection c = ds.getConnection();
     CallableStatement cs = c.prepareCall("{ call api.list_emp(?, ?) }")) {
  cs.registerOutParameter(1, oracle.jdbc.OracleTypes.CURSOR);
  cs.setInt(2, 10);
  cs.execute();
  try (ResultSet rs = (ResultSet) cs.getObject(1)) {
    while (rs.next()) { /* read cols */ }
  }
}
```

**Node.js (oracledb)**

```js
const oracledb = require('oracledb');
const conn = await oracledb.getConnection({...});
const result = await conn.execute(
  `BEGIN api.list_emp(:rc, :dept); END;`,
  { rc: { dir: oracledb.BIND_OUT, type: oracledb.CURSOR }, dept: 10 }
);
const rs = result.outBinds.rc;
let row;
while ((row = await rs.getRow())) console.log(row);
await rs.close();
```

## Strong vs weak REF CURSOR

* **Strong** (`TYPE refcur RETURN emp%ROWTYPE`) catches column-mismatch at compile time but couples callers to that shape.
* **Weak** (`SYS_REFCURSOR`) is flexible and common for APIs; callers rely on runtime shape.

## Gotchas & tips

* **Close what you open.** The ref cursor’s lifetime is your session; always `CLOSE` it client-side or in PL/SQL when done.
* **Avoid `SELECT *`.** Return stable, explicit columns—APIs shouldn’t surprise clients when the table changes.
* **Bind, don’t concat.** Keep the `OPEN ... FOR SELECT ... WHERE deptno = :b1`.
* **No commits inside.** Let callers control the transaction.
* **Multiple result sets?** Add multiple OUT ref cursors:

  ```sql
  PROCEDURE list_emp_and_dept(p_emp OUT SYS_REFCURSOR, p_dept OUT SYS_REFCURSOR, p_deptno IN NUMBER);
  ```
* **Need SQL composability (join/filter in SQL)?** Prefer a **pipelined table function** or `SQL` features like `JSON_TABLE`. Ref cursors are primarily for client consumption, not in-SQL joins.

```yaml
---
id: templates/sql/oracle/370-ref-cursors.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.3"
tested_on: "Oracle 19c"
tags: [plsql, cursor, ref cursor, variables, constants, datatypes]
description: "Examples declaring and using ref cursors."
---
```