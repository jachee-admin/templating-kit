###### Bash

# CLI UX Patterns: Help, Validation, Config Layering, Subcommands, and Output Modes

Friendly CLIs reduce tickets. Give users clear help, predictable flags, sane defaults, and stable output formats.

## TL;DR

* Provide `-h/--help`, `--version`, `-q/--quiet`, `-v[vv]` verbosity, `--yes` non-interactive.
* **Config layering**: defaults → config file → env vars → CLI flags (highest).
* Validate inputs early; print actionable errors.
* Support `-` for stdin/stdout where sensible.
* Offer `--format json|text` and stable field order for parsing.

---

## Canonical skeleton with `getopts` (+ long flags shim)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.4.0"

usage() {
  cat <<EOF
Usage: ${0##*/} [options] <subcommand> [args]

Options:
  -h, --help        Show help
  -q, --quiet       Quieter output (can stack with -v/-vv rules)
  -v, --verbose     Increase verbosity (repeat for more)
  --version         Print version and exit
  --config FILE     Config file path (default: ~/.config/myapp/config.ini)
  --format FORMAT   Output: text|json (default: text)
  --yes             Assume "yes" to prompts (non-interactive)

Subcommands:
  scan     Scan inputs and print a report
  render   Render config from a template

Examples:
  ${0##*/} --format json scan ./targets/
  ${0##*/} -vv render - < template.tmpl > output.conf
EOF
}

# Pre-parse long flags to short equivalents for getopts
long2short() {
  local argv=()
  while (($#)); do
    case "$1" in
      --help) set -- "$@" -h ;;
      --quiet) set -- "$@" -q ;;
      --verbose) set -- "$@" -v ;;
      --version) set -- "$@" -V ;;
      --config) set -- "$@" -c "$2"; shift ;;
      --format) set -- "$@" -F "$2"; shift ;;
      --yes) set -- "$@" -Y ;;
      --) shift; break ;;
      --*) echo "Unknown option: $1" >&2; usage; exit 2 ;;
      *) argv+=("$1") ;;
    esac
    shift
  done
  set -- "${argv[@]}" "$@"
  printf '%s\0' "$@"
}

# Defaults
QUIET=0; VERB=0; YES=0; FORMAT="text"; CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/myapp/config.ini"

# Convert longs and reload argv
mapfile -t ARGV < <(long2short "$@" | xargs -0 -n1)
set -- "${ARGV[@]}"

while getopts ":hqvVc:F:Y" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    q) QUIET=1 ;;
    v) ((VERB++)) ;;
    V) echo "$VERSION"; exit 0 ;;
    c) CONFIG="$OPTARG" ;;
    F) FORMAT="$OPTARG" ;;
    Y) YES=1 ;;
    \?) usage; exit 2 ;;
    :)  echo "Missing arg for -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))

cmd="${1:-}"; [[ -n $cmd ]] || { usage; exit 2; }
shift
```

---

## Config layering (defaults → file → env → CLI)

```bash
# Very light INI reader: key=value (no sections)
declare -A CFG=()
if [[ -r "$CONFIG" ]]; then
  while IFS='=' read -r k v; do
    [[ -z $k || $k =~ ^\s*# ]] && continue
    k="${k//[[:space:]]/}"; v="${v##[[:space:]]}"
    CFG["$k"]="$v"
  done < "$CONFIG"
fi

# Layer with ENV (MYAPP_FOO), then final CLI overrides already applied
HOST="${MYAPP_HOST:-${CFG[host]:-localhost}}"
PORT="${MYAPP_PORT:-${CFG[port]:-8080}}"
```

**Precedence rule (document it):** defaults < config file < environment < CLI flags.

---

## Subcommands as functions

```bash
scan() {
  local dir="${1:-.}"
  [[ -d $dir ]] || { echo "not a directory: $dir" >&2; return 2; }
  find "$dir" -type f -maxdepth 1 -name '*.conf' -print
}

render() {
  local infile="${1:--}"
  local template="${2:-template.tmpl}"
  [[ $infile == "-" ]] && infile="/dev/stdin"
  env HOST="$HOST" PORT="$PORT" envsubst < "$template" > "$infile"
}

case "$cmd" in
  scan|render) "$cmd" "$@" ;;
  *) echo "Unknown subcommand: $cmd" >&2; usage; exit 2 ;;
esac
```

---

## Validation & helpful errors

```bash
# Validate FORMAT early
case "$FORMAT" in
  text|json) ;;
  *) echo "Invalid --format: $FORMAT (expected text|json)" >&2; exit 2 ;;
esac

# Quiet/verbose policy
log() { (( QUIET )) || printf '%s\n' "$*" >&2; }
vlog(){ (( VERB > 0 )) && printf '[v] %s\n' "$*" >&2; }
```

---

## Output modes: text vs JSON (stable fields)

```bash
emit_result() {
  local name="$1" status="$2"
  case "$FORMAT" in
    text)  printf '%-20s %s\n' "$name" "$status" ;;
    json)  jq -nc --arg n "$name" --arg s "$status" '{name:$n,status:$s}' ;;
  esac
}

emit_result "init" "ok"
```

---

## Non-interactive & prompts

```bash
confirm() {
  local msg="${1:-Proceed?}"
  if (( YES )); then return 0; fi
  read -r -p "$msg [y/N] " ans
  [[ $ans =~ ^[Yy](es)?$ ]]
}

confirm "Deploy to $HOST:$PORT" || { echo "aborted"; exit 130; }
```

---

## Progress indicators that don’t break pipes

```bash
work() { sleep 1; echo "data line"; }
work 2> >(while read -r l; do printf '[%(%T)T] %s\n' -1 "$l" >&2; done)
```

---

## `--color` / terminals

```bash
COLOR="${COLOR:-auto}"  # auto|always|never
is_tty() { [[ -t 1 ]]; }
colorize() {
  local txt="$1"
  case "$COLOR" in
    always) printf '\e[32m%s\e[0m\n' "$txt" ;;
    auto) is_tty && printf '\e[32m%s\e[0m\n' "$txt" || printf '%s\n' "$txt" ;;
    never|*) printf '%s\n' "$txt" ;;
  esac
}
```

---

## Self-documenting `--help`: include config/env

Make `--help` mention: config file path, the env variable prefix (e.g., `MYAPP_*`), example commands, exit code meanings, and subcommand-specific help.

```bash
# Subcommand help
case "$cmd" in
  scan) [[ ${1:-} == "--help" ]] && { echo "Usage: $0 scan [dir]"; exit 0; } ;;
  render) [[ ${1:-} == "--help" ]] && { echo "Usage: $0 render [out|-] <template>"; exit 0; } ;;
esac
```

---

## Completion stub (bash-completion)

```bash
# myapp completion (place in /etc/bash_completion.d/myapp)
_myapp_complete() {
  local cur prev words cword
  _init_completion || return
  local subcmds="scan render"
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=( $(compgen -W "$subcmds" -- "$cur") )
  fi
}
complete -F _myapp_complete myapp
```

---

## Exit code policy (document!)

* `0` success
* `2` usage/config error
* `7` remote rejection (example)
* `75` temporary failure (retryable)
* `130` user aborted (Ctrl+C or declined prompt)

---

```yaml
---
id: docs/bash/140-cli-ux-patterns.sh.md
lang: bash
platform: posix
scope: cli
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, cli, getopts, long-options, subcommands, config, env, help, json]
description: "User-friendly, automatable CLIs: help/version, quiet/verbose, config layering, subcommands, stdin/- conventions, stable text/JSON output, and exit-code policy."
---
```

