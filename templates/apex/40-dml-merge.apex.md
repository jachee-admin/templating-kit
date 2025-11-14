###### APEX

# Safe DML Process: MERGE with Optimistic Lock + APEX Items

## TL;DR

* Use a hidden `ROW_VERSION` (or `ORA_ROWSCN`) item to detect lost updates.
* In process, `MERGE` by PK **and** version; if `sql%rowcount=0`, report conflict.

## Script

```plsql
-- Table: T(ID PK, NAME, AMOUNT, ROW_VERSION number default 1)

declare
    l_updated number;
begin
    merge into t dst
    using (select :P10_ID id,
                  :P10_NAME name,
                  :P10_AMOUNT amount,
                  :P10_ROW_VERSION row_version
           from dual) src
    on (dst.id = src.id and dst.row_version = src.row_version)
    when matched then update set
        dst.name = src.name,
        dst.amount = src.amount,
        dst.row_version = dst.row_version + 1;

    l_updated := sql%rowcount;

    if l_updated = 0 then
        apex_error.add_error(
          p_message => 'Row changed by another user. Refresh and retry.',
          p_display_location => apex_error.c_inline_in_notification );
        apex_application.g_unrecoverable_error := true;
    end if;
end;
```

## Notes

* Bind directly to `:Pxx_*` items; add server-side validations for required fields.
* Prefer an explicit `ROW_VERSION` over `ORA_ROWSCN` for deterministic behavior.

```yaml
---
id: docs/apex/40-dml-merge.apex.md
scope: dml
tags: [merge, optimistic-lock, process, items]
description: "Update process using MERGE with row version check to prevent lost updates."
---
```
