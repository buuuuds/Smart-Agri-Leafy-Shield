// lib/utils/test_data_generator.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class TestDataGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  static const String DEVICE_ID = 'ESP32_ALS_001';

  final Random _random = Random();

  /// Generate random sensor readings for the past N days
  Future<int> generatePastWeekData({int daysBack = 7}) async {
    try {
      debugPrint('🔄 Starting test data generation for past $daysBack days...');

      int totalReadings = 0;

      for (int day = daysBack - 1; day >= 0; day--) {
        final date = DateTime.now().subtract(Duration(days: day));
        final readingsForDay = await _generateReadingsForDay(date);
        totalReadings += readingsForDay;

        debugPrint('✅ Generated $readingsForDay readings for ${date.toString().split(' ')[0]}');
      }

      debugPrint('✅ Total readings generated: $totalReadings');
      debugPrint('📊 Now generating daily summaries...');

      // Generate daily summaries for the generated data
      final summariesCount = await _firestoreService.generateMissingSummaries(
        daysBack: daysBack,
      );

      debugPrint('✅ Generated $summariesCount daily summaries');
      debugPrint('🎉 Test data generation complete!');

      return totalReadings;
    } catch (e) {
      debugPrint('❌ Error generating test data: $e');
      return 0;
    }
  }

  /// Generate readings for a specific day (every 10 minutes = 144 readings per day)
  Future<int> _generateReadingsForDay(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final batch = _firestore.batch();

      int count = 0;

      // Generate reading every 10 minutes (144 readings per day)
      for (int i = 0; i < 144; i++) {
        final timestamp = startOfDay.add(Duration(minutes: i * 10));

        // Only generate if timestamp is in the past
        if (timestamp.isAfter(DateTime.now())) break;

        final reading = _generateRandomReading(timestamp, startOfDay);

        final docRef = _firestore
            .collection('sensor_history')
            .doc(DEVICE_ID)
            .collection('readings')
            .doc();

        batch.set(docRef, reading);
        count++;

        // Commit batch every 500 documents (Firestore limit)
        if (count % 500 == 0) {
          await batch.commit();
        }
      }

      // Commit remaining
      if (count % 500 != 0) {
        await batch.commit();
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error generating day data: $e');
      return 0;
    }
  }

  /// Generate a single random sensor reading with realistic values
  Map<String, dynamic> _generateRandomReading(DateTime timestamp, DateTime dayStart) {
    // Time-based variations (simulate day/night cycle)
    final hour = timestamp.hour;
    final isDay = hour >= 6 && hour <= 18;
    final isDusk = hour >= 18 && hour <= 20;
    final isDawn = hour >= 5 && hour <= 7;

    // Temperature: cooler at night, warmer during day (20-35°C)
    double baseTemp = isDay ? 28.0 : 22.0;
    if (isDusk || isDawn) baseTemp = 24.0;
    final temperature = baseTemp + _randomDouble(-3.0, 5.0);

    // Humidity: higher at night, lower during day (50-90%)
    int baseHumidity = isDay ? 60 : 75;
    final humidity = (baseHumidity + _randomInt(-10, 15)).clamp(50, 90);

    // Light Intensity: 0 at night, high during day (0-60000 lux)
    int lightIntensity = 0;
    if (isDay) {
      if (hour >= 10 && hour <= 14) {
        // Peak sunlight
        lightIntensity = 40000 + _randomInt(-10000, 15000);
      } else {
        // Morning/afternoon
        lightIntensity = 20000 + _randomInt(-10000, 10000);
      }
    } else if (isDusk || isDawn) {
      lightIntensity = 5000 + _randomInt(-2000, 3000);
    }
    lightIntensity = lightIntensity.clamp(0, 60000);

    // Soil Moisture: varies throughout day due to watering (40-80%)
    // Lower in hot afternoon, higher in morning/evening
    int baseSoil = isDay ? 55 : 65;
    if (hour >= 12 && hour <= 15) baseSoil -= 10; // Dry during hot afternoon
    final soilMoisture = (baseSoil + _randomInt(-10, 15)).clamp(35, 85);

    // NPK values: relatively stable with minor variations
    final nitrogen = (60 + _randomInt(-20, 20)).clamp(20, 100);
    final phosphorus = (35 + _randomInt(-10, 15)).clamp(10, 60);
    final potassium = (85 + _randomInt(-20, 25)).clamp(50, 150);

    // Water level: decreases throughout day, refills at night
    int baseWater = isDay ? 70 : 85;
    if (hour >= 14 && hour <= 17) baseWater -= 15; // Lower after hot day
    final waterPercent = (baseWater + _randomInt(-10, 10)).clamp(30, 95);

    // Calculate water level in cm (assuming 100% = 20cm)
    final waterLevel = (waterPercent / 100.0) * 20.0;

    // Calculate distance from sensor (assuming sensor is 25cm from bottom)
    final waterDistance = 25.0 - waterLevel;

    return {
      'deviceId': DEVICE_ID,
      'timestamp': timestamp,
      'temperature': double.parse(temperature.toStringAsFixed(1)),
      'soilMoisture': soilMoisture,
      'lightIntensity': lightIntensity,
      'humidity': humidity,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'waterPercent': waterPercent,
      'waterLevel': double.parse(waterLevel.toStringAsFixed(1)),
      'waterDistance': double.parse(waterDistance.toStringAsFixed(1)),
      'sensors': {
        'temperatureConnected': true,
        'soilConnected': true,
        'lightConnected': true,
        'humidityConnected': true,
        'waterLevelConnected': true,
      },
    };
  }

  /// Helper: Generate random double in range
  double _randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  /// Helper: Generate random int in range
  int _randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  /// Clear all test data (use with caution!)
  Future<bool> clearAllTestData() async {
    try {
      debugPrint('🗑️ Clearing all test data...');

      // Delete sensor readings
      final readingsSnapshot = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .limit(500)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in readingsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete daily summaries
      final summariesSnapshot = await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .limit(500)
          .get();

      batch = _firestore.batch();
      for (var doc in summariesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Test data cleared');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing test data: $e');
      return false;
    }
  }

  /// Generate specific day with custom parameters
  Future<int> generateCustomDayData({
    required DateTime date,
    double avgTemp = 28.0,
    int avgHumidity = 65,
    int avgSoil = 60,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final batch = _firestore.batch();

      int count = 0;

      for (int i = 0; i < 144; i++) {
        final timestamp = startOfDay.add(Duration(minutes: i * 10));

        if (timestamp.isAfter(DateTime.now())) break;

        // Use custom averages with variations
        final reading = {
          'deviceId': DEVICE_ID,
          'timestamp': timestamp,
          'temperature': (avgTemp + _randomDouble(-3.0, 3.0)),
          'soilMoisture': (avgSoil + _randomInt(-10, 10)).clamp(0, 100),
          'lightIntensity': _generateRandomReading(timestamp, startOfDay)['lightIntensity'],
          'humidity': (avgHumidity + _randomInt(-10, 10)).clamp(0, 100),
          'nitrogen': 60 + _randomInt(-15, 15),
          'phosphorus': 35 + _randomInt(-10, 10),
          'potassium': 85 + _randomInt(-15, 15),
          'waterPercent': 75 + _randomInt(-15, 15),
          'waterLevel': 15.0 + _randomDouble(-3.0, 3.0),
          'waterDistance': 10.0 + _randomDouble(-3.0, 3.0),
          'sensors': {
            'temperatureConnected': true,
            'soilConnected': true,
            'lightConnected': true,
            'humidityConnected': true,
            'waterLevelConnected': true,
          },
        };

        final docRef = _firestore
            .collection('sensor_history')
            .doc(DEVICE_ID)
            .collection('readings')
            .doc();

        batch.set(docRef, reading);
        count++;

        if (count % 500 == 0) {
          await batch.commit();
        }
      }

      if (count % 500 != 0) {
        await batch.commit();
      }

      // Generate summary for this day
      await _firestoreService.createDailySummary(date);

      debugPrint('✅ Generated $count readings for custom day');
      return count;
    } catch (e) {
      debugPrint('❌ Error generating custom day: $e');
      return 0;
    }
  }

  /// Generate sample data for October 21-28, 2025
  Future<int> generateOctoberSampleData() async {
    try {
      debugPrint('🔄 Generating October 21-28 sample data...');

      int totalGenerated = 0;

      // October 21 - Cool day
      await generateCustomDayData(
        date: DateTime(2025, 10, 21),
        avgTemp: 19.5,
        avgHumidity: 75,
        avgSoil: 68,
      );
      totalGenerated++;

      // October 22 - Optimal day
      await generateCustomDayData(
        date: DateTime(2025, 10, 22),
        avgTemp: 25.0,
        avgHumidity: 65,
        avgSoil: 60,
      );
      totalGenerated++;

      // October 23 - Optimal day
      await generateCustomDayData(
        date: DateTime(2025, 10, 23),
        avgTemp: 26.5,
        avgHumidity: 62,
        avgSoil: 58,
      );
      totalGenerated++;

      // October 24 - Hot day
      await generateCustomDayData(
        date: DateTime(2025, 10, 24),
        avgTemp: 32.0,
        avgHumidity: 55,
        avgSoil: 52,
      );
      totalGenerated++;

      // October 25 - Optimal day
      await generateCustomDayData(
        date: DateTime(2025, 10, 25),
        avgTemp: 24.5,
        avgHumidity: 68,
        avgSoil: 62,
      );
      totalGenerated++;

      // October 26 - Cool day
      await generateCustomDayData(
        date: DateTime(2025, 10, 26),
        avgTemp: 18.0,
        avgHumidity: 78,
        avgSoil: 70,
      );
      totalGenerated++;

      // October 27 - Optimal day
      await generateCustomDayData(
        date: DateTime(2025, 10, 27),
        avgTemp: 27.0,
        avgHumidity: 60,
        avgSoil: 55,
      );
      totalGenerated++;

      // October 28 - Hot day
      await generateCustomDayData(
        date: DateTime(2025, 10, 28),
        avgTemp: 33.5,
        avgHumidity: 52,
        avgSoil: 48,
      );
      totalGenerated++;

      debugPrint('✅ Generated $totalGenerated days of October sample data');
      debugPrint('📅 October 21-28, 2025 data is now available in Firestore');

      return totalGenerated;
    } catch (e) {
      debugPrint('❌ Error generating October sample data: $e');
      return 0;
    }
  }

  /// Generate DIRECT daily summaries for October 16-28 (no sensor readings)
  /// This creates the summary documents directly in daily_summaries collection
  Future<int> generateOctober16to28Summaries() async {
    try {
      debugPrint('🔄 Generating October 16-28 daily summaries...');

      final batch = _firestore.batch();
      int count = 0;

      final summaries = [
        // October 16 - Optimal
        {
          'date': DateTime(2025, 10, 16),
          'temp': {'min': 23.0, 'max': 27.5},
          'soil': {'min': 58, 'max': 68},
          'humidity': {'min': 62, 'max': 72},
          'light': {'min': 8000, 'max': 52000},
        },
        // October 17 - Hot
        {
          'date': DateTime(2025, 10, 17),
          'temp': {'min': 28.0, 'max': 33.0},
          'soil': {'min': 48, 'max': 60},
          'humidity': {'min': 52, 'max': 64},
          'light': {'min': 12000, 'max': 58000},
        },
        // October 18 - Optimal
        {
          'date': DateTime(2025, 10, 18),
          'temp': {'min': 24.0, 'max': 28.0},
          'soil': {'min': 56, 'max': 66},
          'humidity': {'min': 60, 'max': 70},
          'light': {'min': 9000, 'max': 53000},
        },
        // October 19 - Cool
        {
          'date': DateTime(2025, 10, 19),
          'temp': {'min': 17.5, 'max': 19.5},
          'soil': {'min': 66, 'max': 76},
          'humidity': {'min': 72, 'max': 82},
          'light': {'min': 3000, 'max': 46000},
        },
        // October 20 - Optimal
        {
          'date': DateTime(2025, 10, 20),
          'temp': {'min': 22.5, 'max': 26.5},
          'soil': {'min': 60, 'max': 70},
          'humidity': {'min': 64, 'max': 74},
          'light': {'min': 7000, 'max': 51000},
        },
        // October 21 - Cool
        {
          'date': DateTime(2025, 10, 21),
          'temp': {'min': 17.0, 'max': 19.5},
          'soil': {'min': 65, 'max': 72},
          'humidity': {'min': 72, 'max': 78},
          'light': {'min': 2000, 'max': 45000},
        },
        // October 22 - Optimal
        {
          'date': DateTime(2025, 10, 22),
          'temp': {'min': 23.0, 'max': 27.0},
          'soil': {'min': 58, 'max': 68},
          'humidity': {'min': 62, 'max': 70},
          'light': {'min': 8000, 'max': 52000},
        },
        // October 23 - Optimal
        {
          'date': DateTime(2025, 10, 23),
          'temp': {'min': 24.5, 'max': 28.5},
          'soil': {'min': 55, 'max': 65},
          'humidity': {'min': 60, 'max': 68},
          'light': {'min': 10000, 'max': 56000},
        },
        // October 24 - Hot
        {
          'date': DateTime(2025, 10, 24),
          'temp': {'min': 29.0, 'max': 34.0},
          'soil': {'min': 48, 'max': 58},
          'humidity': {'min': 52, 'max': 62},
          'light': {'min': 15000, 'max': 60000},
        },
        // October 25 - Optimal
        {
          'date': DateTime(2025, 10, 25),
          'temp': {'min': 22.5, 'max': 26.5},
          'soil': {'min': 60, 'max': 70},
          'humidity': {'min': 65, 'max': 73},
          'light': {'min': 7000, 'max': 50000},
        },
        // October 26 - Cool
        {
          'date': DateTime(2025, 10, 26),
          'temp': {'min': 16.0, 'max': 19.0},
          'soil': {'min': 68, 'max': 78},
          'humidity': {'min': 75, 'max': 82},
          'light': {'min': 1000, 'max': 42000},
        },
        // October 27 - Optimal
        {
          'date': DateTime(2025, 10, 27),
          'temp': {'min': 25.0, 'max': 29.0},
          'soil': {'min': 52, 'max': 62},
          'humidity': {'min': 58, 'max': 66},
          'light': {'min': 12000, 'max': 58000},
        },
        // October 28 - Hot
        {
          'date': DateTime(2025, 10, 28),
          'temp': {'min': 30.5, 'max': 35.5},
          'soil': {'min': 42, 'max': 54},
          'humidity': {'min': 48, 'max': 58},
          'light': {'min': 18000, 'max': 62000},
        },
      ];

      for (final summary in summaries) {
        final date = summary['date'] as DateTime;
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final temp = summary['temp'] as Map<String, dynamic>;
        final soil = summary['soil'] as Map<String, dynamic>;
        final humidity = summary['humidity'] as Map<String, dynamic>;
        final light = summary['light'] as Map<String, dynamic>;

        final docRef = _firestore
            .collection('daily_summaries')
            .doc(DEVICE_ID)
            .collection('summaries')
            .doc(dateKey);

        batch.set(docRef, {
          'deviceId': DEVICE_ID,
          'date': date,
          'readingsCount': 0,
          'temperature': {
            'min': temp['min'],
            'max': temp['max'],
          },
          'soilMoisture': {
            'min': soil['min'],
            'max': soil['max'],
          },
          'humidity': {
            'min': humidity['min'],
            'max': humidity['max'],
          },
          'lightIntensity': {
            'min': light['min'],
            'max': light['max'],
          },
          'nitrogen': {
            'min': 50 + _randomInt(-10, 15),
            'max': 75 + _randomInt(-10, 15),
          },
          'phosphorus': {
            'min': 28 + _randomInt(-5, 10),
            'max': 45 + _randomInt(-5, 10),
          },
          'potassium': {
            'min': 70 + _randomInt(-10, 15),
            'max': 100 + _randomInt(-10, 15),
          },
          'waterPercent': {
            'min': 50 + _randomInt(-10, 15),
            'max': 80 + _randomInt(-10, 15),
          },
          'createdAt': FieldValue.serverTimestamp(),
        });

        count++;
      }

      await batch.commit();

      debugPrint('✅ Generated $count daily summaries (October 16-28, 2025)');
      debugPrint('📅 Data is now available in Firestore!');
      debugPrint('🎨 Calendar colors:');
      debugPrint('   🔵 Blue (Cool): Oct 19, 21, 26');
      debugPrint('   🟢 Green (Optimal): Oct 16, 18, 20, 22, 23, 25, 27');
      debugPrint('   🔴 Red (Hot): Oct 17, 24, 28');

      return count;
    } catch (e) {
      debugPrint('❌ Error generating summaries: $e');
      return 0;
    }
  }
}
