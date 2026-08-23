#include "FrameParser.h"

#include <ArduinoJson.h>
namespace display {

static bool parseEffect(const char* value, Effect& result) {
  if (!value) return false;
  const std::string effect(value);
  if (effect == "solid") result = Effect::Solid;
  else if (effect == "blink") result = Effect::Blink;
  else if (effect == "pulse") result = Effect::Pulse;
  else return false;
  return true;
}

bool parseFrame(const char* payload, size_t length, uint8_t configuredPixelCount,
                uint8_t channelOffset, uint64_t lastSequence, uint32_t nowMs,
                Frame& output, std::string& error) {
  if (configuredPixelCount == 0 || configuredPixelCount > kMaxPixels) {
    error = "configured pixel count is outside 1..16"; return false;
  }
  if (channelOffset >= kChannelCount || static_cast<uint16_t>(channelOffset) + configuredPixelCount > kChannelCount) {
    error = "configured channel range is outside 0..63"; return false;
  }
  JsonDocument doc;
  const auto jsonError = deserializeJson(doc, payload, length);
  if (jsonError) { error = jsonError.c_str(); return false; }
  if (!doc["version"].is<int>() || doc["version"].as<int>() != kProtocolVersion) {
    error = "wrong protocol version"; return false;
  }
  if (!doc["sequence"].is<uint64_t>()) { error = "invalid sequence"; return false; }
  const uint64_t sequence = doc["sequence"].as<uint64_t>();
  if (sequence <= lastSequence) { error = "stale sequence"; return false; }
  if (!doc["expires_in_ms"].is<uint32_t>()) { error = "invalid expiry"; return false; }
  const uint32_t ttl = doc["expires_in_ms"].as<uint32_t>();
  if (ttl == 0 || ttl > 60000) { error = "expiry is outside 1..60000ms"; return false; }
  if (!doc["channels"].is<JsonArray>()) { error = "channels must be an array"; return false; }
  const JsonArray channels = doc["channels"].as<JsonArray>();
  if (channels.size() != kChannelCount) { error = "frame is not complete"; return false; }

  Frame candidate;
  candidate.sequence = sequence;
  candidate.expiresAtMs = nowMs + ttl;
  candidate.pixelCount = configuredPixelCount;
  bool seen[kChannelCount] = {};
  for (JsonObjectConst item : channels) {
    if (!item["channel"].is<int>()) { error = "channel index is missing"; return false; }
    const int channel = item["channel"].as<int>();
    if (channel < 0 || channel >= kChannelCount || seen[channel]) { error = "duplicate or out-of-range channel"; return false; }
    seen[channel] = true;
    for (const char* field : {"r", "g", "b"}) {
      if (!item[field].is<int>()) { error = std::string("invalid pixel ") + field; return false; }
      const int value = item[field].as<int>();
      if (value < 0 || value > 255) { error = std::string("invalid pixel ") + field; return false; }
    }
    const bool local = channel >= channelOffset && channel < channelOffset + configuredPixelCount;
    Pixel pixel;
    pixel.r = item["r"].as<uint8_t>(); pixel.g = item["g"].as<uint8_t>(); pixel.b = item["b"].as<uint8_t>();
    if (!item["brightness"].isNull()) {
      if (!item["brightness"].is<int>() || item["brightness"].as<int>() < 0 || item["brightness"].as<int>() > 255) {
        error = "invalid pixel brightness"; return false;
      }
      pixel.brightness = item["brightness"].as<uint8_t>();
    }
    if (!parseEffect(item["effect"].as<const char*>(), pixel.effect)) { error = "invalid effect"; return false; }
    if (local) candidate.pixels[channel - channelOffset] = pixel;
  }
  output = candidate;
  return true;
}

}  // namespace display
