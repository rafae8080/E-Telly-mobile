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
  String? _selectedResource;
  bool _showModal = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Request-specific fields
  String _requestType = 'standard';
  Position? _currentPosition;
  String? _currentAddress;
  bool _isGettingLocation = false;
  String _requestQuantity = '1';
  bool _requestUrgent = false;
  String _requestNotes = '';
  final TextEditingController _barangayController = TextEditingController();

  // Location fields (used by address resolution for emergency requests)
  String _detailedAddress = '';
  String _street = '';
  String _barangay = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';

  String? _userAddress;

  List<resources.ResourceItem> _inventoryItems = [];

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchInventoryItems();
    _getCurrentLocation();
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final userData = await _authService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _userAddress = userData['address'] as String?;
      });
    }
  }

  Future<void> _fetchInventoryItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/inventory/public'),
      );

      if (response.statusCode == 200) {
        if (response.body.trimLeft().startsWith('<')) {
          setState(() {
            _errorMessage =
                'Inventory service unavailable. Please try again later.';
            _isLoading = false;
          });
          return;
        }
        final body = jsonDecode(response.body);
        final List<dynamic> items = _extractList(body);
        setState(() {
          _inventoryItems = items.map((item) {
            return resources.ResourceItem(
              id: item['_id']?.toString() ?? '',
              name: item['name'] ?? '',
              category: item['category'] ?? 'Other',
              description: item['description'],
              icon: _getIconFromName(item['name'] ?? ''),
              available: (item['quantity'] ?? 0) > 0,
              estimatedDelivery: 'Within 1-2 hours',
              unit: item['unit'] ?? 'pcs',
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load items (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load items: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Maps any inventory category string to a valid ResourceRequest enum value:
  /// ["food","water","clothing","medicine","hygiene","shelter","other"]
  String _normalizeCategory(String category) {
    switch (category.toLowerCase().trim()) {
      case 'food':
      case 'foods':
      case 'nutrition':
        return 'food';
      case 'water':
      case 'drinks':
      case 'beverage':
        return 'water';
      case 'clothing':
      case 'clothes':
      case 'apparel':
      case 'garments':
        return 'clothing';
      case 'medicine':
      case 'medical':
      case 'medication':
      case 'medicines':
      case 'health':
      case 'healthcare':
        return 'medicine';
      case 'hygiene':
      case 'sanitation':
      case 'personal care':
        return 'hygiene';
      case 'shelter':
      case 'housing':
      case 'relief goods':
        return 'shelter';
      default:
        return 'other';
    }
  }

  IconData _getIconFromName(String name) {
    switch (name.toLowerCase()) {
      case 'megaphone':
        return Icons.volume_up;
      case 'flashlights':
        return Icons.flashlight_on;
      case 'aa batteries':
        return Icons.battery_alert;
      case 'generator fuel (diesel)':
        return Icons.local_gas_station;
      default:
        return Icons.inventory;
    }
  }

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      for (final key in ['data', 'requests', 'donations', 'items', 'results']) {
        if (body[key] is List) return body[key] as List;
      }
    }
    return [];
  }

  // ============ LOCATION METHODS ============

  Future<void> _getCurrentLocation() async {
    final bool locationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      _showEnableLocationDialog();
      return;
    }

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
          _barangayController.text = _barangay;
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
        _barangayController.text = _barangay;
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
        content:
            const Text('Please enable GPS/location services for emergency requests.'),
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
    if (_selectedResource == null) return;

    final resource = _inventoryItems.firstWhere(
      (r) => r.id == _selectedResource,
    );

    final qty = int.tryParse(_requestQuantity) ?? 1;

    if (qty < 1) {
      _showAlert('Error', 'Quantity must be at least 1');
      return;
    }

    if (_requestType == 'emergency' && _currentPosition == null) {
      _showAlert(
        'Location Required',
        'For emergency requests, we need your current location.',
        onOk: () => _getCurrentLocation(),
      );
      return;
    }

    // Build the best available address string for the required `address` field.
    // Priority: GPS-resolved detailed address → user profile address → barangay name.
    final String resolvedAddress = (_detailedAddress.isNotEmpty &&
            _detailedAddress != 'Getting address...' &&
            _detailedAddress != 'Unable to get address' &&
            _detailedAddress != 'Please enter your location manually')
        ? _detailedAddress
        : (_userAddress != null && _userAddress!.isNotEmpty)
            ? _userAddress!
            : _barangay;

    final requestData = {
      'resourceId': _selectedResource,
      'resourceName': resource.name,
      'itemDescription': resource.name,
      'category': _normalizeCategory(resource.category),
      'unit': resource.unit ?? 'pcs',
      'quantity': qty,
      'address': resolvedAddress,
      'barangay': _barangay,
      'requestType': _requestType,
      'reason': _requestNotes.trim(),
      'gpsLat': _currentPosition?.latitude,
      'gpsLng': _currentPosition?.longitude,
    };

    try {
      final response = await _apiService.authenticatedPost(
          '/api/community/requests', requestData);
      if (response.statusCode == 409) {
        _showAlert('Already Requested',
            'You already have an active request in this category.');
        return;
      }
      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        await _fetchInventoryItems();

        String message = _requestType == 'standard'
            ? '✅ STANDARD REQUEST SUBMITTED\n\n'
                'Item: ${resource.name}\n'
                'Quantity: $qty ${resource.unit}\n\n'
                '📍 Pick up at: DSWD Office\n'
                'Navotas City Hall Compound\n\n'
                'Please bring a valid ID for verification.'
            : '🚨 EMERGENCY REQUEST SENT 🚨\n\n'
                'Item: ${resource.name}\n'
                'Quantity: $qty ${resource.unit}\n\n'
                '📍 Location sent to DSWD\n\n'
                'Emergency responders have been notified!\n'
                'Help is on the way!';

        _showAlert(
          _requestType == 'emergency'
              ? 'EMERGENCY REQUEST'
              : 'Request Submitted',
          message,
          onOk: () {
            setState(() {
              _showModal = false;
              _requestQuantity = '1';
              _requestUrgent = false;
              _requestNotes = '';
              _requestType = 'standard';
              _currentPosition = null;
              _selectedResource = null;
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

  void _handleRequestSelect(String resourceId) {
    setState(() {
      _selectedResource = resourceId;
      _requestType = 'standard';
      _currentPosition = null;
      _showModal = true;
    });
  }

  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                color: _requestType == 'standard' ? Colors.blue.shade50 : null,
                child: InkWell(
                  onTap: () => setState(() => _requestType = 'standard'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.person_pin_circle,
                            size: 40, color: Colors.blue.shade700),
                        const SizedBox(height: 8),
                        const Text('Standard',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Pick up at DSWD Office',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                color: _requestType == 'emergency' ? Colors.red.shade50 : null,
                child: InkWell(
                  onTap: () => setState(() => _requestType = 'emergency'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.emergency,
                            size: 40, color: Colors.red.shade700),
                        const SizedBox(height: 8),
                        const Text('Emergency',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Send location to DSWD',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

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
                    setState(() => _requestQuantity = qty.toString());
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
        const SizedBox(height: 12),

        TextField(
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _requestNotes = value,
        ),
        const SizedBox(height: 12),

        const Text('Barangay',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _barangayController,
          decoration: const InputDecoration(
            hintText: 'e.g. Bagong Nayon',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
          ),
        ),

        if (_requestType == 'emergency') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentAddress != null
                            ? _currentAddress!
                            : (_detailedAddress.isNotEmpty
                                ? _detailedAddress
                                : 'No location captured'),
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: Text(_currentPosition == null
                        ? 'Share My Location'
                        : 'Update Location'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // REQUEST BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleSubmitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: _requestType == 'emergency'
                  ? Colors.red.shade700
                  : Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _requestType == 'emergency'
                  ? 'SUBMIT EMERGENCY REQUEST'
                  : 'SUBMIT REQUEST',
              style: const TextStyle(
                fontSize: 16,
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
      case 'clothes':
        return const Color(0xFF10B981);
      case 'medical':
        return const Color(0xFFDC2626);
      case 'communication':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF666666);
    }
  }

  String _getCategoryName(String category) {
    return category;
  }

  @override
  void dispose() {
    _barangayController.dispose();
    super.dispose();
  }

  void _showItemPickerSheet() {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading resources, please wait...')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Select a Resource',
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
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: resources.RequestContent(
                  items: _inventoryItems,
                  getCategoryColor: _getCategoryColor,
                  onItemSelect: (id) {
                    Navigator.pop(ctx);
                    _handleRequestSelect(id);
                  },
                ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showItemPickerSheet,
        icon: const Icon(Icons.add),
        label: const Text('Request Resources'),
        backgroundColor: ET_BLUE,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchInventoryItems,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
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
                urgent: _requestUrgent,
                notes: _requestNotes,
                getCategoryColor: _getCategoryColor,
                getCategoryName: _getCategoryName,
                onClose: () => setState(() => _showModal = false),
                onQuantityChanged: (qty) => setState(() => _requestQuantity = qty),
                onUrgentChanged: (value) => setState(() => _requestUrgent = value),
                onNotesChanged: (text) => setState(() => _requestNotes = text),
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
              colors: [ET_BLUE.withOpacity(0.08), ET_PURPLE.withOpacity(0.06)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ET_BLUE.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_alt, color: ET_BLUE, size: 20),
                  SizedBox(width: 8),
                  Text('Community Resource Sharing',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ET_BLUE)),
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
          color: ET_BLUE,
          title: 'People in Need',
          subtitle: 'See open resource requests from your barangay and offer to help',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CommunityBoardScreen()),
          ),
        ),
        const SizedBox(height: 10),
        _communityNavCard(
          icon: Icons.inventory_2,
          color: ET_PURPLE,
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
          color: ET_GREEN,
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
