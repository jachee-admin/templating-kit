###### Bash

# Security Hardening: Least Privilege, Safe Tempdirs, `--`, Sanitization, and Defense-in-Depth

A script that can destroy a system must first earn the right to exist. Harden everything: inputs, permissions, file ops, and environment.

## TL;DR

* Use `set -Eeuo pipefail` **and** `IFS=$'\n\t'`.
* Always terminate option parsing with `--`.
* Create tempdirs with `mktemp -d` and drop privileges early.
* Refuse to run as root unless required; otherwise use `sudo -u`.
* Sanitize env, path, and input before trusting anything.
* Log dangerous actions and include a dry-run mode.

---

## Baseline shell hygiene

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Restrict PATH to known safe binaries
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin"

# Ensure predictable locale
export LC_ALL=C
umask 027   # files: 640, dirs: 750 (deny world read)
```

---

## Root guard

```bash
require_root() {
  (( EUID == 0 )) || { echo "Must be run as root" >&2; exit 77; }
}
refuse_root() {
  (( EUID == 0 )) && { echo "Do not run as root" >&2; exit 77; }
}
```

---

## Safe temporary directories

```bash
TMPD="$(mktemp -d /tmp/myapp.XXXXXX)"
cleanup() { [[ -d $TMPD ]] && rm -rf -- "$TMPD"; }
trap cleanup EXIT

# File inside
OUT="$TMPD/output.txt"
```

Never use `/tmp/foo.$$`; PIDs are predictable. Always create a directory and work inside it.

---

## Defensive argument parsing

```bash
for f in "$@"; do
  [[ $f == -* ]] && { echo "Refusing suspicious arg: $f" >&2; exit 2; }
  [[ -e $f ]] || { echo "File not found: $f" >&2; exit 2; }
done
```

---

## The mighty `--`

```bash
rm -- "$file"
mv -- "$src" "$dst"
grep -- "$pattern" "$file"
```

Always use `--` before user-supplied filenames or patterns.

---

## Drop privileges

```bash
# If running as root, switch to service user for non-root actions
drop_privs() {
  local user="${1:-nobody}"
  [[ $EUID -eq 0 ]] || return 0
  exec sudo -u "$user" -E "$0" "$@"
}
```

---

## Immutable paths and symlink defense

```bash
safe_copy() {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || { echo "src missing" >&2; return 2; }
  real_dst="$(readlink -f -- "$dst" 2>/dev/null || echo "$dst")"
  case "$real_dst" in
    /etc/*|/var/*|/home/*) ;;
    *) echo "Refusing to write outside allowed roots: $real_dst" >&2; return 2 ;;
  esac
  cp -a -- "$src" "$real_dst"
}
```

---

## Validate user input

```bash
validate_name() {
  [[ $1 =~ ^[a-zA-Z0-9_-]{1,32}$ ]] || { echo "Invalid name: $1" >&2; return 2; }
}
```

---

## Dry-run mode

```bash
DRYRUN="${DRYRUN:-0}"
run() {
  echo "+ $*" >&2
  (( DRYRUN )) || "$@"
}
run rm -rf -- /some/dir
```

---

## Restrict eval and expansions

Avoid `eval`, indirect expansion (`${!var}`), or unquoted command substitution of user input.

If absolutely required, validate against a whitelist:

```bash
case "$action" in
  start|stop|restart) ;;
  *) echo "invalid action" >&2; exit 2 ;;
esac
```

---

## Secure sudo policies

* In `/etc/sudoers.d/myapp`:

  ```
  mysvc ALL=(root) NOPASSWD: /usr/local/bin/myapp --safe-subcommand *
  ```
* Never grant unrestricted shells or wildcards.
* Audit with `sudo -l`.

---

## Logging with integrity

```bash
log_event() {
  local level="$1"; shift
  printf '%s %-5s pid=%d %s\n' "$(date +%FT%T)" "$level" "$$" "$*" >>/var/log/myapp/audit.log
}
chmod 640 /var/log/myapp/audit.log
```

---

## Defensive environment startup

```bash
# Clear unsafe vars
unset -v BASH_ENV CDPATH ENV HISTFILE
```

---

## Check for required binaries early

```bash
for cmd in curl jq tar openssl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 3; }
done
```

---

## Restrict file descriptors & limits

```bash
ulimit -n 1024   # max open files
ulimit -c 0      # no core dumps
ulimit -f 1048576  # 1GB file size limit
```

---

## Example: secure wrapper

```bash
main() {
  refuse_root
  TMPD="$(mktemp -d)"
  trap 'rm -rf "$TMPD"' EXIT
  validate_name "$1"
  run cp -- "$1" "$TMPD/"
}
main "$@"
```

---

```yaml
---
id: templates/bash/190-security-hardening.sh.md
lang: bash
platform: posix
scope: security
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, sudo 1.9+"
tags: [bash, security, hardening, mktemp, umask, sudo, least-privilege, dry-run, validation]
description: "Security-hardening patterns for Bash: safe tempdirs, '--' hygiene, root guards, input validation, drop privileges, dry-run mode, and defensive environment setup."
---
```
