###### Oracle PL/SQL
### Dynamic SQL with binds (+ RETURNING)
Avoid concatenation; bind both inputs and outputs. `DBMS_SQL` described below


## Execute Immediate
```sql
DECLARE
  v_sql   VARCHAR2(4000) := 'INSERT INTO t(pk,val) VALUES (:1,:2) RETURNING val INTO :3';
  v_new   VARCHAR2(100);
BEGIN
  EXECUTE IMMEDIATE v_sql
    USING 1001, 'hello'
    RETURNING INTO v_new;

  DBMS_OUTPUT.PUT_LINE('Inserted val='||v_new);
END;
/
```

## DBMS_SQL
Here’s the mental model: `DBMS_SQL` is Oracle’s **low-level dynamic SQL engine**. It lets you build, bind, describe, and fetch from SQL that isn’t known until runtime—column count, types, and even the whole statement can be unknown at compile time. Think of it as the “manual transmission” compared to `EXECUTE IMMEDIATE` (automatic). You reach for it when you need **full dynamism** (unknown select list, variable number of bind vars, generic data browser, etc.).

## The core API (the ones you’ll use 90% of the time)

* `OPEN_CURSOR` → returns a numeric cursor id.
* `PARSE(c, stmt, DBMS_SQL.NATIVE)` → compiles the SQL text.
* `BIND_VARIABLE(c, name, value)` → binds a scalar (there are typed/array variants too).
* `DESCRIBE_COLUMNS2(c, col_cnt, desc_tab)` → returns metadata (name, type, length, precision/scale, etc.) for each select-list column. The “2” version adds extra metadata; use it.
* `DEFINE_COLUMN(c, pos, var [, maxlen])` → tells DBMS_SQL the datatype/size of the output slot at column *pos*. You must define **every** column you intend to fetch.
* `EXECUTE(c)` → runs the statement (for queries, it just opens the result set).
* `FETCH_ROWS(c)` → fetches the next batch; returns number of rows fetched (0 means no more).
* `COLUMN_VALUE(c, pos, var)` → read column *pos* of the current row into `var`.
* `CLOSE_CURSOR(c)` → always close what you opened.
* Nice extra: `TO_REFCURSOR(c)` → hand off a DBMS_SQL cursor as a `SYS_REFCURSOR`.

## Fetching rows “by position” (generic reader with `ANYDATA`)

You can define every column as `ANYDATA` and then interrogate the runtime type per value. That’s great for generic tools (data browsers, loggers, auditors).

```sql
DECLARE
  c        INTEGER := DBMS_SQL.OPEN_CURSOR;
  col_cnt  PLS_INTEGER;
  desc_tab DBMS_SQL.DESC_TAB2;
  rc       PLS_INTEGER;

  v ANYDATA; -- reused scratch slot for define/column_value
BEGIN
  DBMS_SQL.PARSE(c,
    'select empno, ename, hiredate, sal, deptno from emp where deptno = :d',
    DBMS_SQL.NATIVE);

  DBMS_SQL.BIND_VARIABLE(c, ':d', 10);

  DBMS_SQL.DESCRIBE_COLUMNS2(c, col_cnt, desc_tab);

  -- Define each column position as ANYDATA
  FOR i IN 1 .. col_cnt LOOP
    DBMS_SQL.DEFINE_COLUMN(c, i, v);
  END LOOP;

  rc := DBMS_SQL.EXECUTE(c);

  WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
    -- read each column by ordinal position
    FOR i IN 1 .. col_cnt LOOP
      DBMS_SQL.COLUMN_VALUE(c, i, v);

      -- Inspect and extract the runtime type
      DECLARE
        tname VARCHAR2(128);
        n     NUMBER;
        s     VARCHAR2(4000);
        d     DATE;
        ts    TIMESTAMP;
        code  PLS_INTEGER;
      BEGIN
        tname := v.GetTypeName;  -- e.g., 'NUMBER', 'VARCHAR2', 'DATE', 'TIMESTAMP'
        IF tname = 'NUMBER' THEN
          code := v.GetNumber(n);
          DBMS_OUTPUT.PUT_LINE('col['||i||'] NUM='||TO_CHAR(n));
        ELSIF tname = 'VARCHAR2' THEN
          code := v.GetVarchar2(s);
          DBMS_OUTPUT.PUT_LINE('col['||i||'] STR='||s);
        ELSIF tname = 'DATE' THEN
          code := v.GetDate(d);
          DBMS_OUTPUT.PUT_LINE('col['||i||'] DATE='||TO_CHAR(d,'YYYY-MM-DD'));
        ELSIF tname LIKE 'TIMESTAMP%' THEN
          code := v.GetTimestamp(ts);
          DBMS_OUTPUT.PUT_LINE('col['||i||'] TS='||TO_CHAR(ts,'YYYY-MM-DD HH24:MI:SS'));
        ELSE
          -- Add more cases (CLOB/BLOB/ROWID/OBJECT/etc.) as needed
          DBMS_OUTPUT.PUT_LINE('col['||i||'] ['||tname||'] (not handled)');
        END IF;
      END;
    END LOOP;
  END LOOP;

  DBMS_SQL.CLOSE_CURSOR(c);
EXCEPTION
  WHEN OTHERS THEN
    IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF;
    RAISE;
END;
/
```

Notes on that pattern:

* Defining a column as `ANYDATA` lets you fetch *whatever type it actually is* at runtime.
* `ANYDATA.Get*` routines typically return a status code (`0` = success) and pass the value out via an OUT parameter.
* If you already know the types, you can define strongly (faster, simpler): e.g. `DBMS_SQL.DEFINE_COLUMN(c, 1, l_empno);`, `DBMS_SQL.DEFINE_COLUMN(c, 2, l_ename, 4000);`, then fetch via `COLUMN_VALUE(c, pos, var)` with matching PL/SQL variables.

## Strongly-typed define/fetch (when shapes are known)

```sql
DECLARE
  c        INTEGER := DBMS_SQL.OPEN_CURSOR;
  l_empno  NUMBER;
  l_ename  VARCHAR2(4000);
BEGIN
  DBMS_SQL.PARSE(c,
    'select empno, ename from emp where deptno = :d',
    DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':d', 10);

  -- Define each column with matching PL/SQL types
  DBMS_SQL.DEFINE_COLUMN(c, 1, l_empno);
  DBMS_SQL.DEFINE_COLUMN(c, 2, l_ename, 4000);  -- strings need max length

  IGNORE := DBMS_SQL.EXECUTE(c);

  WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
    DBMS_SQL.COLUMN_VALUE(c, 1, l_empno);
    DBMS_SQL.COLUMN_VALUE(c, 2, l_ename);
    DBMS_OUTPUT.PUT_LINE(l_empno || ' ' || l_ename);
  END LOOP;

  DBMS_SQL.CLOSE_CURSOR(c);
END;
/
```

## What does `DESCRIBE_COLUMNS2` give you?

It fills `desc_tab` with one entry per select-list position: column name, datatype id/name, length/precision/scale, charset info, schema/type name for objects, etc. Typical workflow:

1. `DESCRIBE_COLUMNS2`
2. Loop `1..col_cnt` and choose a `DEFINE_COLUMN` strategy (e.g., for `VARCHAR2` use a max length from `desc_tab(i).col_max_len`).

## When to use `DBMS_SQL` vs `EXECUTE IMMEDIATE`

* Use **`EXECUTE IMMEDIATE`** for simple dynamic SQL with known shape and few binds—clean and fast.
* Use **`DBMS_SQL`** when:

  * the select list is dynamic/unknown,
  * the number or names of bind variables are dynamic,
  * you need to **describe** column metadata,
  * you want a **generic fetch by position** engine,
  * you’ll **convert to `SYS_REFCURSOR`** with `TO_REFCURSOR` (e.g., to return generic results to clients).

## `ANYDATA` in one minute

`ANYDATA` is a **universal container** for a single SQL value plus its type. It can hold scalars (`NUMBER`, `VARCHAR2`, `DATE`, `TIMESTAMP`, `CLOB`, etc.) and even objects. Key operations:

* **Create/convert**: `ANYDATA.ConvertNumber(42)`, `ANYDATA.ConvertVarchar2('x')`, `ANYDATA.ConvertObject(obj)`, …
* **Inspect**: `GetTypeName` (returns a string like `NUMBER`, `VARCHAR2`, `SCHEMA.OBJECT_TYPE`), or `GetType`.
* **Extract**: `GetNumber(n)`, `GetVarchar2(s)`, `GetDate(d)`, `GetTimestamp(ts)`, `GetCLOB(c)`, `GetBLOB(b)`, `GetObject(obj)`, etc.
  These return a status code (0 = success) and fill the OUT variable.

It pairs nicely with `DBMS_SQL` because you can define columns generically and still pull out the concrete values safely at runtime.

## Handy extras

* **Arrays**: `BIND_ARRAY` / `DEFINE_ARRAY` let you do array binds/gets (bulk I/O) if you need higher throughput.
* **Refcursor handoff**: After `PARSE`/`BIND`, you can do `l_rc := DBMS_SQL.TO_REFCURSOR(c);` and then fetch with normal cursor APIs. Once converted, the `DBMS_SQL` cursor id is no longer used by you.
* **Resource safety**: wrap with an exception block; always `CLOSE_CURSOR`. Use `DBMS_SQL.IS_OPEN(c)` before closing in the exception handler.

If you’re building a **generic “SELECT viewer”** or a **metadata-driven ETL** that doesn’t know column shapes ahead of time, this is exactly the right tool. For fixed-shape, performance-critical paths, plain SQL or `EXECUTE IMMEDIATE` stays simpler and faster.



```yaml
---
id: templates/sql/oracle/70-dynamic-sql-execute-immediate-binds.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, dynamic-sql, execute-immediate, binds]
description: "Use EXECUTE IMMEDIATE with proper bind variables and RETURNING INTO"
---
```