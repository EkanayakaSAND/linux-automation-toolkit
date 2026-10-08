#!/usr/bin/env bash
# Usage: cpu_check.sh [-t threshold%]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

threshold="$CPU_THRESHOLD"
while getopts "t:h" opt; do
  case $opt in
    t) threshold="$OPTARG" ;;
    h) echo "Usage: $0 [-t threshold%]"; exit 0 ;;
    *) exit 1 ;;
  esac
done

read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat

idle=$(( (i2 + w2) - (i1 + w1) ))
total=$(( (u2+n2+s2+i2+w2+q2+sq2+st2) - (u1+n1+s1+i1+w1+q1+sq1+st1) ))
(( total > 0 )) || total=1
usage=$(( 100 * (total - idle) / total ))

info "CPU usage: ${usage}% (threshold ${threshold}%)"
if (( usage > threshold )); then
  alert cpu "CPU usage ${usage}% exceeds ${threshold}%"
  ps -eo pid,user,comm,%cpu --sort=-%cpu | sed -n 1,6p | tee -a "$LOG_FILE"
  exit 2
fi
