###### Oracle

## PL/SQL Collections - Best Practices

**1) Choose the right collection**

* **Associative array** (in-memory lookups/caches): fastest for procedural work. Prefer `PLS_INTEGER` keys for speed; use `VARCHAR2` keys for dictionary-style maps. Not SQL-friendly.
* **Nested table** (talks to SQL): use when you need `SELECT … FROM TABLE(col)` or to pass sets into SQL/procedures. Can be sparse; can be stored in columns if you define a SQL type.
* **VARRAY** (small, ordered, bounded): good when you truly have a natural max size and need order preserved in storage or across calls.

**2) Define types at the right level**

* If you need to use the collection in SQL (e.g., `TABLE()` or column types), **create a SQL schema-level type**:
  
  ```sql
  CREATE TYPE t_num_tab AS TABLE OF NUMBER;
  ```
  
  Package-only types are invisible to SQL.

**3) Bulk processing patterns (speed wins)**

* Fetch many rows once:
  
  ```plsql
  SELECT col BULK COLLECT INTO v_tab FROM t WHERE ...;
  ```
  
  Use `LIMIT` with cursor loops to cap memory:
  
  ```plsql
  LOOP
    FETCH c BULK COLLECT INTO v_tab LIMIT 10_000;
    EXIT WHEN v_tab.COUNT = 0;
    FORALL i IN 1..v_tab.COUNT SAVE EXCEPTIONS
      INSERT INTO t2 VALUES (v_tab(i));
  END LOOP;
  ```

* Use `FORALL` for DML on many rows; combine with `SAVE EXCEPTIONS` and inspect `SQL%BULK_EXCEPTIONS`.

* Prefer **index-by `PLS_INTEGER`** for working sets you don’t push into SQL; they’re lighter and faster than NUMBER/BINARY_INTEGER.

**4) Interop with SQL cleanly**

* To filter with an in-memory list, prefer a **SQL type + nested table**:
  
  ```plsql
  DECLARE
    v_ids t_num_tab := t_num_tab(10,20,30);
  BEGIN
    SELECT * FROM emp WHERE empno IN (SELECT COLUMN_VALUE FROM TABLE(v_ids));
  END;
  ```

* Need distinct/union/minus on collections? Use **multiset operators** on nested tables:
  
  ```plsql
  v_out := SET(v_a MULTISET UNION DISTINCT v_b);
  ```

**5) Ordering and sparsity—know the rules**

* **Associative arrays**: sparse; no guaranteed “natural” order. Iterate with `FIRST/NEXT`:
  
  ```plsql
  i := v.FIRST; WHILE i IS NOT NULL LOOP ...; i := v.NEXT(i); END LOOP;
  ```

* **Nested tables**: can become sparse after `DELETE`. If you care about position, **CAST to SQL and `ORDER BY ROWNUM`** or rebuild.

* **VARRAYs**: always dense and ordered; you can’t `DELETE(i)`. Use `EXTEND/TRIM`.

**6) Initialization & nulls**

* Always initialize before use:
  
  ```plsql
  v := t_tab_type();                    -- empty
  v := t_tab_type(1,2,3);               -- constructor
  ```

* `v.COUNT` is 0 for an empty collection; `v.EXISTS(i)` guards against `NO_DATA_FOUND` on gaps.

* Avoid storing `NULL` elements unless you really need “hole means known-null”; empty is usually cleaner.

**7) Memory hygiene**

* Massive `BULK COLLECT` can spike PGA. Use `LIMIT`, reuse the same variable to let memory be reused, and `TRIM` large varrays when done.
* For huge key/value caches, consider **associative array of records** (or packed scalars) to minimize per-element overhead.

**8) Records + collections = tidy APIs**

* Prefer **“table of record”** types for multi-column payloads:
  
  ```plsql
  TYPE r_emp IS RECORD (id NUMBER, sal NUMBER);
  TYPE t_emp IS TABLE OF r_emp INDEX BY PLS_INTEGER;
  ```
  
  This keeps `FORALL`/`BULK COLLECT` code readable and reduces parameter sprawl.

**9) Robust `FORALL` indexing**

* Use `INDICES OF` / `VALUES OF` to handle sparse collections safely:
  
  ```plsql
  FORALL i IN INDICES OF v_ids
    UPDATE emp SET sal = sal*1.1 WHERE empno = v_ids(i);
  ```
  
  Or load a dense index table and use `VALUES OF`.

**10) Exceptions & diagnostics**

* With bulk DML:
  
  ```plsql
  BEGIN
    FORALL i IN 1..v.COUNT SAVE EXCEPTIONS
      INSERT INTO t VALUES (v(i));
  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1..SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Row '||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
                             ' -> '||SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
      RAISE;
  END;
  ```

**11) Don’t overuse VARRAYs**

* The max size is part of the type; changing it later ripples schema changes. Only pick varrays when a real upper bound is part of the domain. Use a constant to document intent:
  
  ```plsql
  CREATE OR REPLACE PACKAGE consts AS Max_Tags CONSTANT PLS_INTEGER := 10; END;
  CREATE TYPE t_tags AS VARRAY(consts.Max_Tags) OF VARCHAR2(50); -- if allowed in your version
  ```

**12) Pipelined functions for streaming**

* When “set from PL/SQL to SQL” is large, consider **pipelined table functions** to stream rows instead of materializing whole collections.
