import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/alert_service.dart';
import '../dbhelper/mongodb.dart';


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

    String statusValue = 'available';
    if (json['available'] != null) {
      statusValue = json['available'] == true ? 'available' : 'full';
    } else if (json['status'] != null) {
      statusValue = json['status'].toString();
    }

    double lat = 14.5865;
    double lng = 121.1756;
    if (json['latitude'] != null) lat = (json['latitude'] as num).toDouble();
    if (json['longitude'] != null) lng = (json['longitude'] as num).toDouble();

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
      capacity: json['capacity'] is int
          ? json['capacity']
          : (json['capacity'] ?? 100).toInt(),
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
  bool _isLoadingHazards = true;
  bool _isLoadingCenters = true;

  // Mapbox Navigation
  MapBoxNavigation? _mapboxNavigation;
  MapBoxOptions? _mapboxOptions;
  bool _isNavigating = false;
  bool _isCalculatingRoute = false;
  EvacuationCenter? _destinationCenter;

  // Location stream
  StreamSubscription<Position>? _positionSubscription;

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
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    _mapboxNavigation?.finishNavigation();
    super.dispose();
  }

  // ── Mapbox Navigation Init ─────────────────

  void _initMapboxNavigation() {
    // FIX: Use the no-arg constructor then register the listener separately.
    // Some versions expose a singleton via MapBoxNavigation.instance — if the
    // line below still fails, replace it with:
    //   _mapboxNavigation = MapBoxNavigation.instance;
    _mapboxNavigation = MapBoxNavigation();
    _mapboxNavigation!.registerRouteEventListener(_onRouteEvent);

    _mapboxOptions = MapBoxOptions(
      initialLatitude: _currentLocation?.latitude ?? 14.5865,
      initialLongitude: _currentLocation?.longitude ?? 121.1756,
      zoom: 15.0,
      tilt: 0.0,
      bearing: 0.0,
      enableRefresh: true,
      alternatives: true,
      voiceInstructionsEnabled: true,
      bannerInstructionsEnabled: true,
      mode: MapBoxNavigationMode.walking,
      isOptimized: true,
      units: VoiceUnits.metric,
      simulateRoute: false, // set true to test without physically moving
      language: "en",
    );
  }

  Future<void> _onRouteEvent(e) async {
    switch (e.eventType) {
      case MapBoxEvent.route_built:
        if (mounted) setState(() => _isNavigating = true);
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
    setState(() {
      _evacuationCenters = _allCenters.map((center) {
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

      _evacuationCenters.sort((a, b) {
        final distA = _parseDistanceToMeters(a.distance);
        final distB = _parseDistanceToMeters(b.distance);
        return distA.compareTo(distB);
      });
    });
  }

  // ── Data loading ───────────────────────────

  Future<void> _loadEvacuationCenters() async {
    if (!mounted) return;
    setState(() => _isLoadingCenters = true);

    try {
      if (!MongoDatabase.isConnected) await MongoDatabase.connect();

      final centersData = await MongoDatabase.getAllEvacuationCenters();
      final centers =
          centersData.map((data) => EvacuationCenter.fromJson(data)).toList();

      List<EvacuationCenter> result = centers;

      if (_currentLocation != null) {
        result = centers.map((center) {
          final distance =
              _calculateDistance(_currentLocation!, center.latLng);
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

      if (mounted) {
        setState(() {
          _allCenters = result;
          _evacuationCenters = result;
          _isLoadingCenters = false;
        });
      }
    } catch (e) {
      print('❌ Error loading evacuation centers: $e');
      if (mounted) {
        setState(() => _isLoadingCenters = false);
        _showErrorDialog('Failed to load evacuation centers: $e');
      }
    }
  }

  Future<void> _loadHazardZones() async {
    if (!mounted) return;
    setState(() => _isLoadingHazards = true);

    try {
      if (!MongoDatabase.isConnected) await MongoDatabase.connect();

      final alerts = await MongoDatabase.getActiveAlerts();
      final List<HazardZone> hazards = [];

      for (var alert in alerts) {
        if (alert['severity'] == 'critical' || alert['severity'] == 'warning') {
          final barangays = List<String>.from(alert['barangays'] ?? []);
          if (barangays.isNotEmpty) {
            hazards.add(HazardZone(
              type: alert['type'] ?? 'hazard',
              severity: alert['severity'] ?? 'warning',
              barangays: barangays,
              center: _getBarangayCenter(barangays[0]),
              radius: 1.5,
              createdAt: DateTime.parse(
                  alert['createdAt'] ?? DateTime.now().toIso8601String()),
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _hazardZones = hazards;
          _isLoadingHazards = false;
        });
      }
    } catch (e) {
      print('Error loading hazards: $e');
      if (mounted) setState(() => _isLoadingHazards = false);
    }
  }

  LatLng _getBarangayCenter(String barangay) {
    final Map<String, LatLng> barangayCoordinates = {
      'San Roque': const LatLng(14.5865, 121.1756),
      'Mambugan': const LatLng(14.6058, 121.1523),
      'Mayamot': const LatLng(14.6154, 121.1589),
      'San Jose': const LatLng(14.5982, 121.1645),
      'Cupang': const LatLng(14.5721, 121.1654),
      'Dela Paz': const LatLng(14.5698, 121.1723),
      'muntindilaw': const LatLng(14.5900, 121.1700),
    };
    final key = barangay.toLowerCase();
    return barangayCoordinates.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == key,
          orElse: () => MapEntry('default', _antipoloCenter),
        )
        .value;
  }

  // ── Navigation ─────────────────────────────

  Future<void> _startEvacuation(EvacuationCenter center) async {
    if (_currentLocation == null) {
      _showErrorDialog('Please wait for your location to load.');
      return;
    }

    setState(() {
      _destinationCenter = center;
      _isCalculatingRoute = true;
    });

    // Warn if hazard is near destination
    final hasNearbyHazard = _hazardZones.any((hazard) =>
        _calculateDistance(center.latLng, hazard.center) < hazard.radius);

    if (hasNearbyHazard) {
      final proceed = await _showHazardWarningDialog(center.name);
      if (!proceed) {
        if (mounted) setState(() => _isCalculatingRoute = false);
        return;
      }
    }

    final wayPoints = [
      WayPoint(
        name: "My Location",
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      ),
      WayPoint(
        name: center.name,
        latitude: center.latitude,
        longitude: center.longitude,
      ),
    ];

    if (mounted) setState(() => _isCalculatingRoute = false);

    await _mapboxNavigation?.startNavigation(
      wayPoints: wayPoints,
      options: _mapboxOptions!,
    );
  }

  void _stopNavigation() {
    _mapboxNavigation?.finishNavigation();
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _destinationCenter = null;
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
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ── Dialogs ────────────────────────────────

  Future<bool> _showHazardWarningDialog(String centerName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Hazard Warning'),
              ],
            ),
            content: Text(
              'There is an active hazard zone near "$centerName". '
              'Proceed with caution — emergency services may be present.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Choose Another'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

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

  Future<void> _makeCall(String contact) async {
    final cleanNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');
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
              // Handle bar
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

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _makeCall(center.contact);
                      },
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
                      onPressed: () {
                        Navigator.pop(context);
                        _startEvacuation(center);
                      },
                      icon: const Icon(Icons.emergency, size: 18),
                      label: const Text('Start Navigation'),
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
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emergency, color: Colors.red),
                    tooltip: 'Navigate',
                    onPressed: () => _startEvacuation(center),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.blue),
                    tooltip: 'Call',
                    onPressed: () => _makeCall(center.contact),
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

              // Hazard circles
              if (_hazardZones.isNotEmpty)
                CircleLayer(
                  circles: _hazardZones.map((hazard) {
                    return CircleMarker(
                      point: hazard.center,
                      radius: hazard.radius * 1000,
                      color: _getHazardColor(hazard.severity).withOpacity(0.4),
                      borderStrokeWidth: 2,
                      borderColor: _getHazardColor(hazard.severity),
                      useRadiusInMeter: true,
                    );
                  }).toList(),
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Current location
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

                  // Destination pin (shown while calculating)
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

                  // Center pins
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
                message: 'Starting Mapbox navigation…',
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
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
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
                                  'Mapbox will route around them.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // List
                      if (_isLoadingCenters)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_evacuationCenters.isEmpty)
                        const Expanded(
                          child:
                              Center(child: Text('No evacuation centers found')),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _evacuationCenters.length,
                            itemBuilder: (context, index) =>
                                _buildCenterCard(_evacuationCenters[index]),
                          ),
                        ),
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