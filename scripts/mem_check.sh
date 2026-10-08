#!/usr/bin/env bash
# Usage: mem_check.sh [-t threshold%]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

threshold="$MEM_THRESHOLD"
while getopts "t:h" opt; do
  case $opt in t) threshold="$OPTARG" ;; h) echo "Usage: $0 [-t threshold%]"; exit 0 ;; *) exit 1 ;; esac
done

# MemAvailable (not MemFree) is what actually matters — Linux uses free RAM for cache
read -r total avail < <(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print t, a}' /proc/meminfo)
usage=$(( 100 * (total - avail) / total ))

info "Memory usage: ${usage}% ($(( avail / 1024 )) MiB available of $(( total / 1024 )) MiB)"
if (( usage > threshold )); then
  alert mem "Memory usage ${usage}% exceeds ${threshold}%"
  ps -eo pid,user,comm,%mem --sort=-%mem | sed -n 1,6p | tee -a "$LOG_FILE"
  exit 2
fi
