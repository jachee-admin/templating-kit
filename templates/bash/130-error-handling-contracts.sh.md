###### Bash

# Error-Handling Contracts: Status vs Data, Retries, Taxonomy, and Pipeline Truth

Make failures **predictable** and **actionable**. Separate data from diagnostics, classify errors, propagate exit codes consistently, and only retry what’s retryable.

## TL;DR

* **Stdout = data, Stderr = diagnostics.**
* **Functions return status**, not data. Emit data on stdout, log to stderr.
* Guard rails: `set -Eeuo pipefail`, but don’t rely on it alone—**check critical steps explicitly**.
* Define a **retry policy** only for transient classes (HTTP 429/5xx, ECONNRESET, timeouts).
* Preserve **original exit codes**; map to a small, documented set at the boundary.

---

## Contract: return status, print data

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Print data to stdout, log to stderr, return 0/!0.
read_key() {
  local file="$1"
  [[ -r "$file" ]] || { echo "not readable: $file" >&2; return 2; }
  head -n1 -- "$file"
}

if key="$(read_key "/etc/myapp/secret.key")"; then
  printf '%s\n' "$key"
else
  rc=$?
  printf 'read_key failed (rc=%d)\n' "$rc" >&2
  exit "$rc"
fi
```

**Why:** Callers can pipe the data. Scripts retain meaningful status codes for automation.

---

## Set flags & their caveats

```bash
set -Eeuo pipefail
# -E: keep ERR trap in functions/subshells
# -e: exit on uncaught non-zero (but beware! suppressed in some contexts)
# -u: treat unset vars as errors
# pipefail: propagate failure across pipelines
```

**Caveat:** `set -e` is ignored inside `if cmd; then`, `while`, `until`, and in `|| true` patterns. Still explicitly check outcomes for critical operations.

---

## Capturing pipeline status precisely

```bash
set -o pipefail
if ! out="$(cmd1 | cmd2 | cmd3)"; then
  # Stage-by-stage statuses
  mapfile -t codes < <(printf '%s\n' "${PIPESTATUS[@]}")
  echo "pipeline failed: ${codes[*]}" >&2
  exit 1
fi
printf '%s\n' "$out"
```

---

## Error taxonomy: decide what to retry

```bash
classify_http() {
  case "$1" in
    200|201|204) echo ok ;;
    408|429|500|502|503|504) echo retry ;;
    4*) echo fatal ;;
    5*) echo retry ;;
    *) echo unknown ;;
  esac
}

classify_errno() {
  # Map common errno (from strace or tool stderr parsing)
  case "$1" in
    ECONNRESET|ETIMEDOUT|EHOSTUNREACH|ENETDOWN) echo retry ;;
    EACCES|EPERM|ENOENT) echo fatal ;;
    *) echo unknown ;;
  esac
}
```

---

## Retry policy: exponential backoff with jitter

```bash
jitter_sleep() {
  local attempt="$1" base=1 cap=30
  local max=$(( base << (attempt-1) )); (( max > cap )) && max=$cap
  awk -v m="$max" 'BEGIN{srand(); printf "%.3f\n", (rand()*m)}'
}

with_retry() {
  local max="${1:-5}"; shift
  local attempt=1
  while :; do
    if "$@"; then return 0; fi
    rc=$?
    case "$rc" in
      75)  # EX_TEMPFAIL (transient)
        sleep "$(jitter_sleep "$attempt")"
        (( attempt++ <= max )) || return "$rc"
        ;;
      *) return "$rc" ;;
    esac
  done
}
```

**Note:** Adopt the BSD `sysexits(3)` vocabulary where useful. Example: `75` = `EX_TEMPFAIL` for retryable failures.

---

## Wrap external commands with classified exits

```bash
# Curl wrapper: set exit code 75 on retryable HTTP statuses
fetch_json() {
  local url="$1" tmpd status
  tmpd="$(mktemp -d)"; trap 'rm -rf -- "$tmpd"' RETURN
  status="$(curl -sS -w '%{http_code}' -o "$tmpd/b" --connect-timeout 5 --max-time 30 "$url" || echo 000)"
  case "$(classify_http "$status")" in
    ok)    cat "$tmpd/b"; return 0 ;;
    retry) cat "$tmpd/b" >&2; return 75 ;;
    fatal) cat "$tmpd/b" >&2; return 22 ;;  # 22 mirrors curl --fail behavior
    *)     echo "unknown http status: $status" >&2; return 1 ;;
  esac
}
with_retry 6 fetch_json "https://api.example.test/items" | jq .
```

---

## Boundary mapping: present clean exit codes

```bash
# Internal functions return granular codes; map to a compact set at the CLI boundary.
main() {
  if ! do_things; then
    case "$?" in
      2)  echo "usage error" >&2;  exit 2 ;;   # EX_USAGE
      22) echo "remote rejected" >&2; exit 7 ;; # map to a CLI doc'd code
      75) echo "temporary failure" >&2; exit 75;;
      *)  echo "unexpected failure" >&2; exit 1 ;;
    esac
  fi
}
```

---

## Ensure cleanup even on errors

```bash
tmpd="$(mktemp -d)"
cleanup() { [[ -d $tmpd ]] && rm -rf -- "$tmpd"; }
trap cleanup EXIT
trap 'echo "ERR line $LINENO rc=$?" >&2' ERR
```

---

## Surface structured errors (for callers)

```bash
# Print machine-readable error envelope to stderr (JSON)
fail_json() {
  local code="$1"; shift
  jq -nc --arg msg "$*" --arg code "$code" --arg ts "$(date +%s)" \
    '{error:{code:$code, msg:$msg, ts:($ts|tonumber)}}' >&2
  return "$code"
}

# Use:
[[ -r "$cfg" ]] || fail_json 2 "config not readable: $cfg"
```

---

## Testing your contracts (bats)

```bash
# test/error_contracts.bats
@test "read_key returns 2 when file missing" {
  run bash -c 'source ./130-error-handling-contracts.sh && read_key /nope'
  [ "$status" -eq 2 ]
  [[ "$output" == *"not readable"* ]]  # stderr captured by bats as $output in run -c?
}
```

---

```yaml
---
id: docs/bash/130-error-handling-contracts.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2, curl 8.x, jq 1.7"
tags: [bash, errors, retries, backoff, pipefail, contracts, exit-codes, stderr]
description: "A disciplined error-handling model: stdout vs stderr, pipeline status, retry taxonomy, jitter backoff, and boundary exit-code mapping."
---
```
