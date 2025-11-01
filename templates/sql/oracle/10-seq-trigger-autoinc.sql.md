---
id: sql/oracle/seq-trigger-autoinc
lang: sql
platform: oracle
scope: triggers
since: "v0.1"
tested_on: "Oracle 19c"
tags: [sequence, trigger, autoincrement]
description: "Assign nextval only when PK is NULL"
---
###### Oracle PL/SQL
### Sequence / Trigger
```sql
-- Sequence
CREATE SEQUENCE acct_seq START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Trigger
CREATE OR REPLACE TRIGGER acct_bi
BEFORE INSERT ON accounts
FOR EACH ROW
WHEN (NEW.id IS NULL)
BEGIN
  :NEW.id := acct_seq.NEXTVAL;
END;
/
```
