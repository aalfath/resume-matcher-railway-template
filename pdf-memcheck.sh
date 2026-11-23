#!/bin/sh
# Installed in front of Playwright's driver and its headless Chromium (used only for
# PDF export). PDF export needs about 1 GB of memory in total: on a smaller service
# (Railway's 0.5 GB Free/Trial plans) starting them gets the whole app OOM-killed,
# so below CHROMIUM_MIN_MEMORY_MB (default 700) they refuse to start and the export
# fails with an error while the rest of the app keeps running.
# Set CHROMIUM_MIN_MEMORY_MB=0 to skip this check.
min_mb="${CHROMIUM_MIN_MEMORY_MB:-700}"
lim="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)"
case "$lim" in
  ''|max|*[!0-9]*) ;;
  *)
    if [ "$min_mb" -gt 0 ] && [ "$lim" -lt $((min_mb * 1024 * 1024)) ]; then
      echo "PDF export needs about 1 GB of memory; this service has $((lim / 1048576)) MB. Raise the service's memory limit (Railway: Settings > Resources) to use PDF export." >&2
      exit 1
    fi ;;
esac
echo 1000 > /proc/self/oom_score_adj 2>/dev/null || true
