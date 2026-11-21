#!/bin/bash
# Samples Argus CPU and RSS while the owner manually adds three targets.
# Usage: scripts/soak.sh [minutes=30] [interval_seconds=30]
# The app must already be running (open build/Argus.app).
set -euo pipefail
minutes="${1:-30}"
interval="${2:-30}"
case "$minutes" in ''|*[!0-9]*) echo "usage: scripts/soak.sh [minutes] [interval_seconds]" >&2; exit 2;; esac
case "$interval" in ''|*[!0-9]*) echo "usage: scripts/soak.sh [minutes] [interval_seconds]" >&2; exit 2;; esac
out="build/soak-$(date +%Y%m%d-%H%M%S).log"
mkdir -p build
echo "time,elapsed_min,pid,cpu_percent,rss_kb" > "$out"
start=$(date +%s)
echo "[soak] logging to $out (${minutes}m, every ${interval}s)"

while :; do
  pid="$(pgrep -x Argus || true)"
  now=$(date +%s)
  elapsed=$(( (now - start) / 60 ))
  if [ -n "$pid" ]; then
    stats="$(ps -o %cpu=,rss= -p "$pid" | awk '{printf "%s,%s", $1, $2}')"
    echo "$(date +%H:%M:%S),$elapsed,$pid,$stats" >> "$out"
  else
    echo "$(date +%H:%M:%S),$elapsed,-,0,0" >> "$out"
    echo "[soak] Argus is not running; logging a zero sample" >&2
  fi
  [ "$elapsed" -ge "$minutes" ] && break
  sleep "$interval"
done
echo "[soak] done: $out"
