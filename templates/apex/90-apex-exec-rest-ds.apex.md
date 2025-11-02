

---

**File: `90-apex-exec-rest-ds.apex.md`**

---

###### APEX

# `apex_exec` Patterns: REST/Data Source Modules, Binds, Pagination, and JSON

Query REST/Data Source Modules and programmatically iterate rows as if they were tables. Great for transformations, staging, and custom processes.

---

## TL;DR

* Use **Web Source / REST Data Source** modules with a **Static ID**.
* Open with `apex_exec.open_web_source_query` or `open_remote_sql_query`.
* Bind values via `p_parameters` and **get columns by name**.
* Use `fetch_rows` in loops; close cursors with `apex_exec.close`.
* For large payloads, process in pages (offset/limit).

---

## 1) GET a REST Data Source and Insert to a Table

Assumes a REST Data Source named **`WS_THINGS`** (Static ID).

```plsql
declare
  l_ctx apex_exec.t_context;
  l_rc  apex_exec.t_rows_count;
begin
  l_ctx := apex_exec.open_web_source_query(
              p_module_static_id => 'WS_THINGS',
              p_parameters       => apex_exec.t_parameters(
                                      apex_exec.t_parameter('limit','100'),
                                      apex_exec.t_parameter('q','status:active')
                                   ));

  loop
    l_rc := apex_exec.fetch_rows(p_context => l_ctx, p_max_rows => 100);
    exit when l_rc.fetched_rows = 0;

    for i in 1 .. l_rc.fetched_rows loop
      insert into thing_dim(id, name, updated_at)
      values (
        apex_exec.get_varchar2(l_ctx, i, 'id'),
        apex_exec.get_varchar2(l_ctx, i, 'name'),
        apex_exec.get_timestamp_tz(l_ctx, i, 'updatedAt')
      );
    end loop;

    commit;
  end loop;

  apex_exec.close(l_ctx);
end;
/
```

> Tip: Column names map to the REST DS response fields (case-insensitive by default). Use **Column Mappings** in the REST DS definition for consistency.

---

## 2) POST with Body, Then Read Result

```plsql
declare
  l_ctx apex_exec.t_context;
begin
  l_ctx := apex_exec.open_web_source(
             p_module_static_id => 'WS_CREATE_ORDER',
             p_operation        => 'POST',
             p_body_clob        => json_object('customerId' value :P10_CUST_ID, 'amount' value :P10_AMOUNT)
           );

  -- If API returns a rowset (e.g., created order), fetch it:
  if apex_exec.has_rows(l_ctx) then
    apex_exec.fetch_rows(l_ctx, 1);
    :P10_ORDER_ID := apex_exec.get_varchar2(l_ctx, 1, 'id');
  end if;

  apex_exec.close(l_ctx);
end;
/
```

---

## 3) Remote SQL (Database Link / REST Enabled SQL)

Query a **Remote SQL** module (e.g., REST Enabled SQL or DB Link-backed DS).

```plsql
declare
  l_ctx apex_exec.t_context;
  l_count apex_exec.t_rows_count;
begin
  l_ctx := apex_exec.open_remote_sql_query(
             p_connection_static_id => 'REMOTE_CONN',
             p_sql_query            => 'select deptno, dname from dept where loc = :loc',
             p_sql_bind_parameters  => apex_exec.t_parameters(
                                         apex_exec.t_parameter('loc', :P10_LOC)));

  loop
    l_count := apex_exec.fetch_rows(l_ctx, 200);
    exit when l_count.fetched_rows = 0;

    for i in 1 .. l_count.fetched_rows loop
      insert into dept_stage(deptno, dname)
      values (
        apex_exec.get_number(l_ctx, i, 'DEPTNO'),
        apex_exec.get_varchar2(l_ctx, i, 'DNAME')
      );
    end loop;
    commit;
  end loop;

  apex_exec.close(l_ctx);
end;
/
```

---

## 4) Read Raw JSON (When You Need It)

```plsql
declare
  l_ctx apex_exec.t_context;
  l_json clob;
begin
  l_ctx := apex_exec.open_web_source_query('WS_THINGS');
  l_json := apex_exec.get_resource(l_ctx); -- raw response body (clob)
  apex_exec.close(l_ctx);

  apex_json.parse(l_json);
  -- parse as needed...
end;
/
```

---

## Notes

* Define **Web Credentials**; never embed secrets—reference by Static ID.
* Tune **p_max_rows** and commit frequency for large pulls.
* Use **apex_debug.enable** to see request/response in debug mode.
* For strict typing, map DS columns in the module and use the typed getters (`get_date`, `get_timestamp_tz`, etc.).

---

```yaml
---
id: templates/apex/90-apex-exec-rest-ds.apex.md
lang: plsql
platform: apex
scope: integration
since: "v0.1"
tested_on: "APEX 24.2"
tags: [apex_exec, rest, web-source, remote-sql, pagination, credentials]
description: "Open, bind, and iterate REST/Data Source modules using apex_exec; patterns for GET/POST, pagination, remote SQL, and raw JSON."
---
```

---

Say the word when you’re ready for the next batch: **100 RLS/VPD**, **110 ORDS/Headers**, and **120 App Logging**.
