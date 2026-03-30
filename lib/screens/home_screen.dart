import 'package:e_telly_app/screens/resources_screen.dart';
import 'package:e_telly_app/widgets/custom_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants.dart';
import '../screens/dashboard_screen.dart';
import '../screens/report_emergency_screen.dart' hide SavedReportsScreen;
import '../screens/evacuation_screen.dart';
import '../screens/profile_screen.dart';
 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();



  @override
  Widget build(BuildContext context) {
    List<String> _titles = [
      'Welcome to E-Telly!',
      'Resources',
      'Report Emergency',
      'Evacuation Navigation',
      'Profile',
    ];
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        shadowColor: Colors.grey,
        title: CustomFont(
          text: _titles[_selectedIndex],
          fontSize: ScreenUtil().setSp(22),
          fontFamily: 'Roboto',
          fontWeight: FontWeight.bold,
          color: ET_RED,
        ),
      ),
      body: PageView(
        controller: _pageController,
        children: <Widget>[
          DashboardScreen(onNavigateToTab: _onTappedBar),
          const ResourcesScreen(),
          const ReportEmergencyScreen(),
          const EvacuationScreen(),
          const ProfileScreen(), 
        ],
        onPageChanged: (page) {
          setState(() {
            _selectedIndex = page;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 20,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: _onTappedBar,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Resources',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Report',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Evac Nav'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: ET_RED,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
      ),
    );
  }

  void _onTappedBar(int value) {
    setState(() {
      _selectedIndex = value;
    });
    _pageController.jumpToPage(value);
  }
}