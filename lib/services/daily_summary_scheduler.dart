// lib/services/daily_summary_scheduler.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'firestore_service.dart';

class DailySummaryScheduler {
  static final DailySummaryScheduler _instance = DailySummaryScheduler._internal();
  factory DailySummaryScheduler() => _instance;
  DailySummaryScheduler._internal();

  final FirestoreService _firestoreService = FirestoreService();
  Timer? _dailyTimer;
  bool _isRunning = false;

  /// Start the daily scheduler
  /// Runs at 11:59 PM every day to compute complete daily summary
  void start() {
    if (_isRunning) {
      debugPrint('⚠️ Daily summary scheduler already running');
      return;
    }

    debugPrint('🕐 Starting daily summary scheduler...');
    _isRunning = true;

    // Schedule next run at 11:59 PM
    _scheduleNextRun();

    debugPrint('✅ Daily summary scheduler started');
  }

  void _scheduleNextRun() {
    final now = DateTime.now();

    // Calculate next 11:59 PM
    DateTime nextRun = DateTime(
      now.year,
      now.month,
      now.day,
      23, // 11 PM
      59, // 59 minutes
      0,  // 0 seconds
    );

    // If it's already past 11:59 PM today, schedule for tomorrow
    if (now.isAfter(nextRun)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    final duration = nextRun.difference(now);

    debugPrint('📅 Next daily summary computation scheduled for: ${nextRun.toString()}');
    debugPrint('⏰ Time until next run: ${duration.inHours}h ${duration.inMinutes % 60}m');

    // Cancel existing timer if any
    _dailyTimer?.cancel();

    // Schedule the task
    _dailyTimer = Timer(duration, () async {
      await _runDailyComputation();
      // Schedule the next run (tomorrow at 11:59 PM)
      _scheduleNextRun();
    });
  }

  /// Execute the daily summary computation
  Future<void> _runDailyComputation() async {
    try {
      final today = DateTime.now();
      debugPrint('🔄 Running daily summary computation for ${today.toString().split(' ')[0]}...');

      // Compute summary for today (12:00 AM to 11:59 PM)
      final success = await _firestoreService.createDailySummary(today);

      if (success) {
        debugPrint('✅ Daily summary computation completed successfully!');
      } else {
        debugPrint('⚠️ Daily summary computation completed but no data found for today');
      }
    } catch (e) {
      debugPrint('❌ Error in daily summary computation: $e');
    }
  }

  /// Manually trigger computation for today
  Future<void> computeToday() async {
    debugPrint('🔄 Manual trigger: Computing daily summary for today...');
    await _runDailyComputation();
  }

  /// Manually trigger computation for a specific date
  Future<void> computeForDate(DateTime date) async {
    debugPrint('🔄 Manual trigger: Computing daily summary for ${date.toString().split(' ')[0]}...');
    try {
      final success = await _firestoreService.createDailySummary(date);
      if (success) {
        debugPrint('✅ Daily summary computed for ${date.toString().split(' ')[0]}');
      } else {
        debugPrint('⚠️ No data found for ${date.toString().split(' ')[0]}');
      }
    } catch (e) {
      debugPrint('❌ Error computing summary for ${date.toString().split(' ')[0]}: $e');
    }
  }

  /// Stop the scheduler
  void stop() {
    if (!_isRunning) {
      debugPrint('⚠️ Daily summary scheduler is not running');
      return;
    }

    debugPrint('🛑 Stopping daily summary scheduler...');
    _dailyTimer?.cancel();
    _dailyTimer = null;
    _isRunning = false;
    debugPrint('✅ Daily summary scheduler stopped');
  }

  /// Check if scheduler is running
  bool get isRunning => _isRunning;
}
