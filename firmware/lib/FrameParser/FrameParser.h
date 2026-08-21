#pragma once

#include <stdint.h>
#include <string>

namespace display {

constexpr uint8_t kProtocolVersion = 1;
constexpr uint8_t kMaxPixels = 16;
constexpr uint8_t kMaxBrightness = 255;

enum class Effect : uint8_t { Solid, Blink, Pulse };

struct Pixel {
  uint8_t r = 0;
  uint8_t g = 0;
  uint8_t b = 0;
  Effect effect = Effect::Solid;
};

struct Frame {
  uint64_t sequence = 0;
  uint32_t expiresAtMs = 0;
  uint8_t brightness = 0;
  uint8_t pixelCount = 0;
  Pixel pixels[kMaxPixels];
};

enum class RenderState : uint8_t { MqttDisconnected, AwaitingFrame, ActiveFrame };

bool parseFrame(const char* payload, size_t length, const std::string& expectedDevice,
                uint8_t configuredPixelCount, uint64_t lastSequence, uint32_t nowMs,
                Frame& output, std::string& error);

inline bool expired(const Frame& frame, uint32_t nowMs) {
  return static_cast<int32_t>(nowMs - frame.expiresAtMs) >= 0;
}

inline RenderState renderState(bool mqttConnected, bool haveFrame, const Frame& frame, uint32_t nowMs) {
  if (!mqttConnected) return RenderState::MqttDisconnected;
  if (!haveFrame || expired(frame, nowMs)) return RenderState::AwaitingFrame;
  return RenderState::ActiveFrame;
}

}  // namespace display
