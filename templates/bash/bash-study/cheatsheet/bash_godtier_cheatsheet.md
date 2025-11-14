# Bash Scripting Cheatsheet — Advanced → “God-Tier”

> Assumes **GNU Bash ≥ 4.2** (notes where 4.4/5.x features appear). Focus: production-grade scripts, correctness, performance, and maintainability.

---

## 1) Hardened Template (prod-ready)

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2310,SC2312
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true   # Bash 5.0+: propagate -e into command subs
IFS=$'\n\t'

readonly SCRIPT=${BASH_SOURCE[0]##*/}
readonly DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# ---- logging ----
_is_tty=0; [[ -t 2 ]] && _is_tty=1
if ((_is_tty)); then R=$'\e[31m'; Y=$'\e[33m'; G=$'\e[32m'; B=$'\e[1m'; Z=$'\e[0m'; else R= Y= G= B= Z=; fi
log()  { printf '%s\n' "$*"; }
info() { printf '%sINFO%s  %s\n' "$B$G" "$Z" "$*" >&2; }
warn() { printf '%sWARN%s  %s\n' "$B$Y" "$Z" "$*" >&2; }
die()  { rc=${2:-1}; printf '%sERROR%s %s\n' "$B$R" "$Z" "$1" >&2; exit "$rc"; }

# ---- cleanup & traps ----
_tmpdir=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
cleanup() { local rc=$?; rm -rf -- "$_tmpdir"; trap - ERR EXIT; exit "$rc"; }
trap cleanup EXIT
trap 'die "Failed at ${BASH_SOURCE[0]}:${LINENO}: ${FUNCNAME[0]:-(main)} (rc=$?)"' ERR

# ---- options ----
_usage() { cat <<EOF
Usage: $SCRIPT [-n DRYRUN] -f FILE [--] [ARGS...]
EOF
}
dryrun=0; infile=
while getopts ':f:n:h' opt; do
  case $opt in
    f) infile=$OPTARG ;;
    n) dryrun=$OPTARG ;;
    h) _usage; exit 0 ;;
    \?|:) _usage; exit 2 ;;
  esac
done
shift $((OPTIND-1))
[[ -n ${infile:-} ]] || die "Missing -f"

# ---- example FD allocation (no clobber) ----
exec {INFD}<"$infile" || die "Open $infile"
# read -r <&"$INFD"
```

**Why this rocks**

* `inherit_errexit` + `set -E` reduces “silent fail” corners (subshells, command substitutions).
* Named FDs (`exec {fd}`) avoid global FD clashes and are shell-safe under concurrency.
* Centralized `die()` and `cleanup()` guarantee tidy exits.

---

## 2) Parameter Expansion (power user level)

```bash
# Defaulting / assertions
: "${REQUIRED?Set REQUIRED}"           # hard fail if empty/unset
: "${OPT:=default}"                    # set default if empty/unset

# Substrings & edits
name="firebreak.labs.tar.gz"
echo "${name%%.*}"      # firebreak         (longest suffix from right of first dot)
echo "${name#*.}"       # labs.tar.gz       (shortest prefix)
echo "${name%%.tar.*}"  # firebreak.labs
echo "${name%.gz}.xz"   # replace suffix

# Replace (glob pattern, not regex)
path="/a/b/c/d.txt"
echo "${path//\//|}"    # |a|b|c|d.txt

# Case modifiers (Bash 4+)
s="MiMi"
echo "${s,,}"           # mimi
echo "${s^^}"           # MIMI
echo "${s^}"            # MiMi (capitalize first char)

# Indirection & variable discovery
prefix=CFG_
CFG_DB=prod
echo "${!prefix@}"      # list vars with that prefix
echo "${!CFG_*}"        # expands names; use with care

# Safe assignment without subshells
printf -v joined '%s,' a b c; joined=${joined%,}
```

---

## 3) Arrays & Associatives (with patterns you’ll actually reuse)

```bash
# Indexed
readarray -t lines < <(grep -vE '^\s*(#|$)' config.txt)

# Associative maps
declare -A conf=( [host]=db.local [port]=5432 )
conf[user]=app
for k in "${!conf[@]}"; do printf '%s=%s\n' "$k" "${conf[$k]}"; done | sort

# Group-by / histogram
declare -A hist=()
while read -r item; do (( hist["$item"]++ )); done < list.txt
for k in "${!hist[@]}"; do printf '%s\t%d\n' "$k" "${hist[$k]}"; done | sort -k2nr
```

---

## 4) File Descriptors & Redirection Kung-fu

```bash
# Named FDs (no collisions, automatic close-on-exec)
exec {out}>results.log
printf 'ok\n' >&"$out"

# Bidirectional open (careful: truncates unless '>>')
exec {fd}<> data.txt
read -r line <&"$fd"
printf 'APPEND\n' >&"$fd"    # writes at current offset

# Tee stderr somewhere else
{ cmd 3>&1 1>&2 2>&3 3>&-; } | tee err.log

# Duplicate & silence
exec {null}<>/dev/null
some_noisy_cmd 2>&"$null"
```

---

## 5) Regex & `[[ =~ ]]` (correct usage)

```bash
line='user:john id=42'
if [[ $line =~ ^user:([a-z]+)[[:space:]]+id=([0-9]+)$ ]]; then
  user=${BASH_REMATCH[1]}
  id=${BASH_REMATCH[2]}
fi
# DO NOT quote the regex RHS; quoting disables regex.
# Use POSIX classes [[:digit:]] [[:space:]] for portability across locales.
```

---

## 6) Globbing Mastery

```bash
shopt -s nullglob dotglob globstar extglob
# extglob patterns: !(pat) *(pat) +(pat) ?(pat) @(a|b)
for f in **/*.@(jpg|png|gif); do :; done

# Exclude with extglob
for f in !(*.bak|*.tmp); do :; done
```

---

## 7) Process Substitution, Coprocesses & Pipelines

```bash
# Compare large files without temp files
comm -3 <(sort -u a.txt) <(sort -u b.txt)

# Coprocess (asynchronous producer/consumer)
coproc FETCH { curl -fsS https://example.com/stream; }
# FETCH[0] => stdout of command, FETCH[1] => stdin to command
read -r first <&"${FETCH[0]}"
printf 'q\n' >&"${FETCH[1]}"
wait "${FETCH_PID}"
```

**Notes**

* On macOS without `/proc`, process substitution may use FIFOs—keep streams open until done.
* `wait -n` (Bash 4.3+) waits for **any** background job to finish.

---

## 8) Concurrency Patterns (Bash-only, no GNU parallel)

**a) Job fan-out with backpressure (N workers):**

```bash
max=4
pids=()
run() { "$@" & pids+=($!); }

for x in "${tasks[@]}"; do
  run do_work "$x"
  while ((${#pids[@]} >= max)); do
    wait -n;                    # requires Bash ≥4.3
    # prune finished pids
    tmp=(); for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && tmp+=("$p"); done
    pids=("${tmp[@]}")
  done
done
wait  # drain
```

**b) NUL-safe producer/consumer pipeline:**

```bash
find . -type f -print0 |
while IFS= read -r -d '' f; do
  process "$f" &
  (( $(jobs -r | wc -l) >= 4 )) && wait -n
done
wait
```

---

## 9) Robust Input Parsing

```bash
# NUL-delimited map into array (fast, safe)
mapfile -d '' -t files < <(find . -type f -name '*.log' -print0)

# CSV (simple commas, no quotes)
while IFS=, read -r a b c; do :; done < file.csv

# INI-ish: KEY=VALUE (no spaces)
set -a
# shellcheck disable=SC1091
source ./config.env
set +a
```

For **long options**, prefer **GNU getopt** (carefully) or a thin manual parser:

```bash
# --key=value and --flag booleans
for arg in "$@"; do
  case $arg in
    --debug) debug=1 ;;
    --threads=*) threads=${arg#*=} ;;
    --) shift; break ;;
    -*) die "Unknown option: $arg" ;;
    *)  pos+=("$arg") ;;
  esac; shift || true
done
```

---

## 10) `set -e` / ERR Trap Edge Cases (know them or bleed)

* `set -e` **does not** fire on failures inside `if`, `while`, `until` tests, `! cmd`, or any command that’s part of `&&`/`||` lists.
  Mitigations:
  
  * Use `set -E`/`shopt -s inherit_errexit` so ERR/`-e` propagate into functions/subshells.
  * Add explicit checks or `|| die "..."` where logic intentionally handles rc≠0.
  * Keep pipelines with `set -o pipefail` so upstream failures are visible.

**Pattern:**

```bash
safe() { "$@" || die "failed: $*"; }
result=$(safe some_cmd with args)
```

---

## 11) `read`, `IFS`, and Word-Splitting Rules

* `read -r` disables backslash escapes (**always**).
* `IFS` only applies to `read` and word splitting **after** expansions (not inside single quotes).
* Preserve leading/trailing whitespace with `IFS= read -r`.

```bash
while IFS= read -r line || [[ -n $line ]]; do
  printf '%q\n' "$line"
done < file.txt
```

---

## 12) Time, Profiling & Tracing

```bash
# Per-command timing
TIMEFORMAT=$'real=%3R user=%3U sys=%3S'   # builtin 'time'
time grep -Ff needles haystack

# Pretty xtrace
export PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '
set -x;  do_work;  set +x

# Trace to FD (avoid mixing with stdout)
exec {XT}>trace.log
BASH_XTRACEFD=$XT
set -x; do_work; set +x
```

---

## 13) Arithmetic & Bits

```bash
(( i = i + 1 ))
(( mask = 1<<8 ))
# bases
echo $((16#FF))      # 255
printf '%#x\n' $((255))  # 0xff
# modulo, ternary
(( n%2 )) && echo odd || echo even
```

---

## 14) Text Handling: Use the Right Tool (bash vs awk/sed)

* Bash string ops are **O(n)** and fine for small tokens. For line/column processing, prefer `awk`.
* Avoid useless use of `cat` (UUOC). Stream with redirections: `awk '...' file` or `awk '...' <(cmd)`.

**Examples**

```bash
# AWK: column sum
awk -F, 'NR>1{sum+=$3}END{print sum}' file.csv

# SED: multi-file in-place (GNU)
sed -i 's/foo/bar/g' **/*.txt
```

---

## 15) Locking, Races, and Idempotency

```bash
# Flock to serialize a critical section
{
  flock -n 9 || die "Another instance running"
  critical_work
} 9>"/var/lock/${SCRIPT}.lock"

# Idempotent tmpdir + atomic move
tmp=$(mktemp -d)
generate > "$tmp/out.new"
mv -fT "$tmp/out.new" final.out
```

---

## 16) Signals, TTY, Jobs, Disown

```bash
trap 'warn "SIGINT"; exit 130' INT
trap 'warn "SIGTERM"; exit 143' TERM

# Background + disown (won't receive HUP)
long_task & disown

# Detect non-interactive
if [[ ! -t 0 ]]; then echo "piped input"; fi
```

---

## 17) Programmable Completion (quick taste)

```bash
# In your script:
_mycomp() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -W "--help --list --force" -- "$cur") )
}
complete -F _mycomp myscript
```

---

## 18) Packaging, Portability, Versions

```bash
req=4
(( BASH_VERSINFO[0] >= req )) || die "Bash $req+ required"

# Detect OS
case $(uname -s) in
  Linux)   : ;;
  Darwin)  : ;;   # macOS (use coreutils via brew for GNU readlink/sed)
esac
```

---

## 19) Mini-Cookbook (copy/paste gold)

**NUL-safe gzip logs:**

```bash
find /var/log -type f -name '*.log' -size +0 -print0 |
xargs -0 -P4 -I{} gzip -9 "{}"
```

**Retry with exp backoff + jitter:**

```bash
retry() {
  local max=${1:-5} i=0; shift
  until "$@"; do
    (( ++i > max )) && return 1
    sleep "$(( (RANDOM%100)/100 + 2**i ))"
  done
}
retry 5 curl -fsS https://example.com/ping
```

**INI reader with sections:**

```bash
# section.key=value -> assoc map: conf[section.key]=value
declare -A conf=()
while IFS= read -r line; do
  [[ $line =~ ^\[(.+)\]$ ]] && sect=${BASH_REMATCH[1]} && continue
  [[ $line =~ ^\s*([A-Za-z0-9_.-]+)\s*=\s*(.*)\s*$ ]] || continue
  conf["$sect.${BASH_REMATCH[1]}"]=${BASH_REMATCH[2]}
done < settings.ini
```

**Top-N biggest files:**

```bash
du -ah . | sort -h | tail -n 20
```

**Safe temp and restore on error:**

```bash
backup() { cp -a -- "$1" "$1.bak"; }
restore() { mv -f -- "$1.bak" "$1"; }
backup conf.yml
trap 'restore conf.yml' ERR
# ... edit conf.yml atomically ...
trap - ERR; rm -f conf.yml.bak
```

---

## 20) Gotchas You’ll Only Learn the Hard Way (unless you read this)

* Quoting regex RHS in `[[ s =~ re ]]` disables regex. Don’t.
* `mapfile`/`readarray` preserves trailing **newline** semantics; final line without newline? Use `|| [[ -n $line ]]` idiom when reading.
* `set -e` and `pipefail`: `cmd | while read; do ...; done` executes loop in a subshell; updates to outer vars won’t persist. Use process substitution: `while read; do ...; done < <(cmd)`.
* `for x in $(cmd)`: word-splitting hell. NUL-delimit (`-print0` / `-0`) + `read -d ''` or `mapfile -d ''`.
* On macOS, many tools are BSD; flags differ (`sed -i` needs a suffix: `-i ''`).

---

## 21) Quality Gate (pre-commit for scripts)

* `shellcheck -x script.sh` clean (or annotated ignores).
* `shfmt -i 2 -ci -sr -w script.sh` (format).
* Unit-ish tests with \[bats-core] or simple golden-file diffs.
* CI env sets `LANG=C.UTF-8`, fixes locale-dependent regex/globs.
* All external commands probed with `command -v`.
