// lib/screens/calendar_view_page.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/firestore_service.dart';
import '../services/daily_summary_scheduler.dart';
import '../services/calendar_reminder_service.dart';
import '../services/esp32_connection_monitor.dart';
import '../models/calendar_reminder.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CalendarViewPage extends StatefulWidget {
  const CalendarViewPage({super.key});

  @override
  State<CalendarViewPage> createState() => _CalendarViewPageState();
}

class _CalendarViewPageState extends State<CalendarViewPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final DailySummaryScheduler _scheduler = DailySummaryScheduler();
  final CalendarReminderService _reminderService = CalendarReminderService();
  final ESP32ConnectionMonitor _connectionMonitor = ESP32ConnectionMonitor();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, DailySensorSummary> _summaries = {};
  bool _isRefreshing = false;
  bool _isConnected = false;

  StreamSubscription<List<CalendarReminder>>? _reminderSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeReminders();
    _initializeConnectionMonitor();
  }

  @override
  void dispose() {
    _reminderSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _initializeConnectionMonitor() {
    _isConnected = _connectionMonitor.isOnline;
    _connectionSubscription = _connectionMonitor.connectionStream.listen((
      isConnected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  Future<void> _initializeReminders() async {
    await _reminderService.initialize();
    _reminderSubscription = _reminderService.reminderStream.listen((reminders) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Stream<Map<DateTime, DailySensorSummary>> _getSummariesStream() {
    final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    return _firestoreService.streamDateRangeSummaries(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> _recomputeTodaySummary() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _scheduler.computeToday();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Today\'s summary recomputed successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error recomputing summary: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showDayDetails(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final summary = _summaries[normalizedDay];

    showDialog(
      context: context,
      builder: (context) => _DayDetailsDialog(
        date: day,
        summary: summary,
        isConnected: _isConnected,
        onAddReminder: () {
          Navigator.pop(context);
          _showAddReminderDialog(day);
        },
        onDeleteReminder: (reminderId) async {
          await _reminderService.deleteReminder(reminderId);
        },
        onToggleComplete: (reminderId) async {
          await _reminderService.toggleReminderCompletion(reminderId);
        },
      ),
    );
  }

  void _showAddReminderDialog(DateTime date) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddReminderDialog(
        selectedDate: date,
        onReminderAdded: (reminder) async {
          await _reminderService.addReminder(reminder);
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Reminder "${reminder.title}" added!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  Color _getDayColor(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final summary = _summaries[normalizedDay];

    if (summary == null) {
      return Colors.grey.shade300;
    }

    if (summary.temperature != null) {
      final temp =
          summary.temperature!.max ??
          ((summary.temperature!.min != null &&
                  summary.temperature!.max != null)
              ? (summary.temperature!.min! + summary.temperature!.max!) / 2
              : summary.temperature!.min);

      if (temp != null) {
        if (temp < 20) return Colors.blue.shade200;
        if (temp >= 20 && temp <= 30) return Colors.green.shade200;
        return Colors.red.shade200;
      }
    }

    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '📅 ${isSmallScreen ? 'Calendar' : 'Sensor Data Calendar'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              size: 18,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 22),
            tooltip: 'Recompute Today',
            onPressed: _isRefreshing ? null : _recomputeTodaySummary,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22),
            tooltip: 'Info',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('📊 How to Use'),
                  content: SingleChildScrollView(
                    child: Text(
                      'This calendar shows daily sensor data summaries.\n\n'
                      '🔵 Blue = Cool (< 20°C)\n'
                      '🟢 Green = Optimal (20-30°C)\n'
                      '🔴 Red = Hot (> 30°C)\n'
                      '⚪ Gray = No data\n\n'
                      'Tap any date to see detailed statistics.\n\n'
                      '📡 WiFi required for sensor readings\n'
                      '📅 Reminders work offline\n'
                      '🔄 Auto-compute at 11:59 PM\n'
                      '🔄 Real-time sync enabled',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<DateTime, DailySensorSummary>>(
        stream: _getSummariesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          _summaries = snapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Calendar widget
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 16.0,
                        vertical: 8.0,
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _showDayDetails(selectedDay);
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                        },
                        daysOfWeekHeight: isSmallScreen ? 30 : 40,
                        rowHeight: isSmallScreen ? 40 : 52,
                        headerStyle: HeaderStyle(
                          titleTextStyle: TextStyle(
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.bold,
                          ),
                          formatButtonTextStyle: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                          weekendStyle: TextStyle(
                            fontSize: isSmallScreen ? 11 : 13,
                            color: Colors.red.shade400,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                          ),
                          weekendTextStyle: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                            color: Colors.red.shade400,
                          ),
                          cellMargin: EdgeInsets.all(isSmallScreen ? 2 : 4),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final dayReminders = _reminderService
                                .getRemindersForDate(day);
                            final hasReminder = dayReminders.isNotEmpty;

                            return Container(
                              margin: EdgeInsets.all(isSmallScreen ? 2 : 4),
                              decoration: BoxDecoration(
                                color: _getDayColor(day),
                                shape: BoxShape.circle,
                                border: hasReminder
                                    ? Border.all(
                                        color: Colors.orange.shade700,
                                        width: isSmallScreen ? 1.5 : 2,
                                      )
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (hasReminder)
                                    Positioned(
                                      top: isSmallScreen ? 1 : 2,
                                      right: isSmallScreen ? 2 : 4,
                                      child: Container(
                                        width: isSmallScreen ? 4 : 6,
                                        height: isSmallScreen ? 4 : 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // Legend
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 16.0,
                        vertical: isSmallScreen ? 12.0 : 16.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📊 Legend:',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Wrap(
                            spacing: isSmallScreen ? 8 : 12,
                            runSpacing: isSmallScreen ? 8 : 12,
                            alignment: WrapAlignment.spaceAround,
                            children: [
                              _LegendItem(
                                color: Colors.blue.shade200,
                                label: 'Cool\n(< 20°C)',
                                isSmall: isSmallScreen,
                              ),
                              _LegendItem(
                                color: Colors.green.shade200,
                                label: 'Optimal\n(20-30°C)',
                                isSmall: isSmallScreen,
                              ),
                              _LegendItem(
                                color: Colors.red.shade200,
                                label: 'Hot\n(> 30°C)',
                                isSmall: isSmallScreen,
                              ),
                              _LegendItem(
                                color: Colors.grey.shade300,
                                label: 'No Data',
                                isSmall: isSmallScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Summary count
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 16.0,
                      ),
                      child: Text(
                        '${_summaries.length} days with data this month',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    const Divider(height: 24),

                    // Upcoming Reminders Section
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 16.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: isSmallScreen ? 18 : 20,
                            color: Colors.orange,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            'Upcoming Reminders',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),

                    // Reminders list
                    StreamBuilder<List<CalendarReminder>>(
                      stream: _reminderService.reminderStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 20.0 : 24.0,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final allReminders = snapshot.data!;
                        final now = DateTime.now();
                        final upcomingReminders =
                            allReminders.where((r) {
                              return !r.isCompleted &&
                                  (r.isToday ||
                                      r.scheduledDateTime.isAfter(now));
                            }).toList()..sort(
                              (a, b) => a.scheduledDateTime.compareTo(
                                b.scheduledDateTime,
                              ),
                            );

                        if (upcomingReminders.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 20.0 : 24.0,
                            ),
                            child: const Center(
                              child: Text(
                                'No upcoming reminders',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12.0 : 16.0,
                          ),
                          itemCount: upcomingReminders.length,
                          itemBuilder: (context, index) {
                            final reminder = upcomingReminders[index];
                            final dateStr = DateFormat(
                              'MMM d, yyyy',
                            ).format(reminder.date);
                            final timeStr = reminder.time.format(context);

                            return Card(
                              margin: EdgeInsets.only(
                                bottom: isSmallScreen ? 8 : 10,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 10 : 12,
                                ),
                                side: BorderSide(
                                  color: reminder.color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 10 : 12,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      reminder.color.withOpacity(0.05),
                                      reminder.color.withOpacity(0.02),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 2 : 4,
                                  ),
                                  leading: Container(
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 6 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: reminder.color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                        isSmallScreen ? 6 : 8,
                                      ),
                                    ),
                                    child: Icon(
                                      reminder.icon,
                                      color: reminder.color,
                                      size: isSmallScreen ? 18 : 22,
                                    ),
                                  ),
                                  title: Text(
                                    reminder.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 13 : 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(
                                      top: isSmallScreen ? 2 : 4,
                                    ),
                                    child: Wrap(
                                      spacing: isSmallScreen ? 6 : 8,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: isSmallScreen ? 10 : 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            SizedBox(
                                              width: isSmallScreen ? 2 : 4,
                                            ),
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 11
                                                    : 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: isSmallScreen ? 10 : 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            SizedBox(
                                              width: isSmallScreen ? 2 : 4,
                                            ),
                                            Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: isSmallScreen
                                                    ? 11
                                                    : 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (reminder.isToday)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 6 : 8,
                                            vertical: isSmallScreen ? 2 : 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'Today',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isSmallScreen ? 9 : 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      SizedBox(width: isSmallScreen ? 2 : 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade600,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showDayDetails(reminder.date),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSmall;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isSmall ? 24 : 30,
          height: isSmall ? 24 : 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(height: isSmall ? 2 : 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: isSmall ? 9 : 10),
        ),
      ],
    );
  }
}

class _DayDetailsDialog extends StatefulWidget {
  final DateTime date;
  final DailySensorSummary? summary;
  final bool isConnected;
  final VoidCallback onAddReminder;
  final Function(String) onDeleteReminder;
  final Function(String) onToggleComplete;

  const _DayDetailsDialog({
    required this.date,
    required this.summary,
    required this.isConnected,
    required this.onAddReminder,
    required this.onDeleteReminder,
    required this.onToggleComplete,
  });

  @override
  State<_DayDetailsDialog> createState() => _DayDetailsDialogState();
}

class _DayDetailsDialogState extends State<_DayDetailsDialog> {
  final CalendarReminderService _reminderService = CalendarReminderService();
  StreamSubscription<List<CalendarReminder>>? _reminderSubscription;
  List<CalendarReminder> _reminders = [];
  String? _expandedReminderId;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _reminderSubscription = _reminderService.reminderStream.listen((reminders) {
      if (mounted) {
        setState(() {
          _reminders = _reminderService.getRemindersForDate(widget.date);
        });
      }
    });
  }

  @override
  void dispose() {
    _reminderSubscription?.cancel();
    super.dispose();
  }

  void _loadReminders() {
    setState(() {
      _reminders = _reminderService.getRemindersForDate(widget.date);
    });
  }

  void _toggleReminderExpansion(String reminderId) {
    setState(() {
      _expandedReminderId = _expandedReminderId == reminderId
          ? null
          : reminderId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: isSmallScreen ? 24 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(widget.date),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.summary != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assessment,
                            size: isSmallScreen ? 14 : 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 6),
                          Text(
                            '${widget.summary!.readingsCount} readings',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reminders Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: isSmallScreen ? 18 : 20,
                              color: Colors.orange,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Text(
                              'Reminders',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: isSmallScreen ? 22 : 24,
                          ),
                          color: Colors.green,
                          tooltip: 'Add Reminder',
                          padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                          constraints: const BoxConstraints(),
                          onPressed: widget.onAddReminder,
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 12),

                    if (_reminders.isEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 20 : 24,
                          horizontal: isSmallScreen ? 12 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No reminders for this date',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._reminders.map((reminder) {
                        final isExpanded = _expandedReminderId == reminder.id;
                        return Card(
                          margin: EdgeInsets.only(
                            bottom: isSmallScreen ? 10 : 12,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 10 : 12,
                            ),
                            side: BorderSide(
                              color: reminder.color.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                isSmallScreen ? 10 : 12,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  reminder.color.withOpacity(0.05),
                                  reminder.color.withOpacity(0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  leading: Container(
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: reminder.color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                        isSmallScreen ? 8 : 10,
                                      ),
                                    ),
                                    child: Icon(
                                      reminder.icon,
                                      color: reminder.color,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  ),
                                  title: Text(
                                    reminder.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isSmallScreen ? 13 : 15,
                                      decoration: reminder.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(
                                      top: isSmallScreen ? 4 : 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: isSmallScreen ? 12 : 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        SizedBox(width: isSmallScreen ? 3 : 4),
                                        Flexible(
                                          child: Text(
                                            '${reminder.time.format(context)} • ${reminder.type.displayName}',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 11 : 13,
                                              color: Colors.grey.shade700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: SizedBox(
                                    width: isSmallScreen ? 80 : 96,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            reminder.isCompleted
                                                ? Icons.check_circle
                                                : Icons.circle_outlined,
                                            size: isSmallScreen ? 20 : 24,
                                            color: reminder.isCompleted
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 4 : 8,
                                          ),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => widget
                                              .onToggleComplete(reminder.id),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: isSmallScreen ? 20 : 24,
                                            color: Colors.red,
                                          ),
                                          padding: EdgeInsets.all(
                                            isSmallScreen ? 4 : 8,
                                          ),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => widget
                                              .onDeleteReminder(reminder.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: reminder.description.isNotEmpty
                                      ? () => _toggleReminderExpansion(
                                          reminder.id,
                                        )
                                      : null,
                                ),
                                if (isExpanded &&
                                    reminder.description.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.fromLTRB(
                                      isSmallScreen ? 12 : 16,
                                      0,
                                      isSmallScreen ? 12 : 16,
                                      isSmallScreen ? 12 : 16,
                                    ),
                                    padding: EdgeInsets.all(
                                      isSmallScreen ? 12 : 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: reminder.color.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.description,
                                              size: isSmallScreen ? 14 : 16,
                                              color: reminder.color,
                                            ),
                                            SizedBox(
                                              width: isSmallScreen ? 4 : 6,
                                            ),
                                            Text(
                                              'Description',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isSmallScreen
                                                    ? 12
                                                    : 13,
                                                color: reminder.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: isSmallScreen ? 6 : 8),
                                        Text(
                                          reminder.description,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                    // Sensor Data Section
                    if (widget.isConnected && widget.summary != null) ...[
                      Divider(height: isSmallScreen ? 24 : 32),
                      Row(
                        children: [
                          Icon(
                            Icons.sensors,
                            size: isSmallScreen ? 18 : 20,
                            color: Colors.blue,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            'Sensor Data',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 12),
                    ],

                    if (!widget.isConnected) ...[
                      Divider(height: isSmallScreen ? 24 : 32),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: isSmallScreen ? 40 : 48,
                              color: Colors.orange.shade700,
                            ),
                            SizedBox(height: isSmallScreen ? 10 : 12),
                            Text(
                              'No WiFi Connection',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            Text(
                              'Sensor readings are not available offline.\nConnect to WiFi to view sensor data.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Sensor stat cards
                    if (widget.isConnected && widget.summary != null) ...[
                      if (widget.summary!.temperature != null)
                        _StatCard(
                          icon: Icons.thermostat,
                          color: Colors.red,
                          label: 'Temperature',
                          stats: widget.summary!.temperature!,
                          unit: '°C',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.soilMoisture != null)
                        _StatCard(
                          icon: Icons.water_drop,
                          color: Colors.brown,
                          label: 'Soil Moisture',
                          stats: widget.summary!.soilMoisture!,
                          unit: '%',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.humidity != null)
                        _StatCard(
                          icon: Icons.opacity,
                          color: Colors.blue,
                          label: 'Humidity',
                          stats: widget.summary!.humidity!,
                          unit: '%',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.lightIntensity != null)
                        _StatCard(
                          icon: Icons.light_mode,
                          color: Colors.amber,
                          label: 'Light Intensity',
                          stats: widget.summary!.lightIntensity!,
                          unit: ' lux',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.nitrogen != null)
                        _StatCard(
                          icon: Icons.grass,
                          color: Colors.green,
                          label: 'Nitrogen (N)',
                          stats: widget.summary!.nitrogen!,
                          unit: ' mg/kg',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.phosphorus != null)
                        _StatCard(
                          icon: Icons.local_florist,
                          color: Colors.orange,
                          label: 'Phosphorus (P)',
                          stats: widget.summary!.phosphorus!,
                          unit: ' mg/kg',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.potassium != null)
                        _StatCard(
                          icon: Icons.spa,
                          color: Colors.purple,
                          label: 'Potassium (K)',
                          stats: widget.summary!.potassium!,
                          unit: ' mg/kg',
                          isSmall: isSmallScreen,
                        ),
                      if (widget.summary!.waterPercent != null)
                        _StatCard(
                          icon: Icons.water,
                          color: Colors.cyan,
                          label: 'Water Level',
                          stats: widget.summary!.waterPercent!,
                          unit: '%',
                          isSmall: isSmallScreen,
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final SensorStats stats;
  final String unit;
  final bool isSmall;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.stats,
    required this.unit,
    this.isSmall = false,
  });

  String _formatValue(num? value) {
    if (value == null) return 'N/A';
    if (value is double) return value.toStringAsFixed(1);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: isSmall ? 10 : 12),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: isSmall ? 18 : 20),
                SizedBox(width: isSmall ? 6 : 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 6 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatValue(
                  label: 'MIN',
                  value: _formatValue(stats.min),
                  unit: unit,
                  color: Colors.blue,
                  isSmall: isSmall,
                ),
                _StatValue(
                  label: 'AVG',
                  value: _formatValue(stats.avg),
                  unit: unit,
                  color: Colors.green,
                  isSmall: isSmall,
                ),
                _StatValue(
                  label: 'MAX',
                  value: _formatValue(stats.max),
                  unit: unit,
                  color: Colors.red,
                  isSmall: isSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isSmall;

  const _StatValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 9 : 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isSmall ? 3 : 4),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: unit,
                style: TextStyle(
                  fontSize: isSmall ? 9 : 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Add Reminder Dialog
class _AddReminderDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(CalendarReminder) onReminderAdded;

  const _AddReminderDialog({
    required this.selectedDate,
    required this.onReminderAdded,
  });

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  ReminderType _selectedType = ReminderType.general;
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _notificationEnabled = true;
  int _reminderMinutesBefore = 30;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveReminder() {
    if (_formKey.currentState!.validate()) {
      final reminder = CalendarReminder(
        id: 'reminder_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text,
        description: _descriptionController.text,
        date: widget.selectedDate,
        time: _selectedTime,
        type: _selectedType,
        notificationEnabled: _notificationEnabled,
        reminderMinutesBefore: _reminderMinutesBefore,
        icon: _selectedType.icon,
        color: _selectedType.color,
        createdAt: DateTime.now(),
      );

      widget.onReminderAdded(reminder);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: isSmallScreen ? 24 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Add Reminder',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          labelStyle: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.title,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.description,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        'Reminder Type',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Wrap(
                        spacing: isSmallScreen ? 6 : 8,
                        runSpacing: isSmallScreen ? 6 : 8,
                        children: ReminderType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type.icon,
                                  size: isSmallScreen ? 14 : 16,
                                  color: type.color,
                                ),
                                SizedBox(width: isSmallScreen ? 3 : 4),
                                Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedType = type;
                              });
                            },
                            backgroundColor: type.color.withOpacity(0.1),
                            selectedColor: type.color.withOpacity(0.3),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6 : 8,
                              vertical: isSmallScreen ? 4 : 6,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                        ),
                        leading: Icon(
                          Icons.access_time,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        title: Text(
                          'Time',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                        subtitle: Text(
                          _selectedTime.format(context),
                          style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                        ),
                        trailing: Icon(
                          Icons.edit,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        onTap: _selectTime,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                        ),
                        title: Text(
                          'Enable Notification',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                        subtitle: Text(
                          'Get alerted before the reminder time',
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
                        ),
                        value: _notificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationEnabled = value;
                          });
                        },
                      ),
                      if (_notificationEnabled) ...[
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                          ),
                          child: Text(
                            'Notify before:',
                            style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        DropdownButtonFormField<int>(
                          value: _reminderMinutesBefore,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.notifications_active,
                              size: isSmallScreen ? 20 : 24,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text(
                                'At the time',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text(
                                '15 minutes before',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text(
                                '30 minutes before',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text(
                                '1 hour before',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 120,
                              child: Text(
                                '2 hours before',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1440,
                              child: Text(
                                '1 day before',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _reminderMinutesBefore = value!;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  ElevatedButton(
                    onPressed: _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 20,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    child: Text(
                      'Add Reminder',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
