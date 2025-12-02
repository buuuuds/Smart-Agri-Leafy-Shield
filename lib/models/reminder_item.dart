// lib/models/reminder_item.dart

import 'package:flutter/material.dart';

class ReminderItem {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool hasAction;
  final String actionText;
  final VoidCallback? onAction;

  ReminderItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.hasAction = false,
    this.actionText = '',
    this.onAction,
  });
}
