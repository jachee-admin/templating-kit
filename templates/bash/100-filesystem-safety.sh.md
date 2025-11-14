###### Bash

# Filesystem Safety: `--`, `-print0/-0`, Checksums, Atomic Moves, and `rsync` Patterns

Filesystems are a haunted house of spaces, newlines, symlinks, and partial writes. These patterns keep your data intact.

## TL;DR

* Always pass `--` before paths to stop option parsing surprises.
* Use `find -print0 | xargs -0` for arbitrary filenames.
* Replace in place via **temp + mv** (atomic on same filesystem).
* For directory syncs, prefer `rsync -a --delete --partial --checksum` with explicit includes.
* Verify with checksums; don’t trust sizes or timestamps.

---

## Null-safety & option terminator

```bash
# Delete specific files from a list safely
while IFS= read -r -d '' f; do
  rm -- "$f"   # -- terminates options even if $f begins with -
done < <(find . -type f -name '*.tmp' -print0)
```

---

## Atomic replace (same filesystem)

```bash
safe_write() {
  local dst="$1"; shift
  local tmp; tmp="$(mktemp "${dst##*/}.XXXX")" || return 1
  cat >"$tmp"
  # preserve mode/owner if file exists
  [[ -e "$dst" ]] && cp --attributes-only --preserve=mode,ownership,timestamps "$dst" "$tmp" 2>/dev/null || true
  mv -f -- "$tmp" "$dst"   # atomic rename within same FS
}

render_config | safe_write "/etc/myapp/config.ini"
```

**Note**: Cross-filesystem `mv` degrades to copy+delete (not atomic). Place temp next to destination if you must guarantee atomicity.

---

## Quarantine instead of delete

```bash
quarantine="/var/quarantine/$(date +%Y%m%d)"
mkdir -p "$quarantine"
find /data -type f -name '*.bad' -print0 \
  | xargs -0 -I{} mv -- "{}" "$quarantine"/
```

Safer than `rm -rf` during incident triage.

---

## Rsync: safe mirroring and deploys

```bash
# One-way mirror with deletes and retries
rsync -a --delete --partial --info=stats1,progress2 \
  --exclude '.git/' \
  /src/dir/ /dst/dir/

# Content validation over mtime/size
rsync -a --checksum /src/ /dst/
```

### Atomic directory publish

```bash
build="/srv/app.build.$$"
dest="/srv/app"

rsync -a --delete ./release/ "$build"/
ln -sfn "$build" "$dest.new"
mv -T "$dest.new" "$dest"    # switch symlink atomically
```

---

## Checksums for integrity

```bash
# Create manifest
find ./payload -type f -print0 | sort -z \
  | xargs -0 sha256sum > manifest.sha256

# Verify later (exit non-zero on mismatch)
sha256sum -c manifest.sha256
```

---

## Symlink pitfalls & defenses

```bash
# Refuse to follow symlinks when walking
find /backups -type f -not -xtype l -print0

# Disarm symlinks by resolving and verifying within allowed root
real="$(readlink -f -- "$candidate")"
case "$real" in
  /safe/root/*)  ;;  # ok
  *) echo "Refusing to touch $candidate (outside root)"; exit 1 ;;
esac
```

---

## Safe recursive delete (guard rails)

```bash
safe_rm_tree() {
  local root="$1"
  [[ -n $root && -d $root && $root != "/" ]] || { echo "Refusing"; return 2; }
  find "$root" -mindepth 1 -maxdepth 1 -print0 \
    | xargs -0 rm -rf --
}
```

---

## Sparse files, permissions, and umask

```bash
# Preserve sparseness when copying big VM images
cp --sparse=always source.img dest.img

# Predictable perms
umask 022
install -m 0644 -D "./conf/app.ini" "/etc/myapp/app.ini"
install -m 0755 -D "./bin/myapp" "/usr/local/bin/myapp"
```

---

## Tar safely (for backups & restores)

```bash
# Create archive with numeric owners (safer cross-host)
tar --numeric-owner -cpzf backup.tar.gz --exclude='./tmp' .

# Restore into empty dir, refusing to overwrite absolute paths
mkdir /restore && cd /restore
tar --warning=no-unknown-keyword --anchored -xpzf /backups/backup.tar.gz
```

---

## Detect partial or failed writes

```bash
# Write to temp, fsync via dd, then move
tmp="$(mktemp)"
dd if=/dev/null of="$tmp" conv=fsync 2>/dev/null || true
generate_data > "$tmp"
mv -f -- "$tmp" "final.dat"
```

---

## Find/grep pipeline: robust pattern

```bash
find /etc -type f -name '*.conf' -print0 \
  | xargs -0 grep -nH -- 'PermitRootLogin'
```

---

```yaml
---
id: docs/bash/100-filesystem-safety.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2, coreutils 9.x, rsync 3.2+"
tags: [bash, filesystem, atomic, rsync, checksums, print0, safety]
description: "Filesystem safety patterns: option terminators, null-safe traversal, atomic writes, rsync mirroring, checksums, quarantine deletes, symlink defenses, and guarded rm."
---
```

