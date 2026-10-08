#!/usr/bin/env bash
# Sourced by every script. Do not run directly.
set -euo pipefail

# Cron runs with a minimal PATH; make it predictable
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$TOOLKIT_ROOT/config/toolkit.conf}"
[[ -f "$CONFIG_FILE" ]] || { echo "Config not found: $CONFIG_FILE (run setup.sh)" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG_FILE"

LOG_DIR="$TOOLKIT_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/toolkit.log"
SCRIPT_NAME="$(basename "$0" .sh)"

log()   { local lvl="$1"; shift; echo "[$(date '+%F %T')] [$lvl] [$SCRIPT_NAME] $*" | tee -a "$LOG_FILE"; }
info()  { log INFO "$@"; }
warn()  { log WARN "$@"; }
error() { log ERROR "$@" >&2; }

require_root() { [[ $EUID -eq 0 ]] || { error "This script must be run as root (sudo)"; exit 1; }; }

# alert <key> <message>  — key is used for cooldown so cron doesn't spam you
alert() {
  local key="$1" msg="$2" now stamp last=0
  now=$(date +%s)
  stamp="$LOG_DIR/.alert_${key//[^a-zA-Z0-9_]/_}"

  [[ -f "$stamp" ]] && last=$(<"$stamp")
  [[ "$last" =~ ^[0-9]+$ ]] || last=0
  if (( now - last < ${ALERT_COOLDOWN:-1800} )); then
    warn "ALERT (suppressed by cooldown): $msg"
    return 0
  fi
  echo "$now" > "$stamp"
  warn "ALERT: $msg"

  [[ "${ALERT_ENABLED:-false}" == "true" ]] || return 0
  local text
  text="[$(hostname)] ${msg//\"/\\\"}"

  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    curl -fsS -m 10 -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$text\"}" "$SLACK_WEBHOOK_URL" >/dev/null || warn "Slack alert failed"
  fi
  if [[ -n "${ALERT_EMAIL:-}" ]] && command -v mail >/dev/null; then
    echo "$text" | mail -s "[$(hostname)] Toolkit alert" "$ALERT_EMAIL" || warn "Email alert failed"
  fi
}
