// screens/notification_page.dart - WITH 2K LIMIT UI

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../utils/time_helper.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  final FirestoreService _firestoreService = FirestoreService();

  List<NotificationItem> notifications = [];
  bool isLoading = true;
  bool isSyncing = false;

  StreamSubscription<List<NotificationItem>>? _notificationSubscription;
  StreamSubscription<List<NotificationData>>? _firestoreStreamSubscription;
  Timer? _timeUpdateTimer;

  String _filterPriority = 'all';

  DateTime? _lastDeleteTime;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startFirestoreRealTimeSync();
    _startTimeUpdateTimer();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _firestoreStreamSubscription?.cancel();
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();

      _notificationSubscription = _notificationService.notificationStream
          .listen((updatedNotifications) {
            if (mounted) {
              setState(() {
                notifications = updatedNotifications;
              });
            }
          });

      setState(() {
        notifications = _notificationService.notifications;
        isLoading = false;
      });

      debugPrint('✅ Notifications initialized: ${notifications.length}');
    } catch (e) {
      debugPrint('❌ Failed to load notifications: $e');
      setState(() => isLoading = false);
    }
  }

  void _startFirestoreRealTimeSync() {
    _firestoreStreamSubscription = _firestoreService
        .streamNotifications(limit: 2000)
        .listen(
          (firestoreNotifications) {
            if (mounted) {
              if (_lastDeleteTime != null) {
                final timeSinceDelete = DateTime.now().difference(
                  _lastDeleteTime!,
                );
                if (timeSinceDelete.inSeconds < 3) {
                  debugPrint('⏸️ Skipping sync - delete operation in progress');
                  return;
                }
              }

              _updateNotificationsFromFirestore(
                firestoreNotifications,
                silent: false,
              );
            }
          },
          onError: (error) {
            debugPrint('❌ Firestore stream error: $error');
          },
        );
    debugPrint('✅ Real-time Firestore sync started');
  }

  void _updateNotificationsFromFirestore(
    List<NotificationData> firestoreNotifs, {
    bool silent = false,
  }) {
    try {
      final updatedNotifications = <NotificationItem>[];
      final newNotificationIds = <String>[];

      for (var firestoreNotif in firestoreNotifs) {
        final existingIndex = notifications.indexWhere(
          (n) => n.id == firestoreNotif.id,
        );

        NotificationItem notificationItem;

        if (existingIndex != -1) {
          final existing = notifications[existingIndex];
          final useLocalIsRead = existing.isRead && !firestoreNotif.isRead;

          notificationItem = NotificationItem(
            id: firestoreNotif.id,
            title: firestoreNotif.title,
            message: firestoreNotif.message,
            timestamp: firestoreNotif.timestamp,
            priority: _parsePriority(firestoreNotif.priority),
            isRead: useLocalIsRead ? existing.isRead : firestoreNotif.isRead,
            icon: firestoreNotif.iconCodePoint != null
                ? IconData(
                    firestoreNotif.iconCodePoint!,
                    fontFamily: 'MaterialIcons',
                  )
                : existing.icon,
            color: firestoreNotif.colorValue != null
                ? Color(firestoreNotif.colorValue!)
                : existing.color,
          );
        } else {
          newNotificationIds.add(firestoreNotif.id);

          notificationItem = NotificationItem(
            id: firestoreNotif.id,
            title: firestoreNotif.title,
            message: firestoreNotif.message,
            timestamp: firestoreNotif.timestamp,
            priority: _parsePriority(firestoreNotif.priority),
            isRead: firestoreNotif.isRead,
            icon: firestoreNotif.iconCodePoint != null
                ? IconData(
                    firestoreNotif.iconCodePoint!,
                    fontFamily: 'MaterialIcons',
                  )
                : Icons.notifications,
            color: firestoreNotif.colorValue != null
                ? Color(firestoreNotif.colorValue!)
                : Colors.blue,
          );
        }

        updatedNotifications.add(notificationItem);
      }

      updatedNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          notifications = updatedNotifications;
        });

        if (silent) {
          debugPrint(
            '🔕 Silent sync: ${updatedNotifications.length} total, '
            '${newNotificationIds.length} new (no push notifications)',
          );
        } else {
          debugPrint(
            '✅ Real-time update: ${updatedNotifications.length} total, '
            '${newNotificationIds.length} new notifications',
          );

          if (newNotificationIds.isNotEmpty) {
            _showPushForNewNotifications(
              updatedNotifications
                  .where((n) => newNotificationIds.contains(n.id))
                  .toList(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating from Firestore: $e');
    }
  }

  void _showPushForNewNotifications(List<NotificationItem> newNotifications) {
    final importantNotifs = newNotifications
        .where(
          (n) =>
              n.priority == NotificationPriority.high ||
              n.priority == NotificationPriority.critical,
        )
        .toList();

    if (importantNotifs.isEmpty) {
      debugPrint('📭 No important notifications to push');
      return;
    }

    debugPrint(
      '📢 ${importantNotifs.length} new important notification(s) detected',
    );

    for (var notif in importantNotifs) {
      debugPrint(
        '  → ${notif.priority.toString().split('.').last.toUpperCase()}: ${notif.title}',
      );
    }
  }

  NotificationPriority _parsePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return NotificationPriority.critical;
      case 'high':
        return NotificationPriority.high;
      case 'medium':
        return NotificationPriority.medium;
      case 'low':
        return NotificationPriority.low;
      default:
        return NotificationPriority.medium;
    }
  }

  Future<void> _syncFromFirestore() async {
    if (isSyncing) return;

    setState(() => isSyncing = true);

    try {
      final firestoreNotifs = await _firestoreService.getNotifications(
        limit: 2000,
        forceRefresh: true,
      );

      _updateNotificationsFromFirestore(firestoreNotifs, silent: true);

      if (mounted) {
        setState(() => isSyncing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('✅ Synced ${firestoreNotifs.length} notifications'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      if (mounted) {
        setState(() => isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Sync failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        setState(() {
          notifications[index] = notifications[index].copyWith(isRead: true);
        });
      }

      await _notificationService.markAsRead(notificationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Marked as read'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Mark as read failed: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() {
        notifications = notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });

      await _notificationService.markAllAsRead();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Mark all as read failed: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      setState(() {
        _isDeleting = true;
        _lastDeleteTime = DateTime.now();
      });

      final deletedNotification = notifications.firstWhere(
        (n) => n.id == notificationId,
      );

      setState(() {
        notifications.removeWhere((n) => n.id == notificationId);
      });

      await _notificationService.deleteNotification(notificationId);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '📦 Notification archived (auto-deleted in 30 days)',
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  notifications.insert(0, deletedNotification);
                  notifications.sort(
                    (a, b) => b.timestamp.compareTo(a.timestamp),
                  );
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Archive failed: $e');

      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive All Notifications'),
        content: const Text(
          'This will archive all notifications.\n\n'
          'Archived notifications will be automatically deleted after 30 days.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isDeleting = true;
          _lastDeleteTime = DateTime.now();
        });

        setState(() {
          notifications.clear();
        });

        await _notificationService.clearAllNotifications();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isDeleting = false;
            });
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '📦 All notifications archived (auto-deleted in 30 days)',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Archive all failed: $e');

        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // 🆕 Manual cleanup dialog
  Future<void> _showCleanupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cleanup Old Notifications'),
          ],
        ),
        content: Text(
          'You have ${notifications.length} notifications.\n\n'
          'Archive old notifications to keep only the most recent 1000?\n\n'
          'Archived notifications will be stored for 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Cleanup'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);

      try {
        final toArchive = notifications.skip(1000).toList();

        int archived = 0;
        for (var notif in toArchive) {
          await _notificationService.deleteNotification(notif.id);
          archived++;
        }

        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Archived $archived old notifications'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Cleanup failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<NotificationItem> get filteredNotifications {
    return notifications.where((notification) {
      final matchesPriority =
          _filterPriority == 'all' ||
          notification.priority.toString().split('.').last == _filterPriority;

      return matchesPriority;
    }).toList();
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.green;
    }
  }

  IconData _getPriorityIcon(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical:
        return Icons.error;
      case NotificationPriority.high:
        return Icons.warning;
      case NotificationPriority.medium:
        return Icons.info;
      case NotificationPriority.low:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final filtered = filteredNotifications;

    // 🆕 Calculate warning level
    final isApproachingLimit = notifications.length >= 1800;
    final countColor = isApproachingLimit ? Colors.orange : Colors.grey[400];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            // 🆕 Show count with color warning
            Text(
              '${notifications.length}/2000 total${unreadCount > 0 ? " • $unreadCount unread" : ""}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: countColor,
              ),
            ),
          ],
        ),
        actions: [
          // 🆕 Warning chip when approaching limit
          if (isApproachingLimit)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                avatar: Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: Colors.orange,
                ),
                label: Text(
                  '${notifications.length}/2000',
                  style: TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.orange.withOpacity(0.2),
              ),
            ),

          // Sync button
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              tooltip: 'Sync from cloud (silent)',
              onPressed: _syncFromFirestore,
            ),

          // Mark all as read
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),

          // Archive all
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.archive),
              tooltip: 'Archive all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _filterPriority == 'all'
                        ? 'No notifications'
                        : 'No $_filterPriority priority notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  if (_filterPriority != 'all') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterPriority = 'all';
                        });
                      },
                      child: const Text('Clear filter'),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _syncFromFirestore,
              child: Column(
                children: [
                  // Filter bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                    child: Row(
                      children: [
                        const Text('Filter: '),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _filterPriority,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'critical',
                              child: Text('Critical'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterPriority = value!;
                            });
                          },
                        ),
                        const Spacer(),
                        if (isSyncing)
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDarkMode ? Colors.white : Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Syncing...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Notifications list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final notification = filtered[index];
                        final priorityColor = _getPriorityColor(
                          notification.priority,
                        );

                        return Dismissible(
                          key: Key(notification.id),
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.orange,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.archive,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await _markAsRead(notification.id);
                              return false;
                            } else {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Archive Notification'),
                                  content: const Text(
                                    'Archive this notification?\n\n'
                                    'It will be automatically deleted after 30 days.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                      ),
                                      child: const Text('Archive'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              _deleteNotification(notification.id);
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            color: notification.isRead
                                ? (isDarkMode ? Colors.grey[850] : Colors.white)
                                : (isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.blue[50]),
                            child: InkWell(
                              onTap: () => _markAsRead(notification.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        notification.icon,
                                        color: priorityColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notification.title,
                                                  style: TextStyle(
                                                    fontWeight:
                                                        notification.isRead
                                                        ? FontWeight.normal
                                                        : FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              if (!notification.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                _getPriorityIcon(
                                                  notification.priority,
                                                ),
                                                size: 14,
                                                color: priorityColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                notification.priority
                                                    .toString()
                                                    .split('.')
                                                    .last
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: priorityColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message:
                                                    TimeHelper.formatTimestamp(
                                                      notification.timestamp,
                                                    ),
                                                child: Text(
                                                  TimeHelper.getRelativeTime(
                                                    notification.timestamp,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      // 🆕 Floating Action Button for manual cleanup
      floatingActionButton: notifications.length >= 1500
          ? FloatingActionButton.extended(
              onPressed: _showCleanupDialog,
              icon: Icon(Icons.cleaning_services),
              label: Text('Cleanup (${notifications.length})'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }
}
