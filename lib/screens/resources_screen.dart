import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/resources.dart' as resources;
import 'community_board_screen.dart';
import 'my_requests_screen.dart';
import 'my_pledges_screen.dart';

class MyRequest {
  final String id;
  final String resourceId;
  final String resourceName;
  final int quantity;
  final bool urgent;
  final String notes;
  final String status;
  final String date;
  final String type;
  final String? requestType;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? donorName;
  final String? donorPhone;
  final String? donorEmail;
  final String? pickupAddress;

  MyRequest({
    required this.id,
    required this.resourceId,
    required this.resourceName,
    required this.quantity,
    required this.urgent,
    required this.notes,
    required this.status,
    required this.date,
    required this.type,
    this.requestType,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.donorName,
    this.donorPhone,
    this.donorEmail,
    this.pickupAddress,
  });

  factory MyRequest.fromJson(Map<String, dynamic> json) {
    return MyRequest(
      id: json['_id']?.toString() ?? '',
      resourceId: json['resourceId'] ?? '',
      resourceName: json['resourceName'] ?? '',
      quantity: json['quantity'] ?? 0,
      urgent: json['urgent'] ?? false,
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'pending',
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      requestType: json['requestType'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationAddress: json['locationAddress'],
      donorName: json['donorName'],
      donorPhone: json['donorPhone'],
      donorEmail: json['donorEmail'],
      pickupAddress: json['pickupAddress'],
    );
  }
}

class ResourcesScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final ValueChanged<String>? onTabSelected;
  final String? userId;

  const ResourcesScreen(
      {super.key, this.onBackPressed, this.onTabSelected, this.userId});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String? _selectedCategory;
  bool _showModal = false;

  // Request-specific fields
  Position? _currentPosition;
  bool _isGettingLocation = false;
  String _requestQuantity = '1';
  String _requestDescription = '';

  // Location fields (resolved from GPS, shown for verification)
  String _detailedAddress = '';
  String _street = '';
  String _barangay = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';

  String? _userAddress;
  String? _userBarangay;

  // Request categories shown to the resident (label → ResourceRequest enum value).
  static const List<_RequestCategory> _categories = [
    _RequestCategory('Food', 'food', Icons.restaurant),
    _RequestCategory('Water', 'water', Icons.water_drop),
    _RequestCategory('Clothes', 'clothing', Icons.checkroom),
    _RequestCategory('Medicine', 'medicine', Icons.medical_services),
    _RequestCategory('Others', 'other', Icons.category),
  ];

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final userData = await _authService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _userAddress = userData['address'] as String?;
        _userBarangay = userData['barangay'] as String?;
      });
    }
  }

  // ============ LOCATION METHODS ============

  Future<void> _getCurrentLocation() async {
    final bool locationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      _showEnableLocationDialog();
      return;
    }

    if (mounted) setState(() => _isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Location request timeout');
        },
      );

      debugPrint(
          '📍 RAW LOCATION: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;
      });

      await _getAddressFromNominatim(position.latitude, position.longitude);
    } catch (err) {
      debugPrint('Geolocation Error: ${err.toString()}');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _getAddressFromNominatim(
      double latitude, double longitude) async {
    try {
      debugPrint('📍 Fetching address from Nominatim API...');

      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'EmergencyReportApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        if (address != null) {
          setState(() {
            final List<String> addressParts = [];

            // Street/Road
            if (address['road'] != null &&
                address['road'].toString().isNotEmpty) {
              String houseNumber = address['house_number'] ?? '';
              if (houseNumber.isNotEmpty) {
                _street = '$houseNumber ${address['road']}';
              } else {
                _street = address['road'];
              }
              addressParts.add(_street);
            }

            // Barangay/Village
            if (address['village'] != null &&
                address['village'].toString().isNotEmpty) {
              _barangay = address['village'];
              addressParts.add(_barangay);
            } else if (address['neighbourhood'] != null) {
              _barangay = address['neighbourhood'];
              addressParts.add(_barangay);
            } else if (address['suburb'] != null) {
              _barangay = address['suburb'];
              addressParts.add(_barangay);
            }

            // City/Municipality
            if (address['city'] != null &&
                address['city'].toString().isNotEmpty) {
              _city = address['city'];
              addressParts.add(_city);
            } else if (address['town'] != null) {
              _city = address['town'];
              addressParts.add(_city);
            } else if (address['municipality'] != null) {
              _city = address['municipality'];
              addressParts.add(_city);
            }

            // Province
            if (address['state'] != null &&
                address['state'].toString().isNotEmpty) {
              _province = address['state'];
              addressParts.add(_province);
            } else if (address['province'] != null) {
              _province = address['province'];
              addressParts.add(_province);
            }

            // Postal code
            if (address['postcode'] != null &&
                address['postcode'].toString().isNotEmpty) {
              _postalCode = address['postcode'];
              addressParts.add(_postalCode);
            }

            if (addressParts.isNotEmpty) {
              _detailedAddress = addressParts.join(', ');
            } else {
              _detailedAddress = data['display_name'] ?? 'Address not found';
            }

            debugPrint('✅ ADDRESS: $_detailedAddress');
          });
          return;
        }
      }

      await _getAddressFromGeocoding(latitude, longitude);
    } catch (e) {
      debugPrint('Nominatim API error: $e');
      await _getAddressFromGeocoding(latitude, longitude);
    }
  }

  Future<void> _getAddressFromGeocoding(
      double latitude, double longitude) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
        localeIdentifier: 'en_PH',
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];

        setState(() {
          final List<String> addressParts = [];

          if (place.street != null && place.street!.isNotEmpty) {
            _street = place.street!;
            addressParts.add(_street);
          }

          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            _barangay = place.subLocality!;
            addressParts.add(_barangay);
          }

          if (place.locality != null && place.locality!.isNotEmpty) {
            _city = place.locality!;
            addressParts.add(_city);
          }

          if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            _province = place.administrativeArea!;
            addressParts.add(_province);
          }

          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            _postalCode = place.postalCode!;
            addressParts.add(_postalCode);
          }

          if (addressParts.isNotEmpty) {
            _detailedAddress = addressParts.join(', ');
          } else {
            _detailedAddress = '${place.name ?? "Location"}';
          }
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      setState(() {
        _detailedAddress = 'Unable to get address';
      });
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text(
            'Please enable GPS/location services so neighbors know where to bring help.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmitRequest() async {
    if (_selectedCategory == null) return;

    final qty = int.tryParse(_requestQuantity) ?? 1;

    if (_requestDescription.trim().isEmpty) {
      _showAlert('Description Required',
          'Please describe what you need (e.g. canned goods, t-shirts).');
      return;
    }

    if (qty < 1) {
      _showAlert('Error', 'Quantity must be at least 1');
      return;
    }

    if (_currentPosition == null) {
      _showAlert(
        'Location Required',
        'We need your current location so neighbors know where to bring help.',
        onOk: () => _getCurrentLocation(),
      );
      return;
    }

    // Build the best available address string for the required `address` field.
    // Priority: GPS-resolved detailed address → user profile address.
    final String resolvedAddress = (_detailedAddress.isNotEmpty &&
            _detailedAddress != 'Getting address...' &&
            _detailedAddress != 'Unable to get address' &&
            _detailedAddress != 'Please enter your location manually')
        ? _detailedAddress
        : (_userAddress ?? '');

    // Use the resident's profile barangay so the request shows up on the Open
    // Needs board (which filters by barangay); fall back to the geocoded
    // barangay, then city, then the full address — anything but empty, so the
    // request never ends up labelled "unknown".
    String barangay = (_userBarangay != null && _userBarangay!.isNotEmpty)
        ? _userBarangay!
        : _barangay;
    if (barangay.trim().isEmpty) barangay = _city;
    if (barangay.trim().isEmpty) barangay = resolvedAddress;

    final requestData = {
      'itemDescription': _requestDescription.trim(),
      'category': _selectedCategory,
      'unit': 'pcs',
      'quantity': qty,
      'address': resolvedAddress,
      'barangay': barangay,
      'reason': '',
      'gpsLat': _currentPosition?.latitude,
      'gpsLng': _currentPosition?.longitude,
    };

    try {
      final response = await _apiService.authenticatedPost(
          '/api/community/requests', requestData);
      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        final message = '✅ Request posted to People in Need\n\n'
            'Item: ${_requestDescription.trim()}\n'
            'Quantity: $qty pcs\n\n'
            'Neighbors in your barangay can now offer to help. '
            'You\'ll be notified when someone responds.';

        _showAlert(
          'Request Submitted',
          message,
          onOk: () {
            setState(() {
              _showModal = false;
              _requestQuantity = '1';
              _requestDescription = '';
              _currentPosition = null;
              _selectedCategory = null;
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            );
          },
        );
      } else {
        final body = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        _showAlert('Error',
            'Failed to submit request (${response.statusCode}): $body');
      }
    } catch (e) {
      _showAlert('Error', 'Failed to submit request: ${e.toString()}');
    }
  }

  void _handleCategorySelect(String categoryValue) {
    setState(() {
      _selectedCategory = categoryValue;
      _requestDescription = '';
      _requestQuantity = '1';
      _showModal = true;
    });
  }

  Widget _buildRequestForm() {
    final category = _categories.firstWhere(
      (c) => c.value == _selectedCategory,
      orElse: () => _categories.last,
    );
    final Color catColor = _getCategoryColor(category.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected category (read-only header)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: catColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(category.icon, color: catColor, size: 22),
              const SizedBox(width: 10),
              Text(
                category.label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: catColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('What do you need?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: category.value == 'food'
                ? 'e.g. canned goods, rice'
                : category.value == 'clothing'
                    ? 'e.g. t-shirts, blankets'
                    : 'Describe what you need',
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _requestDescription = value,
        ),
        const SizedBox(height: 20),

        const Text('Quantity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                int qty = int.tryParse(_requestQuantity) ?? 1;
                if (qty > 1) {
                  setState(() => _requestQuantity = (qty - 1).toString());
                }
              },
              icon: const Icon(Icons.remove_circle),
            ),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                controller: TextEditingController(text: _requestQuantity),
                onChanged: (value) {
                  int qty = int.tryParse(value) ?? 1;
                  if (qty >= 1) {
                    _requestQuantity = qty.toString();
                  }
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
            IconButton(
              onPressed: () {
                int qty = int.tryParse(_requestQuantity) ?? 1;
                setState(() => _requestQuantity = (qty + 1).toString());
              },
              icon: const Icon(Icons.add_circle),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Location (always shown so the resident can verify the address)
        const Text('Your location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Neighbors use this to find you. Make sure it looks correct.',
          style: TextStyle(fontSize: 12, color: ET_GRAY),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: ET_RED),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _detailedAddress.isNotEmpty
                          ? _detailedAddress
                          : (_isGettingLocation
                              ? 'Getting your location…'
                              : 'No location captured yet'),
                      style: const TextStyle(color: Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_currentPosition == null
                      ? 'Share My Location'
                      : 'Refresh Location'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // REQUEST BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleSubmitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: ET_RED,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'SUBMIT REQUEST',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'water':
        return const Color(0xFF06B6D4);
      case 'food':
        return const Color(0xFFF59E0B);
      case 'clothing':
      case 'clothes':
        return const Color(0xFF10B981);
      case 'medicine':
      case 'medical':
        return const Color(0xFFDC2626);
      case 'hygiene':
        return const Color(0xFF7C3AED);
      case 'shelter':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF666666);
    }
  }

  String _getCategoryName(String category) {
    return category;
  }

  void _showCategoryPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'What do you need help with?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _categories.map((cat) {
                  final color = _getCategoryColor(cat.value);
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleCategorySelect(cat.value);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(cat.icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              cat.label,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right, color: ET_GRAY),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _showModal
          ? null
          : SizedBox(
              height: 40,
              child: FloatingActionButton.extended(
                onPressed: _showCategoryPickerSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Request Resources',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
                extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: ET_RED,
                foregroundColor: Colors.white,
                elevation: 2,
              ),
            ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildCommunityHub(),
          ),
          if (_showModal)
            GestureDetector(
              onTap: () => setState(() => _showModal = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_showModal)
            Positioned.fill(
              child: resources.ResourceModal(
                resource: null,
                activeTab: 'request',
                quantity: _requestQuantity,
                urgent: false,
                notes: _requestDescription,
                getCategoryColor: _getCategoryColor,
                getCategoryName: _getCategoryName,
                onClose: () => setState(() => _showModal = false),
                onQuantityChanged: (qty) =>
                    setState(() => _requestQuantity = qty),
                onUrgentChanged: (_) {},
                onNotesChanged: (text) => _requestDescription = text,
                onSubmit: _handleSubmitRequest,
                onContactSupport: () {},
                customContent: _buildRequestForm(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ET_RED.withOpacity(0.08), ET_RED.withOpacity(0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ET_RED.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt, color: ET_RED, size: 20),
                  SizedBox(width: 8),
                  Text('Community Resource Sharing',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ET_RED)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse what your community needs, offer to help, and coordinate deliveries directly with your neighbors.',
                style: TextStyle(fontSize: 12, color: ET_GRAY),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _communityNavCard(
          icon: Icons.people_alt,
          color: ET_RED,
          title: 'People in Need',
          subtitle:
              'See open resource requests from your barangay and offer to help',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunityBoardScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _communityNavCard(
          icon: Icons.inventory_2,
          color: ET_RED,
          title: 'My Requests',
          subtitle:
              'Track your posted requests and review offers from neighbors',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _communityNavCard(
          icon: Icons.handshake,
          color: ET_RED,
          title: 'My Pledges',
          subtitle: 'See requests you\'ve offered to help with',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyPledgesScreen()),
          ),
        ),
      ],
    );
  }

  Widget _communityNavCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: ET_GRAY)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ET_GRAY),
            ],
          ),
        ),
      ),
    );
  }
}

/// A request category shown in the picker. [value] is the ResourceRequest
/// backend enum value (food/water/clothing/medicine/other).
class _RequestCategory {
  final String label;
  final String value;
  final IconData icon;

  const _RequestCategory(this.label, this.value, this.icon);
}
