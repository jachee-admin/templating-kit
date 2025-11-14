---
id: github/python-ci
lang: yaml
since: "v0.1"
tags: [github-actions, python, ci]
description: "Minimal Python CI on push/PR"
---

### Github: Actions
```yaml
name: python-ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install pytest
      - run: pytest -q
```
