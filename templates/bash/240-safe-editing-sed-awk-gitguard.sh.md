###### Bash

# Safe Bulk Editing: `sed`/`awk` with Dry-Run Diffs, Git Guardrails, and Rollback

Perform large-scale text edits **safely** with previews, git stashing, null-safe traversal, and automatic backups. No “oops, I clobbered prod”.

## TL;DR

* Always **preview** changes with `git diff` or unified diffs before writing.
* Use `find -print0 | xargs -0` for filenames.
* Write to **temp + mv** with `.bak.$(epoch)` backups.
* Keep a **git stash**/branch for easy rollback.
* For complex edits, prefer `awk` (clear logic) over multiline `sed` acrobatics.

---

## Guarded session scaffolding

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

branch="bulk-edit-$(date +%Y%m%d-%H%M%S)"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo"; exit 2; }

git stash push -u -m "pre-bulk-edit $(date -u +%FT%TZ)" >/dev/null
git checkout -b "$branch"

backup_suffix=".bak.$(date +%s)"
```

---

## Null-safe traversal + targeted selection

```bash
# Select only tracked text files (example: *.conf and scripts)
git ls-files -z '*.conf' '*.service' '*.sh' \
  | xargs -0 -I{} printf '%s\0' "{}" > /tmp/targets.zlist
```

---

## Dry-run preview with sed

```bash
# Example rule: Port 22 -> 2222 (show diff only)
while IFS= read -r -d '' f; do
  diff -u --label "$f (orig)" --label "$f (edit)" \
    "$f" <(sed -E 's/^#?Port 22$/Port 2222/' "$f") || true
done < /tmp/targets.zlist
```

---

## Apply with backups + atomic move

```bash
apply_rule() {
  local f="$1" tmp
  tmp="$(mktemp "${f##*/}.XXXX")"
  sed -E 's/^#?Port 22$/Port 2222/' "$f" >"$tmp"
  cp -a -- "$f" "$f$backup_suffix"
  mv -f -- "$tmp" "$f"
}
export backup_suffix
while IFS= read -r -d '' f; do apply_rule "$f"; done < /tmp/targets.zlist
```

---

## Post-edit verification

```bash
# Grep to confirm change, then run shellcheck on scripts we touched
while IFS= read -r -d '' f; do
  grep -nE '^Port 2222$' -- "$f" || echo "WARN: no match in $f" >&2
done < /tmp/targets.zlist

# Lint only changed shell files
changed_sh=()
while IFS= read -r f; do [[ $f == *.sh ]] && changed_sh+=("$f"); done < <(git diff --name-only)
((${#changed_sh[@]})) && shellcheck -x "${changed_sh[@]}" || true
```

---

## Git review, commit, and rollback lever

```bash
git add -A
git diff --staged | sed -n '1,200p'   # spot check

read -r -p "Commit changes? [y/N] " ans
if [[ $ans =~ ^[Yy] ]]; then
  git commit -m "Bulk edit: Port 22→2222 (safe-editing template)"
  echo "Committed on branch: $branch"
else
  echo "Reverting edits..."
  git restore --staged .
  git checkout .
  # restore from backups if needed
  while IFS= read -r -d '' f; do
    [[ -e "$f$backup_suffix" ]] && mv -f -- "$f$backup_suffix" "$f"
  done < /tmp/targets.zlist
  git switch - 2>/dev/null || true
  echo "Rolled back."
fi
```

---

## Multi-rule driver (extensible)

```bash
rule_ports() { sed -E 's/^#?Port 22$/Port 2222/'; }
rule_banner() { sed -E 's/^#?Banner .*/Banner \/etc\/issue/'; }

apply_rules() {
  local f="$1" tmp; tmp="$(mktemp "${f##*/}.XXXX")"
  <"$f" rule_ports | rule_banner >"$tmp"
  cp -a -- "$f" "$f$backup_suffix"
  mv -f -- "$tmp" "$f"
}
export -f rule_ports rule_banner apply_rules
xargs -0 -a /tmp/targets.zlist -I{} bash -c 'apply_rules "$@"' _ {}
```

---

## Awk example (clearer for structured edits)

```bash
# Update key=value style configs
awk -F= '
  $1 ~ /^[[:space:]]*Port[[:space:]]*$/ { $2=" 2222"; changed=1 }
  { print }
  END { if (!changed) exit 3 }
' OFS='=' file.conf
```

---

## Safety checklist

* Always keep **backups**; name them with timestamps.
* Never edit outside the repo without explicit paths and `--`.
* For non-git trees, snapshot directory with `tar -cpf` before edits.
* If any step fails mid-flight, stop and **restore from backups**.

---

```yaml
---
id: templates/bash/240-safe-editing-sed-awk-gitguard.sh.md
lang: bash
platform: posix
scope: refactor
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, git 2.44+, sed/awk (GNU)"
tags: [bash, sed, awk, bulk-edit, git, backup, diff, rollback, print0]
description: "Safe bulk editing flows: null-safe traversal, dry-run diffs, backups, atomic writes, git stash/branch guardrails, and awk alternatives for clarity."
---
```
