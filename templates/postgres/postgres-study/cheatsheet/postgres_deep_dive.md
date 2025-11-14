# PostgreSQL Deep Dive (Performance, Concurrency, JSONB, RLS)

## 1) Planner & EXPLAIN
Use `explain analyze` to see the real plan/time.
- Prefer **Index Scan** over **Seq Scan** for selective predicates.
- Align indexes with predicates and order:
  - `where user_id = ? order by created_on desc` → `(user_id, created_on desc)`
- Check misestimates (rows). **ANALYZE** keeps stats fresh (auto on managed).

```sql
explain analyze
select * from dashboards where user_id = $1 order by created_on desc limit 50;
```

## 2) Indexing toolbox
- **btree**: equality/range on scalar.
- **GIN**: jsonb containment (`@>`), arrays, full‑text tsvector.
- **GiST**: ranges/geometry.
- **Partial** indexes: add `where` to skip cold rows.
- **Covering** indexes: include order key to avoid sort.

Pitfall: too many indexes slow writes; keep only those that serve real queries.

## 3) JSONB patterns
- `@>` containment, `?` key existence, `jsonb_set`, `||` merge.
- Index: `using gin (content jsonb_path_ops)` for containment; use expression indexes for frequent lookups:
```sql
create index elem_text_idx on dashboard_elements ((content->>'text'));
```

## 4) Full‑text search
- `tsvector` column (generated) + GIN index.
- Queries: `plainto_tsquery`, `to_tsquery`, ranking with `ts_rank`.
- Combine with trigram for fuzzy.

## 5) Concurrency & isolation
- Default isolation: **read committed**.
- Use `on conflict` for idempotent upserts.
- Use short transactions; keep locks minimal.
- Detect deadlocks → retry transaction.

Optimistic pattern: put a `version` or `updated_on` and check on update (compare expected).

## 6) Pagination at scale
- **Keyset** (seek) pagination beats offset for large tables:
```sql
select * from dashboards
where user_id = $1 and (created_on, id) < ($2, $3)
order by created_on desc, id desc
limit 50;
```

## 7) Partitioning (when tables grow huge)
- Range or hash partitions on timestamp or user_id.
- Index each partition; use constraint exclusion/pruning.

## 8) Views & Materialized views
- Views: live; can hide complexity.
- Materialized: snapshot; refresh manually (optionally concurrently).

## 9) Roles & privileges
- Create application roles; grant minimal permissions.
- In Supabase: `anon` vs `authenticated`; RLS policies enforce per‑row access.
- Avoid granting on `public` by default; be explicit.

## 10) Triggers & Functions
- Use triggers for mechanical concerns (timestamps, denormalized counters) not core business logic unless necessary.
```sql
create or replace function set_updated_on() returns trigger as $$
begin new.updated_on := now(); return new; end $$ language plpgsql;

create trigger trg_dashboards_updated before update on dashboards
for each row execute function set_updated_on();
```

## 11) Timezones & clock
- Use `timestamptz` everywhere; store UTC; format in app.
- Beware daylight saving transitions; don’t do date math in SQL unless simple.

## 12) Backups & migrations
- Use vetted migration tools; keep schema in VCS.
- In Supabase, use SQL migration files; prefer idempotent scripts (`if exists`).

## 13) Diagnostics
- `pg_stat_statements` for hot/slow queries.
- `pg_locks` to inspect blocking.
- `vacuum verbose` (rarely manual in managed) to observe bloat.

## 14) FTS + Trigram combo
```sql
create extension if not exists pg_trgm;
create index dashboards_title_trgm on dashboards using gin (title gin_trgm_ops);
alter table dashboards add column tsv tsvector
  generated always as (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))) stored;
create index dashboards_tsv_idx on dashboards using gin (tsv);
-- exact words boosted by tsv, typos caught by trigram:
select *
from dashboards
where tsv @@ plainto_tsquery('english', $1) or title % $1
order by ts_rank(tsv, plainto_tsquery('english', $1)) desc;
```

## 15) Handy recipes
- **Existence check**: `select exists(select 1 from t where ...)`
- **Distinct on first**:
```sql
select distinct on (user_id) user_id, title, created_on
from dashboards
order by user_id, created_on desc;
```
- **Pivot with filter** (conditional aggregates):
```sql
select user_id,
  sum((status='open')::int) as open,
  sum((status='closed')::int) as closed
from tickets group by user_id;
```

## 16) When to use which type
- `text` > `varchar(n)` unless you truly need enforcement.
- `numeric` for money/precision; `double precision` for scientific.
- `jsonb` for flexible attributes but index what you query.
- `uuid` for distributed IDs; or `bigint` identity for hot single‑node inserts.

## 17) Testing RLS & migrations
- In CI, run migrations on a fresh DB; run RLS tests with `set_config('request.jwt.claims', ...)` to simulate users.
- Test **deny by default**: ensure no data leaks without policies.

— End —
