// models/plant_model.dart - Plant data model para sa CRUD operations

class Plant {
  final String id;
  final String name;
  final String emoji;
  final double minTemperature;
  final double maxTemperature;
  final double optimalTemperature;
  final int minSoilMoisture;
  final int maxSoilMoisture;
  final int minHumidity;
  final int maxHumidity;
  final int minLightIntensity;
  final int maxLightIntensity;
  final String description;
  final List<String> tips;

  Plant({
    required this.id,
    required this.name,
    required this.emoji,
    required this.minTemperature,
    required this.maxTemperature,
    required this.optimalTemperature,
    required this.minSoilMoisture,
    required this.maxSoilMoisture,
    required this.minHumidity,
    required this.maxHumidity,
    required this.minLightIntensity,
    required this.maxLightIntensity,
    required this.description,
    required this.tips,
  });

  // Factory constructor para sa JSON
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'],
      minTemperature: json['minTemperature'].toDouble(),
      maxTemperature: json['maxTemperature'].toDouble(),
      optimalTemperature: json['optimalTemperature'].toDouble(),
      minSoilMoisture: json['minSoilMoisture'],
      maxSoilMoisture: json['maxSoilMoisture'],
      minHumidity: json['minHumidity'],
      maxHumidity: json['maxHumidity'],
      minLightIntensity: json['minLightIntensity'],
      maxLightIntensity: json['maxLightIntensity'],
      description: json['description'],
      tips: List<String>.from(json['tips']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'minTemperature': minTemperature,
      'maxTemperature': maxTemperature,
      'optimalTemperature': optimalTemperature,
      'minSoilMoisture': minSoilMoisture,
      'maxSoilMoisture': maxSoilMoisture,
      'minHumidity': minHumidity,
      'maxHumidity': maxHumidity,
      'minLightIntensity': minLightIntensity,
      'maxLightIntensity': maxLightIntensity,
      'description': description,
      'tips': tips,
    };
  }

  // Copy with method para sa updates
  Plant copyWith({
    String? id,
    String? name,
    String? emoji,
    double? minTemperature,
    double? maxTemperature,
    double? optimalTemperature,
    int? minSoilMoisture,
    int? maxSoilMoisture,
    int? minHumidity,
    int? maxHumidity,
    int? minLightIntensity,
    int? maxLightIntensity,
    String? description,
    List<String>? tips,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      optimalTemperature: optimalTemperature ?? this.optimalTemperature,
      minSoilMoisture: minSoilMoisture ?? this.minSoilMoisture,
      maxSoilMoisture: maxSoilMoisture ?? this.maxSoilMoisture,
      minHumidity: minHumidity ?? this.minHumidity,
      maxHumidity: maxHumidity ?? this.maxHumidity,
      minLightIntensity: minLightIntensity ?? this.minLightIntensity,
      maxLightIntensity: maxLightIntensity ?? this.maxLightIntensity,
      description: description ?? this.description,
      tips: tips ?? this.tips,
    );
  }
}
