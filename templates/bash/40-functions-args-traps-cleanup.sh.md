###### Bash

# Functions, Args, Exit Codes, Traps & Cleanup Patterns

Functions are your unit of composition; traps are your seatbelts. This template shows robust argument handling, error propagation, and resource cleanup that survives signals and failures.

## Minimal Function Contract

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&2; }

die() { log "ERROR: $*"; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

main() {
  need curl jq

  local url="${1:-}"; [[ -n $url ]] || die "usage: $0 <url>"
  local out="${2:-/tmp/out.json}"

  log "Fetching $url"
  curl -fsS "$url" | jq . >"$out"
  log "Wrote $out"
}

main "$@"
```

**Notes:**

* `main "$@"` preserves word boundaries in args.
* `set -Eeuo pipefail` pairs with `die` for friendlier errors. `-E` keeps `ERR` trap across functions.

---

## Return Codes & Error Flow

```bash
maybe_do() {
  local path="$1"
  [[ -e "$path" ]] || return 2   # custom “not found”
  # ... work
}

if ! maybe_do "/etc/shadow"; then
  rc=$?
  (( rc == 2 )) && log "Skipping; not found" || die "maybe_do failed (rc=$rc)"
fi
```

**Pattern:** return **status**, print **data**. Avoid writing success messages to stdout; keep stdout for data.

---

## Argument Parsing (lightweight)

```bash
usage() {
  cat <<EOF
Usage: $0 [-n NAME] [-r] <file>
  -n NAME   Set name
  -r        Read-only mode
EOF
}

name="world"; readonly=false
while getopts ":n:r" opt; do
  case "$opt" in
    n) name="$OPTARG" ;;
    r) readonly=true ;;
    \?) usage; exit 2 ;;
    :)  echo "Missing arg for -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))

file="${1:-}"; [[ -n $file ]] || { usage; exit 2; }
```

For complex CLIs, consider `getopt(1)` (GNU) or a dedicated wrapper, but `getopts` is portable and good enough for most scripts.

---

## Traps: EXIT, ERR, and Signals

```bash
tmp_dir="$(mktemp -d)"
cleanup() {
  [[ -d $tmp_dir ]] && rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

# Fail-fast details:
# -E: propagate ERR to functions
# -o pipefail: pipeline fails if any command fails
trap 'log "ERR at line $LINENO (rc=$?)"' ERR
trap 'log "Interrupted"; exit 130' INT
```

**Gotchas:**

* Traps don’t run in subshells spawned with `(...)`.
* `set -e` ignores failures in some contexts (e.g., `if cmd; then`) — combine with explicit checks or `pipefail`.

---

## Subshell vs Current Shell

```bash
( cd /tmp && touch a )   # subshell; caller’s PWD unchanged
cd /tmp && touch b       # current shell; affects caller
```

Use subshells to sandbox environment changes; use current shell when you intend side effects.

---

## Robust Temporary Files

```bash
tmp="$(mktemp)"
exec 3>"$tmp"        # FD 3 for exclusive writes
printf 'payload\n' >&3
exec 3>&-            # close
rm -f -- "$tmp"
```

Prefer `mktemp` to avoid TOCTOU races; avoid predictable names in `/tmp`.

---

## Locking (flock)

```bash
# Single-instance script using flock on a lock file descriptor
lockfile="/var/lock/myjob.lock"
exec 9>"$lockfile" || exit 1
flock -n 9 || { echo "Another instance running"; exit 0; }

# critical section
do_work
```

On systems without `flock`, emulate with `mkdir` lock dirs.

---

## Background Jobs & Safe Wait

```bash
pids=()
for part in part-*.csv; do
  process_part "$part" &
  pids+=("$!")
done

fail=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then fail=1; fi
done
(( fail == 0 )) || die "one or more jobs failed"
```

Never `wait` without capturing PIDs — you might wait for the wrong process.

---

## Pipeline Data vs Status

```bash
# Capture stdout but keep a reliable status
if out="$(cmd1 | cmd2 | cmd3)"; then
  printf '%s\n' "$out"
else
  rc=$?
  die "pipeline failed (rc=$rc)"
fi
```

`pipefail` ensures the pipeline’s status reflects the failing stage.

---

## Safe `read` Loops (no UUOC, no word split)

```bash
while IFS= read -r line; do
  printf '>%s\n' "$line"
done < input.txt
```

Avoid `cat file | while ...` (spawns subshell in many shells; variables set inside won’t persist).

---

## Tiny Audit Logger (syslog-friendly)

```bash
log_json() {
  local level="$1"; shift
  jq -nc --arg t "$(date +%s)" --arg level "$level" --arg msg "$*" \
    '{ts: ($t|tonumber), level: $level, msg: $msg}'
}
log_json info "startup complete" | tee -a /var/log/myapp.log
```

Keeps stdout as data; compatible with pipelines or `journald`.

---

```yaml
---
id: templates/bash/40-functions-args-traps-cleanup.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, functions, getopts, traps, cleanup, lock, concurrency]
description: "Production-grade patterns for functions, argument parsing, error handling, traps, and cleanup with temporary files and locks."
---
```
