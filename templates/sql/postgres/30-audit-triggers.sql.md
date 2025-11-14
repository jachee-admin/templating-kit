---
id: sql/postgres/audit-trigger
lang: sql
platform: postgres
scope: triggers
since: "v0.1"
tested_on: "PostgreSQL 16"
tags: [audit, trigger]
description: "Touch updated_at/updated_by on DML"
---

### Postgres: Audit Trigger
```sql
CREATE SCHEMA IF NOT EXISTS util;

CREATE OR REPLACE FUNCTION util.touch_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP IN ('INSERT','UPDATE') THEN
    NEW.updated_at := NOW();
    NEW.updated_by := current_setting('app.user_id', true);
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    NEW.created_by := COALESCE(NEW.created_by, current_setting('app.user_id', true));
  END IF;
  RETURN NEW;
END$$;

-- Example attach
DROP TRIGGER IF EXISTS trg_accounts_audit ON public.accounts;
CREATE TRIGGER trg_accounts_audit
BEFORE INSERT OR UPDATE ON public.accounts
FOR EACH ROW EXECUTE FUNCTION util.touch_audit();
```
