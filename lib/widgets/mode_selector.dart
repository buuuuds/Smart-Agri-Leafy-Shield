// widgets/mode_selector.dart - Widget para sa mode selection

import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final bool isAutoMode;
  final Function(bool) onModeChanged;

  const ModeSelector({
    super.key,
    required this.isAutoMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.settings, color: Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operation Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  Text(
                    isAutoMode
                        ? 'Automatic control enabled'
                        : 'Manual control enabled',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isAutoMode ? const Color(0xFF4CAF50) : Colors.grey[300],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Switch(
                value: isAutoMode,
                onChanged: onModeChanged,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF4CAF50),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
