// widgets/pump_mode_selector.dart - Widget for selecting pump operation mode

import 'package:flutter/material.dart';

class PumpModeSelector extends StatelessWidget {
  final String selectedMode;
  final Function(String) onModeChanged;

  const PumpModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water_drop,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Water Pump Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        _getModeDescription(selectedMode),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    'Soil',
                    'soil',
                    Icons.grass,
                    'Monitors soil moisture',
                    context,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeButton(
                    'Cycle',
                    'cycle',
                    Icons.timer,
                    'Fixed time intervals',
                    context,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String label,
    String mode,
    IconData icon,
    String description,
    BuildContext context,
  ) {
    final isSelected = selectedMode == mode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : (isDarkMode ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF4CAF50)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFF2E7D32)
                    : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeDescription(String mode) {
    switch (mode) {
      case 'soil':
        return 'Pump activates when soil moisture is low';
      case 'cycle':
        return 'Pump runs on fixed time cycles';
      case 'manual':
        return 'Manual control only';
      default:
        return 'Unknown mode';
    }
  }
}
