# Version 2 protocols

Factorio sends localhost UDP datagrams to port 34198. There are exactly 64 channels, numbered `0..63`. `snapshot` replaces all channel state and is the five-second heartbeat; `update` merges only changed channels. Sequence numbers are positive and monotonically increasing within a save ID.

Factorio serializes an empty Lua table as `{}`. The daemon therefore accepts `"channels":{}` only as an empty channel list; non-empty channel objects remain invalid.

```json
{"version":2,"save_id":"abc","sequence":42,"tick":1234,"type":"snapshot","channels":[{"id":0,"status":"working"}]}
```

Physical-display lamps use direct-color records in the same `channels` array. Status and direct-color records may be mixed in one snapshot. Direct records require RGB, brightness, and effect fields.

```json
{"id":8,"r":255,"g":80,"b":0,"brightness":192,"effect":"pulse"}
```

The daemon publishes one retained QoS 1 frame to `factorio-display/v2/channels/set`. It contains all 64 channels and has no device-specific fields. Frames expire locally on each controller after `expires_in_ms`; this relative expiry works before the ESP has a wall clock.

```json
{"version":2,"sequence":9,"expires_in_ms":7000,"channels":[{"channel":0,"r":0,"g":255,"b":0,"brightness":127,"effect":"solid"}]}
```

The example is abbreviated; a valid frame has one unique record for every channel `0..63`. Each channel has an independent `0..255` brightness. Status and unassigned channels use `255`; physical-display lamps use their in-game brightness setting. Omitted channel brightness defaults to `255` for compatibility. Effects are `solid`, `blink`, or `pulse`.

Each controller stores a pixel count and channel offset. Local pixel `0` displays the offset channel and local pixel `n` displays `offset + n`; the configured range must stay within `0..63`. The controller validates the entire global frame before atomically extracting its local range. It rejects malformed, incomplete, wrong-version, expired, duplicate-channel, out-of-range, and non-increasing-sequence frames. Device identity is used only for MQTT client identity, retained availability at `factorio-display/v2/device/<device>/availability`, and telemetry at `factorio-display/v2/device/<device>/telemetry`. MQTT Last Will supplies the offline transition after an unclean disconnect.
