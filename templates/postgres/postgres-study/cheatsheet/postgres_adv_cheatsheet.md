# PostgreSQL Cheatsheet — Advanced / Ops & Tuning

> Notion-friendly. Focus on production performance, reliability, and Postgres-specific power features (v12+ assumptions).

---

## 1) MVCC, vacuum, bloat (know the engine)

* **MVCC**: every UPDATE = DELETE (old tuple) + INSERT (new tuple). Readers don’t block writers.
* **VACUUM**: marks dead tuples reusable; **doesn’t** shrink files.

  * `VACUUM (VERBOSE, ANALYZE) schema.table;`
* **VACUUM FULL**: rewrites table to compact; **exclusive lock**. Prefer off-hours or use `pg_repack` (online).
* **HOT updates**: if updated columns don’t touch indexed values, the new row can stay on the same page (fewer index writes).

**Bloat quick checks**

```sql
-- live vs dead tuples (table level)
SELECT relname, n_live_tup, n_dead_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;

-- index usage (low idx_scan = suspicious index)
SELECT relname, idx_scan
FROM pg_stat_user_tables
ORDER BY idx_scan ASC
LIMIT 20;
```

---

## 2) Isolation & concurrency

* Levels: `READ COMMITTED` (default), `REPEATABLE READ`, `SERIALIZABLE`.
* **Phantom reads** possible at RC; **stable snapshot** at RR; true serializability at SERIALIZABLE (may raise serialization failures → retry).

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- do work; on serialization_failure, retry the whole tx
COMMIT;
```

**Advisory locks** (app-level, non-blocking DB work):

```sql
SELECT pg_try_advisory_xact_lock(42);  -- scoped to tx
```

---

## 3) Autovacuum tuning (don’t guess—measure)

Key GUCs (cluster or per table via storage parameters):

* `autovacuum_vacuum_scale_factor` (default 0.2 → often too high for big tables)
* `autovacuum_vacuum_threshold` (defaults 50)
* `autovacuum_analyze_scale_factor` (0.1 by default)
* `autovacuum_naptime` (1 min default)
* `maintenance_work_mem` (used by VACUUM/CREATE INDEX)

Per-table overrides:

```sql
ALTER TABLE big_t
  SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_threshold = 5000);
```

Watchdog:

```sql
SELECT relname, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_autovacuum NULLS FIRST
LIMIT 30;
```

---

## 4) Partitioning (declarative)

* Use for **very large** tables (time-series, tenant sharding, archival).
* Types: RANGE, LIST, HASH. Prefer **RANGE by date** for time-series.
* Attach **default** partition for safety.

```sql
CREATE TABLE events (
  ts timestamptz NOT NULL,
  payload jsonb
) PARTITION BY RANGE (ts);

CREATE TABLE events_2025_09 PARTITION OF events
  FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');

-- helpful indexes on each partition or globally (PG15+ supports some global)
CREATE INDEX ON events_2025_09 (ts);
```

**Pruning** happens only when the partition key is visible to the planner (avoid functions that hide constants).

---

## 5) Index mastery

* **B-tree**: default (equality, range, ORDER BY).
* **GIN**: arrays, `jsonb` containment (`@>`), full-text (`tsvector`).
* **GiST**: ranges, geo (PostGIS), nearest neighbor.
* **BRIN**: massive append-only, naturally ordered columns (tiny).
* **Bloom** (extension): multi-column probabilistic membership.

Patterns:

```sql
-- Expression + INCLUDE (covering)
CREATE INDEX ix_lower_email ON account (lower(email)) INCLUDE (status);

-- Partial (target hot subset)
CREATE INDEX ix_active_email ON account (email) WHERE status='active';

-- JSONB containment
CREATE INDEX ix_evt_payload ON evt USING gin (payload);

-- Trigram (extension: pg_trgm) for ILIKE/substring search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX ix_title_trgm ON doc USING gin (title gin_trgm_ops);
```

Composite index order = **(filter columns equality first) → range/order columns last**.

---

## 6) Statistics & the planner

* Use `EXPLAIN (ANALYZE, BUFFERS)`; examine **row estimates vs actuals**. Big errors → missing stats or bad data skew.
* **Extended stats** (multi-column correlation/MCV/NDV):

```sql
CREATE STATISTICS s1 (dependencies, mcv, ndistinct) ON col1, col2 FROM t;
ANALYZE t;
```

* Planner toggles (session only, for diagnosis): `SET enable_nestloop = off;` etc.
* JIT (PG11+): `SET jit = off;` helps short queries; leave on for long analytics.

---

## 7) Memory & core config (rules of thumb—validate in staging)

* `shared_buffers` ≈ 25% RAM (don’t overshoot).
* `effective_cache_size` ≈ 50–75% RAM (OS cache hint).
* `work_mem` per **sort/hash node** per session. Start small (e.g., 4–64MB) and adjust hotspots.
* `maintenance_work_mem` large during index builds / VACUUM (e.g., 1–4GB on big servers).
* `max_connections`: keep modest; front with **pgBouncer**.
* `random_page_cost` lower on SSDs (e.g., 1.1–1.5).
* Always enable `pg_stat_statements`.

---

## 8) WAL, checkpoints, PITR

* WAL durability knobs:

  * `synchronous_commit = on` (safe); `off` trades durability for latency.
  * `full_page_writes = on` (don’t disable).
* Checkpoint tuning:

  * `max_wal_size` larger → fewer checkpoints.
  * `checkpoint_timeout` (e.g., 15–30m).
  * `checkpoint_completion_target` \~0.9 (spread I/O).
* **Archiving** for PITR:

```conf
wal_level = replica
archive_mode = on
archive_command = 'rsync -a %p /arch/%f'
```

* **Base backup** + WAL archive → restore to any timestamp:

```sql
-- At restore: recovery.signal + restore_command; set recovery_target_time
```

---

## 9) Replication & HA

* **Streaming replication** (physical): primary → standby via WAL; use **replication slots** to retain WAL.
* **Promotion**: `pg_ctl promote` on standby.
* **Logical replication**: per-table publications/subscriptions; cross-version upgrades, selective replication.

```sql
-- On primary
CREATE PUBLICATION pub1 FOR TABLE app.customer, app.order;
-- On replica
CREATE SUBSCRIPTION sub1 CONNECTION 'host=... dbname=... user=... password=...'
  PUBLICATION pub1;
```

* Tools for failover/orchestration: Patroni, repmgr, Stolon, PgAutoFailover.

---

## 10) Connection pooling (pgBouncer)

* Modes: **transaction** (best throughput), **session** (feature-complete), **statement** (rare).
* **Transaction pooling caveats**: no session features between txs (temp tables, prepared statements, `LISTEN/NOTIFY`, GUCs needing session scope, advisory locks). Keep app code tx-bound and stateless.

---

## 11) Security, RLS, definer functions

* Default to **least privilege**; avoid `GRANT ALL ON SCHEMA public TO PUBLIC`.
* Force sane defaults:

```sql
REVOKE ALL ON SCHEMA public FROM PUBLIC;
ALTER DATABASE mydb SET search_path = app, public;
```

* **Row Level Security**:

```sql
ALTER TABLE invoice ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON invoice
  USING (tenant_id = current_setting('app.tenant_id')::int);
```

* **SECURITY DEFINER** functions: whitelisted escalations. Always:

  * `SET search_path` inside the function body
  * validate inputs; never concatenate untrusted SQL.

---

## 12) JSONB & FTS — advanced

**JSONB patterns**

```sql
-- Index specific paths for speed (expression GIN)
CREATE INDEX ix_evt_userid ON evt USING gin ((payload->'user'->>'id'));

-- Existence / containment are cheap with GIN
SELECT * FROM evt
WHERE payload @> '{"type":"signup"}';

-- jsonpath (PG12+)
SELECT * FROM evt
WHERE payload @? '$.items[*] ? (@.price > 100)';
```

**FTS at scale**

```sql
-- Weighted vector + coalesce; store in a generated column
ALTER TABLE doc ADD COLUMN tsv tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(summary,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(body,'')), 'C')
  ) STORED;

CREATE INDEX ix_doc_tsv ON doc USING gin (tsv);
SELECT * FROM doc
WHERE tsv @@ to_tsquery('english', 'donor & network');
```

---

## 13) FDWs, parallel, and large ETL

* **postgres\_fdw** for cross-DB queries:

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER rem FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'h', dbname 'd');
CREATE USER MAPPING FOR appuser SERVER rem OPTIONS (user 'u', password 'p');
IMPORT FOREIGN SCHEMA public FROM SERVER rem INTO rem_s;
```

* **Parallel query** kicks in on large scans/aggregations (planner decides); ensure `max_parallel_workers_per_gather` > 0, sufficient workers.
* Bulk load with `COPY` (server-side) + disable FKs/indexes during initial loads, rebuild after.

---

## 14) Monitoring playbook

Install:

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

Handy queries:

```sql
-- Top slow/expensive
SELECT calls, total_time, mean_time, rows, query
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 20;

-- Blockers & waiters
SELECT bl.pid AS blocked_pid, ka.query AS blocker_query, kl.pid AS blocker_pid, a.query AS blocked_query
FROM pg_locks bl
JOIN pg_stat_activity a ON a.pid = bl.pid
JOIN pg_locks kl ON kl.locktype = bl.locktype AND kl.DATABASE IS NOT DISTINCT FROM bl.DATABASE
  AND kl.relation IS NOT DISTINCT FROM bl.relation AND kl.page IS NOT DISTINCT FROM bl.page
  AND kl.tuple IS NOT DISTINCT FROM bl.tuple AND kl.virtualxid IS NOT DISTINCT FROM bl.virtualxid
  AND kl.transactionid IS NOT DISTINCT FROM bl.transactionid AND kl.classid IS NOT DISTINCT FROM bl.classid
  AND kl.objid IS NOT DISTINCT FROM bl.objid AND kl.objsubid IS NOT DISTINCT FROM bl.objsubid
JOIN pg_stat_activity ka ON ka.pid = kl.pid
WHERE NOT bl.granted;

-- Long running queries
SELECT pid, now()-query_start AS age, state, query
FROM pg_stat_activity
WHERE state <> 'idle' AND now()-query_start > interval '1 minute'
ORDER BY age DESC;

-- Table hot spots
SELECT relname, seq_scan, idx_scan, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
ORDER BY n_tup_upd + n_tup_del DESC
LIMIT 20;
```

---

## 15) Performance recipes

* Prefer **single SQL** over row loops; materialize with CTE only when it **helps** (avoid giant CTE chains on hot paths).
* Replace `IN (SELECT …)` with `EXISTS` for semi-joins.
* Keep **`work_mem`** sized to avoid disk hashes/sorts (watch `EXPLAIN` for `Disk:`).
* For frequent LIKE/ILIKE on text → **pg\_trgm** GIN; for prefix searches → btree on `(col text_pattern_ops)`.
* Avoid `OFFSET N` pagination on big N. Use **keyset pagination**:

```sql
SELECT * FROM t
WHERE (created_at, id) < (timestamptz '2025-09-16', 987654)
ORDER BY created_at DESC, id DESC
LIMIT 50;
```

* Batch writes with `INSERT ... SELECT`, or staged `COPY` into a temp table then merge.

---

## 16) Backup & restore strategy (practical)

* Nightly **base backup** (pgBackRest, barman, or `pg_basebackup`) + continuous WAL archiving.
* Test **PITR** quarterly. Keep **globals** (`pg_dumpall --globals-only`) under version control.
* For schema migrations: idempotent scripts + transactional DDL where possible; partition attaches are instant, big table rewrites are not.

---

## 17) Oracle → Postgres advanced gotchas

* Identifiers are **lowercased** unless quoted; `"CamelCase"` becomes case-sensitive.
* Empty string ≠ NULL. Adjust data checks and unique constraints accordingly.
* Sequences: identity columns **cache** by default; gaps are normal. Use `generated by default/as identity`.
* Date math/rounding differs (`add_months`, `trunc` equivalents: `make_interval`, `date_trunc`).
* No package state; emulate with schemas + functions; use `SECURITY DEFINER` sparingly.

---

## 18) Ops checklist (before you go live)

* `pg_stat_statements` enabled; baseline captured.
* Autovacuum thresholds tuned on largest tables.
* Critical indexes verified; `EXPLAIN (ANALYZE, BUFFERS)` for top queries.
* Backups + WAL archiving tested; restore runbook written.
* Connection pool in place; `max_connections` reasonable.
* Alerts on replication lag, disk WAL volume, long xacts, autovacuum backlog.

---

If you want, I can convert both Postgres sheets into **CSV flashcards** (term\:definition) or a **print-ready PDF**. Ready for the next language whenever you are.
