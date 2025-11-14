###### Oracle PL/SQL

### Dynamic SQL — EXECUTE IMMEDIATE vs DBMS_SQL (Oracle 19c)

Practical patterns with secure, bind-first code. Use EXECUTE IMMEDIATE for 90% of cases; drop to DBMS_SQL for truly dynamic column counts/shapes.

---

## 1) EXECUTE IMMEDIATE — bread-and-butter patterns

### 1.1) Dynamic DDL (schema and object names whitelisted)

```sql
DECLARE
  p_owner  VARCHAR2(30) := 'APP';
  p_table  VARCHAR2(30) := 'ACCOUNTS';
  p_col    VARCHAR2(30) := 'PREFS_JSON';
  p_stmt   VARCHAR2(4000);
BEGIN
  -- Harden object identifiers
  p_owner := DBMS_ASSERT.SIMPLE_SQL_NAME(p_owner);
  p_table := DBMS_ASSERT.SIMPLE_SQL_NAME(p_table);
  p_col   := DBMS_ASSERT.SIMPLE_SQL_NAME(p_col);

  p_stmt := 'ALTER TABLE '||p_owner||'.'||p_table||' ADD ('||p_col||' CLOB CHECK ('||p_col||' IS JSON))';
  EXECUTE IMMEDIATE p_stmt;
END;
/
```

### 1.2) Dynamic DML with binds (IN / OUT / IN OUT) + RETURNING

```sql
DECLARE
  v_sql   VARCHAR2(4000) := 'UPDATE accounts SET full_name = :1, updated_at = SYSTIMESTAMP WHERE email = :2 RETURNING account_id INTO :3';
  v_id    NUMBER;
BEGIN
  EXECUTE IMMEDIATE v_sql USING 'Ada Byron', 'ada@nc.gov' RETURNING INTO v_id;
  DBMS_OUTPUT.PUT_LINE('updated id='||v_id);
END;
/
```

### 1.3) OPEN FOR (REF CURSOR) — dynamic SELECT, fixed shape known at compile time

```sql
DECLARE
  rc   SYS_REFCURSOR;
  v_id NUMBER; v_email VARCHAR2(320);
  p_sql VARCHAR2(4000) := 'SELECT account_id, email FROM accounts WHERE created_at >= :1 ORDER BY 1';
BEGIN
  OPEN rc FOR p_sql USING SYSDATE - 30;
  LOOP
    FETCH rc INTO v_id, v_email; EXIT WHEN rc%NOTFOUND;
    NULL; -- use v_id, v_email
  END LOOP;
  CLOSE rc;
END;
/
```

### 1.4) BULK COLLECT from dynamic SQL

```sql
DECLARE
  TYPE t_num IS TABLE OF NUMBER;
  TYPE t_vc  IS TABLE OF VARCHAR2(320);
  v_ids t_num; v_emails t_vc;
BEGIN
  EXECUTE IMMEDIATE
    'SELECT account_id, email FROM accounts WHERE email LIKE :1'
    BULK COLLECT INTO v_ids, v_emails
    USING 'a%';
  DBMS_OUTPUT.PUT_LINE('#rows='||v_ids.COUNT);
END;
/
```

### 1.5) Dynamic PL/SQL block with IN/OUT binds

```sql
DECLARE
  v_out VARCHAR2(100);
BEGIN
  EXECUTE IMMEDIATE q'[
    DECLARE
      p_in  VARCHAR2(100) := :in1;
      p_out VARCHAR2(100);
    BEGIN
      p_out := UPPER(p_in);
      :out1 := p_out;
    END; ]'
  USING IN  'hello', OUT v_out;
  DBMS_OUTPUT.PUT_LINE(v_out); -- HELLO
END;
/
```

---

## 2) DBMS_SQL — when the shape is unknown at compile time

> Choose **DBMS_SQL** if you don’t know the number/types of columns until runtime (ad-hoc SELECT *), need to **describe** columns, or must handle **very wide** dynamic statements programmatically.

### 2.1) Generic SELECT * reader (describe, fetch by column id)

```sql
DECLARE
  c           INTEGER;
  col_cnt     INTEGER;
  desc_tab    DBMS_SQL.DESC_TAB2;
  v_num_rows  INTEGER;
  v_vc   VARCHAR2(4000);
  v_num  NUMBER;
  v_date DATE;
  any_val VARCHAR2(4000);

  p_sql VARCHAR2(4000) := 'SELECT * FROM accounts WHERE created_at >= :dt ORDER BY 1';
BEGIN
  c := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(c, p_sql, DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':dt', SYSDATE - 30);

  DBMS_SQL.DESCRIBE_COLUMNS2(c, col_cnt, desc_tab);

  -- Define columns generically (simple demo: map common types to generic vars)
  FOR i IN 1..col_cnt LOOP
    CASE desc_tab(i).col_type
      WHEN DBMS_SQL.VARCHAR2_TYPE THEN DBMS_SQL.DEFINE_COLUMN(c, i, v_vc, 4000);
      WHEN DBMS_SQL.NUMBER_TYPE   THEN DBMS_SQL.DEFINE_COLUMN(c, i, v_num);
      WHEN DBMS_SQL.DATE_TYPE     THEN DBMS_SQL.DEFINE_COLUMN(c, i, v_date);
      ELSE DBMS_SQL.DEFINE_COLUMN(c, i, v_vc, 4000); -- fallback as string
    END CASE;
  END LOOP;

  v_num_rows := DBMS_SQL.EXECUTE(c);

  WHILE DBMS_SQL.FETCH_ROWS(c) > 0 LOOP
    -- Example: print first two columns regardless of type
    DBMS_SQL.COLUMN_VALUE(c, 1, any_val);
    DBMS_SQL.COLUMN_VALUE(c, 2, v_vc);
    NULL; -- do something with values
  END LOOP;

  DBMS_SQL.CLOSE_CURSOR(c);
EXCEPTION WHEN OTHERS THEN
  IF DBMS_SQL.IS_OPEN(c) THEN DBMS_SQL.CLOSE_CURSOR(c); END IF; RAISE;
END;
/
```

### 2.2) Turning a DBMS_SQL cursor into a REF CURSOR

```sql
DECLARE
  c  INTEGER;
  rc SYS_REFCURSOR;
BEGIN
  c := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(c, 'SELECT account_id, email FROM accounts WHERE email LIKE :x', DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':x', 'a%');
  rc := DBMS_SQL.TO_REFCURSOR(c);
  -- From here, consume rc as a normal ref cursor…
  CLOSE rc; -- (when done)
END;
/
```

### 2.3) Dynamic DML with DBMS_SQL (rarely needed, supported)

```sql
DECLARE
  c INTEGER;
BEGIN
  c := DBMS_SQL.OPEN_CURSOR;
  DBMS_SQL.PARSE(c, 'DELETE FROM orders WHERE created_at < :cut', DBMS_SQL.NATIVE);
  DBMS_SQL.BIND_VARIABLE(c, ':cut', SYSTIMESTAMP - INTERVAL '90' DAY);
  DBMS_SQL.EXECUTE(c);
  DBMS_SQL.CLOSE_CURSOR(c);
END;
/
```

---

## 3) Security — prevent SQL injection (critical)

* **Always bind values**, never concatenate user input into SQL text.

* **Whitelist identifiers** (schema/table/column), validate with `DBMS_ASSERT`:
  
  * `SIMPLE_SQL_NAME`, `SCHEMA_NAME`, `QUALIFIED_SQL_NAME`, `ENQUOTE_NAME`.

* Avoid passing full WHERE clauses from outside; instead map **known filters** to fragments server-side.

* Prefer **EXECUTE IMMEDIATE with binds**; only use DBMS_SQL when you truly must.

* Log the **normalized** statement (with placeholders), not values.

---

## 4) Feature matrix — choose wisely

| Capability                                | EXECUTE IMMEDIATE (NDS) | DBMS_SQL                          |
| ----------------------------------------- | ----------------------- | --------------------------------- |
| DDL/DML with binds                        | ✅ (simple)              | ✅                                 |
| `RETURNING INTO`                          | ✅                       | ❌ (work around by SELECT after)   |
| `BULK COLLECT` into collections           | ✅                       | ❌ (manual loops only)             |
| `OPEN FOR` dynamic SELECT                 | ✅ (fixed target list)   | ✅ (any shape; use `TO_REFCURSOR`) |
| Describe unknown columns                  | ❌                       | ✅ (`DESCRIBE_COLUMNS2`)           |
| Best performance / least boilerplate      | ✅                       | ❌ (heavier)                       |
| Dynamic PL/SQL blocks                     | ✅                       | (possible but awkward)            |
| Fine control over fetch/define per column | ⚠️ limited              | ✅                                 |

**Rule of thumb:**

* Use **EXECUTE IMMEDIATE** for: dynamic DDL, DML with binds, dynamic queries with known columns, `RETURNING`, `BULK COLLECT`, and ref cursors with fixed projection.
* Use **DBMS_SQL** for: truly **ad-hoc** queries (unknown number/types of columns), metadata-driven tools, or when you must **describe** and fetch generically.

---

## 5) Gotchas & tips

* `USING` bind order matters (`:1, :2 …`) — prefer **named binds** only with `DBMS_SQL`; NDS uses positional binds.
* `RETURNING INTO` works only with **NDS**. For multiple rows, use **`RETURNING BULK COLLECT`**.
* For dynamic object names, **quote identifiers** safely: `DBMS_ASSERT.ENQUOTE_NAME(name, FALSE)` (second arg = case-sensitive).
* Keep dynamic SQL strings short and readable; use `q'[ ... ]'` quoting to avoid escaping hell.
* For performance testing, compare plans with `DBMS_XPLAN.DISPLAY_CURSOR` after running dynamic statements (use `/*+ GATHER_PLAN_STATISTICS */`).
* Transaction semantics are unaffected: dynamic SQL runs in the caller’s transaction (unless you explicitly use an autonomous block).

---

```yaml
---
id: templates/sql/oracle/210-dynamic_sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.10"
tested_on: "Oracle 19c"
tags: [plsql, dynamic-sql, execute-immediate, dbms_sql, ref-cursor, returning, bulk-collect, binds, dbms_assert]
description: "Dynamic SQL in 19c: EXECUTE IMMEDIATE (native dynamic SQL) vs DBMS_SQL. Safe patterns for DDL/DML/queries, binds (IN/OUT/IN OUT), RETURNING INTO, BULK COLLECT, REF CURSORs, and robust SQL injection defenses."
---
```