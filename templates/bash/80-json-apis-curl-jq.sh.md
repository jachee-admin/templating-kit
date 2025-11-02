###### Bash

# JSON APIs with `curl` + `jq`: Auth, Retries, Backoff, Pagination

Battle-tested patterns for talking to HTTP APIs **reliably**. Handle auth, timeouts, transient errors, rate limits, and pagination without turning your script into spaghetti.

## TL;DR

* Keep stdout as **data**; send progress/errors to stderr.
* Use timeouts (`--connect-timeout`, `--max-time`), fail flags (`-fS`), and structured status capture.
* Implement exponential backoff with jitter for `429/5xx`. Respect `Retry-After` when present.
* Build JSON with `jq -n` to avoid quoting bugs.
* Treat pagination as a loop with a clear **cursor** or **next link** contract.

---

## Minimal HTTP helper (status + body + headers)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE="${API_BASE:-https://api.example.com}"
AUTH_TOKEN="${AUTH_TOKEN:-}"    # export in env

http_json() {
  local method="$1" url="$2"; shift 2
  local tmpd hdr body status
  tmpd="$(mktemp -d)"; hdr="$tmpd/h"; body="$tmpd/b"
  trap 'rm -rf -- "$tmpd"' RETURN  # auto-clean when function returns

  # shellcheck disable=SC2086
  curl -sS -X "$method" \
       -H 'Accept: application/json' \
       ${AUTH_TOKEN:+-H "Authorization: Bearer $AUTH_TOKEN"} \
       "$@" \
       -D "$hdr" \
       --connect-timeout 5 --max-time 30 \
       -o "$body" \
       -w '%{http_code}' "$url" >"$tmpd/status"

  status="$(cat "$tmpd/status")"

  # Export-like outputs via global vars (documented contract)
  HTTP_STATUS="$status"
  HTTP_HEADERS_FILE="$hdr"
  HTTP_BODY_FILE="$body"
}

# Usage:
# http_json GET "$API_BASE/items?limit=10"
# echo "status=$HTTP_STATUS" >&2
# jq . < "$HTTP_BODY_FILE"
```

**Notes**

* `-sS` is silent but still shows errors.
* `-w '%{http_code}'` prints status without contaminating body.

---

## Exponential backoff with jitter + `Retry-After`

```bash
backoff() {
  local attempt="$1" base=1 cap=30
  # Full jitter: random in [0, min(cap, base*2^(n-1))]
  local max; max=$(( base << (attempt-1) )); (( max > cap )) && max=$cap
  awk -v m="$max" 'BEGIN{srand(); printf "%.3f\n", (rand()*m)}'
}

api_call() {
  local method="$1" url="$2"; shift 2
  local max_attempts=6 attempt=1

  while :; do
    http_json "$method" "$url" "$@"
    case "$HTTP_STATUS" in
      200|201|204) return 0 ;;
      429|502|503|504)
        # Look for Retry-After header (seconds)
        retry_after="$(awk 'BEGIN{IGNORECASE=1}
          /^Retry-After:/{gsub("\r",""); print $2}' "$HTTP_HEADERS_FILE" | tail -1)"
        if [[ -n ${retry_after:-} ]]; then
          sleep "$retry_after"
        else
          sleep "$(backoff "$attempt")"
        fi
        (( attempt++ ))
        (( attempt <= max_attempts )) || return 1
        ;;
      *) return 1 ;;
    esac
  done
}
```

**Why**: Rate limits and flaky networks are normal. Backoff keeps you polite and resilient.

---

## Building JSON payloads safely

```bash
# Use jq -n to construct JSON (no quoting hell)
new_user_json() {
  local name="$1" email="$2"
  jq -n --arg name "$name" --arg email "$email" \
     '{name: $name, email: $email, role: "reader"}'
}

payload="$(new_user_json "Ada Lovelace" "ada@example.test")"
api_call POST "$API_BASE/users" \
  -H 'Content-Type: application/json' \
  --data-binary @"$HTTP_BODY_FILE" <<<"$payload"   # feed via stdin? see below
```

**Tip**: `--data-binary @-` reads from stdin. If you already have a file, pass `@"file.json"` directly. To combine with our helper, write payload to a temp and pass its path.

---

## Pattern: POST with payload + robust status check

```bash
create_user() {
  local name="$1" email="$2"
  local tmp; tmp="$(mktemp)"
  new_user_json "$name" "$email" >"$tmp"

  api_call POST "$API_BASE/users" \
    -H 'Content-Type: application/json' \
    --data-binary @"$tmp"

  if [[ $HTTP_STATUS == 201 ]]; then
    jq -r '.id' < "$HTTP_BODY_FILE"
  else
    printf 'Create failed (status=%s)\n' "$HTTP_STATUS" >&2
    jq -r '.error // .message // empty' < "$HTTP_BODY_FILE" >&2 || true
    return 1
  fi
}
```

---

## Pagination patterns

### 1) **Link header** (`rel="next"`)

```bash
next_link() {
  awk -F'[<>;, ]+' '
    BEGIN{IGNORECASE=1}
    /^Link:/ {
      for(i=1;i<=NF;i++){
        if($i ~ /^<http/){url=$i}
        if(tolower($i)=="rel=\"next\""){print url}
      }
    }' "$1" | tail -1
}

list_all_pages() {
  local url="$1"
  while :; do
    api_call GET "$url"
    jq -c '.items[]' < "$HTTP_BODY_FILE"
    url="$(next_link "$HTTP_HEADERS_FILE")"
    [[ -n $url ]] || break
  done
}
```

### 2) **Cursor token** in body

```bash
list_all_cursor() {
  local url="$1" cursor=""
  while :; do
    local query="$url"
    [[ -n $cursor ]] && query="$url&cursor=$cursor"
    api_call GET "$query"
    jq -c '.items[]' < "$HTTP_BODY_FILE"
    cursor="$(jq -r '.next_cursor // empty' < "$HTTP_BODY_FILE")"
    [[ -n $cursor ]] || break
  done
}
```

---

## Auth variants

### Bearer token (recommended)

```bash
export AUTH_TOKEN="...redacted..."
api_call GET "$API_BASE/me"
jq . < "$HTTP_BODY_FILE"
```

### Basic (for trusted, internal services only)

```bash
api_call GET "$API_BASE/status" -u "user:pass"
```

### HMAC (sketch)

```bash
hmac_auth() {
  local key="$1" secret="$2" msg="$3"
  printf '%s' "$msg" | openssl dgst -sha256 -hmac "$secret" -binary | base64
}
sig="$(hmac_auth "$API_KEY" "$API_SECRET" "$(date -u +%FT%TZ)$METHOD$PATH")"
curl -H "X-Api-Key: $API_KEY" -H "X-Signature: $sig" ...
```

---

## Idempotency keys for POST/PUT

```bash
idempotency_key() { uuidgen || cat /proc/sys/kernel/random/uuid; }
key="$(idempotency_key)"

api_call POST "$API_BASE/jobs" \
  -H "Idempotency-Key: $key" \
  -H 'Content-Type: application/json' \
  --data-binary @job.json
```

If the network drops, retry with the **same** key to avoid dupes.

---

## Streaming large responses

```bash
# Stream to file while still checking status
dl="$(mktemp)"
http_json GET "$API_BASE/big-export" --output "$dl"
if [[ $HTTP_STATUS == 200 ]]; then
  mv -- "$dl" ./export.ndjson
else
  rm -f -- "$dl"
  jq -r '.error // .message // empty' < "$HTTP_BODY_FILE" >&2 || true
  exit 1
fi
```

---

## Safety & performance notes

* `-fS` (or `--fail-with-body`) makes curl fail non-2xx and still give you the body (version-dependent). Our helper already captures status/body separately.
* Always set timeouts; never let jobs hang forever.
* Prefer `--data-binary` for exact bytes; regular `-d` applies `application/x-www-form-urlencoded`.
* For JSON Lines, process incrementally: `jq -c . | while read -r line; do ...; done`.

---

```yaml
---
id: templates/bash/80-json-apis-curl-jq.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2, curl 8.x, jq 1.7"
tags: [bash, curl, jq, http, retries, backoff, pagination, auth, idempotency]
description: "Reliable HTTP JSON patterns: curl+jq helpers, timeouts, exponential backoff with jitter, Retry-After handling, auth headers, and pagination (Link and cursor)."
---
```

