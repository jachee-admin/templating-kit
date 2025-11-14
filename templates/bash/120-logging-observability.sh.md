###### Bash

# Logging & Observability: Levels, JSON Logs, Journald/Syslog, Logrotate

If you can’t observe it, you can’t fix it. Standardize levels, keep stdout pure, and wire logs to journald/syslog or JSON for tools.

## TL;DR

* **stdout = data**, **stderr = logs**.
* Provide log levels and timestamps; add PID/correlation ID.
* Use JSON logs for machines; human logs for terminals.
* For system services, let **systemd/journald** capture; rotate files with **logrotate**.
* Use `BASH_XTRACEFD` for targeted `set -x` tracing.

---

## Minimal logger (human)

```bash
# levels: debug info warn error
LOG_LEVEL="${LOG_LEVEL:-info}"

_ts() { date +%FT%T%z; }
_lnum() { echo "${BASH_LINENO[0]:-0}"; }

_lvl() {
  local want="$1" ; shift
  local -A rank=([debug]=0 [info]=1 [warn]=2 [error]=3)
  (( ${rank[$want]} < ${rank[$LOG_LEVEL]} )) && return 0
  printf '%s %-5s pid=%d line=%s %s\n' "$(_ts)" "$want" "$$" "$(_lnum)" "$*" >&2
}

debug(){ _lvl debug "$*"; }
info() { _lvl info  "$*"; }
warn() { _lvl warn  "$*"; }
error(){ _lvl error "$*"; }
```

---

## JSON logger (machine)

```bash
log_json() {
  local level="$1"; shift
  jq -nc --arg ts "$(_ts)" --arg level "$level" --arg pid "$$" --arg msg "$*" \
    '{ts:$ts, level:$level, pid:($pid|tonumber), msg:$msg}'
}

# usage
log_json info "startup complete" | tee -a /var/log/myapp.json
```

---

## Split streams reliably

```bash
# data to stdout, logs to stderr
if out="$(do_work 2> >(while read -r l; do warn "$l"; done))"; then
  printf '%s\n' "$out"
else
  error "do_work failed"
  exit 1
fi
```

---

## systemd service logging

```bash
# /etc/systemd/system/myapp.service
[Unit]
Description=My Bash App
After=network-online.target

[Service]
Type=simple
User=myapp
ExecStart=/usr/local/bin/myapp.sh
Restart=on-failure
# Pass environment
Environment=LOG_LEVEL=info
# Journald captures stdout/stderr automatically

[Install]
WantedBy=multi-user.target
```

### Inspect logs

```bash
journalctl -u myapp.service -n 200 -f
journalctl -u myapp.service --since "2025-11-01 12:00"
```

---

## Syslog via `logger`

```bash
# Tag entries with program name and facility
logger -t myapp -p user.info "startup complete"
logger -t myapp -p user.err "failure on step 3"
```

---

## Log rotation (file-based)

```bash
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  create 0640 myapp adm
  postrotate
    systemctl kill -s HUP myapp.service >/dev/null 2>&1 || true
  endscript
}
```

**Tip**: send `HUP` to ask your app to reopen files after rotation.

---

## Trace debugging without flooding stdout

```bash
# Send xtrace to a dedicated FD/file
exec 5>"/tmp/myapp.trace.$$.log"
BASH_XTRACEFD=5
PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
set -x   # enable
# ... troublesome code here ...
set +x
exec 5>&-
```

---

## Capture exit codes across pipelines

```bash
set -o pipefail
if ! gzip -c data.txt | tee data.txt.gz | wc -c; then
  rc="${PIPESTATUS[*]}"   # array of stage exit codes
  error "pipeline failed: $rc"
fi
```

---

## Structured fields (correlation IDs)

```bash
CID="${CID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"
info "start cid=$CID"

# include CID in JSON logs
log_json info "phase one" | jq --arg cid "$CID" '. + {cid:$cid}'
```

---

## Terminal vs non-interactive formatting

```bash
if [[ -t 2 ]]; then
  # stderr is a terminal: add color
  RED=$'\e[31m'; YEL=$'\e[33m'; NC=$'\e[0m'
  warn "${YEL}warming up${NC}"
else
  warn "warming up"  # plain logs for files/pipes
fi
```

---

## Log sampling & rate limiting

```bash
sample_info() {
  local rate="${1:-100}"  # emit 1 in N
  (( RANDOM % rate == 0 )) && info "sampled event"
}
```

---

## Rotate your own (quick & dirty)

```bash
rotate_file() {
  local f="$1" keep="${2:-5}"
  [[ -e "$f" ]] || return 0
  for i in $(seq $((keep-1)) -1 1); do
    [[ -e "$f.$i" ]] && mv -f -- "$f.$i" "$f.$((i+1))"
  done
  mv -f -- "$f" "$f.1"
  : > "$f"
}
```

---

```yaml
---
id: docs/bash/120-logging-observability.sh.md
lang: bash
platform: posix
scope: observability
since: "v0.4"
tested_on: "bash 5.2, systemd 252+, jq 1.7"
tags: [bash, logging, journald, syslog, json, logrotate, pipefail, xtrace]
description: "Operational logging patterns: human and JSON loggers, journald/syslog integration, logrotate configs, xtrace routing, and disciplined stdout/stderr use."
---
```
