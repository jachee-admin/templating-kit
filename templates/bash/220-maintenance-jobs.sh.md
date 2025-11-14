###### Bash

# Maintenance Jobs: Schedules, Safe Rotation, Vacuuming, Integrity Checks, and Reports

Maintenance should be **boring** and **idempotent**. Use timers, locks, dry-runs, and reports you can skim at 6am without coffee.

## TL;DR

* Schedule via **systemd timers** (prefer over bare cron for logging/journals).
* Enforce **single-instance** with `flock`.
* Do **dry-run** and **quarantine** instead of `rm` on first pass.
* Produce a **summary report** with exit codes that CI and humans can parse.
* Tag artifacts with timestamps and keep **retention** policies explicit.

---

## Single-instance job skeleton

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

LOCK="/var/lock/maint.cleanup.lock"
exec 9>"$LOCK" || exit 1
flock -n 9 || { echo "Already running"; exit 0; }

DRYRUN="${DRYRUN:-0}"
log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&2; }

run() { log "+ $*"; (( DRYRUN )) || "$@"; }

# Example: prune old logs with quarantine
Q="/var/quarantine/$(date +%Y%m%d)"
mkdir -p "$Q"
find /var/log/myapp -type f -mtime +14 -print0 |
  xargs -0 -I{} bash -c 'run mv -- "$1" "'"$Q"'/"' _ {}

log "done"
```

---

## systemd timer + service

```ini
# /etc/systemd/system/myapp-maint.service
[Unit]
Description=MyApp maintenance

[Service]
Type=oneshot
User=myapp
ExecStart=/usr/local/bin/myapp_maint.sh
```

```ini
# /etc/systemd/system/myapp-maint.timer
[Unit]
Description=Daily MyApp maintenance

[Timer]
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
```

`Persistent=true` runs missed executions on boot.

---

## Rotation with retention (files & dirs)

```bash
rotate_keep() {
  local path="$1" keep="${2:-7}"
  shopt -s nullglob
  mapfile -t items < <(ls -1t -- "$path"/* 2>/dev/null || true)
  for ((i=keep; i<${#items[@]}; i++)); do
    run rm -rf -- "${items[$i]}"
  done
}
rotate_keep "/var/backups/myapp" 10
```

---

## Postgres vacuum/analyze (lightweight)

```bash
# Requires psql configured in .pgpass or service user
psql "${PGURL:-postgres://app@db/app}" <<'SQL'
VACUUM (VERBOSE, ANALYZE);
SQL
```

---

## SQLite/Local DB maintenance

```bash
db="${DB:-/var/lib/myapp/app.db}"
run sqlite3 "$db" 'PRAGMA wal_checkpoint(TRUNCATE); VACUUM;'
```

---

## Checksums & integrity report

```bash
OUT="/var/reports/maint_$(date +%Y%m%d).txt"
mkdir -p "${OUT%/*}"

sum_file() { sha256sum "$1" | awk '{print $1}'; }

{
  echo "# MyApp maintenance $(date -u +%FT%TZ)"
  echo "vacuum: ok"
  echo "rotation: ok"
  echo "hash app.config: $(sum_file /etc/myapp/app.ini)"
} > "$OUT"
```

---

## Backups (rsync + manifest)

```bash
BK="/var/backups/myapp/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
run rsync -a --delete /srv/myapp/data/ "$BK/data/"
find "$BK" -type f -print0 | sort -z | xargs -0 sha256sum > "$BK/manifest.sha256"
```

---

## Email/Slack summary (outbound hook)

```bash
SLACK_URL="${SLACK_URL:-}"
if [[ -n $SLACK_URL ]]; then
  jq -n --arg text "MyApp maintenance complete $(date +%FT%T)" \
     '{text:$text}' \
  | curl -fsS -H 'Content-Type: application/json' --data-binary @- "$SLACK_URL" || true
fi
```

---

## Cron variant (if you must)

```bash
# /etc/cron.d/myapp-maint
# 15 3 * * * myapp flock -n /var/lock/maint.cleanup.lock /usr/local/bin/myapp_maint.sh >>/var/log/myapp/maint.log 2>&1
```

---

## Safety rails

* Always **quote** vars and use `--` before paths.
* Start new jobs in a **tmp staging dir**; publish with atomic `mv` (see 100-filesystem-safety).
* For long tasks, emit a **heartbeat** metric to your textfile collector.

---

```yaml
---
id: docs/bash/220-maintenance-jobs.sh.md
lang: bash
platform: posix
scope: maintenance
since: "v0.4"
tested_on: "bash 5.2, systemd 252+, coreutils 9.x, psql 16+"
tags: [bash, maintenance, systemd-timer, flock, rotation, vacuum, backups, reports]
description: "Idempotent, single-instance maintenance jobs with systemd timers: retention rotation, DB vacuum, integrity checks, backups, and human-friendly reports."
---
```
