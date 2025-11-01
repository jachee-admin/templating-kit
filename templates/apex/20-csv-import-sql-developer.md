---
id: apex/csv-import-sql-developer
since: "v0.1"
tags: [sql-developer, csv, import]
description: "CSV import: quick notes"
---

- Use SQL Developer wizard; set proper datatypes and date masks
- Stage into a raw table first; then transform into target tables
- Keep `LOG ERRORS` patterns for bulk loads (see Oracle snippet)
