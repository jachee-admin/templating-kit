###### Bash

# Strict Mode Skeleton: Safety Flags, Structured Logging, Traps, Dry-Run, and Usage

Baseline scaffold for robust Bash scripts: strict flags, predictable IFS/locale, structured logs with levels, error/exit traps, optional xtrace, and a DRY-RUN helper.

## TL;DR

* `set -Eeuo pipefail` **and** `IFS=$'\n\t'`, `LC_ALL=C`.
* Structured logging: `debug/info/warn/error`, ISO timestamps, PIDs, line numbers.
* `trap ERR` prints failing command, line, and function; `trap EXIT` cleans up.
* `DRYRUN=1` to preview side-effects via `run cmd …`.
* Optional tracing to a dedicated FD with `TRACE=1`.

---

## Script

```bash
#!/usr/bin/env bash
# strict-mode.sh — reusable strict-mode scaffold
# Usage:
#   strict-mode.sh [-n|--dry-run] [-v|--verbose] [--trace] [--]
# Examples:
#   strict-mode.sh --dry-run
#   strict-mode.sh --trace --verbose

# --- Strict mode & environment -------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# --- Defaults -----------------------------------------------------------------
DRYRUN="${DRYRUN:-0}"
VERBOSE="${VERBOSE:-0}"
TRACE="${TRACE:-0}"

# --- Logging ------------------------------------------------------------------
_ts()  { date -u +%FT%T%Z; }              # RFC3339-ish UTC
_lno() { echo "${BASH_LINENO[0]:-0}"; }
_fn()  { echo "${FUNCNAME[1]:-main}"; }

_log() {
  local level="$1"; shift
  printf '%s %-5s pid=%d line=%s fn=%s %s\n' \
    "$(_ts)" "$level" "$$" "$(_lno)" "$(_fn)" "$*" >&2
}
debug(){ (( VERBOSE > 0 )) && _log DEBUG "$*"; }
info() { _log INFO  "$*"; }
warn() { _log WARN  "$*"; }
error(){ _log ERROR "$*"; }

# --- Error/exit traps ----------------------------------------------------------
on_err() {
  local rc=$? cmd=${BASH_COMMAND:-?}
  error "err rc=$rc cmd=${cmd@Q}"
  exit "$rc"
}
on_exit() {
  local rc=$?
  # cleanup hooks go here; example: [[ -d ${TMPD:-} ]] && rm -rf -- "$TMPD"
  debug "exit rc=$rc"
}
trap on_err ERR
trap on_exit EXIT
trap 'warn "SIGINT received"; exit 130' INT
trap 'warn "SIGTERM received"; exit 143' TERM

# --- Optional xtrace to a separate FD -----------------------------------------
enable_trace() {
  exec 5>"/tmp/${0##*/}.trace.$$.log"
  export BASH_XTRACEFD=5
  export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
  set -x
}
(( TRACE )) && enable_trace

# --- Dry-run helper ------------------------------------------------------------
run() {
  info "+ $*"
  if (( DRYRUN )); then
    return 0
  else
    "$@"
  fi
}

# --- Usage & flag parsing ------------------------------------------------------
usage() {
  cat <<EOF
Usage: ${0##*/} [options]

Options:
  -n, --dry-run     Preview actions; don't execute side-effects
  -v, --verbose     Enable DEBUG logs
      --trace       Enable xtrace to /tmp/${0##*/}.trace.\$\$.log
  -h, --help        Show help
EOF
}

# Long-to-short shim to keep getopts simple
_long2short() {
  local out=()
  while (($#)); do
    case "$1" in
      --dry-run) out+=("-n");;
      --verbose) out+=("-v");;
      --trace)   out+=("--trace");;   # handled later
      --help)    out+=("-h");;
      --)        shift; out+=("$@"); break;;
      -*)        out+=("$1");;
      *)         out+=("$1");;
    esac; shift
  done
  printf '%s\0' "${out[@]}"
}
mapfile -t ARGV < <(_long2short "$@" | xargs -0 -n1)
set -- "${ARGV[@]}"

while getopts ":nvh" opt; do
  case "$opt" in
    n) DRYRUN=1 ;;
    v) VERBOSE=$((VERBOSE+1)) ;;
    h) usage; exit 0 ;;
    \?) usage; exit 2 ;;
  esac
done
shift $((OPTIND-1))
# Handle --trace (was passed through)
for a in "$@"; do [[ $a == --trace ]] && TRACE=1; done
# Re-enable trace if flag came after parsing
(( TRACE )) && enable_trace

# --- Main ----------------------------------------------------------------------
main() {
  info "Starting (dryrun=$DRYRUN, verbose=$VERBOSE, trace=$TRACE)"

  # Example side-effect with run helper
  run echo "Hello, strict world"

  info "Done"
}

main "$@"
```

---

## Notes

* Keep **stdout for data** and logs on **stderr** if you plan to pipe results.
* Add a per-script `TMPD="$(mktemp -d)"` plus cleanup in `on_exit` for temp safety.
* If you wrap pipelines, keep `set -o pipefail` and inspect `${PIPESTATUS[*]}` on failure.

---

```yaml
---
id: templates/bash/10-strict-mode.sh.md
lang: bash
platform: posix
scope: scaffolding
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, strict, logging, traps, dry-run, xtrace]
description: "Strict-mode scaffold with structured logging, ERR/EXIT traps, dry-run helper, optional xtrace, and long/short flag parsing."
---
```
