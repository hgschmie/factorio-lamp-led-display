#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <WebServer.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <cmath>
#include <string>

#include "ConnectionRecovery.h"
#include "FrameParser.h"

#ifndef FIRMWARE_VERSION
#define FIRMWARE_VERSION "dev"
#endif

constexpr uint8_t DATA_PIN = 4;
constexpr uint8_t BOOT_PIN = 9;
constexpr uint32_t BOOT_HOLD_MS = 5000;
constexpr uint32_t TELEMETRY_MS = 30000;
constexpr uint32_t MQTT_RETRY_MS = 5000;
constexpr uint32_t WIFI_RETRY_MS = 5000;
constexpr uint32_t WIFI_RESTART_MS = 60000;
constexpr uint8_t DEFAULT_PIXEL_COUNT = 8;
constexpr uint8_t DEFAULT_CHANNEL_OFFSET = 0;

struct Settings {
  String broker;
  uint16_t port = 1883;
  String username;
  String password;
  String device;
  String pixelOrder = "RGB";
  uint8_t pixels = DEFAULT_PIXEL_COUNT;
  uint8_t channelOffset = DEFAULT_CHANNEL_OFFSET;
  bool valid() const {
    return broker.length() && port > 0 && device.length() && (pixelOrder == "RGB" || pixelOrder == "GRB") &&
      pixels >= 1 && pixels <= display::kMaxPixels && channelOffset < display::kChannelCount &&
      static_cast<uint16_t>(channelOffset) + pixels <= display::kChannelCount;
  }
};

Preferences preferences;
Settings settings;
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
WebServer webServer(80);
Adafruit_NeoPixel* strip = nullptr;
display::Frame frame;
bool haveFrame = false;
uint64_t lastSequence = 0;
uint32_t lastTelemetry = 0;
uint32_t lastMQTTAttempt = 0;
volatile bool portalRequested = false;
String mdnsHostname;
display::WiFiRecovery wifiRecovery(WIFI_RETRY_MS, WIFI_RESTART_MS);

String topic(const char* suffix) { return "factorio-display/v2/device/" + settings.device + "/" + suffix; }
String channelFrameTopic() { return "factorio-display/v2/channels/set"; }

String defaultDeviceID() {
  return "esp-" + String((uint32_t)(ESP.getEfuseMac() & 0xffffff),HEX);
}

bool validDeviceID(const String& value);

void loadSettings() {
  preferences.begin("display", true);
  settings.broker = preferences.getString("broker", ""); settings.port = preferences.getUShort("port", 1883);
  settings.username = preferences.getString("mqtt_user", ""); settings.password = preferences.getString("mqtt_pass", "");
  settings.device = preferences.getString("device", defaultDeviceID()); settings.pixelOrder = preferences.getString("order", "RGB");
  settings.pixels = preferences.getUChar("pixels", DEFAULT_PIXEL_COUNT);
  settings.channelOffset = preferences.getUChar("chan_offset", DEFAULT_CHANNEL_OFFSET);
  preferences.end();
  if (settings.port == 0) settings.port = 1883;
  if (!validDeviceID(settings.device)) settings.device = defaultDeviceID();
  if (settings.pixelOrder != "RGB" && settings.pixelOrder != "GRB") settings.pixelOrder = "RGB";
  if (settings.pixels < 1 || settings.pixels > display::kMaxPixels) settings.pixels = DEFAULT_PIXEL_COUNT;
  if (settings.channelOffset >= display::kChannelCount ||
      static_cast<uint16_t>(settings.channelOffset) + settings.pixels > display::kChannelCount) {
    settings.channelOffset = DEFAULT_CHANNEL_OFFSET;
  }
}

void saveSettings(const Settings& value) {
  preferences.begin("display", false);
  preferences.putString("broker", value.broker); preferences.putUShort("port", value.port);
  preferences.putString("mqtt_user", value.username); preferences.putString("mqtt_pass", value.password);
  preferences.putString("device", value.device); preferences.putString("order", value.pixelOrder);
  preferences.putUChar("pixels", value.pixels);
  preferences.putUChar("chan_offset", value.channelOffset);
  preferences.end();
}

bool validDeviceID(const String& value) {
  if (!value.length() || value.length() > 32) return false;
  for (size_t i = 0; i < value.length(); ++i) {
    const char c = value[i];
    if (!isalnum(static_cast<unsigned char>(c)) && c != '-' && c != '_' && c != '.') return false;
  }
  return true;
}

String htmlEscape(const String& value) {
  String result; result.reserve(value.length() + 16);
  for (size_t i = 0; i < value.length(); ++i) {
    switch (value[i]) {
      case '&': result += "&amp;"; break;
      case '<': result += "&lt;"; break;
      case '>': result += "&gt;"; break;
      case '\"': result += "&quot;"; break;
      case '\'': result += "&#39;"; break;
      default: result += value[i];
    }
  }
  return result;
}

String makeHostname() {
  String result = "factorio-display-" + settings.device;
  result.toLowerCase();
  for (size_t i = 0; i < result.length(); ++i) {
    const char c = result[i];
    if (!isalnum(static_cast<unsigned char>(c)) && c != '-') result.setCharAt(i, '-');
  }
  if (result.length() > 63) result.remove(63);
  return result;
}

void showConfigPage(const String& message = "", int status = 200) {
  String page; page.reserve(5000);
  page = F("<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
           "<title>Factorio Display</title><style>body{font:16px system-ui;max-width:34rem;margin:2rem auto;padding:0 1rem;background:#172018;color:#eef7ee}"
           "form{background:#253128;padding:1.25rem;border-radius:.7rem}label{display:block;margin:.8rem 0 .25rem}input,select{box-sizing:border-box;width:100%;padding:.65rem}"
           "button{margin-top:1.2rem;padding:.7rem 1.2rem;background:#65c466;border:0;border-radius:.35rem;font-weight:700}.note{color:#b9c9ba}.message{padding:.7rem;background:#5b3328}</style></head><body>"
           "<h1>Factorio Display</h1><p class='note'>IP: ");
  page += WiFi.localIP().toString(); page += F(" &middot; MQTT: ");
  page += mqtt.connected() ? F("connected") : F("disconnected"); page += F("</p>");
  if (message.length()) { page += F("<p class='message'>"); page += htmlEscape(message); page += F("</p>"); }
  page += F("<form method='post' action='/save'><label>MQTT broker host</label><input required name='broker' value='");
  page += htmlEscape(settings.broker); page += F("'><label>MQTT broker port</label><input required type='number' min='1' max='65535' name='port' value='");
  page += String(settings.port); page += F("'><label>MQTT username</label><input name='username' value='");
  page += htmlEscape(settings.username); page += F("'><label>MQTT password</label><input type='password' name='password' placeholder='Leave blank to keep current password'>"
                                        "<label>Device ID</label><input required maxlength='32' pattern='[A-Za-z0-9._-]+' name='device' value='");
  page += htmlEscape(settings.device); page += F("'><label>Pixel count</label><input required type='number' min='1' max='16' name='pixels' value='");
  page += String(settings.pixels); page += F("'><label>Channel offset</label><input required type='number' min='0' max='63' name='offset' value='");
  page += String(settings.channelOffset); page += F("'><p class='note'>Pixel 0 displays the offset channel; each following pixel displays the next channel.</p>"
                                                   "<label>Pixel color order</label><select name='order'><option value='RGB'");
  if (settings.pixelOrder == "RGB") page += F(" selected");
  page += F(">RGB</option><option value='GRB'");
  if (settings.pixelOrder == "GRB") page += F(" selected");
  page += F(">GRB</option></select><button type='submit'>Save and restart</button></form>"
                                            "<p class='note'>This page is available only on your local network and does not reveal the saved password.</p></body></html>");
  webServer.send(status, "text/html", page);
}

void saveConfigPage() {
  Settings candidate = settings;
  candidate.broker = webServer.arg("broker"); candidate.broker.trim();
  candidate.username = webServer.arg("username"); candidate.username.trim();
  candidate.device = webServer.arg("device"); candidate.device.trim();
  candidate.pixelOrder = webServer.arg("order"); candidate.pixelOrder.toUpperCase();
  const String newPassword = webServer.arg("password");
  if (newPassword.length()) candidate.password = newPassword;
  const long port = webServer.arg("port").toInt();
  const long pixels = webServer.arg("pixels").toInt();
  const long offset = webServer.arg("offset").toInt();
  if (port < 1 || port > 65535 || pixels < 1 || pixels > display::kMaxPixels ||
      offset < 0 || offset >= display::kChannelCount || offset + pixels > display::kChannelCount ||
      !candidate.broker.length() || !validDeviceID(candidate.device) ||
      (candidate.pixelOrder != "RGB" && candidate.pixelOrder != "GRB")) {
    showConfigPage("Invalid values. Check the broker, port, device ID, pixel count, and channel offset.", 400); return;
  }
  candidate.port = static_cast<uint16_t>(port); candidate.pixels = static_cast<uint8_t>(pixels); candidate.channelOffset = static_cast<uint8_t>(offset);
  saveSettings(candidate);
  webServer.send(200, "text/html", "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
                                     "<meta http-equiv='refresh' content='10;url=/'>"
                                     "<title>Factorio Display</title></head><body><p>Saved. Restarting&hellip;</p>"
                                     "<p>This page will return to the display settings in 10 seconds.</p></body></html>");
  delay(300); ESP.restart();
}

void startMDNS() {
  MDNS.end();
  mdnsHostname = makeHostname();
  if (MDNS.begin(mdnsHostname.c_str())) MDNS.addService("http", "tcp", 80);
}

void startConfigServer() {
  startMDNS();
  webServer.on("/", HTTP_GET, [](){ showConfigPage(); });
  webServer.on("/save", HTTP_POST, saveConfigPage);
  webServer.onNotFound([](){ webServer.sendHeader("Location", "/"); webServer.send(302); });
  webServer.begin();
  Serial.printf("Configuration page: http://%s/ or http://%s.local/\n", WiFi.localIP().toString().c_str(), mdnsHostname.c_str());
}

bool runPortal(bool force = false) {
  WiFiManager wm;
  wm.setConfigPortalTimeout(300);
  const String ap = "Factorio-Display-" + String((uint32_t)(ESP.getEfuseMac() & 0xffffff),HEX);
  return force ? wm.startConfigPortal(ap.c_str()) : wm.autoConnect(ap.c_str());
}

void mqttCallback(char*, byte* payload, unsigned int length) {
  display::Frame candidate; std::string error;
  if (!display::parseFrame(reinterpret_cast<char*>(payload),length,settings.pixels,settings.channelOffset,lastSequence,millis(),candidate,error)) {
    Serial.printf("Rejected MQTT frame: %s\n",error.c_str()); return;
  }
  frame=candidate;lastSequence=frame.sequence;haveFrame=true;
}

void publishAvailability(const char* value) { mqtt.publish(topic("availability").c_str(),value,true); }

bool connectMQTT() {
  if (mqtt.connected()) return true;
  const String clientId="factorio-display-"+settings.device;
  const String availability=topic("availability");
  if (!mqtt.connect(clientId.c_str(),settings.username.c_str(),settings.password.c_str(),availability.c_str(),1,true,"offline")) {
    Serial.printf("MQTT connection failed (state %d); retrying in 5 seconds\n", mqtt.state()); return false;
  }
  // A reconnect begins a new ordered delivery session. This permits the broker's
  // retained frame (and a restarted daemon's sequence) to restore the display.
  lastSequence=0;haveFrame=false;
  if (!mqtt.subscribe(channelFrameTopic().c_str(),1)) {
    Serial.println("MQTT subscription failed; retrying in 5 seconds"); mqtt.disconnect(); return false;
  }
  publishAvailability("online");
  Serial.printf("MQTT connected to %s:%u as %s\n",settings.broker.c_str(),settings.port,clientId.c_str());
  return true;
}

void publishTelemetry() {
  JsonDocument doc;doc["version"]=1;doc["firmware"]=FIRMWARE_VERSION;doc["ip"]=WiFi.localIP().toString();
  doc["rssi"]=WiFi.RSSI();doc["uptime_s"]=millis()/1000;doc["pixel_count"]=settings.pixels;
  doc["channel_offset"]=settings.channelOffset;
  doc["pixel_order"]=settings.pixelOrder;
  char payload[256];const size_t n=serializeJson(doc,payload,sizeof(payload));
  mqtt.publish(topic("telemetry").c_str(),reinterpret_cast<const uint8_t*>(payload),n,false);
}

uint8_t scale(uint8_t value,float amount){return static_cast<uint8_t>(value*amount);}
void render() {
  if (!strip) return;
  const uint32_t now=millis();
  const auto state=display::renderState(mqtt.connected(),haveFrame,frame,now);
  if (state==display::RenderState::MqttDisconnected) {
    const float wave=(sinf(now/700.0f)+1.0f)*0.5f;strip->setBrightness(display::kMaxBrightness);
    for(uint8_t i=0;i<settings.pixels;i++)strip->setPixelColor(i,strip->Color(scale(255,wave),scale(90,wave),0));strip->show();return;
  }
  if (state==display::RenderState::AwaitingFrame) {
    strip->clear();strip->show();return;
  }
  strip->setBrightness(display::kMaxBrightness);
  const bool blink=(now/500)%2==0;const float pulse=(sinf(now/700.0f)+1.0f)*0.5f;
  for(uint8_t i=0;i<frame.pixelCount;i++){
    const auto& p=frame.pixels[i];float amount=p.brightness/255.0f;if(p.effect==display::Effect::Blink)amount*=blink?1.0f:0.0f;else if(p.effect==display::Effect::Pulse)amount*=pulse;
    strip->setPixelColor(i,strip->Color(scale(p.r,amount),scale(p.g,amount),scale(p.b,amount)));
  }
  strip->show();
}

void monitorBootButton(void*) {
  uint32_t pressedAt = 0;
  for (;;) {
    if (digitalRead(BOOT_PIN) == LOW) {
      if (!pressedAt) pressedAt = millis();
      else if (millis() - pressedAt >= BOOT_HOLD_MS) portalRequested = true;
    } else pressedAt = 0;
    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

void logWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
    Serial.printf("Wi-Fi disconnected (reason %u)\n",info.wifi_sta_disconnected.reason);
  }
}

void setup() {
  Serial.begin(115200);pinMode(BOOT_PIN,INPUT_PULLUP);
  xTaskCreate(monitorBootButton,"boot-button",2048,nullptr,1,nullptr);
  WiFi.onEvent(logWiFiEvent);
  loadSettings();
  while(true){
    const bool forcePortal=portalRequested;
    if(forcePortal){portalRequested=false;Serial.println("BOOT held for five seconds; forcing captive portal");}
    if(runPortal(forcePortal))break;
    Serial.println("Wi-Fi provisioning failed; retrying");delay(1000);
  }
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);
  wifiRecovery.markConnected();
  Serial.printf("Wi-Fi connected: %s (RSSI %d dBm)\n",WiFi.localIP().toString().c_str(),WiFi.RSSI());
  const neoPixelType pixelType=(settings.pixelOrder=="GRB"?NEO_GRB:NEO_RGB)+NEO_KHZ800;
  strip=new Adafruit_NeoPixel(settings.pixels,DATA_PIN,pixelType);strip->begin();strip->clear();strip->show();
  mqtt.setServer(settings.broker.c_str(),settings.port);mqtt.setCallback(mqttCallback);mqtt.setBufferSize(8192);mqtt.setKeepAlive(30);mqtt.setSocketTimeout(2);
  startConfigServer();
  if(!settings.valid()||!validDeviceID(settings.device))Serial.println("MQTT is not configured; use the management page");
}

void loop() {
  if(portalRequested){Serial.println("BOOT held for five seconds; starting captive portal");webServer.stop();MDNS.end();if(mqtt.connected()){publishAvailability("offline");mqtt.disconnect();}runPortal(true);ESP.restart();}
  webServer.handleClient();
  if(WiFi.status()!=WL_CONNECTED){
    const bool newlyDisconnected=!wifiRecovery.recovering();
    const auto action=wifiRecovery.updateDisconnected(millis());
    if(newlyDisconnected){Serial.println("Wi-Fi unavailable; stopping MQTT transport");wifiClient.stop();haveFrame=false;}
    if(action==display::WiFiRecoveryAction::Reconnect){Serial.println("Attempting Wi-Fi reconnect");WiFi.reconnect();}
    else if(action==display::WiFiRecoveryAction::Restart){Serial.println("Wi-Fi unavailable for 60 seconds; restarting");delay(50);ESP.restart();}
    render();delay(10);return;
  }
  if(wifiRecovery.markConnected()){
    Serial.printf("Wi-Fi restored: %s (RSSI %d dBm)\n",WiFi.localIP().toString().c_str(),WiFi.RSSI());
    wifiClient.stop();lastMQTTAttempt=0;startMDNS();
  }
  if(settings.valid()&&validDeviceID(settings.device)&&!mqtt.connected()&&(lastMQTTAttempt==0||millis()-lastMQTTAttempt>=MQTT_RETRY_MS)){lastMQTTAttempt=millis();connectMQTT();}
  if(mqtt.connected()&&!mqtt.loop())Serial.printf("MQTT connection lost (state %d)\n",mqtt.state());
  if(mqtt.connected()&&millis()-lastTelemetry>=TELEMETRY_MS){lastTelemetry=millis();publishTelemetry();}
  render();delay(10);
}
