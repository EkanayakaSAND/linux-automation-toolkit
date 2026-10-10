#!/usr/bin/env bash
# Usage: backup.sh [-d dest_dir] [path ...]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

# Archives contain credential files such as /etc/shadow, so everything this
# script creates (archive, .sha256, dest dir) must be readable by root only.
umask 077

require_root

dest="$BACKUP_DEST"
while getopts "d:h" opt; do
  case $opt in d) dest="$OPTARG" ;; h) echo "Usage: $0 [-d dest] [path ...]"; exit 0 ;; *) exit 1 ;; esac
done
shift $(( OPTIND - 1 ))

sources=("$@")
if (( ${#sources[@]} == 0 )); then read -ra sources <<< "$BACKUP_SOURCES"; fi

# tar runs with -C /, so every source must be an absolute path
for src in "${sources[@]}"; do
  [[ "$src" == /* ]] || { error "Backup source must be an absolute path: $src"; exit 1; }
  # Normalise so "//", "/./", "/etc/.." etc. are caught too; stripping all
  # trailing slashes from root leaves an empty string
  norm="$(realpath -m -- "$src")"
  while [[ "$norm" == */ ]]; do norm="${norm%/}"; done
  if [[ -z "$norm" ]]; then
    error "Refusing to back up / — list specific directories instead"
    exit 1
  fi
done

mkdir -p "$dest"
chmod 700 "$dest"
archive="$dest/backup-$(hostname)-$(date +%F_%H%M%S).tar.gz"
info "Backing up ${sources[*]} -> $archive"

set +e
# Archive relative to / so tar doesn't log "Removing leading '/'" for every path
tar -czpf "$archive" -C / "${sources[@]#/}" 2>>"$LOG_FILE"
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
