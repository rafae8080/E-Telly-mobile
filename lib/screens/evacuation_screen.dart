import 'package:flutter/material.dart';
import '../widgets/evacuation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class EvacuationCenter {
  final int id;
  final String name;
  final String address;
  final int capacity;
  final int currentOccupancy;
  final String status; // 'available', 'almost_full', 'full'
  final String contact;
  final String coordinates;
  final String distance;
  final List<String> facilities;
  final String operatingHours;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.currentOccupancy,
    required this.status,
    required this.contact,
    required this.coordinates,
    required this.distance,
    required this.facilities,
    required this.operatingHours,
  });
  
  LatLng get latLng {
    final parts = coordinates.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }
}

class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});

  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  // ANTIPOLO EVACUATION CENTERS
  final List<EvacuationCenter> _evacuationCenters = [
    EvacuationCenter(
      id: 1,
      name: 'Antipolo City Hall Evacuation Center',
      address: 'Antipolo City Hall, Brgy. San Roque, Antipolo, Rizal',
      capacity: 300,
      currentOccupancy: 120,
      status: 'available',
      contact: '8630-1234',
      coordinates: '14.5865,121.1756',
      distance: '0.5 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Power Outlets',
        'Wi-Fi',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 2,
      name: 'Antipolo Sports Complex',
      address: 'Barangay San Jose, Antipolo, Rizal',
      capacity: 800,
      currentOccupancy: 250,
      status: 'available',
      contact: '8630-5678',
      coordinates: '14.5982,121.1645',
      distance: '1.2 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Showers',
        'Play Area',
        'Parking',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 3,
      name: 'Antipolo National High School',
      address: 'M.L. Quezon St, Brgy. San Roque, Antipolo, Rizal',
      capacity: 500,
      currentOccupancy: 180,
      status: 'available',
      contact: '8630-9012',
      coordinates: '14.5812,121.1789',
      distance: '0.8 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Classroom Areas',
        'First Aid',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 4,
      name: 'San Jose Elementary School',
      address: 'Brgy. San Jose, Antipolo, Rizal',
      capacity: 400,
      currentOccupancy: 350,
      status: 'almost_full',
      contact: '8630-3456',
      coordinates: '14.6025,121.1589',
      distance: '1.5 km',
      facilities: [
        'Food & Water',
        'Restrooms',
        'Classroom Areas',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 5,
      name: 'Mambugan Elementary School',
      address: 'Brgy. Mambugan, Antipolo, Rizal',
      capacity: 350,
      currentOccupancy: 400,
      status: 'full',
      contact: '8630-7890',
      coordinates: '14.6058,121.1523',
      distance: '2.0 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 6,
      name: 'Cupang Elementary School',
      address: 'Brgy. Cupang, Antipolo, Rizal',
      capacity: 450,
      currentOccupancy: 200,
      status: 'available',
      contact: '8630-2345',
      coordinates: '14.5721,121.1654',
      distance: '1.8 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Showers',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 7,
      name: 'Dela Paz Elementary School',
      address: 'Brgy. Dela Paz, Antipolo, Rizal',
      capacity: 380,
      currentOccupancy: 380,
      status: 'full',
      contact: '8630-6789',
      coordinates: '14.5698,121.1723',
      distance: '2.2 km',
      facilities: [
        'Food & Water',
        'Restrooms',
        'Classroom Areas',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 8,
      name: 'Mayamot Elementary School',
      address: 'Brgy. Mayamot, Antipolo, Rizal',
      capacity: 420,
      currentOccupancy: 150,
      status: 'available',
      contact: '8630-4567',
      coordinates: '14.6154,121.1589',
      distance: '2.5 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Play Area',
      ],
      operatingHours: '24/7',
    ),
  ];

  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  double _currentZoom = 13;
  
  // Center of Antipolo City (fallback)
  final LatLng _antipoloCenter = const LatLng(14.5865, 121.1756);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled. Please enable GPS.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied. Please enable in settings.';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
        // Center map on current location
        _mapController.move(_currentLocation!, _currentZoom);
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _isLoadingLocation = false;
      });
    }
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);
    double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(point1.latitude)) * cos(_toRadians(point2.latitude)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (pi / 180);

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _currentZoom);
      setState(() {
        _selectedLocation = _currentLocation;
      });
    } else {
      _getCurrentLocation();
    }
  }
  
  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(1, 18);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }
  
  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(1, 18);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

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

  Future<void> _openDirections(String coordinates) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$coordinates&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Unable to open directions'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openContact(String contact) async {
    final cleanNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Unable to make call'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<EvacuationCenter> get _availableCenters => _evacuationCenters
      .where((center) => center.status == 'available')
      .toList();

  List<EvacuationCenter> get _almostFullCenters => _evacuationCenters
      .where((center) => center.status == 'almost_full')
      .toList();

  List<EvacuationCenter> get _fullCenters =>
      _evacuationCenters.where((center) => center.status == 'full').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              StatusSummary(
                availableCount: _availableCenters.length,
                almostFullCount: _almostFullCenters.length,
                fullCount: _fullCenters.length,
              ),
              const SizedBox(height: 16),
              const InstructionsBanner(),
              const SizedBox(height: 16),
              
              // MAP SECTION - Antipolo Map with Current Location
              Stack(
                children: [
                  Container(
                    height: 300,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation ?? _antipoloCenter,
                          initialZoom: _currentZoom,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedLocation = null;
                            });
                          },
                          onPositionChanged: (position, hasGesture) {
                            if (hasGesture) {
                              setState(() {
                                _currentZoom = position.zoom;
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.e_telly.app',
                            tileProvider:  NetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              // Current Location Marker
                              if (_currentLocation != null)
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _currentLocation!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.withOpacity(0.3),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.my_location,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              // Evacuation Center Markers
                              ..._evacuationCenters.map((center) {
                                return Marker(
                                  width: 40,
                                  height: 40,
                                  point: center.latLng,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedLocation = center.latLng;
                                      });
                                      _mapController.move(center.latLng, 15);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _selectedLocation == center.latLng ? Colors.blue : Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _getStatusColor(center.status),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                          // Required OSM Attribution
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                prependCopyright: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Zoom Controls - Top Right
                  Positioned(
                    top: 10,
                    right: 30,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          mini: true,
                          onPressed: _zoomIn,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.add, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${_currentZoom.toInt()}x',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          mini: true,
                          onPressed: _zoomOut,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.remove, color: Colors.blue, size: 20),
                        ),
                      ],
                    ),
                  ),
                  
                  // Location Button - Bottom Right
                  Positioned(
                    bottom: 10,
                    right: 30,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _centerOnCurrentLocation,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
              
              // Loading/Error Indicator
              if (_isLoadingLocation)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Getting your location...',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
              
              if (_locationError != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: _getCurrentLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              
              // Map Legend
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(const Color(0xFF10B981), 'Available'),
                    _buildLegendItem(const Color(0xFFF59E0B), 'Almost Full'),
                    _buildLegendItem(const Color(0xFFDC2626), 'Full'),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('You', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _evacuationCenters.length,
                itemBuilder: (context, index) {
                  final center = _evacuationCenters[index];
                  return EvacuationCenterCard(
                    center: center,
                    statusColor: _getStatusColor(center.status),
                    statusText: _getStatusText(center.status),
                    statusIcon: _getStatusIcon(center.status),
                    onDirections: () => _openDirections(center.coordinates),
                    onCall: () => _openContact(center.contact),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}