// screens/plant_management_page.dart - SHOWS DEFAULT + CUSTOM PLANTS

import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../services/plant_service.dart';
import '../services/firestore_service.dart';

class PlantManagementPage extends StatefulWidget {
  const PlantManagementPage({super.key});

  @override
  State<PlantManagementPage> createState() => _PlantManagementPageState();
}

class _PlantManagementPageState extends State<PlantManagementPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirestoreService _firestoreService = FirestoreService();
  List<Plant> customPlants = [];
  List<Plant> defaultPlants = [];
  bool isLoading = true;

  // Track deleting plants for loading indicators
  Set<String> deletingPlantIds = {};

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() => isLoading = true);

    try {
      // ✅ LOAD DEFAULT PLANTS from PlantService
      defaultPlants = PlantService.getAllPlants()
          .where((p) => !p.id.startsWith('custom_'))
          .toList();

      // ✅ LOAD CUSTOM PLANTS from Firestore
      final loadedCustomPlants = await _firestoreService.getCustomPlants(
        forceRefresh: true,
      );

      // Add to PlantService for app-wide access
      for (final plant in loadedCustomPlants) {
        PlantService.addPlant(plant);
      }

      setState(() {
        customPlants = loadedCustomPlants;
      });

      debugPrint(
        '✅ Loaded ${defaultPlants.length} default + ${customPlants.length} custom plants',
      );
    } catch (e) {
      debugPrint('Failed to load plants: $e');
      _showErrorSnackBar('Failed to load plants: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showAddPlantDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPlantDialog(
        onPlantAdded: (plant) async {
          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          try {
            // SAVE TO FIRESTORE
            final success = await _firestoreService.addCustomPlant(plant);

            if (mounted) Navigator.pop(context); // Close loading

            if (success) {
              setState(() {
                customPlants.add(plant);
              });
              PlantService.addPlant(plant);
              _showSuccessSnackBar('${plant.name} saved to cloud! ☁️');
            } else {
              _showErrorSnackBar('Failed to save ${plant.name} to cloud');
            }
          } catch (e) {
            if (mounted) Navigator.pop(context);
            _showErrorSnackBar('Error: $e');
          }
        },
      ),
    );
  }

  void _editPlant(Plant plant) {
    showDialog(
      context: context,
      builder: (context) => AddPlantDialog(
        plant: plant,
        onPlantAdded: (updatedPlant) async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          try {
            // UPDATE IN FIRESTORE
            final success = await _firestoreService.updateCustomPlant(
              plant.id,
              updatedPlant,
            );

            if (mounted) Navigator.pop(context);

            if (success) {
              setState(() {
                final index = customPlants.indexWhere((p) => p.id == plant.id);
                if (index != -1) {
                  customPlants[index] = updatedPlant;
                }
              });
              PlantService.updatePlant(plant.id, updatedPlant);
              _showSuccessSnackBar('${updatedPlant.name} updated in cloud! ☁️');
            } else {
              _showErrorSnackBar('Failed to update ${updatedPlant.name}');
            }
          } catch (e) {
            if (mounted) Navigator.pop(context);
            _showErrorSnackBar('Error: $e');
          }
        },
      ),
    );
  }

  // OPTIMIZED DELETE: Instant UI update with rollback on error
  void _deletePlant(Plant plant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(plant.emoji),
            const SizedBox(width: 8),
            Text('Delete ${plant.name}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete ${plant.name} from the cloud.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog immediately

              // OPTIMISTIC UI: Delete from UI instantly
              setState(() {
                deletingPlantIds.add(plant.id);
                customPlants.removeWhere((p) => p.id == plant.id);
              });
              PlantService.deletePlant(plant.id);

              // Show deleting message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Deleting ${plant.name} from cloud...'),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );

              // DELETE FROM FIRESTORE in background
              try {
                final success = await _firestoreService.deleteCustomPlant(
                  plant.id,
                );

                if (mounted) {
                  setState(() {
                    deletingPlantIds.remove(plant.id);
                  });

                  if (success) {
                    _showSuccessSnackBar(
                      '${plant.name} deleted from cloud! ☁️',
                    );
                  } else {
                    // ROLLBACK: Restore plant on failure
                    setState(() {
                      customPlants.add(plant);
                      customPlants.sort((a, b) => a.name.compareTo(b.name));
                    });
                    PlantService.addPlant(plant);
                    _showErrorSnackBar(
                      'Failed to delete ${plant.name}. Restored.',
                    );
                  }
                }
              } catch (e) {
                // ROLLBACK on error
                if (mounted) {
                  setState(() {
                    deletingPlantIds.remove(plant.id);
                    customPlants.add(plant);
                    customPlants.sort((a, b) => a.name.compareTo(b.name));
                  });
                  PlantService.addPlant(plant);
                  _showErrorSnackBar('Error deleting ${plant.name}. Restored.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌱 Plant Library',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${defaultPlants.length} default • ${customPlants.length} custom',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _showAddPlantDialog,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Add Plant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF4CAF50)),
                          SizedBox(height: 16),
                          Text('Loading plants...'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPlants,
                      color: const Color(0xFF4CAF50),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          // ✅ DEFAULT PLANTS SECTION
                          if (defaultPlants.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Default Plants',
                              subtitle: 'Built-in plant profiles',
                              icon: Icons.star,
                              isDarkMode: isDarkMode,
                            ),
                            ...defaultPlants.map(
                              (plant) => _PlantCard(
                                plant: plant,
                                isDefault: true,
                                isDeleting: false,
                                isDarkMode: isDarkMode,
                                onEdit: null, // Can't edit default plants
                                onDelete: null, // Can't delete default plants
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ✅ CUSTOM PLANTS SECTION
                          _SectionHeader(
                            title: 'Custom Plants',
                            subtitle: customPlants.isEmpty
                                ? 'No custom plants yet'
                                : '${customPlants.length} plant${customPlants.length == 1 ? '' : 's'}',
                            icon: Icons.eco,
                            isDarkMode: isDarkMode,
                          ),

                          if (customPlants.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tap "Add Plant" to create\nyour first custom plant',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...customPlants.map(
                              (plant) => _PlantCard(
                                plant: plant,
                                isDefault: false,
                                isDeleting: deletingPlantIds.contains(plant.id),
                                isDarkMode: isDarkMode,
                                onEdit: () => _editPlant(plant),
                                onDelete: () => _deletePlant(plant),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SECTION HEADER WIDGET
// ============================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDarkMode;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PLANT CARD WIDGET
// ============================================

class _PlantCard extends StatelessWidget {
  final Plant plant;
  final bool isDefault;
  final bool isDeleting;
  final bool isDarkMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PlantCard({
    required this.plant,
    required this.isDefault,
    required this.isDeleting,
    required this.isDarkMode,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        elevation: isDeleting ? 1 : 3,
        child: Stack(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    plant.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      plant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'DEFAULT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    plant.description.isEmpty
                        ? 'No description'
                        : plant.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.thermostat,
                        '${plant.minTemperature.toInt()}-${plant.maxTemperature.toInt()}°C',
                        Colors.orange,
                      ),
                      _buildInfoChip(
                        Icons.water_drop,
                        '${plant.minSoilMoisture}-${plant.maxSoilMoisture}%',
                        Colors.blue,
                      ),
                      _buildInfoChip(
                        Icons.opacity,
                        '${plant.minHumidity}-${plant.maxHumidity}%',
                        Colors.teal,
                      ),
                      _buildInfoChip(
                        Icons.wb_sunny,
                        '${plant.minLightIntensity}-${plant.maxLightIntensity} lux',
                        Colors.amber,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: isDeleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4CAF50),
                      ),
                    )
                  : (isDefault
                        ? Icon(
                            Icons.lock_outline,
                            color: Colors.grey[400],
                            size: 24,
                          )
                        : PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'edit' && onEdit != null) {
                                onEdit!();
                              } else if (value == 'delete' &&
                                  onDelete != null) {
                                onDelete!();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 12),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          )),
            ),
            // Overlay when deleting
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ADD PLANT DIALOG (unchanged)

class AddPlantDialog extends StatefulWidget {
  final Plant? plant;
  final Function(Plant) onPlantAdded;

  const AddPlantDialog({super.key, this.plant, required this.onPlantAdded});

  @override
  State<AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<AddPlantDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emojiController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<TextEditingController> _tipControllers = [];

  double _minTemp = 15.0;
  double _maxTemp = 30.0;
  double _optimalTemp = 22.0;
  int _minSoilMoisture = 40;
  int _maxSoilMoisture = 80;
  int _minHumidity = 60;
  int _maxHumidity = 80;
  int _minLight = 800;
  int _maxLight = 1500;

  @override
  void initState() {
    super.initState();

    if (widget.plant != null) {
      _nameController.text = widget.plant!.name;
      _emojiController.text = widget.plant!.emoji;
      _descriptionController.text = widget.plant!.description;
      _minTemp = widget.plant!.minTemperature;
      _maxTemp = widget.plant!.maxTemperature;
      _optimalTemp = widget.plant!.optimalTemperature;
      _minSoilMoisture = widget.plant!.minSoilMoisture;
      _maxSoilMoisture = widget.plant!.maxSoilMoisture;
      _minHumidity = widget.plant!.minHumidity;
      _maxHumidity = widget.plant!.maxHumidity;
      _minLight = widget.plant!.minLightIntensity;
      _maxLight = widget.plant!.maxLightIntensity;

      for (String tip in widget.plant!.tips) {
        _tipControllers.add(TextEditingController(text: tip));
      }
    }

    if (_tipControllers.isEmpty) {
      _tipControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _descriptionController.dispose();
    for (var controller in _tipControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTipField() {
    setState(() {
      _tipControllers.add(TextEditingController());
    });
  }

  void _removeTipField(int index) {
    if (_tipControllers.length > 1) {
      setState(() {
        _tipControllers[index].dispose();
        _tipControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plant == null ? 'Add New Plant' : 'Edit Plant'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Plant Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_florist),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter plant name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emojiController,
                  decoration: const InputDecoration(
                    labelText: 'Plant Emoji *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.emoji_emotions),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter an emoji';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Temperature Range (°C)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Min: ${_minTemp.toInt()}°C'),
                Slider(
                  value: _minTemp,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  onChanged: (value) {
                    setState(() {
                      _minTemp = value;
                      // ✅ Auto-adjust if min > max
                      if (_minTemp > _maxTemp) {
                        _maxTemp = _minTemp;
                      }
                      // ✅ Keep optimal in range
                      if (_optimalTemp < _minTemp) {
                        _optimalTemp = _minTemp;
                      }
                      if (_optimalTemp > _maxTemp) {
                        _optimalTemp = _maxTemp;
                      }
                    });
                  },
                ),
                Text('Max: ${_maxTemp.toInt()}°C'),
                Slider(
                  value: _maxTemp,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  onChanged: (value) {
                    setState(() {
                      _maxTemp = value;
                      // ✅ Auto-adjust if max < min
                      if (_maxTemp < _minTemp) {
                        _minTemp = _maxTemp;
                      }
                      // ✅ Keep optimal in range
                      if (_optimalTemp < _minTemp) {
                        _optimalTemp = _minTemp;
                      }
                      if (_optimalTemp > _maxTemp) {
                        _optimalTemp = _maxTemp;
                      }
                    });
                  },
                ),
                Text('Optimal: ${_optimalTemp.toInt()}°C'),
                Slider(
                  value: _optimalTemp.clamp(_minTemp, _maxTemp),
                  min: _minTemp,
                  max: _maxTemp,
                  divisions: (_maxTemp - _minTemp) > 0
                      ? (_maxTemp - _minTemp).toInt().clamp(1, 100)
                      : 1,
                  onChanged: (_maxTemp > _minTemp)
                      ? (value) => setState(() => _optimalTemp = value)
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Soil Moisture Range (%)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Min: $_minSoilMoisture%'),
                Slider(
                  value: _minSoilMoisture.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _minSoilMoisture = value.toInt();
                      // ✅ Auto-adjust if min > max
                      if (_minSoilMoisture > _maxSoilMoisture) {
                        _maxSoilMoisture = _minSoilMoisture;
                      }
                    });
                  },
                ),
                Text('Max: $_maxSoilMoisture%'),
                Slider(
                  value: _maxSoilMoisture.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _maxSoilMoisture = value.toInt();
                      // ✅ Auto-adjust if max < min
                      if (_maxSoilMoisture < _minSoilMoisture) {
                        _minSoilMoisture = _maxSoilMoisture;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Humidity Range (%)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Min: $_minHumidity%'),
                Slider(
                  value: _minHumidity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _minHumidity = value.toInt();
                      // ✅ Auto-adjust if min > max
                      if (_minHumidity > _maxHumidity) {
                        _maxHumidity = _minHumidity;
                      }
                    });
                  },
                ),
                Text('Max: $_maxHumidity%'),
                Slider(
                  value: _maxHumidity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _maxHumidity = value.toInt();
                      // ✅ Auto-adjust if max < min
                      if (_maxHumidity < _minHumidity) {
                        _minHumidity = _maxHumidity;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Light Intensity Range (lux)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Min: $_minLight lux'),
                Slider(
                  value: _minLight.toDouble(),
                  min: 0,
                  max: 50000,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _minLight = value.toInt();
                      // ✅ Auto-adjust if min > max
                      if (_minLight > _maxLight) {
                        _maxLight = _minLight;
                      }
                    });
                  },
                ),
                Text('Max: $_maxLight lux'),
                Slider(
                  value: _maxLight.toDouble(),
                  min: 0,
                  max: 50000,
                  divisions: 100,
                  onChanged: (value) {
                    setState(() {
                      _maxLight = value.toInt();
                      // ✅ Auto-adjust if max < min
                      if (_maxLight < _minLight) {
                        _minLight = _maxLight;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Care Tips',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._tipControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  TextEditingController controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Tip ${index + 1}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lightbulb_outline),
                        suffixIcon: _tipControllers.length > 1
                            ? IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeTipField(index),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: _addTipField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Tip'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final tips = _tipControllers
                  .map((controller) => controller.text)
                  .where((tip) => tip.isNotEmpty)
                  .toList();

              final plant = Plant(
                id:
                    widget.plant?.id ??
                    'custom_${DateTime.now().millisecondsSinceEpoch}',
                name: _nameController.text,
                emoji: _emojiController.text,
                minTemperature: _minTemp,
                maxTemperature: _maxTemp,
                optimalTemperature: _optimalTemp,
                minSoilMoisture: _minSoilMoisture,
                maxSoilMoisture: _maxSoilMoisture,
                minHumidity: _minHumidity,
                maxHumidity: _maxHumidity,
                minLightIntensity: _minLight,
                maxLightIntensity: _maxLight,
                description: _descriptionController.text,
                tips: tips,
              );

              widget.onPlantAdded(plant);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.plant == null ? 'Add Plant' : 'Update Plant'),
        ),
      ],
    );
  }
}
