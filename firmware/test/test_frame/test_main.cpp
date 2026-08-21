#include <unity.h>
#include <string>
#include "FrameParser.h"

using display::Frame;

const char* valid = R"({"version":1,"device":"dev-a","sequence":2,"expires_in_ms":7000,"brightness":200,"pixels":[{"index":0,"r":1,"g":2,"b":3,"effect":"solid"},{"index":1,"r":4,"g":5,"b":6,"effect":"pulse"}]})";

void test_valid_full_brightness() { Frame f;std::string e;TEST_ASSERT_TRUE(display::parseFrame(valid,strlen(valid),"dev-a",2,1,100,f,e));TEST_ASSERT_EQUAL(200,f.brightness);TEST_ASSERT_EQUAL(7100,f.expiresAtMs);TEST_ASSERT_EQUAL(2,f.pixelCount); }
void test_wrong_device_and_stale_sequence() { Frame f;std::string e;TEST_ASSERT_FALSE(display::parseFrame(valid,strlen(valid),"other",2,1,0,f,e));TEST_ASSERT_FALSE(display::parseFrame(valid,strlen(valid),"dev-a",2,2,0,f,e)); }
void test_requires_complete_bounded_frame() { Frame f;std::string e;TEST_ASSERT_FALSE(display::parseFrame(valid,strlen(valid),"dev-a",3,1,0,f,e));const char* duplicate=R"({"version":1,"device":"dev-a","sequence":3,"expires_in_ms":1,"brightness":1,"pixels":[{"index":0,"r":0,"g":0,"b":0,"effect":"solid"},{"index":0,"r":0,"g":0,"b":0,"effect":"solid"}]})";TEST_ASSERT_FALSE(display::parseFrame(duplicate,strlen(duplicate),"dev-a",2,1,0,f,e)); }
void test_expiry_and_atomic_rejection() { Frame f;std::string e;TEST_ASSERT_TRUE(display::parseFrame(valid,strlen(valid),"dev-a",2,1,100,f,e));TEST_ASSERT_FALSE(display::expired(f,7099));TEST_ASSERT_TRUE(display::expired(f,7100));Frame before=f;const char* bad="{}";TEST_ASSERT_FALSE(display::parseFrame(bad,2,"dev-a",2,2,0,f,e));TEST_ASSERT_EQUAL(before.sequence,f.sequence); }
void test_connection_state_transitions() { Frame f;f.expiresAtMs=100;TEST_ASSERT_EQUAL_INT((int)display::RenderState::MqttDisconnected,(int)display::renderState(false,true,f,1));TEST_ASSERT_EQUAL_INT((int)display::RenderState::AwaitingFrame,(int)display::renderState(true,false,f,1));TEST_ASSERT_EQUAL_INT((int)display::RenderState::ActiveFrame,(int)display::renderState(true,true,f,99));TEST_ASSERT_EQUAL_INT((int)display::RenderState::AwaitingFrame,(int)display::renderState(true,true,f,100)); }

int main(int,char**) { UNITY_BEGIN();RUN_TEST(test_valid_full_brightness);RUN_TEST(test_wrong_device_and_stale_sequence);RUN_TEST(test_requires_complete_bounded_frame);RUN_TEST(test_expiry_and_atomic_rejection);RUN_TEST(test_connection_state_transitions);return UNITY_END(); }
