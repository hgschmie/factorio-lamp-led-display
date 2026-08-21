#include "FrameParser.h"

#include <ArduinoJson.h>
#include <algorithm>

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

bool parseFrame(const char* payload, size_t length, const std::string& expectedDevice,
                uint8_t configuredPixelCount, uint64_t lastSequence, uint32_t nowMs,
                Frame& output, std::string& error) {
  if (configuredPixelCount == 0 || configuredPixelCount > kMaxPixels) {
    error = "configured pixel count is outside 1..16"; return false;
  }
  JsonDocument doc;
  const auto jsonError = deserializeJson(doc, payload, length);
  if (jsonError) { error = jsonError.c_str(); return false; }
  if (!doc["version"].is<int>() || doc["version"].as<int>() != kProtocolVersion) {
    error = "wrong protocol version"; return false;
  }
  if (!doc["device"].is<const char*>() || expectedDevice != doc["device"].as<const char*>()) {
    error = "frame is for another device"; return false;
  }
  if (!doc["sequence"].is<uint64_t>()) { error = "invalid sequence"; return false; }
  const uint64_t sequence = doc["sequence"].as<uint64_t>();
  if (sequence <= lastSequence) { error = "stale sequence"; return false; }
  if (!doc["expires_in_ms"].is<uint32_t>()) { error = "invalid expiry"; return false; }
  const uint32_t ttl = doc["expires_in_ms"].as<uint32_t>();
  if (ttl == 0 || ttl > 60000) { error = "expiry is outside 1..60000ms"; return false; }
  if (!doc["brightness"].is<int>()) { error = "invalid brightness"; return false; }
  const int requestedBrightness = doc["brightness"].as<int>();
  if (requestedBrightness < 0 || requestedBrightness > 255) { error = "invalid brightness"; return false; }
  if (!doc["pixels"].is<JsonArray>()) { error = "pixels must be an array"; return false; }
  const JsonArray pixels = doc["pixels"].as<JsonArray>();
  if (pixels.size() != configuredPixelCount) { error = "frame is not complete"; return false; }

  Frame candidate;
  candidate.sequence = sequence;
  candidate.expiresAtMs = nowMs + ttl;
  candidate.brightness = static_cast<uint8_t>(std::min(requestedBrightness, static_cast<int>(kMaxBrightness)));
  candidate.pixelCount = configuredPixelCount;
  bool seen[kMaxPixels] = {};
  for (JsonObjectConst item : pixels) {
    if (!item["index"].is<int>()) { error = "pixel index is missing"; return false; }
    const int index = item["index"].as<int>();
    if (index < 0 || index >= configuredPixelCount || seen[index]) { error = "duplicate or out-of-range pixel"; return false; }
    seen[index] = true;
    for (const char* field : {"r", "g", "b"}) {
      if (!item[field].is<int>()) { error = std::string("invalid pixel ") + field; return false; }
      const int value = item[field].as<int>();
      if (value < 0 || value > 255) { error = std::string("invalid pixel ") + field; return false; }
    }
    Pixel& pixel = candidate.pixels[index];
    pixel.r = item["r"].as<uint8_t>(); pixel.g = item["g"].as<uint8_t>(); pixel.b = item["b"].as<uint8_t>();
    if (!parseEffect(item["effect"].as<const char*>(), pixel.effect)) { error = "invalid effect"; return false; }
  }
  output = candidate;
  return true;
}

}  // namespace display

