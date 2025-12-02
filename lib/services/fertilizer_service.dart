// lib/services/fertilizer_service.dart - MODIFIED: Private add/delete methods

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/fertilizer_log.dart';

class FertilizerService {
  static final FertilizerService _instance = FertilizerService._internal();
  factory FertilizerService() => _instance;
  FertilizerService._internal();

  static const String _logsKey = 'fertilizer_logs';
  static const String _lastDateKey = 'last_fertilized_date';

  List<FertilizerLog> _logs = [];
  DateTime? _lastFertilizedDate;

  List<FertilizerLog> get logs => List.unmodifiable(_logs);
  DateTime? get lastFertilizedDate => _lastFertilizedDate;

  int get daysSinceLastFertilizer {
    if (_lastFertilizedDate == null) return 999;
    return DateTime.now().difference(_lastFertilizedDate!).inDays;
  }

  bool get needsFertilizer => daysSinceLastFertilizer >= 14;

  Future<void> initialize() async {
    await _loadLogs();
    await _loadLastDate();
  }

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? logsJson = prefs.getString(_logsKey);

      if (logsJson != null) {
        final List<dynamic> logsList = json.decode(logsJson);
        _logs = logsList.map((item) => FertilizerLog.fromJson(item)).toList();
        _logs.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (e) {
      debugPrint('Failed to load fertilizer logs: $e');
    }
  }

  Future<void> _loadLastDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dateStr = prefs.getString(_lastDateKey);
      if (dateStr != null) {
        _lastFertilizedDate = DateTime.parse(dateStr);
      }
    } catch (e) {
      debugPrint('Failed to load last fertilizer date: $e');
    }
  }

  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String logsJson = json.encode(
        _logs.map((log) => log.toJson()).toList(),
      );
      await prefs.setString(_logsKey, logsJson);
    } catch (e) {
      debugPrint('Failed to save fertilizer logs: $e');
    }
  }

  Future<void> _saveLastDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastFertilizedDate != null) {
        await prefs.setString(
          _lastDateKey,
          _lastFertilizedDate!.toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Failed to save last fertilizer date: $e');
    }
  }

  // ✅ PRIVATE - No longer accessible from UI
  Future<void> _addLog(FertilizerLog log) async {
    _logs.insert(0, log);

    if (_lastFertilizedDate == null || log.date.isAfter(_lastFertilizedDate!)) {
      _lastFertilizedDate = log.date;
      await _saveLastDate();
    }

    if (_logs.length > 100) {
      _logs = _logs.sublist(0, 100);
    }

    await _saveLogs();
    debugPrint('✅ Fertilizer log added: ${log.type}');
  }

  // ✅ PRIVATE - No longer accessible from UI
  Future<void> _deleteLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
    await _saveLogs();

    if (_logs.isNotEmpty) {
      _lastFertilizedDate = _logs.first.date;
    } else {
      _lastFertilizedDate = null;
    }
    await _saveLastDate();
  }

  // ✅ PUBLIC - Still accessible for reading
  List<FertilizerLog> getLogsForPlant(String plantName) {
    return _logs.where((log) => log.plantName == plantName).toList();
  }

  List<FertilizerLog> getRecentLogs({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _logs.where((log) => log.date.isAfter(cutoff)).toList();
  }
}
