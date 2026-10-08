#!/usr/bin/env bash
# Usage: health_check.sh
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
dir="$(dirname "$(readlink -f "$0")")"

failed=()
for check in uptime_check cpu_check mem_check disk_check service_check; do
  echo "===== $check ====="
  if ! "$dir/$check.sh"; then failed+=("$check"); fi
done

if (( ${#failed[@]} )); then
  warn "Health check finished: ${#failed[@]} issue(s) -> ${failed[*]}"
  exit 2
fi
info "Health check finished: all OK"
