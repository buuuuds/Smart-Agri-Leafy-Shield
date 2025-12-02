#include <Arduino.h>
#include <Wire.h>
#include <BH1750.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoJson.h>
#include <time.h>
#include <WiFiManager.h>
#include <esp_task_wdt.h>
#include <ModbusMaster.h>
#include <HardwareSerial.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ====== FUNCTION FORWARD DECLARATIONS ======
void fetchPlantSettings();
void controlShade(String action);
void stopShadeMotor();
void controlPump(String mode, String action);
void readXYMD02Sensor();
void readNPKSensor();
void readWaterLevelSensor();
void readAndSendSensorData();
void sendHeartbeat();
void checkCommands();
void checkWiFiConnection();
void autoControlIrrigation();
void autoControlMisting();
void autoControlShade();
void initWiFi();
void initFirebase();
void diagnoseWiFi();
void analyzeSoilNutrients();
void assessDiseaseRisk();
bool isTimeSynced();
void syncTimeWithRetry();

// ====== PIN DEFINITIONS ======
#define I2C_SDA 21
#define I2C_SCL 22
#define SOIL_PIN 34
#define WATER_TRIG_PIN 32
#define WATER_ECHO_PIN 35
#define TANK_HEIGHT 45

const int SHADE_MOTOR_PIN_1 = 14;
const int SHADE_MOTOR_PIN_2 = 33;
const int PUMP_PIN_1 = 26;
const int PUMP_PIN_2 = 27;

#define XYMD02_RS485_RXD 16
#define XYMD02_RS485_TXD 17
#define XYMD02_RS485_DE_RE_PIN 25
#define NPK_RS485_RXD 18
#define NPK_RS485_TXD 19
#define NPK_RS485_DE_RE_PIN 23
#define XYMD02_SLAVE_ID 0x01
#define NPK_SLAVE_ID 0x01

// ====== CALIBRATION ======
int SOIL_RAW_AIR = 3000;
int SOIL_RAW_WATER = 1300;
#define SHADE_MOTOR_DURATION 10000
#define PUMP_REST_PERIOD 10000
#define IRRIGATION_DURATION 30000
#define MISTING_DURATION 15000

// ====== FIREBASE CONFIG ======
#define DATABASE_URL "https://agri-leafy-default-rtdb.firebaseio.com"
#define FIREBASE_API_KEY "AIzaSyAOcezTxHko-4rUcmuDy8u91Ky8yOUWX4g"
#define DEVICE_ID "ESP32_ALS_001"
#define UPDATE_INTERVAL 5000
#define HEARTBEAT_INTERVAL 30000
#define WIFI_CHECK_INTERVAL 5000

// ====== PLANT-BASED THRESHOLDS ======
String selectedPlantName = "Pechay";
double plantMinTemperature = 15.0;
double plantMaxTemperature = 30.0;
int plantMinSoilMoisture = 40;
int plantMaxSoilMoisture = 80;
int plantMinHumidity = 60;
int plantMaxHumidity = 80;
int plantMinLightIntensity = 800;
int plantMaxLightIntensity = 1500;
bool plantSettingsLoaded = false;

int waterLevelLowThreshold = 20;

// ====== OBJECTS ======
BH1750 lightMeter;
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
WiFiManager wifiManager;
HardwareSerial SerialRS485(2);
ModbusMaster modbus_node_XYMD02;
HardwareSerial SerialNPK(1);
ModbusMaster modbus_node_NPK;

// ====== SENSOR VARIABLES ======
float temperatureFiltered = NAN;
float humidityFiltered = NAN;
float alpha = 0.5;
float currentTemperature = NAN;
float currentHumidity = NAN;
bool tempSensorConnected = false;
bool humiditySensorConnected = false;
float currentNPKN = NAN;
float currentNPKP = NAN;
float currentNPKK = NAN;
bool npkSensorConnected = false;
float soilPercent = NAN;
bool analog_soil_sensor_is_connected = false;
int currentSoilRaw = 0;
float currentLightLevel = NAN;
bool bh1750_ok = false;
float currentWaterDistance = NAN;
float currentWaterLevel = NAN;
int currentWaterPercent = 0;
bool waterLevelSensorConnected = false;

// ====== SYSTEM STATE ======
bool firebase_ready = false;
unsigned long lastUpdate = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastWiFiCheck = 0;
String currentMode = "auto";
String pumpMode = "soil";

// ====== SHADE STATE ======
unsigned long shadeMotorStartTime = 0;
bool isShadeMoving = false;
bool shadeDeployed = false;

// ====== PUMP STATE ======
String currentPumpMode = "none";
unsigned long pumpStartTime = 0;
bool isPumpRunning = false;
unsigned long lastPumpStopTime = 0;
unsigned long totalIrrigationRuntime = 0;
int irrigationCycleCount = 0;
unsigned long totalMistingRuntime = 0;
int mistingCycleCount = 0;

// ====== SMART WATERING STATE ======
float lastSoilBeforeIrrigation = NAN;
float lastHumidityBeforeMisting = NAN;
unsigned long extendedCooldownUntil = 0;
const unsigned long EXTENDED_COOLDOWN = 1800000;

// ====== WIFI RECONNECT ======
bool wifiReconnecting = false;
int consecutiveFailures = 0;
const int MAX_CONSECUTIVE_FAILURES = 3;

// ====== NTP CONFIG (PHILIPPINE TIME) ======
const char* ntpServer = "ph.pool.ntp.org";  // Philippine NTP server
const char* ntpBackup = "pool.ntp.org";     // Backup NTP server
const long gmtOffset_sec = 8 * 3600;        // UTC+8 (Philippine Time)
const int daylightOffset_sec = 0;           // No DST in Philippines

// ====== MODBUS CALLBACKS ======
void preTransmissionXYMD02() { digitalWrite(XYMD02_RS485_DE_RE_PIN, HIGH); }
void postTransmissionXYMD02() { digitalWrite(XYMD02_RS485_DE_RE_PIN, LOW); }
void preTransmissionNPK() { digitalWrite(NPK_RS485_DE_RE_PIN, HIGH); }
void postTransmissionNPK() { digitalWrite(NPK_RS485_DE_RE_PIN, LOW); }

// ====== HELPER FUNCTIONS ======
float soilPercentFromRaw(int raw) {
  if (SOIL_RAW_WATER > SOIL_RAW_AIR) {
    int t = SOIL_RAW_WATER;
    SOIL_RAW_WATER = SOIL_RAW_AIR;
    SOIL_RAW_AIR = t;
  }
  if (raw < SOIL_RAW_WATER) raw = SOIL_RAW_WATER;
  if (raw > SOIL_RAW_AIR) raw = SOIL_RAW_AIR;
  float pct = 100.0f * (float)(SOIL_RAW_AIR - raw) / (float)(SOIL_RAW_AIR - SOIL_RAW_WATER);
  return constrain(pct, 0, 100);
}

int readSoilRawAveraged(uint8_t samples = 10) {
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);
  long sum = 0;
  for (uint8_t i = 0; i < samples; i++) {
    sum += analogRead(SOIL_PIN);
    delay(5);
  }
  return (int)(sum / samples);
}

bool beginBH1750() {
  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE, 0x23, &Wire)) return true;
  if (lightMeter.begin(BH1750::CONTINUOUS_HIGH_RES_MODE, 0x5C, &Wire)) return true;
  return false;
}

// ✅ FIXED: Check if time is properly synced
bool isTimeSynced() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return false;
  }
  
  // Check if year is reasonable (not 1970 or before 2020)
  int year = timeinfo.tm_year + 1900;
  return (year >= 2020 && year <= 2100);
}

// ✅ FIXED: Sync time with retry and fallback server
void syncTimeWithRetry() {
  Serial.println("⏰ Syncing time with NTP server...");
  
  // Try primary server
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  
  int retry = 0;
  struct tm timeinfo;
  while (!isTimeSynced() && retry < 20) {
    Serial.print(".");
    delay(1000);
    retry++;
    
    // After 10 tries, switch to backup server
    if (retry == 10) {
      Serial.println("\n⚠️ Trying backup NTP server...");
      configTime(gmtOffset_sec, daylightOffset_sec, ntpBackup);
    }
  }
  
  if (isTimeSynced()) {
    getLocalTime(&timeinfo);
    Serial.println("\n✅ Time synced successfully!");
    Serial.print("📅 Philippine Time: ");
    Serial.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");
    Serial.print("📍 Timezone: UTC+8 (Manila)\n");
  } else {
    Serial.println("\n❌ Time sync failed! Timestamps will use millis()");
  }
}

// ✅ FIXED: Proper Philippine Time timestamp
String getTimestamp() {
  if (!isTimeSynced()) {
    // Fallback to millis if time not synced
    return String(millis());
  }
  
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return String(millis());
  }
  
  // Format: 2025-10-29T14:30:45+08:00 (ISO 8601 with PH timezone)
  char buffer[32];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  
  // Append +08:00 for Philippine Time
  return String(buffer) + "+08:00";
}

void checkHeapMemory() {
  uint32_t freeHeap = ESP.getFreeHeap();
  if (freeHeap < 30000) {
    Serial.println("⚠️  Low memory: " + String(freeHeap) + " bytes");
  }
}

void diagnoseWiFi() {
  Serial.println("\n=== 📡 WiFi Diagnostics ===");
  Serial.print("Status: ");
  Serial.println(WiFi.status() == WL_CONNECTED ? "✅ Connected" : "❌ Disconnected");
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("RSSI: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");
  Serial.println("==========================\n");
}

void initWiFi() {
  Serial.println("🌐 Starting WiFi Manager...");
  
  // ✅ ADD THESE TIMEOUTS
  wifiManager.setConnectTimeout(20);       // 20 seconds to connect to saved WiFi
  wifiManager.setConfigPortalTimeout(180); // 3 minutes for config portal
  
  // ✅ ADD DEBUG OUTPUT
  wifiManager.setDebugOutput(true);
  
  // ✅ Show saved WiFi (if exists)
  String savedSSID = WiFi.SSID();
  if (savedSSID.length() > 0) {
    Serial.println("📡 Found saved WiFi: " + savedSSID);
    Serial.println("⏳ Attempting connection (20s timeout)...");
  } else {
    Serial.println("📡 No saved WiFi credentials");
  }

  if (!wifiManager.autoConnect("AgriLeafyShield_Setup", "agrileafy123")) {
    Serial.println("❌ Failed to connect and hit timeout");
    Serial.println("🔄 Restarting ESP32 in 3 seconds...");
    delay(3000);
    ESP.restart();
  }

  Serial.println("✅ WiFi connected!");
  Serial.println("📡 SSID: " + WiFi.SSID());
  Serial.print("📡 IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("📶 Signal Strength: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");

  IPAddress dns1(8, 8, 8, 8);
  IPAddress dns2(8, 8, 4, 4);
  WiFi.config(WiFi.localIP(), WiFi.gatewayIP(), WiFi.subnetMask(), dns1, dns2);

  consecutiveFailures = 0;
  delay(2000);
}

void initFirebase() {
  config.database_url = DATABASE_URL;
  config.api_key = FIREBASE_API_KEY;
  config.token_status_callback = tokenStatusCallback;
  config.timeout.serverResponse = 30000;
  config.timeout.socketConnection = 30000;
  config.timeout.sslHandshake = 30000;
  config.max_token_generation_retry = 5;

  Firebase.reconnectWiFi(true);
  Firebase.begin(&config, &auth);

  if (auth.token.uid.length() == 0) {
    Serial.println("🔐 Signing up anonymously...");
    Firebase.signUp(&config, &auth, "", "");
  }

  Serial.print("🔥 Connecting to Firebase");
  int attempts = 0;
  while (!Firebase.ready() && attempts < 40) {
    Serial.print(".");
    delay(1000);
    attempts++;
    esp_task_wdt_reset();
  }

  firebase_ready = Firebase.ready();

  if (firebase_ready) {
    Serial.println("\n✅ Firebase connected successfully!");
    Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/online", true);
    sendHeartbeat();
    fetchPlantSettings();
  } else {
    Serial.println("\n❌ Firebase connection failed!");
  }
}

void fetchPlantSettings() {
  if (!firebase_ready) return;

  String path = "/devices/" + String(DEVICE_ID) + "/plant_settings";

  Serial.println("🌱 Fetching plant settings from Firebase...");

  if (Firebase.RTDB.getString(&fbdo, path + "/selected_plant")) {
    String newPlant = fbdo.stringData();
    if (newPlant.length() > 0 && newPlant != selectedPlantName) {
      selectedPlantName = newPlant;
      Serial.println("   Plant: " + selectedPlantName);
    }
  }

  if (Firebase.RTDB.getDouble(&fbdo, path + "/min_temperature")) {
    plantMinTemperature = fbdo.doubleData();
  }
  if (Firebase.RTDB.getDouble(&fbdo, path + "/max_temperature")) {
    plantMaxTemperature = fbdo.doubleData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/min_soil_moisture")) {
    plantMinSoilMoisture = fbdo.intData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/max_soil_moisture")) {
    plantMaxSoilMoisture = fbdo.intData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/min_humidity")) {
    plantMinHumidity = fbdo.intData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/max_humidity")) {
    plantMaxHumidity = fbdo.intData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/min_light_intensity")) {
    plantMinLightIntensity = fbdo.intData();
  }
  if (Firebase.RTDB.getInt(&fbdo, path + "/max_light_intensity")) {
    plantMaxLightIntensity = fbdo.intData();
  }

  plantSettingsLoaded = true;

  Serial.println("✅ Plant Settings Loaded:");
  Serial.println("   Plant: " + selectedPlantName);
  Serial.println("   Temp: " + String(plantMinTemperature) + "-" + String(plantMaxTemperature) + "°C");
  Serial.println("   Soil: " + String(plantMinSoilMoisture) + "-" + String(plantMaxSoilMoisture) + "%");
  Serial.println("   Humidity: " + String(plantMinHumidity) + "-" + String(plantMaxHumidity) + "%");
  Serial.println("   Light: " + String(plantMinLightIntensity) + "-" + String(plantMaxLightIntensity) + " lux\n");
}

void analyzeSoilNutrients() {
  if (!npkSensorConnected) return;

  const float OPTIMAL_N_MIN = 150, OPTIMAL_N_MAX = 250;
  const float OPTIMAL_P_MIN = 40, OPTIMAL_P_MAX = 80;
  const float OPTIMAL_K_MIN = 200, OPTIMAL_K_MAX = 300;

  bool needsNitrogen = (currentNPKN < OPTIMAL_N_MIN);
  bool needsPhosphorus = (currentNPKP < OPTIMAL_P_MIN);
  bool needsPotassium = (currentNPKK < OPTIMAL_K_MIN);

  int severityLevel = needsNitrogen + needsPhosphorus + needsPotassium;

  if (severityLevel > 0) {
    Serial.println("\n🧪 FERTILIZER RECOMMENDATION:");
    String rec = "Apply: ";
    if (needsNitrogen) rec += "Urea/Compost (N↑) ";
    if (needsPhosphorus) rec += "Bone Meal (P↑) ";
    if (needsPotassium) rec += "Wood Ash (K↑)";
    Serial.println("   " + rec);
    Serial.println("   Severity: " + String(severityLevel) + "/3");
  }
}

void assessDiseaseRisk() {
  if (!tempSensorConnected || !humiditySensorConnected) return;

  int fungalRisk = 0;
  int bacterialRisk = 0;
  int pestRisk = 0;
  String warnings = "";

  if (currentHumidity > 85 && currentTemperature > 20 && currentTemperature < 30) {
    fungalRisk = 80;
    warnings += "⚠️ HIGH FUNGAL RISK! Increase ventilation. ";
  } else if (currentHumidity > 75) {
    fungalRisk = 50;
  }

  if (currentHumidity > 90 && currentTemperature > 28) {
    bacterialRisk = 70;
    warnings += "⚠️ Bacterial soft rot possible. ";
  }

  if (currentTemperature > 24 && currentTemperature < 30 && currentHumidity < 70) {
    pestRisk = 60;
    warnings += "Monitor for aphids/whiteflies. ";
  }

  if (fungalRisk > 50 || bacterialRisk > 50 || pestRisk > 50) {
    Serial.println("\n⚠️  DISEASE RISK ALERT:");
    Serial.println("   Fungal: " + String(fungalRisk) + "%");
    Serial.println("   Bacterial: " + String(bacterialRisk) + "%");
    Serial.println("   Pest: " + String(pestRisk) + "%");
    Serial.println("   " + warnings);
  }
}

void autoControlShade() {
  if (currentMode != "auto") return;
  if (!tempSensorConnected || !bh1750_ok) return;

  bool tempHigh = (currentTemperature > plantMaxTemperature);
  bool lightHigh = (currentLightLevel > plantMaxLightIntensity);

  if ((tempHigh || lightHigh) && !shadeDeployed && !isShadeMoving) {
    Serial.println("🌡️ Auto-deploying shade:");
    Serial.println("   Temp: " + String(currentTemperature) + "°C (Max: " + String(plantMaxTemperature) + "°C)");
    Serial.println("   Light: " + String(currentLightLevel) + " lux (Max: " + String(plantMaxLightIntensity) + " lux)");
    controlShade("deploy");
  }
  else if (!tempHigh && !lightHigh && shadeDeployed && !isShadeMoving) {
    Serial.println("✅ Auto-retracting shade (Conditions optimal)");
    controlShade("retract");
  }
}

void autoControlIrrigation() {
  if (currentMode != "auto") return;
  if (pumpMode != "soil") return;
  if (!analog_soil_sensor_is_connected) return;
  if (isPumpRunning) return;

  if (currentWaterPercent < waterLevelLowThreshold) return;
  if (millis() < extendedCooldownUntil) return;
  if (millis() - lastPumpStopTime < PUMP_REST_PERIOD) return;

  if (soilPercent < plantMinSoilMoisture) {
    Serial.println("💧 Auto-starting irrigation:");
    Serial.println("   Current: " + String(soilPercent) + "% < Min: " + String(plantMinSoilMoisture) + "%");
    lastSoilBeforeIrrigation = soilPercent;
    controlPump("irrigation", "start");
  }
}

void autoControlMisting() {
  if (currentMode != "auto") return;
  if (pumpMode != "humidity") return;
  if (!humiditySensorConnected) return;
  if (isPumpRunning) return;

  if (currentWaterPercent < waterLevelLowThreshold) return;
  if (millis() < extendedCooldownUntil) return;
  if (millis() - lastPumpStopTime < PUMP_REST_PERIOD) return;

  if (currentHumidity < plantMinHumidity) {
    Serial.println("💨 Auto-starting misting:");
    Serial.println("   Current: " + String(currentHumidity) + "% < Min: " + String(plantMinHumidity) + "%");
    lastHumidityBeforeMisting = currentHumidity;
    controlPump("misting", "start");
  }
}

void controlPump(String mode, String action) {
  if (action == "start") {
    if (currentWaterPercent < waterLevelLowThreshold) {
      Serial.println("⚠️  WATER LOW (" + String(currentWaterPercent) + "%) - Cannot start!");
      return;
    }
    if (isPumpRunning) {
      Serial.println("⚠️  Pump already running in " + currentPumpMode + " mode");
      return;
    }
    if (millis() - lastPumpStopTime < PUMP_REST_PERIOD) {
      Serial.println("⏳ Pump cooling down...");
      return;
    }

    if (millis() < extendedCooldownUntil) {
      unsigned long remaining = (extendedCooldownUntil - millis()) / 60000;
      Serial.println("⏳ Extended cooldown: " + String(remaining) + " min remaining");
      return;
    }

    currentPumpMode = mode;
    isPumpRunning = true;
    pumpStartTime = millis();

    if (mode == "irrigation") {
      digitalWrite(PUMP_PIN_1, HIGH);
      Serial.println("💧 IRRIGATION STARTED (" + String(IRRIGATION_DURATION/1000) + "s)");
    } else if (mode == "misting") {
      digitalWrite(PUMP_PIN_2, HIGH);
      Serial.println("💨 MISTING STARTED (" + String(MISTING_DURATION/1000) + "s)");
    }

    if (firebase_ready) {
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/pump_running", true);
      Firebase.RTDB.setString(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/current_pump_mode", currentPumpMode);
    }
  }
  else if (action == "stop") {
    if (!isPumpRunning) return;

    digitalWrite(PUMP_PIN_1, LOW);
    digitalWrite(PUMP_PIN_2, LOW);

    unsigned long runtime = millis() - pumpStartTime;

    if (currentPumpMode == "irrigation") {
      totalIrrigationRuntime += runtime / 1000;
      irrigationCycleCount++;

      if (!isnan(lastSoilBeforeIrrigation) && !isnan(soilPercent)) {
        float improvement = soilPercent - lastSoilBeforeIrrigation;

        if (improvement < 5.0) {
          extendedCooldownUntil = millis() + EXTENDED_COOLDOWN;
          Serial.println("⚠️ Soil barely improved (+" + String(improvement) + "%)");
          Serial.println("🔒 EXTENDED COOLDOWN: 30 minutes");
        } else {
          Serial.println("✅ Soil improved by +" + String(improvement) + "%");
        }
      }

      Serial.println("💧 IRRIGATION STOPPED (Runtime: " + String(runtime/1000) + "s)");
    }
    else if (currentPumpMode == "misting") {
      totalMistingRuntime += runtime / 1000;
      mistingCycleCount++;

      if (!isnan(lastHumidityBeforeMisting) && !isnan(currentHumidity)) {
        float improvement = currentHumidity - lastHumidityBeforeMisting;

        if (improvement < 5.0) {
          extendedCooldownUntil = millis() + EXTENDED_COOLDOWN;
          Serial.println("⚠️ Humidity barely improved (+" + String(improvement) + "%)");
          Serial.println("🔒 EXTENDED COOLDOWN: 30 minutes");
        } else {
          Serial.println("✅ Humidity improved by +" + String(improvement) + "%");
        }
      }

      Serial.println("💨 MISTING STOPPED (Runtime: " + String(runtime/1000) + "s)");
    }

    isPumpRunning = false;
    currentPumpMode = "none";
    lastPumpStopTime = millis();

    if (firebase_ready) {
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/pump_running", false);
      Firebase.RTDB.setString(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/current_pump_mode", "none");
      Firebase.RTDB.setInt(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/irrigation_runtime_sec", totalIrrigationRuntime);
      Firebase.RTDB.setInt(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/irrigation_cycles", irrigationCycleCount);
      Firebase.RTDB.setInt(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/misting_runtime_sec", totalMistingRuntime);
      Firebase.RTDB.setInt(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/misting_cycles", mistingCycleCount);
    }
  }
}

void controlShade(String action) {
  if (isShadeMoving) {
    Serial.println("⚠️  Shade motor already moving");
    return;
  }

  if (action == "deploy" && !shadeDeployed) {
    digitalWrite(SHADE_MOTOR_PIN_1, HIGH);
    digitalWrite(SHADE_MOTOR_PIN_2, LOW);
    isShadeMoving = true;
    shadeMotorStartTime = millis();
    Serial.println("☂️  Deploying shade...");

    if (firebase_ready) {
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/shade_deployed", true);
    }
  }
  else if (action == "retract" && shadeDeployed) {
    digitalWrite(SHADE_MOTOR_PIN_1, LOW);
    digitalWrite(SHADE_MOTOR_PIN_2, HIGH);
    isShadeMoving = true;
    shadeMotorStartTime = millis();
    Serial.println("☀️  Retracting shade...");

    if (firebase_ready) {
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/shade_deployed", false);
    }
  }
}

void stopShadeMotor() {
  if (!isShadeMoving) return;

  if (millis() - shadeMotorStartTime >= SHADE_MOTOR_DURATION) {
    digitalWrite(SHADE_MOTOR_PIN_1, LOW);
    digitalWrite(SHADE_MOTOR_PIN_2, LOW);
    isShadeMoving = false;
    shadeDeployed = !shadeDeployed;
    Serial.println("✅ Shade motor stopped");
  }
}

void readXYMD02Sensor() {
  uint8_t result = modbus_node_XYMD02.readHoldingRegisters(0x0000, 2);

  if (result == modbus_node_XYMD02.ku8MBSuccess) {
    uint16_t rawHumidity = modbus_node_XYMD02.getResponseBuffer(0);
    uint16_t rawTemperature = modbus_node_XYMD02.getResponseBuffer(1);

    float newTemp = rawTemperature / 10.0;
    float newHumidity = rawHumidity / 10.0;

    if (newTemp > -40 && newTemp < 80) {
      if (isnan(temperatureFiltered)) {
        temperatureFiltered = newTemp;
      } else {
        temperatureFiltered = (alpha * newTemp) + ((1.0 - alpha) * temperatureFiltered);
      }
      currentTemperature = temperatureFiltered;
      tempSensorConnected = true;
    }

    if (newHumidity >= 0 && newHumidity <= 100) {
      if (isnan(humidityFiltered)) {
        humidityFiltered = newHumidity;
      } else {
        humidityFiltered = (alpha * newHumidity) + ((1.0 - alpha) * humidityFiltered);
      }
      currentHumidity = humidityFiltered;
      humiditySensorConnected = true;
    }
  } else {
    tempSensorConnected = false;
    humiditySensorConnected = false;
  }
}

void readNPKSensor() {
  uint8_t result = modbus_node_NPK.readHoldingRegisters(0x001E, 3);

  if (result == modbus_node_NPK.ku8MBSuccess) {
    currentNPKN = modbus_node_NPK.getResponseBuffer(0);
    currentNPKP = modbus_node_NPK.getResponseBuffer(1);
    currentNPKK = modbus_node_NPK.getResponseBuffer(2);
    npkSensorConnected = true;
  } else {
    npkSensorConnected = false;
    currentNPKN = NAN;
    currentNPKP = NAN;
    currentNPKK = NAN;
  }
}

void readWaterLevelSensor() {
  digitalWrite(WATER_TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(WATER_TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(WATER_TRIG_PIN, LOW);

  long duration = pulseIn(WATER_ECHO_PIN, HIGH, 30000);

  if (duration > 0) {
    float distance = duration * 0.034 / 2.0;

    if (distance > 0 && distance < 200) {
      currentWaterDistance = distance;
      currentWaterLevel = TANK_HEIGHT - distance;
      currentWaterPercent = (currentWaterLevel / TANK_HEIGHT) * 100.0;
      currentWaterPercent = constrain(currentWaterPercent, 0, 100);
      waterLevelSensorConnected = true;
    } else {
      waterLevelSensorConnected = false;
    }
  } else {
    waterLevelSensorConnected = false;
  }
}

void readAndSendSensorData() {
  if (!firebase_ready) return;

  currentSoilRaw = readSoilRawAveraged();
  soilPercent = soilPercentFromRaw(currentSoilRaw);
  analog_soil_sensor_is_connected = (currentSoilRaw > 0);

  if (bh1750_ok) {
    currentLightLevel = lightMeter.readLightLevel();
  }

  readXYMD02Sensor();
  readNPKSensor();
  readWaterLevelSensor();

  analyzeSoilNutrients();
  assessDiseaseRisk();

  String basePath = "/devices/" + String(DEVICE_ID) + "/sensor_data";
  String timestamp = getTimestamp();

  Firebase.RTDB.setString(&fbdo, basePath + "/timestamp", timestamp);

  if (tempSensorConnected) {
    Firebase.RTDB.setDouble(&fbdo, basePath + "/temperature", currentTemperature);
  }
  if (humiditySensorConnected) {
    Firebase.RTDB.setInt(&fbdo, basePath + "/humidity", (int)currentHumidity);
  }
  if (analog_soil_sensor_is_connected) {
    Firebase.RTDB.setInt(&fbdo, basePath + "/soil", (int)soilPercent);
  }
  if (bh1750_ok) {
    Firebase.RTDB.setInt(&fbdo, basePath + "/light", (int)currentLightLevel);
  }
  if (npkSensorConnected) {
    Firebase.RTDB.setInt(&fbdo, basePath + "/nitrogen", (int)currentNPKN);
    Firebase.RTDB.setInt(&fbdo, basePath + "/phosphorus", (int)currentNPKP);
    Firebase.RTDB.setInt(&fbdo, basePath + "/potassium", (int)currentNPKK);
  }
  if (waterLevelSensorConnected) {
    Firebase.RTDB.setInt(&fbdo, basePath + "/water_percent", currentWaterPercent);
    Firebase.RTDB.setDouble(&fbdo, basePath + "/water_level", currentWaterLevel);
    Firebase.RTDB.setDouble(&fbdo, basePath + "/water_distance", currentWaterDistance);
  }

  Firebase.RTDB.setBool(&fbdo, basePath + "/sensor_status/temperature_connected", tempSensorConnected);
  Firebase.RTDB.setBool(&fbdo, basePath + "/sensor_status/humidity_connected", humiditySensorConnected);
  Firebase.RTDB.setBool(&fbdo, basePath + "/sensor_status/soil_connected", analog_soil_sensor_is_connected);
  Firebase.RTDB.setBool(&fbdo, basePath + "/sensor_status/light_connected", bh1750_ok);
  Firebase.RTDB.setBool(&fbdo, basePath + "/sensor_status/water_level_connected", waterLevelSensorConnected);

  String statusPath = "/devices/" + String(DEVICE_ID) + "/status";
  Firebase.RTDB.setInt(&fbdo, statusPath + "/wifi_rssi", WiFi.RSSI());
  Firebase.RTDB.setInt(&fbdo, statusPath + "/free_heap", ESP.getFreeHeap());
  Firebase.RTDB.setInt(&fbdo, statusPath + "/uptime_ms", millis());
  Firebase.RTDB.setString(&fbdo, statusPath + "/mode", currentMode);
  Firebase.RTDB.setString(&fbdo, statusPath + "/pump_mode", pumpMode);
  Firebase.RTDB.setString(&fbdo, statusPath + "/current_pump_mode", currentPumpMode);
  Firebase.RTDB.setBool(&fbdo, statusPath + "/shade_deployed", shadeDeployed);
  Firebase.RTDB.setBool(&fbdo, statusPath + "/pump_running", isPumpRunning);
  Firebase.RTDB.setInt(&fbdo, statusPath + "/irrigation_runtime_sec", totalIrrigationRuntime);
  Firebase.RTDB.setInt(&fbdo, statusPath + "/irrigation_cycles", irrigationCycleCount);
  Firebase.RTDB.setInt(&fbdo, statusPath + "/misting_runtime_sec", totalMistingRuntime);
  Firebase.RTDB.setInt(&fbdo, statusPath + "/misting_cycles", mistingCycleCount);

  Serial.println("📤 Sensor data sent to Firebase");
}

void sendHeartbeat() {
  if (!firebase_ready) return;

  String timestamp = getTimestamp();
  
  Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/online", true);
  Firebase.RTDB.setString(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/timestamp", timestamp);
  Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/wifi_connected", WiFi.status() == WL_CONNECTED);
  Firebase.RTDB.setInt(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/wifi_rssi", WiFi.RSSI());
  Firebase.RTDB.setString(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/current_mode", currentMode);
  Firebase.RTDB.setString(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/pump_mode", pumpMode);
  Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/shade_deployed", shadeDeployed);
}

void checkCommands() {
  if (!firebase_ready) return;

  String basePath = "/devices/" + String(DEVICE_ID);

  // ✅ Check for new plant selection
  if (Firebase.RTDB.getString(&fbdo, basePath + "/plant_settings/selected_plant")) {
    String newPlant = fbdo.stringData();
    if (newPlant.length() > 0 && newPlant != selectedPlantName) {
      Serial.println("🌱 New plant selected: " + newPlant);
      fetchPlantSettings();
    }
  }

  // ✅ Check for mode changes (auto/manual)
  if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/mode")) {
    String mode = fbdo.stringData();
    if (mode == "auto" || mode == "manual") {
      if (mode != currentMode) {
        currentMode = mode;
        Serial.println("🔄 Mode changed to: " + currentMode);
        Firebase.RTDB.setString(&fbdo, basePath + "/status/current_mode", currentMode);
        Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/mode");
      }
    }
  }

  // ✅ Check for pump mode changes (soil/humidity)
  if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/pump_mode")) {
    String mode = fbdo.stringData();
    if (mode == "soil" || mode == "humidity") {
      if (mode != pumpMode) {
        pumpMode = mode;
        Serial.println("🔄 Pump mode changed to: " + pumpMode);
        Firebase.RTDB.setString(&fbdo, basePath + "/status/pump_mode", pumpMode);
        Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/pump_mode");
      }
    }
  }

  // ✅ Check for pump commands
  if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/pump_command")) {
    String cmd = fbdo.stringData();
    Serial.println("📥 Pump command: " + cmd);

    if (cmd == "irrigation_start") {
      controlPump("irrigation", "start");
    } else if (cmd == "irrigation_stop") {
      controlPump("irrigation", "stop");
    } else if (cmd == "misting_start") {
      controlPump("misting", "start");
    } else if (cmd == "misting_stop") {
      controlPump("misting", "stop");
    }

    Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/pump_command");
  }

  // ✅ Check for shade commands
  if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/shade_command")) {
    String cmd = fbdo.stringData();
    Serial.println("📥 Shade command: " + cmd);
    controlShade(cmd);
    Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/shade_command");
  }

  // ✅✅✅ UPDATED SYSTEM COMMANDS - SUPPORTS BOTH OBJECT AND STRING ✅✅✅
  
  // TRY READING AS OBJECT FIRST (new format with timestamp)
  if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/system_command/command")) {
    String cmd = fbdo.stringData();
    
    // Static variable to track last processed timestamp
    static String lastTimestamp = "";
    
    // Check if this is a new command by reading timestamp
    if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/system_command/timestamp")) {
      String currentTimestamp = fbdo.stringData();
      
      // Only process if timestamp is different (new command)
      if (currentTimestamp != lastTimestamp) {
        lastTimestamp = currentTimestamp;
        
        Serial.println("📥 System command (object): " + cmd);
        Serial.println("   Timestamp: " + currentTimestamp);
        
        if (cmd == "restart") {
          Serial.println("🔄 RESTARTING ESP32...");
          Serial.println("   WiFi credentials: PRESERVED");
          
          // Mark as executed
          Firebase.RTDB.setString(&fbdo, basePath + "/commands/system_command/status", "executed");
          Firebase.RTDB.setBool(&fbdo, basePath + "/status/online", false);
          
          delay(1000);
          ESP.restart();
        }
        else if (cmd == "factory_reset") {
          Serial.println("🔥🔥🔥 FACTORY RESET! 🔥🔥🔥");
          Serial.println("   ⚠️  CLEARING WIFI CREDENTIALS!");
          
          // Mark as executed
          Firebase.RTDB.setString(&fbdo, basePath + "/commands/system_command/status", "executed");
          Firebase.RTDB.setBool(&fbdo, basePath + "/status/online", false);
          
          delay(1000);
          
          // ✅ CLEAR WIFI CREDENTIALS
          wifiManager.resetSettings();
          
          Serial.println("✅ WiFi credentials cleared!");
          Serial.println("📡 Device will restart in config mode");
          Serial.println("📡 Connect to: AgriLeafyShield_Setup");
          Serial.println("🔑 Password: agrileafy123");
          
          delay(2000);
          ESP.restart();
        }
      } else {
        // Same timestamp = already processed, ignore
        Serial.println("⏭️  Skipping duplicate system command");
      }
    }
  }
  // FALLBACK: Check if system_command is a simple string (backwards compatibility)
  else if (Firebase.RTDB.getString(&fbdo, basePath + "/commands/system_command")) {
    String cmd = fbdo.stringData();
    
    // Only process if it's a valid string command (not an object)
    if (cmd == "restart" || cmd == "factory_reset") {
      Serial.println("📥 System command (string): " + cmd);
      
      if (cmd == "restart") {
        Serial.println("🔄 RESTARTING ESP32...");
        Serial.println("   WiFi credentials: PRESERVED");
        
        Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/system_command");
        Firebase.RTDB.setBool(&fbdo, basePath + "/status/online", false);
        
        delay(1000);
        ESP.restart();
      }
      else if (cmd == "factory_reset") {
        Serial.println("🔥🔥🔥 FACTORY RESET! 🔥🔥🔥");
        Serial.println("   ⚠️  CLEARING WIFI CREDENTIALS!");
        
        Firebase.RTDB.deleteNode(&fbdo, basePath + "/commands/system_command");
        Firebase.RTDB.setBool(&fbdo, basePath + "/status/online", false);
        
        delay(1000);
        
        // ✅ CLEAR WIFI CREDENTIALS
        wifiManager.resetSettings();
        
        Serial.println("✅ WiFi credentials cleared!");
        Serial.println("📡 Device will restart in config mode");
        Serial.println("📡 Connect to: AgriLeafyShield_Setup");
        Serial.println("🔑 Password: agrileafy123");
        
        delay(2000);
        ESP.restart();
      }
    }
  }
}

void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED) {
    if (firebase_ready) {
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/online", false);
      Firebase.RTDB.setBool(&fbdo, "/devices/" + String(DEVICE_ID) + "/status/wifi_connected", false);
    }
    
    Serial.println("⚠️  WiFi disconnected! Reconnecting...");
    consecutiveFailures++;

    if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
      Serial.println("🔄 Multiple failures, restarting ESP32...");
      delay(1000);
      ESP.restart();
    }

    WiFi.reconnect();
    wifiReconnecting = true;
  } else {
    if (wifiReconnecting) {
      Serial.println("✅ WiFi reconnected!");
      wifiReconnecting = false;
      
      // Re-sync time after WiFi reconnection
      syncTimeWithRetry();
      
      if (firebase_ready) {
        sendHeartbeat();
      }
    }
    consecutiveFailures = 0;
  }
}

void setup() {
  Serial.begin(115200);
  delay(2000);

  Serial.println("\n\n");
  Serial.println("╔════════════════════════════════════╗");
  Serial.println("║   AGRI-LEAFY SHIELD STARTING...   ║");
  Serial.println("║   ESP32 Plant Monitoring System   ║");
  Serial.println("╚════════════════════════════════════╝");
  Serial.println();

  // wifiManager.resetSettings();
  // Serial.println("🔥 WiFi credentials cleared! Will enter setup mode...");
  // delay(2000);
  esp_task_wdt_init(30, true);
  esp_task_wdt_add(NULL);

  pinMode(SHADE_MOTOR_PIN_1, OUTPUT);
  pinMode(SHADE_MOTOR_PIN_2, OUTPUT);
  pinMode(PUMP_PIN_1, OUTPUT);
  pinMode(PUMP_PIN_2, OUTPUT);
  pinMode(WATER_TRIG_PIN, OUTPUT);
  pinMode(WATER_ECHO_PIN, INPUT);
  pinMode(XYMD02_RS485_DE_RE_PIN, OUTPUT);
  pinMode(NPK_RS485_DE_RE_PIN, OUTPUT);

  digitalWrite(SHADE_MOTOR_PIN_1, LOW);
  digitalWrite(SHADE_MOTOR_PIN_2, LOW);
  digitalWrite(PUMP_PIN_1, LOW);
  digitalWrite(PUMP_PIN_2, LOW);
  digitalWrite(XYMD02_RS485_DE_RE_PIN, LOW);
  digitalWrite(NPK_RS485_DE_RE_PIN, LOW);

  Wire.begin(I2C_SDA, I2C_SCL);
  delay(100);

  Serial.print("🌞 Initializing BH1750 Light Sensor... ");
  bh1750_ok = beginBH1750();
  Serial.println(bh1750_ok ? "✅ Connected" : "❌ Not found");

  Serial.print("🌡️  Initializing XYMD02 (Temp/Humidity)... ");
  SerialRS485.begin(4800, SERIAL_8N1, XYMD02_RS485_RXD, XYMD02_RS485_TXD);
  modbus_node_XYMD02.begin(XYMD02_SLAVE_ID, SerialRS485);
  modbus_node_XYMD02.preTransmission(preTransmissionXYMD02);
  modbus_node_XYMD02.postTransmission(postTransmissionXYMD02);
  Serial.println("✅ Initialized");

  Serial.print("🧪 Initializing NPK Sensor... ");
  SerialNPK.begin(4800, SERIAL_8N1, NPK_RS485_RXD, NPK_RS485_TXD);
  modbus_node_NPK.begin(NPK_SLAVE_ID, SerialNPK);
  modbus_node_NPK.preTransmission(preTransmissionNPK);
  modbus_node_NPK.postTransmission(postTransmissionNPK);
  Serial.println("✅ Initialized");

  initWiFi();

// ✅ FIXED: Sync time with improved retry
  syncTimeWithRetry();

  initFirebase();

  diagnoseWiFi();

  Serial.println("\n✅ SETUP COMPLETE - System ready!\n");
}

void loop() {
  esp_task_wdt_reset();

  unsigned long currentMillis = millis();

  if (currentMillis - lastWiFiCheck >= WIFI_CHECK_INTERVAL) {
    checkWiFiConnection();
    lastWiFiCheck = currentMillis;
  }

  if (!firebase_ready && WiFi.status() == WL_CONNECTED) {
    Serial.println("🔄 Attempting Firebase reconnection...");
    initFirebase();
  }

  if (currentMillis - lastUpdate >= UPDATE_INTERVAL) {
    readAndSendSensorData();
    lastUpdate = currentMillis;
  }

  if (currentMillis - lastHeartbeat >= HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = currentMillis;
  }

  checkCommands();

  if (currentMode == "auto") {
    autoControlShade();
    autoControlIrrigation();
    autoControlMisting();
  }

  stopShadeMotor();

  if (isPumpRunning) {
    unsigned long runtime = currentMillis - pumpStartTime;
    unsigned long maxDuration = (currentPumpMode == "irrigation") ? IRRIGATION_DURATION : MISTING_DURATION;

    if (runtime >= maxDuration) {
      controlPump(currentPumpMode, "stop");
    }
  }

  checkHeapMemory();

  // ✅ ENHANCED: Check time sync every 5 minutes and re-sync if needed
  static unsigned long lastTimeCheck = 0;
  if (currentMillis - lastTimeCheck > 300000) {  // Every 5 minutes
    if (!isTimeSynced()) {
      Serial.println("⚠️ Time sync lost! Re-syncing...");
      syncTimeWithRetry();
    } else {
      struct tm timeinfo;
      if (getLocalTime(&timeinfo)) {
        Serial.print("🕐 PH Time: ");
        Serial.println(&timeinfo, "%Y-%m-%d %H:%M:%S");
      }
    }
    lastTimeCheck = currentMillis;
  }

  delay(100);
}