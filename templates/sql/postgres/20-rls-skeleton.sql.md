---
id: sql/postgres/rls-skeleton
lang: sql
platform: postgres
scope: security
since: "v0.1"
tested_on: "PostgreSQL 16"
tags: [rls, multitenant, policies]
description: "Enable RLS and add basic tenant policy"
---

### Postgres: RLS Skeleton
Tenant isolation using a trusted session setting (`app.tenant_id`).

### RLS Snippet
```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_orders_tenant_isolation
  ON public.orders
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);
```

### Session bootstrap (example)
```sql
-- set once per session/connection:
SELECT set_config('app.tenant_id', '00000000-0000-0000-0000-000000000000', false);
```
