###### Oracle PL/SQL
### Collections + BULK COLLECT & FORALL — comprehensive patterns (19c)
Drop-in examples for every collection flavor and high-throughput bulk processing. Use `BULK COLLECT` to cut context switches on fetch; use `FORALL` for set DML.

---

## 0) Quick primer

- **Associative array (index-by)**: pure PL/SQL hash map (keys `PLS_INTEGER` or `VARCHAR2`), *not* SQL-visible. Great for lookups/dedup.
- **Nested table**: set-like; SQL-visible; can be sparse; use `TABLE()` to query.
- **VARRAY**: ordered, bounded array; stored inline; best when small, fixed-ish size.
- **BULK COLLECT**: fetch many rows into a collection (optionally `LIMIT`).
- **FORALL**: execute one DML per element with a *single* context switch (optionally `SAVE EXCEPTIONS`).

---

## 1) Associative arrays (index-by): integer & string keys

```sql
DECLARE
  -- Integer-keyed map
  TYPE t_int_map IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
  v_int t_int_map;

  -- String-keyed map (e.g., email → id)
  TYPE t_str_map IS TABLE OF NUMBER INDEX BY VARCHAR2(320);
  v_id_by_email t_str_map;

  k  PLS_INTEGER;
BEGIN
  -- Put/exists/delete
  v_int(10) := 'ten';
  IF v_int.EXISTS(10) THEN v_int.DELETE(10); END IF;

  v_id_by_email('ada@nc.gov') := 1001;
  v_id_by_email('grace@nc.gov') := 1002;

  -- Sparse traversal with FIRST/NEXT
  DECLARE c VARCHAR2(320); BEGIN
    c := v_id_by_email.FIRST;
    WHILE c IS NOT NULL LOOP
      DBMS_OUTPUT.PUT_LINE(c||' -> '||v_id_by_email(c));
      c := v_id_by_email.NEXT(c);
    END LOOP;
  END;
END;
/
````

**API reminders**: `EXISTS(k)`, `COUNT`, `FIRST/LAST`, `PRIOR/NEXT`, `DELETE`, `DELETE(k)`, `DELETE(m,n)`.

---

## 2) Nested tables: SQL-visible, set-like

```sql
-- SQL types (schema objects) so you can use TABLE(...) in SQL
CREATE OR REPLACE TYPE t_email_tab AS TABLE OF VARCHAR2(320);
/

-- PL/SQL: construct, de-dup via MULTISET, pass into SQL
DECLARE
  v_emails t_email_tab := t_email_tab('a@x','b@x','a@x'); -- duplicates allowed
  v_unique t_email_tab;
BEGIN
  -- Remove dups (multiset semantics)
  v_unique := SET(v_emails); -- or v_emails MULTISET UNION DISTINCT t_email_tab();

  -- Query with TABLE() – e.g., join to accounts
  FOR r IN (
    SELECT a.account_id, a.email
    FROM   accounts a
    JOIN   TABLE(v_unique) e ON e.COLUMN_VALUE = a.email
  ) LOOP
    NULL;
  END LOOP;
END;
/
```

**Common ops**: `EXTEND`, `TRIM`, `DELETE`, `COUNT`, `MULTISET UNION/INTERSECT/EXCEPT`, `SUBMULTISET OF`, `CARDINALITY()` (in SQL).

---

## 3) VARRAYs: ordered, bounded arrays

```sql
CREATE OR REPLACE TYPE t_code_arr AS VARRAY(10) OF VARCHAR2(20);
/

DECLARE
  v_codes t_code_arr := t_code_arr('A','B','C');
BEGIN
  v_codes.EXTEND; v_codes(v_codes.COUNT) := 'D';
  -- Use in SQL
  FOR r IN (
    SELECT COLUMN_VALUE AS code
    FROM   TABLE(v_codes)
    ORDER  BY 1
  ) LOOP NULL; END LOOP;
END;
/
```

**Notes**: VARRAYs have a max size; stored inline when used as a column type; great for small ordered lists.

---

## 4) Bulk fetch: `BULK COLLECT` (with and without `LIMIT`)

### 4a) Into a collection of scalars

```sql
DECLARE
  TYPE t_id_tab IS TABLE OF accounts.account_id%TYPE;
  v_ids t_id_tab;
BEGIN
  SELECT account_id BULK COLLECT INTO v_ids
  FROM   accounts
  WHERE  created_at >= SYSDATE - 7;

  DBMS_OUTPUT.PUT_LINE('#ids='||v_ids.COUNT);
END;
/
```

### 4b) Into a collection of records (`%ROWTYPE`) with `LIMIT` (streaming)

```sql
DECLARE
  CURSOR c IS SELECT account_id, email FROM accounts ORDER BY account_id;
  TYPE t_row_tab IS TABLE OF c%ROWTYPE;
  v_rows t_row_tab;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_rows LIMIT 500; -- tune batch size
    EXIT WHEN v_rows.COUNT = 0;

    FOR i IN 1..v_rows.COUNT LOOP
      NULL; -- process v_rows(i).account_id, v_rows(i).email
    END LOOP;

    COMMIT; -- optional batch boundary
  END LOOP;
  CLOSE c;
END;
/
```

---

## 5) `FORALL` DML: high-throughput set operations

> `FORALL` binds each element and executes the statement *once per element* but with a **single** context switch. Use with scalar collections (numbers, varchars). For records, keep parallel arrays (same subscripts).

### 5a) Update many by PK

```sql
DECLARE
  TYPE t_id_tab IS TABLE OF orders.order_id%TYPE;
  v_ids t_id_tab := t_id_tab(101,102,103,104);

BEGIN
  FORALL i IN v_ids.FIRST .. v_ids.LAST
    UPDATE orders
    SET    processed   = 'Y',
           processed_at = SYSTIMESTAMP
    WHERE  order_id = v_ids(i);

  COMMIT;
END;
/
```

### 5b) Insert many (parallel arrays) + `SAVE EXCEPTIONS`

```sql
DECLARE
  TYPE t_num IS TABLE OF NUMBER;
  TYPE t_vc  IS TABLE OF VARCHAR2(320);

  v_acct_id t_num := t_num(1001,1002,1003);
  v_email   t_vc  := t_vc ('a@x','b@x','a@x'); -- unique constraint may trip

BEGIN
  BEGIN
    FORALL i IN 1 .. v_acct_id.COUNT SAVE EXCEPTIONS
      INSERT INTO accounts(account_id, email) VALUES (v_acct_id(i), v_email(i));
  EXCEPTION
    WHEN OTHERS THEN
      FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(
          'i='||SQL%BULK_EXCEPTIONS(j).ERROR_INDEX||
          ' code='||SQL%BULK_EXCEPTIONS(j).ERROR_CODE||
          ' '||SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
  END;

  COMMIT;
END;
/
```

### 5c) Sparse collections with `INDICES OF` and named subranges

```sql
DECLARE
  TYPE t_id_tab IS TABLE OF NUMBER INDEX BY PLS_INTEGER; -- associative (sparse)
  v_ids t_id_tab;
BEGIN
  v_ids(10) := 1001;
  v_ids(40) := 1002; -- holes in between

  FORALL i IN INDICES OF v_ids
    DELETE FROM orders WHERE order_id = v_ids(i);

  COMMIT;
END;
/
```

### 5d) Use a **driver** collection of values (`VALUES OF`)

```sql
DECLARE
  TYPE t_index_tab IS TABLE OF PLS_INTEGER;  -- driver indexes
  TYPE t_id_tab    IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

  v_ids t_id_tab;
  v_ix  t_index_tab := t_index_tab(10,40);   -- which indexes to use
BEGIN
  v_ids(10) := 1001;
  v_ids(40) := 1002;

  FORALL i IN VALUES OF v_ix
    UPDATE orders SET processed='Y' WHERE order_id = v_ids(i);

  COMMIT;
END;
/
```

---

## 6) `RETURNING BULK COLLECT` — capture generated values

```sql
DECLARE
  TYPE t_ord_id IS TABLE OF orders.order_id%TYPE;
  v_new_ids t_ord_id;
BEGIN
  INSERT INTO orders(account_id, total_cents)
  SELECT a.account_id, 12345
  FROM   accounts a
  WHERE  a.email LIKE 'a%'
  RETURNING order_id BULK COLLECT INTO v_new_ids;

  DBMS_OUTPUT.PUT_LINE('#inserted='||v_new_ids.COUNT);
END;
/
```

---

## 7) Collections of objects/records for richer shapes

```sql
-- Object + collection types (SQL-visible)
CREATE OR REPLACE TYPE t_pair AS OBJECT (k NUMBER, v VARCHAR2(100));
/
CREATE OR REPLACE TYPE t_pair_tab AS TABLE OF t_pair;
/

DECLARE
  v_pairs t_pair_tab := t_pair_tab(t_pair(1,'a'), t_pair(2,'b'));
BEGIN
  -- Consume in SQL
  INSERT INTO some_table(pk, val)
  SELECT p.k, p.v FROM TABLE(v_pairs) p;

  -- Back to PL/SQL iteration
  FOR r IN (SELECT * FROM TABLE(v_pairs) ORDER BY k) LOOP
    NULL;
  END LOOP;
END;
/
```

---

## 8) Multiset operations & membership (nested table/varray)

```sql
DECLARE
  a t_email_tab := t_email_tab('a@x','b@x','c@x');
  b t_email_tab := t_email_tab('b@x','d@x');

  inter   t_email_tab;
  only_a  t_email_tab;
  union_d t_email_tab;
BEGIN
  inter   := a MULTISET INTERSECT DISTINCT b;  -- {'b@x'}
  only_a  := a MULTISET EXCEPT DISTINCT b;     -- {'a@x','c@x'}
  union_d := a MULTISET UNION DISTINCT b;      -- {'a@x','b@x','c@x','d@x'}

  IF b SUBMULTISET OF union_d THEN NULL; END IF;

  DBMS_OUTPUT.PUT_LINE('|a|='||CARDINALITY(a));
END;
/
```

---

## 9) Do/don’t and performance tips

* **Use `BULK COLLECT` + `LIMIT`** for big scans to cap PGA and keep response snappy (e.g., 500–5000).
* **Commit in batches** outside the cursor loop (or after each `FORALL`), not per row.
* **Prefer `FORALL`** for DML, not a `FOR` loop of single-row DML.
* **Associative arrays** are fastest for lookups but cannot be used directly in SQL (except via `INDICES/VALUES OF` in `FORALL`).
* **Nested tables/VARRAYs** are SQL-visible and work with `TABLE()`, `MULTISET`, `CARDINALITY`.
* **Parallel arrays** beat record collections for `FORALL`. Keep indexes aligned.
* **Error handling**: combine `SAVE EXCEPTIONS` + a log of `SQL%BULK_EXCEPTIONS` for resilient batches.
* **Memory**: `DELETE` large collections when done or let them go out of scope.

---

## 10) End-to-end: scan → transform → upsert at scale

```sql
DECLARE
  CURSOR c IS
    SELECT account_id, SUM(total_cents) AS cents
    FROM   orders
    WHERE  created_at >= SYSDATE - 30
    GROUP  BY account_id;

  TYPE t_acc   IS TABLE OF NUMBER;
  TYPE t_cents IS TABLE OF NUMBER;

  v_acc   t_acc;
  v_cents t_cents;
BEGIN
  -- Bulk fetch in chunks
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_acc, v_cents LIMIT 1000;
    EXIT WHEN v_acc.COUNT = 0;

    -- Upsert with FORALL (parallel scalar arrays)
    FORALL i IN 1 .. v_acc.COUNT
      MERGE INTO monthly_spend d
      USING (SELECT v_acc(i) AS account_id, v_cents(i) AS cents FROM dual) s
      ON (d.account_id = s.account_id AND d.month_key = TRUNC(SYSDATE,'MM'))
      WHEN MATCHED THEN
        UPDATE SET d.cents = s.cents
      WHEN NOT MATCHED THEN
        INSERT (account_id, month_key, cents)
        VALUES (s.account_id, TRUNC(SYSDATE,'MM'), s.cents);

    COMMIT;
  END LOOP;
  CLOSE c;
END;
/
```


```yaml
---
id: sql/oracle/plsql/collections-bulk-19c
lang: sql
platform: oracle
scope: plsql
since: "v0.9"
tested_on: "Oracle 19c"
tags: [plsql, collections, associative-array, nested-table, varray, bulk-collect, forall, save-exceptions, indices-of, values-of, table, multiset]
description: Collections in PL/SQL (index-by/associative arrays, nested tables, varrays) with practical BULK COLLECT & FORALL patterns: batching, sparse traversal, INDICES OF / VALUES OF, RETURNING BULK COLLECT, and using collections in SQL.
---
```