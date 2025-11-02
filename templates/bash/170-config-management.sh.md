###### Bash

# Config Management: Defaults → File → ENV → CLI, Secrets Patterns, and Templating

Configuration should be boring, explicit, and layerable. This template implements a predictable precedence model, safe INI parsing, secret handling, and templating strategies that won’t leak credentials.

## TL;DR

* Precedence: **defaults < config file < environment < CLI** (document it).
* Keep **secrets in files** or a secret store; pass values via `FOO_FILE` or file descriptors.
* Mask secrets in logs; never echo raw secrets.
* Use `envsubst` or `jq -n` for templating, not fragile `sed` hacks.
* Consider `.env` (dotenv) for dev, and **sops**/**age** or a vault in prod.

---

## Canonical layering scaffold

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Defaults
CFG_FILE="${CFG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/myapp/config.ini}"
HOST="localhost"
PORT="8080"
MODE="dev"

# 1) Load file (INI key=value; no sections, no quotes)
declare -A CFG=()
if [[ -r "$CFG_FILE" ]]; then
  while IFS='=' read -r k v; do
    [[ -z $k || $k =~ ^\s*# ]] && continue
    k="${k//[[:space:]]/}"
    v="${v##[[:space:]]}"
    CFG["$k"]="$v"
  done < "$CFG_FILE"
fi

# 2) Merge file values
HOST="${CFG[host]:-$HOST}"
PORT="${CFG[port]:-$PORT}"
MODE="${CFG[mode]:-$MODE}"

# 3) Merge environment overrides (MYAPP_* prefix)
HOST="${MYAPP_HOST:-$HOST}"
PORT="${MYAPP_PORT:-$PORT}"
MODE="${MYAPP_MODE:-$MODE}"

# 4) CLI flags override (handled elsewhere; see 140-cli-ux-patterns)
```

**Rule of thumb:** pick an ENV prefix (`MYAPP_…`) and stick to it.

---

## Secrets: pass **by file** or FD, not inline

```bash
# Convention: if FOO not set but FOO_FILE is, read from file (first line, no trim)
read_secret() {
  local name="$1" filevar="${1}_FILE" val
  val="${!name:-}"
  if [[ -n $val ]]; then printf '%s\n' "$val"; return 0; fi
  if [[ -n ${!filevar:-} && -r ${!filevar} ]]; then
    IFS= read -r val < "${!filevar}" && printf '%s\n' "$val"; return 0
  fi
  return 1
}

# Usage
API_TOKEN="$(read_secret API_TOKEN || true)"
```

### Mask secrets in logs

```bash
mask() { local s="$1"; [[ ${#s} -le 8 ]] && printf '****' || printf '%s…' "${s:0:4}"; }

info() { printf '%s %s\n' "$(date +%FT%T)" "$*" >&2; }
info "Using MODE=$MODE, HOST=$HOST, TOKEN=$(mask "${API_TOKEN:-}")"
```

---

## .env support (dev only)

```bash
# Load .env if present; ignore comments and empty lines
dotenv() {
  local f="${1:-.env}"; [[ -r $f ]] || return 0
  while IFS= read -r line; do
    [[ -z $line || $line =~ ^\s*# ]] && continue
    export "$line"
  done < "$f"
}
dotenv
```

**Note:** `.env` is not a secret manager—commit policy and OS permissions still matter.

---

## Sops/age (encrypted config)

* Encrypt secrets with **sops** (`.sops.yaml` policy) using **age** or GPG keys.
* Decrypt at runtime into a **tmpfs** or pipe directly:

```bash
cfg_json="$(sops -d config.enc.json)"
HOST="$(jq -r '.host' <<<"$cfg_json")"
API_TOKEN="$(jq -r '.api_token' <<<"$cfg_json")"
unset cfg_json
```

---

## Templating configs safely

```bash
# envsubst (POSIX vars only) — safe for simple templates
render_envsubst() {
  local tmpl="$1" out="$2"
  envsubst < "$tmpl" > "$out"
}

# jq-driven templating (structural)
render_json() {
  local out="$1"
  jq -n --arg host "$HOST" --arg port "$PORT" --arg mode "$MODE" \
     '{server:{host:$host,port:($port|tonumber)}, mode:$mode}' > "$out"
}
```

---

## Multiple environment files (override stack)

```bash
# Apply in order (later wins)
for f in /etc/myapp/config.ini "$HOME/.config/myapp/config.ini" "./config.local.ini"; do
  [[ -r $f ]] || continue
  while IFS='=' read -r k v; do
    [[ -z $k || $k =~ ^\s*# ]] && continue
    CFG["${k//[[:space:]]/}"]="${v##[[:space:]]}"
  done < "$f"
done
```

---

## Config validation (fail early)

```bash
require_nonempty() { [[ -n ${!1:-} ]] || { echo "Missing required: $1" >&2; return 2; }; }

require_nonempty HOST
require_nonempty PORT
[[ $PORT =~ ^[0-9]+$ ]] || { echo "PORT must be integer" >&2; exit 2; }
```

---

## Runtime config dump (redacted)

```bash
dump_cfg() {
  jq -n \
    --arg host "$HOST" \
    --arg port "$PORT" \
    --arg mode "$MODE" \
    --arg token "$(mask "${API_TOKEN:-}")" \
    '{host:$host, port:($port|tonumber), mode:$mode, api_token:$token}'
}
dump_cfg >&2
```

---

## Per-environment directories

```
config/
  default.ini
  dev.ini
  test.ini
  prod.ini
```

Pick one with `MYAPP_ENV=prod` and merge `default.ini` first, then the selected environment file.

---

## Passing secrets via FD (no temp files)

```bash
# Caller: exec 9< <(sops -d secret.txt)
read -r API_TOKEN <&9
exec 9<&-  # close
```

---

```yaml
---
id: templates/bash/170-config-management.sh.md
lang: bash
platform: posix
scope: config
since: "v0.4"
tested_on: "bash 5.2, gettext envsubst, jq 1.7, sops 3.x"
tags: [bash, config, dotenv, sops, age, secrets, templating, precedence]
description: "Predictable config layering with safe INI parsing, dotenv for dev, secrets via *_FILE or FDs, masking, sops/age decryption, and robust templating."
---
```
