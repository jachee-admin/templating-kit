###### APEX

# APEX Collections: Bulk/Wizard Staging Before Commit

## TL;DR

* Use **collections** to stage multi-page input; write to base tables at the end.
* Each row = one member; store JSON payload in `c001` or key fields in `c00x`.

## Script

```plsql
-- Page 1 (Add/Update staged row)
begin
    apex_collection.create_or_truncate_collection('WIZ_USERS');
    apex_collection.add_member(
        p_collection_name => 'WIZ_USERS',
        p_c001 => :P10_EMAIL,
        p_c002 => :P10_NAME,
        p_c003 => :P10_ROLE,
        p_c010 => to_char(systimestamp,'yyyy-mm-dd"T"hh24:mi:ss.ff3'));
end;
```

```sql
-- Report region SQL (Preview page)
select seq_id,
       c001 as email, c002 as name, c003 as role, c010 as added_at
from apex_collections
where collection_name = 'WIZ_USERS'
```

```plsql
-- Finish (commit to base table)
begin
  for r in (
    select c001 email, c002 name, c003 role
    from apex_collections where collection_name='WIZ_USERS'
  ) loop
    merge into app_user u
    using (select r.email email from dual) s
    on (u.email = s.email)
    when matched then update set u.name = r.name, u.role = r.role
    when not matched then insert (email, name, role) values (r.email, r.name, r.role);
  end loop;
  apex_collection.delete_collection('WIZ_USERS');
end;
```

## Notes

* Great for **wizard** UX, CSV imports, and multi-row validation before commit.
* If you need strict types, store JSON in `c001` and parse at write time.

```yaml
---
id: templates/apex/50-collections-wizard.apex.md
scope: staging
tags: [collections, wizard, bulk, staging]
description: "Stage multi-page input with APEX collections; preview and commit safely."
---
```
