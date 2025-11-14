---
id: ansible/postgres-db-user
lang: yaml
scope: db
since: "v0.1"
tags: [ansible, postgres]
description: "Create a Postgres DB and role"
---

### Ansible: Postgres DB User
```yaml
- name: Create Postgres DB and role
  hosts: db
  become: true
  vars:
    db_name: appdb
    db_user: appuser
    db_pass: "{{ vault_appdb_password }}"
  tasks:
    - name: Ensure database present
      community.postgresql.postgresql_db:
        name: "{{ db_name }}"

    - name: Ensure role present
      community.postgresql.postgresql_user:
        name: "{{ db_user }}"
        password: "{{ db_pass }}"
        db: "{{ db_name }}"
        privileges: CONNECT
```
