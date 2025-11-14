# PostgreSQL Daily Quick‑Ref (One‑Pager)

## Data types
- `uuid` (`gen_random_uuid()`), `text`, `timestamptz`, `int/bigint`, `boolean`, `jsonb`, `numeric`, `enum`

## DDL
```sql
create extension if not exists pgcrypto;
create table profiles (id uuid primary key, display_name text, created_on timestamptz default now());
alter table profiles add constraint profiles_id_fkey foreign key (id) references auth.users(id) on delete cascade;
create index on profiles (created_on desc);
```

## CRUD
```sql
insert into t (a,b) values ($1,$2)
on conflict (a) do update set b = excluded.b
returning *;

select * from t where a = $1 order by created_on desc limit 20 offset 0;

update t set b = $2 where id = $1;
delete from t where id = $1;
```

## Joins & CTEs
```sql
select d.*, p.display_name
from dashboards d join profiles p on p.id = d.user_id;

with recent as (
  select * from dashboards where user_id = $1 order by created_on desc limit 50
) select * from recent where title ilike '%vision%';
```

## JSONB
```sql
select content->>'text' from dashboard_elements;
update dashboard_elements
set content = jsonb_set(content, '{style,color}', to_jsonb('blue'::text), true)
where id = $1;
create index on dashboard_elements using gin (content jsonb_path_ops);
```

## Full‑text & trigram
```sql
create extension if not exists pg_trgm;
create index on dashboards using gin (title gin_trgm_ops);
select * from dashboards where title % 'vission';
```

## Window functions
```sql
select user_id, count(*) as n,
       rank() over (order by count(*) desc) as rnk
from dashboards group by user_id;
```

## Transactions
```sql
begin;  -- do work
commit; -- or rollback;
```

## RLS (owner‑only)
```sql
alter table dashboards enable row level security;
create policy "owner_all" on dashboards for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
```

## Indexing
```sql
create index on dashboards (user_id, created_on desc);  -- composite
create index on dashboards (user_id) where archived = false; -- partial
```

## Diagnose
```sql
explain analyze select * from dashboards where user_id = $1;
```

## psql
```
\dt+      -- list tables
\d+ t     -- describe table
\timing on
```

False friends: `timestamp` (use `timestamptz`), `serial` (prefer `identity`/UUID), `select *` in APIs.
