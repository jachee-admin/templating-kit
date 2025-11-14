###### Oracle PL/SQL
### Package constants + one-time init
Centralize shared types/constants; run a small init block exactly once per session.

```sql
CREATE OR REPLACE PACKAGE app_env AS
  c_app_name CONSTANT VARCHAR2(30) := 'NC-DPI';
  SUBTYPE t_email IS VARCHAR2(320);
  FUNCTION version RETURN VARCHAR2;
END app_env;
/
CREATE OR REPLACE PACKAGE BODY app_env AS
  g_version VARCHAR2(10);
  PROCEDURE init IS BEGIN g_version := 'v0.2'; END;
  FUNCTION version RETURN VARCHAR2 IS BEGIN RETURN g_version; END;
BEGIN
  init; -- runs once per session when package is first referenced
END app_env;
/
```

```yaml
---
id: docs/sql/oracle/110-package-constants-init.sql.md
lang: sql
platform: oracle
scope: plsql
since: "v0.2"
tested_on: "Oracle 19c"
tags: [plsql, package, constants, initialization]
description: "Package with constants, types, and one-time initialization in the package body"
---
```