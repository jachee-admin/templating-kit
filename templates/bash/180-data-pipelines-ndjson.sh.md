###### Bash

# Data Pipelines with NDJSON: Streaming, Chunking, Backpressure, and Parallel Stages

NDJSON (newline-delimited JSON) is perfect for shell pipelines: one JSON per line, streamable, grep-able, jq-friendly. This template shows how to validate, transform, chunk, and fan-out without melting RAM.

## TL;DR

* Keep records as **one JSON object per line**.
* Validate with `jq -e` early; fail fast.
* Control memory with streaming tools: `jq -c`, `split`, `parallel --pipe`, `xargs -n`.
* Preserve **order** only when you truly need it (`parallel -k`).
* For APIs, batch with backoff and idempotency keys.

---

## Validate + normalize input

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# Ensure every line is a valid JSON object and normalize field order
jq -c -e 'objects' < input.ndjson > normalized.ndjson
# -e: exit non-zero on error
# -c: compact (one line per object)
```

### Schema check (lightweight)

```bash
# Required keys: id (string), status (string), ts (number)
jq -c -e 'select(has("id") and has("status") and has("ts") and (.id|type=="string") and (.ts|type=="number"))' \
  < normalized.ndjson > valid.ndjson
```

---

## Transform fields in stream

```bash
# Add day bucket and map statuses
jq -c '
  .day = ( .ts | todateiso8601[0:10] )
  | .status = ( {ok:"OK", fail:"ERROR"}[.status] // .status )
' < valid.ndjson > transformed.ndjson
```

---

## Backpressure & buffering realities

* Pipes have limited buffers (~64KiB typical). If a consumer is slow, the producer will block—**that’s good**.
* Avoid accidental full-file reads: use streaming commands (`jq` with `-c`, no `map(...)` over the whole file).
* Insert `stdbuf -oL` or `--line-buffered` where tools default to block buffering on pipes.

```bash
# Example: force line-buffered grep
stdbuf -oL grep -n 'ERROR' < transformed.ndjson > errors.ndjson
```

---

## Chunking for parallelism

### Fixed-size batches (by lines)

```bash
# 10k records per chunk; names xaa, xab, ...
split -l 10000 -d --additional-suffix=.ndjson transformed.ndjson chunk_
```

### Size-based chunking (approx bytes)

```bash
split -C 50m -d --additional-suffix=.ndjson transformed.ndjson chunk_
```

### Streamed chunking directly to workers (no temp files)

```bash
# parallel --pipe reads blocks from stdin and runs jobs on them
# -N lines per job OR --block size per job; -k to keep order
cat transformed.ndjson \
  | parallel --pipe -k -j "$(nproc)" -N 5000 'jq -c ". | {id,day}" | gzip -c > out.{#}.ndjson.gz'
```

---

## Fan-out processing

```bash
# One file → multiple derived streams using process substitution
jq -c '. as $o | $o | select(.status=="ERROR")' transformed.ndjson \
  > errors.ndjson &
jq -c '. as $o | $o | select(.status=="OK")' transformed.ndjson \
  > ok.ndjson &
wait
```

**Note:** Two passes over input; for single pass with tee:

```bash
tee >(jq -c 'select(.status=="ERROR")' > errors.ndjson) \
    >(jq -c 'select(.status=="OK")' > ok.ndjson) \
    >/dev/null < transformed.ndjson
```

---

## Aggregations without loading everything

```bash
# Count per day
jq -r '.day' < transformed.ndjson | sort | uniq -c | awk '{printf "%s %d\n",$2,$1}' > counts_by_day.txt
```

---

## Batched API writes with retry/backoff

```bash
# Prepare batches of 100 NDJSON lines and POST to an endpoint
post_batch() {
  local url="$1"
  curl -fsS -H 'Content-Type: application/x-ndjson' --data-binary @- "$url"
}

# Retry wrapper (see 130 & 80)
send_with_retry() {
  local url="$1" attempt=1 max=6
  while :; do
    if post_batch "$url"; then return 0; fi
    rc=$?
    sleep "$(awk -v m=$((2**attempt)) 'BEGIN{srand(); print rand()*m<30?rand()*m:30}')"
    (( attempt++ <= max )) || return "$rc"
  done
}

# Chunk and send
parallel --pipe -N 100 -j 4 'send_with_retry https://api.example/bulk' < transformed.ndjson
```

---

## Deduplication by key (streaming)

```bash
# Keep first event per id (requires sorted input by id to be strict streaming)
jq -c '.id as $k | {k:$k, v:.}' transformed.ndjson \
| sort -t: -k1,1 -u \
| cut -d: -f2- > deduped.ndjson
```

For very large streams and true streaming, maintain a **Bloom filter** in an external tool; bash-only dedupe requires disk or limited memory.

---

## Joining reference data

```bash
# Join NDJSON stream with small lookup (id -> name) loaded into jq
lookup_json='{"u1":"Alice","u2":"Bob"}'
jq -c --argjson L "$lookup_json" '.name = ($L[.id] // "Unknown")' < transformed.ndjson > enriched.ndjson
```

---

## Repartition to per-day files (deterministic)

```bash
mkdir -p day/
jq -r '.day + "\t" + (.|tojson)' < transformed.ndjson \
| while IFS=$'\t' read -r day obj; do
    printf '%s\n' "$obj" >> "day/$day.ndjson"
  done
```

---

## End-to-end skeleton

```bash
main() {
  local in="${1:-input.ndjson}" outdir="${2:-out}"
  mkdir -p "$outdir"
  jq -c -e 'objects | select(has("id") and has("ts"))' < "$in" \
  | jq -c '.day = ( .ts | todateiso8601[0:10] )' \
  | tee "$outdir/all.ndjson" \
  | parallel --pipe -N 5000 -j "$(nproc)" 'jq -c "select(.status==\"ERROR\")"' \
  > "$outdir/errors.ndjson"
}
main "$@"
```

---

## Performance knobs

* Use `LC_ALL=C` for pure ASCII sorts and uniq.
* Prefer `parallel --pipe` over manual `split`+`xargs` when IO-bound.
* Avoid `jq` filters that materialize arrays of the whole file (`[...]`). Stick to streaming (`-c` + per-record transforms).
* Gzip streams inline: `… | gzip -c > file.gz` or `parallel --pipe 'gzip -c > out.{#}.gz'`.

---

```yaml
---
id: docs/bash/180-data-pipelines-ndjson.sh.md
lang: bash
platform: posix
scope: data
since: "v0.4"
tested_on: "bash 5.2, jq 1.7, GNU parallel 2024.x, coreutils 9.x"
tags: [bash, ndjson, jq, streaming, chunking, parallel, backpressure, batching]
description: "Streaming NDJSON pipelines: validation, schema checks, transformations, chunking with parallel --pipe, batching to APIs with retries, and deterministic repartitioning."
---
```

