// lib/utils/firestore_initializer.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String DEVICE_ID = 'ESP32_ALS_001';

  /// Initialize Firestore collections structure
  /// Run this ONCE on first app launch
  Future<bool> initializeCollections() async {
    try {
      debugPrint('🔄 Initializing Firestore collections...');

      // Create sensor_history collection structure
      await _createSensorHistoryStructure();

      // Create daily_summaries collection structure
      await _createDailySummariesStructure();

      // Create notifications collection structure
      await _createNotificationsStructure();

      // Create plants collection structure
      await _createPlantsStructure();

      debugPrint('✅ Firestore collections initialized successfully!');
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing Firestore: $e');
      return false;
    }
  }

  /// Create sensor_history collection
  Future<void> _createSensorHistoryStructure() async {
    try {
      // Create main document
      await _firestore.collection('sensor_history').doc(DEVICE_ID).set({
        'deviceId': DEVICE_ID,
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Sensor readings for ESP32 device',
      });

      // Create readings subcollection with placeholder
      await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .doc('_placeholder')
          .set({
        'deviceId': DEVICE_ID,
        'timestamp': FieldValue.serverTimestamp(),
        'isPlaceholder': true,
        'note': 'This document can be deleted after first real reading',
      });

      // Create latest subcollection
      await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('latest')
          .doc('current')
          .set({
        'deviceId': DEVICE_ID,
        'timestamp': FieldValue.serverTimestamp(),
        'isPlaceholder': true,
        'note': 'Will be updated by ESP32',
      });

      debugPrint('✅ sensor_history collection created');
    } catch (e) {
      debugPrint('❌ Error creating sensor_history: $e');
    }
  }

  /// Create daily_summaries collection
  Future<void> _createDailySummariesStructure() async {
    try {
      // Create main document
      await _firestore.collection('daily_summaries').doc(DEVICE_ID).set({
        'deviceId': DEVICE_ID,
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Daily sensor summaries for calendar view',
      });

      // Create summaries subcollection with placeholder
      await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .doc('_placeholder')
          .set({
        'deviceId': DEVICE_ID,
        'date': FieldValue.serverTimestamp(),
        'isPlaceholder': true,
        'note': 'This document can be deleted after first summary generation',
      });

      debugPrint('✅ daily_summaries collection created');
    } catch (e) {
      debugPrint('❌ Error creating daily_summaries: $e');
    }
  }

  /// Create notifications collection
  Future<void> _createNotificationsStructure() async {
    try {
      // Create placeholder notification
      await _firestore.collection('notifications').doc('_placeholder').set({
        'deviceId': DEVICE_ID,
        'title': 'System Initialized',
        'message': 'Firestore collections have been set up successfully.',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
        'priority': 'low',
        'isRead': false,
      });

      debugPrint('✅ notifications collection created');
    } catch (e) {
      debugPrint('❌ Error creating notifications: $e');
    }
  }

  /// Create plants collection
  Future<void> _createPlantsStructure() async {
    try {
      // Create placeholder plant
      await _firestore.collection('plants').doc('_placeholder').set({
        'deviceId': DEVICE_ID,
        'name': 'Placeholder Plant',
        'isCustom': false,
        'createdAt': FieldValue.serverTimestamp(),
        'note': 'This document can be deleted after adding real plants',
      });

      debugPrint('✅ plants collection created');
    } catch (e) {
      debugPrint('❌ Error creating plants: $e');
    }
  }

  /// Check if collections are already initialized
  Future<bool> areCollectionsInitialized() async {
    try {
      // Check if sensor_history exists
      final sensorDoc = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .get();

      // Check if daily_summaries exists
      final summariesDoc = await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .get();

      return sensorDoc.exists && summariesDoc.exists;
    } catch (e) {
      debugPrint('❌ Error checking collections: $e');
      return false;
    }
  }

  /// Delete placeholder documents (call after you have real data)
  Future<void> cleanupPlaceholders() async {
    try {
      debugPrint('🧹 Cleaning up placeholder documents...');

      // Delete sensor_history placeholder
      await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .doc('_placeholder')
          .delete();

      // Delete daily_summaries placeholder
      await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .doc('_placeholder')
          .delete();

      // Delete notifications placeholder
      await _firestore
          .collection('notifications')
          .doc('_placeholder')
          .delete();

      // Delete plants placeholder
      await _firestore
          .collection('plants')
          .doc('_placeholder')
          .delete();

      debugPrint('✅ Placeholders cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning placeholders: $e');
    }
  }

  /// Show Firestore structure info
  void printCollectionStructure() {
    debugPrint('''

📦 Firestore Collection Structure:

sensor_history/
  └── ESP32_ALS_001/
      ├── readings/          (ESP32 writes here every 5 seconds)
      │   └── {auto-id}
      └── latest/
          └── current        (Latest reading)

daily_summaries/
  └── ESP32_ALS_001/
      └── summaries/         (Calendar gets data here)
          └── {date-key}     (e.g., "2025-01-15")

notifications/
  └── {notification-id}      (Active notifications)

notifications_archive/
  └── {notification-id}      (Archived notifications)

plants/
  └── {plant-id}             (Custom plants)

    ''');
  }
}
