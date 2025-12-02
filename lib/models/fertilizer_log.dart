// lib/models/fertilizer_log.dart - CREATE NEW FILE
class FertilizerLog {
  final String id;
  final DateTime date;
  final String type;
  final double amount;
  final String method;
  final String notes;
  final String plantName;

  FertilizerLog({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.method,
    this.notes = '',
    required this.plantName,
  });

  factory FertilizerLog.fromJson(Map<String, dynamic> json) {
    return FertilizerLog(
      id: json['id'],
      date: DateTime.parse(json['date']),
      type: json['type'],
      amount: json['amount'].toDouble(),
      method: json['method'],
      notes: json['notes'] ?? '',
      plantName: json['plantName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type,
      'amount': amount,
      'method': method,
      'notes': notes,
      'plantName': plantName,
    };
  }
}
