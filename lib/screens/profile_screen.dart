import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../dbhelper/mongodb.dart';
import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';

// Antipolo City specific barangays
final List<String> antipoloBarangays = [
  'Bagong Nayon',
  'Beverly Hills',
  'Calumpang',
  'Cupang',
  'Dalig',
  'Dela Paz',
  'Inarawan',
  'Ligaya',
  'Mambugan',
  'Muntingdilaw',
  'San Isidro',
  'San Jose',
  'San Juan',
  'San Luis',
  'San Roque',
  'Santa Cruz',
  'Santa Elena',
  'Taytay',
  'Tumana',
  'Villa Carissa'
];

class UserProfile {
  String? id;
  String? fullName;
  String? email;
  String? phoneNumber;
  String? region;
  String? province;
  String? city;
  String? barangay;
  String? postalCode;
  String? streetAddress;
  String? emergencyContactName;
  String? emergencyContactPhone;
  String? emergencyContactRelationship;
  String? landmark;
  String role;

  UserProfile({
    this.id,
    this.fullName,
    this.email,
    this.phoneNumber,
    this.region = 'CALABARZON (Region IV-A)',
    this.province = 'Rizal',
    this.city = 'Antipolo City',
    this.barangay,
    this.postalCode = '1870',
    this.streetAddress,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.landmark,
    this.role = 'resident',
  });

  UserProfile copy() {
    return UserProfile(
      id: id,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      region: region,
      province: province,
      city: city,
      barangay: barangay,
      postalCode: postalCode,
      streetAddress: streetAddress,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      emergencyContactRelationship: emergencyContactRelationship,
      landmark: landmark,
      role: role,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'region': region,
      'province': province,
      'city': city,
      'barangay': barangay,
      'postalCode': postalCode,
      'streetAddress': streetAddress,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelationship': emergencyContactRelationship,
      'landmark': landmark,
      'role': role,
    };
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  
  UserProfile _profile = UserProfile();
  bool _isEditing = false;
  UserProfile _editedProfile = UserProfile();
  String? _profileImage;
  bool _isUploading = false;
  bool _showEmergencyModal = false;
  bool _isLoading = true;
  bool _isGettingLocation = false;
  final ImagePicker _picker = ImagePicker();
  String? _userEmail;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _barangayController;
  late TextEditingController _streetAddressController;
  late TextEditingController _landmarkController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationshipController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _checkAuthAndLoadProfile();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _barangayController = TextEditingController();
    _streetAddressController = TextEditingController();
    _landmarkController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _emergencyRelationshipController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _barangayController.dispose();
    _streetAddressController.dispose();
    _landmarkController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    try {
      final isValid = await _authService.isLoggedIn();
      
      if (!isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        await HiveService.setLoggedIn(false);
        
        if (mounted) {
          _showAlert('Session Expired', 'Please login again');
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        return;
      }
      
      await _loadUserProfile();
      
    } catch (e) {
      print('Auth check error: $e');
      if (mounted) {
        _showAlert('Error', 'Failed to authenticate');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _userEmail = prefs.getString('userEmail');
      
      if (_userEmail == null || _userEmail!.isEmpty) {
        print('No logged in user found');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showAlert('Error', 'Please login first');
        return;
      }
      
      print('Loading profile for email: $_userEmail');
      
      var userData = await MongoDatabase.findUserByEmail(_userEmail!);
      
      if (userData != null) {
        print('User data found: ${userData['email']}');

        String fullName = userData['name'] ?? '';
        String email = userData['email'] ?? '';
        String barangay = userData['barangay'] ?? '';
        String streetDetails = userData['streetDetails'] ?? '';
        String role = userData['role'] ?? 'resident';
        String landmark = userData['landmark'] ?? '';

        if (!mounted) return;
        setState(() {
          _profile = UserProfile(
            id: userData['_id']?.toString(),
            fullName: fullName,
            email: email,
            phoneNumber: userData['phoneNumber'] ?? '',
            region: 'CALABARZON (Region IV-A)',
            province: 'Rizal',
            city: 'Antipolo City',
            barangay: barangay,
            postalCode: '1870',
            streetAddress: streetDetails,
            emergencyContactName: userData['emergencyContactName'] ?? '',
            emergencyContactPhone: userData['emergencyContactPhone'] ?? '',
            emergencyContactRelationship: userData['emergencyContactRelationship'] ?? '',
            landmark: landmark,
            role: role,
          );
          
          _saveProfileToPreferences();
          _updateJWTToken();
          
          _editedProfile = _profile.copy();
          _updateControllersFromProfile();
          _isLoading = false;
        });
      } else {
        print('No user data found in MongoDB for email: $_userEmail');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showAlert('Error', 'User data not found');
      }
    } catch (error) {
      print('Error loading profile: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showAlert('Error', 'Failed to load profile data');
    }
  }
  
  Future<void> _updateJWTToken() async {
    // Only update the locally-cached user data — never replace the server-issued JWT.
    // Generating a local JWT with a different secret breaks server-side auth
    // (ownership checks return 403 because req.user.id won't match stored userId).
    try {
      final userMap = _profile.toMap();
      await _authService.updateUserData(userMap);
      await HiveService.setLoggedIn(true);
      print('Local user data cache updated (server JWT preserved)');
    } catch (e) {
      print('Error updating local user data: $e');
    }
  }
  
  Future<void> _saveProfileToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('full_name', _profile.fullName ?? '');
      await prefs.setString('email', _profile.email ?? '');
      await prefs.setString('phone_number', _profile.phoneNumber ?? '');
      await prefs.setString('region', _profile.region ?? '');
      await prefs.setString('province', _profile.province ?? '');
      await prefs.setString('city', _profile.city ?? '');
      await prefs.setString('barangay', _profile.barangay ?? '');
      await prefs.setString('postal_code', _profile.postalCode ?? '');
      await prefs.setString('street_address', _profile.streetAddress ?? '');
      await prefs.setString('landmark', _profile.landmark ?? '');
      await prefs.setString('emergency_contact_name', _profile.emergencyContactName ?? '');
      await prefs.setString('emergency_contact_phone', _profile.emergencyContactPhone ?? '');
      await prefs.setString('emergency_contact_relationship', _profile.emergencyContactRelationship ?? '');
      await prefs.setString('role', _profile.role);
    } catch (error) {
      print('Error saving to preferences: $error');
    }
  }

  Future<void> _getCurrentAddress() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showAlert('Location Error', 'Please enable location services');
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showAlert('Location Error', 'Location permission denied');
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showAlert('Location Error', 'Location permissions are permanently denied');
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        String fullAddress = '';
        
        if (place.street != null && place.street!.isNotEmpty) {
          fullAddress = place.street!;
        }
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          if (fullAddress.isNotEmpty) fullAddress += ', ';
          fullAddress += place.subLocality!;
        }
        
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          if (fullAddress.isNotEmpty) fullAddress += ', ';
          fullAddress += place.thoroughfare!;
        }
        
        setState(() {
          _editedProfile.streetAddress = fullAddress;
          _streetAddressController.text = fullAddress;
        });
        
        String detectedBarangay = '';
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          for (String barangay in antipoloBarangays) {
            if (place.subLocality!.toLowerCase().contains(barangay.toLowerCase()) ||
                barangay.toLowerCase().contains(place.subLocality!.toLowerCase())) {
              detectedBarangay = barangay;
              break;
            }
          }
        }
        
        if (detectedBarangay.isEmpty && place.locality != null) {
          for (String barangay in antipoloBarangays) {
            if (place.locality!.toLowerCase().contains(barangay.toLowerCase())) {
              detectedBarangay = barangay;
              break;
            }
          }
        }
        
        if (detectedBarangay.isNotEmpty) {
          setState(() {
            _editedProfile.barangay = detectedBarangay;
            _barangayController.text = detectedBarangay;
          });
          _showAlert('Location Found', 
            'Address: $fullAddress\n\nBarangay: $detectedBarangay\n\nCity: Antipolo City\n\nProvince: Rizal');
        } else {
          _showAlert('Location Found', 
            'Address: $fullAddress\n\nNote: Please manually select your Barangay');
        }
      } else {
        _showAlert('Location Error', 'Could not get address from location');
      }
    } catch (e) {
      print('Error getting location: $e');
      _showAlert('Location Error', 'Failed to get location: $e');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        _updateProfileImage(image.path);
      }
    } catch (error) {
      _showAlert('Error', 'Failed to pick image');
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        _updateProfileImage(image.path);
      }
    } catch (error) {
      _showAlert('Error', 'Failed to take photo');
    }
  }

  Future<void> _updateProfileImage(String imagePath) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', imagePath);
      
      setState(() {
        _profileImage = imagePath;
        _isUploading = false;
      });

      _showAlert('Success', 'Profile image updated successfully');
    } catch (error) {
      setState(() {
        _isUploading = false;
      });
      _showAlert('Error', 'Failed to update profile image');
    }
  }

  void _handleEdit() {
    setState(() {
      _isEditing = true;
      _editedProfile = _profile.copy();
      _updateControllersFromProfile();
    });
  }

  Future<void> _handleSave() async {
    if (_editedProfile.fullName == null || _editedProfile.fullName!.isEmpty) {
      _showAlert('Error', 'Please enter your name');
      return;
    }

    if (_editedProfile.barangay == null || _editedProfile.barangay!.isEmpty) {
      _showAlert('Error', 'Please select your barangay in Antipolo City');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> updatedData = {
        'name': _editedProfile.fullName,
        'phoneNumber': _editedProfile.phoneNumber ?? '',
        'region': 'CALABARZON (Region IV-A)',
        'province': 'Rizal',
        'city': 'Antipolo City',
        'barangay': _editedProfile.barangay,
        'postalCode': '1870',
        'streetDetails': _editedProfile.streetAddress ?? '',
        'landmark': _editedProfile.landmark ?? '',
        'address': '${_editedProfile.streetAddress ?? ''}, ${_editedProfile.barangay ?? ''}, Antipolo City, Rizal',
        'emergencyContactName': _editedProfile.emergencyContactName ?? '',
        'emergencyContactPhone': _editedProfile.emergencyContactPhone ?? '',
        'emergencyContactRelationship': _editedProfile.emergencyContactRelationship ?? '',
      };
      
      bool success = await MongoDatabase.updateUser(_userEmail!, updatedData);
      
      if (success) {
        setState(() {
          _profile = _editedProfile.copy();
          _isEditing = false;
          _isLoading = false;
        });
        
        await _saveProfileToPreferences();
        await _updateJWTToken();
        
        _showAlert('Success', 'Profile updated successfully');
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (error) {
      print('Error saving profile: $error');
      setState(() {
        _isLoading = false;
      });
      _showAlert('Error', 'Failed to save profile');
    }
  }

  void _handleCancel() {
    setState(() {
      _isEditing = false;
      _editedProfile = _profile.copy();
      _updateControllersFromProfile();
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Cancel token refresh listener and unregister from backend before JWT is cleared
      NotificationService.cancelTokenRefresh();
      try {
        final fcmToken = await NotificationService.getToken();
        if (fcmToken != null) {
          await ApiService().authenticatedDelete(
            '/api/push/fcm-unsubscribe',
            {'token': fcmToken},
          );
        }
      } catch (e) {
        print('[FCM] Unsubscribe failed: $e');
      }

      await _authService.logout();
      await HiveService.clearSession();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Logout error: $e');
      if (mounted) {
        _showAlert('Error', 'Failed to logout properly');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateControllersFromProfile() {
    _nameController.text = _editedProfile.fullName ?? '';
    _phoneController.text = _editedProfile.phoneNumber ?? '';
    _barangayController.text = _editedProfile.barangay ?? '';
    _streetAddressController.text = _editedProfile.streetAddress ?? '';
    _landmarkController.text = _editedProfile.landmark ?? '';
    _emergencyNameController.text = _editedProfile.emergencyContactName ?? '';
    _emergencyPhoneController.text = _editedProfile.emergencyContactPhone ?? '';
    _emergencyRelationshipController.text =
        _editedProfile.emergencyContactRelationship ?? '';
  }

  void _showImagePickerOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFDC2626)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takeProfilePhoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFDC2626),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: const Text(
                'Select Barangay in Antipolo City',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: antipoloBarangays.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(antipoloBarangays[index]),
                    onTap: () {
                      setState(() {
                        _editedProfile.barangay = antipoloBarangays[index];
                        _barangayController.text = antipoloBarangays[index];
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFDC2626)),
              const SizedBox(height: 20),
              const Text(
                'Loading profile...',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: null,
        automaticallyImplyLeading: false,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: _handleEdit,
              icon: const Icon(Icons.edit, color: Color(0xFFDC2626)),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _handleSave,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _isEditing ? _showImagePickerOptions : null,
                        child: Stack(
                          children: [
                            if (_isUploading)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              )
                            else if (_profileImage != null)
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: FileImage(File(_profileImage!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _profile.fullName
                                            ?.split(' ')
                                            .map((n) => n.isNotEmpty ? n[0] : '')
                                            .join('')
                                            .toUpperCase() ??
                                        'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              TextField(
                                controller: _nameController,
                                onChanged: (value) => setState(
                                  () => _editedProfile.fullName = value,
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Full Name',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDC2626),
                                      width: 2,
                                    ),
                                  ),
                                  isDense: true,
                                ),
                              )
                            else
                              Text(
                                _profile.fullName ?? 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _profile.email ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _profile.role == 'lgu_admin'
                                    ? 'LGU Admin'
                                    : 'Resident',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  PersonalInfoSection(
                    isEditing: _isEditing,
                    profile: _profile,
                    phoneController: _phoneController,
                    onPhoneChanged: (value) =>
                        setState(() => _editedProfile.phoneNumber = value),
                  ),
                  
                  AddressSection(
                    isEditing: _isEditing,
                    profile: _profile,
                    barangayController: _barangayController,
                    streetAddressController: _streetAddressController,
                    landmarkController: _landmarkController,
                    onBarangayChanged: (value) =>
                        setState(() => _editedProfile.barangay = value),
                    onStreetAddressChanged: (value) =>
                        setState(() => _editedProfile.streetAddress = value),
                    onLandmarkChanged: (value) =>
                        setState(() => _editedProfile.landmark = value),
                    onBarangayTap: _showBarangayPicker,
                    onGetCurrentAddress: _isEditing ? _getCurrentAddress : null,
                    isGettingLocation: _isGettingLocation,
                  ),
                  
                  EmergencyContactSection(
                    isEditing: _isEditing,
                    profile: _profile,
                    emergencyNameController: _emergencyNameController,
                    emergencyPhoneController: _emergencyPhoneController,
                    emergencyRelationshipController:
                        _emergencyRelationshipController,
                    onEmergencyNameChanged: (value) => setState(
                      () => _editedProfile.emergencyContactName = value,
                    ),
                    onEmergencyPhoneChanged: (value) => setState(
                      () => _editedProfile.emergencyContactPhone = value,
                    ),
                    onEmergencyRelationshipChanged: (value) => setState(
                      () => _editedProfile.emergencyContactRelationship = value,
                    ),
                    onInfoPressed: () =>
                        setState(() => _showEmergencyModal = true),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Logout Button - Styled exactly like Login button
                  if (!_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        ],
      ),
      bottomSheet: _showEmergencyModal
          ? EmergencyModal(
              onClose: () => setState(() => _showEmergencyModal = false),
            )
          : null,
    );
  }
}

class PersonalInfoSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController phoneController;
  final Function(String) onPhoneChanged;

  const PersonalInfoSection({
    super.key,
    required this.isEditing,
    required this.profile,
    required this.phoneController,
    required this.onPhoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEditing) ...[
              TextField(
                controller: phoneController,
                onChanged: onPhoneChanged,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '09XX XXX XXXX',
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
            ] else ...[
              _buildInfoRow('Phone Number', profile.phoneNumber ?? 'Not set'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}

class AddressSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController barangayController;
  final TextEditingController streetAddressController;
  final TextEditingController landmarkController;
  final Function(String) onBarangayChanged;
  final Function(String) onStreetAddressChanged;
  final Function(String) onLandmarkChanged;
  final VoidCallback onBarangayTap;
  final VoidCallback? onGetCurrentAddress;
  final bool isGettingLocation;

  const AddressSection({
    super.key,
    required this.isEditing,
    required this.profile,
    required this.barangayController,
    required this.streetAddressController,
    required this.landmarkController,
    required this.onBarangayChanged,
    required this.onStreetAddressChanged,
    required this.onLandmarkChanged,
    required this.onBarangayTap,
    this.onGetCurrentAddress,
    this.isGettingLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Address Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                if (isEditing && onGetCurrentAddress != null)
                  ElevatedButton.icon(
                    onPressed: isGettingLocation ? null : onGetCurrentAddress,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(
                      isGettingLocation ? 'Getting...' : 'Use Current Location',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEditing) ...[
              GestureDetector(
                onTap: onBarangayTap,
                child: AbsorbPointer(
                  child: TextField(
                    controller: barangayController,
                    onChanged: onBarangayChanged,
                    decoration: InputDecoration(
                      labelText: 'Barangay *',
                      hintText: 'Select your barangay in Antipolo',
                      prefixIcon: const Icon(Icons.location_city, size: 20),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: streetAddressController,
                onChanged: onStreetAddressChanged,
                decoration: InputDecoration(
                  labelText: 'Street Address',
                  hintText: 'House number, street, subdivision',
                  prefixIcon: const Icon(Icons.streetview, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: landmarkController,
                onChanged: onLandmarkChanged,
                decoration: InputDecoration(
                  labelText: 'Landmark (Optional)',
                  hintText: 'e.g., Near Antipolo Cathedral, beside SM Cherry',
                  prefixIcon: const Icon(Icons.flag, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
            ] else ...[
              _buildInfoRow('Barangay', profile.barangay ?? 'Not set'),
              const SizedBox(height: 12),
              _buildInfoRow('Street Address', profile.streetAddress ?? 'Not set'),
              if (profile.landmark != null && profile.landmark!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Landmark', profile.landmark!),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Postal Code: 1870',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}

class EmergencyContactSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController emergencyNameController;
  final TextEditingController emergencyPhoneController;
  final TextEditingController emergencyRelationshipController;
  final Function(String) onEmergencyNameChanged;
  final Function(String) onEmergencyPhoneChanged;
  final Function(String) onEmergencyRelationshipChanged;
  final VoidCallback onInfoPressed;

  const EmergencyContactSection({
    super.key,
    required this.isEditing,
    required this.profile,
    required this.emergencyNameController,
    required this.emergencyPhoneController,
    required this.emergencyRelationshipController,
    required this.onEmergencyNameChanged,
    required this.onEmergencyPhoneChanged,
    required this.onEmergencyRelationshipChanged,
    required this.onInfoPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency, size: 20, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onInfoPressed,
                  icon: const Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEditing) ...[
              TextField(
                controller: emergencyNameController,
                onChanged: onEmergencyNameChanged,
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  hintText: 'Full name of emergency contact',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emergencyPhoneController,
                onChanged: onEmergencyPhoneChanged,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Contact Phone Number',
                  hintText: '09XX XXX XXXX',
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emergencyRelationshipController,
                onChanged: onEmergencyRelationshipChanged,
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g., Spouse, Parent, Sibling',
                  prefixIcon: const Icon(Icons.family_restroom, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                  ),
                ),
              ),
            ] else ...[
              _buildInfoRow('Name', profile.emergencyContactName ?? 'Not set'),
              const SizedBox(height: 12),
              _buildInfoRow('Phone', profile.emergencyContactPhone ?? 'Not set'),
              const SizedBox(height: 12),
              _buildInfoRow('Relationship', profile.emergencyContactRelationship ?? 'Not set'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}

class EmergencyModal extends StatelessWidget {
  final VoidCallback onClose;

  const EmergencyModal({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.emergency, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Why is Emergency Contact Important?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'In case of emergencies, we need to have a contact person who can be reached immediately. This information helps us:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 16),
                  _buildBulletPoint('Quickly notify your family or friends'),
                  _buildBulletPoint('Provide immediate assistance when needed'),
                  _buildBulletPoint('Ensure your safety and well-being'),
                  _buildBulletPoint('Coordinate with local authorities if necessary'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Please make sure to keep this information updated.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 14, color: Color(0xFFDC2626)),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}