// services/plant_service.dart - IMPROVED: Better validation & default plants

import '../models/plant_model.dart';

class PlantService {
  static final List<Plant> _plants = [
    Plant(
      id: '1',
      name: 'Pechay',
      emoji: '🥬',
      minTemperature: 15.0,
      maxTemperature: 25.0,
      optimalTemperature: 20.0,
      minSoilMoisture: 40, // IMPROVED: Changed from 400 to percentage
      maxSoilMoisture: 80,
      minHumidity: 60,
      maxHumidity: 80,
      minLightIntensity: 5000,
      maxLightIntensity: 15000,
      description:
          'Pechay is a leafy vegetable that grows well in cool conditions. It prefers consistent moisture and partial shade during hot weather.',
      tips: [
        'Water regularly but avoid waterlogging',
        'Harvest after 30-45 days',
        'Prefers shaded areas during hot weather',
        'Grows best in rich, well-draining soil',
      ],
    ),
    Plant(
      id: '2',
      name: 'Lettuce',
      emoji: '🥗',
      minTemperature: 10.0,
      maxTemperature: 20.0,
      optimalTemperature: 15.0,
      minSoilMoisture: 35,
      maxSoilMoisture: 70,
      minHumidity: 50,
      maxHumidity: 70,
      minLightIntensity: 5000,
      maxLightIntensity: 15000,
      description:
          'Lettuce is a cool-season crop sensitive to heat. Perfect for salads and sandwiches.',
      tips: [
        'Plant during cool season',
        'Harvest outer leaves first',
        'Needs consistent moisture',
        'Protect from direct afternoon sunlight',
      ],
    ),
    Plant(
      id: '3',
      name: 'Spinach',
      emoji: '🌿',
      minTemperature: 12.0,
      maxTemperature: 22.0,
      optimalTemperature: 17.0,
      minSoilMoisture: 45,
      maxSoilMoisture: 75,
      minHumidity: 55,
      maxHumidity: 75,
      minLightIntensity: 5000,
      maxLightIntensity: 12000,
      description:
          'Spinach is a nutritious leafy green that grows quickly. Rich in iron and vitamins.',
      tips: [
        'Harvest young leaves for tender taste',
        'Successive planting every 2 weeks',
        'Bolts quickly in hot weather',
        'Good companion with tomatoes',
      ],
    ),
  ];

  // Get all plants
  static List<Plant> getAllPlants() {
    return List.from(_plants);
  }

  // Get plant by ID
  static Plant? getPlantById(String id) {
    try {
      return _plants.firstWhere((plant) => plant.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get plant by name
  static Plant? getPlantByName(String name) {
    try {
      return _plants.firstWhere(
        (plant) => plant.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // IMPROVED: Validate plant data
  static bool validatePlant(Plant plant) {
    if (plant.name.isEmpty) return false;
    if (plant.emoji.isEmpty) return false;
    if (plant.minTemperature >= plant.maxTemperature) return false;
    if (plant.optimalTemperature < plant.minTemperature ||
        plant.optimalTemperature > plant.maxTemperature)
      return false;
    if (plant.minSoilMoisture >= plant.maxSoilMoisture) return false;
    if (plant.minHumidity >= plant.maxHumidity) return false;
    if (plant.minLightIntensity >= plant.maxLightIntensity) return false;
    return true;
  }

  // Add new plant with validation
  static bool addPlant(Plant plant) {
    if (!validatePlant(plant)) {
      return false;
    }

    // IMPROVED: Check for duplicates
    if (_plants.any((p) => p.id == plant.id)) {
      return false;
    }

    _plants.add(plant);
    return true;
  }

  // Update plant
  static bool updatePlant(String id, Plant updatedPlant) {
    if (!validatePlant(updatedPlant)) {
      return false;
    }

    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index != -1) {
      _plants[index] = updatedPlant;
      return true;
    }
    return false;
  }

  // Delete plant (prevent deleting default plants)
  static bool deletePlant(String id) {
    // IMPROVED: Protect default plants
    if (['1', '2', '3'].contains(id)) {
      return false;
    }

    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index != -1) {
      _plants.removeAt(index);
      return true;
    }
    return false;
  }

  // Generate unique ID
  static String generateId() {
    return 'plant_${DateTime.now().millisecondsSinceEpoch}';
  }

  // IMPROVED: Search plants
  static List<Plant> searchPlants(String query) {
    if (query.isEmpty) return getAllPlants();

    final lowercaseQuery = query.toLowerCase();
    return _plants.where((plant) {
      return plant.name.toLowerCase().contains(lowercaseQuery) ||
          plant.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get temperature status with color coding
  static TemperatureStatus getTemperatureStatus(
    Plant plant,
    double currentTemp,
  ) {
    if (currentTemp < plant.minTemperature) {
      return TemperatureStatus.cold;
    } else if (currentTemp > plant.maxTemperature) {
      return TemperatureStatus.hot;
    } else if (currentTemp >= plant.optimalTemperature - 2 &&
        currentTemp <= plant.optimalTemperature + 2) {
      return TemperatureStatus.optimal;
    } else {
      return TemperatureStatus.warning;
    }
  }

  // Get soil moisture status
  static SensorStatus getSoilMoistureStatus(Plant plant, int currentMoisture) {
    if (currentMoisture < plant.minSoilMoisture) {
      return SensorStatus.low;
    } else if (currentMoisture > plant.maxSoilMoisture) {
      return SensorStatus.high;
    } else {
      return SensorStatus.optimal;
    }
  }

  // Get humidity status
  static SensorStatus getHumidityStatus(Plant plant, int currentHumidity) {
    if (currentHumidity < plant.minHumidity) {
      return SensorStatus.low;
    } else if (currentHumidity > plant.maxHumidity) {
      return SensorStatus.high;
    } else {
      return SensorStatus.optimal;
    }
  }

  // Get light intensity status
  static SensorStatus getLightStatus(Plant plant, int currentLight) {
    if (currentLight < plant.minLightIntensity) {
      return SensorStatus.low;
    } else if (currentLight > plant.maxLightIntensity) {
      return SensorStatus.high;
    } else {
      return SensorStatus.optimal;
    }
  }

  // IMPROVED: Get overall plant health score (0-100)
  static int getPlantHealthScore(
    Plant plant, {
    required double? temperature,
    required int? soilMoisture,
    required int? humidity,
    required int? lightIntensity,
  }) {
    int score = 100;
    int factors = 0;

    if (temperature != null) {
      factors++;
      final tempStatus = getTemperatureStatus(plant, temperature);
      if (tempStatus == TemperatureStatus.cold ||
          tempStatus == TemperatureStatus.hot) {
        score -= 30;
      } else if (tempStatus == TemperatureStatus.warning) {
        score -= 15;
      }
    }

    if (soilMoisture != null) {
      factors++;
      final soilStatus = getSoilMoistureStatus(plant, soilMoisture);
      if (soilStatus == SensorStatus.low || soilStatus == SensorStatus.high) {
        score -= 25;
      }
    }

    if (humidity != null) {
      factors++;
      final humidityStatus = getHumidityStatus(plant, humidity);
      if (humidityStatus == SensorStatus.low ||
          humidityStatus == SensorStatus.high) {
        score -= 20;
      }
    }

    if (lightIntensity != null) {
      factors++;
      final lightStatus = getLightStatus(plant, lightIntensity);
      if (lightStatus == SensorStatus.low || lightStatus == SensorStatus.high) {
        score -= 25;
      }
    }

    return factors > 0 ? score.clamp(0, 100) : 0;
  }

  // IMPROVED: Get plant recommendations based on conditions
  static List<String> getRecommendations(
    Plant plant, {
    required double? temperature,
    required int? soilMoisture,
    required int? humidity,
    required int? lightIntensity,
  }) {
    List<String> recommendations = [];

    if (temperature != null) {
      if (temperature < plant.minTemperature) {
        recommendations.add('Increase temperature or move to warmer location');
      } else if (temperature > plant.maxTemperature) {
        recommendations.add('Reduce temperature or provide shade');
      }
    }

    if (soilMoisture != null) {
      if (soilMoisture < plant.minSoilMoisture) {
        recommendations.add('Increase watering frequency');
      } else if (soilMoisture > plant.maxSoilMoisture) {
        recommendations.add('Reduce watering or improve drainage');
      }
    }

    if (humidity != null) {
      if (humidity < plant.minHumidity) {
        recommendations.add('Increase humidity with misting or humidifier');
      } else if (humidity > plant.maxHumidity) {
        recommendations.add('Improve air circulation');
      }
    }

    if (lightIntensity != null) {
      if (lightIntensity < plant.minLightIntensity) {
        recommendations.add('Increase light exposure');
      } else if (lightIntensity > plant.maxLightIntensity) {
        recommendations.add('Provide shade during peak hours');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('Conditions are optimal - keep up the good work!');
    }

    return recommendations;
  }
}

enum TemperatureStatus { cold, optimal, warning, hot }

enum SensorStatus { low, optimal, high }
