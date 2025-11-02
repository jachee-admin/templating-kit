###### APEX

# Demo App Spec: Async CSV Import (Upload → Enqueue → Background Parse → Monitor)

A small APEX app that lets users upload a CSV, runs the import in the background with `DBMS_SCHEDULER`, and shows live status + row-level errors.

---

## 0) Prereqs

* Database objects from **`71-apex-csv-async-scheduler.md`**:
  `CSV_UPLOADS`, `CSV_IMPORT_RUNS`, `CSV_IMPORT_ERRORS`, and `PKG_CSV_IMPORT`.
* Target table (example): `TARGET_TABLE(col1 varchar2(100), col2 date, col3 varchar2(100), col4 number)`.
* Job queue enabled: `ALTER SYSTEM SET job_queue_processes=20;`
* App-level Error Handling Function set (your `app_error_handler` from earlier card).

---

## 1) App Overview

* **Name**: CSV Import Demo
* **Alias**: `csv_import_demo`
* **Auth**: your standard scheme (e.g., APEX Accounts).
* **Role/Authorization Schemes**:

  * `ROLE_UPLOAD`: returns `auth_has_role('UPLOAD')`
  * `ROLE_ADMIN`: returns `auth_has_role('ADMIN')`

**Navigation (top level):**

* Upload & Run
* My Run Status
* Admin Runs

---

## 2) Pages

### Page 10 — Upload & Enqueue (User)

**Purpose**: Upload CSV, persist to BLOB table, enqueue background worker, show newly created RUN_ID.

**Regions**

* Region: “Upload CSV”
* Region: “Submission Result” (shows run id & quick link to status page; conditional when `P10_RUN_ID` not null)

**Items**

* `P10_FILE` — *File Browse* (Storage: `APEX_APPLICATION_TEMP_FILES`)
* `P10_RUN_ID` — *Hidden* (Number)
* `P10_TARGET_TABLE` — *Select List* (static default `TARGET_TABLE`; restrict to allowed targets)

**Buttons**

* `UPLOAD_ENQUEUE` (Hot) — authorized by `ROLE_UPLOAD`
* `GO_STATUS` (Normal) — condition: `P10_RUN_ID is not null`

**Process (after submit: UPLOAD_ENQUEUE)**

```plsql
declare
  l_temp apex_application_temp_files%rowtype;
  l_upload_id number;
begin
  if :P10_FILE is null then
     apex_error.add_error(p_message=>'Please choose a file to upload.',
       p_display_location=>apex_error.c_inline_in_notification);
     return;
  end if;

  select * into l_temp from apex_application_temp_files where name = :P10_FILE;

  insert into csv_uploads(filename, mime_type, uploaded_by, content)
  values (l_temp.filename, l_temp.mime_type, :APP_USER, l_temp.blob_content)
  returning upload_id into l_upload_id;

  :P10_RUN_ID := pkg_csv_import.submit_job(
                   p_upload_id    => l_upload_id,
                   p_target_table => :P10_TARGET_TABLE,
                   p_commit_every => 1000,
                   p_chunk_rows   => 5000);

  delete from apex_application_temp_files where name = :P10_FILE;
end;
```

**Branch**

* When Button Pressed = `UPLOAD_ENQUEUE` → **Redirect to Page 20** with `P20_RUN_ID=&P10_RUN_ID.`

**Validations**

* `P10_FILE` is not null.
* Optional: check file extension `.csv` and size (via `apex_error.add_error` pre-process).

---

### Page 20 — Run Status (User)

**Purpose**: Show the live progress for a single run; auto-refresh every few seconds.

**Items**

* `P20_RUN_ID` — *Hidden* (Number), passed from Page 10.

**Regions**

* “Import Status” (Classic/Interactive Report) — *Refresh* every 3–5s using region auto-refresh or DA timer.

**Region Source (Status)**

```sql
select run_id, status, processed_rows, error_rows, total_rows,
       case when total_rows > 0 then round(100*processed_rows/total_rows,1) end pct,
       message, created_at, started_at, finished_at
from csv_import_runs
where run_id = :P20_RUN_ID
```

**Region: “Errors” (IR)**

```sql
select row_num, err_msg, row_text, created_at
from csv_import_errors
where run_id = :P20_RUN_ID
order by row_num
```

**Dynamic Action (optional)**

* Event: *Page Load* → *Refresh* the two regions every 4s until `status in ('SUCCEEDED','FAILED')`.

**Buttons**

* `BACK_UPLOAD` (redirect to Page 10)
* `VIEW_TARGET` (optional) — link to a report page showing latest records in `TARGET_TABLE`.

---

### Page 30 — Admin Runs (Admin)

**Purpose**: Admin view of all runs with quick actions.

**Authorization**: `ROLE_ADMIN`

**Regions**

* “All Runs” (Interactive Report):

```sql
select run_id, uploaded_by, target_table, status,
       processed_rows, error_rows, total_rows,
       message, created_at, started_at, finished_at
from csv_import_runs r
join csv_uploads u on u.upload_id = r.upload_id
order by r.run_id desc
```

**Interactive Report Links**

* Link on `RUN_ID` → Page 20 with `P20_RUN_ID`.

**Buttons (optional)**

* `CANCEL_JOB` — calls `dbms_scheduler.stop_job` if you also store job names.
* `PURGE_UPLOAD` — deletes BLOBs older than N days (admin-only).

**Processes (optional)**

```plsql
-- Purge old blobs (e.g., older than 30d)
begin
  delete from csv_uploads
   where uploaded_at < add_months(trunc(sysdate), -1)
     and upload_id not in (select upload_id from csv_import_runs where finished_at is null);
  commit;
end;
```

---

## 3) Error Handling & UX

* Global **Error Handling Function** logs tech details; converts business errors (`BR:`) to user-friendly text.
* On Page 20, if `status='FAILED'`, show `message` prominently above the reports.
* Ensure **Public Pages** are restricted; all pages require auth.

---

## 4) Security

* Authorization scheme `ROLE_UPLOAD` on Page 10, `ROLE_ADMIN` on Page 30.
* Validate file type (`.csv`) and cap BLOB size.
* Lock down `pkg_csv_import` privileges to the parsing schema only.
* Don’t leak raw error stacks to end users; use `apex_debug` for detail.

---

## 5) Performance & Ops

* Tune `p_chunk_rows` (2k–20k typical).
* Commit every `p_commit_every` (500–2k).
* Consider `MERGE` for dedupe keys instead of `INSERT`.
* Add a retention policy for `csv_import_errors` and `csv_uploads.content`.
* Optional: add an index on `csv_import_errors(run_id, row_num)`.

---

## 6) Nice-to-Haves (Fast Follows)

* **Page 40: Target Browser** — IR on `TARGET_TABLE` with filters.
* **Cancel Button** on Page 20 if job still RUNNING (requires storing job name).
* **Email Notifications** after success/failure via `apex_mail` (store email on upload).
* **Audit Log** table: who uploaded, from where, how many rows inserted/failed.

---

## 7) Test Plan (Quick)

1. Upload a small well-formed CSV → status transitions RUNNING → SUCCEEDED; rows land in `TARGET_TABLE`.
2. Upload malformed rows → SUCCEEDED with non-zero `error_rows`; errors visible in Page 20.
3. Upload a ~50MB CSV → UI remains responsive; progress increments; finishes within expected window.
4. Permissions: non-admin can’t see Page 30; admin can.
5. Purge task removes old BLOBs and keeps recent ones.

---

## 8) CI/CD Notes

* Include schema DDL and `pkg_csv_import` in your repo.
* App export with **Split Files** enabled (see `01-app-export-checklist.md`).
* Use SQLcl/ORDS pipeline to import app, then run DDL package install.

---

```yaml
---
id: templates/apex/73-csv-import-demo-app-spec.md
lang: plsql
platform: apex
scope: app-spec
since: "v0.1"
tested_on: "APEX 24.2 / Oracle 23ai"
tags: [apex, csv, async, scheduler, spec, demo-app]
description: "APEX demo app spec for async CSV import: upload & enqueue, background worker, live status, and admin views."
---
```

