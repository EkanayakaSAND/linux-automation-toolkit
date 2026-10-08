#!/usr/bin/env bash
# Usage: log_compress.sh [-n] [dir ...]   (-n = dry run)
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

dry=false
while getopts "nh" opt; do
  case $opt in n) dry=true ;; h) echo "Usage: $0 [-n] [dir ...]"; exit 0 ;; *) exit 1 ;; esac
done
shift $(( OPTIND - 1 ))

dirs=("$@")
if (( ${#dirs[@]} == 0 )); then read -ra dirs <<< "$COMPRESS_LOG_DIRS"; fi

for dir in "${dirs[@]}"; do
  [[ -d "$dir" ]] || { warn "Skipping missing directory: $dir"; continue; }

  while IFS= read -r -d '' f; do
    if $dry; then info "[dry-run] would compress $f"
    else gzip -9 -- "$f" && info "Compressed $f"; fi
  done < <(find "$dir" -type f -name '*.log' -mtime +"$LOG_COMPRESS_AFTER_DAYS" -print0)

  while IFS= read -r -d '' f; do
    if $dry; then info "[dry-run] would delete $f"
    else rm -f -- "$f" && info "Deleted $f"; fi
  done < <(find "$dir" -type f -name '*.log.gz' -mtime +"$LOG_DELETE_AFTER_DAYS" -print0)
done
