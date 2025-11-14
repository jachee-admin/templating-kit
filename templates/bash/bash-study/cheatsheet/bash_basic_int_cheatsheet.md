# Bash Scripting Cheatsheet — Basics → Intermediate

> Assumes **GNU/Linux** (Ubuntu/Fedora). Shell is **bash** (not sh or zsh).

---

## Script skeleton (robust defaults)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
# -E: inherit ERR traps in functions/subshells
# -e: exit on uncaught error
# -u: error on unset vars
# -o pipefail: fail if any piped cmd fails
IFS=$'\n\t'   # safer word-splitting

script_name=${0##*/}

usage() {
  cat <<EOF
Usage: $script_name [-v] -f <file> [--] [positional...]
Options:
  -f FILE    input file (required)
  -v         verbose
  -h         help
EOF
}

cleanup() { :; }                # put temp-file deletes etc. here
trap cleanup EXIT                # always runs, even on error
trap 'echo "Error on line $LINENO" >&2' ERR

verbose=false
infile=""

while getopts ":f:vh" opt; do
  case "$opt" in
    f) infile=$OPTARG ;;
    v) verbose=true ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown -$OPTARG"; usage; exit 2 ;;
    :)  echo "Option -$OPTARG needs a value"; usage; exit 2 ;;
  esac
done
shift $((OPTIND-1))

$verbose && echo "Using $infile"
[[ -n ${infile:-} ]] || { echo "Missing -f"; usage; exit 2; }

# your code...
```

---

## Must-know syntax & operators

### Quoting

* **Always quote variables**: `"$var"` (prevents word-splitting & globbing).
* Use single quotes for literals: `'*.txt'`; double quotes to allow `"$var"` expansion.

### Tests

Prefer `[[ ... ]]` over `[ ... ]`:

```bash
# strings
[[ $a == "$b" ]]        # pattern match under [[ ]]
[[ $a =~ ^re[0-9]+$ ]]  # regex (no quotes on rhs)
# numbers
[[ $x -lt 10 ]]
# files
[[ -f path ]] [[ -d dir ]] [[ -s file ]] [[ -x cmd ]]
```

### Conditionals & case

```bash
if [[ -z $var ]]; then
  echo "empty"
elif [[ $var == foo* ]]; then
  echo "prefix foo"
fi

case $ext in
  jpg|png) echo "image" ;;
  *)       echo "other" ;;
esac
```

### Arithmetic

```bash
(( i += 1 ))
if (( x % 2 == 0 )); then echo even; fi
```

### Loops (safe patterns)

```bash
# Iterate arguments
for arg in "$@"; do echo "$arg"; done

# Read lines (no backslash escapes)
while IFS= read -r line; do
  printf '%s\n' "$line"
done < "$infile"

# CSV (comma-delimited)
while IFS=, read -r col1 col2 col3; do
  :
done < "$infile"
```

### Functions & locals

```bash
myfn() {
  local msg=${1:-"default"}
  printf '%s\n' "$msg"
}
```

---

## Variables & parameter expansion (power moves)

| Form                         | Meaning                                  |
| ---------------------------- | ---------------------------------------- |
| `${var:-def}`                | Use `def` if unset or empty              |
| `${var:=def}`                | Set to `def` if unset/empty, replace var |
| `${var:?msg}`                | Exit with `msg` if unset/empty           |
| `${var:+alt}`                | Use `alt` if set (else empty)            |
| `${#var}`                    | Length of `$var`                         |
| `${var:pos:len}`             | Substring                                |
| `${var#pat}` / `${var##pat}` | Remove shortest/longest **prefix** match |
| `${var%pat}` / `${var%%pat}` | Remove shortest/longest **suffix** match |
| `${var/pat/repl}`            | Replace first match                      |
| `${var//pat/repl}`           | Replace all matches                      |
| `${arr[@]}`                  | All elements (quoted expands to words)   |
| `${!prefix@}`                | Indirect list of vars by prefix          |

---

## Arrays (indexed & associative)

```bash
# Indexed
nums=(10 20 "thirty")
echo "${nums[1]}"         # 20
echo "${#nums[@]}"        # count
for n in "${nums[@]}"; do echo "$n"; done

# Append & slice
nums+=("forty")
echo "${nums[@]:1:2}"

# Associative (bash 4+)
declare -A ages=([alice]=30 [bob]=41)
echo "${ages[alice]}"
for k in "${!ages[@]}"; do printf '%s=%s\n' "$k" "${ages[$k]}"; done
```

---

## Subshells, grouping, and pipelines

```bash
(cmd1; cmd2)        # run in subshell (env changes don’t leak)
{ cmd1; cmd2; }     # same shell (note braces need spaces & ; )
cmd1 | cmd2 | cmd3  # pipeline (use set -o pipefail for robust erroring)

# Check all pipeline statuses
echo "statuses: ${PIPESTATUS[*]}"
```

---

## Redirection, here-docs, and process substitution

```bash
cmd >out.txt 2>err.txt        # redirect stdout/stderr
cmd >>append.log
cmd >/dev/null 2>&1

# here-doc
cat <<'EOF' > script.sh
literal $DOLLAR and backticks won't expand due to single-quoted EOF
EOF
chmod +x script.sh

# here-string
wc -w <<< "$text"

# process substitution (feed a stream as a file)
diff <(sort a.txt) <(sort b.txt)
```

---

## Command substitution & xargs

```bash
files=$(find . -type f -name '*.log')   # beware spaces; prefer maps:
# Better:
mapfile -t logs < <(find . -type f -name '*.log' -print0 | xargs -0 -I{} printf '%s\n' "{}")
for f in "${logs[@]}"; do :; done
```

---

## Safer file iteration

```bash
shopt -s nullglob dotglob   # optional: include dotfiles; empty globs -> empty list
for f in *.txt; do
  [[ -e $f ]] || continue   # in case no matches without nullglob
  printf 'File: %q\n' "$f"
done
```

---

## CLI args: `getopts` vs `"$@"`

* Use **getopts** for POSIX-style short flags.
* For long flags (`--flag=value`), either parse manually or use `getopt` (GNU) carefully.

```bash
# After getopts/shift, positional params are in "$@"
for p in "$@"; do printf 'arg=%q\n' "$p"; done
```

---

## Logging & colors

```bash
# Portable colors (disable if not a TTY)
is_tty=0; [[ -t 1 ]] && is_tty=1
if (( is_tty )); then
  RED=$'\e[31m'; YEL=$'\e[33m'; GRN=$'\e[32m'; BLD=$'\e[1m'; RST=$'\e[0m'
else
  RED= YEL= GRN= BLD= RST=
fi

log()  { printf '%s\n' "$*"; }
info() { printf '%sINFO%s: %s\n' "$BLD$GRN" "$RST" "$*"; }
warn() { printf '%sWARN%s: %s\n' "$BLD$YEL" "$RST" "$*" >&2; }
err()  { printf '%sERROR%s: %s\n' "$BLD$RED" "$RST" "$*" >&2; }
```

---

## Debugging & linting

```bash
bash -n script.sh           # syntax check
shellcheck script.sh        # linter (highly recommended)
set -x                       # trace commands
PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '  # pretty xtrace
```

---

## Parallelism & jobs

```bash
long_running & pid=$!
# run other work...
wait "$pid"                # wait for completion, propagate status

# Fire off N jobs and wait
pids=()
for t in {1..5}; do sleep "$t" & pids+=($!); done
for p in "${pids[@]}"; do wait "$p"; done
```

> Need heavy parallel? Consider **GNU parallel**; for bash-only, background jobs + `wait` is fine.

---

## Common one-liners (practical)

```bash
# Unique, sorted values from column 2 of CSV (ignoring header)
tail -n +2 file.csv | cut -d, -f2 | sort -u

# Find large files (>100MB)
find . -type f -size +100M -print0 | xargs -0 ls -lh

# Replace in-place across files (GNU sed)
sed -i 's/old/new/g' **/*.txt  # requires: shopt -s globstar

# Test if command exists
if command -v jq >/dev/null 2>&1; then :; fi

# JSON read with jq (external, but common)
jq -r '.items[].name' data.json
```

---

## Gotchas (and fixes)

* **`echo` vs `printf`**: `echo` is ambiguous (flags, escape handling). Prefer `printf '%s\n' "$var"`.
* **Word splitting**: Always quote: `rm -rf "$dir"` (handles spaces/newlines).
* **`for f in $(...)`**: Bad with spaces/newlines. Prefer `mapfile -t` + `while read` + NUL-delimited pipelines.
* **`set -e` quirks**: Doesn’t trigger on all failures (e.g., in `if cmd; then ...`). Combine with `pipefail`, check statuses where needed.
* **Regex in `[[ ... =~ ... ]]`**: Don’t quote the regex; it disables regex.
* **Arrays need quotes when expanding**: `"${arr[@]}"` preserves elements; `${arr[@]}` unquoted will split/glob.

---

## File/dir utilities you’ll actually use

```bash
tmpdir=$(mktemp -d)              # secure temp dir
tmpfile=$(mktemp)
trap 'rm -rf "$tmpdir" "$tmpfile"' EXIT

readlink_f() {                   # macOS note: use greadlink from coreutils
  readlink -f -- "$1"
}
```

---

## Pattern cookbook

### 1) Robust “find & handle” (NUL-safe)

```bash
find . -type f -name '*.log' -print0 |
while IFS= read -r -d '' f; do
  gzip -9 "$f"
done
```

### 2) INI/KEY=VAL config loader

```bash
# config.env: FOO=bar (no spaces)
set -a
# shellcheck disable=SC1091
source ./config.env
set +a
echo "$FOO"
```

### 3) Retry with backoff

```bash
retry() {
  local max=${1:-5} i=0
  shift
  until "$@"; do
    (( i++ >= max )) && return 1
    sleep $((2**i))
  done
}
retry 5 curl -fsS https://example.com
```

### 4) Time a block

```bash
start=$SECONDS
# ... work ...
printf 'Elapsed: %ss\n' "$((SECONDS - start))"
```

### 5) Simple progress spinner

```bash
spin() { while :; do for c in / - \\ \|; do printf "\r[%s]" "$c"; sleep .1; done; done }
long_job() { sleep 5; }
spin & spid=$!
long_job; kill "$spid"; printf '\r     \r'
```

---

## Globbing power (via `shopt`)

```bash
shopt -s globstar   # **/ recursive globs
shopt -s nullglob   # unmatched globs -> empty (not literal)
shopt -s extglob    # extended patterns: @(a|b) !(pat) +(pat) *(pat) ?(pat)
```

---

## Environment & exports

```bash
export PATH="$HOME/.local/bin:$PATH"
: "${REQUIRED_VAR:?Set REQUIRED_VAR first}"   # enforce presence
```

---

## Version checks (features like assoc arrays need bash 4+)

```bash
if (( BASH_VERSINFO[0] < 4 )); then
  echo "Bash 4+ required" >&2; exit 1
fi
```

---

## Quick reference tables

### String & file tests

| Test              | True if…                              |
| ----------------- | ------------------------------------- |
| `[[ -z $s ]]`     | string empty                          |
| `[[ -n $s ]]`     | string not empty                      |
| `[[ $a == $b ]]`  | strings equal (pattern under `[[ ]]`) |
| `[[ $a != $b ]]`  | strings not equal                     |
| `[[ -e p ]]`      | path exists                           |
| `[[ -f p ]]`      | regular file                          |
| `[[ -d p ]]`      | directory                             |
| `[[ -s p ]]`      | size > 0                              |
| `[[ -x p ]]`      | executable                            |
| `[[ p1 -nt p2 ]]` | newer than                            |
| `[[ p1 -ot p2 ]]` | older than                            |

### Special variables

| Var                 | Meaning                                  |
| ------------------- | ---------------------------------------- |
| `$0`                | script name                              |
| `$1..$N`            | positionals                              |
| `$#`                | count of args                            |
| `$@`                | all args (preserves quoting as elements) |
| `$*`                | all args (single word when quoted)       |
| `$?`                | last exit status                         |
| `$$`                | current PID                              |
| `$!`                | last background PID                      |
| `$LINENO`           | current line number                      |
| `${BASH_SOURCE[0]}` | current file                             |

---

## Packaging & running

```bash
chmod +x script.sh
./script.sh -f data.txt
# Or explicitly:
bash script.sh --help
```

---

## Quality checklist before you run it in prod

* `shellcheck` passes (or justified ignores).
* `set -Eeuo pipefail` at top.
* Temp files/dirs via `mktemp`, cleaned in `trap`.
* All vars quoted; arrays expanded as `"${arr[@]}"`.
* Inputs validated; clear `usage`.
* Log to stderr for warnings/errors.
* Idempotent where feasible.
