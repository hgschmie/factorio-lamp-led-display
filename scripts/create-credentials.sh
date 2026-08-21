#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
secrets_dir="$project_dir/secrets"
passwd_file="$project_dir/mosquitto/config/passwd"

mkdir -p "$secrets_dir"
umask 077
printf 'Daemon MQTT password: ' >&2
IFS= read -r -s daemon_password
printf '\nDevice MQTT password: ' >&2
IFS= read -r -s device_password
printf '\n' >&2
if [[ -z "$daemon_password" || -z "$device_password" ]]; then
  printf 'Passwords must not be empty.\n' >&2
  exit 1
fi

printf '%s\n' daemon > "$secrets_dir/daemon_username"
printf '%s\n' "$daemon_password" > "$secrets_dir/daemon_password"
printf '%s\n' "$device_password" > "$secrets_dir/device_password"
docker run --rm --user "$(id -u):$(id -g)" -v "$project_dir/mosquitto/config:/mosquitto/config" eclipse-mosquitto:2.0.22 \
  mosquitto_passwd -b -c /mosquitto/config/passwd daemon "$daemon_password"
docker run --rm --user "$(id -u):$(id -g)" -v "$project_dir/mosquitto/config:/mosquitto/config" eclipse-mosquitto:2.0.22 \
  mosquitto_passwd -b /mosquitto/config/passwd device "$device_password"
chmod 644 "$passwd_file"
chmod 600 "$secrets_dir/daemon_username" "$secrets_dir/daemon_password" "$secrets_dir/device_password"
printf 'Credentials created. Enter username "device" and the device password in each captive portal.\n'
