###### Bash

# Monitoring & Metrics: Health Checks, SLO Signals, Prometheus Textfile Exporter, and Alert Wiring

Observability isn’t just logs. You want crisp **signals** that can page humans or silence themselves. This template gives you reliable health checks, minimal SLO math, and Prometheus-friendly metrics emission.

## TL;DR

* Keep health checks **fast** and **side-effect free**.
* Emit Prometheus metrics via the **textfile collector** (node_exporter).
* Track **latency**, **error rate**, and **availability**; summarize into **SLIs** (Service Level Indicators).
* Use **exit codes** to integrate with `systemd` `Restart=` and simple on-host monitors.
* Prefer **thresholds** + **rate-of-change** to avoid alert flapping.

---

## Lightweight HTTP health check (internal)

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

URL="${URL:-http://127.0.0.1:8080/health}"
timeout_s="${TIMEOUT:-2}"

start_ns=$(date +%s%N)
body="$(curl -fsS --max-time "$timeout_s" "$URL" || true)"
rc=$?
dur_ms=$(( ( $(date +%s%N) - start_ns ) / 1000000 ))

# Accept health bodies like {"status":"ok"} or plain "ok"
if (( rc == 0 )) && [[ $body == *ok* ]]; then
  echo "OK ${dur_ms}ms"
  exit 0
else
  echo "FAIL rc=$rc ${dur_ms}ms body=${body:0:80}" >&2
  exit 1
fi
```

---

## Prometheus: textfile exporter (node_exporter)

Emit metrics into a file that node_exporter scrapes.

```bash
# Path configured via --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
OUT="${OUT:-/var/lib/node_exporter/textfile_collector/myapp.prom.$$}"

ts="$(date +%s)"
latency_ms="$dur_ms"; status=$(( rc == 0 ? 1 : 0 ))

{
  echo "# HELP myapp_health_success 1 if health ok"
  echo "# TYPE myapp_health_success gauge"
  echo "myapp_health_success $status $ts"
  echo "# HELP myapp_health_latency_ms Health check latency in ms"
  echo "# TYPE myapp_health_latency_ms gauge"
  echo "myapp_health_latency_ms $latency_ms $ts"
} > "$OUT"

# Atomic publish
mv -f -- "$OUT" "${OUT%.$$}"
```

**Tip:** One file per run; overwrite atomically. Use labels if you have multiple instances:

```
myapp_health_success{instance="app01",env="prod"} 1
```

---

## Error-rate SLIs (rolling window)

```bash
# Keep a sliding window counter file (append only; logrotate trims)
METRICS_DIR="/var/lib/myapp/metrics"; mkdir -p "$METRICS_DIR"
echo "$(date +%s) $rc" >> "$METRICS_DIR/health_rc.log"

# Summarize last 5 minutes into a success ratio
cutoff=$(( $(date +%s) - 300 ))
ok=0; total=0
while read -r t r; do
  (( t >= cutoff )) || continue
  (( total++ ))
  (( r == 0 )) && (( ok++ ))
done < "$METRICS_DIR/health_rc.log"

ratio=0
(( total > 0 )) && ratio=$(( 100 * ok / total ))

cat > "${OUT}.rc" <<EOF
# HELP myapp_health_success_ratio_5m Success ratio over last 5 minutes (percent)
# TYPE myapp_health_success_ratio_5m gauge
myapp_health_success_ratio_5m $ratio
EOF
mv -f -- "${OUT}.rc" "${OUT%.prom.$$}.rc.prom"
```

---

## Basic SLO math (99.9 availability envelope)

* For 30 days: 99.9% allows ~43 minutes of error budget.
* Track **burn rate**: how fast you’re consuming budget. Alert when burn rate > threshold over 1h and 6h.

PromQL sketch (for your Grafana/Prometheus side):

```
# Instant error rate (1m)
1 - (sum(rate(myapp_health_success[1m])) / sum(rate(myapp_health_success[1m]) + rate(myapp_health_fail[1m])))
```

(Or derive from `success_ratio_5m` if that’s all you have.)

---

## Systemd service + watchdog

```ini
# /etc/systemd/system/myapp-health.service
[Unit]
Description=MyApp health check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/myapp_health_check.sh
```

```ini
# Timer every 30s
# /etc/systemd/system/myapp-health.timer
[Unit]
Description=Run MyApp health checker

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
```

Enable:

```bash
systemctl enable --now myapp-health.timer
journalctl -u myapp-health.service -f
```

---

## Thresholds & alert strategy (practical)

* Page on **sustained** failures (e.g., success ratio < 95% for 10 minutes).
* Ticket (not page) for slow latency (p95 > 400ms for 30 minutes).
* Use **dead-man’s switch** (heartbeat metric) to detect broken monitoring.

---

## Disk, CPU, memory quick metrics (textfile)

```bash
# CPU load (1m)
load="$(cut -d' ' -f1 /proc/loadavg)"
echo "node_local_load1 $load" > /var/lib/node_exporter/textfile_collector/local.prom.$$
mv -f /var/lib/node_exporter/textfile_collector/local.prom.$$ /var/lib/node_exporter/textfile_collector/local.prom
```

---

## Canary checks (external dependency)

```bash
# Verify DB connectivity without mutating state
psql "postgres://user:pass@db:5432/app?sslmode=require" -c 'SELECT 1;' -tA >/dev/null \
  && echo "myapp_db_connect 1" \
  || echo "myapp_db_connect 0" \
  > /var/lib/node_exporter/textfile_collector/myapp_db.prom.$$
mv -f -- /var/lib/node_exporter/textfile_collector/myapp_db.prom.$$ /var/lib/node_exporter/textfile_collector/myapp_db.prom
```

---

```yaml
---
id: templates/bash/210-monitoring-metrics.sh.md
lang: bash
platform: posix
scope: monitoring
since: "v0.4"
tested_on: "bash 5.2, node_exporter 1.x, systemd 252+"
tags: [bash, monitoring, health, prometheus, textfile, slo, systemd-timer]
description: "Operational monitoring patterns: HTTP health checks, Prometheus textfile metrics, rolling success ratio SLIs, systemd timers, and practical alert thresholds."
---
```