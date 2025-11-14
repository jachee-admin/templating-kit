###### APEX

# Email & Files: `apex_mail` templating + BLOB download links

## TL;DR

* Build HTML emails; queue with `apex_mail.send`, then `apex_mail.push_queue`.
* Generate secure file links using `apex_util.get_blob_file_src`.

## Script

```plsql
-- Send HTML email
declare
  l_id number;
begin
  l_id := apex_mail.send(
    p_to        => :P0_EMAIL,
    p_from      => 'no-reply@example.org',
    p_subj      => 'Welcome!',
    p_body      => 'Plain text fallback',
    p_body_html => '<h3>Welcome to our app</h3><p>Glad you are here.</p>');
  apex_mail.push_queue; -- or run scheduler job
end;
/
```

```sql
-- Table T_FILES(id, filename, mime, content BLOB)
-- Region Source (Classic Report) to list files with download links:
select id,
       filename,
       mime,
       apex_util.get_blob_file_src(
         p_position => 1,
         p_content_disposition => 'attachment',
         p_table_name => 'T_FILES',
         p_primary_key_column => 'ID',
         p_primary_key_value => id,
         p_blob_column => 'CONTENT',
         p_filename => filename,
         p_mime_type => mime) as download_url
from t_files
```

## Notes

* Ensure `apex_instance_admin.set_parameter('SMTP_HOST_ADDRESS', ...)` is configured.
* For inline images, use `apex_mail.add_attachment` or CID references if needed.

```yaml
---
id: docs/apex/60-mail-files.apex.md
scope: messaging
tags: [apex_mail, email, blob, download]
description: "HTML email sending and secure BLOB download URLs."
---
```
