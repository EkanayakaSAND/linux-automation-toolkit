#!/usr/bin/env bash
# Usage: ./setup.sh [--install-cron]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MARK="# linux-automation-toolkit"

chmod +x "$ROOT"/scripts/*.sh
mkdir -p "$ROOT/logs"

if [[ ! -f "$ROOT/config/toolkit.conf" ]]; then
  cp "$ROOT/config/toolkit.conf.example" "$ROOT/config/toolkit.conf"
  chmod 600 "$ROOT/config/toolkit.conf"
  echo "Created config/toolkit.conf — edit it before scheduling"
fi

if [[ "${1:-}" == "--install-cron" ]]; then
  tmp=$(mktemp)
  # Re-running setup replaces our lines instead of duplicating them
  crontab -l 2>/dev/null | grep -v "$MARK" > "$tmp" || true
  cat >> "$tmp" <<EOF
*/5 * * * * $ROOT/scripts/health_check.sh >/dev/null 2>&1 $MARK
0 2 * * *   $ROOT/scripts/backup.sh       >/dev/null 2>&1 $MARK
30 3 * * *  $ROOT/scripts/log_compress.sh >/dev/null 2>&1 $MARK
0 4 * * 0   $ROOT/scripts/cleanup_tmp.sh  >/dev/null 2>&1 $MARK
EOF
  crontab "$tmp"; rm -f "$tmp"
  echo "Cron jobs installed. View with: crontab -l"
fi
echo "Setup complete."
