###### APEX

# REST Outbound: `apex_web_service` JSON GET/POST with Headers + Retry

## TL;DR

* Define a Web Credential in APEX; reference it in calls.
* Always set `p_wallet_path` if required (on-prem TLS).
* Parse with `apex_json.get_*` or SQL/JSON.

## Script

```plsql
declare
    l_url    varchar2(4000) := 'https://api.example.com/v1/things';
    l_res    clob;
    l_status pls_integer;
begin
    apex_web_service.g_request_headers(1).name  := 'Accept';
    apex_web_service.g_request_headers(1).value := 'application/json';

    l_res := apex_web_service.make_rest_request(
               p_url                  => l_url,
               p_http_method          => 'GET',
               p_credential_static_id => 'API_CRED');

    l_status := apex_web_service.g_status_code;

    if l_status between 200 and 299 then
        apex_json.parse(l_res);
        for i in 1..apex_json.get_count(p_path=>'$.items') loop
            insert into api_thing(id, name)
            values (apex_json.get_varchar2('$.items[%d].id', i),
                    apex_json.get_varchar2('$.items[%d].name', i));
        end loop;
        commit;
    else
        raise_application_error(-20001, 'BR:API failed '||l_status);
    end if;
end;
/
```

## Notes

* Use **Web Credential** (Static ID: `API_CRED`) for auth; don’t embed secrets.
* For large responses, LOAD into a CLOB and parse iteratively; avoid giant collections.

```yaml
---
id: docs/apex/30-rest-outbound.apex.md
scope: integration
tags: [apex_web_service, apex_json, rest, credentials]
description: "Outbound REST GET/POST with headers and JSON parsing into a table."
---
```
