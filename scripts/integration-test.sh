#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
daemon_password=$(<"$project_dir/secrets/daemon_password")
test_dir=$(mktemp -d)
test_config="$test_dir/display.yaml"
override="$test_dir/compose.override.yaml"
integration_udp_port=${DISPLAY_INTEGRATION_UDP_PORT:-44198}
export DISPLAY_INTEGRATION_UDP_PORT="$integration_udp_port"
cp "$project_dir/config.example.yaml" "$test_config"
printf 'services:\n  daemon:\n    volumes:\n      - %s:/config/display.yaml:ro\n    ports: !override\n      - "127.0.0.1:%s:34198/udp"\n  mosquitto:\n    ports: !reset []\n' "$test_config" "$integration_udp_port" > "$override"
compose=(docker compose -p factorio-display-integration -f "$project_dir/compose.yaml" -f "$override")

cleanup() {
  "${compose[@]}" down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT
"${compose[@]}" up -d --build

python3 - <<'PY'
import json, os, socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
p = {"version":2,"save_id":"integration","sequence":1,"tick":60,"type":"snapshot","channels":[{"id":0,"status":"working"}]}
s.sendto(json.dumps(p).encode(), ("127.0.0.1", int(os.environ["DISPLAY_INTEGRATION_UDP_PORT"])))
time.sleep(2)
PY

payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v2/channels/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["version"] == 2
assert frame["channels"][0]["g"] == 255
assert len(frame["channels"]) == 64
print("received valid retained working frame")
PY

python3 - <<'PY'
import json, os, socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
p = {"version":2,"save_id":"integration","sequence":2,"tick":61,"type":"update","channels":[{"id":1,"r":12,"g":34,"b":56,"brightness":78,"effect":"blink"}]}
s.sendto(json.dumps(p).encode(), ("127.0.0.1", int(os.environ["DISPLAY_INTEGRATION_UDP_PORT"])))
time.sleep(2)
PY
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v2/channels/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
pixel = json.loads(sys.argv[1])["channels"][1]
assert (pixel["r"], pixel["g"], pixel["b"]) == (12, 34, 56)
assert pixel["brightness"] == 78 and pixel["effect"] == "blink"
print("direct lamp color, brightness, and effect passed through")
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
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v2/channels/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["channels"][0]["b"] == 250
print("valid color reload applied")
PY

printf '\ninvalid: [' >> "$test_config"
sleep 2
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v2/channels/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["channels"][0]["b"] == 250
print("invalid reload retained the previous valid configuration")
PY

printf 'Waiting 12 seconds for the stale-game transition...\n'
sleep 12
payload=$("${compose[@]}" exec -T mosquitto \
  mosquitto_sub -h localhost -u daemon -P "$daemon_password" -t 'factorio-display/v2/channels/set' -C 1 -W 10)
python3 - "$payload" <<'PY'
import json, sys
frame = json.loads(sys.argv[1])
assert frame["channels"][0]["b"] == 255
assert frame["channels"][0]["effect"] == "pulse"
print("received valid retained stale-game frame")
PY
