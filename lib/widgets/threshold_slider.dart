// widgets/threshold_slider.dart - WITH TEXT INPUT OPTION

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThresholdSlider extends StatefulWidget {
  final double temperatureThreshold;
  final Function(double) onThresholdChanged;
  final String? label;
  final IconData? icon;
  final double? min;
  final double? max;
  final String? unit;
  final String? subtitle;

  const ThresholdSlider({
    super.key,
    required this.temperatureThreshold,
    required this.onThresholdChanged,
    this.label,
    this.icon,
    this.min,
    this.max,
    this.unit,
    this.subtitle,
  });

  @override
  State<ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<ThresholdSlider> {
  late double _currentValue;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentValue = widget.temperatureThreshold;
    _textController.text = _currentValue.toStringAsFixed(0);
  }

  @override
  void didUpdateWidget(ThresholdSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.temperatureThreshold != oldWidget.temperatureThreshold) {
      _currentValue = widget.temperatureThreshold;
      _textController.text = _currentValue.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showInputDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final minValue = widget.min ?? 20.0;
    final maxValue = widget.max ?? 40.0;
    final unit = widget.unit ?? '°C';

    showDialog(
      context: context,
      builder: (context) {
        final inputController = TextEditingController(
          text: _currentValue.toStringAsFixed(0),
        );

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                widget.icon ?? Icons.thermostat,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              Text(widget.label ?? 'Set Threshold'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter value between ${minValue.toStringAsFixed(0)} and ${maxValue.toStringAsFixed(0)}$unit',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: inputController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: widget.label ?? 'Threshold',
                  suffixText: unit,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(widget.icon ?? Icons.thermostat),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(inputController.text);
                if (value != null && value >= minValue && value <= maxValue) {
                  setState(() {
                    _currentValue = value;
                    _textController.text = value.toStringAsFixed(0);
                  });
                  widget.onThresholdChanged(value);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a value between ${minValue.toStringAsFixed(0)} and ${maxValue.toStringAsFixed(0)}$unit',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final minValue = widget.min ?? 20.0;
    final maxValue = widget.max ?? 40.0;
    final unit = widget.unit ?? '°C';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF2D2D2D), const Color(0xFF1F1F1F)]
              : [Colors.white, const Color(0xFFF5F5F5)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon ?? Icons.thermostat,
                  color: const Color(0xFF4CAF50),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label ?? 'Temperature Threshold',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              // ✅ MANUAL INPUT BUTTON
              InkWell(
                onTap: _showInputDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Input',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: _currentValue,
                      min: minValue,
                      max: maxValue,
                      divisions: ((maxValue - minValue) * 2).toInt(),
                      label: '${_currentValue.toStringAsFixed(1)}$unit',
                      activeColor: const Color(0xFF4CAF50),
                      inactiveColor: Colors.grey[300],
                      onChanged: (value) {
                        setState(() {
                          _currentValue = value;
                          _textController.text = value.toStringAsFixed(0);
                        });
                      },
                      onChangeEnd: (value) {
                        widget.onThresholdChanged(value);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${minValue.toStringAsFixed(0)}$unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${maxValue.toStringAsFixed(0)}$unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _currentValue.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      unit,
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
        ],
      ),
    );
  }
}
