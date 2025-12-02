// lib/services/calendar_reminder_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import '../models/calendar_reminder.dart';
import 'notification_service.dart';
import 'local_alarm_service.dart';

class CalendarReminderService {
  static final CalendarReminderService _instance =
      CalendarReminderService._internal();
  factory CalendarReminderService() => _instance;
  CalendarReminderService._internal();

  static const String _remindersKey = 'calendar_reminders';
  static const String DEVICE_ID = 'ESP32_ALS_001';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  final List<CalendarReminder> _reminders = [];
  final StreamController<List<CalendarReminder>> _reminderController =
      StreamController<List<CalendarReminder>>.broadcast();

  Timer? _notificationCheckTimer;
  StreamSubscription? _firestoreSubscription;

  Stream<List<CalendarReminder>> get reminderStream =>
      _reminderController.stream;
  List<CalendarReminder> get reminders => List.unmodifiable(_reminders);

  Future<void> initialize() async {
    debugPrint('🔄 Initializing Calendar Reminder Service...');

    // Load from cache first (fast startup)
    await _loadFromCache();

    // Then sync with Firestore (source of truth)
    await _syncFromFirestore();

    // Listen for real-time updates from Firestore
    _startFirestoreListener();

    // Start notification checker
    _startNotificationChecker();

    debugPrint('✅ Calendar Reminder Service initialized');
  }

  /// Load reminders from local cache (SharedPreferences) - FAST
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? remindersJson = prefs.getString(_remindersKey);

      if (remindersJson != null) {
        final List<dynamic> remindersList = json.decode(remindersJson);
        _reminders.clear();
        _reminders.addAll(
          remindersList.map((item) => CalendarReminder.fromJson(item)).toList(),
        );
        _reminders.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        _reminderController.add(_reminders);
        debugPrint('📱 Loaded ${_reminders.length} reminders from cache');
      }
    } catch (e) {
      debugPrint('❌ Failed to load from cache: $e');
    }
  }

  /// Sync reminders from Firestore - SOURCE OF TRUTH
  Future<void> _syncFromFirestore() async {
    try {
      debugPrint('☁️ Syncing reminders from Firestore...');

      final snapshot = await _firestore
          .collection('calendar_reminders')
          .where('deviceId', isEqualTo: DEVICE_ID)
          .orderBy('date')
          .get();

      if (snapshot.docs.isNotEmpty) {
        _reminders.clear();

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final reminder = CalendarReminder.fromJson(data);
            _reminders.add(reminder);
          } catch (e) {
            debugPrint('⚠️ Failed to parse reminder ${doc.id}: $e');
          }
        }

        _reminders.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );

        // Update cache
        await _saveToCache();

        // Notify listeners
        _reminderController.add(_reminders);

        debugPrint('✅ Synced ${_reminders.length} reminders from Firestore');
      } else {
        debugPrint('📭 No reminders found in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Failed to sync from Firestore: $e');
    }
  }

  /// Listen for real-time Firestore updates
  void _startFirestoreListener() {
    debugPrint('👂 Starting Firestore real-time listener...');

    _firestoreSubscription = _firestore
        .collection('calendar_reminders')
        .where('deviceId', isEqualTo: DEVICE_ID)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '🔄 Firestore update received (${snapshot.docs.length} docs)',
            );

            _reminders.clear();

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final reminder = CalendarReminder.fromJson(data);
                _reminders.add(reminder);
              } catch (e) {
                debugPrint('⚠️ Failed to parse reminder ${doc.id}: $e');
              }
            }

            _reminders.sort(
              (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
            );

            // Update cache
            _saveToCache();

            // Notify listeners
            _reminderController.add(_reminders);
          },
          onError: (error) {
            debugPrint('❌ Firestore listener error: $error');
          },
        );
  }

  /// Save to local cache (SharedPreferences)
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String remindersJson = json.encode(
        _reminders.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_remindersKey, remindersJson);
    } catch (e) {
      debugPrint('❌ Failed to save to cache: $e');
    }
  }

  /// Save to Firestore (PRIMARY STORAGE)
  Future<void> _saveToFirestore(CalendarReminder reminder) async {
    try {
      final reminderData = reminder.toJson();
      reminderData['deviceId'] = DEVICE_ID;
      reminderData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('calendar_reminders')
          .doc(reminder.id)
          .set(reminderData, SetOptions(merge: true));

      debugPrint('✅ Reminder saved to Firestore: ${reminder.title}');
    } catch (e) {
      debugPrint('❌ Failed to save to Firestore: $e');
    }
  }

  void _startNotificationChecker() {
    // Check every minute for reminders that need notifications
    _notificationCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndSendNotifications(),
    );
    // Also check immediately on start
    _checkAndSendNotifications();
  }

  Future<void> _checkAndSendNotifications() async {
    final now = DateTime.now();

    for (var reminder in _reminders) {
      if (reminder.shouldNotify) {
        await _sendReminderNotification(reminder);
      }

      // Auto-complete if past due by more than 1 hour
      if (!reminder.isCompleted &&
          reminder.isPast &&
          now.difference(reminder.scheduledDateTime).inHours > 1) {
        debugPrint(
          '⏰ Auto-marking overdue reminder as completed: ${reminder.title}',
        );
        // Don't auto-complete, just log it
      }
    }
  }

  Future<void> _sendReminderNotification(CalendarReminder reminder) async {
    final notification = NotificationItem(
      id: 'reminder_${reminder.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: '📅 ${reminder.type.displayName} Reminder',
      message:
          '${reminder.title}\n${reminder.description}\n\nScheduled for: ${_formatTime(reminder.time)}',
      timestamp: DateTime.now(),
      priority: NotificationPriority.high,
      isRead: false,
      icon: reminder.icon,
      color: reminder.color,
    );

    await _notificationService.addNotification(notification);
    debugPrint('✅ Sent reminder notification: ${reminder.title}');
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> addReminder(CalendarReminder reminder) async {
    // Save to Firestore (primary storage)
    await _saveToFirestore(reminder);

    // Local list will be updated automatically via Firestore listener
    debugPrint('✅ Reminder added: ${reminder.title}');

    // Check if notification should be sent immediately
    if (reminder.shouldNotify) {
      await _sendReminderNotification(reminder);
    }
  }

  Future<void> updateReminder(CalendarReminder reminder) async {
    // Save to Firestore (primary storage)
    await _saveToFirestore(reminder);

    // Local list will be updated automatically via Firestore listener
    debugPrint('✅ Reminder updated: ${reminder.title}');
  }

  Future<void> deleteReminder(String reminderId) async {
    try {
      // Delete from Firestore (primary storage)
      await _firestore
          .collection('calendar_reminders')
          .doc(reminderId)
          .delete();

      // Local list will be updated automatically via Firestore listener
      debugPrint('✅ Reminder deleted from Firestore');
    } catch (e) {
      debugPrint('❌ Failed to delete from Firestore: $e');
    }
  }

  Future<void> toggleReminderCompletion(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index != -1) {
      final updatedReminder = _reminders[index].copyWith(
        isCompleted: !_reminders[index].isCompleted,
      );

      // Save to Firestore (primary storage)
      await _saveToFirestore(updatedReminder);

      // Local list will be updated automatically via Firestore listener
      debugPrint('✅ Reminder completion toggled');
    }
  }

  List<CalendarReminder> getRemindersForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _reminders.where((r) {
      final reminderDate = DateTime(r.date.year, r.date.month, r.date.day);
      return reminderDate == normalizedDate;
    }).toList();
  }

  List<CalendarReminder> getUpcomingReminders({int days = 7}) {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    return _reminders.where((r) {
      return r.scheduledDateTime.isAfter(now) &&
          r.scheduledDateTime.isBefore(futureDate) &&
          !r.isCompleted;
    }).toList();
  }

  List<CalendarReminder> getTodayReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _reminders.where((r) {
      final reminderDate = DateTime(r.date.year, r.date.month, r.date.day);
      return reminderDate == today;
    }).toList();
  }

  List<CalendarReminder> getOverdueReminders() {
    final now = DateTime.now();
    return _reminders.where((r) {
      return r.scheduledDateTime.isBefore(now) && !r.isCompleted;
    }).toList();
  }

  int getUncompletedCount() {
    return _reminders.where((r) => !r.isCompleted && !r.isPast).length;
  }

  void dispose() {
    _reminderController.close();
    _notificationCheckTimer?.cancel();
    _firestoreSubscription?.cancel();
    debugPrint('🛑 Calendar Reminder Service disposed');
  }
}
