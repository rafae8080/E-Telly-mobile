import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/profile.dart';

class UserProfile {
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
  String role;

  UserProfile({
    this.fullName,
    this.email,
    this.phoneNumber,
    this.region,
    this.province,
    this.city,
    this.barangay,
    this.postalCode,
    this.streetAddress,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.role = 'resident',
  });

  UserProfile copy() {
    return UserProfile(
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
      role: role,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = UserProfile();
  bool _isEditing = false;
  UserProfile _editedProfile = UserProfile();
  String? _profileImage;
  bool _isUploading = false;
  bool _showEmergencyModal = false;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _regionController;
  late TextEditingController _provinceController;
  late TextEditingController _cityController;
  late TextEditingController _barangayController;
  late TextEditingController _postalCodeController;
  late TextEditingController _streetAddressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationshipController;

  final List<Map<String, dynamic>> bottomNavItems = [
    {
      'id': 'home',
      'label': 'Home',
      'icon': Icons.home_outlined,
      'iconActive': Icons.home,
    },
    {
      'id': 'safety',
      'label': 'Safety Tips',
      'icon': Icons.security_outlined,
      'iconActive': Icons.security,
    },
    {
      'id': 'evac',
      'label': 'Evac Map',
      'icon': Icons.map_outlined,
      'iconActive': Icons.map,
    },
    {
      'id': 'resources',
      'label': 'Resources',
      'icon': Icons.inventory_outlined,
      'iconActive': Icons.inventory,
    },
    {
      'id': 'profile',
      'label': 'Profile',
      'icon': Icons.person_outline,
      'iconActive': Icons.person,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserProfile();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _regionController = TextEditingController();
    _provinceController = TextEditingController();
    _cityController = TextEditingController();
    _barangayController = TextEditingController();
    _postalCodeController = TextEditingController();
    _streetAddressController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _emergencyRelationshipController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _barangayController.dispose();
    _postalCodeController.dispose();
    _streetAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();
    super.dispose();
  }

  void _updateControllersFromProfile() {
    _nameController.text = _editedProfile.fullName ?? '';
    _phoneController.text = _editedProfile.phoneNumber ?? '';
    _regionController.text = _editedProfile.region ?? '';
    _provinceController.text = _editedProfile.province ?? '';
    _cityController.text = _editedProfile.city ?? '';
    _barangayController.text = _editedProfile.barangay ?? '';
    _postalCodeController.text = _editedProfile.postalCode ?? '';
    _streetAddressController.text = _editedProfile.streetAddress ?? '';
    _emergencyNameController.text = _editedProfile.emergencyContactName ?? '';
    _emergencyPhoneController.text = _editedProfile.emergencyContactPhone ?? '';
    _emergencyRelationshipController.text =
        _editedProfile.emergencyContactRelationship ?? '';
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _profile = UserProfile(
          fullName: prefs.getString('full_name') ?? 'John Doe',
          email: prefs.getString('email') ?? 'user@example.com',
          phoneNumber: prefs.getString('phone_number'),
          region: prefs.getString('region'),
          province: prefs.getString('province'),
          city: prefs.getString('city'),
          barangay: prefs.getString('barangay'),
          postalCode: prefs.getString('postal_code'),
          streetAddress: prefs.getString('street_address'),
          emergencyContactName: prefs.getString('emergency_contact_name'),
          emergencyContactPhone: prefs.getString('emergency_contact_phone'),
          emergencyContactRelationship: prefs.getString(
            'emergency_contact_relationship',
          ),
          role: 'resident',
        );

        _editedProfile = _profile.copy();
        _updateControllersFromProfile();
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading profile: $error');
      setState(() {
        _isLoading = false;
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

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _profileImage = imagePath;
      _isUploading = false;
    });

    _showAlert('Success', 'Profile image updated successfully');
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

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('full_name', _editedProfile.fullName ?? '');
      await prefs.setString('phone_number', _editedProfile.phoneNumber ?? '');
      await prefs.setString('region', _editedProfile.region ?? '');
      await prefs.setString('province', _editedProfile.province ?? '');
      await prefs.setString('city', _editedProfile.city ?? '');
      await prefs.setString('barangay', _editedProfile.barangay ?? '');
      await prefs.setString('postal_code', _editedProfile.postalCode ?? '');
      await prefs.setString(
        'street_address',
        _editedProfile.streetAddress ?? '',
      );
      await prefs.setString(
        'emergency_contact_name',
        _editedProfile.emergencyContactName ?? '',
      );
      await prefs.setString(
        'emergency_contact_phone',
        _editedProfile.emergencyContactPhone ?? '',
      );
      await prefs.setString(
        'emergency_contact_relationship',
        _editedProfile.emergencyContactRelationship ?? '',
      );

      setState(() {
        _profile = _editedProfile.copy();
        _isEditing = false;
        _isLoading = false;
      });

      _showAlert('Success', 'Profile updated successfully');
    } catch (error) {
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

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile header: image left, name/email right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image
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
                                            .map(
                                              (n) => n.isNotEmpty ? n[0] : '',
                                            )
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
                      // Name and Email
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                decoration: InputDecoration(
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _profile.email ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profile.role == 'lgu_admin'
                                  ? 'LGU Admin'
                                  : 'Resident',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit Button on the right
                      IconButton(
                        onPressed: _isEditing ? _handleSave : _handleEdit,
                        icon: Icon(
                          _isEditing ? Icons.check : Icons.edit,
                          size: 22,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                    regionController: _regionController,
                    provinceController: _provinceController,
                    cityController: _cityController,
                    barangayController: _barangayController,
                    postalCodeController: _postalCodeController,
                    streetAddressController: _streetAddressController,
                    onRegionChanged: (value) =>
                        setState(() => _editedProfile.region = value),
                    onProvinceChanged: (value) =>
                        setState(() => _editedProfile.province = value),
                    onCityChanged: (value) =>
                        setState(() => _editedProfile.city = value),
                    onBarangayChanged: (value) =>
                        setState(() => _editedProfile.barangay = value),
                    onPostalCodeChanged: (value) =>
                        setState(() => _editedProfile.postalCode = value),
                    onStreetAddressChanged: (value) =>
                        setState(() => _editedProfile.streetAddress = value),
                    onCurrentLocation: () => _showAlert(
                      'Info',
                      'Current location feature would be implemented here',
                    ),
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
                  ActionButtons(
                    isEditing: _isEditing,
                    onCancel: _handleCancel,
                    onLogout: _handleLogout,
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
