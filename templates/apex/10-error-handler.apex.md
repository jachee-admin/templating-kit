###### APEX

# App-wide Error Handler: Structured Messages, Logging, and Friendly UX

## TL;DR

* Use **Application → Error Handling Function**.
* For known business errors, show user-friendly text; log full tech detail with `apex_debug`.
* Return `apex_error.t_error_result` with `message`, `additional_info`, `page_item_name` as needed.

## Script

```plsql
create or replace function app_error_handler(
    p_error in apex_error.t_error )
  return apex_error.t_error_result
is
    l_result apex_error.t_error_result := apex_error.init_error_result(p_error => p_error);
    l_is_business boolean := false;
begin
    -- Example: tag business rule exceptions by prefix
    if p_error.message like 'BR:%' then
        l_is_business := true;
        l_result.message := substr(p_error.message, 4); -- strip 'BR:'
        l_result.display_location := apex_error.c_on_error_page;
    end if;

    -- Always log rich context
    apex_debug.message('ERR: %s | code=%s | comp=%s | page=%s | session=%s',
        p_error.message, p_error.ora_sqlcode, p_error.component.type,
        v('APP_PAGE_ID'), v('APP_SESSION'));

    if not l_is_business then
        -- Normalize ORA- errors -> tidy message
        l_result.message := apex_error.get_first_ora_error_text(p_error);
    end if;

    return l_result;
end;
/
```

## Notes

* Set at **Application → Definition → Error Handling**.
* Use `BR:` prefix (or an app-specific pragma) to distinguish user-safe messages.

```yaml
---
id: docs/apex/10-error-handler.apex.md
scope: errors
tags: [apex_error, apex_debug, handler]
description: "Global error handler that logs rich context and shows user-friendly messages."
---
```
