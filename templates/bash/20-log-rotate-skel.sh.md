---
id: bash/log-rotate-skel
lang: bash
since: "v0.1"
tags: [bash, logs]
description: "Rotate and compress logs with retention"
---

### Script
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

DIR="${1:-/var/log/myapp}"
KEEP="${2:-14}"
find "$DIR" -type f -name "*.log" -mtime +0 -print0 | while IFS= read -r -d '' f; do
  ts=$(date -r "$f" +%Y%m%d-%H%M%S)
  mv "$f" "$f.$ts"
  gzip -9 "$f.$ts"
done

# prune old archives
find "$DIR" -type f -name "*.log.*.gz" -mtime +"$KEEP" -delete
```
