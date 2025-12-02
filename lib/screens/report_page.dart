// screens/report_page.dart - WITH PULL-TO-REFRESH + REFRESH BUTTON

import 'package:flutter/material.dart';
import '../services/plant_service.dart';
import '../models/plant_model.dart';
import '../services/firestore_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Plant _selectedPlant;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedPlant = PlantService.getAllPlants().first;
    _refreshPlantList();
  }

  // ✅ FIX: Refresh plant list when page is visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPlantList();
  }

  // ✅ IMPROVED: Async refresh with loading state
  Future<void> _refreshPlantList() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Load custom plants from Firestore
      final customPlants = await _firestoreService.getCustomPlants(
        forceRefresh: true,
      );

      // Add them to PlantService
      for (final plant in customPlants) {
        PlantService.addPlant(plant);
      }

      // Get all plants
      final plants = PlantService.getAllPlants();

      // Check if current plant still exists
      final currentExists = plants.any((p) => p.id == _selectedPlant.id);

      if (!currentExists && plants.isNotEmpty) {
        // Current plant was deleted, select first available
        if (mounted) {
          setState(() {
            _selectedPlant = plants.first;
          });
        }
      }

      debugPrint(
        '✅ Report page: Refreshed plant list (${plants.length} plants)',
      );
    } catch (e) {
      debugPrint('❌ Error refreshing plants: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ✅ FIX: Get fresh plant list every build
    List<Plant> allPlants = PlantService.getAllPlants();

    // ✅ FIX: Verify selected plant still exists
    if (!allPlants.any((p) => p.id == _selectedPlant.id)) {
      _selectedPlant = allPlants.first;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
              : [const Color(0xFFF8FAF8), const Color(0xFFE8F5E8)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ DROPDOWN WITH REFRESH BUTTON
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2D2D2D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? const Color(0xFF4CAF50).withOpacity(0.5)
                              : Colors.green.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black26
                                : Colors.green.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Plant>(
                          value: _selectedPlant,
                          isExpanded: true,
                          dropdownColor: isDarkMode
                              ? const Color(0xFF2D2D2D)
                              : Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDarkMode
                                ? const Color(0xFF4CAF50)
                                : Colors.green,
                          ),
                          items: allPlants.map((plant) {
                            return DropdownMenuItem(
                              value: plant,
                              child: Row(
                                children: [
                                  Text(
                                    plant.emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      plant.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  // ✅ Show "Custom" badge for custom plants
                                  if (plant.id.startsWith('custom_')) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4CAF50,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Custom',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF4CAF50),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (Plant? newPlant) {
                            if (newPlant != null) {
                              setState(() {
                                _selectedPlant = newPlant;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ REFRESH BUTTON
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            )
                          : const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
                      onPressed: _isRefreshing ? null : _refreshPlantList,
                      tooltip: 'Refresh plant list',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshPlantList,
                  color: const Color(0xFF4CAF50),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Text(
                          '${_selectedPlant.emoji} ${_selectedPlant.name} Care Guide',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2E7D32),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        _RangeCard(
                          title: "Temperature",
                          icon: Icons.thermostat,
                          range:
                              "${_selectedPlant.minTemperature}°C - ${_selectedPlant.maxTemperature}°C (Optimal: ${_selectedPlant.optimalTemperature}°C)",
                          color: Colors.orange,
                          isDarkMode: isDarkMode,
                        ),
                        _RangeCard(
                          title: "Soil Moisture",
                          icon: Icons.water_drop,
                          range:
                              "${_selectedPlant.minSoilMoisture}% - ${_selectedPlant.maxSoilMoisture}%",
                          color: Colors.blue,
                          isDarkMode: isDarkMode,
                        ),
                        _RangeCard(
                          title: "Humidity",
                          icon: Icons.cloud,
                          range:
                              "${_selectedPlant.minHumidity}% - ${_selectedPlant.maxHumidity}%",
                          color: Colors.teal,
                          isDarkMode: isDarkMode,
                        ),
                        _RangeCard(
                          title: "Light Intensity",
                          icon: Icons.wb_sunny,
                          range:
                              "${_selectedPlant.minLightIntensity} - ${_selectedPlant.maxLightIntensity} lux",
                          color: Colors.yellow[800]!,
                          isDarkMode: isDarkMode,
                        ),

                        const SizedBox(height: 20),

                        Text(
                          _selectedPlant.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),

                        ..._selectedPlant.tips.map(
                          (tip) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: isDarkMode
                                      ? const Color(0xFF4CAF50)
                                      : Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  final String title;
  final String range;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  const _RangeCard({
    required this.title,
    required this.range,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        subtitle: Text(
          range,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.black87,
          ),
        ),
      ),
    );
  }
}
