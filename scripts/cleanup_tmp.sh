#!/usr/bin/env bash
# Usage: cleanup_tmp.sh [-n] [-a days] [dir ...]   (-n = dry run)
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

dry=false; age="$TMP_MAX_AGE_DAYS"
while getopts "na:h" opt; do
  case $opt in
    n) dry=true ;; a) age="$OPTARG" ;;
    h) echo "Usage: $0 [-n] [-a days] [dir ...]"; exit 0 ;; *) exit 1 ;;
  esac
done
shift $(( OPTIND - 1 ))

dirs=("$@")
if (( ${#dirs[@]} == 0 )); then read -ra dirs <<< "$TMP_DIRS"; fi

for dir in "${dirs[@]}"; do
  if [[ -z "$dir" || "$dir" == "/" ]]; then error "Refusing to clean '$dir'"; continue; fi
  [[ -d "$dir" ]] || { warn "Skipping missing directory: $dir"; continue; }

  mapfile -d '' files < <(find "$dir" -mindepth 1 -xdev -type f -mtime +"$age" -print0)
  info "$dir: ${#files[@]} file(s) older than ${age} days"
  (( ${#files[@]} )) || continue

  if $dry; then
    printf '  [dry-run] %s\n' "${files[@]}"
  else
    rm -f -- "${files[@]}"
    find "$dir" -mindepth 1 -xdev -type d -empty -mtime +"$age" -delete
    info "$dir: cleaned"
  fi
done
