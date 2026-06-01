import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/hive_service.dart';
import '../services/api_service.dart';
import '../services/alert_service.dart';
import '../services/hazard_routing_service.dart';
import '../services/notification_service.dart';


class EvacuationCenter {
  final String id;
  final String name;
  final String address;
  final int capacity;
  final int currentOccupancy;
  final String status;
  final String contact;
  final double latitude;
  final double longitude;
  String distance;
  final List<String> facilities;
  final String operatingHours;
  bool isHazardAffected;
  String? hazardType;
  String hazardSeverityLevel;
  bool wasRerouted;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.currentOccupancy,
    required this.status,
    required this.contact,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.facilities,
    required this.operatingHours,
    this.isHazardAffected = false,
    this.hazardType,
    this.hazardSeverityLevel = 'none',
    this.wasRerouted = false,
  });

  LatLng get latLng => LatLng(latitude, longitude);
  int get availableCapacity => capacity - currentOccupancy;
  double get occupancyPercentage => (currentOccupancy / capacity) * 100;

  factory EvacuationCenter.fromJson(Map<String, dynamic> json,
      {String? distance}) {
    String addressValue = 'Address not available';
    if (json['location'] != null && json['location'].toString().isNotEmpty) {
      addressValue = json['location'].toString();
      if (json['barangay'] != null && json['barangay'].toString().isNotEmpty) {
        addressValue += ', Brgy. ${json['barangay']}';
      }
    } else if (json['barangay'] != null) {
      addressValue = 'Brgy. ${json['barangay']}';
    }

    int occupancy = 0;
    if (json['occupancy'] != null) {
      occupancy = json['occupancy'] is int
          ? json['occupancy']
          : (json['occupancy'] as num).toInt();
    } else if (json['currentOccupancy'] != null) {
      occupancy = json['currentOccupancy'] is int
          ? json['currentOccupancy']
          : (json['currentOccupancy'] as num).toInt();
    }

    int capacity = json['capacity'] is int
        ? json['capacity']
        : (json['capacity'] ?? 100).toInt();

    // Status is derived from BOTH the admin availability flag and live occupancy,
    // so a center filled to capacity becomes 'full' (and thus non-navigable) even
    // when the admin hasn't manually toggled it unavailable.
    final bool adminUnavailable = json['available'] == false;
    String statusValue;
    if (adminUnavailable) {
      statusValue = 'full';
    } else if (capacity > 0 && occupancy >= capacity) {
      statusValue = 'full';
    } else if (capacity > 0 && occupancy / capacity >= 0.8) {
      statusValue = 'almost_full';
    } else if (json['available'] == null && json['status'] != null) {
      statusValue = json['status'].toString();
    } else {
      statusValue = 'available';
    }

    double lat = 14.5865;
    double lng = 121.1756;
    if (json['latitude'] != null) lat = (json['latitude'] as num).toDouble();
    else if (json['lat'] != null) lat = (json['lat'] as num).toDouble();
    if (json['longitude'] != null) lng = (json['longitude'] as num).toDouble();
    else if (json['lng'] != null) lng = (json['lng'] as num).toDouble();

    List<String> facilitiesList = [];
    if (json['facilities'] != null && json['facilities'] is List) {
      facilitiesList = List<String>.from(json['facilities']);
    } else {
      facilitiesList = ['Basic Shelter', 'First Aid', 'Food'];
    }

    return EvacuationCenter(
      id: json['_id'].toString(),
      name: json['name'] ?? 'Unknown Center',
      address: addressValue,
      capacity: capacity,
      currentOccupancy: occupancy,
      status: statusValue,
      contact: json['contact']?.toString() ?? 'N/A',
      latitude: lat,
      longitude: lng,
      distance: distance ?? '0 km',
      facilities: facilitiesList,
      operatingHours: json['operatingHours']?.toString() ?? '24/7',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'capacity': capacity,
        'currentOccupancy': currentOccupancy,
        'status': status,
        'contact': contact,
        'latitude': latitude,
        'longitude': longitude,
        'facilities': facilities,
        'operatingHours': operatingHours,
      };
}

class HazardZone {
  final String type;
  final String severity;
  final List<String> barangays;
  final LatLng center;
  final double radius;
  final DateTime createdAt;

  HazardZone({
    required this.type,
    required this.severity,
    required this.barangays,
    required this.center,
    required this.radius,
    required this.createdAt,
  });
}

// A single Mapbox route alternative tagged with the hazards that fall on it.
class _RouteOption {
  final List<LatLng> geometry;
  final List<HazardPoint> criticals;
  final List<HazardPoint> warnings;
  _RouteOption({
    required this.geometry,
    required this.criticals,
    required this.warnings,
  });
}

// User's decision when a warning/watch hazard sits on the chosen route.
enum _RouteChoice { cancel, alternative, continueRoute }

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});

  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  // Centers
  List<EvacuationCenter> _evacuationCenters = [];
  List<EvacuationCenter> _allCenters = [];

  // Map
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  double _currentZoom = 14;

  // Hazards
  List<HazardZone> _hazardZones = [];
  bool _isLoadingCenters = true;

  // Mapbox Navigation
  MapBoxNavigation? _mapboxNavigation;
  bool _isNavigating = false;
  bool _isCalculatingRoute = false;
  EvacuationCenter? _destinationCenter;

  // Location stream
  StreamSubscription<Position>? _positionSubscription;

  // Hazard routing
  List<HazardPoint> _hazardPoints = [];
  List<HazardPoint> _routeHazardWarnings = [];

  // Offline state
  bool _isOfflineMode = false;
  bool _isCompassMode = false;
  List<LatLng> _offlineRouteGeometry = [];
  List<LatLng> _lastRouteGeometry = [];

  // UI banners
  bool _showHazardWarningBanner = false;

  // Live updates (socket.io)
  IO.Socket? _socket;
  Timer? _liveHazardDebounce;
  Timer? _liveCenterDebounce;
  final Set<String> _notifiedHazardIds = {};

  final LatLng _antipoloCenter = const LatLng(14.5865, 121.1756);

  // ── Lifecycle ──────────────────────────────

  @override
  void initState() {
    super.initState();
    _initMapboxNavigation();
    _getCurrentLocation();
    _loadEvacuationCenters();
    _loadHazardZones();
    _startLocationUpdates();
    _initLiveUpdates();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _liveHazardDebounce?.cancel();
    _liveCenterDebounce?.cancel();
    _socket?.dispose();
    _mapController.dispose();
    _mapboxNavigation?.finishNavigation();
    super.dispose();
  }

  // ── Live updates (socket.io) ───────────────

  void _initLiveUpdates() {
    try {
      _socket = IO.io(
        ApiService.baseUrl,
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
      );
      _socket!.connect();
      // Hazard-affecting events → refresh alerts + approved reports.
      for (final e in const [
        'new_alert', 'alert_updated', 'report_status_updated', 'report_updated',
      ]) {
        _socket!.on(e, (_) { if (mounted) _scheduleHazardRefresh(); });
      }
      // Center-affecting events → refresh evacuation centers.
      for (final e in const ['evacuation_updated', 'evacuation_center_created']) {
        _socket!.on(e, (_) { if (mounted) _scheduleCenterRefresh(); });
      }
    } catch (e) {
      print('[Evacuation] live updates init failed: $e');
    }
  }

  // A single admin action can emit several events at once — coalesce them so we
  // reload once rather than hammering the network.
  void _scheduleHazardRefresh() {
    _liveHazardDebounce?.cancel();
    _liveHazardDebounce = Timer(const Duration(milliseconds: 800), _refreshHazardsLive);
  }

  void _scheduleCenterRefresh() {
    _liveCenterDebounce?.cancel();
    _liveCenterDebounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _loadEvacuationCenters();
    });
  }

  Future<void> _refreshHazardsLive() async {
    if (!mounted) return;
    await _loadHazardZones();
    if (!mounted) return;

    // Keep the native navigation map's hazard markers in sync with live updates.
    _pushHazardMarkersToNav();

    // While navigating, auto-reroute if a NEW critical hazard now sits on the
    // active route (block radius). Reuses the same hazard-aware routing applied
    // at trip start, then swaps the route live without restarting navigation.
    if (_isNavigating && _lastRouteGeometry.isNotEmpty && _destinationCenter != null) {
      final criticals = _hazardPoints.where((h) => h.isCritical).toList();
      final onRoute = HazardAwareRoutingService.hazardsWithin(
          _lastRouteGeometry, criticals, HazardAwareRoutingService.blockRadius);
      final fresh = onRoute.where((h) => !_notifiedHazardIds.contains(h.id)).toList();
      if (fresh.isNotEmpty) {
        _notifiedHazardIds.addAll(fresh.map((h) => h.id));
        await _liveRerouteAround(fresh);
      }
    }
  }

  // Computes a safe route to the current destination that avoids [fresh] and
  // swaps it into the running navigation. Falls back to a notification when no
  // safe route can be found (e.g. every alternative is also blocked).
  Future<void> _liveRerouteAround(List<HazardPoint> fresh) async {
    final origin = _currentLocation;
    final center = _destinationCenter;
    if (origin == null || center == null) return;

    final hazardPoints = _hazardPoints;
    // Anchor detours on every critical currently blocking the active route (fall
    // back to the freshly-detected ones), then find the shortest safe route.
    final criticals = hazardPoints.where((h) => h.isCritical).toList();
    final blocking = HazardAwareRoutingService.hazardsWithin(
        _lastRouteGeometry, criticals, HazardAwareRoutingService.blockRadius);
    print('[LiveReroute] triggered: ${fresh.length} fresh, ${blocking.length} blocking on active route');
    final safeGeom = await _findSafeWalkingRoute(
        origin, center.latLng, blocking.isNotEmpty ? blocking : fresh, hazardPoints);

    if (!mounted) return;

    if (safeGeom == null) {
      // No route avoids it — keep the user informed (previous behaviour).
      print('[LiveReroute] no safe route -> notify + keep current route');
      final h = fresh.first;
      await NotificationService.showLocalAlert(
        'New hazard on your route',
        '${h.label} reported on your way — re-check your route.',
      );
      return;
    }

    _lastRouteGeometry   = safeGeom;
    _routeHazardWarnings = _warningsOnRoute(safeGeom, hazardPoints);
    final wayPoints = _wayPointsFor(origin, center, safeGeom, forceDetour: true);

    try {
      print('[LiveReroute] applying reroute with ${wayPoints.length} waypoints');
      await _mapboxNavigation?.reroute(wayPoints: wayPoints);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hazard ahead — rerouting'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print('[Evacuation] live reroute failed: $e');
    }
  }

  // ── Mapbox Navigation Init ─────────────────

  void _initMapboxNavigation() {
    _mapboxNavigation = MapBoxNavigation();
    _mapboxNavigation!.registerRouteEventListener(_onRouteEvent);
  }

  // Serializes the current hazard points into the {lat,lng,severity} payload the
  // native navigation map expects.
  List<Map<String, dynamic>> _hazardMarkerPayload() => _hazardPoints
      .map((h) => {
            'lat': h.location.latitude,
            'lng': h.location.longitude,
            'severity': h.severity,
          })
      .toList();

  // Pushes the current hazards onto the native navigation map. No-op unless
  // navigation is running (the native activity holds the map).
  void _pushHazardMarkersToNav() {
    if (!_isNavigating) return;
    final payload = _hazardMarkerPayload();
    print('[Markers] pushing ${payload.length} hazards to nav (navigating=$_isNavigating)');
    _mapboxNavigation?.updateHazardMarkers(hazards: payload);
  }

  MapBoxOptions _buildMapboxOptions() => MapBoxOptions(
    initialLatitude: _currentLocation?.latitude ?? 14.5865,
    initialLongitude: _currentLocation?.longitude ?? 121.1756,
    zoom: 15.0,
    tilt: 0.0,
    bearing: 0.0,
    enableRefresh: true,
    alternatives: false,
    voiceInstructionsEnabled: true,
    bannerInstructionsEnabled: true,
    mode: MapBoxNavigationMode.walking,
    isOptimized: false,
    units: VoiceUnits.metric,
    simulateRoute: false,
    language: "en",
  );

  Future<void> _onRouteEvent(e) async {
    switch (e.eventType) {
      case MapBoxEvent.route_built:
        if (mounted) setState(() => _isNavigating = true);
        _pushHazardMarkersToNav();
        break;

      case MapBoxEvent.route_build_failed:
        _showErrorDialog('Failed to build route. Please try again.');
        if (mounted) setState(() => _isNavigating = false);
        break;

      case MapBoxEvent.navigation_running:
        if (mounted) setState(() => _isNavigating = true);
        break;

      case MapBoxEvent.on_arrival:
        if (mounted) setState(() => _isNavigating = false);
        _showArrivalDialog();
        break;

      case MapBoxEvent.navigation_cancelled:
      case MapBoxEvent.navigation_finished:
        if (mounted) {
          setState(() {
            _isNavigating = false;
            _destinationCenter = null;
          });
        }
        break;

      default:
        break;
    }
  }

  // ── Connectivity ───────────────────────────

  Future<bool> _hasConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Location ───────────────────────────────

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (!mounted) return;
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = newLocation);
      if (_allCenters.isNotEmpty) _updateDistances();
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationError = 'Location services are disabled';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationError = 'Location permissions are denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permissions are permanently denied';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
          _mapController.move(_currentLocation!, _currentZoom);
        });
        _updateDistances();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to get location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _currentZoom);
    } else {
      _getCurrentLocation();
    }
  }

  // ── Distance helpers ───────────────────────

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(point1.latitude)) *
            cos(_toRadians(point2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (pi / 180);

  double _parseDistanceToMeters(String distanceStr) {
    if (distanceStr.contains('km')) {
      return double.parse(distanceStr.replaceAll(' km', '')) * 1000;
    } else {
      return double.parse(distanceStr.replaceAll(' m', '')).toDouble();
    }
  }

  void _updateDistances() {
    if (_currentLocation == null) return;
    final updated = _allCenters.map((center) {
      final distance = _calculateDistance(_currentLocation!, center.latLng);
      final distanceStr = distance < 1
          ? '${(distance * 1000).toInt()} m'
          : '${distance.toStringAsFixed(1)} km';
      return EvacuationCenter(
        id: center.id,
        name: center.name,
        address: center.address,
        capacity: center.capacity,
        currentOccupancy: center.currentOccupancy,
        status: center.status,
        contact: center.contact,
        latitude: center.latitude,
        longitude: center.longitude,
        distance: distanceStr,
        facilities: center.facilities,
        operatingHours: center.operatingHours,
        isHazardAffected: center.isHazardAffected,
        hazardType: center.hazardType,
        hazardSeverityLevel: center.hazardSeverityLevel,
        wasRerouted: center.wasRerouted,
      );
    }).toList();

    updated.sort((a, b) {
      final distA = _parseDistanceToMeters(a.distance);
      final distB = _parseDistanceToMeters(b.distance);
      return distA.compareTo(distB);
    });

    setState(() {
      _allCenters = updated;
      _evacuationCenters = updated;
    });
  }

  // ── Data loading ───────────────────────────

  Future<void> _loadEvacuationCenters() async {
    if (!mounted) return;
    setState(() => _isLoadingCenters = true);

    if (await _hasConnectivity()) {
      try {
        final response = await ApiService()
            .authenticatedGet('/api/evacuation/centers?barangay=all');
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List<dynamic> raw = body is List
              ? body
              : (body['centers'] ?? body['data'] ?? []);
          final data = raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          await HiveService.cacheEvacuationCenters(data);
          _processCenters(data);
        } else {
          print('❌ Evacuation centers API ${response.statusCode}');
          await _loadCentersFromCache(markOffline: false);
        }
      } catch (e) {
        print('❌ Error loading evacuation centers: $e');
        await _loadCentersFromCache(markOffline: false);
      }
    } else {
      await _loadCentersFromCache(markOffline: true);
    }
  }

  Future<void> _loadCentersFromCache({bool markOffline = true}) async {
    final cached = await HiveService.getCachedEvacuationCenters();
    if (cached.isEmpty) {
      if (mounted) setState(() => _isLoadingCenters = false);
      return;
    }
    if (markOffline && mounted) setState(() => _isOfflineMode = true);
    _processCenters(cached);
  }

  void _processCenters(List<Map<String, dynamic>> data) {
    final centers = data.map((d) => EvacuationCenter.fromJson(d)).toList();

    List<EvacuationCenter> result = centers;
    if (_currentLocation != null) {
      result = centers.map((center) {
        final distance = _calculateDistance(_currentLocation!, center.latLng);
        final distanceStr = distance < 1
            ? '${(distance * 1000).toInt()} m'
            : '${distance.toStringAsFixed(1)} km';
        return EvacuationCenter(
          id: center.id,
          name: center.name,
          address: center.address,
          capacity: center.capacity,
          currentOccupancy: center.currentOccupancy,
          status: center.status,
          contact: center.contact,
          latitude: center.latitude,
          longitude: center.longitude,
          distance: distanceStr,
          facilities: center.facilities,
          operatingHours: center.operatingHours,
        );
      }).toList();

      result.sort((a, b) {
        final distA = _parseDistanceToMeters(a.distance);
        final distB = _parseDistanceToMeters(b.distance);
        return distA.compareTo(distB);
      });
    }

    final annotated = _hazardPoints.isNotEmpty
        ? HazardAwareRoutingService.annotateCentersWithHazards(result, _hazardPoints)
        : result;

    if (mounted) {
      setState(() {
        _allCenters = annotated;
        _evacuationCenters = annotated;
        _isLoadingCenters = false;
      });
    }
  }

  Future<void> _loadHazardZones() async {
    if (!mounted) return;

    if (await _hasConnectivity()) {
      try {
        // AlertService calls /api/alerts, caches to Hive, falls back on failure
        final alerts  = await AlertService().fetchAlerts();
        final reports = await _fetchApprovedReports();
        await HiveService.cacheCommunityReports(reports);
        await _buildHazardState(alerts, reports);
      } catch (e) {
        print('Error loading hazards: $e');
        await _loadHazardZonesFromCache(markOffline: false);
      }
    } else {
      await _loadHazardZonesFromCache(markOffline: true);
    }
  }

  Future<void> _loadHazardZonesFromCache({bool markOffline = true}) async {
    if (markOffline && mounted) setState(() => _isOfflineMode = true);
    final cachedAlerts  = await HiveService.getCachedAlerts();
    final cachedReports = await HiveService.getCachedCommunityReports();
    await _buildHazardState(cachedAlerts, cachedReports);
  }

  Future<void> _buildHazardState(
      List<Map<String, dynamic>> alerts,
      List<Map<String, dynamic>> reports) async {
    final zones = <HazardZone>[];

    for (final a in alerts) {
      final severity = a['severity'] as String? ?? 'watch';
      // Show circles for all active hazard severities — severity only controls radius size

      final barangayName = a['barangay'] as String?
          ?? (a['barangays'] is List && (a['barangays'] as List).isNotEmpty
              ? (a['barangays'] as List).first.toString()
              : '');
      final center = HazardAwareRoutingService.extractLatLng(a)
          ?? _getBarangayCenter(barangayName.split(',').first.trim());
      final type = a['alertType'] as String? ?? a['type'] as String? ?? 'hazard';
      final barangayLabel = a['barangay'] as String?
          ?? (a['barangays'] is List ? (a['barangays'] as List).join(', ') : '');

      // Scale radius by severity so watch/warning circles are proportionally smaller.
      // AlertService maps raw 'warning' → 'high', so accept both spellings.
      final baseRadius = HazardAwareRoutingService.criticalRadiusFor(type);
      final radiusM = (severity == 'critical' || severity == 'evacuate')
          ? baseRadius
          : (severity == 'warning' || severity == 'high')
              ? baseRadius * 0.6
              : baseRadius * 0.3; // moderate / watch

      zones.add(HazardZone(
        type:      type,
        severity:  severity,
        barangays: [barangayLabel],
        center:    center,
        radius:    radiusM / 1000.0,
        createdAt: DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime.now(),
      ));
    }

    // Only show community reports from the last 7 days to prevent stale data accumulating
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    for (final r in reports) {
      final createdAt = DateTime.tryParse(r['createdAt'] as String? ?? '');
      if (createdAt != null && createdAt.isBefore(sevenDaysAgo)) continue;

      final center = HazardAwareRoutingService.extractLatLng(r);
      if (center == null) continue;
      final type = r['emergencyType'] as String? ?? r['type'] as String? ?? 'other';
      final reportSeverity = r['severity'] == 'High' ? 'critical' : 'warning';
      final baseRadius = HazardAwareRoutingService.criticalRadiusFor(type);
      final loc = r['location'];
      zones.add(HazardZone(
        type:      type,
        severity:  reportSeverity,
        barangays: [(loc is Map ? loc['barangay'] as String? : null) ?? ''],
        center:    center,
        radius:    baseRadius * (reportSeverity == 'critical' ? 0.6 : 0.4) / 1000.0,
        createdAt: createdAt ?? DateTime.now(),
      ));
    }

    final hazardPoints = await HazardAwareRoutingService.loadAllHazardPoints();

    if (!mounted) return;
    setState(() {
      _hazardZones  = zones;
      _hazardPoints = hazardPoints;
    });

    if (_allCenters.isNotEmpty) {
      final annotated = HazardAwareRoutingService
          .annotateCentersWithHazards(_allCenters, _hazardPoints);
      setState(() { _evacuationCenters = annotated; _allCenters = annotated; });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchApprovedReports() async {
    try {
      final response = await ApiService().authenticatedGet('/api/reports/approved');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> raw = body is List ? body : (body['reports'] ?? []);
        return List<Map<String, dynamic>>.from(
            raw.where((r) => r['severity'] == 'High' || r['severity'] == 'Medium'));
      }
    } catch (e) {
      print('[Evacuation] Failed to fetch approved reports: $e');
    }
    return [];
  }

  LatLng _getBarangayCenter(String barangay) {
    const coords = {
      'san roque':    LatLng(14.5832, 121.1719),
      'mambugan':     LatLng(14.6206, 121.1416),
      'mayamot':      LatLng(14.6247, 121.1233),
      'san jose':     LatLng(14.6236, 121.2598),
      'cupang':       LatLng(14.6360, 121.1239),
      'dela paz':     LatLng(14.5901, 121.1703),
      'muntindilaw':  LatLng(14.5989, 121.1301),
      'bagong nayon': LatLng(14.6261, 121.1687),
      'beverly hills':LatLng(14.5843, 121.1582),
      'calawis':      LatLng(14.6731, 121.2423),
      'dalig':        LatLng(14.5763, 121.1820),
      'inarawan':     LatLng(14.6248, 121.1950),
      'san isidro':   LatLng(14.5916, 121.1838),
      'san juan':     LatLng(14.6278, 121.1770),
      'san luis':     LatLng(14.6043, 121.1981),
      'santa cruz':   LatLng(14.6157, 121.1694),
    };
    return coords[barangay.toLowerCase()] ?? _antipoloCenter;
  }

  // ── Mapbox Directions helpers ──────────────

  // Fetches all Mapbox walking route alternatives between two points.
  // Returns empty list on any failure — callers fall back to straight-line check.
  Future<List<List<LatLng>>> _fetchMapboxAlternatives(
      LatLng origin, LatLng dest) async {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (token.isEmpty) return [];
      final coords = '${origin.longitude},${origin.latitude};'
                     '${dest.longitude},${dest.latitude}';
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/$coords'
        '?alternatives=true&geometries=geojson&access_token=$token',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final routes = (jsonDecode(res.body)['routes'] as List?) ?? [];
      return routes.map<List<LatLng>>((r) =>
        (r['geometry']['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList()
      ).toList();
    } catch (e) {
      print('[Evacuation] Directions API error: $e');
      return [];
    }
  }

  // Fetches a single walking route forced through [via] — used to build a detour
  // when Mapbox returns no hazard-free alternative. Empty list on any failure.
  Future<List<LatLng>> _fetchMapboxRouteVia(
      LatLng origin, LatLng via, LatLng dest) async {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (token.isEmpty) return [];
      final coords = '${origin.longitude},${origin.latitude};'
                     '${via.longitude},${via.latitude};'
                     '${dest.longitude},${dest.latitude}';
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/$coords'
        '?alternatives=false&geometries=geojson&access_token=$token',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final routes = (jsonDecode(res.body)['routes'] as List?) ?? [];
      if (routes.isEmpty) return [];
      return (routes.first['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (e) {
      print('[Evacuation] Detour Directions API error: $e');
      return [];
    }
  }

  // Attempts to build a route that avoids [avoid] by inserting a perpendicular
  // detour waypoint clear of the worst hazard. Probes BOTH sides at escalating
  // offsets so it exhausts real alternatives before giving up. Returns the detour
  // geometry if it succeeds, else null. When [mustBeClean] the detour must clear
  // every hazard within warnRadius (warning case); otherwise it only needs to clear
  // criticals out of blockRadius (the impassable street).
  Future<List<LatLng>?> _tryForcedDetour(LatLng origin, LatLng dest,
      List<HazardPoint> avoid, List<HazardPoint> allHazards,
      {bool mustBeClean = false}) async {
    if (avoid.isEmpty) return null;
    final block = HazardAwareRoutingService.blockRadius;
    final warn  = HazardAwareRoutingService.warnRadius;
    final criticals = allHazards.where((h) => h.isCritical).toList();

    // Detour around the hazard closest to the straight path.
    final worst = avoid.reduce((a, b) =>
        _minDistanceToGeometry(a.location, [origin, dest]) <=
        _minDistanceToGeometry(b.location, [origin, dest]) ? a : b);

    // Escalating perpendicular offsets — a small nudge usually suffices, a larger
    // one is the fallback for tight grids.
    for (final offset in [block + 150, block + 450]) {
      final candidates = HazardAwareRoutingService.computeDetourWaypoints(
          worst.location, origin, dest, offsetMeters: offset);
      for (final via in candidates) {
        final geom = await _fetchMapboxRouteVia(origin, via, dest);
        if (geom.isEmpty) continue;
        final stillBlocked = mustBeClean
            ? HazardAwareRoutingService.hazardsWithin(geom, allHazards, warn).isNotEmpty
            : HazardAwareRoutingService.hazardsWithin(geom, criticals, block).isNotEmpty;
        if (!stillBlocked) return geom;
      }
    }
    return null;
  }

  // Fetches a single walking route through MULTIPLE ordered via-points
  // (origin;via1;via2;…;dest). Used for corridor detours that straddle a hazard.
  // overview=full so the geometry is dense enough for accurate hazard sampling.
  Future<List<LatLng>> _fetchMapboxRouteViaMany(
      LatLng origin, List<LatLng> vias, LatLng dest) async {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      if (token.isEmpty) return [];
      final pts = [origin, ...vias, dest];
      final coords = pts.map((p) => '${p.longitude},${p.latitude}').join(';');
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/$coords'
        '?alternatives=false&geometries=geojson&overview=full&access_token=$token',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final routes = (jsonDecode(res.body)['routes'] as List?) ?? [];
      if (routes.isEmpty) return [];
      return (routes.first['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (e) {
      print('[Evacuation] Corridor Directions API error: $e');
      return [];
    }
  }

  // Finds the SHORTEST walking route from [origin] to [dest] that clears every
  // critical hazard at blockRadius. Searches Mapbox's own alternatives plus
  // CORRIDOR detours (two via-points straddling each blocking hazard, both sides,
  // escalating offsets) — a single side waypoint can't force avoidance of a hazard
  // area, which is why earlier versions always failed and fell back to "blocked".
  // Returns the shortest clear geometry, or null ONLY when nothing clears.
  Future<List<LatLng>?> _findSafeWalkingRoute(LatLng origin, LatLng dest,
      List<HazardPoint> blocking, List<HazardPoint> allHazards) async {
    final criticals = allHazards.where((h) => h.isCritical).toList();
    final block = HazardAwareRoutingService.blockRadius;
    final hasToken = (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '').isNotEmpty;
    print('[Reroute] token=$hasToken blocking=${blocking.length} criticals=${criticals.length}');

    bool clears(List<LatLng> g) =>
        g.isNotEmpty &&
        HazardAwareRoutingService.hazardsWithin(g, criticals, block).isEmpty;

    final clear = <List<LatLng>>[];

    // 1) Mapbox's own walking alternatives.
    final alts = await _fetchMapboxAlternatives(origin, dest);
    for (final g in alts) {
      if (clears(g)) clear.add(g);
    }
    print('[Reroute] alternatives=${alts.length} clearedFromAlts=${clear.length}');

    // 2) Corridor detours around the blocking hazards nearest the path first.
    //    Cap HTTP probes so the search stays responsive.
    final ordered = [...blocking]..sort((a, b) =>
        _minDistanceToGeometry(a.location, [origin, dest])
            .compareTo(_minDistanceToGeometry(b.location, [origin, dest])));
    var probes = 0;
    for (final h in ordered.take(2)) {
      final corridors = HazardAwareRoutingService.computeCorridorWaypoints(
          h.location, origin, dest);
      for (final pair in corridors) {
        if (probes >= 10) break;
        probes++;
        final geom = await _fetchMapboxRouteViaMany(origin, pair, dest);
        if (clears(geom)) clear.add(geom);
      }
    }
    print('[Reroute] corridorsProbed=$probes totalCleared=${clear.length}');

    if (clear.isEmpty) {
      print('[Reroute] no clear route -> null (dead-end)');
      return null;
    }
    clear.sort((a, b) => _routeLengthMeters(a).compareTo(_routeLengthMeters(b)));
    final direct = HazardAwareRoutingService.distanceMeters(origin, dest);
    final lens = clear.map((g) => _routeLengthMeters(g).round()).toList();
    print('[Reroute] straightDist=${direct.toStringAsFixed(0)}m clearedLengths=$lens');
    print('[Reroute] chosen length=${_routeLengthMeters(clear.first).toStringAsFixed(0)}m');
    return clear.first;
  }

  double _routeLengthMeters(List<LatLng> geom) {
    double total = 0;
    for (int i = 1; i < geom.length; i++) {
      total += HazardAwareRoutingService.distanceMeters(geom[i - 1], geom[i]);
    }
    return total;
  }

  // Samples intermediate via-points DENSELY along the detour [geometry] so the
  // Mapbox Navigation SDK is pinned tightly onto the chosen safe corridor. Sparse
  // points let the navigator cut corners *between* them — straight back through
  // the hazard — which made reroutes look like "no reroute". We therefore lay
  // points roughly every (route / 22), ≥100 m apart, capped at 22 (Mapbox allows
  // 25 coordinates total = origin + 22 vias + dest). These are SILENT waypoints,
  // so they only shape the route, not the turn-by-turn stops; order is preserved.
  List<LatLng> _detourViaPoints(List<LatLng> geometry) {
    if (geometry.length < 3) return [];
    double total = 0;
    for (int i = 1; i < geometry.length; i++) {
      total += HazardAwareRoutingService.distanceMeters(geometry[i - 1], geometry[i]);
    }
    if (total <= 0) return [];

    const maxPts = 22;
    final interval = max(100.0, total / maxPts);
    final pts = <LatLng>[];
    double acc = 0;
    for (int i = 1; i < geometry.length - 1; i++) {
      acc += HazardAwareRoutingService.distanceMeters(geometry[i - 1], geometry[i]);
      if (acc >= interval) {
        pts.add(geometry[i]);
        acc = 0;
        if (pts.length >= maxPts) break;
      }
    }
    // Guarantee at least one shaping point for short detours.
    if (pts.isEmpty) pts.add(geometry[geometry.length ~/ 2]);
    return pts;
  }

  // Fetches every Mapbox walking alternative and tags each with the critical /
  // warning hazards that lie on it. The caller decides what to do per the
  // hazard-aware policy (auto-reroute around critical, ask the user on warning).
  Future<List<_RouteOption>> _analyzeRouteOptions(
      LatLng origin, LatLng dest, List<HazardPoint> hazards) async {
    final geometries = await _fetchMapboxAlternatives(origin, dest);
    final criticalHazards = hazards.where((h) => h.isCritical).toList();
    final options = <_RouteOption>[];
    for (final g in geometries) {
      // Blocking = critical hazards on the street itself (block radius).
      // Warnings = anything else within the wider warn radius.
      final blocking = HazardAwareRoutingService.hazardsWithin(
          g, criticalHazards, HazardAwareRoutingService.blockRadius);
      final near = HazardAwareRoutingService.hazardsWithin(
          g, hazards, HazardAwareRoutingService.warnRadius);
      options.add(_RouteOption(
        geometry:  g,
        criticals: blocking,
        warnings:  near.where((h) => !blocking.contains(h)).toList(),
      ));
    }
    return options;
  }

  // First fully clean option (no critical, no warning), or null.
  _RouteOption? _firstClean(Iterable<_RouteOption> options) {
    for (final o in options) {
      if (o.criticals.isEmpty && o.warnings.isEmpty) return o;
    }
    return null;
  }

  // Builds the waypoint list for [geometry]. Adds one apex via-point only when a
  // detour is being forced, so the SDK locks onto the chosen corridor without
  // looping; the plain origin→dest route is used otherwise.
  List<WayPoint> _wayPointsFor(
      LatLng origin, EvacuationCenter center, List<LatLng> geometry,
      {required bool forceDetour}) {
    final dest = center.latLng;
    if (!forceDetour) return [_wp('My Location', origin), _wp(center.name, dest)];
    return [
      _wp('My Location', origin),
      for (final p in _detourViaPoints(geometry)) _wpSilent(p),
      _wp(center.name, dest),
    ];
  }

  WayPoint _wp(String name, LatLng loc) =>
      WayPoint(name: name, latitude: loc.latitude, longitude: loc.longitude);

  WayPoint _wpSilent(LatLng loc) =>
      WayPoint(name: 'via', latitude: loc.latitude, longitude: loc.longitude, isSilent: true);

  // ── Navigation ─────────────────────────────

  Future<void> _startEvacuation(EvacuationCenter center) async {
    // Single gate covering every navigation entry point (card, bottom sheet,
    // list item, suggested card): a full center cannot be navigated to.
    if (center.status == 'full') {
      _showErrorDialog(
          'This center is full. Please choose another evacuation center.');
      return;
    }
    if (_currentLocation == null) {
      _showErrorDialog('Please wait for your location to load.');
      return;
    }

    setState(() {
      _destinationCenter = center;
      _isCalculatingRoute = true;
      _routeHazardWarnings = [];
      _showHazardWarningBanner = false;
    });
    _notifiedHazardIds.clear(); // per-trip: re-arm mid-nav hazard notifications

    if (await _hasConnectivity()) {
      // Build hazard points from state → Hive cache → displayed zones (in order).
      // This ensures detection works even if async loading hasn't finished yet.
      List<HazardPoint> hazardPoints = _hazardPoints.isNotEmpty
          ? _hazardPoints
          : await HazardAwareRoutingService.loadAllHazardPoints();
      if (hazardPoints.isEmpty && _hazardZones.isNotEmpty) {
        hazardPoints = _hazardZones.map((z) => HazardPoint(
          id: '${z.center.latitude},${z.center.longitude}',
          type: z.type,
          severity: z.severity,
          source: 'zone',
          label: '${z.type[0].toUpperCase()}${z.type.substring(1)} ${z.severity}',
          location: z.center,
          createdAt: z.createdAt,
        )).toList();
      }

      // If the destination itself sits ON a critical hazard (block radius), pick next safe center
      final destInCritical = hazardPoints.where((h) => h.isCritical).any((h) =>
          HazardAwareRoutingService.distanceMeters(center.latLng, h.location) <=
          HazardAwareRoutingService.blockRadius);

      if (destInCritical) {
        final safe = HazardAwareRoutingService.filterSafeCenters(_allCenters, hazardPoints);
        if (safe.isNotEmpty && safe.first.id != center.id) {
          safe.first.wasRerouted = true;
          if (mounted) setState(() => _isCalculatingRoute = false);
          _startEvacuation(safe.first);
          return;
        }
        // All centers in critical zone — proceed anyway
      }

      // Analyze every alternative, then apply the hazard policy:
      //   • critical/evacuate on route → auto-reroute around it (red dialog only
      //     if no route avoids it)
      //   • warning/watch on route     → ask the user: alternative or continue
      final origin  = _currentLocation!;
      final options = await _analyzeRouteOptions(origin, center.latLng, hazardPoints);

      List<WayPoint> wayPoints;
      bool wasRerouted = false;

      if (options.isEmpty) {
        // Directions API unavailable → straight-line hazard check, plain route.
        final crits = HazardAwareRoutingService.getHazardsNearStraightLine(
            origin, center.latLng,
            hazardPoints.where((h) => h.isCritical).toList(),
            HazardAwareRoutingService.blockRadius);
        final near = HazardAwareRoutingService.getHazardsNearStraightLine(
            origin, center.latLng, hazardPoints,
            HazardAwareRoutingService.warnRadius);
        _routeHazardWarnings = near.where((h) => !crits.contains(h)).toList();
        _lastRouteGeometry = [];
        if (crits.isNotEmpty) {
          final proceed = await _showCriticalHazardDialog(crits.first);
          if (!proceed) {
            if (mounted) setState(() => _isCalculatingRoute = false);
            return;
          }
        }
        wayPoints = _wayPointsFor(origin, center, const [], forceDetour: false);
      } else {
        final primary = options.first;

        if (primary.criticals.isNotEmpty) {
          // CRITICAL/EVACUATE → reroute automatically to the SHORTEST safe route
          // (Mapbox alternatives + forced detours). Only give up if nothing clears.
          final rerouteGeom = await _findSafeWalkingRoute(
              origin, center.latLng, primary.criticals, hazardPoints);

          if (rerouteGeom != null) {
            _lastRouteGeometry   = rerouteGeom;
            _routeHazardWarnings = _warningsOnRoute(rerouteGeom, hazardPoints);
            wasRerouted = true;
            wayPoints = _wayPointsFor(origin, center, rerouteGeom, forceDetour: true);
          } else {
            // No route avoids it → let the user decide.
            _lastRouteGeometry = primary.geometry;
            _routeHazardWarnings = [];
            final proceed = await _showCriticalHazardDialog(primary.criticals.first);
            if (!proceed) {
              if (mounted) setState(() => _isCalculatingRoute = false);
              return;
            }
            wayPoints = _wayPointsFor(origin, center, primary.geometry, forceDetour: false);
          }
        } else if (primary.warnings.isNotEmpty) {
          // WARNING/WATCH → offer the user a choice. Prefer a hazard-free Mapbox
          // alternative; if none, try to force a detour so "Use Alternative" is
          // still a real option.
          List<LatLng>? altGeom = _firstClean(options.skip(1))?.geometry;
          altGeom ??= await _tryForcedDetour(
              origin, center.latLng, primary.warnings, hazardPoints,
              mustBeClean: true);

          final choice = await _showHazardOnRouteDialog(
              primary.warnings, hasAlternative: altGeom != null);
          if (choice == _RouteChoice.cancel) {
            if (mounted) setState(() => _isCalculatingRoute = false);
            return;
          }
          if (choice == _RouteChoice.alternative && altGeom != null) {
            _lastRouteGeometry   = altGeom;
            _routeHazardWarnings = _warningsOnRoute(altGeom, hazardPoints);
            wasRerouted = true;
            wayPoints = _wayPointsFor(origin, center, altGeom, forceDetour: true);
          } else {
            // Continue on the warned route.
            _lastRouteGeometry   = primary.geometry;
            _routeHazardWarnings = primary.warnings;
            wayPoints = _wayPointsFor(origin, center, primary.geometry, forceDetour: false);
          }
        } else {
          // Clean primary route.
          _lastRouteGeometry   = primary.geometry;
          _routeHazardWarnings = [];
          wayPoints = _wayPointsFor(origin, center, primary.geometry, forceDetour: false);
        }
      }

      final wasAdjusted = wasRerouted;

      await HiveService.cacheEvacuationRoute({
        'centerId': center.id,
        'start': {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude},
        'end':   {'lat': center.latitude, 'lng': center.longitude, 'name': center.name},
        'waypoints': wayPoints
            .sublist(1, wayPoints.length - 1)
            .map((w) => {'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        'geometry': _lastRouteGeometry
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'adjustedForHazards': wasAdjusted,
        'cachedAt': DateTime.now().toIso8601String(),
      }, centerId: center.id);

      if (mounted) {
        setState(() => _isCalculatingRoute = false);
        if (wasAdjusted) _showRoutingAdjustedSnackbar();
        if (_routeHazardWarnings.isNotEmpty) {
          setState(() => _showHazardWarningBanner = true);
          _showHazardOnRouteSnackbar(_routeHazardWarnings);
        }
      }

      try {
        await _mapboxNavigation?.startNavigation(
            wayPoints: wayPoints, options: _buildMapboxOptions());
      } catch (e) {
        print('[Evacuation] Navigation start error: $e');
        if (mounted) {
          _showErrorDialog('Failed to start navigation. Please try again.');
          setState(() => _isCalculatingRoute = false);
        }
      }

    } else {
      // ── OFFLINE PATH ──────────────────────────────────────────────────────
      // Restore the SAME Mapbox/hazard-aware route the user computed for THIS
      // center while online (keyed per-center), so the OSM offline route matches
      // what Mapbox suggested — not whatever center was navigated last.
      final cached = await HiveService.getCachedEvacuationRouteForCenter(center.id);
      if (mounted) setState(() { _isCalculatingRoute = false; _isOfflineMode = true; });

      final geoRaw = (cached?['geometry'] as List?) ?? [];
      final geometry = geoRaw.map((g) {
        final m = g is Map<String, dynamic> ? g : Map<String, dynamic>.from(g as Map);
        return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
      }).toList();

      if (geometry.isNotEmpty) {
        if (mounted) setState(() => _offlineRouteGeometry = geometry);
        _mapController.fitCamera(CameraFit.coordinates(
          coordinates: geometry,
          padding: const EdgeInsets.all(48),
        ));
      } else {
        // No cached Mapbox route for this center (never navigated here online) →
        // straight-line compass guidance as a last resort.
        if (mounted) setState(() => _isCompassMode = true);
      }
    }
  }

  // Informational hazards on a route: anything within warnRadius that isn't a
  // blocking critical (within blockRadius). Drives the orange banner + snackbar.
  List<HazardPoint> _warningsOnRoute(List<LatLng> geom, List<HazardPoint> hazards) {
    final blocking = HazardAwareRoutingService.hazardsWithin(
        geom, hazards.where((h) => h.isCritical).toList(),
        HazardAwareRoutingService.blockRadius);
    final near = HazardAwareRoutingService.hazardsWithin(
        geom, hazards, HazardAwareRoutingService.warnRadius);
    return near.where((h) => !blocking.contains(h)).toList();
  }

  double _minDistanceToGeometry(LatLng p, List<LatLng> geometry) {
    double best = double.infinity;
    for (final g in geometry) {
      final d = HazardAwareRoutingService.distanceMeters(p, g);
      if (d < best) best = d;
    }
    return best;
  }

  Future<bool> _showCriticalHazardDialog(HazardPoint hazard) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.dangerous, color: Colors.red),
          SizedBox(width: 8),
          Text('Hazard Cannot Be Avoided'),
        ]),
        content: Text(
          'An active ${hazard.label} has been reported and all available '
          'routes pass through the affected area.\n\n'
          'Proceeding may be dangerous. Only continue if it is safe to do so.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Proceed Anyway',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  // Warning/watch hazard on the route → let the user choose. Offers "Use
  // alternative" only when a hazard-free alternative actually exists, plus
  // "Continue" (proceed on the warned route) and "Cancel".
  Future<_RouteChoice> _showHazardOnRouteDialog(
      List<HazardPoint> warnings, {required bool hasAlternative}) async {
    final h = warnings.first;
    final color = _getHazardColor(h.severity);
    final summary = warnings.length == 1
        ? 'A ${h.label} has been reported on your route.'
        : '${warnings.length} hazards have been reported on your route '
          '(${h.label} and ${warnings.length - 1} more).';
    final result = await showDialog<_RouteChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 8),
          const Expanded(child: Text('Hazard on Route')),
        ]),
        content: Text(
          hasAlternative
              ? '$summary\n\nWould you like to take an alternative route that '
                'avoids it, or continue on this one?'
              : '$summary\n\nThere is no alternative route that avoids it. '
                'Continue with caution?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _RouteChoice.cancel),
            child: const Text('Cancel'),
          ),
          if (hasAlternative)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _RouteChoice.alternative),
              child: const Text('Use Alternative'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _RouteChoice.continueRoute),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? _RouteChoice.cancel;
  }

  // Non-blocking heads-up shown after navigation starts when the user chose to
  // continue on a route that still has a watch/warning hazard.
  void _showHazardOnRouteSnackbar(List<HazardPoint> warnings) {
    if (!mounted || warnings.isEmpty) return;
    final h = warnings.first;
    final message = warnings.length == 1
        ? '${h.label} reported on this street — proceed with caution'
        : '${h.label} and ${warnings.length - 1} more reported on this street — proceed with caution';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: _getHazardColor(h.severity),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showRoutingAdjustedSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.alt_route, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text('Route adjusted for safety — avoiding hazard zone')),
      ]),
      backgroundColor: Colors.deepOrange,
      duration: const Duration(seconds: 3),
    ));
  }

  void _stopNavigation() {
    _mapboxNavigation?.finishNavigation();
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _destinationCenter = null;
        _isCompassMode = false;
        _offlineRouteGeometry = [];
      });
    }
  }

  // ── Map controls ───────────────────────────

  void _zoomIn() {
    if (!mounted) return;
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(1, 18);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    if (!mounted) return;
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(1, 18);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  // ── Color/icon helpers ─────────────────────

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF10B981);
      case 'almost_full':
        return const Color(0xFFF59E0B);
      case 'full':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'almost_full':
        return 'Almost Full';
      case 'full':
        return 'FULL';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'almost_full':
        return Icons.warning;
      case 'full':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getHazardColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'evacuate':
        return const Color(0xFFDC2626);  // red
      case 'warning':
      case 'high':
        return const Color(0xFFF97316);  // orange
      case 'watch':
      case 'moderate':
        return const Color(0xFFFBBF24);  // yellow
      default:
        return const Color(0xFF6366F1);  // indigo
    }
  }

  double _getHazardOpacity(String severity) {
    switch (severity) {
      case 'critical':
      case 'evacuate':
        return 0.50;
      case 'warning':
      case 'high':
        return 0.40;
      default:
        return 0.25;  // watch / moderate — lighter so map stays readable
    }
  }

  Color _hazardBadgeColor(String severity) {
    switch (severity) {
      case 'critical': return const Color(0xFFDC2626);
      case 'high':     return const Color(0xFFF59E0B);
      case 'moderate': return const Color(0xFFEAB308);
      default:         return Colors.transparent;
    }
  }

  String _hazardSeverityLabel(String severity) {
    switch (severity) {
      case 'critical': return 'Critical';
      case 'high':     return 'Warning';
      case 'moderate': return 'Watch';
      default:         return '';
    }
  }

  // ── Compass widget ─────────────────────────

  Widget _buildCompassWidget(EvacuationCenter dest, LatLng current) {
    final dist    = HazardAwareRoutingService.distanceMeters(current, dest.latLng);
    final bearing = _bearing(current, dest.latLng);
    final distTxt = dist < 1000
        ? '${dist.round()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.explore, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dest.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('$distTxt  •  ${bearing.round()}°',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Text('No cached route — navigate manually',
                style: TextStyle(color: Colors.orange, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  double _bearing(LatLng from, LatLng to) {
    final dLng = _toRadians(to.longitude - from.longitude);
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  // ── Dialogs ────────────────────────────────

  void _showArrivalDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Arrived Safely!'),
          ],
        ),
        content: Text('You have arrived at ${_destinationCenter?.name}'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // A center has a dialable hotline only when the backend supplied a number.
  bool _hasContact(EvacuationCenter c) =>
      c.contact.trim().isNotEmpty && c.contact.trim().toUpperCase() != 'N/A';

  Future<void> _makeCall(String contact) async {
    final cleanNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.isEmpty) {
      _showErrorDialog('No hotline available for this center.');
      return;
    }
    final url = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showErrorDialog('Unable to make call');
    }
  }

  // ── Bottom sheet: center details ───────────

  void _showCenterDetails(EvacuationCenter center) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getStatusColor(center.status),
                    child: Icon(_getStatusIcon(center.status),
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(center.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          _getStatusText(center.status),
                          style:
                              TextStyle(color: _getStatusColor(center.status)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _buildDetailRow(Icons.location_on, center.address),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.phone, center.contact),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.people,
                  '${center.currentOccupancy} / ${center.capacity} people'),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.access_time, center.operatingHours),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.directions_walk, center.distance),

              const SizedBox(height: 16),
              const Text('Facilities:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    center.facilities.map((f) => Chip(label: Text(f))).toList(),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hasContact(center)
                          ? () {
                              Navigator.pop(context);
                              _makeCall(center.contact);
                            }
                          : null,
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: center.status == 'full'
                          ? null
                          : () {
                              Navigator.pop(context);
                              _startEvacuation(center);
                            },
                      icon: const Icon(Icons.emergency, size: 18),
                      label: Text(
                          center.status == 'full' ? 'Center Full' : 'Start Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  // ── Nearest center suggestion ──────────────

  EvacuationCenter? get _suggestedCenter {
    if (_evacuationCenters.isEmpty) return null;
    try {
      return _evacuationCenters.firstWhere((c) => c.status != 'full');
    } catch (_) {
      return _evacuationCenters.first;
    }
  }

  Widget _buildSuggestedCenterCard(EvacuationCenter center) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.my_location, color: Colors.white70, size: 13),
              SizedBox(width: 4),
              Text('Nearest Available Center',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
            const SizedBox(height: 4),
            Text(center.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.directions_walk, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(center.distance,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.people, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(
                '${center.currentOccupancy}/${center.capacity}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startEvacuation(center),
                icon: const Icon(Icons.emergency, size: 16),
                label: const Text('Navigate Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Center list (always attaches scrollController) ────────────────────

  Widget _buildCenterList(ScrollController scrollController) {
    if (_isLoadingCenters) {
      return ListView(
        controller: scrollController,
        children: const [
          SizedBox(height: 40),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_evacuationCenters.isEmpty) {
      return ListView(
        controller: scrollController,
        children: const [
          SizedBox(height: 40),
          Center(child: Text('No evacuation centers found')),
        ],
      );
    }
    final hasSuggested = _currentLocation != null && _suggestedCenter != null;
    final listCenters = hasSuggested
        ? _evacuationCenters.where((c) => c.id != _suggestedCenter!.id).toList()
        : _evacuationCenters;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: listCenters.length + (hasSuggested ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasSuggested && index == 0) {
          return _buildSuggestedCenterCard(_suggestedCenter!);
        }
        return _buildCenterCard(listCenters[hasSuggested ? index - 1 : index]);
      },
    );
  }

  // ── Center list card ───────────────────────

  Widget _buildCenterCard(EvacuationCenter center) {
    final statusColor = _getStatusColor(center.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCenterDetails(center),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor,
                child: Icon(_getStatusIcon(center.status),
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      center.address,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${center.currentOccupancy}/${center.capacity}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.directions_walk,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          center.distance,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    if (center.hazardSeverityLevel != 'none') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _hazardBadgeColor(center.hazardSeverityLevel),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.warning_amber_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            center.wasRerouted
                                ? 'Rerouted • ${center.hazardType ?? "Hazard"}'
                                : '${_hazardSeverityLabel(center.hazardSeverityLevel)} • '
                                  '${center.hazardType ?? "Hazard"}',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.emergency,
                        color: center.status == 'full'
                            ? Colors.grey
                            : Colors.red),
                    tooltip: center.status == 'full' ? 'Center full' : 'Navigate',
                    onPressed: center.status == 'full'
                        ? null
                        : () => _startEvacuation(center),
                  ),
                  IconButton(
                    icon: Icon(Icons.phone,
                        color:
                            _hasContact(center) ? Colors.blue : Colors.grey),
                    tooltip: _hasContact(center) ? 'Call' : 'No hotline',
                    onPressed: _hasContact(center)
                        ? () => _makeCall(center.contact)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Base map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _antipoloCenter,
              initialZoom: _currentZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.e_telly.app',
              ),

              // Cached offline route
              if (_offlineRouteGeometry.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _offlineRouteGeometry,
                      strokeWidth: 5.0,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),

              // Hazard pin markers — exact location, no oversized circles
              if (_hazardZones.isNotEmpty)
                MarkerLayer(
                  markers: _hazardZones.map((hazard) {
                    final color = _getHazardColor(hazard.severity);
                    return Marker(
                      width: 32,
                      height: 32,
                      point: hazard.center,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 16),
                      ),
                    );
                  }).toList(),
                ),

              // Markers
              MarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    Marker(
                      width: 30,
                      height: 30,
                      point: _currentLocation!,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.4),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.my_location,
                              color: Colors.blue, size: 16),
                        ),
                      ),
                    ),

                  if (_destinationCenter != null && _isCalculatingRoute)
                    Marker(
                      width: 40,
                      height: 40,
                      point: _destinationCenter!.latLng,
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.flag, color: Colors.white, size: 16),
                      ),
                    ),

                  ..._evacuationCenters.map((center) {
                    return Marker(
                      width: 32,
                      height: 32,
                      point: center.latLng,
                      child: GestureDetector(
                        onTap: () {
                          _mapController.move(center.latLng, 15);
                          _showCenterDetails(center);
                        },
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: _getStatusColor(center.status),
                          child: const Icon(Icons.location_on,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Loading banners ──
          if (_isLoadingLocation || _isLoadingCenters)
            Positioned(
              top: 60,
              left: 16,
              right: 72,
              child: _infoBanner(
                color: Colors.blue,
                icon: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                message: _isLoadingLocation
                    ? 'Getting your location…'
                    : 'Loading evacuation centers…',
              ),
            ),

          if (_isCalculatingRoute)
            Positioned(
              top: 60,
              left: 16,
              right: 72,
              child: _infoBanner(
                color: Colors.orange,
                icon: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                message: 'Calculating safe route…',
              ),
            ),

          if (_locationError != null)
            Positioned(
              top: 60,
              left: 16,
              right: 72,
              child: _infoBanner(
                color: Colors.red,
                icon: const Icon(Icons.location_off,
                    color: Colors.white, size: 18),
                message: _locationError!,
              ),
            ),

          // ── Map zoom + location controls ──
          Positioned(
            top: 60,
            right: 16,
            child: Column(
              children: [
                _mapButton(Icons.add, _zoomIn),
                const SizedBox(height: 8),
                _mapButton(Icons.remove, _zoomOut),
                const SizedBox(height: 8),
                _mapButton(Icons.my_location, _centerOnCurrentLocation,
                    color: Colors.blue),
              ],
            ),
          ),

          // ── Active navigation banner ──
          if (_isNavigating && _destinationCenter != null)
            Positioned(
              top: 60,
              left: 16,
              right: 72,
              child: _infoBanner(
                color: Colors.green,
                icon:
                    const Icon(Icons.navigation, color: Colors.white, size: 18),
                message: 'Navigating to ${_destinationCenter!.name}',
                trailing: TextButton(
                  onPressed: _stopNavigation,
                  child: const Text('Stop',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),

          // ── Watch/Warning route banner ──
          if (_showHazardWarningBanner && _routeHazardWarnings.isNotEmpty)
            Positioned(
              top: _isNavigating ? 100 : 60,
              left: 16,
              right: 72,
              child: Material(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_routeHazardWarnings.first.label} on route — proceed with caution',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showHazardWarningBanner = false),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ]),
                ),
              ),
            ),

          // ── Offline mode banner ──
          if (_isOfflineMode)
            Positioned(
              bottom: 260,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.blueGrey.shade700,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                    child: Text(
                      _offlineRouteGeometry.isNotEmpty
                          ? 'Offline — Showing cached route'
                          : 'Offline Mode — Using cached data',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  ]),
                ),
              ),
            ),

          // ── Compass mode (offline + no cached route) ──
          if (_isCompassMode && _destinationCenter != null && _currentLocation != null)
            Positioned(
              bottom: 300,
              left: 16,
              right: 16,
              child: _buildCompassWidget(_destinationCenter!, _currentLocation!),
            ),

          // ── Bottom draggable list (only when not navigating) ──
          if (!_isNavigating)
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_city, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Evacuation Centers',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (!_isLoadingCenters)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_evacuationCenters.length} Centers',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Hazard warning strip
                      if (_hazardZones.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_hazardZones.length} active hazard zone(s) in area. '
                                  'Route will auto-avoid critical zones.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Expanded(child: _buildCenterList(scrollController)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Small reusable widgets ─────────────────

  Widget _mapButton(IconData icon, VoidCallback onPressed,
      {Color color = Colors.black87}) {
    return FloatingActionButton(
      heroTag: icon.codePoint.toString(),
      mini: true,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      elevation: 2,
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _infoBanner({
    required Color color,
    required Widget icon,
    required String message,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
