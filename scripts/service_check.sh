#!/usr/bin/env bash
# Usage: service_check.sh [-r] [service ...]   (-r = try to restart failed services)
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

restart=false
while getopts "rh" opt; do
  case $opt in r) restart=true ;; h) echo "Usage: $0 [-r] [service ...]"; exit 0 ;; *) exit 1 ;; esac
done
shift $(( OPTIND - 1 ))

if $restart; then require_root; fi

services=("$@")
# SERVICES is set in toolkit.conf, not a typo of $services
# shellcheck disable=SC2153
if (( ${#services[@]} == 0 )); then read -ra services <<< "$SERVICES"; fi

status=0
for svc in "${services[@]}"; do
  # A missing unit is a config problem, not an outage; don't alert or fail the run
  if [[ -z "$(systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null || true)" ]]; then
    warn "$svc: not installed on this system — check SERVICES in config"
    continue
  fi
  if systemctl is-active --quiet "$svc"; then
    info "$svc: active"
    continue
  fi
  alert "svc_$svc" "Service $svc is DOWN"
  status=2
  if $restart; then
    if systemctl restart "$svc"; then info "$svc restarted successfully"
    else error "Failed to restart $svc"; fi
  fi
done
exit $status
