###### Bash

# Incident Tooling: Triage, Quarantine, Forensics, and Immutable Evidence Capture

When production burns, stay calm and gather facts. These patterns automate safe evidence capture, isolation, and structured triage logs.

## TL;DR

* Collect before you fix. Timestamp everything.
* Write **immutable artifacts** (append-only, checksummed).
* Quarantine with `mv`, never `rm`.
* Always include **who/when/where** in triage metadata.
* Compress and sign bundles with `sha256sum` + `gpg` or `age`.

---

## Triage session header

```bash
SESSION_ID="$(date +%Y%m%d-%H%M%S)-$$"
TRIAGE_DIR="/var/triage/$SESSION_ID"
mkdir -p "$TRIAGE_DIR"
echo "Triage session $SESSION_ID" >&2
```

---

## System snapshot

```bash
collect_system() {
  {
    echo "# uname"
    uname -a
    echo "# uptime"
    uptime
    echo "# df -h"
    df -h
    echo "# top -b -n1 | head -20"
    top -b -n1 | head -20
    echo "# ps auxf"
    ps auxf
    echo "# netstat -tulpn"
    netstat -tulpn || ss -tulpn
    echo "# journalctl -n 200"
    journalctl -n 200 --no-pager 2>/dev/null || true
  } >"$TRIAGE_DIR/system.txt"
}
collect_system
```

---

## Targeted process capture

```bash
collect_proc() {
  local pid="$1" out="$TRIAGE_DIR/proc_${pid}.txt"
  [[ -d /proc/$pid ]] || return
  {
    echo "# lsof"
    lsof -p "$pid"
    echo "# env"
    cat /proc/$pid/environ | tr '\0' '\n'
    echo "# limits"
    cat /proc/$pid/limits
    echo "# cmdline"
    cat /proc/$pid/cmdline | tr '\0' ' '
  } >"$out"
}
pgrep myapp | while read -r pid; do collect_proc "$pid"; done
```

---

## File & config snapshot

```bash
snapshot_tree() {
  local path="$1" out="$TRIAGE_DIR/snapshot_${path//\//_}.tar.gz"
  tar --numeric-owner -cpzf "$out" --exclude='*.tmp' -- "$path"
}
snapshot_tree "/etc/myapp"
```

---

## Immutable evidence: compress & hash

```bash
cd /var/triage
tar -cpzf "${SESSION_ID}.tar.gz" "$SESSION_ID"
sha256sum "${SESSION_ID}.tar.gz" > "${SESSION_ID}.sha256"
```

---

## Sign evidence (optional)

```bash
gpg --local-user ops@example.net --detach-sign "${SESSION_ID}.tar.gz"
# or encrypt to security team
age -r ops@company.com -o "${SESSION_ID}.tar.gz.age" "${SESSION_ID}.tar.gz"
```

---

## Quarantine suspicious files

```bash
quarantine_dir="/var/quarantine/$SESSION_ID"
mkdir -p "$quarantine_dir"
find /srv/app -type f -name '*.sh' -mmin -5 -print0 \
  | xargs -0 -I{} mv -- "{}" "$quarantine_dir/"
```

---

## Forensic hash of directory

```bash
(cd /srv/app && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$TRIAGE_DIR/app_hashes.txt"
```

---

## Immutable triage log

```bash
LOG="$TRIAGE_DIR/triage.log"
exec 3>>"$LOG"
printf '%s start triage pid=%s user=%s\n' "$(date +%FT%T)" "$$" "$USER" >&3

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&3; }

log "collected system snapshot"
log "hashes complete"
```

---

## Network capture (short)

```bash
timeout 30 tcpdump -nn -s 512 -w "$TRIAGE_DIR/traffic.pcap" host 10.0.0.5
```

---

## Immutable permissioning

```bash
chmod -R a-w "$TRIAGE_DIR"
chown -R root:security "$TRIAGE_DIR"
```

---

## Generate summary

```bash
jq -n --arg id "$SESSION_ID" \
      --arg host "$(hostname)" \
      --arg user "$USER" \
      --arg files "$(find "$TRIAGE_DIR" -type f | wc -l)" \
      '{session:$id, host:$host, user:$user, file_count:($files|tonumber)}' \
> "$TRIAGE_DIR/summary.json"
```

---

## Upload bundle (out-of-band)

```bash
scp -o ControlMaster=no -o StrictHostKeyChecking=yes \
  "$TRIAGE_DIR/summary.json" security@bastion:/var/secure-intake/
```

---

## Cleanup script (after sign-off)

```bash
cleanup_triage() {
  local keep_days=30
  find /var/triage -maxdepth 1 -type d -mtime +$keep_days -exec rm -rf -- {} +
}
cleanup_triage
```

---

## Post-mortem baseline: automate diffing

```bash
# Compare two hash snapshots
diff -u \
  <(cut -d' ' -f1 "$old/app_hashes.txt" | sort) \
  <(cut -d' ' -f1 "$new/app_hashes.txt" | sort)
```

---

```yaml
---
id: docs/bash/200-incident-tooling.sh.md
lang: bash
platform: posix
scope: incident
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, tar 1.34, gpg 2.4, age 1.1"
tags: [bash, incident-response, triage, forensic, quarantine, hash, tar, audit, gpg, age]
description: "Incident-response toolkit: automated triage collection, process and file snapshots, immutable archives, quarantines, hashing, signing, and evidence upload."
---
```
