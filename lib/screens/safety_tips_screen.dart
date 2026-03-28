import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../widgets/safety_tips.dart';

class SafetyTip {
  final String id;
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int steps;
  final String riskLevel;
  final List<String>? detailedSteps;
  final String? emergencyNumber;

  SafetyTip({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.steps,
    required this.riskLevel,
    this.detailedSteps,
    this.emergencyNumber,
  });
}

class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  SafetyTip? _selectedTip;
  bool _showDetailModal = false;

  final List<SafetyTip> safetyTips = [
    SafetyTip(
      id: '1',
      category: 'First Aid',
      title: 'Basic first aid for common emergencies',
      description: 'Essential medical response procedures',
      icon: Icons.medical_services,
      color: Color(0xFFDC2626),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'Check the scene for safety',
        'Call emergency services immediately',
        'Check if the person is responsive',
        'Perform CPR if trained and needed',
        'Control bleeding with direct pressure',
        'Treat for shock by keeping person warm',
        'Do not move injured person unless necessary',
        'Check for medical alert tags',
        'Stay with person until help arrives',
        'Follow dispatcher instructions carefully',
      ],
    ),
    SafetyTip(
      id: '2',
      category: 'Typhoon',
      title: 'Typhoon Preparedness',
      description: 'Complete guide for typhoon season',
      icon: Icons.cloud,
      color: Color(0xFF3B82F6),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'Secure all windows and doors',
        'Trim trees and remove loose objects',
        'Stock 3-day supply of food and water',
        'Charge all electronic devices',
        'Prepare emergency lighting sources',
        'Stay indoors during the storm',
        'Stay away from windows',
        'Monitor official weather updates',
        'Evacuate if in flood-prone area',
        'Check on neighbors after storm passes',
      ],
    ),
    SafetyTip(
      id: '3',
      category: 'Earthquake',
      title: 'Earthquake Safety',
      description: 'Drop, Cover, and Hold On procedures',
      icon: Icons.warning,
      color: Color(0xFFF59E0B),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'DROP to your hands and knees',
        'COVER your head and neck',
        'HOLD ON to sturdy furniture',
        'Stay away from windows and glass',
        'If outside, move to open area',
        'If driving, pull over and stay in car',
        'Stay indoors until shaking stops',
        'Check for injuries after shaking stops',
        'Expect aftershocks',
        'Listen to emergency broadcasts',
      ],
    ),
    SafetyTip(
      id: '4',
      category: 'Fire',
      title: 'Fire Emergency Guide',
      description: 'Prevention and response to fire hazards',
      icon: Icons.local_fire_department,
      color: Color(0xFFDC2626),
      steps: 8,
      riskLevel: 'High Risk',
      emergencyNumber: '8-281-0854',
      detailedSteps: [
        'Install smoke detectors on every level',
        'Test smoke detectors monthly',
        'Create and practice fire escape plan',
        'Keep fire extinguishers accessible',
        'Stop, drop, and roll if clothes catch fire',
        'Crawl low under smoke',
        'Check doors for heat before opening',
        'Meet at designated outside location',
      ],
    ),
    SafetyTip(
      id: '5',
      category: 'Flood',
      title: 'Flood Safety Guide',
      description: 'Essential steps before, during, and after floods',
      icon: Icons.water_damage,
      color: Color(0xFF06B6D4),
      steps: 10,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'Monitor weather updates and flood warnings',
        'Prepare emergency kit with food, water, and medications',
        'Move valuables to higher floors',
        'Turn off electricity at main switch',
        'Evacuate immediately if instructed',
        'Avoid walking or driving through floodwaters',
        'Stay away from downed power lines',
        'Listen to local news for updates',
        'Return only when authorities say it\'s safe',
        'Document damage for insurance claims',
      ],
    ),
    SafetyTip(
      id: '6',
      category: 'Evacuation',
      title: 'Evacuation Procedures',
      description: 'Safe evacuation routes and procedures',
      icon: Icons.directions_walk,
      color: Color(0xFF10B981),
      steps: 7,
      riskLevel: 'Medium Risk',
      emergencyNumber: '8-281-1111',
      detailedSteps: [
        'Know your evacuation zone',
        'Plan multiple evacuation routes',
        'Prepare "go-bag" with essentials',
        'Follow official evacuation orders',
        'Take pets and medications',
        'Inform family of destination',
        'Use only designated evacuation routes',
      ],
    ),
    SafetyTip(
      id: '7',
      category: 'Heat',
      title: 'Heatwave Safety',
      description: 'Protection during extreme heat conditions',
      icon: Icons.thermostat,
      color: Color(0xFFDC2626),
      steps: 6,
      riskLevel: 'Medium Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'Stay hydrated with water',
        'Avoid outdoor activities during peak heat',
        'Wear lightweight, light-colored clothing',
        'Stay in air-conditioned places',
        'Check on elderly and vulnerable neighbors',
        'Know signs of heat exhaustion',
      ],
    ),
    SafetyTip(
      id: '8',
      category: 'Electrical',
      title: 'Electrical Safety',
      description: 'Preventing electrical hazards',
      icon: Icons.flash_on,
      color: Color(0xFFF59E0B),
      steps: 8,
      riskLevel: 'High Risk',
      emergencyNumber: '911',
      detailedSteps: [
        'Keep electrical appliances away from water',
        'Do not overload outlets',
        'Use surge protectors',
        'Check cords for damage',
        'Turn off main breaker during floods',
        'Do not touch electrical equipment if wet',
        'Have electrical system inspected',
        'Know location of main electrical panel',
      ],
    ),
  ];

  final List<Map<String, dynamic>> bottomNavItems = [
    {'id': 'home', 'label': 'Home', 'icon': Icons.home_outlined, 'iconActive': Icons.home},
    {'id': 'safety', 'label': 'Safety Tips', 'icon': Icons.security_outlined, 'iconActive': Icons.security},
    {'id': 'evac', 'label': 'Evac Nav', 'icon': Icons.map_outlined, 'iconActive': Icons.map},
    {'id': 'resources', 'label': 'Resources', 'icon': Icons.widgets_outlined, 'iconActive': Icons.widgets},
    {'id': 'profile', 'label': 'Profile', 'icon': Icons.person_outline, 'iconActive': Icons.person},
  ];

  Color getRiskLevelColor(String riskLevel) {
    switch (riskLevel) {
      case 'High Risk':
        return Color(0xFFDC2626);
      case 'Medium Risk':
        return Color(0xFFF59E0B);
      case 'Low Risk':
        return Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  void _handleSafetyTipPress(SafetyTip tip) {
    setState(() {
      _selectedTip = tip;
      _showDetailModal = true;
    });
  }

  void _handleEmergencyCall(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Unable to make call'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        shadowColor: Colors.grey,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Safety Tips'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Implement search functionality
            },
          )
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALL SAFETY TIPS (${safetyTips.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        SizedBox(height: 16),
                        ...safetyTips.map((tip) => SafetyTipCard(
                          tip: tip,
                          onTap: () => _handleSafetyTipPress(tip),
                          getRiskLevelColor: getRiskLevelColor,
                        )).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showDetailModal && _selectedTip != null)
            SafetyTipDetailModal(
              tip: _selectedTip!,
              getRiskLevelColor: getRiskLevelColor,
              onClose: () => setState(() => _showDetailModal = false),
              onEmergencyCall: _handleEmergencyCall,
            ),
        ],
      ),
      ),
    );
  }
}
