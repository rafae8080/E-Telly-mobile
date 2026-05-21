// lib/screens/alerts_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/alert_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'message': message,
    'barangay': barangay,
    'timestamp': timestamp,
    'severity': severity,
    'active': active,
    'read': read,
    'waterLevel': waterLevel,
    'evacuationCenter': evacuationCenter,
  };

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    barangay: json['barangay'] as String,
    timestamp: json['timestamp'] as String,
    severity: json['severity'] as String,
    active: json['active'] as bool,
    read: json['read'] as bool,
    waterLevel: json['waterLevel'] as String?,
    evacuationCenter: json['evacuationCenter'] as String?,
  );
  
  int get priorityLevel {
    switch (severity) {
      case 'critical': return 4;
      case 'high': return 3;
      case 'moderate': return 2;
      default: return 1;
    }
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  List<AlertItem> _alerts = [];
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;
  StreamSubscription<String>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Auto-refresh when a new alert notification arrives while this screen is open
    _fcmSub = onFcmRouteReceived.listen((route) {
      if (route == 'alerts' && mounted) _loadAlerts();
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _isOffline = false;
    });

    try {
      final alertsData = await _alertService.fetchAlerts();
      
      if (!mounted) return;
      
      if (alertsData.isNotEmpty) {
        final loadedAlerts = <AlertItem>[];
        
        for (var data in alertsData) {
          loadedAlerts.add(AlertItem(
            id: data['id'] as String,
            type: data['type'] as String,
            title: data['title'] as String,
            message: data['message'] as String,
            barangay: data['barangay'] as String,
            timestamp: data['timestamp'] as String,
            severity: data['severity'] as String,
            active: data['active'] as bool,
            read: data['read'] as bool,
            waterLevel: data['waterLevel'] as String?,
            evacuationCenter: data['evacuationCenter'] as String?,
          ));
        }

        final cachedAlerts = await HiveService.getCachedAlerts();
        final readStatus = <String, bool>{};
        for (var cached in cachedAlerts) {
          readStatus[cached['id'] as String] = cached['read'] as bool;
        }
        
        for (var alert in loadedAlerts) {
          alert.read = readStatus[alert.id] ?? false;
        }

        _sortAlertsByPriority(loadedAlerts);
        
        setState(() {
          _alerts = loadedAlerts;
          _isLoading = false;
        });
        
        final alertsJson = loadedAlerts.map((a) => a.toJson()).toList();
        await HiveService.cacheAlerts(alertsJson);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      final cachedAlerts = await HiveService.getCachedAlerts();
      if (cachedAlerts.isNotEmpty) {
        final loadedFromCache = <AlertItem>[];
        for (var data in cachedAlerts) {
          loadedFromCache.add(AlertItem.fromJson(data));
        }
        _sortAlertsByPriority(loadedFromCache);
        setState(() {
          _alerts = loadedFromCache;
          _isLoading = false;
          _isOffline = true;
          _error = null;
        });
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  void _sortAlertsByPriority(List<AlertItem> alerts) {
    alerts.sort((a, b) {
      final priorityCompare = b.priorityLevel.compareTo(a.priorityLevel);
      if (priorityCompare != 0) return priorityCompare;
      if (a.read != b.read) return a.read ? 1 : -1;
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  Future<void> _refreshAlerts() async {
    await _loadAlerts();
  }

  List<AlertItem> get _activeAlerts {
    return _alerts.where((alert) => alert.active).toList();
  }

  List<AlertItem> get _criticalAlerts {
    return _activeAlerts
        .where((alert) => alert.severity == 'critical')
        .toList();
  }

  int get _unreadAlerts {
    return _activeAlerts.where((alert) => !alert.read).length;
  }

  void _handleMarkAllRead() async {
    setState(() {
      for (var alert in _alerts) {
        if (alert.active) {
          alert.read = true;
        }
      }
    });
    
    final alertsJson = _alerts.map((a) => a.toJson()).toList();
    await HiveService.cacheAlerts(alertsJson);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All alerts marked as read'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _handleAlertPress(AlertItem alert) async {
    setState(() {
      alert.read = true;
    });
    
    final alertsJson = _alerts.map((a) => a.toJson()).toList();
    await HiveService.cacheAlerts(alertsJson);
    
    final details = [
      'Location: ${alert.barangay}',
      'Time: ${alert.timestamp}',
      if (alert.waterLevel != null) 'Water Level: ${alert.waterLevel}',
      if (alert.evacuationCenter != null) 'Evacuation Center: ${alert.evacuationCenter}',
      '',
      _getAlertAdvice(alert.type),
    ].where((item) => item.isNotEmpty).join('\n');

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getAlertIcon(alert.type), color: _getAlertColor(alert.type), size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(alert.title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(alert.message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getAlertColor(alert.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (alert.severity == 'critical')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEvacuationGuide(alert);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ET_RED),
              child: const Text('Evacuation Guide'),
            ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _getAlertAdvice(String type) {
    switch (type) {
      case 'evacuate':
        return 'EVACUATE IMMEDIATELY if in affected area!';
      case 'flood':
        return 'Avoid floodwaters - may contain contaminants!';
      case 'rain':
      case 'rainfall':
        return 'Prepare emergency kits and stay indoors!';
      case 'water_level':
      case 'river':
        return 'Monitor water levels closely. Prepare for possible flooding.';
      case 'earthquake':
        return 'Drop, Cover, and Hold On! Prepare for aftershocks.';
      case 'typhoon':
        return 'Secure loose objects and prepare emergency supplies!';
      case 'volcano':
        return 'Stay indoors and wear masks if ashfall occurs!';
      default:
        return 'Stay alert and follow official instructions.';
    }
  }

  void _showEvacuationGuide(AlertItem alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evacuation Guide'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What to bring:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Emergency kit (food, water, medicine)'),
            const Text('• Important documents (IDs, insurance)'),
            const Text('• Flashlight, radio, power bank'),
            const Text('• Clothes, blankets, hygiene kit'),
            const SizedBox(height: 12),
            const Text('What to do:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('1. Stay calm and alert family members'),
            const Text('2. Turn off gas and electricity'),
            const Text('3. Move to higher ground'),
            const Text('4. Follow designated evacuation routes'),
            const Text('5. Go to nearest evacuation center'),
            if (alert.barangay.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Affected area: ${alert.barangay}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getAlertColor(String type) {
    final Map<String, Color> colors = {
      'flood': ET_BLUE,
      'evacuate': ET_RED,
      'rain': ET_PURPLE,
      'rainfall': ET_PURPLE,
      'water_level': ET_ORANGE,
      'river': ET_ORANGE,
      'earthquake': const Color(0xFFEC4899),
      'typhoon': const Color(0xFF6366F1),
      'volcano': const Color(0xFF6366F1),
    };
    return colors[type] ?? const Color(0xFF666666);
  }

  IconData _getAlertIcon(String type) {
    final Map<String, IconData> icons = {
      'flood': Icons.water,
      'evacuate': Icons.directions_run,
      'rain': Icons.water_drop,
      'rainfall': Icons.water_drop,
      'water_level': Icons.show_chart,
      'river': Icons.show_chart,
      'earthquake': Icons.warning,
      'typhoon': Icons.air,
      'volcano': Icons.fire_extinguisher,
    };
    return icons[type] ?? Icons.warning;
  }

  String _getAlertTypeText(String type) {
    final Map<String, String> texts = {
      'flood': 'FLOOD ALERT',
      'evacuate': 'EVACUATION',
      'rain': 'RAINFALL',
      'rainfall': 'RAINFALL',
      'water_level': 'WATER LEVEL',
      'river': 'RIVER LEVEL',
      'earthquake': 'EARTHQUAKE',
      'typhoon': 'TYPHOON',
      'volcano': 'VOLCANO',
    };
    return texts[type]?.toUpperCase() ?? 'ALERT';
  }

  void _goToHome() {

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false, 
    );
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
          onPressed: _goToHome, // Fixed: No back arrow on Home screen
          tooltip: 'Back to Home',
        ),
        title: const Text('Alerts'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshAlerts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading alerts...'),
                  ],
                ),
              )
            : _error != null && _alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Unable to load alerts', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshAlerts,
                          style: ElevatedButton.styleFrom(backgroundColor: ET_RED),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshAlerts,
                    child: _activeAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                                const SizedBox(height: 16),
                                const Text('No Active Alerts', style: TextStyle(fontSize: 18)),
                                const SizedBox(height: 8),
                                Text('All systems normal', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _activeAlerts.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        _buildStatCard(
                                          count: _criticalAlerts.length,
                                          label: 'CRITICAL',
                                          color: ET_RED,
                                        ),
                                        const SizedBox(width: 12),
                                        _buildStatCard(
                                          count: _activeAlerts.length,
                                          label: 'ACTIVE',
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
                                    const SizedBox(height: 16),
                                    Row(
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
                                        if (_unreadAlerts > 0)
                                          TextButton(
                                            onPressed: _handleMarkAllRead,
                                            child: Text(
                                              'Mark all as read',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: ET_RED,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              }
                              final alertIndex = index - 1;
                              return _buildAlertCard(_activeAlerts[alertIndex]);
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    final alertColor = _getAlertColor(alert.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.severity == 'critical' ? ET_RED : const Color(0xFFE5E7EB),
          width: alert.severity == 'critical' ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: alert.severity == 'critical' 
                ? ET_RED.withOpacity(0.2) 
                : Colors.black.withOpacity(0.05),
            blurRadius: alert.severity == 'critical' ? 4 : 2,
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
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getAlertTypeText(alert.type),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: alertColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: alert.severity == 'critical' ? ET_RED : const Color(0xFF1F2937),
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
  }
}