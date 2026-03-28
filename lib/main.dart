import 'dart:ui'; 
import 'package:e_telly_app/dbhelper/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/offline_report_storage.dart';
import 'services/hive_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/report_emergency_screen.dart';
import 'screens/flood_monitoring_screen.dart';
import 'screens/safety_tips_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/sign_up_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('user_session');
  await Hive.openBox('cached_alerts');
  await OfflineReportStorage.init();
  
  
  _connectToMongoDBInBackground();
  
  runApp(const EtellyApp());
}


void _connectToMongoDBInBackground() async {
  try {
    await MongoDatabase.connect();
    print('MongoDB connected in background');
    

    final pendingReports = OfflineReportStorage.getPendingSyncCount();
    if (pendingReports > 0) {
      print('Syncing $pendingReports pending reports...');
      await OfflineReportStorage.syncReportsToServer();
    }
    
   
    final pendingRegs = OfflineReportStorage.getPendingRegistrationsCount();
    if (pendingRegs > 0) {
      print('Syncing $pendingRegs pending registrations...');
      await OfflineReportStorage.syncRegistrationsToServer();
    }
  } catch (e) {
    print('Offline mode: MongoDB connection failed - $e');
  }
}

class EtellyApp extends StatelessWidget {
  const EtellyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(412, 715), 
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'E-Telly',
          home: const SplashScreen(),
          routes: {
            '/dashboard': (context) => const DashboardScreen(),
            '/home': (context) => const HomeScreen(),
            '/alerts': (context) => const AlertsScreen(),
            '/report-emergency': (context) => const ReportEmergencyScreen(),
            '/flood-monitor': (context) => const FloodMonitoringScreen(),
            '/safety-tips': (context) => const SafetyTipsScreen(),
            '/login': (context) => const LoginScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/sign-up': (context) => const SignUpScreen(),
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  void _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final isLoggedIn = HiveService.isLoggedIn();
    
    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'E-Telly',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Emergency Response System',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}