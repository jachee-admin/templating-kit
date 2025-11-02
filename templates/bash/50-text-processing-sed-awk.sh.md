###### Bash

# Text Processing with `grep`/`sed`/`awk` (and friends)

High-leverage text moves for logs, configs, CSV-ish data, and report generation. Focused on **safety**, **portability**, and **zero surprise** behavior.

## TL;DR

* Prefer `LC_ALL=C` for raw byte-speed when you don’t need Unicode semantics.
* Quote variables, and prefer `printf` to `echo`.
* For edits, don’t clobber files: write to a temp, verify, then move.
* Multiline `sed` is possible (pattern space & hold space), but sometimes `awk` is clearer.
* CSV is a landmine; if quotes/escapes matter, reach for `jq` (JSON) or Python.

---

## Grep: precise patterns, context, performance

```bash
# Basic grep with context lines
grep -nE 'ERROR|FATAL' app.log              # -E: extended regex
grep -nE 'ERROR|FATAL' -C2 app.log          # +/-2 lines of context
grep -nE '^\s*#' *.conf                     # leading comment lines

# Fast path when you don’t need locale collation
LC_ALL=C grep -nF 'needle' bigfile          # -F: fixed strings (no regex)
```

**Tips**

* `-F` beats regex for plain substrings.
* `-r` (recursive) + `--include='*.{sh,service}'` keeps searches scoped.
* For binary safety, add `-a` (treat as text) if needed.

---

## Sed: surgical edits, in-place with backups

```bash
# Replace text safely (GNU/BSD compatible)
sed -E 's/\<dev\>/prod/g' config.ini > config.ini.new && mv config.ini.new config.ini

# In-place with backup (GNU sed: -i, BSD sed: -i '')
sed -i.bak -E 's/^Port .*/Port 2222/' /etc/ssh/sshd_config   # creates .bak

# Delete lines matching a pattern
sed -E '/^\s*#/d' file        # drop comments
sed -E '/^$/d' file           # drop empty lines

# Insert after a match
sed -E '/^\[default\]$/a region = us-east-1' config.ini

# Extract a block between markers (inclusive)
sed -n '/^BEGIN CONFIG$/,/^END CONFIG$/p' file
```

### Multiline sed (pattern space & hold space)

```bash
# Join lines that end with a backslash and print as single logical lines
sed -E ':a; /\\$/ { N; s/\\\n//; ba }' file

# Swap adjacent lines (toy example)
sed -n 'N; s/\n/ /; p; D' file
```

**Reality check:** If the logic feels like line-oriented assembly, consider `awk` for readability.

---

## Awk: structured line parsing & reporting

```bash
# Count requests per status code (space-delimited)
awk '{ count[$9]++ } END { for (k in count) printf "%s %d\n", k, count[k] }' access.log | sort -n

# CSV-ish with a simple delimiter (pure awk; naive about quotes)
awk -F',' '{ printf "%-20s %6.2f\n", $1, $3 }' data.csv

# Tab-delimited (safer; tabs rarely appear in fields)
awk -F'\t' -v OFS='\t' '{ $3 = toupper($3); print }' data.tsv

# Field guards & defaults
awk -F':' 'NF>=7 { shell=$7 } NF<7 { shell="/bin/false" } { print $1, shell }' /etc/passwd
```

### Awk with conditions and computed keys

```bash
# Histogram by hour from "2025-11-01T13:42:00Z something" lines
awk -F'[T:]' '/^[0-9]{4}-[0-9]{2}-[0-9]{2}T/ { hour=$2; h[hour]++ } END { for (k in h) printf "%02d %d\n", k, h[k] }' app.log | sort -n
```

### When CSV has quotes/commas inside fields

* `awk -F,` will **not** handle `"a,b"` as one field. Use a proper CSV parser (Python `csv`), or convert sources to JSON and use `jq`.
* Example: parse JSON lines quickly:

```bash
jq -r '.items[] | [.id, .name, .status] | @tsv' data.json | awk -F'\t' '{print $1,$2,$3}'
```

---

## find/xargs: null-safety for arbitrary filenames

```bash
# Grep only *.conf files, null-safe
find /etc -type f -name '*.conf' -print0 | xargs -0 grep -nH 'PermitRootLogin'

# Run sed in-place across matching files (backup .bak)
find . -type f -name '*.service' -print0 |
  xargs -0 sed -i.bak -E 's/Restart=on-failure/Restart=always/'
```

**Rule:** Use `-print0` with `-0` whenever filenames might contain spaces/newlines/UTF-8 weirdness.

---

## Report generation: join data streams

```bash
# Join two TSV files by key (requires coreutils join)
# users.tsv: id\tname
# events.tsv: id\tevents
join -t $'\t' -1 1 -2 1 <(sort -t $'\t' -k1,1 users.tsv) <(sort -t $'\t' -k1,1 events.tsv) |
awk -F'\t' '{ printf "%s\t%s\t%s\n", $1, $2, $3 }'
```

---

## Multiline record parsing with awk

```bash
# Parse blocks separated by blank lines
awk -v RS='' -v ORS='\n\n' '
{
  for (i=1; i<=NF; i++) if ($i ~ /^ID=/) { sub(/^ID=/,"",$i); id=$i }
  print "BLOCK for id=" id "\n" $0
}' records.txt
```

---

## Edits with audit trail (no data loss)

```bash
inplace_edit() {
  local file="$1" expr="$2"
  local tmp; tmp="$(mktemp "${file##*/}.XXXX")" || return 1
  sed -E "$expr" "$file" >"$tmp" && cp -a -- "$file" "$file.bak.$(date +%s)" &&
    mv -- "$tmp" "$file"
}
inplace_edit "sshd_config" 's/^#?PasswordAuthentication .*/PasswordAuthentication no/'
```

---

## Performance knobs

* `LC_ALL=C` speeds up byte-wise ops (`grep`, `sort`, `tr`) when Unicode isn’t needed.
* Prefer single pass: `awk` can often replace a `grep | sed | cut` pipeline.
* Replace `cat file | cmd` with redirection where possible: `cmd < file`.
* For huge streams, avoid backreferences in `sed -E` if you can; they’re costly.

---

```yaml
---
id: templates/bash/50-text-processing-sed-awk.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, grep, sed, awk, text-processing, find, xargs, jq]
description: "Reliable patterns for searching, editing, and reporting with grep/sed/awk, null-safe file traversal, and practical CSV/JSON notes."
---
```

