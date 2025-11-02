###### Bash

# SSH Bastion Artifact Ferry: Push/Pull with Integrity, Compression, and Resume

Move artifacts across locked-down networks via a bastion (jump host) with **checksums, compression, resumable transfers**, and **atomic publish** on the target.

## TL;DR

* Prefer `ProxyJump` in `~/.ssh/config` over ad-hoc tunnels.
* Generate and verify **SHA-256 manifests** before/after transfer.
* Use `rsync -az --partial --checksum` (with `-e "ssh -J bastion"`).
* Publish atomically on the target (`mv -T` or symlink swap).
* Log a receipt (sizes, checksums, host, user, timestamp).

---

## SSH config (bastion)

```bash
# ~/.ssh/config
Host bastion
  HostName bastion.example.net
  User ops
  IdentityFile ~/.ssh/ops_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  ControlMaster auto
  ControlPersist 2m
  ControlPath ~/.ssh/cm-%r@%h:%p

Host app-*.prod
  User deploy
  ProxyJump bastion
  IdentityFile ~/.ssh/deploy_ed25519
  IdentitiesOnly yes
```

---

## Create artifact + manifest

```bash
set -Eeuo pipefail

build_dir="./build"
release="myapp-$(date +%Y%m%d-%H%M%S)"
pkg="$release.tar.zst"

# Pack deterministically
tar --numeric-owner --sort=name -cpf - -C "$build_dir" . \
  | zstd -19 -T0 -o "$pkg"

sha256sum "$pkg" > "$pkg.sha256"
```

---

## Push via rsync over ProxyJump (resume-friendly)

```bash
target="app-01.prod:/srv/releases"
rsync -az --partial --info=stats2,progress2 \
  -e 'ssh -J bastion' \
  "$pkg" "$pkg.sha256" "$target/"
```

---

## Verify on target & atomic publish

```bash
ssh app-01.prod <<'REMOTE'
set -Eeuo pipefail
cd /srv/releases

pkg="$(ls -1t myapp-*.tar.zst | head -1)"
sha="$(ls -1t myapp-*.tar.zst.sha256 | head -1)"

sha256sum -c "$sha"

# Stage, then atomic publish
stage="/srv/app.stage.$$"
dest="/srv/app"

mkdir -p "$stage"
tar -I zstd -xpf "$pkg" -C "$stage"
# optional: run migrations/tests here

ln -sfn "$stage" "$dest.new"
mv -T "$dest.new" "$dest"
# keep a pointer to current for hygiene
ln -sfn "$stage" /srv/app.current
REMOTE
```

---

## Pull artifacts back (logs, evidence)

```bash
# Pull compressed logs without re-compressing on source
ssh -J bastion app-01.prod 'tar -C /var/log/myapp -cpf - . | zstd -19 -T0' \
  > "logs-app01-$(date +%Y%m%d).tar.zst"

sha256sum "logs-app01-$(date +%Y%m%d).tar.zst" > "logs.sha256"
```

---

## Multi-host fan-out (bounded, ordered)

```bash
hosts=(app-01.prod app-02.prod app-03.prod)
export pkg pkg_sha="$pkg.sha256"
deploy_one() {
  h="$1"
  rsync -az --partial -e 'ssh -J bastion' "$pkg" "$pkg_sha" "$h:/srv/releases/"
  ssh -J bastion "$h" 'bash -s' <<'R'
set -Eeuo pipefail
cd /srv/releases
pkg="$(ls -1t myapp-*.tar.zst | head -1)"
sha="${pkg}.sha256"
sha256sum -c "$sha"
stage="/srv/app.stage.$$"; mkdir -p "$stage"
tar -I zstd -xpf "$pkg" -C "$stage"
ln -sfn "$stage" /srv/app.new && mv -T /srv/app.new /srv/app
R
}
export -f deploy_one
parallel -k -j 2 deploy_one ::: "${hosts[@]}"
```

---

## Receipt (prove what moved, where, when)

```bash
receipt="receipt-$(date -u +%FT%TZ).json"
jq -n \
  --arg host "$(hostname)" \
  --arg user "$USER" \
  --arg pkg "$pkg" \
  --arg sum "$(cut -d' ' -f1 "$pkg.sha256")" \
  --arg ts "$(date -u +%FT%TZ)" \
  '{host:$host,user:$user,pkg:$pkg,sha256:$sum,ts:$ts}' > "$receipt"
```

---

## Troubleshooting notes

* If sockets exceed path length, shorten `ControlPath`.
* Use `-S none` with GNU `parallel` if SSH multiplexing misbehaves.
* For air-gapped hops, pre-stage to bastion disk, then inner hop; keep manifests consistent.

---

```yaml
---
id: templates/bash/230-ssh-bastion-artifacts.sh.md
lang: bash
platform: posix
scope: orchestration
since: "v0.4"
tested_on: "bash 5.2, OpenSSH_9.x, rsync 3.2+, zstd 1.5+"
tags: [bash, ssh, bastion, ProxyJump, rsync, checksum, atomic, artifact]
description: "Bastion-friendly artifact transfers: ProxyJump, resumable rsync, SHA-256 manifests, and atomic publish with receipts."
---
```
