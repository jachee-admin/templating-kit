###### Bash

# Tempfiles, PID Files, Single-Instance Locks & Safe Cleanup

Make scripts **crash-resistant** and **concurrency-safe**. Use race-free tempfiles, robust cleanup, and lock strategies that work on real systems with weird filenames and impatient operators.

## TL;DR

* Always create temps with `mktemp` (files or `-d` for dirs).
* Register cleanup with `trap ... EXIT` early; pair with `set -Eeuo pipefail`.
* For single-instance: prefer `flock` on a dedicated FD; if unavailable, emulate with `mkdir` lockdirs.
* PID files are fine **only** when combined with atomic create (`noclobber`) and liveness checks.

---

## Safe tempfiles & tempdirs

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

tmpd="$(mktemp -d)"
cleanup() { [[ -d $tmpd ]] && rm -rf -- "$tmpd"; }
trap cleanup EXIT

# Create temp files inside our private dir
cfg="$tmpd/config.$$"
log="$tmpd/run.log"

printf '[default]\n' >"$cfg"
printf 'working in %s\n' "$tmpd" >>"$log"
```

**Why**: `mktemp -d` avoids TOCTOU races. Keeping all temps inside one private dir simplifies cleanup.

---

## In-place edits with audit trail (atomic-ish)

```bash
safe_replace() {
  local src="$1" expr="$2" tmp
  tmp="$(mktemp "${src##*/}.XXXX")"
  sed -E "$expr" "$src" >"$tmp"
  cp -a -- "$src" "$src.bak.$(date +%s)"
  mv -- "$tmp" "$src"
}
safe_replace "/etc/sshd_config" 's/^#?Port .*/Port 2222/'
```

---

## Single-instance with `flock` (preferred)

```bash
# Lock file and dedicated FD
lockfile="/var/lock/myjob.lock"
exec 9>"$lockfile"            # open for writing
if ! flock -n 9; then
  printf 'Another instance is running.\n' >&2
  exit 0
fi

# Optional: keep metadata in the lockfile
printf 'pid=%s\nstarted=%(%FT%T)T\n' "$$" -1 1>&9
```

**Notes**

* `flock -n` is non-blocking; drop `-n` to wait.
* Works even across users if permissions allow.
* Close FD 9 at exit implicitly; the OS releases the lock with the process.

---

## Single-instance without `flock`: lockdir pattern

```bash
lockdir="/var/lock/myjob.lockdir"
if mkdir "$lockdir" 2>/dev/null; then
  # We own the lockdir; arrange cleanup
  trap 'rmdir -- "$lockdir"' EXIT
  printf '%s\n' "$$" > "$lockdir/pid"
else
  # Check if stale
  if [[ -f "$lockdir/pid" ]] && ps -p "$(cat "$lockdir/pid")" >/dev/null 2>&1; then
    echo "Another instance is active" >&2; exit 0
  fi
  # Try to force-claim (rare race possible; acceptable for many jobs)
  rmdir "$lockdir" 2>/dev/null || true
  mkdir "$lockdir" || { echo "Could not acquire lock" >&2; exit 1; }
  trap 'rmdir -- "$lockdir"' EXIT
fi
```

**Trade-offs**: portable, but you must guard against stale lockdirs; a tiny race remains between remove/create.

---

## PID file with atomic create

```bash
pidfile="/run/myjob.pid"
# Refuse to overwrite (noclobber)
( umask 022; : > "$pidfile" ) 2>/dev/null || true  # ensure parent dir perms

exec 8>>"$pidfile"       # open extra FD to hold the file
if ! printf '%d\n' "$$" 1>&8; then
  echo "Cannot write pidfile" >&2; exit 1
fi
# Best effort: if pidfile already had content, someone else wrote first
# Validate liveness:
oldpid="$(head -n1 "$pidfile" || true)"
if [[ $oldpid != "$$" ]] && ps -p "$oldpid" >/dev/null 2>&1; then
  echo "Another instance ($oldpid) is running" >&2; exit 0
fi
trap 'rm -f -- "$pidfile"' EXIT
```

**Reality check**: PID files alone are not locks. They’re an *advisory* courtesy to operators/tools.

---

## Robust `trap` patterns

```bash
set -Eeuo pipefail
tmpd="$(mktemp -d)"

err() { printf 'ERR: line %s rc=%s\n' "$BASH_LINENO" "$?"; }
cleanup() { [[ -d $tmpd ]] && rm -rf -- "$tmpd"; }

trap err ERR
trap cleanup EXIT
trap 'printf "INT received\n" >&2; exit 130' INT
trap 'printf "TERM received\n" >&2; exit 143' TERM
```

**Gotchas**

* `trap` doesn’t fire inside subshells `(...)`.
* `set -e` is skipped in some compound commands; explicit checks beat superstition.

---

## Exclusive file writes with FDs

```bash
outfile="/var/log/myapp.log"
exec 3>>"$outfile"               # open once
printf '%s %s\n' "$(date +%FT%T)" "started" >&3
# ... later
printf '%s %s\n' "$(date +%FT%T)" "done" >&3
exec 3>&-                         # close
```

Opening once reduces contention; the kernel serializes writes at the FD level.

---

## Temporary work tree staging

```bash
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

# build artifacts to stage, then deploy atomically
rsync -a --delete build/ "$stage"/
# atomic publish (same filesystem)
mv -T "$stage" /srv/www.new
ln -sfn /srv/www.new /srv/www
```

**Why**: build and verify in isolation, then switch with a single, atomic rename.

---

## Pattern: “do work only if lock acquired”

```bash
with_lock() {
  local lock="$1"; shift
  exec 9>"$lock"
  flock -n 9 || return 0   # no-op if busy
  "$@"
}
with_lock "/var/lock/reindex.lock" reindex_search
```

---

```yaml
---
id: docs/bash/70-tempfiles-locks-flock.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2"
tags: [bash, mktemp, trap, flock, lockdir, pidfile, atomic, cleanup]
description: "Crash-resistant patterns: mktemp tempdirs, EXIT/ERR traps, single-instance locks via flock or lockdir, and atomic file replacement."
---
```
