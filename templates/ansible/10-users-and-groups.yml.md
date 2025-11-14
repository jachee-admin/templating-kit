---
id: ansible/users-and-groups
lang: yaml
scope: config-mgmt
since: "v0.1"
tags: [ansible, users, groups]
description: "Idempotent local users and groups"
---

### Ansible: User/Groups playbook
```yaml
- name: Manage local users and groups
  hosts: all
  become: true
  tasks:
    - name: Ensure groups exist
      group:
        name: "{{ item }}"
        state: present
      loop: ["dba", "devops"]

    - name: Ensure users exist with groups
      user:
        name: "{{ item.name }}"
        groups: "{{ item.groups | join(',') }}"
        append: true
        shell: /bin/bash
        state: present
      loop:
        - { name: "svc_apex", groups: ["dba"] }
        - { name: "svc_ci", groups: ["devops"] }
```
