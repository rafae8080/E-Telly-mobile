import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../widgets/custom_font.dart';
import '../dbhelper/mongodb.dart';
import '../services/relay_queue_manager.dart';
import '../services/internet_checker_service.dart';
import '../screens/p2p_relay_screen.dart';

// Define EmergencyType class
class EmergencyType {
  final String id;
  final String title;
  final IconData icon;
  final Color typeColor;
  
  const EmergencyType({
    required this.id,
    required this.title,
    required this.icon,
    required this.typeColor,
  });
}

// Define SeverityLevel class
class SeverityLevel {
  final String level;
  final String label;
  final String description;
  final Color color;
  
  const SeverityLevel({
    required this.level,
    required this.label,
    required this.description,
    required this.color,
  });
}

// Define SummaryRow widget
class SummaryRow extends StatelessWidget {
  final String label;
  final Widget value;
  
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }
}

// Define ImagePreviewList widget
class ImagePreviewList extends StatelessWidget {
  final List<String> images;
  final void Function(int) onRemove;
  
  const ImagePreviewList({
    super.key,
    required this.images,
    required this.onRemove,
  });
  
  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 80.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                margin: EdgeInsets.only(right: 8.w),
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  image: DecorationImage(
                    image: FileImage(File(images[index])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 4.w,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// UserData class
class UserData {
  final String? fullName;
  final String? email;
  final String? address;
  final String? phoneNumber;
  
  const UserData({
    this.fullName,
    this.email,
    this.address,
    this.phoneNumber,
  });
}

class ReportEmergencyScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final dynamic mapController;
  final void Function(List<double> coordinates)? onLocated;

  const ReportEmergencyScreen({
    super.key, 
    this.onBackPressed,
    this.mapController,
    this.onLocated,
  });

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  String? _emergencyType;
  String _severity = 'Medium'; 
  bool _isSubmitting = false;
  UserData _userData = const UserData();
  bool _loading = true;
  final List<String> _images = [];
  bool _showAdditionalInfo = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Location variables
  bool _isLoadingLocation = false;
  String? _locationError;
  String _exactAddress = '';
  String _detailedAddress = '';
  String _street = '';
  String _barangay = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';
  String _landmark = '';
  String _buildingName = '';
  String _subLocality = '';
  
  // Store coordinates
  List<double> _currentPosition = const [];
  
  // User's previous reports
  List<Map<String, dynamic>> _userReports = [];
  bool _loadingReports = false;
  
  final List<EmergencyType> _emergencyTypes = const [
    EmergencyType(
      id: 'flood',
      title: 'Flood',
      icon: Icons.flood,
      typeColor: Color(0xFF06B6D4),
    ),
    EmergencyType(
      id: 'rescue',
      title: 'Rescue',
      icon: Icons.emoji_people,
      typeColor: Color(0xFF10B981),
    ),
    EmergencyType(
      id: 'medical',
      title: 'Medical',
      icon: Icons.medical_services,
      typeColor: Color(0xFFDC2626),
    ),
    EmergencyType(
      id: 'earthquake',
      title: 'Earthquake',
      icon: Icons.warning,
      typeColor: Color(0xFFF59E0B),
    ),
    EmergencyType(
      id: 'landslide',
      title: 'Landslide',
      icon: Icons.landslide,
      typeColor: Color(0xFFDC2626),
    ),
    EmergencyType(
      id: 'other',
      title: 'Other',
      icon: Icons.warning,
      typeColor: Color(0xFF666666),
    ),
  ];

  final List<SeverityLevel> _severityLevels = const [
    SeverityLevel(
      level: 'Low',
      label: 'Low',
      description: 'Minor issue, no immediate danger',
      color: Color(0xFF10B981),
    ),
    SeverityLevel(
      level: 'Medium',
      label: 'Medium',
      description: 'Significant issue, monitor closely',
      color: Color(0xFFF59E0B),
    ),
    SeverityLevel(
      level: 'High',
      label: 'High',
      description: 'Urgent, immediate action needed',
      color: Color(0xFFDC2626),
    ),
  ];

@override
void initState() {
  super.initState();
  _loadUserData();
  _loadUserReports();

  // Start internet checker — flushes relay queue whenever internet returns
  InternetCheckerService.instance.start(
    onCycleComplete: ({required int succeeded, required int failed}) {
      if (!mounted) return;
      if (succeeded > 0) {
        _loadUserReports();
      }
    },
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _getCurrentLocation().then((_) {
      debugPrint('Location loaded successfully');
    }).catchError((e) {
      debugPrint('Location loading error: $e');
    });
  });
}

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReportEmergencyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.mapController != oldWidget.mapController) {
      _getCurrentLocation();
    }
  }

  Color getSeverityColor(String severity) {
    switch (severity) {
      case 'Low': return const Color(0xFF10B981);
      case 'Medium': return const Color(0xFFF59E0B);
      case 'High': return const Color(0xFFDC2626);
      default: return const Color(0xFFF59E0B);
    }
  }

  Future<void> _loadUserReports() async {
    try {
      setState(() => _loadingReports = true);
      
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('email');
      
      if (userEmail != null && userEmail.isNotEmpty) {
        final localReports = prefs.getStringList('user_reports_$userEmail') ?? [];
        if (localReports.isNotEmpty) {
          final reports = localReports.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
          setState(() => _userReports = reports);
        }
        
        _loadReportsFromMongoDB(userEmail);
      }
    } catch (e) {
      debugPrint('Error loading user reports: $e');
      setState(() => _userReports = []);
    } finally {
      setState(() => _loadingReports = false);
    }
  }
  
  Future<void> _loadReportsFromMongoDB(String userEmail) async {
    try {
      final reports = await MongoDatabase.getUserEmergencyReports(userEmail);
      if (reports.isNotEmpty) {
        setState(() => _userReports = reports);
        final prefs = await SharedPreferences.getInstance();
        final reportsJson = reports.map((r) => jsonEncode(r)).toList();
        await prefs.setStringList('user_reports_$userEmail', reportsJson);
      }
    } catch (e) {
      debugPrint('Error loading from MongoDB: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'pending': return Icons.pending;
      default: return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      case 'pending': return 'PENDING';
      default: return status.toUpperCase();
    }
  }

  Future<void> _getCurrentLocation() async {
    // Check if location services are enabled
    final bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled. Please enable GPS.';
        _isLoadingLocation = false;
      });
      
      // Show dialog to enable location
      _showEnableLocationDialog();
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Request permission if not granted
      PermissionStatus permission = await Permission.location.status;
      
      if (!permission.isGranted) {
        permission = await Permission.location.request();
      }
      
      if (permission.isGranted) {
        // Try to get current position with best accuracy
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
        debugPrint('📍 ACCURACY: ${position.accuracy} meters');
        
        final List<double> coords = [position.latitude, position.longitude];
        setState(() {
          _currentPosition = coords;
        });
        
        if (widget.onLocated != null) {
          widget.onLocated!(coords);
        }
        
        // Get detailed address using multiple methods
        await _getAddressFromNominatim(position.latitude, position.longitude);
        
        setState(() {
          _isLoadingLocation = false;
        });
        
      } else if (permission.isDenied) {
        setState(() {
          _locationError = 'Location permission denied. Please enable location access.';
          _isLoadingLocation = false;
        });
        
        // Show explanation dialog
        _showPermissionDialog();
        
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _locationError = 'Location permission permanently denied. Please enable from settings.';
          _isLoadingLocation = false;
        });
        
        // Open app settings
        _showOpenSettingsDialog();
      }
    } catch (err) {
      debugPrint('Geolocation Error: ${err.toString()}');
      setState(() {
        _locationError = 'Unable to get location: ${err.toString()}';
        _isLoadingLocation = false;
      });
    }
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text('Please enable GPS/location services to report emergencies accurately.'),
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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('This app needs location access to report emergencies accurately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Permission.location.request();
              _getCurrentLocation();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('Location permission is permanently denied. Please enable it from app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _manualLocationEntry() async {
    final TextEditingController addressController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                hintText: 'Enter your exact address',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 8.h),
            const Text(
              'Example: R. Higgins Street, Zone 19, Pasay, 1309 Metro Manila',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final manualAddress = addressController.text.trim();
              if (manualAddress.isNotEmpty) {
                setState(() {
                  _exactAddress = manualAddress;
                  _detailedAddress = manualAddress;
                  _locationError = null;
                });
                
                // Try to geocode the manual address to get coordinates
                try {
                  List<Location> locations = await locationFromAddress(manualAddress);
                  if (locations.isNotEmpty) {
                    final loc = locations.first;
                    setState(() {
                      _currentPosition = [loc.latitude, loc.longitude];
                    });
                    if (widget.onLocated != null) {
                      widget.onLocated!([loc.latitude, loc.longitude]);
                    }
                  }
                } catch (e) {
                  debugPrint('Could not geocode manual address: $e');
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Helper method to check if a string is a plus code
  bool _isPlusCode(String text) {
    final plusCodePattern = RegExp(r'^[A-Z0-9]+\+[A-Z0-9]+', caseSensitive: false);
    return plusCodePattern.hasMatch(text);
  }

  // Get address from OpenStreetMap Nominatim API (better for Philippines)
  Future<void> _getAddressFromNominatim(double latitude, double longitude) async {
    try {
      debugPrint('📍 Fetching address from Nominatim API...');
      
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'EmergencyReportApp/1.0', // Required by Nominatim
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        
        if (address != null) {
          setState(() {
            // Extract address components
            _street = '';
            _barangay = '';
            _city = '';
            _province = '';
            _postalCode = '';
            _subLocality = '';
            
            final List<String> addressParts = [];
            
            // Building name or amenity
            if (data['name'] != null && data['name'].toString().isNotEmpty) {
              _buildingName = data['name'];
              addressParts.add(_buildingName);
            }
            
            // Road/Street name
            if (address['road'] != null && address['road'].toString().isNotEmpty) {
              String houseNumber = address['house_number'] ?? '';
              if (houseNumber.isNotEmpty) {
                _street = '$houseNumber ${address['road']}';
              } else {
                _street = address['road'];
              }
              addressParts.add(_street);
            } else if (address['pedestrian'] != null) {
              _street = address['pedestrian'];
              addressParts.add(_street);
            }
            
            // Suburb/Zone/Sub-locality
            if (address['suburb'] != null && address['suburb'].toString().isNotEmpty) {
              _subLocality = address['suburb'];
              addressParts.add(_subLocality);
            } else if (address['subdivision'] != null) {
              _subLocality = address['subdivision'];
              addressParts.add(_subLocality);
            }
            
            // Barangay/Village
            if (address['village'] != null && address['village'].toString().isNotEmpty) {
              _barangay = address['village'];
              addressParts.add(_barangay);
            } else if (address['neighbourhood'] != null) {
              _barangay = address['neighbourhood'];
              addressParts.add(_barangay);
            } else if (address['quarter'] != null) {
              _barangay = address['quarter'];
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
            
            // Province/State
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
            
            // Country
            if (address['country'] != null && address['country'].toString().isNotEmpty) {
              addressParts.add(address['country']);
            }
            
            if (addressParts.isNotEmpty) {
              _detailedAddress = addressParts.join(', ');
              _exactAddress = _detailedAddress;
            } else {
              // Fallback to display name
              _detailedAddress = data['display_name'] ?? 'Address not found';
              _exactAddress = _detailedAddress;
            }
            
            debugPrint('✅ NOMINATIM ADDRESS: $_detailedAddress');
            debugPrint('📍 Components - Building: $_buildingName, Street: $_street, SubLocality: $_subLocality, Barangay: $_barangay, City: $_city, Province: $_province, Postal: $_postalCode');
          });
          return;
        }
      }
      
      // Fallback to geocoding package if Nominatim fails
      await _getAddressFromGeocoding(latitude, longitude);
      
    } catch (e) {
      debugPrint('Nominatim API error: $e');
      // Fallback to geocoding package
      await _getAddressFromGeocoding(latitude, longitude);
    }
  }

  // Fallback method using geocoding package
  Future<void> _getAddressFromGeocoding(double latitude, double longitude) async {
    try {
      debugPrint('📍 Falling back to geocoding package...');
      
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude, 
        longitude,
        localeIdentifier: 'en_PH',
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => [],
      );
      
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        
        setState(() {
          final List<String> addressParts = [];
          
          // Street
          String streetAddress = '';
          if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
            streetAddress += '${place.subThoroughfare} ';
          }
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty && !_isPlusCode(place.thoroughfare!)) {
            streetAddress += place.thoroughfare!;
          }
          if (streetAddress.isNotEmpty && streetAddress.trim().isNotEmpty) {
            _street = streetAddress.trim();
            addressParts.add(_street);
          }
          
          // Barangay
          if (place.subLocality != null && place.subLocality!.isNotEmpty && !_isPlusCode(place.subLocality!)) {
            _barangay = place.subLocality!;
            addressParts.add(_barangay);
          } else if (place.locality != null && place.locality!.isNotEmpty && !_isPlusCode(place.locality!)) {
            _barangay = place.locality!;
            addressParts.add(_barangay);
          }
          
          // City
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            _city = place.administrativeArea!;
            addressParts.add(_city);
          }
          
          // Province
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            _province = place.subAdministrativeArea!;
            addressParts.add(_province);
          }
          
          // Postal code
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            _postalCode = place.postalCode!;
            addressParts.add(_postalCode);
          }
          
          if (addressParts.isNotEmpty) {
            _detailedAddress = addressParts.join(', ');
            _exactAddress = _detailedAddress;
          } else {
            _detailedAddress = '${place.name ?? "Location"}, ${place.locality ?? ""}, ${place.administrativeArea ?? ""}';
            _exactAddress = _detailedAddress;
          }
          
          debugPrint('✅ GEOCODING ADDRESS: $_detailedAddress');
        });
      } else {
        setState(() {
          _detailedAddress = 'Unable to get address';
          _exactAddress = 'Please enter your exact location';
          _locationError = 'Could not find address. Please enter manually.';
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      setState(() {
        _detailedAddress = 'Error getting address';
        _exactAddress = 'Please enter your location manually';
        _locationError = 'Failed to get address. Please enter manually.';
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userData = UserData(
          fullName: prefs.getString('full_name'),
          email: prefs.getString('email'),
          address: prefs.getString('address'),
          phoneNumber: prefs.getString('phone_number'),
        );
        _loading = false;
      });
    } catch (error) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null && _images.length < 5) {
      setState(() => _images.add(image.path));
    } else if (_images.length >= 5) {
      _showAlert('Limit Reached', 'You can only upload up to 5 images');
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (image != null && _images.length < 5) {
      setState(() => _images.add(image.path));
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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

  void _resetForm() {
    setState(() {
      _emergencyType = null;
      _severity = 'Medium';
      _images.clear();
      _showAdditionalInfo = false;
      _descriptionController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (_emergencyType == null) {
      _showAlert('Error', 'Please select an emergency type');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      String finalAddress = _exactAddress;
      if (finalAddress.isEmpty || finalAddress == 'Please enter your exact location' || finalAddress == 'Please enter your location manually') {
        if (_currentPosition.isNotEmpty) {
          finalAddress = 'Location coordinates available';
        } else {
          finalAddress = 'Location unavailable';
        }
      }
      
      final report = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'emergencyType': _emergencyType,
        'severity': _severity,
        'description': _descriptionController.text.trim(),
        'images': List<String>.from(_images),
        'userData': {
          'fullName': _userData.fullName ?? 'Anonymous',
          'email': _userData.email ?? 'no-email@example.com',
          'address': _userData.address ?? finalAddress,
          'phoneNumber': _userData.phoneNumber ?? 'Not provided',
        },
        'location': {
          'exactAddress': finalAddress,
          'detailedAddress': _detailedAddress,
          'street': _street,
          'barangay': _barangay,
          'city': _city,
          'province': _province,
          'postalCode': _postalCode,
          'landmark': _landmark,
          'buildingName': _buildingName,
          'subLocality': _subLocality,
          'coordinates': {
            'latitude': _currentPosition.isNotEmpty ? _currentPosition[0] : null,
            'longitude': _currentPosition.isNotEmpty ? _currentPosition[1] : null,
          }
        },
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toString(),
        'status': 'pending',
      };
      
      await _saveToLocalStorage(report);

      await RelayQueueManager.enqueue(report); 
      
      setState(() {
        _userReports.insert(0, report);
      });
      
      _showSuccessDialog();
      _resetForm();
      
      if (mounted) setState(() => _isSubmitting = false);
      
      //_saveToMongoDBInBackground(report);
      final isOnline = await InternetCheckerService.instance.forceFlushIfOnline();
      if (isOnline) {
        _notifyBackendInBackground(report);
      }
      _syncReportsToLocalStorage();
      
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showAlert('Error', 'Failed to save report: $e');
      }
    }
  }
  
  Future<void> _saveToLocalStorage(Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = _userData.email ?? 'anonymous';
      List<String> savedReports = prefs.getStringList('user_reports_$userEmail') ?? [];
      savedReports.insert(0, jsonEncode(report));
      if (savedReports.length > 50) savedReports = savedReports.take(50).toList();
      await prefs.setStringList('user_reports_$userEmail', savedReports);
      debugPrint('Report saved to local storage');
    } catch (e) {
      debugPrint('Error saving to local storage: $e');
    }
  }
  
  Future<void> _syncReportsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = _userData.email ?? 'anonymous';
      final reportsJson = _userReports.map((r) => jsonEncode(r)).toList();
      await prefs.setStringList('user_reports_$userEmail', reportsJson);
    } catch (e) {
      debugPrint('Error syncing to local storage: $e');
    }
  }

  Future<void> _saveToMongoDBInBackground(Map<String, dynamic> report) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await MongoDatabase.connect();
      await MongoDatabase.saveEmergencyReport(report);
      debugPrint('Report saved to MongoDB in background');
    } catch (e) {
      debugPrint('Background MongoDB save failed: $e');
    }
  }
  
  Future<void> _notifyBackendInBackground(Map<String, dynamic> report) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final response = await http.post(
        Uri.parse('https://e-telly-ca75b10e9536.herokuapp.com/api/notify-emergency'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reportId': report['id'],
          'emergencyType': report['emergencyType'],
          'severity': report['severity'],
          'location': report['location']['exactAddress'],
          'detailedAddress': report['location']['detailedAddress'],
          'barangay': report['location']['barangay'],
          'city': report['location']['city'],
          'timestamp': report['timestamp'],
          'userName': report['userData']['fullName'],
          'phoneNumber': report['userData']['phoneNumber'],
          'description': report['description'],
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Backend notified successfully');
      } else {
        debugPrint('Failed to notify backend: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error notifying backend: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Report Submitted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your emergency report has been submitted successfully.'),
            SizedBox(height: 12.h),
            if (_detailedAddress.isNotEmpty && _detailedAddress != 'Getting address...') ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📍 LOCATION:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                    SizedBox(height: 6.h),
                    Text(_detailedAddress, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
                    if (_barangay.isNotEmpty && _city.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text('$_barangay, $_city', style: TextStyle(fontSize: 11.sp, color: Colors.blue.shade700)),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: getSeverityColor(_severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: getSeverityColor(_severity).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: getSeverityColor(_severity), size: 20.sp),
                  SizedBox(width: 8.w),
                  Text('Severity Level: $_severity',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: getSeverityColor(_severity))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onBackPressed != null) {
                widget.onBackPressed!();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (_isLoadingLocation) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16.w,
              height: 16.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Getting your exact location...',
              style: TextStyle(fontSize: 12.sp),
            ),
          ],
        ),
      );
    } else if (_locationError != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 16.sp, color: Colors.red),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _locationError!,
                style: TextStyle(fontSize: 11.sp, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Retry',
                style: TextStyle(fontSize: 11.sp),
              ),
            ),
            TextButton(
              onPressed: _manualLocationEntry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Enter Manually',
                style: TextStyle(fontSize: 11.sp, color: Colors.blue),
              ),
            ),
          ],
        ),
      );
    } else if (_detailedAddress.isNotEmpty && _detailedAddress != 'Getting address...' && _detailedAddress != 'Error getting address') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on, size: 16.sp, color: Colors.green),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your Location:',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _detailedAddress,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_barangay.isNotEmpty && _city.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      '$_barangay, $_city',
                      style: TextStyle(fontSize: 9.sp, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: _getCurrentLocation,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(Icons.refresh, size: 16.sp, color: Colors.green),
              ),
            ),
            GestureDetector(
              onTap: _manualLocationEntry,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(Icons.edit, size: 16.sp, color: Colors.blue),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEmergencyTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 0.9,
      ),
      itemCount: _emergencyTypes.length,
      itemBuilder: (context, index) {
        final type = _emergencyTypes[index];
        final isSelected = _emergencyType == type.id;
        return GestureDetector(
          onTap: () => setState(() => _emergencyType = type.id),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isSelected ? type.typeColor : const Color(0xFFE5E7EB),
                width: isSelected ? 2.w : 1.w,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36.w,
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: type.typeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(type.icon, size: 22.sp, color: Colors.white),
                ),
                SizedBox(height: 6.h),
                Text(
                  type.title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeverityGrid() {
    return Column(
      children: _severityLevels.map((level) {
        final isSelected = _severity == level.level;
        return GestureDetector(
          onTap: () => setState(() => _severity = level.level),
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isSelected ? level.color : const Color(0xFFE5E7EB),
                width: isSelected ? 2.w : 1.w,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 16.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: level.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    level.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? level.color : Colors.black,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      maxLines: 4,
      maxLength: 500,
      decoration: InputDecoration(
        hintText: 'Describe your emergency situation...',
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
        contentPadding: EdgeInsets.all(14.w),
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildSummaryCard() {
    final selectedEmergency = _emergencyTypes.firstWhere(
      (e) => e.id == _emergencyType,
      orElse: () => _emergencyTypes[0],
    );
    final selectedSeverity = _severityLevels.firstWhere(
      (s) => s.level == _severity,
      orElse: () => _severityLevels[1],
    );

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryRow(
            label: 'Type:',
            value: Text(
              selectedEmergency.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
            ),
          ),
          Divider(height: 20.h),
          SummaryRow(
            label: 'Severity:',
            value: Text(
              selectedSeverity.label,
              style: TextStyle(
                color: selectedSeverity.color,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ),
          Divider(height: 20.h),
          SummaryRow(
            label: 'Location:',
            value: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _detailedAddress.isNotEmpty && _detailedAddress != 'Getting address...'
                      ? _detailedAddress 
                      : (_userData.address ?? 'Getting location...'),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.sp),
                  ),
                  if (_barangay.isNotEmpty && _city.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      '($_barangay, $_city)',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_descriptionController.text.isNotEmpty) ...[
            Divider(height: 20.h),
            Text('Description:', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            SizedBox(height: 4.h),
            Text(_descriptionController.text, style: TextStyle(fontSize: 12.sp)),
          ],
          if (_images.isNotEmpty) ...[
            Divider(height: 20.h),
            Text('Attachments: ${_images.length} image(s)', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
 
  Widget _buildP2PRelayButton() {
    final pendingCount = RelayQueueManager.pendingCount;
 
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const P2PRelayScreen(),
            ),
          ).then((_) {
            // Refresh reports list when returning from P2P screen
            _loadUserReports();
          });
        },
        icon: Icon(
          Icons.bluetooth_searching,
          size: 18.sp,
          color: const Color(0xFF06B6D4),
        ),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Send via P2P',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF06B6D4),
              ),
            ),
            if (pendingCount > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$pendingCount',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: const Color(0xFF06B6D4).withOpacity(0.5),
            width: 1.5.w,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: const Color(0xFFDC2626).withOpacity(0.2),
          width: 0.5.w,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, size: 16.sp, color: const Color(0xFFDC2626)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'This emergency report will be sent immediately to emergency responders. '
              'False reports may result in legal action. In case of immediate danger, call 911 first.',
              style: TextStyle(fontSize: 11.sp, color: const Color(0xFF1F2937), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStatusSection() {
    if (_loadingReports) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_userReports.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: const Center(
          child: Text(
            'No reports submitted yet.\nSubmit your first emergency report above.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    final recentReports = _userReports.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Your Recent Reports',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...recentReports.map((report) {
          final status = report['status'] ?? 'pending';
          final statusColor = _getStatusColor(status);
          
          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            report['emergencyType'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        report['location']?['barangay'] ?? report['location']?['city'] ?? 'Unknown location',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatDate(report['timestamp']),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                if (report['adminNotes'] != null && report['adminNotes'].toString().isNotEmpty)
                  Tooltip(
                    message: report['adminNotes'],
                    child: Icon(
                      Icons.info_outline,
                      size: 16.sp,
                      color: status == 'rejected' ? Colors.red : Colors.blue,
                    ),
                  ),
              ],
            ),
          );
        }),
        if (_userReports.length > 3)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: TextButton(
              onPressed: _showAllReportsDialog,
              child: const Text('View all reports →'),
            ),
          ),
      ],
    );
  }
  
  void _showAllReportsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 40,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                const Text(
                  'All Reports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _userReports.length,
                    itemBuilder: (context, index) {
                      final report = _userReports[index];
                      final status = report['status'] ?? 'pending';
                      final statusColor = _getStatusColor(status);
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        child: ListTile(
                          leading: Container(
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: statusColor,
                            ),
                          ),
                          title: Text(
                            report['emergencyType'].toString().toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(report['location']?['barangay'] ?? report['location']?['city'] ?? 'Unknown'),
                              Text(
                                _formatDate(report['timestamp']),
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (report['adminNotes'] != null)
                                Text(
                                  'Note: ${report['adminNotes']}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: status == 'rejected' ? Colors.red : Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              _getStatusText(status),
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
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
          );
        },
      ),
    );
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4.w, top: 4.h),
              child: const CustomFont(
                text: 'What is your emergency?',
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            
            _buildLocationStatus(),
            SizedBox(height: 12.h),
      
            _buildEmergencyTypeGrid(),
      
            if (_emergencyType == null) ...[
              SizedBox(height: 16.h),
              _buildDisclaimer(),
            ],
      
            if (_emergencyType != null) ...[
              SizedBox(height: 20.h),
              const Text(
                'Select Severity Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              _buildSeverityGrid(),
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: () =>
                    setState(() => _showAdditionalInfo = !_showAdditionalInfo),
                child: Row(
                  children: [
                    Icon(
                      _showAdditionalInfo ? Icons.expand_less : Icons.expand_more,
                      size: 20.sp,
                    ),
                    const Text(
                      ' Additional Info (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (_showAdditionalInfo) ...[
                SizedBox(height: 12.h),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6.h),
                _buildDescriptionField(),
                SizedBox(height: 12.h),
                const Text(
                  'Attach Photos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: Icon(Icons.camera_alt, size: 18.sp),
                        label: Text('Camera', style: TextStyle(fontSize: 12.sp)),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.photo_library, size: 18.sp),
                        label: Text('Gallery', style: TextStyle(fontSize: 12.sp)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ImagePreviewList(images: _images, onRemove: _removeImage),
              ],
              SizedBox(height: 20.h),
              const Text(
                'Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              _buildSummaryCard(),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'SUBMIT REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 10.h),
              _buildP2PRelayButton(),
              SizedBox(height: 16.h),
              _buildDisclaimer(),
              SizedBox(height: 20.h),
              
              Divider(height: 30.h),
              _buildReportStatusSection(),
              SizedBox(height: 20.h),
            ],
          ],
        ),
      ),
    );
  }
}