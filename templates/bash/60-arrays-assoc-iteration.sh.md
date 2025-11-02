###### Bash

# Arrays, Associative Maps & Iteration Patterns

Bash arrays are the difference between brittle one-liners and robust scripts. This template shows **safe creation**, **passing arrays to functions**, **set-like ops**, and **histograms**—all with quoting that doesn’t explode on spaces.

## TL;DR

* Use `declare -a` (indexed) and `declare -A` (associative).
* Expand arrays with `"${arr[@]}"`, never `${arr[*]}` unless you mean join-with-IFS.
* To pass arrays: use namerefs (`declare -n`) or serialize via `printf '%s\0'`.
* Iterate over **values** with `"${arr[@]}"`, over **indexes** with `"${!arr[@]}"`.

---

## Indexed arrays: creation & iteration

```bash
# Creation
declare -a files=(/var/log/*.log "notes with spaces.txt")

# Values
for f in "${files[@]}"; do
  printf 'file: %s\n' "$f"
done

# Indexes
for i in "${!files[@]}"; do
  printf '[%d]=%s\n' "$i" "${files[$i]}"
done
```

### Appending, slicing, length

```bash
files+=("/tmp/new.log")
echo "${#files[@]}"          # number of elements
printf '%s\n' "${files[@]:1:2}"   # slice [start:len]
```

---

## Associative arrays (Bash 4+)

```bash
declare -A cfg=([host]="db.local" [port]="5432")
cfg[sslmode]="require"

echo "${cfg[host]}:${cfg[port]}"
for k in "${!cfg[@]}"; do
  printf '%s=%s\n' "$k" "${cfg[$k]}"
done

echo "${#cfg[@]}"            # count of keys
unset 'cfg[sslmode]'         # delete a key (quote the whole subscript)
```

---

## Passing arrays to functions (nameref & portable pattern)

```bash
# Nameref: simplest (Bash 4.3+)
join_by() {
  local sep="$1"; shift
  local -n _arr="$1"     # _arr references the caller's array
  local out=()
  local i
  for i in "${_arr[@]}"; do out+=("$i"); done
  local IFS="$sep"
  printf '%s\n' "${out[*]}"
}

colors=(red "blue green" cyan)
join_by ',' colors        # → red,blue green,cyan

# Portable: serialize as NUL-delimited via stdin
with_array() {
  local a=()
  while IFS= read -r -d '' x; do a+=("$x"); done
  printf 'first=%s count=%d\n' "${a[0]}" "${#a[@]}"
}
printf '%s\0' "${colors[@]}" | with_array
```

---

## Building arrays from commands (null-safe)

```bash
# From find(1)
declare -a logs=()
while IFS= read -r -d '' f; do logs+=("$f"); done < <(find /var/log -type f -name '*.log' -print0)

# From jq (array of strings)
mapfile -t urls < <(jq -r '.urls[]' config.json)
```

---

## Set-like operations (unique, intersection, difference)

```bash
unique() {
  local -n in="$1" out="$2"
  declare -A seen=()
  out=()
  local x
  for x in "${in[@]}"; do
    [[ ${seen["$x"]+1} ]] || { seen["$x"]=1; out+=("$x"); }
  done
}

intersect() {
  local -n a="$1" b="$2" out="$3"
  declare -A mark=()
  out=()
  local x
  for x in "${a[@]}"; do mark["$x"]=1; done
  for x in "${b[@]}"; do [[ ${mark["$x"]+1} ]] && out+=("$x"); done
}

diff() {
  local -n a="$1" b="$2" out="$3"
  declare -A mark=()
  out=()
  local x
  for x in "${b[@]}"; do mark["$x"]=1; done
  for x in "${a[@]}"; do [[ ${mark["$x"]+1} ]] || out+=("$x"); done
}

A=(a b "c d" a) B=(b x "c d")
unique A U;       printf 'U: %q\n' "${U[@]}"
intersect A B I;  printf 'I: %q\n' "${I[@]}"
diff A B D;       printf 'D: %q\n' "${D[@]}"
```

---

## Histograms & counters

```bash
declare -A hist=()
while IFS= read -r line; do
  key="${line%% *}"          # first word as key
  ((hist["$key"]++))
done < access.log

for k in "${!hist[@]}"; do
  printf '%s %d\n' "$k" "${hist[$k]}"
done | sort -k2,2n
```

---

## Grouping records into arrays (multi-map)

```bash
# Group files by extension: map[ext] -> array of files
declare -A groups=()

add_group() {
  local ext="$1" file="$2"
  local -n bucket="groups_$ext"   # create a per-ext array via naming
  bucket+=("$file")
  groups["$ext"]=1                # register ext key
}

for f in *.*; do
  ext="${f##*.}"
  add_group "$ext" "$f"
done

# Iterate groups
for ext in "${!groups[@]}"; do
  local -n arr="groups_$ext"
  printf '[%s]\n' "$ext"
  printf '  - %s\n' "${arr[@]}"
done
```

**Why this pattern:** Bash can’t store arrays inside associative arrays. The “prefix name + nameref” trick gives you a multi-map.

---

## Sorting arrays (stable external sort)

```bash
# Sort values lexicographically using external sort (handles spaces safely)
sorted=()
while IFS= read -r -d '' x; do sorted+=("$x"); done < <(
  printf '%s\0' "${files[@]}" | sort -z
)
printf '%s\n' "${sorted[@]}"
```

---

## INI → associative map (simple)

```bash
# Very simple INI (no sections, no quotes/escapes)
declare -A ini=()
while IFS='=' read -r k v; do
  [[ -z $k || $k =~ ^\s*# ]] && continue
  k="${k//[[:space:]]/}"
  v="${v##[[:space:]]}"
  ini["$k"]="$v"
done < config.ini

printf 'host=%s port=%s\n' "${ini[host]}" "${ini[port]}"
```

For real INI/section parsing, prefer `python -c` or `jq` on JSON.

---

## Defensive iteration patterns

```bash
# Avoid iterating over glob expansions directly; materialize once
shopt -s nullglob
paths=(/etc/*.conf)
for p in "${paths[@]}"; do
  printf 'config: %s\n' "$p"
done
```

---

```yaml
---
id: templates/bash/60-arrays-assoc-iteration.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, arrays, associative-arrays, iteration, nameref, histogram, set-ops]
description: "Deep-dive patterns for arrays and associative maps: safe creation, passing arrays, set-like operations, histograms, grouping, and sorting."
---
```
