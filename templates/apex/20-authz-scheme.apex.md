###### APEX

# Authorization Scheme: Role Checks via Table or JWT Claims

## TL;DR

* Centralize role checks in one scheme function.
* Cache roles in session state (`apex_util.set_session_state`).
* Keep it **read-only** inside apps; manage roles in DB/IDP.

## Script

```plsql
-- Table: APP_USER_ROLE(user_name, role_name)
create or replace function auth_has_role(p_role in varchar2)
return boolean
is
    l_user varchar2(128) := lower(v('APP_USER'));
    l_yes  number;
begin
    select count(*) into l_yes
    from app_user_role
    where user_name = l_user
      and role_name = p_role;

    return l_yes > 0;
end;
/

-- Authorization Scheme (PL/SQL Function Returning Boolean)
-- return auth_has_role('ADMIN');
```

### Variation: From JWT/OAuth claim stored in session

```plsql
create or replace function auth_has_claim(p_claim in varchar2)
return boolean
is
    l_claim apex_util.get_session_state('G_CLAIMS'); -- e.g. JSON from post-auth
    l_val   varchar2(4000);
begin
    if l_claim is null then return false; end if;
    l_val := json_value(l_claim, '$."'||p_claim||'"');
    return l_val in ('1','true','TRUE');
end;
/
```

## Notes

* Apply the scheme on **pages, regions, buttons, processes**.
* Keep one scheme per *policy*, not per component.

```yaml
---
id: templates/apex/20-authz-scheme.apex.md
scope: auth
tags: [authorization, roles, jwt, session_state]
description: "Reusable Authorization Scheme to gate UI/processes by roles or claims."
---
```
