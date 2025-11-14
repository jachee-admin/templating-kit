###### Oracle PL/SQL
### Packages, Procedures & Functions — the exhaustive variations (Oracle 19c)
Canonical snippets showing the legit ways to shape subprograms in 19c. Mix & match. (Most are minimal but real.)

---

## A) Packages — shapes & options

### A1) Basic package with public constants/types + private helpers
```sql
CREATE OR REPLACE PACKAGE acct_api AS
  c_version  CONSTANT VARCHAR2(10) := '1.0';
  SUBTYPE t_email IS VARCHAR2(320);
  TYPE t_id_tab IS TABLE OF NUMBER;

  PROCEDURE create_account(p_email IN t_email, p_name IN VARCHAR2);
  FUNCTION  exists(p_email IN t_email) RETURN BOOLEAN;
END acct_api;
/

CREATE OR REPLACE PACKAGE BODY acct_api AS
  -- private helper
  FUNCTION norm_email(p IN t_email) RETURN t_email IS
  BEGIN
    RETURN LOWER(TRIM(p));
  END;

  PROCEDURE create_account(p_email IN t_email, p_name IN VARCHAR2) IS
  BEGIN
    INSERT INTO accounts(email, full_name) VALUES (norm_email(p_email), p_name);
  END;

  FUNCTION exists(p_email IN t_email) RETURN BOOLEAN IS
    v NUMBER;
  BEGIN
    SELECT 1 INTO v FROM accounts WHERE email = norm_email(p_email);
    RETURN TRUE;
  EXCEPTION WHEN NO_DATA_FOUND THEN RETURN FALSE;
  END;
END acct_api;
/
````

### A2) Package initialization block (runs once per session)

```sql
CREATE OR REPLACE PACKAGE env_pkg AS
  g_user  VARCHAR2(128);
  FUNCTION user_name RETURN VARCHAR2;
END env_pkg;
/

CREATE OR REPLACE PACKAGE BODY env_pkg AS
  FUNCTION user_name RETURN VARCHAR2 IS BEGIN RETURN g_user; END;
BEGIN
  g_user := SYS_CONTEXT('USERENV','SESSION_USER'); -- init section
END env_pkg;
/
```

### A3) Invoker rights vs definer rights

```sql
-- Default is DEFINER rights (uses owner’s privileges)
CREATE OR REPLACE PACKAGE def_pkg AUTHID DEFINER AS
  PROCEDURE p;
END def_pkg;
/

-- Invoker rights (uses caller’s privileges; good for shared utilities)
CREATE OR REPLACE PACKAGE inv_pkg AUTHID CURRENT_USER AS
  PROCEDURE p;
END inv_pkg;
/
```

### A4) `SERIALLY_REUSABLE` (stateless package state for pooled sessions)

```sql
CREATE OR REPLACE PACKAGE cache_pkg IS
  PRAGMA SERIALLY_REUSABLE;
  g_hits NUMBER := 0;
  PROCEDURE bump;
END cache_pkg;
/
CREATE OR REPLACE PACKAGE BODY cache_pkg IS
  PRAGMA SERIALLY_REUSABLE;
  PROCEDURE bump IS BEGIN g_hits := g_hits + 1; END;
END cache_pkg;
/
```

### A5) Restrict who can call into the package (`ACCESSIBLE BY`)

```sql
CREATE OR REPLACE PACKAGE secure_api
  ACCESSIBLE BY (PACKAGE order_api, PROCEDURE public_entry)
AS
  PROCEDURE secret_op;
END secure_api;
/
```

### A6) Overloading (same name, different signatures)

```sql
CREATE OR REPLACE PACKAGE math_api AS
  FUNCTION sum(p_a IN NUMBER, p_b IN NUMBER) RETURN NUMBER;
  FUNCTION sum(p_vals IN sys.odcinumberlist) RETURN NUMBER;
END math_api;
/
```

---

## B) Procedures — all variations

### B1) Standalone procedure (no package)

```sql
CREATE OR REPLACE PROCEDURE ping IS
BEGIN
  DBMS_OUTPUT.PUT_LINE('pong');
END;
/
```

### B2) Parameters: `IN`, `OUT`, `IN OUT` + defaults + named notation

```sql
CREATE OR REPLACE PROCEDURE add_user(
  p_email   IN  VARCHAR2,
  p_name    IN  VARCHAR2 DEFAULT NULL,
  p_user_id OUT NUMBER
) IS
BEGIN
  INSERT INTO users(email, full_name) VALUES (p_email, p_name)
  RETURNING user_id INTO p_user_id;
END;
/
-- call with named args
DECLARE v_id NUMBER; BEGIN add_user(p_email=>'x@nc.gov', p_user_id=>v_id); END; /
```

### B3) `NOCOPY` (performance hint for OUT/IN OUT large params)

```sql
CREATE OR REPLACE PROCEDURE fill_big(p_data OUT NOCOPY CLOB) IS
BEGIN
  p_data := RPAD('x', 1000000, 'x');
END;
/
```

### B4) `AUTHID` on a procedure (definer/invoker rights)

```sql
CREATE OR REPLACE PROCEDURE list_my_tables AUTHID CURRENT_USER IS
BEGIN
  FOR r IN (SELECT table_name FROM user_tables ORDER BY 1) LOOP
    DBMS_OUTPUT.PUT_LINE(r.table_name);
  END LOOP;
END;
/
```

### B5) `PRAGMA AUTONOMOUS_TRANSACTION` (durable side-effects)

```sql
CREATE OR REPLACE PROCEDURE log_msg(p_text IN CLOB) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO log_event(level,msg) VALUES('INFO', p_text);
  COMMIT;
END;
/
```

### B6) Procedure returning a cursor (`OUT SYS_REFCURSOR`)

```sql
CREATE OR REPLACE PROCEDURE get_orders(p_account_id IN NUMBER, p_rc OUT SYS_REFCURSOR) IS
BEGIN
  OPEN p_rc FOR
    SELECT order_id, total_cents FROM orders WHERE account_id = p_account_id ORDER BY 1;
END;
/
```

### B7) Overloaded procedures (arity/types)

```sql
CREATE OR REPLACE PACKAGE notify AS
  PROCEDURE send(p_to IN VARCHAR2, p_msg IN CLOB);
  PROCEDURE send(p_to IN sys.odcivarchar2list, p_msg IN CLOB);
END notify;
/
```

### B8) Forward declaration (mutual recursion inside a package body)

```sql
CREATE OR REPLACE PACKAGE BODY rec_pkg AS
  PROCEDURE a(n IN PLS_INTEGER); -- forward decl
  PROCEDURE b(n IN PLS_INTEGER) IS BEGIN IF n>0 THEN a(n-1); END IF; END;
  PROCEDURE a(n IN PLS_INTEGER) IS BEGIN IF n>0 THEN b(n-1); END IF; END;
END rec_pkg;
/
```

---

## C) Functions — all variations

### C1) Simple scalar function

```sql
CREATE OR REPLACE FUNCTION add_tax(p_amount IN NUMBER) RETURN NUMBER IS
BEGIN
  RETURN p_amount * 1.075;
END;
/
```

### C2) Functions with `OUT`/`IN OUT` (allowed, but avoid in SQL)

```sql
CREATE OR REPLACE FUNCTION f_with_out(p_in IN NUMBER, p_out OUT NUMBER) RETURN NUMBER IS
BEGIN
  p_out := p_in*2;
  RETURN p_in+1;
END;
/
```

### C3) `DETERMINISTIC` (same inputs → same output)

```sql
CREATE OR REPLACE FUNCTION normalize_email(p_email IN VARCHAR2)
  RETURN VARCHAR2 DETERMINISTIC
IS
BEGIN
  RETURN LOWER(TRIM(p_email));
END;
/
```

### C4) `RESULT_CACHE` (cache by arguments; great for ref data)

```sql
CREATE OR REPLACE FUNCTION country_name(p_id IN NUMBER)
  RETURN VARCHAR2 RESULT_CACHE RELIES_ON (countries)
IS
  v VARCHAR2(64);
BEGIN
  SELECT name INTO v FROM countries WHERE id = p_id;
  RETURN v;
END;
/
```

### C5) `PRAGMA UDF` (optimize for SQL-callable scalar UDF)

```sql
CREATE OR REPLACE FUNCTION fast_len(p IN VARCHAR2) RETURN PLS_INTEGER IS
  PRAGMA UDF;
BEGIN
  RETURN LENGTH(p);
END;
/
```

### C6) Pipelined table function (stream rows)

```sql
CREATE OR REPLACE TYPE t_num_row  AS OBJECT (n NUMBER);
/
CREATE OR REPLACE TYPE t_num_tab  AS TABLE OF t_num_row;
/
CREATE OR REPLACE FUNCTION series(p_from NUMBER, p_to NUMBER)
  RETURN t_num_tab PIPELINED
IS
BEGIN
  FOR i IN p_from..p_to LOOP
    PIPE ROW (t_num_row(i));
  END LOOP;
  RETURN;
END;
/
-- SELECT * FROM TABLE(series(1,5));
```

### C7) Pipelined with `PARALLEL_ENABLE` (partitioned, if inputs allow)

```sql
CREATE OR REPLACE FUNCTION series_parallel(p_to NUMBER)
  RETURN t_num_tab PIPELINED PARALLEL_ENABLE (PARTITION p_to BY ANY)
IS
BEGIN
  FOR i IN 1..p_to LOOP PIPE ROW (t_num_row(i)); END LOOP; RETURN;
END;
/
```

### C8) Function returning object/collection

```sql
CREATE OR REPLACE FUNCTION emails_for_domain(p_domain IN VARCHAR2)
  RETURN sys.odcivarchar2list
IS
  res sys.odcivarchar2list := sys.odcivarchar2list();
  i   PLS_INTEGER := 0;
BEGIN
  FOR r IN (SELECT email FROM accounts WHERE email LIKE '%'||p_domain) LOOP
    i := i+1; res.EXTEND; res(i) := r.email;
  END LOOP;
  RETURN res;
END;
/
```

### C9) Function returning `SYS_REFCURSOR`

```sql
CREATE OR REPLACE FUNCTION open_accounts RETURN SYS_REFCURSOR IS
  rc SYS_REFCURSOR;
BEGIN
  OPEN rc FOR SELECT account_id, email FROM accounts ORDER BY 1;
  RETURN rc;
END;
/
```

### C10) Authid, inline pragma, exceptions — combo

```sql
CREATE OR REPLACE FUNCTION safe_div(p_a IN NUMBER, p_b IN NUMBER)
  RETURN NUMBER AUTHID DEFINER
IS
  PRAGMA UDF;
BEGIN
  IF p_b = 0 THEN RAISE_APPLICATION_ERROR(-20001,'Divide by zero'); END IF;
  RETURN p_a / p_b;
END;
/
```

---

## D) Ref Cursors — strong vs weak

### D1) Strong typed ref cursor from a package

```sql
CREATE OR REPLACE PACKAGE types_pkg AS
  TYPE rc_acct IS REF CURSOR RETURN accounts%ROWTYPE;
END types_pkg;
/
```

### D2) Function returning strong cursor

```sql
CREATE OR REPLACE FUNCTION open_recent(p_days IN NUMBER)
  RETURN types_pkg.rc_acct
AS
  rc types_pkg.rc_acct;
BEGIN
  OPEN rc FOR SELECT * FROM accounts WHERE created_at >= SYSDATE - p_days;
  RETURN rc;
END;
/
```

### D3) Weak cursor (shape varies)

```sql
DECLARE
  rc SYS_REFCURSOR; v_id NUMBER; v_email VARCHAR2(320);
BEGIN
  OPEN rc FOR 'SELECT account_id, email FROM accounts WHERE rownum<=3';
  LOOP FETCH rc INTO v_id, v_email; EXIT WHEN rc%NOTFOUND; NULL; END LOOP;
  CLOSE rc;
END;
/
```

---

## E) Parameter & notation variants (grab bag)

* **Defaults & named association** (seen above).
* **Positional vs named mix**:

  ```sql
  acct_api.create_account('a@b.com', p_name=>'Ada');
  ```
* **Boolean parameters** (PL/SQL only; not usable directly from SQL).
* **Subtypes** to constrain signatures: `SUBTYPE t_email IS VARCHAR2(320);`.
* **`NOCOPY`** for large OUT/IN OUT parameters (CLOBs, big collections).
* **`ACCESSIBLE BY`** on subprograms (12c+) inside packages/bodies to limit callers.
* **Overloading by type/arity** (be cautious with numeric/binary-float confusion).
* **`AUTHID CURRENT_USER`** for library utilities to honor caller’s rights.

---

## F) Patterns you’ll reach for a lot

### F1) CRUD package template (public API, private SQL)

```sql
CREATE OR REPLACE PACKAGE person_api AUTHID DEFINER AS
  PROCEDURE ins(p_email IN VARCHAR2, p_name IN VARCHAR2, p_id OUT NUMBER);
  PROCEDURE upd(p_id IN NUMBER, p_name IN VARCHAR2);
  PROCEDURE del(p_id IN NUMBER);
  FUNCTION  get(p_id IN NUMBER) RETURN persons%ROWTYPE;
END person_api;
/
```

### F2) Validation-first function (raise on bad input)

```sql
CREATE OR REPLACE FUNCTION require_email(p IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  IF p IS NULL OR INSTR(p,'@')=0 THEN RAISE_APPLICATION_ERROR(-20050,'Bad email'); END IF;
  RETURN LOWER(TRIM(p));
END;
/
```

### F3) Package with feature flag & result cache helper

```sql
CREATE OR REPLACE PACKAGE feature AS
  FUNCTION on(p_name IN VARCHAR2) RETURN BOOLEAN RESULT_CACHE;
END feature;
/
```

---

## G) Quick decision guide

* Need **shared types/state** → Package.
* Need **caller’s privileges** → `AUTHID CURRENT_USER`.
* Need to **stream rows** → Pipelined function (optionally `PARALLEL_ENABLE`).
* Need **speed** for SQL-called scalars → `PRAGMA UDF` (+ deterministic if true).
* Need **durable log** → procedure/function with `AUTONOMOUS_TRANSACTION`.
* Passing **large OUT** data → `NOCOPY`.
* **Cache** repeat lookups → `RESULT_CACHE`.
* Shape varies / client pulls → return **`SYS_REFCURSOR`** (or strong typed for fixed shape).

```yaml
---
id: docs/sql/oracle/280-pack-proc-func.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.8"
tested_on: "Oracle 19c"
tags: [plsql, packages, procedures, functions, overloading, authid, nocopy, result_cache, deterministic, pipelined, parallel_enable, ref-cursor, serially_reusable, accessible_by, autonomous_transaction, udf]
description: "An exhaustive catalog of PL/SQL subprogram variations you can drop into any schema: package patterns, procedures, and function flavors with 19c-friendly options."
---
```