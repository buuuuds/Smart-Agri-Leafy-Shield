import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/main_layout.dart';
import 'services/app_state_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/sensor_logger_service.dart';
import 'services/fertilizer_service.dart';
import 'services/daily_summary_scheduler.dart';
import 'services/esp32_connection_monitor.dart';
import 'services/firebase_service.dart'; // ✅ ADD THIS IMPORT

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    // Disable Firestore offline persistence to prevent cache restore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    debugPrint('✅ Firestore offline persistence disabled');
  } catch (e) {
    debugPrint('❌ Firebase init failed: $e');
  }

  // Initialize AppState
  final appState = AppStateService();
  await appState.initialize();

  // ✅ NEW: Initialize FirebaseService and register to AppState
  final firebaseService = FirebaseService();
  try {
    await firebaseService.initialize();
    appState.setFirebaseService(firebaseService);
    debugPrint('✅ FirebaseService initialized and registered');
  } catch (e) {
    debugPrint('❌ FirebaseService init failed: $e');
  }

  final notificationService = NotificationService();
  await notificationService.initialize();

  final fcmService = FCMService();
  FCMService.navigatorKey = navigatorKey;
  await fcmService.initialize();

  if (fcmService.isInitialized) {
    await fcmService.subscribeToTopic('all_devices');
    await fcmService.subscribeToTopic('ESP32_ALS_001');
    debugPrint('✅ Subscribed to FCM topics');
  }

  final sensorLogger = SensorLoggerService();
  await sensorLogger.initialize();

  final fertilizerService = FertilizerService();
  await fertilizerService.initialize();
  debugPrint('✅ Fertilizer service initialized');

  // Start daily summary scheduler (runs at 11:59 PM daily)
  final dailySummaryScheduler = DailySummaryScheduler();
  dailySummaryScheduler.start();
  debugPrint('✅ Daily summary scheduler started');

  // Start ESP32 connection monitor (marks as disconnected if no heartbeat)
  final connectionMonitor = ESP32ConnectionMonitor();
  connectionMonitor.start();
  debugPrint('✅ ESP32 connection monitor started');

  runApp(MyApp(appState: appState));
}

class MyApp extends StatefulWidget {
  final AppStateService appState;

  const MyApp({super.key, required this.appState});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri Leafy Shield',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: CardThemeData(
          elevation: 2,
          color: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1F1F1F),
        ),
      ),

      themeMode: widget.appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      home: const MainLayout(),
    );
  }
}
