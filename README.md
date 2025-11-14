# Firebreak Templates Repository

Reusable, production-ready **code templates** and **reference patterns** for Bash, Perl, Oracle PL/SQL, and APEX.
Each language section is structured for **clarity, reuse, and mentoring**—short, annotated examples that can be dropped directly into real projects.

> Philosophy: clarity over cleverness.
> Every template should be readable six months from now without guessing what past-you meant.

---

## Repository Layout

```
templates/
├── bash/         # Shell scaffolds and ops snippets
├── perl/         # Scripting and system patterns
├── plsql/        # Database / Oracle logic building blocks
└── apex/         # APEX automation, REST, and UI patterns
```

Each directory contains numbered `.md` cards (e.g. `10-strict-mode.sh.md`) with:

* short **summary + TL;DR**
* **annotated code block**
* **Notes** explaining usage, gotchas, and conventions
* **YAML footer** for tagging, indexing, and automated documentation

---

## Bash Templates

> **Scope:** automation, logging, safety, rotation, CI/CD glue

Highlights:

* **10-strict-mode.sh.md** – baseline strict mode scaffold (safe flags, logging, traps, dry-run)
* **20-log-rotate-skel.sh.md** – rotate/compress logs with retention
* **30+ series** – argument parsing, retry patterns, health checks, and more

---

## Perl Templates

> **Scope:** utilities, data ingest, modern Perl idioms

Highlights:

* **Perl Templating Kit** – master reference covering CLI scaffolds, argument parsing, CSV/JSON, DBI, and retry logic
* **145–150 series** – full OO lineage (packages → roles → Moo quickstart)
* Covers resilient file I/O, `Text::CSV_XS`, `HTTP::Tiny`, concurrency, test frameworks, and modern CPAN picks

---

## PL/SQL Templates

> **Scope:** database logic, bulk operations, and API design

Includes:

* **collections**, **BULK COLLECT/FORALL**, **DBMS_SQL**, **dynamic SQL**, and **transaction control**
* date/time helpers, trigger patterns, and instrumentation packages
* **autonomous transactions**, **RLS policies**, and **error logging** best practices

Each file is structured for schema devs working in CI/CD or ORDS environments.

---

## APEX Templates

> **Scope:** app lifecycle, automation, UI, and integration

Key cards:

* **01-app-export-checklist.md** – pre-flight before exporting apps for version control
* **05-csv-import-sql-developer.md** – structured CSV import workflow via SQL Developer
* **70-csv-import-apex-file-browse.md** – self-service import with `apex_data_parser`
* **71-apex-csv-async-scheduler.md** – async large-file imports with `DBMS_SCHEDULER`
* **72-csv-import-demo-app-spec.md** – full demo app spec (upload → enqueue → monitor)
* **90-apex-exec-rest-ds.md** – integration patterns with REST Data Source modules
* **100–120 series** – RLS/VPD, ORDS headers, and application logging practices

---

## Conventions

* Language ID in filename and metadata (`lang: bash|perl|plsql|javascript`).
* Descriptive YAML footer for easy indexing by scripts or static doc builders.
* Markdown code fences for syntax highlighting.
* All examples are **lint-clean**, **idempotent**, and designed to be runnable standalone.

---

## How to Use

1. Browse templates by language and purpose.
2. Copy fragments directly into your project or APEX code editor.
3. Customize variables, logging, and environment paths.
4. When satisfied, **commit both code and documentation** for your team.

> Every template doubles as teaching material—use it to onboard new devs, document internal standards, or run code reviews.

---

## Next Steps

Planned expansions:

* Bash → `40-healthcheck`, `50-api-call`, `60-notify-slack`
* Perl → `160-pdl-numeric`, `170-template-toolkit`
* APEX → `100-rls-vpd.md`, `110-ords-headers.md`, `120-app-logging.md`
* PL/SQL → modern test harnesses and bulk-ETL orchestration
