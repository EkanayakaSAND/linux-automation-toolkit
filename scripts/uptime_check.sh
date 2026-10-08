#!/usr/bin/env bash
# Usage: uptime_check.sh
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

info "Uptime: $(uptime -p) (since $(uptime -s))"

read -r l1 l5 l15 _ < /proc/loadavg
cores=$(nproc)
info "Load average: $l1 $l5 $l15 (CPU cores: $cores)"

if [[ -f /var/run/reboot-required ]]; then warn "System reboot required (pending updates)"; fi

# Sustained 5-min load above core count = the box is overloaded
if awk -v l="$l5" -v c="$cores" 'BEGIN{exit !(l > c)}'; then
  alert load "5-min load $l5 exceeds core count $cores"
  exit 2
fi
