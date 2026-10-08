#!/usr/bin/env bash
# Usage: disk_check.sh [-t threshold%]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

threshold="$DISK_THRESHOLD"
while getopts "t:h" opt; do
  case $opt in t) threshold="$OPTARG" ;; h) echo "Usage: $0 [-t threshold%]"; exit 0 ;; *) exit 1 ;; esac
done

status=0
while read -r _ _ _ _ pct mount; do
  pct=${pct%\%}
  [[ "$pct" =~ ^[0-9]+$ ]] || continue   # some filesystems report "-"
  info "Disk $mount: ${pct}% used"
  if (( pct > threshold )); then
    alert "disk_${mount}" "Disk $mount at ${pct}% (threshold ${threshold}%)"
    status=2
  fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | tail -n +2)

exit $status
