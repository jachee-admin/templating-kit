###### Bash

# Migration Playbooks: Scriptable Multi-Step Refactors with Checkpoints, Resume, and Rollback

Turn risky changes into controlled choreography. Define a plan, run step-by-step with checkpoints, lock execution, persist state, and roll back cleanly.

## TL;DR

* **Plan → Preflight → Apply → Verify → Finalize**.
* Single-instance lock with `flock`; state stored in a **JSON state file**.
* Each step is **idempotent**; steps record `started/finished/rc`.
* **Resume** from last completed step; **rollback** when verification fails.
* Emit a **human summary** and machine-readable **state** at the end.

---

## Playbook skeleton

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

LOCK="/var/lock/migrate.myapp.lock"
STATE="${STATE:-.migrate.state.json}"
exec 9>"$LOCK"; flock -n 9 || { echo "Another migration is running"; exit 0; }

# Steps registry
STEPS=(preflight backup refactor_config bump_ports data_migrate verify finalize)
current_step=""

# State helpers
jq_state() { jq "$@" "$STATE" 2>/dev/null || jq -n "$@" ; }
mark_started()  { step="$1"; jq_state ".steps.$step.started = now" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
mark_finished() { step="$1"; rc="$2"; jq_state ".steps.$step.finished = now | .steps.$step.rc = $rc" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
is_done()       { step="$1"; jq -e ".steps.$step.rc==0" "$STATE" >/dev/null 2>&1; }

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&2; }
```

---

## Preflight (fail early)

```bash
preflight() {
  log "preflight checks"
  for cmd in jq rsync tar; do command -v "$cmd" >/dev/null || { log "missing $cmd"; return 2; }; done
  [[ -d /srv/app && -r /etc/myapp/app.ini ]] || { log "paths missing"; return 2; }
}
```

---

## Backup (snapshot)

```bash
backup() {
  log "snapshot /srv/app and config"
  dest="/var/backups/myapp/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dest"
  tar --numeric-owner -cpzf "$dest/app.tgz" -C /srv app
  cp -a -- /etc/myapp/app.ini "$dest/app.ini"
  sha256sum "$dest/"* > "$dest/manifest.sha256"
}
```

---

## Refactor config (idempotent key rename)

```bash
refactor_config() {
  log "rename config key 'server_port' -> 'http.port'"
  cfg="/etc/myapp/app.ini"
  # Only change if not already applied
  if grep -qE '^server_port[[:space:]]*=' "$cfg"; then
    cp -a -- "$cfg" "$cfg.bak.$(date +%s)"
    awk -F= '
      $1 ~ /^[[:space:]]*server_port$/ { $1="http.port" }
      { print }
    ' OFS='=' "$cfg" > "$cfg.new" && mv -f -- "$cfg.new" "$cfg"
  fi
}
```

---

## Bump ports safely (firewall/service)

```bash
bump_ports() {
  log "update systemd unit and firewall"
  sed -i.bak -E 's/^#?Port 22$/Port 2222/' /etc/ssh/sshd_config
  # Example service port bump; keep idempotent
  sed -i.bak -E 's/ListenPort=8080/ListenPort=8081/' /etc/systemd/system/myapp.service
  systemctl daemon-reload
}
```

---

## Data migration (batched, resumable)

```bash
data_migrate() {
  log "data migration in batches of 10k"
  marker="${STATE}.batch"
  start="${1:-$(cat "$marker" 2>/dev/null || echo 0)}"
  total="$(wc -l < /srv/app/data/records.ndjson)"
  while read -r block_start; do
    block_end=$(( block_start + 9999 ))
    jq -c 'select(.status=="legacy") | .status="ok"' \
      < /srv/app/data/records.ndjson \
      | sed -n "$block_start,$block_end p" \
      >> /srv/app/data/records.migrated.ndjson
    echo "$((block_end+1))" > "$marker"
  done < <(seq "$start" 10000 "$total")
}
```

---

## Verify (consistency & health)

```bash
verify() {
  log "verify migrated data count and service health"
  want="$(jq -r '.[0]' < /srv/app/data/expected_count.json 2>/dev/null || echo 0)"
  got="$(jq -r 'select(.status=="ok") | 1' < /srv/app/data/records.migrated.ndjson | wc -l || echo 0)"
  if [[ "$got" -lt "$want" ]]; then
    log "mismatch: got=$got want=$want"; return 22
  fi
  curl -fsS --max-time 2 http://127.0.0.1:8081/health >/dev/null
}
```

---

## Finalize (publish atomically + cleanup)

```bash
finalize() {
  log "publish and cleanup"
  ln -sfn /srv/app /srv/app.current
  rm -f -- "${STATE}.batch" 2>/dev/null || true
}
```

---

## Runner with resume/rollback

```bash
run_step() {
  local s="$1"
  is_done "$s" && { log "skip $s (already done)"; return 0; }
  mark_started "$s"; set +e; "$s"; rc=$?; set -e
  mark_finished "$s" "$rc"
  return "$rc"
}

rollback() {
  log "attempting rollback"
  # Example rollback: restore config backup if present
  lastbak="$(ls -1t /etc/myapp/app.ini.bak.* 2>/dev/null | head -1 || true)"
  [[ -n $lastbak ]] && mv -f -- "$lastbak" /etc/myapp/app.ini
  systemctl daemon-reload || true
  systemctl restart myapp || true
}

main() {
  for s in "${STEPS[@]}"; do
    current_step="$s"
    if ! run_step "$s"; then
      log "step '$s' failed; starting rollback"
      rollback
      exit 1
    fi
  done
  log "migration complete"
}
main "$@"
```

---

## Human summary

```bash
jq '.steps | to_entries | map({step:.key, rc:.value.rc, started:.value.started, finished:.value.finished})' "$STATE" \
  | jq -r '.[] | "\(.step)\t\(.rc)\t\(.started // "n/a")\t\(.finished // "n/a")"'
```

---

## CI/Change-management notes

* Attach the **plan** (this file), **STATE JSON**, and the **backup manifest** to the ticket.
* Require a **dry-run** on a staging clone before production (toggle with `DRYRUN=1` and guarding `run` helper if you integrate one).
* Use **change windows** and **on-call** confirmations; timebox each step.

---

```yaml
---
id: templates/bash/260-migration-playbooks.sh.md
lang: bash
platform: posix
scope: migration
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, jq 1.7, systemd 252+"
tags: [bash, migration, playbook, checkpoints, resume, rollback, state, flock]
description: "Scriptable migrations with checkpoints and resume: preflight, backup, idempotent steps, verification, rollback, and machine-readable state for audits."
---
```

