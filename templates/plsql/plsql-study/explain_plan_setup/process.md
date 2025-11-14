Good question — and this one’s quietly changed over the years. The short version is:
`EXPLAIN PLAN` is fine for *rough sketches*, but the **real plan of record** comes from the *actual cursor* in memory. That means:
✅ **`DBMS_XPLAN.DISPLAY_CURSOR`**, not just `EXPLAIN PLAN FOR …`.

Let’s unpack that carefully.

---

### 1. The old-school way (`EXPLAIN PLAN`)

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders WHERE customer_id = 123;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

That writes a theoretical plan into the `PLAN_TABLE`.
It’s cheap and quick, but it’s **not what actually ran** — it’s what Oracle *thinks* it would run if it were executed now, with current stats and parameters.

If your session or query context differs from when the SQL actually ran (bind values, session parameters, adaptive features, cardinality feedback, etc.), `EXPLAIN PLAN` can lie to you.

**So these days, it’s used mostly for:**

* teaching,
* quick what-if plan estimation,
* and static SQL analysis before the first execution.

---

### 2. The modern way (`DBMS_XPLAN.DISPLAY_CURSOR`)

This is the real deal. It dumps the **executed** or **cached** plan from `V$SQL_PLAN` using the cursor handle of the SQL statement.

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

That shows:

* the *actual plan used*,
* the *actual row counts* per step (not just estimates),
* CPU and I/O metrics (if you include `ALLSTATS`),
* adaptive plan notes (if applicable).

If you just executed a statement in the same session, this will show the exact plan it used.

You can also target a specific SQL ID:

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&&sql_id', NULL, 'ALLSTATS LAST'));
```

---

### 3. How it differs

| Feature                              | `EXPLAIN PLAN` | `DISPLAY_CURSOR`       |
| ------------------------------------ | -------------- | ---------------------- |
| Shows plan without running query     | ✅              | ❌ (requires execution) |
| Reflects adaptive plan changes       | ❌              | ✅                      |
| Reflects bind variable peeking       | ❌              | ✅                      |
| Reflects real runtime stats          | ❌              | ✅                      |
| Works for past SQLs in library cache | ❌              | ✅                      |
| Requires PLAN_TABLE                  | ✅              | ❌                      |

In practice:
→ **Use `EXPLAIN PLAN` before first execution** to sanity-check your joins and access paths.
→ **Use `DBMS_XPLAN.DISPLAY_CURSOR` after execution** to see what Oracle *actually did*.

---

### 4. Typical workflow these days

```sql
-- run your query once (even with small LIMIT)
SELECT * FROM orders WHERE customer_id = 123;

-- show the plan Oracle really used
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

Or, for something running elsewhere:

```sql
SELECT sql_id, child_number, sql_text
FROM v$sql
WHERE sql_text LIKE '%orders%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('7bq4p6g5f8m7z', 0, 'ALLSTATS LAST'));
```

That shows both estimated vs. actual rows per step — which is *gold* for diagnosing bad cardinality estimates.

---

### 5. Other flavors of `DBMS_XPLAN`

| Procedure                                      | Purpose                                      |
| ---------------------------------------------- | -------------------------------------------- |
| `DISPLAY(plan_table, format)`                  | shows the `EXPLAIN PLAN` results (old way)   |
| `DISPLAY_CURSOR(sql_id, child_no, format)`     | shows the executed plan from memory (modern) |
| `DISPLAY_AWR(sql_id, format)`                  | shows a plan from AWR history                |
| `DISPLAY_SQL_PLAN_BASELINE(plan_name, format)` | shows baseline plans                         |
| `DISPLAY_SQLSET(sqlset_name, format)`          | shows plans from SQL tuning sets             |

---

### 6. Pro tips

* Use format `'ALLSTATS LAST +OUTLINE +PEEKED_BINDS'` for the full picture.
* Run with `GATHER_PLAN_STATISTICS` hint or `ALTER SESSION SET statistics_level = ALL` if you want actual runtime row counts (`A-Rows` column).
* Always compare **E-Rows** (estimated) vs. **A-Rows** (actual) — big differences mean the optimizer’s cardinality model is off.
* Save the SQL ID from `V$SQL` for performance tuning sessions — it’s how Oracle identifies plans, not by the text alone.

---

### TL;DR modern workflow

| Step | Command                                                                        | Purpose                      |
| ---- | ------------------------------------------------------------------------------ | ---------------------------- |
| 1    | `ALTER SESSION SET statistics_level = ALL;`                                    | collect runtime stats        |
| 2    | Run your query                                                                 | populate plan and stats      |
| 3    | `SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));` | see the *actual* plan        |
| 4    | Optional: use `sql_id` from `V$SQL` for cross-session analysis                 | deep dive or historic lookup |

---

Would you like me to show you a **sample `DBMS_XPLAN.DISPLAY_CURSOR` output** (annotated line by line) so you can see how to interpret estimated vs. actual rows, CPU, and I/O?
