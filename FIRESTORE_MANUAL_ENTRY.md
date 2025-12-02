# 📝 Manual Entry Guide for Firestore Daily Summaries

## Collection Path
```
daily_summaries/ESP32_ALS_001/summaries/{date-key}
```

## Date Key Format
Use format: `YYYY-MM-DD` (example: `2025-10-16`)

---

## 📋 Document Structure (JSON Format)

Copy this template and paste sa Firestore Console:

```json
{
  "deviceId": "ESP32_ALS_001",
  "date": "2025-10-16T00:00:00.000Z",
  "readingsCount": 0,
  "temperature": {
    "min": 18.5,
    "max": 32.0
  },
  "soilMoisture": {
    "min": 45,
    "max": 75
  },
  "humidity": {
    "min": 50,
    "max": 85
  },
  "lightIntensity": {
    "min": 0,
    "max": 55000
  },
  "nitrogen": {
    "min": 40,
    "max": 80
  },
  "phosphorus": {
    "min": 25,
    "max": 45
  },
  "potassium": {
    "min": 60,
    "max": 110
  },
  "waterPercent": {
    "min": 40,
    "max": 90
  },
  "createdAt": "2025-10-16T12:00:00.000Z"
}
```

---

## 🎯 Step-by-Step: How to Add Data sa Firestore Console

### Step 1: Open Firestore Console
1. Go to Firebase Console: https://console.firebase.google.com
2. Select project: **agri-leafy**
3. Click **Firestore Database** sa left menu

### Step 2: Navigate to Collection
```
daily_summaries → ESP32_ALS_001 → summaries
```

### Step 3: Add Document
1. Click **"Add document"** button
2. **Document ID**: Use date format `2025-10-16`
3. Click **"Field"** to add fields manually OR
4. Click **"JSON mode"** to paste the template above

### Step 4: Fill in Fields

#### Required Fields:
- **deviceId** (string): `"ESP32_ALS_001"`
- **date** (timestamp): Select date picker, choose October 16, 2025
- **readingsCount** (number): `0` (if manual entry)

#### Sensor Data (object):
For each sensor, add an **object** with **min** and **max** only:

**Example for temperature:**
```
temperature (map):
  ├─ min (number): 18.5
  └─ max (number): 32.0
```

#### All Available Sensors:
- `temperature` → min & max (number, in °C)
- `soilMoisture` → min & max (integer, 0-100%)
- `humidity` → min & max (integer, 0-100%)
- `lightIntensity` → min & max (integer, in lux)
- `nitrogen` → min & max (integer, mg/kg)
- `phosphorus` → min & max (integer, mg/kg)
- `potassium` → min & max (integer, mg/kg)
- `waterPercent` → min & max (integer, 0-100%)

#### Optional:
- **createdAt** (timestamp): Current time

---

## 📊 Example: October 16, 2025 Entry

### Using Firestore Console (Field by Field):

1. **Document ID**: `2025-10-16`

2. **Add these fields:**

| Field | Type | Value |
|-------|------|-------|
| deviceId | string | ESP32_ALS_001 |
| date | timestamp | Oct 16, 2025 00:00:00 |
| readingsCount | number | 0 |

3. **Add temperature object:**
   - Field name: `temperature`
   - Type: `map`
   - Add subfields:
     - `min` (number): `19.0`
     - `max` (number): `31.5`

4. **Add soilMoisture object:**
   - Field name: `soilMoisture`
   - Type: `map`
   - Add subfields:
     - `min` (number): `48`
     - `max` (number): `72`

5. **Add humidity object:**
   - Field name: `humidity`
   - Type: `map`
   - Add subfields:
     - `min` (number): `55`
     - `max` (number): `82`

6. **Add lightIntensity object:**
   - Field name: `lightIntensity`
   - Type: `map`
   - Add subfields:
     - `min` (number): `0`
     - `max` (number): `52000`

7. **Repeat for other sensors** (nitrogen, phosphorus, potassium, waterPercent)

---

## 🎨 Calendar Display

Based on **temperature.max** or **temperature.min** average:

- **🔵 Blue** (Cool): < 20°C
- **🟢 Green** (Optimal): 20-30°C
- **🔴 Red** (Hot): > 30°C

Example:
- If max = 31.5°C → Red (Hot day)
- If max = 25.0°C → Green (Optimal)
- If max = 18.0°C → Blue (Cool)

---

## ⚡ Quick Copy-Paste Templates

### Cool Day (< 20°C)
```json
{
  "deviceId": "ESP32_ALS_001",
  "date": "2025-10-16T00:00:00.000Z",
  "readingsCount": 0,
  "temperature": {"min": 15.0, "max": 19.0},
  "soilMoisture": {"min": 60, "max": 80},
  "humidity": {"min": 70, "max": 90},
  "lightIntensity": {"min": 0, "max": 45000},
  "nitrogen": {"min": 50, "max": 75},
  "phosphorus": {"min": 30, "max": 45},
  "potassium": {"min": 70, "max": 100}
}
```

### Optimal Day (20-30°C)
```json
{
  "deviceId": "ESP32_ALS_001",
  "date": "2025-10-16T00:00:00.000Z",
  "readingsCount": 0,
  "temperature": {"min": 22.0, "max": 28.0},
  "soilMoisture": {"min": 55, "max": 70},
  "humidity": {"min": 60, "max": 75},
  "lightIntensity": {"min": 5000, "max": 55000},
  "nitrogen": {"min": 55, "max": 80},
  "phosphorus": {"min": 32, "max": 48},
  "potassium": {"min": 75, "max": 105}
}
```

### Hot Day (> 30°C)
```json
{
  "deviceId": "ESP32_ALS_001",
  "date": "2025-10-16T00:00:00.000Z",
  "readingsCount": 0,
  "temperature": {"min": 28.0, "max": 35.0},
  "soilMoisture": {"min": 40, "max": 60},
  "humidity": {"min": 45, "max": 65},
  "lightIntensity": {"min": 10000, "max": 60000},
  "nitrogen": {"min": 45, "max": 70},
  "phosphorus": {"min": 28, "max": 42},
  "potassium": {"min": 65, "max": 95}
}
```

---

## 🔥 Important Notes

1. **Date field** must be a Firestore **Timestamp** type
2. **Document ID** should match the date: `YYYY-MM-DD` format
3. **Only min and max** are required - no avg needed!
4. You can skip sensors you don't have data for
5. Real-time sync will show changes immediately in the app
6. Calendar color is based on temperature values

---

## 📱 After Adding Data

1. Open your Flutter app
2. Go to Calendar page
3. Navigate to October 2025
4. You should see October 16 with a color (based on temperature)
5. Tap the date to see the detailed min/max values

---

## ❓ Troubleshooting

**Q: Data not showing in calendar?**
- Check document ID format: must be `YYYY-MM-DD`
- Check date field: must be Firestore Timestamp
- Check deviceId: must be `ESP32_ALS_001`

**Q: Wrong color on calendar?**
- Check temperature.max value
- Blue: max < 20°C
- Green: max 20-30°C
- Red: max > 30°C

**Q: Can I add data for past dates?**
- Yes! Just change the date field to any date you want

---

## 🎯 Quick Test

Add this to test immediately:

**Document ID**: `2025-10-16`

**Copy-paste this JSON**:
```json
{
  "deviceId": "ESP32_ALS_001",
  "date": "2025-10-16T00:00:00.000Z",
  "readingsCount": 0,
  "temperature": {"min": 25, "max": 30},
  "createdAt": "2025-10-16T12:00:00.000Z"
}
```

Save → Open app → Go to October 2025 → Should see October 16 in GREEN! 🟢
