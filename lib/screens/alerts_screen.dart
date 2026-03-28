import 'package:flutter/material.dart';
import '../constants.dart';

class AlertItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String barangay;
  final String timestamp;
  final String severity;
  final bool active;
  bool read;
  final String? waterLevel;
  final String? evacuationCenter;

  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.barangay,
    required this.timestamp,
    required this.severity,
    required this.active,
    required this.read,
    this.waterLevel,
    this.evacuationCenter,
  });
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertItem> _alerts = [
    AlertItem(
      id: '1',
      type: 'flood',
      title: 'CRITICAL: COASTAL FLOODING',
      message:
          'High tide + heavy rain causing severe flooding in coastal areas. Water level at 1.8 meters.',
      barangay: 'Tanza 1, Tanza 2, Bangkulasi',
      timestamp: '10:45 AM',
      severity: 'critical',
      active: true,
      read: false,
      waterLevel: '1.8m',
      evacuationCenter: 'Navotas City Hall Evacuation Center',
    ),
    AlertItem(
      id: '2',
      type: 'evacuate',
      title: 'EVACUATION ORDER - IMMEDIATE',
      message:
          'Mandatory evacuation for riverside communities. Navotas River overflowing.',
      barangay: 'Daanghari, North Bay Boulevard South',
      timestamp: '10:30 AM',
      severity: 'critical',
      active: true,
      read: false,
      waterLevel: '2.1m',
      evacuationCenter: 'Navotas National High School',
    ),
    AlertItem(
      id: '3',
      type: 'rain',
      title: 'INTENSE RAINFALL WARNING',
      message:
          'Heavy to intense rainfall (15-30mm/hr) expected for next 3 hours. Prepare for possible flooding.',
      barangay: 'All Navotas Barangays',
      timestamp: '10:15 AM',
      severity: 'high',
      active: true,
      read: true,
      waterLevel: 'Rising',
    ),
    AlertItem(
      id: '4',
      type: 'flood',
      title: 'URBAN FLOODING ALERT',
      message:
          'Drainage systems overwhelmed. Major roads impassable due to knee-deep flooding.',
      barangay: 'San Roque, Tangos, Navotas West',
      timestamp: '9:45 AM',
      severity: 'high',
      active: true,
      read: true,
      waterLevel: '0.8m',
      evacuationCenter: 'Tangos Elementary School',
    ),
    AlertItem(
      id: '5',
      type: 'water_level',
      title: 'NAVOTAS RIVER WARNING',
      message:
          'River water level approaching critical mark at 2.3 meters. Monitor closely.',
      barangay: 'Riverside Communities',
      timestamp: 'Yesterday',
      severity: 'moderate',
      active: true,
      read: true,
      waterLevel: '2.3m',
    ),
  ];

  int get _unreadAlerts {
    return _alerts.where((alert) => alert.active && !alert.read).length;
  }

  List<AlertItem> get _activeAlerts {
    return _alerts.where((alert) => alert.active).toList();
  }

  List<AlertItem> get _criticalAlerts {
    return _alerts
        .where((alert) => alert.severity == 'critical' && alert.active)
        .toList();
  }

  void _handleMarkAllRead() {
    setState(() {
      for (var alert in _alerts) {
        alert.read = true;
      }
    });
  }

  void _handleAlertPress(AlertItem alert) {
    setState(() {
      alert.read = true;
    });
    // Navigate to alert details or show modal
    final details = [
      '📍 Location: ${alert.barangay}',
      '⏰ Time: ${alert.timestamp}',
      if (alert.waterLevel != null) '🌊 Water Level: ${alert.waterLevel}',
      if (alert.evacuationCenter != null)
        '🏫 Evacuation Center: ${alert.evacuationCenter}',
      '',
      if (alert.type == 'evacuate')
        '🚨 EVACUATE IMMEDIATELY if in affected area!',
      if (alert.type == 'flood')
        '⚠️ Avoid floodwaters - may contain contaminants!',
      if (alert.type == 'rain') '☔ Prepare emergency kits and stay indoors!',
      if (alert.type == 'typhoon')
        '🌀 Secure loose objects and prepare for strong winds!',
      if (alert.type == 'earthquake')
        '🌍 Drop, Cover, and Hold On during shaking!',
      if (alert.type == 'fire')
        '🔥 Check electrical systems and avoid open flames!',
      if (alert.type == 'medical') '🏥 Boil water and maintain hygiene!',
    ].where((item) => item.isNotEmpty).join('\n');

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: SingleChildScrollView(
          child: Text('${alert.message}\n\n$details'),
        ),
        actions: actions,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Color _getAlertColor(String type) {
    final Map<String, Color> colors = {
      'flood': ET_BLUE,
      'evacuate': ET_RED,
      'rain': ET_PURPLE,
      'water_level': ET_ORANGE,
    };
    return colors[type] ?? const Color(0xFF666666);
  }

  IconData _getAlertIcon(String type) {
    final Map<String, IconData> icons = {
      'flood': Icons.water,
      'evacuate': Icons.directions_run,
      'rain': Icons.water_drop,
      'water_level': Icons.show_chart,
    };
    return icons[type] ?? Icons.warning;
  }

  String _getAlertTypeText(String type) {
    final Map<String, String> texts = {
      'flood': 'FLOOD ALERT',
      'evacuate': 'EVACUATION',
      'rain': 'RAINFALL',
      'water_level': 'WATER LEVEL',
    };
    return texts[type] ?? 'ALERT';
  }

  Widget _buildStatCard({
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0.5,
        shadowColor: Colors.grey,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Alerts'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Emergency Stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              child: Row(
                children: [
                  _buildStatCard(
                    count: _criticalAlerts.length,
                    label: 'CRITICAL',
                    color: ET_RED,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    count: _activeAlerts.length,
                    label: 'ACTIVE ALERTS',
                    color: ET_ORANGE,
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    count: _unreadAlerts,
                    label: 'UNREAD',
                    color: ET_BLUE,
                  ),
                ],
              ),
            ),
        
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ET_RED,
                    ),
                  ),
                  TextButton(
                    onPressed: _unreadAlerts == 0 ? null : _handleMarkAllRead,
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _unreadAlerts == 0 ? Colors.grey : ET_RED,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        
            // Alerts List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _activeAlerts.length,
                itemBuilder: (context, index) {
                  final alert = _activeAlerts[index];
                  final alertColor = _getAlertColor(alert.type);
        
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleAlertPress(alert),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: alertColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _getAlertIcon(alert.type),
                                  size: 20,
                                  color: alertColor,
                                ),
                              ),
                              const SizedBox(width: 12),
        
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _getAlertTypeText(alert.type),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: alertColor,
                                          ),
                                        ),
                                        Text(
                                          alert.timestamp,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      alert.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      alert.message,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF666666),
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: Color(0xFF666666),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            alert.barangay,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF666666),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
        
                              // Unread indicator
                              if (!alert.read)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: alertColor,
                                      shape: BoxShape.circle,
                                    ),
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
    );
  }
}
