---
id: sql/postgres/upsert-basic
lang: sql
platform: postgres
scope: dml
since: "v0.1"
tested_on: "PostgreSQL 16"
tags: [upsert, conflict, audit]
description: "Idempotent upsert with audit columns"
---

### Context
Minimal UPSERT that preserves `created_at` and touches `updated_at`. Suitable for application‑level ids (`uuid`) or database‑generated.

### Primary snippet
```sql
INSERT INTO public.accounts AS a (
  account_id,
  email,
  full_name,
  created_at,
  updated_at
) VALUES (
  COALESCE($1, gen_random_uuid()),
  $2,
  $3,
  NOW(),
  NOW()
)
ON CONFLICT (account_id)
DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name,
  updated_at = NOW()
RETURNING a.*;
```

### Notes
- Prefer table defaults for audit columns; set them explicitly here for portability across tools.
- If you upsert by `email` instead, create a unique index on `(email)` and change `ON CONFLICT (email)`.
