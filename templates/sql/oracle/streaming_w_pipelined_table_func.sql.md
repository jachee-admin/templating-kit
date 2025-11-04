
###### Oracle

## PL/SQL Collections - Streaming & Pipelined Table Functions

### 1) Tiny “generate_series” (scalar rows)

Use a built-in SQL collection type so we can return it directly from SQL.

```sql
-- uses built-in SQL type: SYS.ODCINUMBERLIST is TABLE OF NUMBER
CREATE OR REPLACE FUNCTION generate_series(
  p_start NUMBER,
  p_end   NUMBER,
  p_step  NUMBER DEFAULT 1
) RETURN SYS.ODCINUMBERLIST PIPELINED IS
  v NUMBER := p_start;
BEGIN
  IF p_step = 0 THEN
    RAISE_APPLICATION_ERROR(-20000, 'p_step cannot be zero');
  END IF;

  WHILE (p_step > 0 AND v <= p_end) OR (p_step < 0 AND v >= p_end) LOOP
    PIPE ROW (v);        -- emits one row at a time
    v := v + p_step;     -- no big array builds up
  END LOOP;
  RETURN;
END;
/

-- Use it like a table:
SELECT COLUMN_VALUE AS n
FROM   TABLE(generate_series(1, 10, 2));
```

### 2) Stream rows from a big table in chunks (record/object rows)

When returning multiple columns, define a SQL object type + SQL collection type. Fetch in batches (LIMIT) to cap PGA and pipe rows as you go.

```sql
-- SQL types visible to SQL (not package types)
CREATE OR REPLACE TYPE t_emp_obj AS OBJECT (
  empno NUMBER,
  ename VARCHAR2(100),
  sal   NUMBER
);
/
CREATE OR REPLACE TYPE t_emp_tab AS TABLE OF t_emp_obj;
/

CREATE OR REPLACE PACKAGE emp_tf AS
  FUNCTION stream_emp(p_min_sal NUMBER) RETURN t_emp_tab PIPELINED;
END emp_tf;
/
CREATE OR REPLACE PACKAGE BODY emp_tf AS
  FUNCTION stream_emp(p_min_sal NUMBER) RETURN t_emp_tab PIPELINED IS
    CURSOR c_emp IS
      SELECT empno, ename, sal
      FROM   emp
      WHERE  sal >= p_min_sal;

    TYPE t_chunk IS TABLE OF c_emp%ROWTYPE;
    v_chunk t_chunk;
  BEGIN
    OPEN c_emp;
    LOOP
      FETCH c_emp BULK COLLECT INTO v_chunk LIMIT 1000; -- stream in chunks
      EXIT WHEN v_chunk.COUNT = 0;

      FOR i IN 1 .. v_chunk.COUNT LOOP
        PIPE ROW ( t_emp_obj(v_chunk(i).empno, v_chunk(i).ename, v_chunk(i).sal) );
      END LOOP;
    END LOOP;
    CLOSE c_emp;
    RETURN;  -- required in pipelined functions
  END stream_emp;
END emp_tf;
/

-- Now you can join/filter/order in pure SQL, and Oracle pulls rows as they’re piped:
SELECT e.empno, e.ename, e.sal
FROM   TABLE(emp_tf.stream_emp(5000)) e
WHERE  e.ename LIKE 'A%'
ORDER  BY e.sal DESC;
```

### 3) Parameterized “list-in” filter without staging tables

Pass a list of IDs and stream back matching rows—handy for API inputs or UI filters.

```sql
-- Use built-in list type for the input too:
-- SYS.ODCINUMBERLIST (TABLE OF NUMBER)

CREATE OR REPLACE PACKAGE emp_tf2 AS
  FUNCTION by_empnos(p_empnos SYS.ODCINUMBERLIST) RETURN t_emp_tab PIPELINED;
END emp_tf2;
/
CREATE OR REPLACE PACKAGE BODY emp_tf2 AS
  FUNCTION by_empnos(p_empnos SYS.ODCINUMBERLIST) RETURN t_emp_tab PIPELINED IS
    CURSOR c_emp IS
      SELECT empno, ename, sal
      FROM   emp
      WHERE  empno IN (SELECT COLUMN_VALUE FROM TABLE(p_empnos));
    TYPE t_chunk IS TABLE OF c_emp%ROWTYPE;
    v_chunk t_chunk;
  BEGIN
    OPEN c_emp;
    LOOP
      FETCH c_emp BULK COLLECT INTO v_chunk LIMIT 1000;
      EXIT WHEN v_chunk.COUNT = 0;
      FOR i IN 1 .. v_chunk.COUNT LOOP
        PIPE ROW ( t_emp_obj(v_chunk(i).empno, v_chunk(i).ename, v_chunk(i).sal) );
      END LOOP;
    END LOOP;
    CLOSE c_emp;
    RETURN;
  END;
END emp_tf2;
/

-- Usage:
SELECT *
FROM   TABLE(emp_tf2.by_empnos(SYS.ODCINUMBERLIST(7369, 7499, 7521)));
```

### Practical notes (the interview ammo)

* **Return SQL types, not package types.** SQL must “see” the object/collection type.
* **Streaming ≠ buffering.** The `BULK COLLECT … LIMIT` + `PIPE ROW` loop bounds memory use while keeping throughput high.
* **Composability.** You can join, filter, sort, aggregate the piped rows in the outer SQL; predicate pushdown still applies to the inner cursor where possible.
* **No commits.** Don’t `COMMIT/ROLLBACK` inside table functions; treat them as query producers.
* **Diagnostics.** Wrap your inner loop with `PRAGMA UDF` (if on a supported release) for tiny scalar helpers; keep the function pure to aid caching and parallel plans.
