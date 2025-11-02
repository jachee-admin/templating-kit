###### Oracle PL/SQL
# Forall Indicies of / Values of

“**INDICES OF**” is a `FORALL` modifier that tells PL/SQL: *iterate over the actual index values present in a (usually sparse) PL/SQL collection*, not over a simple `1..N` range.

It has **nothing** to do with database indexes on a table. “Indices” here are the **subscripts of your PL/SQL collection** (associative array, nested table, or varray). Your table doesn’t need any DB index for `INDICES OF` to work—though a real B-tree index on `emp.empno` can make the `UPDATE` run faster. Different thing.

### Why use `INDICES OF`?

* Standard `FORALL i IN 1..l_tab.COUNT` assumes a **dense** collection (every position exists).
* Real life often gives you **sparse** collections (holes). `INDICES OF` safely iterates **only the existing subscripts**.

### Your pattern, explained

```plsql
DECLARE
  TYPE t_ids IS TABLE OF emp.empno%TYPE INDEX BY PLS_INTEGER; -- associative array
  l_ids     t_ids;      -- maybe holds data you’ll use (e.g., empnos)
  valid_idx t_ids;      -- its *keys* mark which entries to process (sparse ok)
BEGIN
  -- imagine you populated valid_idx(101), valid_idx(205), valid_idx(9999) only

  FORALL i IN INDICES OF valid_idx SAVE EXCEPTIONS
    UPDATE emp
       SET sal = sal * 1.05
     WHERE empno = valid_idx(i);

  -- optional bulk error handling
  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Error at iteration '||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
                             ' ORA-'||SQL%BULK_EXCEPTIONS(j).ERROR_CODE);
      END LOOP;
      RAISE;
END;
```

* The loop variable `i` takes on the **actual existing subscripts** of `valid_idx` (e.g., 101, 205, 9999 if those are the keys you set).
* Inside the DML you reference the element `valid_idx(i)`—that value becomes the bind for `empno`.

### Siblings: `VALUES OF`

There’s a second variant for when you have a **list of subscripts** stored in another collection.

```plsql
DECLARE
  TYPE t_ints IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;

  TYPE t_empnos IS TABLE OF emp.empno%TYPE INDEX BY PLS_INTEGER;
  l_empnos t_empnos;  -- data array, sparse: keys are meaningful (e.g., actual IDs)

  l_keys   t_ints;    -- *subscripts* to process, e.g., (1=>101, 2=>205, 3=>9999)
BEGIN
  -- populate l_empnos(101)=101, l_empnos(205)=205, ...
  -- populate l_keys(1)=101, l_keys(2)=205, l_keys(3)=9999

  FORALL j IN VALUES OF l_keys
    DELETE FROM emp
     WHERE empno = l_empnos(j); -- j are the subscripts pulled from l_keys’ values
END;
```

Use **`INDICES OF`** when the *keys of the control collection* are the iterations you want.
Use **`VALUES OF`** when another collection holds the *list of subscripts* to use.

### What collections work?

* `FORALL` supports associative arrays (indexed by `PLS_INTEGER`/`BINARY_INTEGER`), nested tables, and varrays.
* `INDICES OF`/`VALUES OF` are most useful for **associative arrays**, which can be sparse. Nested tables/varrays are naturally dense (1..COUNT), so a plain `FORALL i IN 1..coll.COUNT` usually suffices.

### Bounds filter (optional)

You can clip to a range if desired:

```plsql
FORALL i IN INDICES OF valid_idx BETWEEN 100 AND 999
  ...
```

### Quick performance note

`FORALL` is about **bulk binds** (fewer context switches). Whether the table has a database index is a **separate** query-planning concern:

* If your predicate is `WHERE empno = :b1`, an index on `emp(empno)` can make each lookup faster, but `FORALL` will still work without it.
* If many rows are touched, a full scan might be cheaper anyway—the optimizer decides.

### What is `ANYDATA` (since you mentioned it earlier)?

`ANYDATA` is an Oracle **generic wrapper for a single SQL value** (stores the value + its type). Handy when writing generic code (e.g., with `DBMS_SQL`) where column types aren’t known until runtime. It’s unrelated to `INDICES OF` and `FORALL`—different feature for different problems.

**Bottom line:** `INDICES OF` iterates over the **existing keys of a PL/SQL collection** so you can bulk-DML sparse sets cleanly. It doesn’t care about database indexes; it speaks “collection subscripts,” not “B-trees.”
```yaml
---
id: templates/sql/oracle/380-forall-indicies-of-values-of.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.3"
tested_on: "Oracle 19c"
tags: [plsql, forall, values of, indicies ofvariables, constants, datatypes]
description: "Examples of forall variations."
---
```