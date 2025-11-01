# NC DPI Templating Kit

A pragmatic, grab‑and‑go repository of code fragments, templates, and repeatable patterns for daily engineering work. Designed for fast copy‑paste, with metadata for searchability and a consistent structure across languages and tools.

---

## Repository layout (v0)

```
templating-kit/
├── README.md
├── LICENSE
├── .editorconfig
├── .gitattributes
├── .gitignore
├── CONTRIBUTING.md
├── templates/
│   ├── sql/
│   │   ├── postgres/
│   │   │   ├── 10-upsert-basic.sql
│   │   │   ├── 20-rls-skeleton.sql
│   │   │   └── 30-audit-triggers.sql
│   │   └── oracle/
│   │       ├── 10-seq-trigger-autoinc.sql
│   │       ├── 20-insert-append-and-errlog.sql
│   │       └── 30-explain-plan-tooling.sql
│   ├── apex/
│   │   ├── 10-app-export-checklist.md
│   │   ├── 20-csv-import-sql-developer.md
│   │   └── 30-auth-schemes-overview.md
│   ├── ords/
│   │   ├── 10-serve-config-snippets.md
│   │   └── 20-proxy-user-and-logging.md
│   ├── ansible/
│   │   ├── 10-users-and-groups.yml
│   │   └── 20-postgres-db-user.yml
│   ├── bash/
│   │   ├── 10-strict-mode.sh
│   │   └── 20-log-rotate-skel.sh
│   ├── python/
│   │   ├── 10-retry-with-jitter.py
│   │   └── 20-csv-to-json.py
│   ├── git-github/
│   │   ├── 10-pr-template.md
│   │   ├── 20-issue-templates.md
│   │   └── actions/
│   │       └── 10-python-ci.yml
│   └── security/
│       ├── 10-secret-management-notes.md
│       └── 20-sso-saml-oidc-cheatsheet.md
└── tools/
    └── grep-snippets.py
```

> Naming: `NN-topic-name.ext` to preserve stable ordering. Prefer kebab‑case. Keep snippets small and focused.

---

## Snippet metadata convention

Each snippet (code or doc) begins with a YAML header for easy grep/indexing.

```yaml
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
```

Follow the header with the code and very short usage notes.

---

## Starter templates

### 1) PostgreSQL — basic UPSERT with audit columns

```sql
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

Usage: `account_id` optional; server generates when null. Keep audit columns in table default (`created_at default now()`), but set explicitly here for portability.

---

### 2) PostgreSQL — RLS policy skeleton (tenant_id)

```sql
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
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_orders_tenant_isolation
  ON public.orders
  USING (tenant_id = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);

-- At session start (e.g., via pooler or app):
-- SELECT set_config('app.tenant_id', '00000000-0000-0000-0000-000000000000', false);
```

Notes: swap config source to a SECURE immutable session var. Pair with `SECURITY DEFINER` views if needed.

---

### 3) PostgreSQL — audit trigger (updated_at, updated_by)

```sql
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

---

### 4) Oracle — sequence + trigger autoincrement if NULL on insert

```sql
---
id: sql/oracle/seq-trigger-autoinc
lang: sql
platform: oracle
scope: triggers
since: "v0.1"
tested_on: "Oracle 19c"
tags: [sequence, trigger, autoincrement]
description: "Assign nextval only when PK is NULL"
---
-- Sequence
CREATE SEQUENCE acct_seq START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Trigger
CREATE OR REPLACE TRIGGER acct_bi
BEFORE INSERT ON accounts
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
  :NEW.id := acct_seq.NEXTVAL;
END;
/
```

---

### 5) Oracle — INSERT /*+ APPEND */ with error logging pattern

```sql
---
id: sql/oracle/append-errlog
lang: sql
platform: oracle
scope: dml
since: "v0.1"
tested_on: "Oracle 19c"
tags: [direct-path, error-logging]
description: "High-throughput insert with DML error logging"
---
BEGIN
  DBMS_ERRLOG.CREATE_ERROR_LOG(dml_table_name => 'STAGE_ORDERS_CSV');
END;
/

INSERT /*+ APPEND */ INTO stage_orders_csv (col1, col2, ...)
SELECT col1, col2, ...
FROM   ext_table
LOG ERRORS INTO err$_stage_orders_csv ('LOAD') REJECT LIMIT UNLIMITED;
```

Notes: `APPEND` uses direct-path insert—bypasses buffer cache, faster for bulk loads. Pair with `ALTER SESSION DISABLE PARALLEL DML`/`ENABLE` as needed.

---

### 6) Oracle — EXPLAIN PLAN helpers (modern)

```sql
---
id: sql/oracle/explain-plan-modern
lang: sql
platform: oracle
scope: tuning
since: "v0.1"
tested_on: "Oracle 19c"
tags: [explain-plan, dbms_xplan]
description: "Plan table setup and display helpers"
---
-- Create plan table once per schema if missing
@?/rdbms/admin/utlxplan.sql

-- Example usage
EXPLAIN PLAN FOR
SELECT /* test */ * FROM accounts WHERE email = :b1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE +PROJECTION'));

-- Compare actual execution stats after run
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

---

### 7) Ansible — users & groups (idempotent)

```yaml
---
# id: ansible/users-and-groups
# tags: [ansible, users, groups]
- name: Manage local users and groups
  hosts: all
  become: true
  tasks:
    - name: Ensure groups exist
      group:
        name: "{{ item }}"
        state: present
      loop: ["dba", "devops"]

    - name: Ensure users exist with groups
      user:
        name: "{{ item.name }}"
        groups: "{{ item.groups | join(',') }}"
        append: true
        shell: /bin/bash
        state: present
      loop:
        - { name: "svc_apex", groups: ["dba"] }
        - { name: "svc_ci", groups: ["devops"] }
```

---

### 8) Ansible — PostgreSQL DB & role

```yaml
---
# id: ansible/postgres-db-user
# tags: [ansible, postgres]
- name: Create Postgres DB and role
  hosts: db
  become: true
  vars:
    db_name: appdb
    db_user: appuser
    db_pass: "{{ vault_appdb_password }}"
  tasks:
    - name: Ensure database present
      community.postgresql.postgresql_db:
        name: "{{ db_name }}"

    - name: Ensure role present
      community.postgresql.postgresql_user:
        name: "{{ db_user }}"
        password: "{{ db_pass }}"
        db: "{{ db_name }}"
        privileges: CONNECT
```

---

### 9) Python — retry with bounded jitter decorator

```python
"""
id: python/retry-with-jitter
lang: python
since: "v0.1"
tags: [retry, jitter, decorator]
description: "Transient-safe retry with cap + jitter"
"""
import random, time, functools

class RetryableError(Exception):
    pass

def retry(max_attempts=5, base=0.25, cap=4.0):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            attempt = 0
            while True:
                try:
                    return fn(*args, **kwargs)
                except RetryableError as e:
                    attempt += 1
                    if attempt >= max_attempts:
                        raise
                    sleep = min(cap, base * (2 ** (attempt - 1)))
                    sleep += random.uniform(0, sleep * 0.2)  # ±20% jitter
                    time.sleep(sleep)
        return wrapper
    return deco
```

---

### 10) Bash — strict mode + logging skeleton

```bash
#!/usr/bin/env bash
# id: bash/strict-mode
# since: v0.1
# tags: [bash, strict, logging]
set -Eeuo pipefail
IFS=$'\n\t'

log() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }
trap 'log "ERR at line $LINENO"' ERR

usage(){ echo "Usage: $0 [-n]"; }
while getopts ":n" opt; do
  case "$opt" in
    n) DRYRUN=1 ;;
    :) usage; exit 2 ;;
  esac
done

main(){
  log "Starting"
  # your code here
  log "Done"
}
main "$@"
```

---

### 11) GitHub — PR template & CI

**.github/pull_request_template.md**

```md
---
id: github/pr-template
---
## What & Why

## How to Test

## Checklist
- [ ] Lints pass
- [ ] Backwards compatible
- [ ] Docs updated (if needed)
```

**.github/workflows/python-ci.yml**

```yaml
name: python-ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install pytest
      - run: pytest -q
```

---

## Repo hygiene

**.editorconfig**

```
root = true
[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true
indent_style = space
indent_size = 2
```

**.gitattributes**

```
* text=auto eol=lf
*.sh linguist-language=Shell
*.sql linguist-language=SQL
```

**LICENSE** → MIT (or org standard).

**CONTRIBUTING.md** → short guide on snippet headers, testing, and PR flow.

---

## Tools — quick grep helper (optional)

A tiny Python helper to search headers by `id:`/`tags:` and print paths.

```python
# tools/grep-snippets.py
import sys, re, pathlib, yaml
root = pathlib.Path(__file__).resolve().parents[1] / 'templates'
pattern = sys.argv[1] if len(sys.argv) > 1 else ''
for p in root.rglob('*.*'):
    if p.suffix in {'.sql', '.yml', '.yaml', '.md', '.py', '.sh'}:
        head = ''.join(p.read_text(encoding='utf-8').splitlines(True)[:30])
        m = re.search(r'^---\n(.*?)\n---', head, re.S)
        if not m: continue
        meta = yaml.safe_load(m.group(1))
        hay = ' '.join(map(str, meta.values())).lower()
        if pattern.lower() in hay:
            print(f"{p} :: {meta.get('id')} :: {meta.get('tags')}")
```

---

## Next steps

1. Initialize a new repo with this scaffold.
2. Add organization‑specific READMEs under `apex/`, `ords/`, and `security/` as you discover DPI conventions.
3. In daily work, when you craft a good snippet, wrap it with the YAML header and drop it in the right folder.
4. We’ll later add a `Makefile` or `uv`/`pipx` tasks to lint snippets (shellcheck, sqlfluff, yamllint).

> Guiding principle: **opt for tiny, trustworthy snippets over frameworks**. If it takes longer than 60 seconds to paste and adapt, it’s too big for this repo.
