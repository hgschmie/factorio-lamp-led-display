# Version 1 protocols

Factorio sends localhost UDP datagrams to port 34198. `snapshot` replaces all logical channel state and is the five-second heartbeat; `update` merges only changed channels. Sequence numbers are positive and monotonically increasing within a save ID.

```json
{"version":1,"save_id":"abc","sequence":42,"tick":1234,"type":"snapshot","channels":[{"id":"smelter-1","status":"working"}]}
```

The daemon publishes retained QoS 1 frames to `factorio-display/v1/device/<device>/set`. Frames are complete and expire locally on the controller after `expires_in_ms`; this relative expiry works before the ESP has a wall clock.

```json
{"version":1,"device":"shop-floor-a","sequence":9,"expires_in_ms":7000,"brightness":48,"pixels":[{"index":0,"r":0,"g":255,"b":0,"effect":"solid"}]}
```

The controller rejects malformed, incomplete, wrong-device, wrong-version, expired, duplicate-pixel, out-of-range, and non-increasing-sequence frames atomically. It publishes retained `online`/`offline` availability and non-retained telemetry under the same device topic. MQTT Last Will supplies the offline transition after an unclean disconnect.

