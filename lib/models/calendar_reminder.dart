// lib/models/calendar_reminder.dart

import 'package:flutter/material.dart';

class CalendarReminder {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay time;
  final ReminderType type;
  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final bool notificationEnabled;
  final int reminderMinutesBefore;
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final DateTime createdAt;

  CalendarReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.type,
    this.isRecurring = false,
    this.recurrenceType,
    this.notificationEnabled = true,
    this.reminderMinutesBefore = 30,
    required this.icon,
    required this.color,
    this.isCompleted = false,
    required this.createdAt,
  });

  DateTime get scheduledDateTime {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime get notificationDateTime {
    return scheduledDateTime.subtract(Duration(minutes: reminderMinutesBefore));
  }

  bool get isPast {
    return scheduledDateTime.isBefore(DateTime.now());
  }

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get shouldNotify {
    if (!notificationEnabled || isCompleted) return false;
    final now = DateTime.now();
    return now.isAfter(notificationDateTime) && now.isBefore(scheduledDateTime);
  }

  CalendarReminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? time,
    ReminderType? type,
    bool? isRecurring,
    RecurrenceType? recurrenceType,
    bool? notificationEnabled,
    int? reminderMinutesBefore,
    IconData? icon,
    Color? color,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return CalendarReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'type': type.toString().split('.').last,
      'isRecurring': isRecurring,
      'recurrenceType': recurrenceType?.toString().split('.').last,
      'notificationEnabled': notificationEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CalendarReminder.fromJson(Map<String, dynamic> json) {
    return CalendarReminder(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      time: TimeOfDay(hour: json['timeHour'], minute: json['timeMinute']),
      type: ReminderType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ReminderType.general,
      ),
      isRecurring: json['isRecurring'] ?? false,
      recurrenceType: json['recurrenceType'] != null
          ? RecurrenceType.values.firstWhere(
              (e) => e.toString().split('.').last == json['recurrenceType'],
            )
          : null,
      notificationEnabled: json['notificationEnabled'] ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] ?? 30,
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue']),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

enum ReminderType {
  watering,
  fertilizing,
  pruning,
  harvesting,
  inspection,
  maintenance,
  general,
}

enum RecurrenceType { daily, weekly, biWeekly, monthly }

extension ReminderTypeExtension on ReminderType {
  String get displayName {
    switch (this) {
      case ReminderType.watering:
        return 'Watering';
      case ReminderType.fertilizing:
        return 'Fertilizing';
      case ReminderType.pruning:
        return 'Pruning';
      case ReminderType.harvesting:
        return 'Harvesting';
      case ReminderType.inspection:
        return 'Inspection';
      case ReminderType.maintenance:
        return 'Maintenance';
      case ReminderType.general:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderType.watering:
        return Icons.water_drop;
      case ReminderType.fertilizing:
        return Icons.science;
      case ReminderType.pruning:
        return Icons.cut;
      case ReminderType.harvesting:
        return Icons.agriculture;
      case ReminderType.inspection:
        return Icons.search;
      case ReminderType.maintenance:
        return Icons.build;
      case ReminderType.general:
        return Icons.event;
    }
  }

  Color get color {
    switch (this) {
      case ReminderType.watering:
        return Colors.blue;
      case ReminderType.fertilizing:
        return Colors.green;
      case ReminderType.pruning:
        return Colors.orange;
      case ReminderType.harvesting:
        return Colors.amber;
      case ReminderType.inspection:
        return Colors.purple;
      case ReminderType.maintenance:
        return Colors.grey;
      case ReminderType.general:
        return Colors.teal;
    }
  }
}

extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.biWeekly:
        return 'Bi-Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
    }
  }
}
