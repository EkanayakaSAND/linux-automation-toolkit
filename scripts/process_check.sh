#!/usr/bin/env bash
# Usage: process_check.sh [-n N] [-s cpu|mem] [-p process_name]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"

n=10; sort=cpu; name=""
while getopts "n:s:p:h" opt; do
  case $opt in
    n) n="$OPTARG" ;; s) sort="$OPTARG" ;; p) name="$OPTARG" ;;
    h) echo "Usage: $0 [-n N] [-s cpu|mem] [-p name]"; exit 0 ;; *) exit 1 ;;
  esac
done

if [[ -n "$name" ]]; then
  if pids=$(pgrep -x "$name"); then
    info "Process '$name' running (PIDs: $(echo "$pids" | tr '\n' ' '))"
    exit 0
  fi
  alert "proc_$name" "Process '$name' is not running"
  exit 2
fi

zombies=$(ps -eo stat= | awk '/^Z/{c++} END{print c+0}')
info "Total processes: $(ps -e --no-headers | wc -l), zombies: $zombies"

key="%cpu"; [[ "$sort" == "mem" ]] && key="%mem"
ps -eo pid,user,comm,%cpu,%mem --sort=-"$key" | sed -n "1,$(( n + 1 ))p"
