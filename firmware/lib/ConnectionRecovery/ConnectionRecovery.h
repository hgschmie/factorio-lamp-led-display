#pragma once

#include <stdint.h>

namespace display {

enum class WiFiRecoveryAction : uint8_t { None, Reconnect, Restart };

class WiFiRecovery {
 public:
  WiFiRecovery(uint32_t retryIntervalMs, uint32_t restartAfterMs)
      : retryIntervalMs_(retryIntervalMs), restartAfterMs_(restartAfterMs) {}

  WiFiRecoveryAction updateDisconnected(uint32_t nowMs) {
    if (!recovering_) {
      recovering_ = true;
      disconnectedAtMs_ = nowMs;
      lastAttemptMs_ = nowMs;
      return WiFiRecoveryAction::Reconnect;
    }
    if (nowMs - disconnectedAtMs_ >= restartAfterMs_) {
      return WiFiRecoveryAction::Restart;
    }
    if (nowMs - lastAttemptMs_ >= retryIntervalMs_) {
      lastAttemptMs_ = nowMs;
      return WiFiRecoveryAction::Reconnect;
    }
    return WiFiRecoveryAction::None;
  }

  bool markConnected() {
    const bool recovered = recovering_;
    recovering_ = false;
    return recovered;
  }

  bool recovering() const { return recovering_; }

 private:
  const uint32_t retryIntervalMs_;
  const uint32_t restartAfterMs_;
  bool recovering_ = false;
  uint32_t disconnectedAtMs_ = 0;
  uint32_t lastAttemptMs_ = 0;
};

}  // namespace display
