#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
daemon_password=$(<"$project_dir/secrets/daemon_password")
test_dir=$(mktemp -d)
test_config="$test_dir/display.yaml"
override="$test_dir/compose.override.yaml"
cp "$project_dir/config.yaml" "$test_config"
printf 'services:\n  daemon:\n    volumes:\n      - %s:/config/display.yaml:ro\n' "$test_config" > "$override"
compose=(docker compose -p factorio-display-integration -f "$project_dir/compose.yaml" -f "$override")

cleanup() {
  "${compose[@]}" down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT
"${compose[@]}" up -d --build

python3 - <<'PY'
import json, socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
p = {"version":1,"save_id":"integration","sequence":1,"tick":60,"type":"snapshot","channels":[{"id":"smelter-1","status":"working"}]}
s.sendto(json.dumps(p).encode(), ("127.0.0.1", 34198))
time.sleep(2)
PY

payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v1/device/shop-floor-a/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["version"] == 1
assert frame["pixels"][0]["g"] == 255
assert len(frame["pixels"]) >= 1
print("received valid retained working frame")
PY

python3 - "$test_config" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace("working:   {r: 0,   g: 255, b: 0,   effect: solid}", "working:   {r: 0,   g: 0,   b: 250, effect: solid}")
p.write_text(text)
PY
sleep 2
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v1/device/shop-floor-a/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["pixels"][0]["b"] == 250
print("valid mapping/color reload applied")
PY

printf '\ninvalid: [' >> "$test_config"
sleep 2
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v1/device/shop-floor-a/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["pixels"][0]["b"] == 250
print("invalid reload retained the previous valid configuration")
PY

printf 'Waiting 12 seconds for the stale-game transition...\n'
sleep 12
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v1/device/shop-floor-a/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["pixels"][0]["b"] == 255
assert frame["pixels"][0]["effect"] == "pulse"
print("received valid retained stale-game frame")
PY
