// lib/screens/alerts_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../services/alert_service.dart';
import '../services/report_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../utils/alert_presentation.dart';
import '../utils/geo_utils.dart';
import 'home_screen.dart';

class AlertItem {
  final String id;
  final String type;       // mobile display type (flood, rain, water_level, ...)
  final String rawType;    // backend hazard type (flood, rainfall, typhoon, ...)
  final String rawSeverity; // backend PAGASA severity (watch/warning/critical/evacuate)
  final String title;
  final String message;        // resident-friendly (auto) or operator text (manual)
  final String officialDetail; // CDRRMO-grade technical description + source
  final bool isManual;
  final String source;
  final String barangay;
  final String timestamp;
  final String severity;       // legacy collapsed value (critical/high/moderate)
  final bool active;
  bool read;
  final String? waterLevel;
  final String? evacuationCenter;

  AlertItem({
    required this.id,
    required this.type,
    required this.rawType,
    required this.rawSeverity,
    required this.title,
    required this.message,
    required this.officialDetail,
    required this.isManual,
    required this.source,
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
    'rawType': rawType,
    'rawSeverity': rawSeverity,
    'title': title,
    'message': message,
    'officialDetail': officialDetail,
    'isManual': isManual,
    'source': source,
    'barangay': barangay,
    'timestamp': timestamp,
    'severity': severity,
    'active': active,
    'read': read,
    'waterLevel': waterLevel,
    'evacuationCenter': evacuationCenter,
  };

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    // Null-safe reads so alerts cached by older app versions (which lacked the
    // resident-presentation fields) still load instead of throwing.
    final legacySeverity = (json['severity'] as String?) ?? 'moderate';
    final rawSeverity = (json['rawSeverity'] as String?) ??
        _rawSeverityFromLegacy(legacySeverity);
    return AlertItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] as String?) ?? 'other',
      rawType: (json['rawType'] as String?) ??
          (json['alertType'] as String?) ??
          (json['type'] as String?) ??
          'other',
      rawSeverity: rawSeverity,
      title: (json['title'] as String?) ?? 'Alert',
      message: (json['message'] as String?) ?? '',
      officialDetail: (json['officialDetail'] as String?) ??
          (json['message'] as String?) ??
          '',
      isManual: (json['isManual'] as bool?) ?? false,
      source: (json['source'] as String?) ?? 'system',
      barangay: (json['barangay'] as String?) ?? 'Antipolo City',
      timestamp: (json['timestamp'] as String?) ?? '',
      severity: legacySeverity,
      active: (json['active'] as bool?) ?? true,
      read: (json['read'] as bool?) ?? false,
      waterLevel: json['waterLevel'] as String?,
      evacuationCenter: json['evacuationCenter'] as String?,
    );
  }

  static String _rawSeverityFromLegacy(String legacy) {
    switch (legacy) {
      case 'critical': return 'critical';
      case 'high':     return 'warning';
      default:         return 'watch';
    }
  }

  AlertActionLevel get actionLevel =>
      AlertPresentation.levelFromSeverity(rawSeverity);

  int get priorityLevel {
    switch (rawSeverity) {
      case 'evacuate': return 5;
      case 'critical': return 4;
      case 'warning':  return 3;
      case 'watch':    return 2;
      default:         return 1;
    }
  }
}

/// A nearby community report paired with its distance from the user.
class _NearbyReport {
  final Map<String, dynamic> report;
  final double distanceKm;
  _NearbyReport({required this.report, required this.distanceKm});
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  final ReportService _reportService = ReportService();

  List<AlertItem> _alerts = [];
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;
  String _filter = 'all'; // all | unread | near
  StreamSubscription<String>? _fcmSub;

  // ── Near You (nearby community reports) state ─────────────────────────────
  List<Map<String, dynamic>> _reports = [];
  double? _userLat;
  double? _userLng;
  double _radiusKm = 10;
  bool _nearLoading = false;
  bool _nearLoaded = false;
  bool _locationDenied = false;

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
        final loadedAlerts =
            alertsData.map((data) => AlertItem.fromJson(data)).toList();

        final cachedAlerts = await HiveService.getCachedAlerts();
        final readStatus = <String, bool>{};
        for (var cached in cachedAlerts) {
          readStatus[cached['id'] as String] = (cached['read'] as bool?) ?? false;
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
        final loadedFromCache =
            cachedAlerts.map((data) => AlertItem.fromJson(data)).toList();
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

  Future<void> _refreshAlerts() async => _loadAlerts();

  List<AlertItem> get _activeAlerts =>
      _alerts.where((alert) => alert.active).toList();

  int get _unreadAlerts => _activeAlerts.where((alert) => !alert.read).length;

  List<AlertItem> get _filteredAlerts {
    if (_filter == 'unread') {
      return _activeAlerts.where((a) => !a.read).toList();
    }
    return _activeAlerts;
  }

  // ── Near You: location + reports ─────────────────────────────────────────
  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadNearYou() async {
    if (!mounted) return;
    setState(() {
      _nearLoading = true;
      _locationDenied = false;
    });

    final pos = await _getCurrentLocation();
    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _nearLoading = false;
        _nearLoaded = true;
        _locationDenied = true;
      });
      return;
    }

    final reports = await _reportService.fetchApprovedReports();
    if (!mounted) return;

    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _reports = reports;
      _nearLoading = false;
      _nearLoaded = true;
    });
  }

  List<_NearbyReport> get _nearbyReports {
    if (_userLat == null || _userLng == null) return [];
    final list = <_NearbyReport>[];
    for (final r in _reports) {
      final lat = (r['latitude'] as num?)?.toDouble();
      final lng = (r['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final d = distanceKm(_userLat!, _userLng!, lat, lng);
      if (d <= _radiusKm) {
        list.add(_NearbyReport(report: r, distanceKm: d));
      }
    }
    list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return list;
  }

  void _handleMarkAllRead() async {
    setState(() {
      for (var alert in _alerts) {
        if (alert.active) alert.read = true;
      }
    });

    final alertsJson = _alerts.map((a) => a.toJson()).toList();
    await HiveService.cacheAlerts(alertsJson);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All alerts marked as read'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  void _handleAlertPress(AlertItem alert) async {
    setState(() {
      alert.read = true;
    });

    final alertsJson = _alerts.map((a) => a.toJson()).toList();
    await HiveService.cacheAlerts(alertsJson);

    if (!mounted) return;
    _showAlertDetailSheet(alert);
  }

  // ── Alert detail bottom sheet ────────────────────────────────────────────
  void _showAlertDetailSheet(AlertItem alert) {
    final level = alert.actionLevel;
    final isAuto = AlertPresentation.isAutoAlert(alert.source, alert.isManual);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _buildBandPill(level),
              const SizedBox(height: 12),
              Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                alert.message,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 16),
              _detailRow(Icons.location_on_outlined, alert.barangay),
              const SizedBox(height: 6),
              _detailRow(Icons.schedule, alert.timestamp),
              if (alert.waterLevel != null) ...[
                const SizedBox(height: 6),
                _detailRow(Icons.water, 'Water level: ${alert.waterLevel}'),
              ],
              // Official details — only for auto alerts (manual alerts already
              // show the operator's plain message as the main body).
              if (isAuto && alert.officialDetail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: const Text(
                      'Official details & source',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    iconColor: const Color(0xFF6B7280),
                    collapsedIconColor: const Color(0xFF6B7280),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          alert.officialDetail,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Report detail bottom sheet ───────────────────────────────────────────
  void _showReportDetailSheet(_NearbyReport nr) {
    final r = nr.report;
    final type = (r['emergencyType'] ?? 'report').toString();
    final color = _reportColor(r['severity'] as String?);
    final description = (r['description'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_reportIcon(type), size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${type.toUpperCase()} report',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: const TextStyle(
                    fontSize: 15, height: 1.5, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 16),
            ],
            _detailRow(Icons.social_distance,
                '${nr.distanceKm.toStringAsFixed(1)} km from your location'),
            const SizedBox(height: 6),
            _detailRow(
                Icons.location_on_outlined, _reportLocationText(r['location'])),
            const SizedBox(height: 6),
            _detailRow(Icons.schedule, _reportTimeText(r['timestamp'])),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  // ── Hazard icon / label (kept for recognizability; colored by band) ──────
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
      'flood': 'FLOOD',
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

  // ── Report helpers ───────────────────────────────────────────────────────
  Color _reportColor(String? severity) {
    switch ((severity ?? '').toLowerCase()) {
      case 'high':   return ET_RED;
      case 'medium': return ET_ORANGE;
      case 'low':    return ET_YELLOW;
      default:       return ET_GRAY;
    }
  }

  IconData _reportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':       return Icons.local_fire_department;
      case 'flood':      return Icons.water;
      case 'earthquake': return Icons.warning;
      case 'typhoon':    return Icons.air;
      case 'landslide':  return Icons.terrain;
      case 'medical':    return Icons.medical_services;
      case 'accident':   return Icons.car_crash;
      default:           return Icons.report_problem;
    }
  }

  String _reportLocationText(dynamic loc) {
    if (loc is Map) {
      return (loc['exactAddress'] ??
              loc['barangay'] ??
              loc['address'] ??
              loc['city'] ??
              'Unknown location')
          .toString();
    }
    if (loc is String && loc.isNotEmpty) return loc;
    return 'Unknown location';
  }

  String _reportTimeText(dynamic timestamp) {
    final date =
        timestamp is String ? DateTime.tryParse(timestamp) : null;
    if (date == null) return 'Unknown time';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  // ── Reusable band pill ───────────────────────────────────────────────────
  Widget _buildBandPill(AlertActionLevel level) {
    final color = AlertPresentation.bandColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AlertPresentation.bandIcon(level), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            AlertPresentation.bandLabel(level),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String value, String label, int count) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label${count > 0 ? '  $count' : ''}'),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF6B7280),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        selectedColor: ET_RED,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          setState(() => _filter = value);
          if (value == 'near' && !_nearLoaded && !_nearLoading) {
            _loadNearYou();
          }
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTabChip('all', 'All', _activeAlerts.length),
          _buildTabChip('unread', 'Unread', _unreadAlerts),
          _buildTabChip('near', 'Near You', 0),
        ],
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
          onPressed: _goToHome,
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
            onPressed: _filter == 'near' ? _loadNearYou : _refreshAlerts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildTabBar(),
            const SizedBox(height: 12),
            Expanded(
              child: _filter == 'near'
                  ? _buildNearYouContent()
                  : _buildAlertsContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── All / Unread content ─────────────────────────────────────────────────
  Widget _buildAlertsContent() {
    if (_isLoading && _alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading alerts...'),
          ],
        ),
      );
    }

    if (_error != null && _alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Unable to load alerts',
                style: TextStyle(color: Colors.grey[600])),
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
      );
    }

    final filtered = _filteredAlerts;

    return RefreshIndicator(
      onRefresh: _refreshAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildAlertsHeader(filtered);
          return _buildAlertCard(filtered[index - 1]);
        },
      ),
    );
  }

  Widget _buildAlertsHeader(List<AlertItem> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isOffline)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ET_YELLOW.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 14, color: ET_YELLOW),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Offline — showing saved alerts',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _filter == 'unread' ? 'Unread Alerts' : 'Recent Alerts',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: ET_RED),
            ),
            if (_unreadAlerts > 0)
              TextButton(
                onPressed: _handleMarkAllRead,
                child: Text(
                  'Mark all as read',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: ET_RED),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: Colors.green[400]),
                  const SizedBox(height: 12),
                  Text(
                    _filter == 'unread'
                        ? 'No unread alerts'
                        : 'No active alerts',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('All systems normal',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    final level = alert.actionLevel;
    final bandColor = AlertPresentation.bandColor(level);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
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
                    color: bandColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_getAlertIcon(alert.type),
                      size: 20, color: bandColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildBandPill(level),
                          const Spacer(),
                          Text(
                            alert.timestamp,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                          if (!alert.read) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: bandColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_getAlertTypeText(alert.type)} · ${alert.barangay}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
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
  }

  // ── Near You content ─────────────────────────────────────────────────────
  Widget _buildNearYouContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildRadiusSelector(),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildNearYouList()),
      ],
    );
  }

  Widget _buildRadiusSelector() {
    Widget chip(double km) {
      final selected = _radiusKm == km;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('${km.toInt()} km'),
          selected: selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
          backgroundColor: const Color(0xFFF3F4F6),
          selectedColor: ET_BLUE,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          onSelected: (_) => setState(() => _radiusKm = km),
        ),
      );
    }

    return Row(
      children: [
        const Icon(Icons.social_distance, size: 16, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        const Text('Within',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(width: 10),
        chip(5),
        chip(10),
        chip(20),
      ],
    );
  }

  Widget _buildNearYouList() {
    if (_nearLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding reports near you...'),
          ],
        ),
      );
    }

    if (_locationDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Location needed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Turn on location and allow access to see emergency reports near you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNearYou,
                style: ElevatedButton.styleFrom(backgroundColor: ET_RED),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final nearby = _nearbyReports;

    if (nearby.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNearYou,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: Colors.green[400]),
                  const SizedBox(height: 12),
                  Text('No reports within ${_radiusKm.toInt()} km',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Nothing reported near your area',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearYou,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: nearby.length,
        itemBuilder: (context, index) => _buildReportCard(nearby[index]),
      ),
    );
  }

  Widget _buildReportCard(_NearbyReport nr) {
    final r = nr.report;
    final type = (r['emergencyType'] ?? 'report').toString();
    final color = _reportColor(r['severity'] as String?);
    final description = (r['description'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportDetailSheet(nr),
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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(_reportIcon(type), size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${nr.distanceKm.toStringAsFixed(1)} km away',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _reportTimeText(r['timestamp']),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${type.toUpperCase()} report',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _reportLocationText(r['location']),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF),
                              ),
                              overflow: TextOverflow.ellipsis,
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
  }
}
