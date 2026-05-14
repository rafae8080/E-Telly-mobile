import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:e_telly_app/dbhelper/mongodb.dart';
import '../widgets/resources.dart' as resources;

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

  const ResourcesScreen({super.key, this.onBackPressed, this.onTabSelected, this.userId});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String _activeTab = 'donate';
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

  // Donation-specific fields - Location
  bool _isLoadingLocation = false;
  String? _locationError;
  String _exactAddress = '';
  String _detailedAddress = '';
  String _street = '';
  String _barangay = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';
  
  // Donation-specific fields - Donor Info
  bool _isAnonymous = false;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleInitialController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  DateTime? _selectedDateOfBirth;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _donationQuantity = '1';
  String _donationNotes = '';

  List<resources.ResourceItem> _inventoryItems = [];
  List<MyRequest> _myRequests = [];
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchInventoryItems();
    _fetchMyRequests();
    _getCurrentLocation();
  }

  Future<void> _fetchInventoryItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await MongoDatabase.connect();
      
      final items = await MongoDatabase.getInventoryItems();
      
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
      
      print('Loaded ${_inventoryItems.length} inventory items');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load items: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching inventory: $e');
    }
  }

  IconData _getIconFromName(String name) {
    switch (name.toLowerCase()) {
      case 'megaphone': return Icons.volume_up;
      case 'flashlights': return Icons.flashlight_on;
      case 'aa batteries': return Icons.battery_alert;
      case 'generator fuel (diesel)': return Icons.local_gas_station;
      default: return Icons.inventory;
    }
  }

  Future<void> _fetchMyRequests() async {
    if (widget.userId == null) return;
    
    try {
      final requestsData = await MongoDatabase.getUserRequests(widget.userId!);
      final donationsData = await MongoDatabase.getUserDonations(widget.userId!);
      
      List<MyRequest> allItems = [];
      
      for (var request in requestsData) {
        allItems.add(MyRequest.fromJson(request));
      }
      
      for (var donation in donationsData) {
        allItems.add(MyRequest.fromJson(donation));
      }
      
      allItems.sort((a, b) => b.date.compareTo(a.date));
      
      setState(() {
        _myRequests = allItems;
      });
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }

  // ============ LOCATION METHODS ============
  
  Future<void> _getCurrentLocation() async {
    final bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled. Please enable GPS.';
        _isLoadingLocation = false;
      });
      _showEnableLocationDialog();
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

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
      
      debugPrint('📍 RAW LOCATION: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _currentPosition = position;
      });
      
      await _getAddressFromNominatim(position.latitude, position.longitude);
      
      setState(() {
        _isLoadingLocation = false;
      });
      
    } catch (err) {
      debugPrint('Geolocation Error: ${err.toString()}');
      setState(() {
        _locationError = 'Unable to get location: ${err.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getAddressFromNominatim(double latitude, double longitude) async {
    try {
      debugPrint('📍 Fetching address from Nominatim API...');
      
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';
      
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
            if (address['road'] != null && address['road'].toString().isNotEmpty) {
              String houseNumber = address['house_number'] ?? '';
              if (houseNumber.isNotEmpty) {
                _street = '$houseNumber ${address['road']}';
              } else {
                _street = address['road'];
              }
              addressParts.add(_street);
            }
            
            // Barangay/Village
            if (address['village'] != null && address['village'].toString().isNotEmpty) {
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
            if (address['city'] != null && address['city'].toString().isNotEmpty) {
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
            if (address['state'] != null && address['state'].toString().isNotEmpty) {
              _province = address['state'];
              addressParts.add(_province);
            } else if (address['province'] != null) {
              _province = address['province'];
              addressParts.add(_province);
            }
            
            // Postal code
            if (address['postcode'] != null && address['postcode'].toString().isNotEmpty) {
              _postalCode = address['postcode'];
              addressParts.add(_postalCode);
            }
            
            if (addressParts.isNotEmpty) {
              _detailedAddress = addressParts.join(', ');
              _exactAddress = _detailedAddress;
            } else {
              _detailedAddress = data['display_name'] ?? 'Address not found';
              _exactAddress = _detailedAddress;
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

  Future<void> _getAddressFromGeocoding(double latitude, double longitude) async {
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
          
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            _province = place.administrativeArea!;
            addressParts.add(_province);
          }
          
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            _postalCode = place.postalCode!;
            addressParts.add(_postalCode);
          }
          
          if (addressParts.isNotEmpty) {
            _detailedAddress = addressParts.join(', ');
            _exactAddress = _detailedAddress;
          } else {
            _detailedAddress = '${place.name ?? "Location"}';
            _exactAddress = _detailedAddress;
          }
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      setState(() {
        _detailedAddress = 'Unable to get address';
        _exactAddress = 'Please enter your location manually';
      });
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text('Please enable GPS/location services to donate items.'),
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

  Widget _buildLocationStatus() {
    if (_isLoadingLocation) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Getting your exact location...'),
          ],
        ),
      );
    } else if (_locationError != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 16, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _locationError!,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_detailedAddress.isNotEmpty && _detailedAddress != 'Getting address...') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pickup Location:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    _detailedAddress,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_barangay.isNotEmpty && _city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$_barangay, $_city',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: _getCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 16, color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleSubmitDonation() async {
    if (_selectedResource == null) return;

    final resource = _inventoryItems.firstWhere(
      (r) => r.id == _selectedResource,
    );

    final qty = int.tryParse(_donationQuantity) ?? 1;

    if (qty < 1) {
      _showAlert('Error', 'Quantity must be at least 1');
      return;
    }

    if (_exactAddress.isEmpty && _detailedAddress.isEmpty) {
      _showAlert('Error', 'Please wait for location or enter manually');
      return;
    }

    // Validate only if not anonymous
    if (!_isAnonymous) {
      if (_firstNameController.text.trim().isEmpty) {
        _showAlert('Error', 'Please enter your first name');
        return;
      }
      if (_lastNameController.text.trim().isEmpty) {
        _showAlert('Error', 'Please enter your last name');
        return;
      }
      if (_selectedDateOfBirth == null) {
        _showAlert('Error', 'Please select your date of birth');
        return;
      }
      if (_emailController.text.trim().isEmpty) {
        _showAlert('Error', 'Please enter your email');
        return;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showAlert('Error', 'Please enter your phone number');
        return;
      }
    }

    final donationData = {
      'userId': widget.userId,
      'resourceId': _selectedResource,
      'resourceName': resource.name,
      'quantity': qty,
      'urgent': false,
      'notes': _donationNotes.trim(),
      'type': 'donation',
      'status': 'pending',
      'date': _formatDateTime(DateTime.now()),
      'isAnonymous': _isAnonymous,
      'location': {
        'exactAddress': _exactAddress,
        'detailedAddress': _detailedAddress,
        'street': _street,
        'barangay': _barangay,
        'city': _city,
        'province': _province,
        'postalCode': _postalCode,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
      },
      'donorName': _isAnonymous ? 'Anonymous Donor' : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      'donorFirstName': _firstNameController.text.trim(),
      'donorMiddleInitial': _middleInitialController.text.trim(),
      'donorLastName': _lastNameController.text.trim(),
      'dateOfBirth': _selectedDateOfBirth?.toIso8601String(),
      'donorEmail': _isAnonymous ? 'anonymous@donation.com' : _emailController.text.trim(),
      'donorPhone': _isAnonymous ? 'N/A' : _phoneController.text.trim(),
      'pickupAddress': _detailedAddress,
    };

    try {
      final success = await MongoDatabase.submitDonation(donationData);
      
      if (success) {
        await _fetchMyRequests();
        
        _showAlert(
          'Donation Submitted!',
          _isAnonymous
              ? 'Thank you for your anonymous donation!\n\n'
                'Item: ${resource.name}\n'
                'Quantity: $qty\n'
                'Pickup Location: $_detailedAddress\n\n'
                'DRRMO will arrange pickup.'
              : 'Thank you for your generous donation of $qty ${resource.name}!\n\n'
                'Donor: ${_firstNameController.text} ${_lastNameController.text}\n'
                'Pickup Location: $_detailedAddress\n\n'
                'DRRMO will contact you for pickup arrangements.',
          onOk: () {
            setState(() {
              _showModal = false;
              _donationQuantity = '1';
              _donationNotes = '';
              _isAnonymous = false;
              _selectedResource = null;
              _firstNameController.clear();
              _middleInitialController.clear();
              _lastNameController.clear();
              _selectedDateOfBirth = null;
              _emailController.clear();
              _phoneController.clear();
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _activeTab = 'myRequests';
              });
            });
          },
        );
      } else {
        _showAlert('Error', 'Failed to submit donation');
      }
    } catch (e) {
      _showAlert('Error', 'Failed to submit donation: ${e.toString()}');
    }
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

    // Check stock availability
    final currentItem = await MongoDatabase.getInventoryItemById(resource.id);
    if (currentItem != null) {
      int currentQty = currentItem['quantity'] ?? 0;
      if (qty > currentQty) {
        _showAlert('Insufficient Stock', 'Only $currentQty ${resource.unit} available.');
        return;
      }
      await MongoDatabase.updateInventoryQuantity(resource.id, currentQty - qty);
    }

    final requestData = {
      'userId': widget.userId,
      'resourceId': _selectedResource,
      'resourceName': resource.name,
      'quantity': qty,
      'urgent': _requestUrgent,
      'notes': _requestNotes.trim(),
      'requestType': _requestType,
      'latitude': _currentPosition?.latitude,
      'longitude': _currentPosition?.longitude,
      'locationAddress': _currentAddress ?? _detailedAddress,
      'type': 'request',
      'status': 'pending',
      'date': _formatDateTime(DateTime.now()),
    };

    try {
      final success = await MongoDatabase.submitRequest(requestData);
      
      if (success) {
        await _fetchInventoryItems();
        await _fetchMyRequests();
        
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
          _requestType == 'emergency' ? 'EMERGENCY REQUEST' : 'Request Submitted',
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
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() {
                _activeTab = 'myRequests';
              });
            });
          },
        );
      } else {
        _showAlert('Error', 'Failed to submit request');
      }
    } catch (e) {
      _showAlert('Error', 'Failed to submit request: ${e.toString()}');
    }
  }

  void _handleDonationSelect(String resourceId) {
    setState(() {
      _selectedResource = resourceId;
      _isAnonymous = false;
      _firstNameController.clear();
      _middleInitialController.clear();
      _lastNameController.clear();
      _selectedDateOfBirth = null;
      _emailController.clear();
      _phoneController.clear();
      _donationQuantity = '1';
      _donationNotes = '';
      _showModal = true;
    });
  }

  void _handleRequestSelect(String resourceId) {
    setState(() {
      _selectedResource = resourceId;
      _requestType = 'standard';
      _currentPosition = null;
      _showModal = true;
    });
  }

  Widget _buildDonationForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Section
          const Text(
            'Pickup Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildLocationStatus(),
          const SizedBox(height: 16),

          // Remain Anonymous Checkbox
          Row(
            children: [
              Checkbox(
                value: _isAnonymous,
                onChanged: (value) => setState(() => _isAnonymous = value ?? false),
              ),
              const Expanded(
                child: Text(
                  'Remain Anonymous',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donor Information (disabled when anonymous)
          const Text(
            'Donor Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _firstNameController,
            enabled: !_isAnonymous,
            decoration: InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _middleInitialController,
            enabled: !_isAnonymous,
            decoration: InputDecoration(
              labelText: 'Middle Initial',
              hintText: 'Enter your middle initial',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _lastNameController,
            enabled: !_isAnonymous,
            decoration: InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Date of Birth
          InkWell(
            onTap: _isAnonymous ? null : () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDateOfBirth = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400,
                ),
                borderRadius: BorderRadius.circular(8),
                color: _isAnonymous ? Colors.grey.shade50 : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _isAnonymous ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDateOfBirth == null
                          ? 'Date of Birth'
                          : 'DOB: ${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.year}',
                      style: TextStyle(
                        color: _isAnonymous 
                            ? Colors.grey.shade400 
                            : (_selectedDateOfBirth == null ? Colors.grey : Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDateOfBirth == null && !_isAnonymous)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                'Date of Birth is required.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
          const SizedBox(height: 12),

          // Email
          TextField(
            controller: _emailController,
            enabled: !_isAnonymous,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'email@example.com',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
            ),
          ),
          if (_emailController.text.isEmpty && !_isAnonymous)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                'Email is required.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
          const SizedBox(height: 12),

          // Phone
          TextField(
            controller: _phoneController,
            enabled: !_isAnonymous,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone',
              hintText: '+639XXXXXXXXX',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _isAnonymous ? Colors.grey.shade300 : Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quantity
          const Text(
            'Quantity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  int qty = int.tryParse(_donationQuantity) ?? 1;
                  if (qty > 1) {
                    setState(() => _donationQuantity = (qty - 1).toString());
                  }
                },
                icon: const Icon(Icons.remove_circle),
              ),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  controller: TextEditingController(text: _donationQuantity),
                  onChanged: (value) {
                    int qty = int.tryParse(value) ?? 1;
                    if (qty >= 1) {
                      setState(() => _donationQuantity = qty.toString());
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  int qty = int.tryParse(_donationQuantity) ?? 1;
                  setState(() => _donationQuantity = (qty + 1).toString());
                },
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any special instructions...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _donationNotes = value,
          ),
          const SizedBox(height: 24),

          // DONATE BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSubmitDonation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'DONATE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                      Icon(Icons.person_pin_circle, size: 40, color: Colors.blue.shade700),
                      const SizedBox(height: 8),
                      const Text('Standard', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Pick up at DSWD Office', style: TextStyle(fontSize: 12)),
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
                      Icon(Icons.emergency, size: 40, color: Colors.red.shade700),
                      const SizedBox(height: 8),
                      const Text('Emergency', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Send location to DSWD', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      
      const Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          labelText: 'Notes (optional)',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => _requestNotes = value,
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
                          : (_detailedAddress.isNotEmpty ? _detailedAddress : 'No location captured'),
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_currentPosition == null ? 'Share My Location' : 'Update Location'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
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
            backgroundColor: _requestType == 'emergency' ? Colors.red.shade700 : Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _requestType == 'emergency' ? 'SUBMIT EMERGENCY REQUEST' : 'SUBMIT REQUEST',
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

  void _handleCancelRequest(String requestId) {
    _showConfirmDialog(
      'Cancel',
      'Are you sure you want to cancel this?',
      onConfirm: () async {
        await MongoDatabase.cancelRequest(requestId);
        await MongoDatabase.cancelDonation(requestId);
        await _fetchMyRequests();
        _showAlert('Cancelled', 'Your item has been cancelled.');
      },
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  void _showConfirmDialog(String title, String message, {required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'water': return const Color(0xFF06B6D4);
      case 'food': return const Color(0xFFF59E0B);
      case 'clothes': return const Color(0xFF10B981);
      case 'medical': return const Color(0xFFDC2626);
      case 'communication': return const Color(0xFF3B82F6);
      default: return const Color(0xFF666666);
    }
  }

  String _getCategoryName(String category) {
    return category;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 3),
              resources.TabBar(
                activeTab: _activeTab,
                onTabChanged: (tab) => setState(() => _activeTab = tab),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    _fetchInventoryItems();
                                    _fetchMyRequests();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            child: _buildContent(),
                          ),
              ),
            ],
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
                activeTab: _activeTab,
                quantity: _activeTab == 'request' ? _requestQuantity : _donationQuantity,
                urgent: _requestUrgent,
                notes: _activeTab == 'request' ? _requestNotes : _donationNotes,
                getCategoryColor: _getCategoryColor,
                getCategoryName: _getCategoryName,
                onClose: () => setState(() => _showModal = false),
                onQuantityChanged: _activeTab == 'request' 
                    ? (qty) => setState(() => _requestQuantity = qty)
                    : (qty) => setState(() => _donationQuantity = qty),
                onUrgentChanged: (value) => setState(() => _requestUrgent = value),
                onNotesChanged: _activeTab == 'request'
                    ? (text) => setState(() => _requestNotes = text)
                    : (text) => setState(() => _donationNotes = text),
                onSubmit: _activeTab == 'donate' ? _handleSubmitDonation : _handleSubmitRequest,
                onContactSupport: () {},
                customContent: _activeTab == 'donate' ? _buildDonationForm() : _buildRequestForm(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case 'donate':
        return resources.DonateContent(
          items: _inventoryItems,
          getCategoryColor: _getCategoryColor,
          onItemSelect: _handleDonationSelect,
        );
      case 'request':
        return resources.RequestContent(
          items: _inventoryItems,
          getCategoryColor: _getCategoryColor,
          onItemSelect: _handleRequestSelect,
        );
      case 'myRequests':
        return resources.MyRequestsContent(
          requests: _myRequests.map((req) => resources.MyRequest(
            id: req.id,
            resourceId: req.resourceId,
            quantity: req.quantity,
            urgent: req.urgent,
            notes: req.notes,
            status: req.status,
            date: req.date,
            type: req.type,
          )).toList(),
          donatableItems: _inventoryItems,
          requestableItems: _inventoryItems,
          getDonateCategoryColor: _getCategoryColor,
          getRequestCategoryColor: _getCategoryColor,
          onCancelRequest: _handleCancelRequest,
          onShowAlert: (title, message) => _showAlert(title, message),
        );
      default:
        return Container();
    }
  }
}