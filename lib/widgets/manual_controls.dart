import 'package:flutter/material.dart';

class ManualControls extends StatefulWidget {
  final Function(String) onShadeCommand;
  final Function(String) onPumpCommand;
  final bool isConnected; // ✅ NEW: ESP32 connection status

  const ManualControls({
    super.key,
    required this.onShadeCommand,
    required this.onPumpCommand,
    this.isConnected = true, // Default to true for backward compatibility
  });

  @override
  State<ManualControls> createState() => _ManualControlsState();
}

class _ManualControlsState extends State<ManualControls> {
  String selectedPumpMode = "irrigation"; // "irrigation" or "misting"

  // State tracking para sa buttons
  bool isPumpRunning = false;
  bool isShadeDeployed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app, color: Color(0xFF2E7D32)),
                const SizedBox(width: 12),
                const Text(
                  'Manual Controls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'MANUAL MODE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ CONNECTION WARNING when offline
            if (!widget.isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ESP32 Offline - Controls Disabled',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // PUMP MODE SELECTOR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.water_drop,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Pump Mode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPumpModeButton(
                          'Irrigation',
                          '💧 30s',
                          'irrigation',
                          Icons.water_drop,
                          Colors.blue,
                          isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPumpModeButton(
                          'Misting',
                          '💨 15s',
                          'misting',
                          Icons.cloud,
                          Colors.cyan,
                          isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PUMP CONTROLS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isPumpRunning || !widget.isConnected)
                        ? null // Disabled kung tumatakbo na OR offline
                        : () {
                            setState(() {
                              isPumpRunning = true;
                            });
                            widget.onPumpCommand('${selectedPumpMode}_start');
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      'Start ${selectedPumpMode == "irrigation" ? "Irrigation" : "Misting"}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedPumpMode == "irrigation"
                          ? Colors.blue
                          : Colors.cyan,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!isPumpRunning || !widget.isConnected)
                        ? null // Disabled kung hindi tumatakbo OR offline
                        : () {
                            setState(() {
                              isPumpRunning = false;
                            });
                            widget.onPumpCommand('${selectedPumpMode}_stop');
                          },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Pump'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (selectedPumpMode == "irrigation"
                            ? Colors.blue
                            : Colors.cyan)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      (selectedPumpMode == "irrigation"
                              ? Colors.blue
                              : Colors.cyan)
                          .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: selectedPumpMode == "irrigation"
                        ? Colors.blue
                        : Colors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedPumpMode == "irrigation"
                          ? '💧 Irrigation runs for 30 seconds to water soil'
                          : '💨 Misting runs for 15 seconds to increase humidity',
                      style: TextStyle(
                        fontSize: 11,
                        color: (selectedPumpMode == "irrigation"
                            ? Colors.blue
                            : Colors.cyan)[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // SHADE CONTROLS
            const Text(
              'Shade Controls',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isShadeDeployed || !widget.isConnected)
                        ? null // Disabled kung deployed na OR offline
                        : () {
                            setState(() {
                              isShadeDeployed = true;
                            });
                            widget.onShadeCommand('deploy');
                          },
                    icon: const Icon(Icons.wb_cloudy),
                    label: const Text('Deploy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!isShadeDeployed || !widget.isConnected)
                        ? null // Disabled kung retracted na OR offline
                        : () {
                            setState(() {
                              isShadeDeployed = false;
                            });
                            widget.onShadeCommand('retract');
                          },
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('Retract'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpModeButton(
    String label,
    String duration,
    String mode,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    final isSelected = selectedPumpMode == mode;

    return GestureDetector(
      onTap: isPumpRunning
          ? null // Hindi pwede magpalit ng mode habang tumatakbo
          : () {
              setState(() {
                selectedPumpMode = mode;
              });
            },
      child: Opacity(
        opacity: isPumpRunning ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : (isDarkMode ? Colors.grey[800] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? color : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
