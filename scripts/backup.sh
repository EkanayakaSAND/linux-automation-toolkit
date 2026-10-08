#!/usr/bin/env bash
# Usage: backup.sh [-d dest_dir] [path ...]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

require_root

dest="$BACKUP_DEST"
while getopts "d:h" opt; do
  case $opt in d) dest="$OPTARG" ;; h) echo "Usage: $0 [-d dest] [path ...]"; exit 0 ;; *) exit 1 ;; esac
done
shift $(( OPTIND - 1 ))

sources=("$@")
if (( ${#sources[@]} == 0 )); then read -ra sources <<< "$BACKUP_SOURCES"; fi

mkdir -p "$dest"
archive="$dest/backup-$(hostname)-$(date +%F_%H%M%S).tar.gz"
info "Backing up ${sources[*]} -> $archive"

set +e
tar -czpf "$archive" "${sources[@]}" 2>>"$LOG_FILE"
rc=$?
set -e

case $rc in
  0) info "Backup OK ($(du -h "$archive" | cut -f1))" ;;
  1) warn "Backup completed, but some files changed while being read" ;;
  *) alert backup "Backup FAILED (tar exit $rc) for ${sources[*]}"; rm -f "$archive"; exit 2 ;;
esac

sha256sum "$archive" > "$archive.sha256"
info "Checksum written: $archive.sha256"

# Retention
while IFS= read -r -d '' old; do
  rm -f -- "$old"; info "Removed old backup: $old"
done < <(find "$dest" -maxdepth 1 -name 'backup-*.tar.gz*' -mtime +"$BACKUP_RETENTION_DAYS" -print0)
