###### APEX

# CSV Import via APEX File Browse: Parser, Preview, and Safe Commit Pattern

Empower business users (or yourself) to upload CSVs directly through the APEX UI—safely, predictably, and with validation before commit.

---

## TL;DR

* Use a **File Browse item** and `apex_data_parser.parse` to read uploaded CSVs.
* Always stage parsed rows in a **temporary table or APEX collection** before writing to target tables.
* Provide a **preview report** so users can review and confirm before commit.
* Use `LOG ERRORS` or validation procedures to trap data issues early.
* Clean up uploaded BLOBs (or expire files) after processing.

---

## 1️⃣ Page Setup

**Page Items**

* `P70_FILE` — File Browse item (Storage Type: *Table APEX_APPLICATION_TEMP_FILES*).
* `P70_PREVIEW` — (optional) hidden field or region item for JSON preview toggle.

**Buttons**

* `Parse` → PL/SQL process calling `apex_data_parser.parse`.
* `Commit` → PL/SQL process inserting staged rows into target tables.
* `Cancel` → cleans up collection/temp table.

---

## 2️⃣ Parse Uploaded File

```plsql
declare
  l_file   apex_application_temp_files%rowtype;
  l_data   apex_data_parser.t_data;
  l_count  number := 0;
begin
  select * into l_file
  from apex_application_temp_files
  where name = :P70_FILE;

  l_data := apex_data_parser.parse(
               p_content         => l_file.blob_content,
               p_file_name       => l_file.filename,
               p_add_headers_row => 'Y');

  apex_collection.create_or_truncate_collection('CSV_STAGE');

  for i in 1 .. l_data.count loop
    apex_collection.add_member(
      p_collection_name => 'CSV_STAGE',
      p_c001 => l_data(i).col001,
      p_c002 => l_data(i).col002,
      p_c003 => l_data(i).col003,
      p_c004 => l_data(i).col004);
    l_count := l_count + 1;
  end loop;

  :P70_PREVIEW := 'Y';
  apex_debug.message('Parsed %s rows from %s', l_count, l_file.filename);
end;
```

This converts the uploaded BLOB into structured rows, staged in a temporary APEX collection.

---

## 3️⃣ Preview Region (SQL Source)

```sql
select seq_id,
       c001 as col1,
       c002 as col2,
       c003 as col3,
       c004 as col4
from apex_collections
where collection_name = 'CSV_STAGE'
```

Users can review and correct input before final commit.

---

## 4️⃣ Commit to Target Table

```plsql
declare
  l_rows number := 0;
begin
  for r in (
    select c001 col1, c002 col2, c003 col3, c004 col4
    from apex_collections where collection_name='CSV_STAGE'
  ) loop
    begin
      insert into target_table (col1, col2, col3, col4)
      values (r.col1, r.col2, r.col3, r.col4);
      l_rows := l_rows + 1;
    exception
      when others then
        insert into csv_import_errors(row_data, err_msg)
        values (r.col1||','||r.col2||','||r.col3||','||r.col4, sqlerrm);
    end;
  end loop;

  apex_collection.delete_collection('CSV_STAGE');
  apex_debug.message('Committed %s rows to target_table', l_rows);
end;
```

*Optional:* Use `LOG ERRORS` if your table has a defined error log via `DBMS_ERRLOG.CREATE_ERROR_LOG`.

---

## 5️⃣ Clean Up Uploaded Files

To remove uploaded files from the temporary storage table:

```plsql
begin
  delete from apex_application_temp_files
  where name = :P70_FILE;
end;
```

---

## 6️⃣ Enhancements & Hardening

* **Validation** – Add a package procedure to check datatypes, required fields, duplicates.
* **Large Files** – For 10 MB+, use `apex_data_parser.parse` with `p_max_rows` and process in chunks.
* **Logging** – Create a `CSV_IMPORT_LOG` table recording filename, user, upload time, row count, errors.
* **Reusable Pattern** – Wrap the entire pattern in a reusable package (`pkg_csv_import.upload_and_stage`).
* **Security** – Restrict File Browse item to authenticated users only; never trust header-derived column names.

---

## Notes

* `apex_data_parser` supports CSV, XLSX, JSON, XML — same logic applies.
* Collections are volatile (cleared on session end), which is perfect for ephemeral uploads.
* Use a background `DBMS_SCHEDULER` job for large asynchronous imports.
* For pipelines, combine this with the **App Export Checklist** and **SQL Developer Import** cards to cover both GUI and CLI ingest workflows.

---

```yaml
---
id: docs/apex/70-csv-import-apex-file-browse.md
lang: plsql
platform: apex
scope: data-load
since: "v0.1"
tested_on: "APEX 24.2"
tags: [apex, csv, file-browse, apex_data_parser, collections, staging, import, validation]
description: "Self-service CSV import via File Browse and apex_data_parser, with preview, validation, and safe commit patterns."
---
```

