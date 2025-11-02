###### Bash

# Log Rotation Skeleton: Timestamped Archives, Compression, and Retention

A simple, portable skeleton to rotate, compress, and prune logs safely without relying on `logrotate`.
Useful for ephemeral containers or custom services that emit directly to a single file.

---

## TL;DR

* Rotates all `*.log` files in a directory by timestamp.
* Compresses with `gzip -9`.
* Retains a configurable number of days (default 14).
* Handles filenames safely (null-terminated, spaces allowed).
* Skips active log files in use by other processes.

---

## Script

```bash
#!/usr/bin/env bash
#
# rotate-logs.sh — self-contained log rotation helper
# Usage: ./rotate-logs.sh [/path/to/logdir] [keep_days]
#
# Example:
#   ./rotate-logs.sh /var/log/myapp 30
#

set -Eeuo pipefail
IFS=$'\n\t'

DIR="${1:-/var/log/myapp}"
KEEP="${2:-14}"

[[ -d "$DIR" ]] || { echo "Directory not found: $DIR" >&2; exit 1; }

log() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&2; }

log "Rotating logs in $DIR (keeping $KEEP days)..."

# Rotate each *.log file
find "$DIR" -maxdepth 1 -type f -name "*.log" -print0 |
  while IFS= read -r -d '' f; do
    [[ -s "$f" ]] || continue  # skip empty files
    ts="$(date -r "$f" +%Y%m%d-%H%M%S)"
    rotated="${f}.${ts}"

    # skip if file is actively written to (open fd)
    if lsof "$f" >/dev/null 2>&1; then
      log "Skipping active file: $f"
      continue
    fi

    log "→ Rotating $f → $rotated.gz"
    cp -- "$f" "$rotated" && : > "$f"
    gzip -9 "$rotated"
  done

# Prune old archives
log "Pruning logs older than $KEEP days..."
find "$DIR" -type f -name "*.log.*.gz" -mtime +"$KEEP" -print0 |
  xargs -0r rm -f --

log "Rotation complete."
```

---

## Notes

* This script uses **copy-then-truncate** (`cp` then `: > file`) instead of `mv` to prevent losing an open file handle that a running process may still be writing to.
* If you know logs are closed between rotations, you can safely `mv "$f" "$f.$ts"`.
* For high-volume systems, use `pigz` (parallel gzip) to speed compression:

  ```bash
  gzip() { command pigz -9 "$@"; }
  ```
* To run daily via systemd:

  ```ini
  [Unit]
  Description=Rotate MyApp Logs
  [Service]
  Type=oneshot
  ExecStart=/usr/local/bin/rotate-logs.sh /var/log/myapp 14
  [Install]
  WantedBy=multi-user.target
  ```
* Use `logrotate` for complex rotation patterns (size thresholds, postrotate scripts, etc.), but this skeleton stays self-contained and dependency-free.

---

```yaml
---
id: templates/bash/20-log-rotate-skel.sh.md
lang: bash
platform: posix
scope: maintenance
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, gzip 1.13"
tags: [bash, logs, rotation, compression, retention, maintenance]
description: "Safe, self-contained log rotation: timestamped copies, gzip compression, null-safe traversal, and retention pruning."
---
```
