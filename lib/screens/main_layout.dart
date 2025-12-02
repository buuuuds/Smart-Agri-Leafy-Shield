// screens/main_layout.dart - With persistent page state using PageView

// screens/main_layout.dart - With persistent page state using PageView

import 'package:flutter/material.dart';
import 'dart:async';
import 'dashboard_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'notification_page.dart'; // Your existing NotificationPage from document
import 'plant_management_page.dart';
import 'calendar_view_page.dart'; // 🆕 Calendar View
import '../services/notification_service.dart';

class MainLayout extends StatefulWidget {
  final void Function(bool)? onThemeChanged;

  const MainLayout({super.key, this.onThemeChanged});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;
  int unreadNotificationCount = 0;

  // Use PageController to maintain state across pages
  final PageController _pageController = PageController();

  // Create pages once and reuse them (keeps state)
  late final List<Widget> pages;

  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<NotificationItem>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize pages once
    pages = [
      const DashboardPage(),
      const ReportPage(),
      const PlantManagementPage(),
      SettingsPage(onThemeChanged: widget.onThemeChanged),
    ];

    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();

      _notificationSubscription = _notificationService.notificationStream
          .listen((notifications) {
            if (mounted) {
              setState(() {
                unreadNotificationCount = notifications
                    .where((n) => !n.isRead)
                    .length;
              });
            }
          });

      setState(() {
        unreadNotificationCount = _notificationService.unreadCount;
      });
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  void _navigateToNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NotificationPage()));

    // Update count when returning
    if (mounted) {
      setState(() {
        unreadNotificationCount = _notificationService.unreadCount;
      });
    }
  }

  // 🆕 Navigate to Calendar View
  void _navigateToCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CalendarViewPage()),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF1F1F1F)
            : const Color(0xFF2E7D32),
        elevation: 15,
        toolbarHeight: 90,
        title: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 8),
            const Expanded(
              // ✅ Prevent overflow
              child: Text(
                "Smart Agri-Leafy Shield",
                overflow: TextOverflow
                    .ellipsis, // ✅ Add ellipsis (…) if text too long
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 🆕 Calendar button
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            tooltip: 'Sensor Data Calendar',
            onPressed: _navigateToCalendar,
          ),
          // Notifications button with badge
          Stack(
            children: [
              IconButton(
                padding: const EdgeInsets.only(right: 16.0),
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _navigateToNotifications,
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 12,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadNotificationCount > 99
                          ? '99+'
                          : unreadNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe, use nav only
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.dashboard, "Dashboard", 0, isDarkMode),
            _buildNavItem(Icons.analytics, "Analytics", 1, isDarkMode),
            _buildNavItem(Icons.eco, "Plants", 2, isDarkMode),
            _buildNavItem(Icons.settings, "Settings", 3, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    bool isDarkMode,
  ) {
    bool isSelected = selectedIndex == index;
    final selectedColor = isDarkMode
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2E7D32);
    final unselectedColor = isDarkMode ? Colors.grey[400] : Colors.grey;
    final backgroundColor = isDarkMode
        ? (isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.2)
              : Colors.transparent)
        : (isSelected ? const Color(0xFFE8F5E9) : Colors.transparent);

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: isSelected ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? selectedColor : unselectedColor),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selectedColor,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
