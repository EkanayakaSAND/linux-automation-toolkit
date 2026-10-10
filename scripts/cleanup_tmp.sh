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

  # systemd-private-* dirs belong to systemd (PrivateTmp=) and must never be touched
  mapfile -d '' files < <(find "$dir" -mindepth 1 -xdev -name 'systemd-private-*' -prune \
                            -o -type f -mtime +"$age" -print0 2>/dev/null)
  info "$dir: ${#files[@]} file(s) older than ${age} days"
  (( ${#files[@]} )) || continue

  if $dry; then
    printf '  [dry-run] %s\n' "${files[@]}"
  else
    rm -f -- "${files[@]}"
    # Same prune as above; a failed rmdir (e.g. dir no longer empty) must not abort the run
    find "$dir" -mindepth 1 -xdev -name 'systemd-private-*' -prune \
      -o -type d -empty -mtime +"$age" -print0 2>/dev/null \
      | xargs -0 -r rmdir -- 2>/dev/null || true
    info "$dir: cleaned"
  fi
done
