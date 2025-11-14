###### Oracle PL/SQL
### Pipelined table function
Pipelined functions are **table functions** that stream rows back to the SQL engine as they’re produced, instead of first building a whole collection in memory and returning it at the end. Think “generator” in Python or a cursor you can `SELECT` from—but implemented as a PL/SQL function that returns a SQL collection type.

Your example is exactly that: the function returns a collection type (`t_emp_tab`) and uses `PIPE ROW(...)` inside a loop so the caller can start consuming rows immediately:

```sql
CREATE OR REPLACE TYPE t_emp_row AS OBJECT(empno NUMBER, ename VARCHAR2(50));
/
CREATE OR REPLACE TYPE t_emp_tab AS TABLE OF t_emp_row;
/
CREATE OR REPLACE FUNCTION f_emp_pipe(p_dept NUMBER)
  RETURN t_emp_tab PIPELINED
IS
BEGIN
  FOR r IN (SELECT empno, ename FROM emp WHERE deptno = p_dept) LOOP
    PIPE ROW(t_emp_row(r.empno, r.ename));
  END LOOP;
  RETURN; -- required, even though rows were already piped
END;
/
-- Use like a table:
SELECT * FROM TABLE(f_emp_pipe(10));
```

## When to use them

Use a pipelined table function when you want to **produce rows on the fly** and let SQL consume them like a table:

1. **Streaming/large outputs**
   Transform or generate millions of rows without materializing the entire result in memory first. The consumer can fetch rows as they’re ready (better memory profile, better first-row latency).

2. **ETL-style transforms**
   Wrap external data sources (files, web services, queues) or complex PL/SQL transforms so they’re composable in SQL and joinable with regular tables.

3. **Row-by-row generation**
   Expand JSON/XML payloads, split strings, pivot/unpivot custom formats, generate series, etc., then filter/join/order them in SQL.

4. **Parallelizable producers**
   With `PARALLEL_ENABLE`, the SQL engine can run multiple instances concurrently (partitioned input → multiple pipelines).

## Why they’re valuable (vs. returning a collection all at once)

* **Lower memory usage**: No need to `BULK COLLECT` the entire result before returning.
* **Faster time-to-first-row**: Results start flowing as soon as the first `PIPE ROW` fires.
* **Composability**: You can `JOIN`, `WHERE`, `ORDER BY`, and `WITH` them like any other table.
* **Backpressure-friendly**: If the consumer only fetches 100 rows, production stops there.

A non-pipelined version would have to do something like:

```sql
CREATE OR REPLACE FUNCTION f_emp_bulk(p_dept NUMBER)
  RETURN t_emp_tab
IS
  l_tab t_emp_tab := t_emp_tab();
BEGIN
  SELECT t_emp_row(empno, ename)
  BULK COLLECT INTO l_tab
  FROM emp
  WHERE deptno = p_dept;

  RETURN l_tab; -- nothing returned until everything is filled
END;
```

That’s simple but it materializes the full dataset.

## A more “industrial” pattern (chunking)

If your producer must do work that benefits from batching (e.g., file I/O or remote calls), combine `BULK COLLECT ... LIMIT` with `PIPE ROW`:

```sql
CREATE OR REPLACE FUNCTION f_emp_pipe_limit(p_dept NUMBER)
  RETURN t_emp_tab PIPELINED
IS
  CURSOR c IS
    SELECT empno, ename
    FROM emp
    WHERE deptno = p_dept;

  TYPE t_empbulk IS TABLE OF c%ROWTYPE;
  l_rows t_empbulk;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO l_rows LIMIT 1000;
    EXIT WHEN l_rows.COUNT = 0;

    FOR i IN 1..l_rows.COUNT LOOP
      PIPE ROW(t_emp_row(l_rows(i).empno, l_rows(i).ename));
    END LOOP;
  END LOOP;

  CLOSE c;
  RETURN;
END;
/
```

That pattern is great when each batch involves expensive transformation you’d like to amortize.

## Parallel pipelined table functions (optional superpower)

If you need throughput, you can allow the SQL engine to run the function in parallel by adding a `PARALLEL_ENABLE` clause and a partitioning scheme:

```sql
CREATE OR REPLACE FUNCTION f_emp_pipe_parallel(p_dept NUMBER)
  RETURN t_emp_tab PIPELINED
  PARALLEL_ENABLE(PARTITION p_dept BY ANY)
IS
BEGIN
  FOR r IN (SELECT empno, ename FROM emp WHERE deptno = p_dept) LOOP
    PIPE ROW(t_emp_row(r.empno, r.ename));
  END LOOP;
  RETURN;
END;
```

There are several partitioning options (`BY ANY`, `HASH`, etc.). With a proper design, the SQL engine can invoke multiple producers and merge their outputs.

## Practical tips

* **Types must be SQL types** (not just PL/SQL). You already did this by creating `OBJECT` and `TABLE` types.
* **No COMMIT/ROLLBACK** inside: functions invoked from SQL can’t perform transaction control. Keep side effects out or call them only from PL/SQL contexts where that’s allowed.
* **Make them pure transformers**: treat them like views-with-logic. That keeps plans stable and debugging sane.
* **Cardinality/optimizer**: the optimizer may guess row counts. If a plan looks odd, you can guide it with hints (e.g., `/*+ CARDINALITY(T 100000) */`) where `T` is the `TABLE(...)` alias.
* **Chaining**: you can `TABLE(f1(...)) JOIN TABLE(f2(...))` but beware of readability. Consider SQL macros or views if the chain gets long.
* **Compare alternatives**: sometimes a simple view, an inline `WITH` subquery, or JSON_TABLE can replace a custom function with less moving parts.

## A non-table example: reading external data

Here’s a sketch of a pipelined reader that streams lines from a directory object (for ETL-ish work):

```sql
CREATE OR REPLACE TYPE t_line AS OBJECT(line_no NUMBER, text VARCHAR2(4000));
/
CREATE OR REPLACE TYPE t_line_tab AS TABLE OF t_line;
/

CREATE OR REPLACE FUNCTION f_readfile_pipe(p_dir  IN VARCHAR2,
                                           p_file IN VARCHAR2)
  RETURN t_line_tab PIPELINED
IS
  l_file  UTL_FILE.file_type;
  l_text  VARCHAR2(4000);
  l_line  PLS_INTEGER := 0;
BEGIN
  l_file := UTL_FILE.fopen(p_dir, p_file, 'R');
  LOOP
    BEGIN
      UTL_FILE.get_line(l_file, l_text);
      l_line := l_line + 1;
      PIPE ROW(t_line(l_line, l_text));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN EXIT;
    END;
  END LOOP;
  UTL_FILE.fclose(l_file);
  RETURN;
END;
/
-- Then:
SELECT * FROM TABLE(f_readfile_pipe('DATA_DIR','input.txt')) WHERE line_no <= 100;
```

Notice how you can filter to the first 100 lines and the function will stop producing after that—no full read required.

---

**Bottom line:** Pipelined functions turn PL/SQL logic into a **streaming, table-like data source**. They shine when you need to generate or transform large result sets, integrate external sources, improve memory use and first-row latency, or parallelize custom producers—while keeping everything composable in SQL. Use them when a view isn’t expressive enough and a “return-the-whole-collection” function would be too chunky.


```yaml
---
id: docs/sql/oracle/80-pipelined-function.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, pipelined, table-function]
description: "Stream rows from PL/SQL as if they were a table using a pipelined function"
---
```