#include <unity.h>
#include <string>

#include "FrameParser.h"

using display::Frame;

std::string framePayload(uint64_t sequence = 2, int channelCount = display::kChannelCount,
                         int duplicateLast = -1, bool badBrightness = false,
                         int version = display::kProtocolVersion) {
  std::string payload = "{\"version\":" + std::to_string(version) +
    ",\"sequence\":" + std::to_string(sequence) +
    ",\"expires_in_ms\":7000,\"channels\":[";
  for (int i = 0; i < channelCount; ++i) {
    if (i) payload += ',';
    const int channel = duplicateLast >= 0 && i == channelCount - 1 ? duplicateLast : i;
    payload += "{\"channel\":" + std::to_string(channel) +
      ",\"r\":" + std::to_string(channel) +
      ",\"g\":" + std::to_string(channel + 1) +
      ",\"b\":" + std::to_string(channel + 2);
    if (channel == 8) payload += badBrightness ? ",\"brightness\":256" : ",\"brightness\":127";
    payload += std::string(",\"effect\":\"") + (channel == 9 ? "pulse" : "solid") + "\"}";
  }
  return payload + "]}";
}

void test_valid_frame_selects_configured_channel_range() {
  const std::string payload = framePayload();
  Frame frame; std::string error;
  TEST_ASSERT_TRUE(display::parseFrame(payload.data(), payload.size(), 2, 8, 1, 100, frame, error));
  TEST_ASSERT_EQUAL(8, frame.pixels[0].r);
  TEST_ASSERT_EQUAL(127, frame.pixels[0].brightness);
  TEST_ASSERT_EQUAL(9, frame.pixels[1].r);
  TEST_ASSERT_EQUAL(255, frame.pixels[1].brightness);
  TEST_ASSERT_EQUAL_INT(static_cast<int>(display::Effect::Pulse), static_cast<int>(frame.pixels[1].effect));
  TEST_ASSERT_EQUAL(7100, frame.expiresAtMs);
  TEST_ASSERT_EQUAL(2, frame.pixelCount);
}

void test_stale_sequence_and_configured_bounds() {
  const std::string payload = framePayload();
  Frame frame; std::string error;
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 2, 8, 2, 0, frame, error));
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 5, 60, 1, 0, frame, error));
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 0, 0, 1, 0, frame, error));
}

void test_requires_complete_unique_64_channel_frame() {
  Frame frame; std::string error;
  std::string payload = framePayload(3, 63);
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 2, 0, 1, 0, frame, error));
  payload = framePayload(3, display::kChannelCount, 0);
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 2, 0, 1, 0, frame, error));
  payload = framePayload(3, display::kChannelCount, -1, true);
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 2, 8, 1, 0, frame, error));
  payload = framePayload(3, display::kChannelCount, -1, false, 1);
  TEST_ASSERT_FALSE(display::parseFrame(payload.data(), payload.size(), 2, 0, 1, 0, frame, error));
}

void test_expiry_and_atomic_rejection() {
  const std::string payload = framePayload();
  Frame frame; std::string error;
  TEST_ASSERT_TRUE(display::parseFrame(payload.data(), payload.size(), 2, 0, 1, 100, frame, error));
  TEST_ASSERT_FALSE(display::expired(frame, 7099));
  TEST_ASSERT_TRUE(display::expired(frame, 7100));
  const Frame before = frame;
  TEST_ASSERT_FALSE(display::parseFrame("{}", 2, 2, 0, 2, 0, frame, error));
  TEST_ASSERT_EQUAL(before.sequence, frame.sequence);
}

void test_connection_state_transitions() {
  Frame frame; frame.expiresAtMs = 100;
  TEST_ASSERT_EQUAL_INT(static_cast<int>(display::RenderState::MqttDisconnected), static_cast<int>(display::renderState(false, true, frame, 1)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(display::RenderState::AwaitingFrame), static_cast<int>(display::renderState(true, false, frame, 1)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(display::RenderState::ActiveFrame), static_cast<int>(display::renderState(true, true, frame, 99)));
  TEST_ASSERT_EQUAL_INT(static_cast<int>(display::RenderState::AwaitingFrame), static_cast<int>(display::renderState(true, true, frame, 100)));
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_valid_frame_selects_configured_channel_range);
  RUN_TEST(test_stale_sequence_and_configured_bounds);
  RUN_TEST(test_requires_complete_unique_64_channel_frame);
  RUN_TEST(test_expiry_and_atomic_rejection);
  RUN_TEST(test_connection_state_transitions);
  return UNITY_END();
}
