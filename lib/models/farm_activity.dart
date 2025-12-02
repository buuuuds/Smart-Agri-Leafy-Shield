// lib/models/farm_activity.dart

class FarmActivity {
  final String id;
  final String deviceId;
  final DateTime date;
  final DateTime timestamp;
  final String type; // fertilizer, planting, harvest, pruning, pest, maintenance, general
  final String title;
  final String description;
  final DateTime createdAt;

  FarmActivity({
    required this.id,
    required this.deviceId,
    required this.date,
    required this.timestamp,
    required this.type,
    required this.title,
    this.description = '',
    required this.createdAt,
  });

  factory FarmActivity.fromJson(String id, Map<String, dynamic> json) {
    return FarmActivity(
      id: id,
      deviceId: json['deviceId'] as String,
      date: DateTime.parse(json['date'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'date': _formatDate(date),
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  FarmActivity copyWith({
    String? id,
    String? deviceId,
    DateTime? date,
    DateTime? timestamp,
    String? type,
    String? title,
    String? description,
    DateTime? createdAt,
  }) {
    return FarmActivity(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
