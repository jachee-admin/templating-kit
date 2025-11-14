# PostgreSQL — Master Cheat Sheet (Language & Ops Focus)

**Audience:** Full‑stack devs (Next.js/Supabase). **Goal:** Practical SQL + Postgres features you’ll use daily, with production‑ready defaults.

---

## 0) Daily Quick‑Ref (90% of usage)

```sql
-- Create tables
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_on timestamptz not null default now()
);

create table dashboards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  created_on timestamptz not null default now()
);

-- Unique / constraints
alter table dashboards add constraint dashboards_title_owner_unique
  unique (user_id, title);

-- Insert / upsert
insert into dashboards (user_id, title) values ($1, $2)
on conflict (user_id, title) do update set title = excluded.title;

-- Select
select d.id, d.title
from dashboards d
where d.user_id = $1
order by d.created_on desc
limit 20 offset 0;

-- Update / Delete
update dashboards set title = $2 where id = $1;
delete from dashboards where id = $1;

-- Index (btree default)
create index on dashboards (user_id, created_on desc);

-- JSONB read
select data->>'name' as name from dashboard_elements;

-- Explain
explain analyze select * from dashboards where user_id = $1;

-- Transactions
begin;
  update dashboards set title = 'New' where id = $1;
commit;
```

---

## 1) Data Types You Actually Use

- **text** (unbounded string) — default for strings.
- **varchar(n)** only if you truly must enforce length.
- **uuid** — great PKs; `gen_random_uuid()` from `pgcrypto`.
- **int / bigint** — counters; prefer `bigint` for high growth.
- **boolean** — `true/false`.
- **timestamptz** — always use **time zone aware** timestamps.
- **jsonb** — schemaless blobs with indexes.
- **numeric(precision, scale)** — money/precise decimals.
- **enum** — for small, stable sets (or use text + check constraint).

```sql
create extension if not exists pgcrypto; -- for gen_random_uuid()

create type element_type as enum ('text', 'image', 'affirmation');
-- or: check (type in ('text','image','affirmation'))
```

---

## 2) Constraints & Defaults

- `primary key`, `unique`, `not null`, `check`, `references` (FK).
- Default timestamps: `timestamptz not null default now()`.
- Cascade deletes when children should go with parent:
  `references profiles(id) on delete cascade`.

**Generated columns:**
```sql
alter table dashboard_elements
add column search_text text generated always as ((content->>'text')) stored;
```

---

## 3) Joins, CTEs, Windows

```sql
-- Joins
select d.id, d.title, p.display_name
from dashboards d
join profiles p on p.id = d.user_id;

-- CTEs (WITH)
with recent as (
  select * from dashboards where user_id = $1 order by created_on desc limit 50
)
select * from recent where title ilike '%vision%';

-- Window functions
select user_id,
       count(*) as total,
       rank() over (order by count(*) desc) as rnk
from dashboards
group by user_id;
```

**Common windows:** `row_number()`, `rank()`, `dense_rank()`, `lag()`, `lead()`, `sum() over (partition by ...)`

---

## 4) JSONB Power Moves

```sql
-- Read
select elem.content->>'text' as text
from dashboard_elements elem;

-- Update nested
update dashboard_elements
set content = jsonb_set(content, '{style,color}', to_jsonb('blue'::text), true)
where id = $1;

-- Existence / containment
select * from dashboard_elements
where content ? 'style'                -- has key
  and content @> '{"type":"text"}';    -- contains

-- Index JSONB (GIN)
create index on dashboard_elements using gin (content jsonb_path_ops);
```

---

## 5) Upsert & Concurrency

```sql
insert into dashboards (id, user_id, title)
values (gen_random_uuid(), $1, $2)
on conflict (user_id, title) do update
  set updated_on = now()
returning *;
```

- Use **`on conflict`** for idempotency.
- For “last write wins” keep a `updated_on` column and set it on updates.

**Isolation basics:** default is **Read Committed** (good). For rare cross‑row consistency, use `serializable` with care. Prefer **optimistic** patterns + unique constraints to avoid locks.

---

## 6) Indexing That Matters

- **btree** (default): equality & range on scalar columns.
- **GIN**: JSONB containment, arrays, full‑text (`tsvector`).
- **GiST**: ranges, geometry.
- **hash**: equality only (rarely needed).

```sql
-- Composite to match your WHERE/ORDER BY
create index dashboards_user_created_idx on dashboards (user_id, created_on desc);

-- Partial index (filters)
create index dashboards_active_idx on dashboards (user_id) where archived = false;

-- Full‑text
alter table dashboards add column tsv tsvector
  generated always as (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))) stored;
create index on dashboards using gin (tsv);
select * from dashboards where tsv @@ plainto_tsquery('english', 'vision goals');
```

`explain analyze` to see plan & timing; look for **Seq Scan** vs **Index Scan**, row estimates, and sort vs index ordering.

---

## 7) Transactions, Locks, Deadlocks

```sql
begin;
  update dashboards set title = 'A' where id = $1;
  -- do related updates...
commit;

-- Roll back early
rollback;
```

- **Row‑level locks:** `select ... for update` to lock rows before updates.
- Avoid long transactions; keep them small to reduce contention.
- Deadlock fix: acquire locks in consistent order, or retry on deadlock error.

---

## 8) RLS (Row Level Security) — Supabase‑ready

```sql
alter table profiles enable row level security;

create policy "profiles_select_own"
  on profiles for select
  using (id = auth.uid());

create policy "profiles_insert_own"
  on profiles for insert
  with check (id = auth.uid());

create policy "profiles_update_own"
  on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());
```

For child tables:

```sql
alter table dashboards enable row level security;

create policy "dashboards_owner_all"
  on dashboards for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

Elements via parent ownership:

```sql
alter table dashboard_elements enable row level security;

create policy "elements_owner_all"
on dashboard_elements for all
using (exists (
  select 1 from dashboards d where d.id = dashboard_id and d.user_id = auth.uid()
))
with check (exists (
  select 1 from dashboards d where d.id = dashboard_id and d.user_id = auth.uid()
));
```

**Test RLS in SQL Editor (simulate user):**
```sql
begin;
select set_config('request.jwt.claims', json_build_object('role','authenticated','sub','<USER_UUID>')::text, true);
set local role authenticated;
select auth.uid(); -- should be USER_UUID
-- run your selects here
rollback;
```

---

## 9) Views & Materialized Views

```sql
create view v_recent_dashboards as
select * from dashboards where created_on > now() - interval '30 days';

create materialized view mv_dashboard_counts as
select user_id, count(*) as n from dashboards group by user_id;
create index on mv_dashboard_counts (user_id);
refresh materialized view concurrently mv_dashboard_counts;
```

Materialized views need manual `refresh`. Use `concurrently` to avoid locks (requires unique index).

---

## 10) Extensions You’ll Actually Use

- `pgcrypto` — `gen_random_uuid()`.
- `uuid-ossp` — legacy UUID gen (prefer pgcrypto).
- `pg_trgm` — trigram search (`%` similarity, `gin_trgm_ops`).
- `unaccent` — normalize diacritics.
- `postgis` — geospatial (if needed).

```sql
create extension if not exists pg_trgm;
create index on dashboards using gin (title gin_trgm_ops);
select * from dashboards where title % 'vission'; -- fuzzy match
```

---

## 11) Maintenance & Health

- **VACUUM** (auto in Supabase/managed): cleans dead tuples.
- **ANALYZE**: keep planner stats fresh (auto).
- **`pg_stat_statements`**: find slow/top queries (managed often pre‑enabled).
- Keep transactions short; don’t leave idle in transaction.

**Explain checklist:**
- Compare estimated vs actual rows.
- Ensure selective predicates have supporting indexes.
- Prefer index order to avoid explicit sort.

---

## 12) Security Basics

- Always use **parameterized queries** (`$1, $2, ...`) → avoid injection.
- Principle of least privilege: grant only what’s needed.
- With Supabase, never ship service role to the client.

```sql
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
```

---

## 13) psql & CLI Nuggets

```bash
# connect
psql $DATABASE_URL

# timing
\timing on

# show last query plan quickly
explain analyze select ...;

# list tables
\dt+

# describe table
\d+ public.dashboards
```

---

## 14) Patterns & Anti‑Patterns

**Do:**
- Narrow rows: avoid giant wide tables of nullable columns; split into related tables.
- Prefer `timestamptz`, not `timestamp`.
- Composite indexes to match common `where` + `order by`.
- `on conflict` for idempotent writes.

**Avoid:**
- Over‑normalizing tiny attributes into many join tables (balance is key).
- `select *` in APIs (specify needed columns).
- Using `uuid_generate_v4()` without enabling the extension (prefer `gen_random_uuid()`).
- Triggers for business logic when a plain application write is simpler.

---

## 15) Handy Snippets

```sql
-- Soft delete pattern
alter table dashboards add column deleted_at timestamptz;
create index on dashboards (deleted_at) where deleted_at is not null;

-- Pagination (keyset)
select * from dashboards
where user_id = $1 and created_on < $2
order by created_on desc
limit 50;

-- Upsert JSONB merge
update dashboard_elements
set content = content || jsonb_build_object('lastEditedBy', $2)
where id = $1;

-- Row existence check
select exists(select 1 from dashboards where id = $1);
```

— End —
