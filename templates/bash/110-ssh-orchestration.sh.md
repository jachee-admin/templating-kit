###### Bash

# SSH Orchestration: Multiplexing, ProxyJump, Remote Heredocs, Rolling Ops

SSH is your remote control. Make it fast (multiplex), predictable (config), and safe (strict host keys, bounded fan-out). This template covers daily-driver patterns for orchestrating fleets.

## TL;DR

* Put connection policy in `~/.ssh/config`; keep scripts thin.
* Use **ControlMaster** multiplexing for speed; pair with sane `ControlPersist`.
* Prefer **ProxyJump** over manual `ProxyCommand` tunnels.
* Use **remote heredocs** and `rsync -e ssh` for idempotent deploys.
* For many hosts: use **GNU parallel** with `ssh`, keep concurrency bounded and outputs ordered.

---

## SSH config (baseline)

```bash
# ~/.ssh/config
Host *
  ServerAliveInterval 30
  ServerAliveCountMax 4
  ForwardAgent no
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  ControlMaster auto
  ControlPersist 2m
  ControlPath ~/.ssh/cm-%r@%h:%p

Host edge
  HostName edge.example.net
  User ops
  IdentityFile ~/.ssh/ops_ed25519

Host *.corp
  User ops
  IdentityFile ~/.ssh/ops_ed25519
  ProxyJump edge
```

**Notes**

* `accept-new` is convenient; for high-security, pin keys out-of-band.
* `ControlPath` must be short (UNIX socket path length limits).

---

## One-off command

```bash
ssh app01.corp 'uptime && hostname'
```

## Remote heredoc (quoted to avoid local expansion)

```bash
ssh db01.corp 'bash -s' <<'REMOTE'
set -Eeuo pipefail
sudo install -m 0644 -D /dev/stdin /etc/myapp/app.ini <<'CFG'
[default]
mode=prod
CFG
sudo systemctl reload myapp
REMOTE
```

**Why**: quoted (`<<'REMOTE'`) prevents local variable/command expansion.

---

## Rsync over SSH (deploys)

```bash
build_dir="./release/"
dest="ops@app01.corp:/srv/myapp/"
rsync -az --delete --info=stats2,progress2 -e ssh "$build_dir" "$dest"
ssh app01.corp 'sudo systemctl try-reload-or-restart myapp'
```

---

## Multiplex warm-up (avoid handshake latency)

```bash
# Establish or reuse a master connection; subsequent ssh/scp/rsync will be instant
ssh -MNf app01.corp   # -M master, -N no command, -f background
# Later: close all masters
ssh -O exit app01.corp
```

---

## ProxyJump chain

```bash
# app01 requires jumping through edge (as set in ssh_config)
ssh app01.corp 'hostname'
# ad-hoc without config:
ssh -J ops@edge.example.net ops@app01.corp 'hostname'
```

---

## Sudo non-interactive commands

```bash
ssh app01.corp 'sudo -n systemctl status myapp || true'
# If password is required, pre-approve with a short-lived ticket instead of embedding passwords.
```

---

## Fan-out to many hosts (bounded & ordered)

```bash
hosts=(app01.corp app02.corp app03.corp)
N="${N:-3}"

# Example: rolling restart with health check, keeping output ordered (-k)
health() { ssh "$1" 'curl -fsS http://127.0.0.1:8080/health'; }
restart() { ssh "$1" 'sudo systemctl restart myapp'; sleep 2; health "$1"; }

export -f health restart
parallel -k -j "$N" restart ::: "${hosts[@]}"
```

---

## Rolling change with pause & abort on failure

```bash
rolling() {
  local hosts=("$@")
  for h in "${hosts[@]}"; do
    echo "==> $h"
    if ssh "$h" 'sudo systemctl restart myapp && sleep 3 && curl -fsS localhost:8080/health'; then
      echo "OK $h"
    else
      echo "FAIL $h" >&2
      return 1
    fi
  done
}
rolling "${hosts[@]}" || { echo "Aborting rollout"; exit 1; }
```

---

## Tar over SSH (quick, metadata-preserving copy)

```bash
# Pack on source, unpack on target (avoids temp files)
tar -C /srv/app -cpf - . | ssh app01.corp 'sudo tar -C /srv/app -xpf -'
```

---

## Batch SFTP (when rsync unavailable)

```bash
cat > /tmp/sftp.batch <<'EOF'
cd /srv/app
put ./release/app.tar.gz
bye
EOF
sftp -b /tmp/sftp.batch ops@app01.corp
```

---

## Agent forwarding warnings

* Avoid `ForwardAgent yes` unless absolutely necessary; it exposes your agent to the remote host.
* Prefer using per-host deploy keys and `IdentitiesOnly yes`.

---

## Known_hosts hygiene (CI/CD)

```bash
# Pin host key in CI step (example using ssh-keyscan)
ssh-keyscan -H app01.corp >> ~/.ssh/known_hosts
```

---

```yaml
---
id: docs/bash/110-ssh-orchestration.sh.md
lang: bash
platform: posix
scope: orchestration
since: "v0.4"
tested_on: "bash 5.2, OpenSSH_9.x, rsync 3.2+"
tags: [bash, ssh, ProxyJump, ControlMaster, heredoc, rsync, rolling-restart, parallel]
description: "Fast, safe SSH orchestration: config defaults, multiplexing, ProxyJump, remote heredocs, rsync deploys, and bounded/ordered fan-out."
---
```
