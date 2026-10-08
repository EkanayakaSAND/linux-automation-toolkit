#!/usr/bin/env bash
# Usage: sudo create_user.sh -u username [-g group] [-s shell] [-k pubkey_file]
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
require_root

user=""; group=""; shell="/bin/bash"; key=""
usage() { echo "Usage: $0 -u username [-g group] [-s shell] [-k pubkey_file]"; }
while getopts "u:g:s:k:h" opt; do
  case $opt in
    u) user="$OPTARG" ;; g) group="$OPTARG" ;; s) shell="$OPTARG" ;; k) key="$OPTARG" ;;
    h) usage; exit 0 ;; *) usage; exit 1 ;;
  esac
done

[[ -n "$user" ]] || { usage; exit 1; }
[[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { error "Invalid username: $user"; exit 1; }
if id "$user" &>/dev/null; then error "User $user already exists"; exit 1; fi
[[ -z "$group" || "$group" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { error "Invalid group name: $group"; exit 1; }
grep -qxF -- "$shell" /etc/shells || { error "Shell not listed in /etc/shells: $shell"; exit 1; }
if [[ -n "$key" ]]; then
  [[ -f "$key" ]] || { error "Key file not found: $key"; exit 1; }
  # Catches typos and, more importantly, someone passing their *private* key
  if grep -q 'PRIVATE KEY' "$key"; then error "$key is a private key; pass the .pub file"; exit 1; fi
  ssh-keygen -l -f "$key" >/dev/null 2>&1 || { error "Not a valid SSH public key: $key"; exit 1; }
fi

args=(-m -s "$shell")
if [[ -n "$group" ]]; then
  getent group "$group" >/dev/null || groupadd "$group"
  args+=(-G "$group")
fi
useradd "${args[@]}" "$user"
info "Created user $user (shell $shell${group:+, group $group})"

if [[ -n "$key" ]]; then
  home=$(getent passwd "$user" | cut -d: -f6)
  pgroup=$(id -gn "$user")   # primary group isn't always named after the user
  install -d -m 700 -o "$user" -g "$pgroup" "$home/.ssh"
  install -m 600 -o "$user" -g "$pgroup" "$key" "$home/.ssh/authorized_keys"
  passwd -l "$user" >/dev/null
  info "SSH key installed for $user; password login locked"
else
  pass=$(openssl rand -base64 12)
  echo "$user:$pass" | chpasswd
  chage -d 0 "$user"            # force password change at first login
  info "Temporary password set for $user (must change at first login)"
  echo "Temporary password (shown once, NOT logged): $pass"
fi
