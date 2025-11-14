###### Bash

# Testing & Linting: `bats` Unit Tests, `shellcheck` Gates, and CI Wiring

Treat shell like a real language: test behaviors, lint aggressively, and block merges when scripts regress.

## TL;DR

* **Lint first, test second.** Fail fast on style/bugs with `shellcheck`.
* Use **`bats-core`** for unit tests and golden-output checks.
* Isolate environment (tmpdirs, fake `$PATH`, captured FDs).
* In CI, run: `shellcheck`, `bats`, and a **smoke test** of installed artifacts.

---

## Project layout (suggested)

```
bin/
  myapp
lib/
  logging.sh
tests/
  unit/
    myapp_flags.bats
    logging.bats
  fixtures/
    sample.ini
  helpers/
    test_helpers.bash
```

---

## Install tools (dev box)

```bash
# Debian/Ubuntu
sudo apt-get install -y shellcheck bats
# Or latest bats-core via git
git clone https://github.com/bats-core/bats-core.git
sudo ./bats-core/install.sh /usr/local
```

---

## Common test helpers (`tests/helpers/test_helpers.bash`)

```bash
setup() {
  export TMPDIR="$(mktemp -d)"
  export PATH="$TMPDIR/bin:$PATH"
  mkdir -p "$TMPDIR/bin"
  # Fake dependencies (override external tools safely)
  printf '#!/usr/bin/env bash\necho 42\n' > "$TMPDIR/bin/jq"
  chmod +x "$TMPDIR/bin/jq"
}

teardown() {
  rm -rf -- "$TMPDIR"
}

# Capture both streams separately (bats' `run` captures stdout only)
run2() {
  stdout="$TMPDIR/stdout.$$"
  stderr="$TMPDIR/stderr.$$
"
  "$@" >"$stdout" 2>"$stderr"
  status=$?
  output="$(cat "$stdout")"
  errout="$(cat "$stderr")"
  return "$status"
}
```

> Helpers let you sandbox `$PATH`, stub commands, and capture stderr without polluting tests.

---

## Unit tests: flags & usage (`tests/unit/myapp_flags.bats`)

```bash
#!/usr/bin/env bats

load '../helpers/test_helpers.bash'

@test "--help prints usage and exits 0" {
  run ./bin/myapp --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "invalid flag exits 2 with message" {
  run ./bin/myapp --wat
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"Usage:"* ]]
}

@test "--version prints semver" {
  run ./bin/myapp --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
```

---

## Unit tests: behavior & JSON output (`tests/unit/logging.bats`)

```bash
#!/usr/bin/env bats

load '../helpers/test_helpers.bash'

@test "JSON logger emits keys" {
  run bash -c 'source ./lib/logging.sh; log_json info "hi"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"level\":\"info\""* ]]
  [[ "$output" == *"\"msg\":\"hi\""* ]]
}
```

---

## Golden-output test (stable text mode)

```bash
@test "scan emits stable list" {
  run ./bin/myapp scan tests/fixtures
  [ "$status" -eq 0 ]
  diff -u <(printf '%s\n' "tests/fixtures/sample.ini") <(printf '%s\n' "$output")
}
```

---

## Shellcheck gate (local)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s globstar
fail=0
for f in bin/** lib/**; do
  shellcheck -x "$f" || fail=1
done
exit "$fail"
```

**Flags**

* `-x` follows sourced files.
* Consider `-S error` to elevate warnings in CI later.

---

## Makefile snippets (dev ergonomics)

```make
SHELL := /usr/bin/env bash

.PHONY: lint test
lint:
\t@bash scripts/shellcheck_gate.sh

test:
\t@bats tests/unit

ci: lint test
```

---

## GitHub Actions (CI)

```yaml
# .github/workflows/shell-ci.yml
name: shell-ci
on: [push, pull_request]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install tools
        run: sudo apt-get update && sudo apt-get install -y shellcheck bats
      - name: Lint
        run: bash scripts/shellcheck_gate.sh
      - name: Unit tests
        run: bats tests/unit
      - name: Smoke install
        run: |
          install -D -m 0755 bin/myapp /usr/local/bin/myapp
          myapp --help >/dev/null
```

---

## Coverage-like signal (lightweight)

* Count unique code paths via `set -x` routing to a trace file and diff per test.
* Or instrument functions to increment counters and print a summary in teardown.

---

## Test doubles: fake network & time

```bash
# Freeze time for deterministic timestamps
date() { command date -u -d '@1730438400' +%FT%TZ; }  # 2025-11-01T00:00:00Z

# Fake curl for API tests
curl() { printf '{"status":"ok"}'; }
```

Place these stubs **inside the test script scope** so production code remains unmodified.

---

```yaml
---
id: docs/bash/150-testing-bats-shellcheck.sh.md
lang: bash
platform: posix
scope: testing
since: "v0.4"
tested_on: "bash 5.2, bats-core 1.11+, shellcheck 0.9+"
tags: [bash, testing, bats, shellcheck, ci, fixtures, sandbox]
description: "Unit tests with bats, aggressive shellcheck linting, sandboxed helpers, golden-output checks, and CI wiring with smoke installs."
---
```

