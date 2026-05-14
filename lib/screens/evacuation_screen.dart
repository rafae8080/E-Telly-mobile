import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  
  factory EvacuationCenter.fromJson(Map<String, dynamic> json, {String? distance}) {
    // Build address from location and barangay
    String addressValue = 'Address not available';
    if (json['location'] != null && json['location'].toString().isNotEmpty) {
      addressValue = json['location'].toString();
      if (json['barangay'] != null && json['barangay'].toString().isNotEmpty) {
        addressValue += ', Brgy. ${json['barangay']}';
      }
    } else if (json['barangay'] != null) {
      addressValue = 'Brgy. ${json['barangay']}';
    }
    
    // Get occupancy (use 'occupancy' field, not 'currentOccupancy')
    int occupancy = 0;
    if (json['occupancy'] != null) {
      occupancy = json['occupancy'] is int ? json['occupancy'] : (json['occupancy'] as num).toInt();
    } else if (json['currentOccupancy'] != null) {
      occupancy = json['currentOccupancy'] is int ? json['currentOccupancy'] : (json['currentOccupancy'] as num).toInt();
    }
    
    // Get status from 'available' boolean
    String statusValue = 'available';
    if (json['available'] != null) {
      statusValue = json['available'] == true ? 'available' : 'full';
    } else if (json['status'] != null) {
      statusValue = json['status'].toString();
    }
    
    // Get coordinates (use default if not present)
    double lat = 14.5865;
    double lng = 121.1756;
    
    if (json['latitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
    }
    if (json['longitude'] != null) {
      lng = (json['longitude'] as num).toDouble();
    }
    
    // Get facilities
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
      capacity: json['capacity'] is int ? json['capacity'] : (json['capacity'] ?? 100).toInt(),
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
  
  Map<String, dynamic> toJson() {
    return {
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

class TurnByTurnStep {
  final String instruction;
  final String streetName;
  final double distance;
  final double duration;
  final String maneuverType;
  final String modifier;
  final LatLng location;
  
  TurnByTurnStep({
    required this.instruction,
    this.streetName = '',
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.modifier,
    required this.location,
  });
}

class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});

  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  List<EvacuationCenter> _evacuationCenters = [];
  List<EvacuationCenter> _allCenters = [];
  
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  double _currentZoom = 14;
  List<HazardZone> _hazardZones = [];
  bool _isLoadingHazards = true;
  bool _isLoadingCenters = true;
  
  bool _isNavigating = false;
  List<LatLng> _currentRoute = [];
  List<TurnByTurnStep> _turnByTurnSteps = [];
  EvacuationCenter? _destinationCenter;
  int _currentStepIndex = 0;
  double _totalDistance = 0;
  double _totalDuration = 0;
  bool _isCalculatingRoute = false;
  String? _rerouteMessage;
  bool _hasHazardsOnRoute = false;
  
  StreamSubscription<Position>? _positionSubscription;
  
  final LatLng _antipoloCenter = const LatLng(14.5865, 121.1756);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEvacuationCenters();
    _loadHazardZones();
    _startLocationUpdates();
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }
  
  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (!mounted) return;
      
      final newLocation = LatLng(position.latitude, position.longitude);
      
      if (_isNavigating && _currentLocation != null) {
        final distanceMoved = _calculateDistance(_currentLocation!, newLocation);
        if (distanceMoved > 0.05) {
          setState(() {
            _currentLocation = newLocation;
          });
          if (_destinationCenter != null) {
            _checkAndReroute();
          }
        }
      } else {
        setState(() {
          _currentLocation = newLocation;
        });
        if (_allCenters.isNotEmpty) {
          _updateDistances();
        }
      }
    });
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
  
  double _parseDistanceToMeters(String distanceStr) {
    if (distanceStr.contains('km')) {
      return double.parse(distanceStr.replaceAll(' km', '')) * 1000;
    } else {
      return double.parse(distanceStr.replaceAll(' m', '')).toDouble();
    }
  }

  Future<void> _loadEvacuationCenters() async {
    if (!mounted) return;
    setState(() => _isLoadingCenters = true);
    
    try {
      if (!MongoDatabase.isConnected) {
        await MongoDatabase.connect();
      }
      
      final centersData = await MongoDatabase.getAllEvacuationCenters();
      print('📊 Raw data count: ${centersData.length}');
      
      final centers = centersData.map((data) => EvacuationCenter.fromJson(data)).toList();
      print('✅ Parsed ${centers.length} centers');
      
      if (_currentLocation != null) {
        final centersWithDistance = centers.map((center) {
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
        
        centersWithDistance.sort((a, b) {
          final distA = _parseDistanceToMeters(a.distance);
          final distB = _parseDistanceToMeters(b.distance);
          return distA.compareTo(distB);
        });
        
        if (mounted) {
          setState(() {
            _allCenters = centersWithDistance;
            _evacuationCenters = centersWithDistance;
            _isLoadingCenters = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _allCenters = centers;
            _evacuationCenters = centers;
            _isLoadingCenters = false;
          });
        }
      }
      
      print('🎉 Final count: ${_evacuationCenters.length} centers loaded');
      
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
      if (!MongoDatabase.isConnected) {
        await MongoDatabase.connect();
      }
      
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
              createdAt: DateTime.parse(alert['createdAt'] ?? DateTime.now().toIso8601String()),
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
    return barangayCoordinates.entries.firstWhere(
      (e) => e.key.toLowerCase() == key,
      orElse: () => MapEntry('default', _antipoloCenter),
    ).value;
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

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
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

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(point1.latitude)) * cos(_toRadians(point2.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (pi / 180);

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _currentZoom);
    } else {
      _getCurrentLocation();
    }
  }
  
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available': return const Color(0xFF10B981);
      case 'almost_full': return const Color(0xFFF59E0B);
      case 'full': return const Color(0xFFDC2626);
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available': return 'Available';
      case 'almost_full': return 'Almost Full';
      case 'full': return 'FULL';
      default: return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available': return Icons.check_circle;
      case 'almost_full': return Icons.warning;
      case 'full': return Icons.cancel;
      default: return Icons.help;
    }
  }
  
  Color _getHazardColor(String severity) {
    switch (severity) {
      case 'critical': return const Color(0xFFDC2626);
      case 'warning': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6366F1);
    }
  }

  Future<void> _startEvacuation(EvacuationCenter center) async {
    if (_currentLocation == null) {
      _showErrorDialog('Please wait for location to load');
      return;
    }
    
    if (!mounted) return;
    
    setState(() {
      _isNavigating = true;
      _destinationCenter = center;
      _isCalculatingRoute = true;
      _rerouteMessage = null;
      _hasHazardsOnRoute = false;
    });
    
    await _calculateTurnByTurnRoute(_currentLocation!, center.latLng);
    
    if (mounted) {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
    
    if (_currentRoute.isNotEmpty) {
      _fitRouteToMap();
    }
  }
  
  Future<void> _checkAndReroute() async {
    if (_currentLocation == null || _destinationCenter == null) return;
    
    if (_turnByTurnSteps.isNotEmpty && _currentStepIndex < _turnByTurnSteps.length) {
      final nextStepLocation = _turnByTurnSteps[_currentStepIndex].location;
      final distanceToNextStep = _calculateDistance(_currentLocation!, nextStepLocation);
      
      if (distanceToNextStep > 0.1) {
        setState(() {
          _isCalculatingRoute = true;
        });
        await _calculateTurnByTurnRoute(_currentLocation!, _destinationCenter!.latLng);
        if (mounted) {
          setState(() {
            _isCalculatingRoute = false;
          });
        }
      }
    }
  }
  
  Future<void> _calculateTurnByTurnRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/walking/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true'
    );
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          setState(() {
            _currentRoute = coordinates.map<LatLng>((coord) {
              final lng = (coord[0] is int) ? (coord[0] as int).toDouble() : coord[0] as double;
              final lat = (coord[1] is int) ? (coord[1] as int).toDouble() : coord[1] as double;
              return LatLng(lat, lng);
            }).toList();
            
            _totalDistance = (route['distance'] is int) 
                ? (route['distance'] as int).toDouble() / 1000 
                : route['distance'] / 1000;
            _totalDuration = (route['duration'] is int) 
                ? (route['duration'] as int).toDouble() / 60 
                : route['duration'] / 60;
            
            _turnByTurnSteps = [];
            final legs = route['legs'];
            if (legs != null && legs.isNotEmpty) {
              for (var leg in legs) {
                final steps = leg['steps'];
                for (var step in steps) {
                  final maneuver = step['maneuver'];
                  final location = maneuver['location'];
                  final instruction = _getTurnInstruction(maneuver);
                  
                  _turnByTurnSteps.add(TurnByTurnStep(
                    instruction: instruction,
                    streetName: step['name'] ?? '',
                    distance: (step['distance'] is int) 
                        ? (step['distance'] as int).toDouble() / 1000 
                        : step['distance'] / 1000,
                    duration: (step['duration'] is int) 
                        ? (step['duration'] as int).toDouble() / 60 
                        : step['duration'] / 60,
                    maneuverType: maneuver['type'] ?? 'continue',
                    modifier: maneuver['modifier'] ?? '',
                    location: LatLng(location[1], location[0]),
                  ));
                }
              }
            }
            _currentStepIndex = 0;
          });
          
          await _checkRouteForHazards();
        }
      } else {
        _showErrorDialog('Failed to calculate route');
        _stopNavigation();
      }
    } catch (e) {
      print('Error calculating route: $e');
      _showErrorDialog('Error calculating route');
      _stopNavigation();
    }
  }
  
  String _getTurnInstruction(Map maneuver) {
    final type = maneuver['type'] ?? '';
    final modifier = maneuver['modifier'] ?? '';
    final name = maneuver['name'] ?? '';
    
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left': return 'Turn left${name.isNotEmpty ? ' onto $name' : ''}';
          case 'right': return 'Turn right${name.isNotEmpty ? ' onto $name' : ''}';
          case 'slight left': return 'Turn slight left${name.isNotEmpty ? ' onto $name' : ''}';
          case 'slight right': return 'Turn slight right${name.isNotEmpty ? ' onto $name' : ''}';
          default: return 'Turn${name.isNotEmpty ? ' onto $name' : ''}';
        }
      case 'new name':
        return 'Continue onto $name';
      case 'depart':
        return 'Start walking to evacuation center';
      case 'arrive':
        return 'You have arrived';
      default:
        return 'Continue${name.isNotEmpty ? ' on $name' : ''}';
    }
  }
  
  Future<void> _checkRouteForHazards() async {
    if (_hazardZones.isEmpty) return;
    
    bool hasHazard = false;
    for (var point in _currentRoute) {
      for (var hazard in _hazardZones) {
        if (_calculateDistance(point, hazard.center) < hazard.radius) {
          hasHazard = true;
          break;
        }
      }
    }
    
    if (hasHazard && mounted) {
      setState(() {
        _hasHazardsOnRoute = true;
        _rerouteMessage = '⚠️ HAZARD AHEAD: ${_hazardZones.first.type.toUpperCase()} zone detected on route';
      });
    } else {
      setState(() {
        _hasHazardsOnRoute = false;
        _rerouteMessage = null;
      });
    }
  }
  
  void _fitRouteToMap() {
    if (_currentRoute.isEmpty) return;
    
    double minLat = _currentRoute[0].latitude;
    double maxLat = _currentRoute[0].latitude;
    double minLon = _currentRoute[0].longitude;
    double maxLon = _currentRoute[0].longitude;
    
    for (var point in _currentRoute) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }
    
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    _mapController.move(center, 13);
  }
  
  void _stopNavigation() {
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _currentRoute = [];
        _turnByTurnSteps = [];
        _destinationCenter = null;
        _currentStepIndex = 0;
        _totalDistance = 0;
        _totalDuration = 0;
        _rerouteMessage = null;
        _hasHazardsOnRoute = false;
      });
    }
  }
  
  void _nextStep() {
    if (!mounted) return;
    
    if (_currentStepIndex < _turnByTurnSteps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      
      if (_turnByTurnSteps[_currentStepIndex].location != null) {
        _mapController.move(_turnByTurnSteps[_currentStepIndex].location, 16);
      }
    } else {
      _showArrivalDialog();
    }
  }
  
  void _previousStep() {
    if (!mounted) return;
    
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      
      if (_turnByTurnSteps[_currentStepIndex].location != null) {
        _mapController.move(_turnByTurnSteps[_currentStepIndex].location, 16);
      }
    }
  }
  
  void _showArrivalDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Arrived Safely!'),
          ],
        ),
        content: Text('You have arrived at ${_destinationCenter?.name}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopNavigation();
            },
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

  List<EvacuationCenter> get _availableCenters => 
      _evacuationCenters.where((c) => c.status == 'available').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
              
              if (_currentRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentRoute,
                      color: _hasHazardsOnRoute ? Colors.orange : Colors.green,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              
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
                          child: Icon(Icons.my_location, color: Colors.blue, size: 16),
                        ),
                      ),
                    ),
                  
                  if (_destinationCenter != null)
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
                  
                  if (!_isNavigating)
                    ..._evacuationCenters.map((center) {
                      return Marker(
                        width: 30,
                        height: 30,
                        point: center.latLng,
                        child: GestureDetector(
                          onTap: () {
                            _mapController.move(center.latLng, 15);
                            _showCenterDetails(center);
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: _getStatusColor(center.status),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 12),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
          
          if (_rerouteMessage != null && _isNavigating)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _rerouteMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_isLoadingLocation || _isLoadingCenters)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(_isLoadingLocation ? 'Getting your location...' : 'Loading evacuation centers...'),
                  ],
                ),
              ),
            ),
          
          if (_isCalculatingRoute)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Calculating turn-by-turn route...'),
                  ],
                ),
              ),
            ),
          
          Positioned(
            top: 60,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.blue, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.blue, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _centerOnCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ],
            ),
          ),
          
          if (_isNavigating && _turnByTurnSteps.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: (_currentStepIndex + 1) / _turnByTurnSteps.length,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _hasHazardsOnRoute ? Colors.orange : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Step ${_currentStepIndex + 1} of ${_turnByTurnSteps.length}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _hasHazardsOnRoute ? Colors.orange.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: _hasHazardsOnRoute ? Colors.orange : Colors.green,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _turnByTurnSteps[_currentStepIndex].instruction,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_turnByTurnSteps[_currentStepIndex].distance.toStringAsFixed(1)} km • ${_turnByTurnSteps[_currentStepIndex].duration.toStringAsFixed(0)} mins',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _previousStep,
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('Previous'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _nextStep,
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: Text(
                                  _currentStepIndex == _turnByTurnSteps.length - 1 ? 'Arrive' : 'Next',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasHazardsOnRoute ? Colors.orange : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.straighten, size: 20, color: Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(
                                  '${_totalDistance.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Distance', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                            Container(height: 30, width: 1, color: Colors.grey.shade300),
                            Column(
                              children: [
                                Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(
                                  '${_totalDuration.toStringAsFixed(0)} min',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Est. Time', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                            Container(height: 30, width: 1, color: Colors.grey.shade300),
                            Column(
                              children: [
                                Icon(Icons.flag, size: 20, color: Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(
                                  '${_turnByTurnSteps.length}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Steps', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          
          if (!_isNavigating)
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.location_city, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Evacuation Centers',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (!_isLoadingCenters)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_evacuationCenters.length} Centers',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_isLoadingCenters)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_evacuationCenters.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No evacuation centers found'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _evacuationCenters.length,
                            itemBuilder: (context, index) {
                              final center = _evacuationCenters[index];
                              return _buildCenterCard(center);
                            },
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
  
  Widget _buildCenterCard(EvacuationCenter center) {
    final statusColor = _getStatusColor(center.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(_getStatusIcon(center.status), color: Colors.white, size: 20),
        ),
        title: Text(center.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${center.address}\n${center.currentOccupancy}/${center.capacity} people • ${center.distance}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.emergency, color: Colors.red),
              onPressed: () => _startEvacuation(center),
            ),
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.blue),
              onPressed: () => _makeCall(center.contact),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCenterDetails(EvacuationCenter center) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(center.status),
                  child: Icon(_getStatusIcon(center.status), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(center.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(center.status, style: TextStyle(color: _getStatusColor(center.status))),
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
            _buildDetailRow(Icons.people, '${center.currentOccupancy} / ${center.capacity} people'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time, center.operatingHours),
            const SizedBox(height: 16),
            const Text('Facilities:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: center.facilities.map((f) => Chip(label: Text(f))).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startEvacuation(center);
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Start Evacuation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
          ],
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
}