---
id: bash/strict-mode
lang: bash
since: "v0.1"
tags: [bash, strict, logging]
description: "Strict mode + minimal logging"
---

### Bash: Strict mode
```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

log() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }
trap 'log "ERR at line $LINENO"' ERR

usage(){ echo "Usage: $0 [-n]"; }
while getopts ":n" opt; do
  case "$opt" in
    n) DRYRUN=1 ;;
    :) usage; exit 2 ;;
  esac
done

main(){
  log "Starting"
  # your code here
  log "Done"
}
main "$@"
```
