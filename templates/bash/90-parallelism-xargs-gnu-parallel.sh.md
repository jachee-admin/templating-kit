###### Bash

# Parallelism with `xargs -P` & GNU `parallel`: Bounded Concurrency, Ordering, and Reliability

Concurrency without chaos. Use bounded workers, null-safe inputs, stable ordering when needed, and proper status aggregation.

## TL;DR

* Prefer `xargs -0 -n1 -P "$(nproc)"` for portable, lightweight parallelism.
* Use GNU `parallel` for richer features (ordering `-k`, job logs, retries, SSH fan-out).
* Keep **stdout as data**, **stderr for logs**; aggregate exit codes.
* Always use `find -print0 | xargs -0 …` for arbitrary filenames.

---

## xargs: bounded parallelism (portable, fast)

```bash
# Process each file with at most N concurrent workers
N="${N:-$(nproc || echo 4)}"
find /data -type f -name '*.json' -print0 \
  | xargs -0 -n1 -P "$N" -I{} bash -c '
      set -Eeuo pipefail
      f="$1"
      jq -c . "$f" >/dev/null
    ' _ {}
```

**Flags**

* `-0` null-delimited safety.
* `-n1` one arg per invocation.
* `-P N` run N jobs in parallel.
* `-I{}` template arg position.

### Collecting exit status across parallel jobs

```bash
# xargs exits with 0 only if all jobs succeed (GNU; BSD differs slightly).
if ! find . -name '*.csv' -print0 | xargs -0 -n1 -P "$N" ./validate_csv.sh; then
  echo "one or more tasks failed" >&2
  exit 1
fi
```

---

## Preserve input order vs maximize throughput

* **Throughput**: default `xargs -P` interleaves outputs.
* **Ordering**: GNU `parallel -k` preserves input order in output.

```bash
# Keep output aligned with input ordering
parallel -k -j "$N" do_work ::: "${items[@]}"
```

---

## Avoid stdout soup: prefix or separate streams

```bash
# Prefix each line with job id or filename
export LC_ALL=C
find logs -name '*.log' -print0 \
| xargs -0 -n1 -P "$N" -I{} bash -c '
  f="$1"
  while IFS= read -r line; do
    printf "%s | %s\n" "$f" "$line"
  done < <(grep -E "ERROR|FATAL" "$f")
' _ {}
```

---

## GNU parallel: the power toolbox

If available, it’s often simpler and clearer.

### Basic fan-out

```bash
# Run cmd on a list; ::: introduces arguments
parallel -j "$N" gzip -9 ::: *.ndjson
```

### Preserve order, capture exit codes & stop on first failure

```bash
# --halt now,fail=1: abort when any job fails (propagate non-zero exit)
parallel -k -j "$N" --halt now,fail=1 process_one ::: "${files[@]}"
```

### Structured input (CSV/TSV) to named parameters

```bash
# CSV → variables {1} {2} ...
parallel -j "$N" --colsep ',' 'backup_user {1} {2}' :::: users.csv
```

### Retries with exponential backoff

```bash
# --retries 3 with delay growth (1s,2s,4s)
parallel -j "$N" --retries 3 --delay 1 --joblog joblog.tsv do_api_call ::: "${ids[@]}"
```

### Export environment & functions

```bash
myfn() { curl -fsS "https://api/x?id=$1" | jq -r .name; }
export -f myfn
parallel -j "$N" myfn ::: "${ids[@]}"
```

### SSH fan-out

```bash
# Distribute jobs across hosts (SSH config must be set)
parallel -S server1,server2,server3 -j 0 'uptime && hostname'
```

`-j 0` = one job per CPU per server.

---

## Chunking inputs to amortize startup cost

```bash
# Send 50 items per invocation to reduce process spawn overhead
printf '%s\n' "${urls[@]}" \
  | xargs -n50 -P "$N" bash -c '
      set -Eeuo pipefail
      for u in "$@"; do curl -fsS "$u" -o /dev/null; done
    ' _
```

---

## Ordered artifacts: one file per job

```bash
# Dedicate output files; combine later
export OUTDIR="/tmp/out"; mkdir -p "$OUTDIR"
parallel -j "$N" 'jq -c . "{1}" > "$OUTDIR"/"{#}".json' ::: "${files[@]}"

# Combine deterministically
for i in $(seq 1 $(ls "$OUTDIR" | wc -l)); do cat "$OUTDIR/$i.json"; done > all.json
```

`{#}` is the job slot index; `{1}` is the first argument.

---

## Safety knobs

* Limit descriptors: `ulimit -n 1024` if tools leak FDs.
* Avoid fork bombs: keep `N` ≤ 2× cores for network-bound; ≤ cores for CPU-bound.
* Rate limits: insert sleeps or use `--delay` in `parallel`.

---

```yaml
---
id: templates/bash/90-parallelism-xargs-gnu-parallel.sh.md
lang: bash
platform: posix
scope: scripting
since: "v0.4"
tested_on: "bash 5.2, GNU parallel 2024.x"
tags: [bash, xargs, parallel, concurrency, ordering, retries, ssh]
description: "Bounded concurrency with xargs and GNU parallel: null-safe fan-out, ordered output, retries, job logs, SSH distribution, and reliable status handling."
---
```

