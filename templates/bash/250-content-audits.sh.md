###### Bash

# Content Audits: Regex Scans, Allow/Deny Lists, SPDX/License Headers, Secret & Entropy Checks, and Reports

Automate repo hygiene: scan for risky patterns, enforce headers, and emit a clear report. Always null-safe, diff-friendly, and CI-ready.

## TL;DR

* Traverse with `find -print0 | xargs -0` to survive “weird” filenames.
* Compile **allow/deny lists** once; pass through a single null-safe pipeline.
* Check **SPDX** license headers and **shebangs** for scripts.
* Secret scanning uses **regex + entropy**; treat matches as **suspect** not proof.
* Emit machine-readable **JSON** and a human summary; exit non-zero on blocking issues.

---

## Target selection (tracked text files)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Use git if available; fall back to find
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files -z ':!:*.png' ':!:*.jpg' ':!:*.pdf' ':!:*.gz' > /tmp/audit.zlist
else
  find . -type f \
    ! -name '*.png' ! -name '*.jpg' ! -name '*.pdf' ! -name '*.gz' \
    -print0 > /tmp/audit.zlist
fi
```

---

## Deny/allow lists (centralized)

```bash
# denylist.regex: one ERE per line (example: hard-coded keys, temp passwords)
cat > /tmp/denylist.regex <<'RE'
AKIA[0-9A-Z]{16}
(?i)password\s*=\s*.+$
-----BEGIN (EC|RSA|OPENSSH) PRIVATE KEY-----
RE

# allowlist.regex: suppress false positives (paths/comments)
cat > /tmp/allowlist.regex <<'RE'
tests?/.*(fixture|sample|example)
# SPDX headers and commented examples:
^\s*#\s*example:\s*
RE
```

---

## SPDX & license headers

```bash
require_spdx() {
  local f="$1"
  case "$f" in
    *.sh|*.py|*.pl|*.rb|*.js|*.ts|*.go|*.c|*.h|*.java|*.scala)
      grep -qE 'SPDX-License-Identifier:\s*(MIT|Apache-2.0|BSD-3-Clause|GPL-3.0-or-later)' -- "$f"
      ;;
    *) return 0 ;;
  esac
}

check_spdx() {
  local fail=0
  while IFS= read -r -d '' f; do
    require_spdx "$f" || { printf 'MISSING SPDX: %s\n' "$f"; fail=1; }
  done < /tmp/audit.zlist
  return "$fail"
}
```

---

## Shebang checks (scripts only)

```bash
is_script() { head -c 2 "$1" | grep -q '^#!'; }

check_shebangs() {
  local fail=0
  while IFS= read -r -d '' f; do
    is_script "$f" || continue
    head -n1 -- "$f" | grep -qE '^#!/usr/bin/env (bash|python3|perl|ruby|node)$' || {
      printf 'SHEBANG WARN: %s\n' "$f"; fail=1;
    }
  done < /tmp/audit.zlist
  return "$fail"
}
```

---

## Secret scan: regex + entropy heuristic

```bash
entropy() {  # Shannon entropy over base64-ish alphabet
  awk '
    function log2(x){return log(x)/log(2)}
    {n=split($0,a,""); for(i=1;i<=n;i++) f[a[i]]++}
    END{sum=0; for(k in f) {p=f[k]/n; sum+=-p*log2(p)}; print sum}
  '
}

scan_secrets() {
  local hits="/tmp/hits.ndjson"; : > "$hits"
  while IFS= read -r -d '' f; do
    # Regex pass
    if grep -nE -f /tmp/denylist.regex -- "$f" | grep -Ev -f /tmp/allowlist.regex -n || true; then
      while IFS=: read -r file line text; do
        # Entropy filter: long tokens likely secrets
        token="$(printf '%s' "$text" | grep -Eo '[A-Za-z0-9_\-+/=]{20,}' | head -1 || true)"
        ent="0"; [[ -n $token ]] && ent="$(printf '%s' "$token" | entropy)"
        jq -nc --arg f "$file" --arg l "$line" --arg t "$text" --arg ent "$ent" \
          '{file:$f,line:($l|tonumber),match:$t,entropy:($ent|tonumber)}' >> "$hits"
      done < <(grep -nE -f /tmp/denylist.regex -- "$f" || true)
    fi
  done < /tmp/audit.zlist
  printf '%s\n' "$hits"
}
```

---

## File headers auto-fix (SPDX inject)

```bash
add_spdx() {
  local f="$1" lic="${2:-Apache-2.0}"
  if head -n1 "$f" | grep -q '^#!'; then
    # Preserve shebang
    { head -n1 "$f"; echo "# SPDX-License-Identifier: $lic"; tail -n +2 "$f"; } > "$f.new" && mv "$f.new" "$f"
  else
    { printf '# SPDX-License-Identifier: %s\n' "$lic"; cat "$f"; } > "$f.new" && mv "$f.new" "$f"
  fi
}

auto_fix_spdx() {
  while IFS= read -r -d '' f; do
    require_spdx "$f" || add_spdx "$f" "Apache-2.0"
  done < /tmp/audit.zlist
}
```

---

## Summary report (human + JSON)

```bash
HUM="/tmp/audit-summary.txt"
JSON="/tmp/audit-summary.json"

spdx_missing=$(check_spdx || true)
shebang_issues=$(check_shebangs || true)
hits_file="$(scan_secrets)"

jq -s '{
  spdx_missing: ( .[0] // [] ),
  shebang_issues: ( .[1] // [] ),
  secrets: ( input | (try (reduce inputs as $i ([]; . + $i)) catch []) )
}' <(printf '[]') <(printf '[]') "$hits_file" > "$JSON"

# Human overview
{
  echo "# Audit Summary $(date -u +%FT%TZ)"
  echo "SPDX missing: $(grep -c '^MISSING SPDX' <<<"$spdx_missing" || echo 0)"
  echo "Shebang issues: $(grep -c '^SHEBANG WARN' <<<"$shebang_issues" || echo 0)"
  echo "Secret suspects: $(jq '. | length' "$hits_file" 2>/dev/null || echo 0)"
} > "$HUM"
```

---

## CI policy

* **Block** on missing SPDX or high-entropy secret suspects.
* **Warn** on shebang style differences (unless policy says block).
* Attach `$HUM` and `$JSON` as artifacts; print top 20 findings in job logs.

```bash
fail=0
grep -q '^MISSING SPDX' <<<"$spdx_missing" && fail=1
if [[ -s "$hits_file" ]] && jq -e 'map(select(.entropy>=3.5)) | length>0' "$hits_file" >/dev/null; then
  fail=1
fi
exit "$fail"
```

---

```yaml
---
id: docs/bash/250-content-audits.sh.md
lang: bash
platform: posix
scope: audit
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, jq 1.7, git 2.44+"
tags: [bash, audit, regex, allowlist, denylist, SPDX, shebang, secrets, entropy, CI]
description: "Repository content audits: null-safe traversal, allow/deny lists, SPDX/license and shebang checks, regex+entropy secret scanning, and JSON/human reports for CI."
---
```