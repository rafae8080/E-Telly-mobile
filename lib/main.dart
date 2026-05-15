import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/offline_report_storage.dart';
import 'services/hive_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/report_emergency_screen.dart';
import 'screens/flood_monitoring_screen.dart';
import 'screens/safety_tips_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/profile_screen.dart';
import 'services/relay_queue_manager.dart';
import 'services/internet_checker_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
    
    // Initialize Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final fcmToken = await messaging.getToken();
    print('FCM Token: $fcmToken');
  } catch (e, stack) {
    print('Firebase initialization error: $e');
    print('Stack trace: $stack');
  }
  
  await ScreenUtil.ensureScreenSize();
  
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('user_session');
  await Hive.openBox('cached_alerts');
  
  await HiveService.init();
  await OfflineReportStorage.init();
  await RelayQueueManager.init();

  InternetCheckerService.instance.start();

  // CHECK JWT TOKEN
  final authService = AuthService();
  final isJwtValid = await authService.isLoggedIn();
  
  print('========== APP START ==========');
  print('JWT Valid: $isJwtValid');
  print('================================');
  
  // Sync with Hive
  await HiveService.setLoggedIn(isJwtValid);
  
  runApp(EtellyApp(initialRoute: isJwtValid ? '/home' : '/welcome'));
}

class EtellyApp extends StatelessWidget {
  final String initialRoute;
  
  const EtellyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(412, 715),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true, 
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'E-Telly',
          theme: ThemeData(
            fontFamily: 'Roboto',
            useMaterial3: true,
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: 14.sp),
              bodyMedium: TextStyle(fontSize: 12.sp),
              bodySmall: TextStyle(fontSize: 10.sp),
            ),
          ),
          initialRoute: initialRoute,
          routes: {
            '/dashboard': (context) => const DashboardScreen(),
            '/home': (context) => const HomeScreen(),
            '/alerts': (context) => const AlertsScreen(),
            '/report-emergency': (context) => const ReportEmergencyScreen(),
            '/disaster-monitor': (context) => const DisasterMonitoringScreen(),
            '/safety-tips': (context) => const SafetyTipsScreen(),
            '/login': (context) => const LoginScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/sign-up': (context) => const SignUpScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
      },
    );
  }
}