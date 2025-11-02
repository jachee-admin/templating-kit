###### Bash

# Variables, Quoting & Expansions

Mastering quoting and expansions prevents ~80% of shell bugs. This template is a compact, mentor-friendly reference with safe defaults, sharp edges called out, and copy-pasteable patterns.

## TL;DR

* Prefer `local` in functions; avoid global name collisions.
* Always quote expansions: `"$var"`, `"${arr[@]}"`.
* Use braces for clarity: `"${var}"`, `"${var%suffix}"`.
* Don’t change `IFS` globally; use a subshell or a function.
* Avoid word splitting and globbing surprises: quote or disable with `set -f`.

---

## Variables & Scope

```bash
#!/usr/bin/env bash

# Global vs local
project_root="/srv/app"

do_work() {
  local tmp_dir
  tmp_dir="$(mktemp -d)" || { echo "mktemp failed" >&2; return 1; }
  # ... use "$tmp_dir"
  rm -rf -- "$tmp_dir"
}
```

**Why:** `local` avoids clobbering globals in bigger scripts. `mktemp -d` is race-safe compared to hand-rolled names.

---

## Quoting Rules That Save Careers

```bash
name="Ada Lovelace"
echo "$name"          # correct
echo $name            # BAD: word splitting if $name had spaces/newlines

path="/opt/*"
printf '%s\n' "$path" # prints literal /opt/*
printf '%s\n' $path   # BAD: * expands to files
```

**Mental model:** unquoted expansions undergo **word splitting** (split on IFS) and **pathname expansion** (globbing). Quote unless you explicitly want those behaviors.

---

## Arrays (indexed & associative)

```bash
# Indexed
nums=(10 20 "30 40")
echo "${nums[0]}"              # 10
printf '%s\n' "${nums[@]}"     # each item on its own line

# Associative (Bash 4+)
declare -A cfg=([host]="db.local" [port]="5432")
echo "${cfg[host]}"
for k in "${!cfg[@]}"; do
  printf '%s=%s\n' "$k" "${cfg[$k]}"
done
```

**Gotcha:** `${arr[@]}` expands to **each element**; `${arr[*]}` joins with the first char of `IFS` (usually space).

---

## Parameter Expansion Power-Ups

```bash
file="report_2025-11-01.csv"
echo "${file%.csv}.parquet"       # suffix trim → report_2025-11-01.parquet
echo "${file#report_}"            # prefix trim → 2025-11-01.csv

user="${USER:-unknown}"           # default if unset or empty
region="${REGION:?REGION required}"  # hard fail with message

s="  spaced   "
s="${s#"${s%%[![:space:]]*}"}"    # ltrim
s="${s%"${s##*[![:space:]]}"}"    # rtrim
printf '<%s>\n' "$s"

# Safe substring & length
id="abcd-efgh"
echo "${#id}"                     # length
echo "${id:5:2}"                  # 'fg'
```

**Notes:**

* `${var:?}` is a great guardrail in production scripts.
* `${var:-default}` doesn’t modify `var`; `${var:=default}` assigns.

---

## Null/Unset vs Empty, `set -u`, and Defensive Reads

```bash
set -u  # treat unset variables as an error

: "${CONFIG_DIR:="/etc/myapp"}"   # assign default once
: "${LOG_LEVEL:="info"}"

# Reading safely (no trimming, preserve spaces)
IFS= read -r line < /path/to/file

# Mapfile reads all lines into an array
mapfile -t lines < /path/to/list.txt
printf '%s\n' "${lines[@]}"
```

**Gotcha:** `set -u` + `${arr[@]}` is safe; but referencing an unset scalar explodes. Initialize your variables.

---

## Field Splitting: Use Surgical IFS

```bash
# Parse colon-separated record without breaking global IFS
parse_record() (
  local IFS=":"
  read -r a b c <<<"$1"
  printf 'A=%s B=%s C=%s\n' "$a" "$b" "$c"
)
parse_record "one:two three:four"
```

**Pattern:** Use a **subshell** `(...)` or a small function to limit the blast radius of a modified `IFS`.

---

## Globbing: When You Mean It

```bash
shopt -s nullglob dotglob
files=(/var/log/myapp/*.log)
for f in "${files[@]}"; do
  : # process "$f"
done
```

`nullglob` avoids the “literal pattern” bug when no matches. `dotglob` includes dotfiles when you truly want them.

---

## Command Substitution Pitfalls

```bash
# Prefer $() over backticks
ts="$(date +%FT%T%z)"
count="$(wc -l < "data.csv")"  # faster, avoids UUOC and trims spaces
```

---

## Here Docs & Here Strings

```bash
# Here doc with quoted delimiter: no expansion inside
cat >config.ini <<'EOF'
[default]
region = ${REGION}   # literal, not expanded
EOF

# Here string: pass small data to STDIN
grep -E '^(y|yes)$' <<<"$answer"
```

---

## Regex Matching (Bash [[ … ]] only)

```bash
if [[ $email =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}$ ]]; then
  echo "ok"
fi
```

`[[ … ]]` is safer: no word splitting/globbing of unquoted vars; `=~` uses ERE (extended regex).

---

## Common Failure Modes

* Forgetting quotes around `"${arr[@]}"` → multi-word entries break.
* Using `echo` for data with escapes or `-n` flags → prefer `printf`.
* Global `IFS` edits → cause spooky action at a distance.
* Assuming `${var:-}` distinguishes unset vs empty; use `${var+x}` to detect set-ness.

```bash
if [[ -v var ]]; then echo "set (maybe empty)"; fi   # Bash 4.2+
if [[ ${var+x} ]]; then echo "set (maybe empty)"; fi # portable Bash
```

---

## Practical Snippet: Safe CSV Field Extraction (no awk)

```bash
get_csv_field() (
  # Extract Nth comma-separated field without invoking awk/sed
  local -i n="$1"; shift
  local IFS=, fields
  read -r -a fields <<<"$*"
  printf '%s\n' "${fields[n-1]}"
)
get_csv_field 3 "a,b,c d,e"   # → c d
```

---

```yaml
---
id: templates/bash/30-variables-quoting-expansions.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, quoting, parameter-expansion, arrays, ifs, globbing]
description: "Battle-tested patterns for variables, quoting, arrays, and parameter expansion with minimal footguns."
---
```
