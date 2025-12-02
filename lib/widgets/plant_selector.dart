// widgets/plant_selector.dart - AUTO-REFRESH

import 'package:flutter/material.dart';
import '../services/plant_service.dart';
import '../services/firestore_service.dart';

class PlantSelector extends StatefulWidget {
  final String selectedPlant;
  final Function(String) onPlantChanged;

  const PlantSelector({
    super.key,
    required this.selectedPlant,
    required this.onPlantChanged,
  });

  @override
  State<PlantSelector> createState() => _PlantSelectorState();
}

class _PlantSelectorState extends State<PlantSelector>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshPlants();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _refreshPlants();
    }
  }

  Future<void> _refreshPlants() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final customPlants = await _firestoreService.getCustomPlants(
        forceRefresh: true,
      );

      for (final plant in customPlants) {
        PlantService.addPlant(plant);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint(
          '✅ Plant selector refreshed: ${customPlants.length} custom plants',
        );
      }
    } catch (e) {
      debugPrint('Error refreshing plants: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final plants = PlantService.getAllPlants();

    String currentSelection = widget.selectedPlant;
    if (!plants.any((p) => p.name == currentSelection)) {
      currentSelection = plants.first.name;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.eco, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Selected Plant',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    if (!_isLoading)
                      InkWell(
                        onTap: _refreshPlants,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                DropdownButton<String>(
                  value: currentSelection,
                  dropdownColor: const Color(0xFF4CAF50),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  underline: Container(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  items: plants.map((plant) {
                    return DropdownMenuItem(
                      value: plant.name,
                      child: Text('${plant.emoji} ${plant.name}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      widget.onPlantChanged(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
