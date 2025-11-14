###### Oracle PL/SQL

### Mini-recipes

### Pagination fetch (LIMIT-like)

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp.empno%TYPE;
  l_ids t_emp;
  v_last_id NUMBER := 0;
BEGIN
  LOOP
    SELECT empno BULK COLLECT INTO l_ids
    FROM emp
    WHERE empno > v_last_id
    ORDER BY empno
    FETCH FIRST 100 ROWS ONLY;

    EXIT WHEN l_ids.COUNT = 0;
    v_last_id := l_ids(l_ids.LAST);
    -- process batch...
  END LOOP;
END;
/
```

### Audit on change (row-level)

```sql
CREATE OR REPLACE TRIGGER emp_audit_trg
AFTER UPDATE OF sal ON emp
FOR EACH ROW
BEGIN
  INSERT INTO emp_audit(empno, old_sal, new_sal, ts)
  VALUES (:NEW.empno, :OLD.sal, :NEW.sal, SYSTIMESTAMP);
END;
/
```

### Safe “upsert list” with FORALL

```sql
DECLARE
  TYPE t_emp IS TABLE OF emp%ROWTYPE;
  l_rows t_emp;
BEGIN
  SELECT * BULK COLLECT INTO l_rows FROM staging_emp;

  FORALL i IN l_rows.FIRST..l_rows.LAST
    MERGE INTO emp t
    USING (SELECT l_rows(i).empno empno,
                  l_rows(i).ename ename,
                  l_rows(i).sal   sal
             FROM dual) s
      ON (t.empno = s.empno)
    WHEN MATCHED THEN UPDATE SET t.sal = s.sal, t.ename = s.ename
    WHEN NOT MATCHED THEN INSERT (empno, ename, sal)
                         VALUES (s.empno, s.ename, s.sal);
END;
/
```

---

## 15) Quick tables

### Cursor attributes

| Attribute | Meaning |
| --- | --- |
| `SQL%ROWCOUNT` | Rows affected by last DML/SELECT INTO |
| `SQL%FOUND` / `NOTFOUND` | True if ≥1 row / 0 rows |
| `SQL%ISOPEN` | Always FALSE for implicit cursor |

### Collection types

| Type | Indexing | DB column? | Notes |
| --- | --- | --- | --- |
| Associative array | PLS\_INTEGER / VARCHAR2 key | No  | In-memory map; fastest for lookups |
| Nested table | Dense, unbounded | Yes | Use `TABLE()` to query |
| VARRAY | Dense, bounded | Yes | Preserves order; size limit |

### Common exceptions

| Name | ORA | Meaning |
| --- | --- | --- |
| `NO_DATA_FOUND` | 01403 | SELECT INTO found no row |
| `TOO_MANY_ROWS` | 01422 | SELECT INTO returned >1 |
| `DUP_VAL_ON_INDEX` | 00001 | Unique/PK violation |
| `ZERO_DIVIDE` | 01476 | Divide by zero |
| `VALUE_ERROR` | 06502 | Conversion/overflow |

```yaml
---
id: docs/sql/oracle/330-tables-recipes.sql.md
lang: sql
platform: oracle
scope: recipes and tables, info help
since: "v0.1"
tested_on: "Oracle 19c"
tags: [help, recipes, tables, info]
description: ""
---
```