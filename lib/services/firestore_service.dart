// lib/services/firestore_service.dart - WITH 2K LIMIT & AUTO-CLEANUP

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/plant_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String DEVICE_ID = 'ESP32_ALS_001';

  List<Plant>? _cachedPlants;
  DateTime? _cacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  List<NotificationData>? _cachedNotifications;
  DateTime? _notificationsCacheTime;

  // ====== PLANT MANAGEMENT (FIRESTORE ONLY) ======

  Future<List<Plant>> getCustomPlants({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPlants != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheExpiry) {
      debugPrint('✅ Returning cached plants');
      return _cachedPlants!;
    }

    try {
      final snapshot = await _firestore
          .collection('plants')
          .where('isCustom', isEqualTo: true)
          .where('deviceId', isEqualTo: DEVICE_ID)
          .orderBy('createdAt', descending: true)
          .get();

      final plants = snapshot.docs.map((doc) {
        final data = doc.data();
        return Plant.fromJson({...data, 'id': doc.id});
      }).toList();

      _cachedPlants = plants;
      _cacheTime = DateTime.now();

      debugPrint('✅ Loaded ${plants.length} custom plants from Firestore');
      return plants;
    } catch (e) {
      debugPrint('❌ Error getting custom plants: $e');
      if (_cachedPlants != null) {
        debugPrint('⚠️ Using cached data due to error');
        return _cachedPlants!;
      }
      return [];
    }
  }

  Future<bool> addCustomPlant(Plant plant) async {
    try {
      final plantData = plant.toJson();
      plantData['isCustom'] = true;
      plantData['createdAt'] = FieldValue.serverTimestamp();
      plantData['updatedAt'] = FieldValue.serverTimestamp();
      plantData['deviceId'] = DEVICE_ID;

      await _firestore.collection('plants').doc(plant.id).set(plantData);

      _cachedPlants = null;

      debugPrint('✅ Plant added to Firestore: ${plant.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding plant: $e');
      return false;
    }
  }

  Future<bool> updateCustomPlant(String plantId, Plant plant) async {
    try {
      final plantData = plant.toJson();
      plantData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('plants').doc(plantId).update(plantData);

      _cachedPlants = null;

      debugPrint('✅ Plant updated in Firestore: ${plant.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating plant: $e');
      return false;
    }
  }

  Future<bool> deleteCustomPlant(String plantId) async {
    try {
      await _firestore.collection('plants').doc(plantId).delete();

      _cachedPlants = null;

      debugPrint('✅ Plant deleted from Firestore: $plantId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting plant: $e');
      return false;
    }
  }

  void clearPlantCache() {
    _cachedPlants = null;
    _cacheTime = null;
    debugPrint('✅ Plant cache cleared');
  }

  // ====== NOTIFICATIONS - WITH 2K LIMIT ======

  /// Get all notifications from Firestore (MAX 2000)
  Future<List<NotificationData>> getNotifications({
    int limit = 2000, // 🆕 Changed default to 2000
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? priority,
    bool? isRead,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedNotifications != null &&
        _notificationsCacheTime != null &&
        DateTime.now().difference(_notificationsCacheTime!) <
            const Duration(minutes: 2)) {
      debugPrint(
        '✅ Returning cached notifications (${_cachedNotifications!.length})',
      );
      return _cachedNotifications!;
    }

    try {
      // ✅ Query with 2K limit
      Query query = _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(limit); // Max 2000

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }
      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }
      if (priority != null) {
        query = query.where('priority', isEqualTo: priority);
      }
      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      final snapshot = await query.get();

      // Filter by deviceId in memory
      final notifications = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return NotificationData.fromFirestore(doc.id, data);
            } catch (e) {
              debugPrint('❌ Error parsing notification: $e');
              return null;
            }
          })
          .whereType<NotificationData>()
          .where((notif) => notif.deviceId == DEVICE_ID)
          .take(limit) // ✅ Ensure max 2K
          .toList();

      _cachedNotifications = notifications;
      _notificationsCacheTime = DateTime.now();

      debugPrint(
        '✅ Loaded ${notifications.length} notifications (max: $limit)',
      );

      // 🆕 Auto-cleanup if approaching limit
      if (notifications.length >= (limit * 0.9).toInt()) {
        // 90% = 1800
        debugPrint(
          '⚠️ Firestore has ${notifications.length} notifications. Starting cleanup...',
        );
        _autoCleanupOldNotifications();
      }

      return notifications;
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      if (_cachedNotifications != null) {
        debugPrint('⚠️ Using cached notifications due to error');
        return _cachedNotifications!;
      }
      return [];
    }
  }

  /// 🆕 Auto-cleanup old notifications in Firestore when approaching 2K
  Future<void> _autoCleanupOldNotifications() async {
    try {
      debugPrint('🧹 Auto-cleanup: Archiving old notifications...');

      final snapshot = await _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(2500)
          .get();

      final deviceNotifications = snapshot.docs
          .where((doc) => doc.data()['deviceId'] == DEVICE_ID)
          .toList();

      if (deviceNotifications.length > 1500) {
        final toArchive = deviceNotifications.skip(1500).toList();

        debugPrint(
          '📦 Auto-archiving ${toArchive.length} old notifications...',
        );

        int archivedCount = 0;
        for (var doc in toArchive) {
          try {
            final data = doc.data();

            // Add to archive
            await _firestore
                .collection('notifications_archive')
                .doc(doc.id)
                .set({
                  ...data,
                  'archivedAt': FieldValue.serverTimestamp(),
                  'expiresAt': DateTime.now().add(const Duration(days: 30)),
                  'originalId': doc.id,
                });

            // Delete from main collection
            await doc.reference.delete();
            archivedCount++;

            // Throttle to avoid overwhelming Firestore
            if (archivedCount % 100 == 0) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e) {
            debugPrint('⚠️ Failed to archive ${doc.id}: $e');
          }
        }

        debugPrint(
          '✅ Auto-cleanup complete: $archivedCount notifications archived',
        );
        _cachedNotifications = null; // Clear cache to force refresh
      }
    } catch (e) {
      debugPrint('❌ Auto-cleanup failed: $e');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(2000)
          .get();

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['deviceId'] == DEVICE_ID &&
            (data['isRead'] ?? true) == false;
      }).length;

      return count;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      _cachedNotifications = null;

      debugPrint('✅ Notification marked as read: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to mark notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(2000)
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['deviceId'] == DEVICE_ID &&
            (data['isRead'] ?? true) == false) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      await batch.commit();
      _cachedNotifications = null;

      debugPrint('✅ All notifications marked as read');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to mark all as read: $e');
      return false;
    }
  }

  Future<bool> archiveNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ Notification not found: $notificationId');
        return false;
      }

      final data = doc.data()!;

      final archiveData = {
        ...data,
        'archivedAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)),
        'originalId': notificationId,
      };

      await _firestore
          .collection('notifications_archive')
          .doc(notificationId)
          .set(archiveData);

      await _firestore.collection('notifications').doc(notificationId).delete();

      _cachedNotifications = null;

      debugPrint('✅ Notification archived: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to archive notification: $e');
      return false;
    }
  }

  Future<int> archiveAllNotifications() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['deviceId'] == DEVICE_ID) {
          final archiveData = {
            ...data,
            'archivedAt': FieldValue.serverTimestamp(),
            'expiresAt': DateTime.now().add(const Duration(days: 30)),
            'originalId': doc.id,
          };

          batch.set(
            _firestore.collection('notifications_archive').doc(doc.id),
            archiveData,
          );

          batch.delete(doc.reference);
          count++;
        }
      }

      await batch.commit();
      _cachedNotifications = null;

      debugPrint('✅ Archived $count notifications');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to archive all notifications: $e');
      return 0;
    }
  }

  Future<int> cleanupExpiredArchive() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('notifications_archive')
          .where('expiresAt', isLessThan: now)
          .limit(500)
          .get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['deviceId'] == DEVICE_ID) {
          batch.delete(doc.reference);
          count++;
        }
      }

      await batch.commit();

      debugPrint('✅ Cleaned up $count expired archived notifications');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to cleanup expired archive: $e');
      return 0;
    }
  }

  Future<int> getArchivedCount() async {
    try {
      final snapshot = await _firestore
          .collection('notifications_archive')
          .orderBy('archivedAt', descending: true)
          .limit(1000)
          .get();

      final count = snapshot.docs
          .where((doc) => doc.data()['deviceId'] == DEVICE_ID)
          .length;

      debugPrint('📦 Archived notifications count: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Failed to get archived count: $e');
      return 0;
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      _cachedNotifications = null;

      debugPrint('✅ Notification deleted: $notificationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete notification: $e');
      return false;
    }
  }

  Future<void> deleteOldNotifications({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot = await _firestore
          .collection('notifications')
          .where('timestamp', isLessThan: cutoffDate)
          .limit(500)
          .get();

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['deviceId'] == DEVICE_ID) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      _cachedNotifications = null;

      debugPrint('✅ Deleted old notifications');
    } catch (e) {
      debugPrint('❌ Error deleting old notifications: $e');
    }
  }

  Future<Map<String, dynamic>> getNotificationStatistics({int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final notifications = await getNotifications(
        startDate: startDate,
        forceRefresh: true,
      );

      int critical = 0;
      int high = 0;
      int medium = 0;
      int low = 0;

      Map<String, int> typeCount = {};

      for (var notification in notifications) {
        switch (notification.priority.toLowerCase()) {
          case 'critical':
            critical++;
            break;
          case 'high':
            high++;
            break;
          case 'medium':
            medium++;
            break;
          case 'low':
            low++;
            break;
        }

        typeCount[notification.type] = (typeCount[notification.type] ?? 0) + 1;
      }

      return {
        'total': notifications.length,
        'critical': critical,
        'high': high,
        'medium': medium,
        'low': low,
        'byType': typeCount,
        'unread': notifications.where((n) => !n.isRead).length,
      };
    } catch (e) {
      debugPrint('❌ Error getting notification statistics: $e');
      return {};
    }
  }

  /// Stream notifications in real-time - MAX 2000
  Stream<List<NotificationData>> streamNotifications({int limit = 2000}) {
    debugPrint('🔄 Starting notification stream (limit: $limit)...');

    return _firestore
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final allNotifications = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  return NotificationData.fromFirestore(doc.id, data);
                } catch (e) {
                  debugPrint('❌ Error parsing notification stream: $e');
                  return null;
                }
              })
              .whereType<NotificationData>()
              .toList();

          final filtered = allNotifications
              .where((notif) => notif.deviceId == DEVICE_ID)
              .take(limit)
              .toList();

          debugPrint(
            '✅ Streamed ${filtered.length}/${allNotifications.length} notifications',
          );
          return filtered;
        });
  }

  void clearNotificationCache() {
    _cachedNotifications = null;
    _notificationsCacheTime = null;
    debugPrint('✅ Notification cache cleared');
  }

  // ====== SENSOR HISTORY (FIRESTORE ONLY - for analytics) ======

  Future<void> saveSensorReading({
    required double? temperature,
    required int? soilMoisture,
    required int? lightIntensity,
    required int? humidity,
    required int? nitrogen,
    required int? phosphorus,
    required int? potassium,
    int? waterPercent,
    double? waterLevel,
    double? waterDistance,
    required bool tempConnected,
    required bool soilConnected,
    required bool lightConnected,
    required bool humidityConnected,
    bool waterLevelConnected = false,
  }) async {
    try {
      final now = DateTime.now();
      final reading = {
        'deviceId': DEVICE_ID,
        'timestamp': FieldValue.serverTimestamp(),
        'temperature': temperature,
        'soilMoisture': soilMoisture,
        'lightIntensity': lightIntensity,
        'humidity': humidity,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'waterPercent': waterPercent,
        'waterLevel': waterLevel,
        'waterDistance': waterDistance,
        'sensors': {
          'temperatureConnected': tempConnected,
          'soilConnected': soilConnected,
          'lightConnected': lightConnected,
          'humidityConnected': humidityConnected,
          'waterLevelConnected': waterLevelConnected,
        },
      };

      final batch = _firestore.batch();

      final docRef = _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .doc();

      batch.set(docRef, reading);

      final latestRef = _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('latest')
          .doc('current');

      batch.set(latestRef, reading, SetOptions(merge: true));

      await batch.commit();

      debugPrint('✅ Sensor reading saved to Firestore');

      await _updateDailySummary(
        date: now,
        temperature: temperature,
        soilMoisture: soilMoisture,
        lightIntensity: lightIntensity,
        humidity: humidity,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        waterPercent: waterPercent,
      );
    } catch (e) {
      debugPrint('❌ Error saving sensor reading: $e');
    }
  }

  Future<void> _updateDailySummary({
    required DateTime date,
    double? temperature,
    int? soilMoisture,
    int? lightIntensity,
    int? humidity,
    int? nitrogen,
    int? phosphorus,
    int? potassium,
    int? waterPercent,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final summaryRef = _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .doc(dateKey);

      final doc = await summaryRef.get();

      if (doc.exists) {
        final data = doc.data()!;
        final updates = <String, dynamic>{};

        void updateMinMaxAvg(String field, num? newValue) {
          if (newValue == null) return;

          final current = data[field] as Map<String, dynamic>?;
          if (current == null) {
            updates[field] = {
              'min': newValue,
              'max': newValue,
              'sum': newValue,
              'count': 1,
              'avg': newValue,
            };
          } else {
            final currentMin = current['min'] as num?;
            final currentMax = current['max'] as num?;
            final currentSum = (current['sum'] as num?) ?? 0;
            final currentCount = (current['count'] as int?) ?? 0;

            if (currentMin == null || newValue < currentMin) {
              updates['$field.min'] = newValue;
            }
            if (currentMax == null || newValue > currentMax) {
              updates['$field.max'] = newValue;
            }

            final newSum = currentSum + newValue;
            final newCount = currentCount + 1;
            final newAvg = newSum / newCount;

            updates['$field.sum'] = newSum;
            updates['$field.count'] = newCount;
            updates['$field.avg'] = newAvg;
          }
        }

        updateMinMaxAvg('temperature', temperature);
        updateMinMaxAvg('soilMoisture', soilMoisture);
        updateMinMaxAvg('lightIntensity', lightIntensity);
        updateMinMaxAvg('humidity', humidity);
        updateMinMaxAvg('nitrogen', nitrogen);
        updateMinMaxAvg('phosphorus', phosphorus);
        updateMinMaxAvg('potassium', potassium);
        updateMinMaxAvg('waterPercent', waterPercent);

        if (updates.isNotEmpty) {
          updates['readingsCount'] = FieldValue.increment(1);
          await summaryRef.update(updates);
          debugPrint('✅ Daily summary updated for $dateKey');
        }
      } else {
        final newSummary = {
          'deviceId': DEVICE_ID,
          'date': normalizedDate,
          'readingsCount': 1,
        };

        if (temperature != null) {
          newSummary['temperature'] = {
            'min': temperature,
            'max': temperature,
            'sum': temperature,
            'count': 1,
            'avg': temperature,
          };
        }
        if (soilMoisture != null) {
          newSummary['soilMoisture'] = {
            'min': soilMoisture,
            'max': soilMoisture,
            'sum': soilMoisture,
            'count': 1,
            'avg': soilMoisture,
          };
        }
        if (lightIntensity != null) {
          newSummary['lightIntensity'] = {
            'min': lightIntensity,
            'max': lightIntensity,
            'sum': lightIntensity,
            'count': 1,
            'avg': lightIntensity,
          };
        }
        if (humidity != null) {
          newSummary['humidity'] = {
            'min': humidity,
            'max': humidity,
            'sum': humidity,
            'count': 1,
            'avg': humidity,
          };
        }
        if (nitrogen != null) {
          newSummary['nitrogen'] = {
            'min': nitrogen,
            'max': nitrogen,
            'sum': nitrogen,
            'count': 1,
            'avg': nitrogen,
          };
        }
        if (phosphorus != null) {
          newSummary['phosphorus'] = {
            'min': phosphorus,
            'max': phosphorus,
            'sum': phosphorus,
            'count': 1,
            'avg': phosphorus,
          };
        }
        if (potassium != null) {
          newSummary['potassium'] = {
            'min': potassium,
            'max': potassium,
            'sum': potassium,
            'count': 1,
            'avg': potassium,
          };
        }
        if (waterPercent != null) {
          newSummary['waterPercent'] = {
            'min': waterPercent,
            'max': waterPercent,
            'sum': waterPercent,
            'count': 1,
            'avg': waterPercent,
          };
        }

        newSummary['createdAt'] = FieldValue.serverTimestamp();

        await summaryRef.set(newSummary);
        debugPrint('✅ New daily summary created for $dateKey');
      }
    } catch (e) {
      debugPrint('❌ Error updating daily summary: $e');
    }
  }

  Future<SensorHistoryData?> getLatestReading() async {
    try {
      final doc = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('latest')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        return SensorHistoryData.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting latest reading: $e');
      return null;
    }
  }

  Future<List<SensorHistoryData>> getSensorHistory({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();

      final readings = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return SensorHistoryData.fromFirestore(data);
            } catch (e) {
              debugPrint('❌ Error parsing document: $e');
              return null;
            }
          })
          .whereType<SensorHistoryData>()
          .toList();

      debugPrint('✅ Loaded ${readings.length} readings from Firestore');
      return readings;
    } catch (e) {
      debugPrint('❌ Error getting sensor history: $e');
      return [];
    }
  }

  Future<List<SensorHistoryData>> getRecentReadings({int hours = 24}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(hours: hours));

      final snapshot = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return SensorHistoryData.fromFirestore(data);
            } catch (e) {
              return null;
            }
          })
          .whereType<SensorHistoryData>()
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting recent readings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getStatistics({int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final readings = await getSensorHistory(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      if (readings.isEmpty) {
        return {
          'totalReadings': 0,
          'avgTemperature': 0.0,
          'avgSoilMoisture': 0.0,
          'avgHumidity': 0.0,
          'avgLight': 0.0,
          'avgWaterLevel': 0.0,
        };
      }

      double tempSum = 0, soilSum = 0, humSum = 0, lightSum = 0;
      int tempCount = 0, soilCount = 0, humCount = 0, lightCount = 0;
      double waterSum = 0;
      int waterCount = 0;

      for (var reading in readings) {
        if (reading.temperature != null) {
          tempSum += reading.temperature!;
          tempCount++;
        }
        if (reading.soilMoisture != null) {
          soilSum += reading.soilMoisture!;
          soilCount++;
        }
        if (reading.humidity != null) {
          humSum += reading.humidity!;
          humCount++;
        }
        if (reading.lightIntensity != null) {
          lightSum += reading.lightIntensity!;
          lightCount++;
        }
        if (reading.waterLevel != null) {
          waterSum += reading.waterLevel!;
          waterCount++;
        }
      }

      return {
        'totalReadings': readings.length,
        'avgTemperature': tempCount > 0 ? tempSum / tempCount : 0.0,
        'avgSoilMoisture': soilCount > 0 ? soilSum / soilCount : 0.0,
        'avgHumidity': humCount > 0 ? humSum / humCount : 0.0,
        'avgLight': lightCount > 0 ? lightSum / lightCount : 0.0,
        'avgWaterLevel': waterCount > 0 ? waterSum / waterCount : 0.0,
      };
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {};
    }
  }

  Future<void> deleteOldRecords({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .where('timestamp', isLessThan: cutoffDate)
          .limit(500)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint(
        '✅ Deleted ${snapshot.docs.length} old records from Firestore',
      );
    } catch (e) {
      debugPrint('❌ Error deleting old records: $e');
    }
  }

  // ====== DAILY SUMMARY (for Calendar View) ======

  Future<bool> createDailySummary(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      debugPrint(
        '📊 Generating daily summary for ${startOfDay.toString().split(' ')[0]}',
      );

      final snapshot = await _firestore
          .collection('sensor_history')
          .doc(DEVICE_ID)
          .collection('readings')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No readings found for this date');
        return false;
      }

      double? minTemp, maxTemp, avgTemp;
      int? minSoil, maxSoil, avgSoil;
      int? minLight, maxLight, avgLight;
      int? minHumidity, maxHumidity, avgHumidity;
      int? minNitrogen, maxNitrogen, avgNitrogen;
      int? minPhosphorus, maxPhosphorus, avgPhosphorus;
      int? minPotassium, maxPotassium, avgPotassium;
      int? minWaterPercent, maxWaterPercent, avgWaterPercent;

      List<double> tempValues = [];
      List<int> soilValues = [];
      List<int> lightValues = [];
      List<int> humidityValues = [];
      List<int> nitrogenValues = [];
      List<int> phosphorusValues = [];
      List<int> potassiumValues = [];
      List<int> waterPercentValues = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data['temperature'] != null) {
          tempValues.add((data['temperature'] as num).toDouble());
        }
        if (data['soilMoisture'] != null) {
          soilValues.add(data['soilMoisture'] as int);
        }
        if (data['lightIntensity'] != null) {
          lightValues.add(data['lightIntensity'] as int);
        }
        if (data['humidity'] != null) {
          humidityValues.add(data['humidity'] as int);
        }
        if (data['nitrogen'] != null) {
          nitrogenValues.add(data['nitrogen'] as int);
        }
        if (data['phosphorus'] != null) {
          phosphorusValues.add(data['phosphorus'] as int);
        }
        if (data['potassium'] != null) {
          potassiumValues.add(data['potassium'] as int);
        }
        if (data['waterPercent'] != null) {
          waterPercentValues.add(data['waterPercent'] as int);
        }
      }

      if (tempValues.isNotEmpty) {
        minTemp = tempValues.reduce((a, b) => a < b ? a : b);
        maxTemp = tempValues.reduce((a, b) => a > b ? a : b);
        avgTemp = tempValues.reduce((a, b) => a + b) / tempValues.length;
      }

      if (soilValues.isNotEmpty) {
        minSoil = soilValues.reduce((a, b) => a < b ? a : b);
        maxSoil = soilValues.reduce((a, b) => a > b ? a : b);
        avgSoil = (soilValues.reduce((a, b) => a + b) / soilValues.length)
            .round();
      }

      if (lightValues.isNotEmpty) {
        minLight = lightValues.reduce((a, b) => a < b ? a : b);
        maxLight = lightValues.reduce((a, b) => a > b ? a : b);
        avgLight = (lightValues.reduce((a, b) => a + b) / lightValues.length)
            .round();
      }

      if (humidityValues.isNotEmpty) {
        minHumidity = humidityValues.reduce((a, b) => a < b ? a : b);
        maxHumidity = humidityValues.reduce((a, b) => a > b ? a : b);
        avgHumidity =
            (humidityValues.reduce((a, b) => a + b) / humidityValues.length)
                .round();
      }

      if (nitrogenValues.isNotEmpty) {
        minNitrogen = nitrogenValues.reduce((a, b) => a < b ? a : b);
        maxNitrogen = nitrogenValues.reduce((a, b) => a > b ? a : b);
        avgNitrogen =
            (nitrogenValues.reduce((a, b) => a + b) / nitrogenValues.length)
                .round();
      }

      if (phosphorusValues.isNotEmpty) {
        minPhosphorus = phosphorusValues.reduce((a, b) => a < b ? a : b);
        maxPhosphorus = phosphorusValues.reduce((a, b) => a > b ? a : b);
        avgPhosphorus =
            (phosphorusValues.reduce((a, b) => a + b) / phosphorusValues.length)
                .round();
      }

      if (potassiumValues.isNotEmpty) {
        minPotassium = potassiumValues.reduce((a, b) => a < b ? a : b);
        maxPotassium = potassiumValues.reduce((a, b) => a > b ? a : b);
        avgPotassium =
            (potassiumValues.reduce((a, b) => a + b) / potassiumValues.length)
                .round();
      }

      if (waterPercentValues.isNotEmpty) {
        minWaterPercent = waterPercentValues.reduce((a, b) => a < b ? a : b);
        maxWaterPercent = waterPercentValues.reduce((a, b) => a > b ? a : b);
        avgWaterPercent =
            (waterPercentValues.reduce((a, b) => a + b) /
                    waterPercentValues.length)
                .round();
      }

      final summaryData = {
        'deviceId': DEVICE_ID,
        'date': startOfDay,
        'readingsCount': snapshot.docs.length,
        'temperature': {'min': minTemp, 'max': maxTemp, 'avg': avgTemp},
        'soilMoisture': {'min': minSoil, 'max': maxSoil, 'avg': avgSoil},
        'lightIntensity': {'min': minLight, 'max': maxLight, 'avg': avgLight},
        'humidity': {
          'min': minHumidity,
          'max': maxHumidity,
          'avg': avgHumidity,
        },
        'nitrogen': {
          'min': minNitrogen,
          'max': maxNitrogen,
          'avg': avgNitrogen,
        },
        'phosphorus': {
          'min': minPhosphorus,
          'max': maxPhosphorus,
          'avg': avgPhosphorus,
        },
        'potassium': {
          'min': minPotassium,
          'max': maxPotassium,
          'avg': avgPotassium,
        },
        'waterPercent': {
          'min': minWaterPercent,
          'max': maxWaterPercent,
          'avg': avgWaterPercent,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final dateKey =
          '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}-${startOfDay.day.toString().padLeft(2, '0')}';
      await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .doc(dateKey)
          .set(summaryData);

      debugPrint(
        '✅ Daily summary created: $dateKey (${snapshot.docs.length} readings)',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error creating daily summary: $e');
      return false;
    }
  }

  Future<DailySensorSummary?> getDailySummary(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final dateKey =
          '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}-${startOfDay.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .doc(dateKey)
          .get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('⚠️ No summary found for $dateKey');
        return null;
      }

      return DailySensorSummary.fromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('❌ Error getting daily summary: $e');
      return null;
    }
  }

  Future<Map<DateTime, DailySensorSummary>> getDateRangeSummaries({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final normalizedStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final normalizedEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );

      final snapshot = await _firestore
          .collection('daily_summaries')
          .doc(DEVICE_ID)
          .collection('summaries')
          .where('date', isGreaterThanOrEqualTo: normalizedStart)
          .where('date', isLessThanOrEqualTo: normalizedEnd)
          .get();

      final Map<DateTime, DailySensorSummary> summaries = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final summary = DailySensorSummary.fromFirestore(data);
          summaries[summary.date] = summary;
        } catch (e) {
          debugPrint('❌ Error parsing summary: $e');
        }
      }

      debugPrint('✅ Loaded ${summaries.length} daily summaries');
      return summaries;
    } catch (e) {
      debugPrint('❌ Error getting date range summaries: $e');
      return {};
    }
  }

  Stream<Map<DateTime, DailySensorSummary>> streamDateRangeSummaries({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    debugPrint('🔄 Streaming daily summaries for date range...');

    return _firestore
        .collection('daily_summaries')
        .doc(DEVICE_ID)
        .collection('summaries')
        .where('date', isGreaterThanOrEqualTo: normalizedStart)
        .where('date', isLessThanOrEqualTo: normalizedEnd)
        .snapshots()
        .map((snapshot) {
          final Map<DateTime, DailySensorSummary> summaries = {};

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final summary = DailySensorSummary.fromFirestore(data);
              summaries[summary.date] = summary;
            } catch (e) {
              debugPrint('❌ Error parsing summary in stream: $e');
            }
          }

          debugPrint('✅ Stream updated: ${summaries.length} summaries');
          return summaries;
        });
  }

  Future<int> generateMissingSummaries({int daysBack = 30}) async {
    try {
      int generated = 0;
      final now = DateTime.now();

      for (int i = 0; i < daysBack; i++) {
        final date = now.subtract(Duration(days: i));
        final existing = await getDailySummary(date);

        if (existing == null) {
          final success = await createDailySummary(date);
          if (success) generated++;
        }
      }

      debugPrint('✅ Generated $generated missing daily summaries');
      return generated;
    } catch (e) {
      debugPrint('❌ Error generating missing summaries: $e');
      return 0;
    }
  }
}

// ====== DATA MODELS ======

class SensorHistoryData {
  final DateTime timestamp;
  final double? temperature;
  final int? soilMoisture;
  final int? lightIntensity;
  final int? humidity;
  final int? nitrogen;
  final int? phosphorus;
  final int? potassium;
  final int? waterPercent;
  final double? waterLevel;
  final double? waterDistance;
  final Map<String, bool> sensors;

  SensorHistoryData({
    required this.timestamp,
    this.temperature,
    this.soilMoisture,
    this.lightIntensity,
    this.humidity,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.waterPercent,
    this.waterLevel,
    this.waterDistance,
    required this.sensors,
  });

  factory SensorHistoryData.fromFirestore(Map<String, dynamic> data) {
    return SensorHistoryData(
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      temperature: data['temperature']?.toDouble(),
      soilMoisture: data['soilMoisture']?.toInt(),
      lightIntensity: data['lightIntensity']?.toInt(),
      humidity: data['humidity']?.toInt(),
      nitrogen: data['nitrogen']?.toInt(),
      phosphorus: data['phosphorus']?.toInt(),
      potassium: data['potassium']?.toInt(),
      waterPercent: data['waterPercent']?.toInt(),
      waterLevel: data['waterLevel']?.toDouble(),
      waterDistance: data['waterDistance']?.toDouble(),
      sensors: Map<String, bool>.from(data['sensors'] ?? {}),
    );
  }
}

class NotificationData {
  final String id;
  final String deviceId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final DateTime timestamp;
  final bool isRead;
  final int? iconCodePoint;
  final int? colorValue;

  NotificationData({
    required this.id,
    required this.deviceId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    required this.isRead,
    this.iconCodePoint,
    this.colorValue,
  });

  factory NotificationData.fromFirestore(String id, Map<String, dynamic> data) {
    return NotificationData(
      id: id,
      deviceId: data['deviceId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'alert',
      priority: data['priority'] ?? 'medium',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      iconCodePoint: data['iconCodePoint'],
      colorValue: data['colorValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }
}

class DailySensorSummary {
  final DateTime date;
  final String deviceId;
  final int readingsCount;
  final SensorStats? temperature;
  final SensorStats? soilMoisture;
  final SensorStats? lightIntensity;
  final SensorStats? humidity;
  final SensorStats? nitrogen;
  final SensorStats? phosphorus;
  final SensorStats? potassium;
  final SensorStats? waterPercent;

  DailySensorSummary({
    required this.date,
    required this.deviceId,
    required this.readingsCount,
    this.temperature,
    this.soilMoisture,
    this.lightIntensity,
    this.humidity,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.waterPercent,
  });

  factory DailySensorSummary.fromFirestore(Map<String, dynamic> data) {
    return DailySensorSummary(
      date: (data['date'] as Timestamp).toDate(),
      deviceId: data['deviceId'] ?? '',
      readingsCount: data['readingsCount'] ?? 0,
      temperature: data['temperature'] != null
          ? SensorStats.fromMap(data['temperature'])
          : null,
      soilMoisture: data['soilMoisture'] != null
          ? SensorStats.fromMap(data['soilMoisture'])
          : null,
      lightIntensity: data['lightIntensity'] != null
          ? SensorStats.fromMap(data['lightIntensity'])
          : null,
      humidity: data['humidity'] != null
          ? SensorStats.fromMap(data['humidity'])
          : null,
      nitrogen: data['nitrogen'] != null
          ? SensorStats.fromMap(data['nitrogen'])
          : null,
      phosphorus: data['phosphorus'] != null
          ? SensorStats.fromMap(data['phosphorus'])
          : null,
      potassium: data['potassium'] != null
          ? SensorStats.fromMap(data['potassium'])
          : null,
      waterPercent: data['waterPercent'] != null
          ? SensorStats.fromMap(data['waterPercent'])
          : null,
    );
  }
}

class SensorStats {
  final num? min;
  final num? max;
  final num? avg;

  SensorStats({this.min, this.max, this.avg});

  factory SensorStats.fromMap(Map<String, dynamic> map) {
    return SensorStats(min: map['min'], max: map['max'], avg: map['avg']);
  }

  Map<String, dynamic> toMap() {
    return {'min': min, 'max': max, 'avg': avg};
  }
}
