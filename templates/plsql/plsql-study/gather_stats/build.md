Short answer: no, it’s not the same as pre-12c. The optimizer’s stats story got much smarter. Today you lean on **automatic stats**, **AUTO sample sizes**, **incremental stats** for partitions, **extended stats** on correlated columns, and (from 12c/18c/19c) **online/real-time stats** during bulk loads—so you gather far less by hand.

# What changed since pre-12c

* **Automatic Statistics Gathering** (nightly job) is the default; you let it handle most objects and only override exceptions.
* **AUTO sample size** (`ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE`) became genuinely good. Stop hard-coding 10%/100% unless you have evidence.
* **Incremental Global Stats for Partitioned Tables**: set `INCREMENTAL => TRUE`. Oracle maintains synopses per partition so global stats don’t require a full scan after small partition refreshes.
* **Online/Real-Time Stats**:

  * **Online stats for bulk loads** (12c): `CTAS` and `INSERT /*+ APPEND */` populate stats as data lands.
  * **Real-Time Statistics** (18c/19c+): Oracle continuously maintains some stats during DML; post-load `GATHER_*_STATS` is often unnecessary.
* **Histograms got smarter**: top-frequency and hybrid histograms appear automatically when needed; don’t blanket “SIZE 254” anymore.
* **Extended stats**: you can (and should) create column-group stats for correlated predicates; the auto job won’t infer correlations on its own.

# Recommended practice (baseline)

1. **Let the auto job run**; don’t disable it.
2. Keep these **preferences** unless you have proven reasons to change:

   * `ESTIMATE_PERCENT = AUTO_SAMPLE_SIZE`
   * `METHOD_OPT = 'FOR ALL COLUMNS SIZE AUTO'`
   * `CASCADE = DBMS_STATS.AUTO_CASCADE`
   * `NO_INVALIDATE = DBMS_STATS.AUTO_INVALIDATE`
3. For **large partitioned tables** that see rolling loads:

   * `INCREMENTAL = TRUE`
   * `PUBLISH = TRUE` (or use pending stats in sensitive systems)
   * `GRANULARITY = AUTO`
4. Use **extended stats** on correlated columns used together in predicates/joins.
5. For **bulk loads** (ETL): prefer `CTAS` / `INSERT /*+ APPEND */` and let online/real-time stats do the work; only gather if plans look off.

# When to gather manually

* Fresh objects with no stats and you need performance **before** the auto job runs.
* After **massive data skew changes** (e.g., new dominant values) and plans suffer.
* Post-partition maintenance where incremental synopses weren’t created (catch-up run).
* Before critical releases: gather on changed objects to stabilize plans.

# Practical snippets

## Set global defaults (once)

```sql
BEGIN
  DBMS_STATS.SET_GLOBAL_PREFS('ESTIMATE_PERCENT', DBMS_STATS.AUTO_SAMPLE_SIZE);
  DBMS_STATS.SET_GLOBAL_PREFS('METHOD_OPT', 'FOR ALL COLUMNS SIZE AUTO');
  DBMS_STATS.SET_GLOBAL_PREFS('CASCADE', DBMS_STATS.AUTO_CASCADE);
  DBMS_STATS.SET_GLOBAL_PREFS('NO_INVALIDATE', DBMS_STATS.AUTO_INVALIDATE);
END;
/
```

## Turn on incremental stats for a partitioned table

```sql
BEGIN
  DBMS_STATS.SET_TABLE_PREFS(USER, 'SALES_FACT', 'INCREMENTAL', 'TRUE');
  DBMS_STATS.SET_TABLE_PREFS(USER, 'SALES_FACT', 'PUBLISH', 'TRUE');
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'SALES_FACT'); -- primes synopses
END;
/
```

## Gather table stats (modern defaults)

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname          => USER,
    tabname          => 'ORDERS',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    cascade          => DBMS_STATS.AUTO_CASCADE
  );
END;
/
```

## Create extended (column group) stats

```sql
-- Correlated filters: (status, region) often used together
SELECT DBMS_STATS.CREATE_EXTENDED_STATS(USER, 'ORDERS', '(status, region)') FROM dual;
-- Then re-gather:
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS'); END; /
```

## Pending stats (test before publish)

```sql
BEGIN
  DBMS_STATS.SET_TABLE_PREFS(USER, 'ORDERS', 'PUBLISH', 'FALSE');
  DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS');      -- writes pending stats
END;
/

-- Test with pending stats:
ALTER SESSION SET optimizer_use_pending_statistics = TRUE;
-- run representative queries, inspect plans

-- If good, publish:
BEGIN DBMS_STATS.PUBLISH_PENDING_STATS(USER, 'ORDERS'); END; /
```

## Lock stats (freeze on stable lookup tables)

```sql
BEGIN DBMS_STATS.LOCK_TABLE_STATS(USER, 'DIM_COUNTRY'); END; /
-- Later: DBMS_STATS.UNLOCK_TABLE_STATS(USER, 'DIM_COUNTRY');
```

# Gotchas / tips

* **Don’t force 100% estimates** on big tables; it burns hours and redo for marginal plan benefit.
* **Histograms**: let AUTO decide; manually sizing many columns can bloat stats and change plans unpredictably.
* **“Stats look fine but plan is wrong”** → check **extended stats** needs, **bind peeking** impact, and use `DBMS_XPLAN.DISPLAY_CURSOR('sql_id','child','ALLSTATS LAST +PEEKED_BINDS')`.
* **Real-Time Stats** reduce—but don’t eliminate—the need to gather. If you see E-Rows vs A-Rows way off, gather on the target objects (or fix column groups).
* **Partition exchange loads**: incremental stats + `PUBLISH=TRUE` keeps global stats current with minimal work.

If you want, I can review one of your largest tables and propose the exact `SET_TABLE_PREFS` + extended-stats definitions that fit its access patterns.
