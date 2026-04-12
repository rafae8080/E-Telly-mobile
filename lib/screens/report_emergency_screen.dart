import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/custom_font.dart';
import '../widgets/report.dart';
import '../dbhelper/mongodb.dart';

// Update UserData class to include email
class UserData {
  final String? fullName;
  final String? email;
  final String? address;
  final String? phoneNumber;
  
  UserData({
    this.fullName,
    this.email,
    this.address,
    this.phoneNumber,
  });
}

class ReportEmergencyScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const ReportEmergencyScreen({super.key, this.onBackPressed});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  String? _emergencyType;
  String _severity = 'Medium'; 
  bool _isSubmitting = false;
  UserData _userData = UserData();
  bool _loading = true;
  final List<String> _images = [];
  bool _showAdditionalInfo = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Location variables
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _exactAddress = '';
  String _street = '';
  String _barangay = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';
  
  final List<EmergencyType> _emergencyTypes = [
    EmergencyType(
      id: 'flood',
      title: 'Flood',
      icon: Icons.flood,
      typeColor: const Color(0xFF06B6D4),
    ),
    EmergencyType(
      id: 'rescue',
      title: 'Rescue',
      icon: Icons.emoji_people,
      typeColor: const Color(0xFF10B981),
    ),
    EmergencyType(
      id: 'medical',
      title: 'Medical',
      icon: Icons.medical_services,
      typeColor: const Color(0xFFDC2626),
    ),
    EmergencyType(
      id: 'earthquake',
      title: 'Earthquake',
      icon: Icons.warning,
      typeColor: const Color(0xFFF59E0B),
    ),
    EmergencyType(
      id: 'fire',
      title: 'Fire',
      icon: Icons.local_fire_department,
      typeColor: const Color(0xFFDC2626),
    ),
    EmergencyType(
      id: 'seawall',
      title: 'Seawall',
      icon: Icons.shield,
      typeColor: const Color(0xFF8B5CF6),
    ),
    EmergencyType(
      id: 'other',
      title: 'Other',
      icon: Icons.warning,
      typeColor: const Color(0xFF666666),
    ),
  ];

  // Added Severity Levels
  final List<SeverityLevel> _severityLevels = [
    SeverityLevel(
      level: 'Low',
      label: 'Low',
      description: 'Minor issue, no immediate danger',
      color: const Color(0xFF10B981),
    ),
    SeverityLevel(
      level: 'Medium',
      label: 'Medium',
      description: 'Significant issue, monitor closely',
      color: const Color(0xFFF59E0B),
    ),
    SeverityLevel(
      level: 'High',
      label: 'High',
      description: 'Urgent, immediate action needed',
      color: const Color(0xFFDC2626),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _connectToMongoDB();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _connectToMongoDB() async {
    try {
      await MongoDatabase.connect();
      print('MongoDB connection initialized');
    } catch (e) {
      print('Error connecting to MongoDB: $e');
    }
  }

  // Get severity color
  Color getSeverityColor(String severity) {
    switch (severity) {
      case 'Low': return const Color(0xFF10B981);
      case 'Medium': return const Color(0xFFF59E0B);
      case 'High': return const Color(0xFFDC2626);
      default: return const Color(0xFFF59E0B);
    }
  }

  // Request location permission and get current location with exact address
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      PermissionStatus permission = await Permission.location.request();
      
      if (permission.isGranted) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _locationError = 'Location services are disabled. Please enable GPS.';
            _isLoadingLocation = false;
          });
          return;
        }
        
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        
        setState(() {
          _currentPosition = position;
        });
        
        print('Location obtained: ${position.latitude}, ${position.longitude}');
        
        await _getExactAddress(position.latitude, position.longitude);
        
        setState(() {
          _isLoadingLocation = false;
        });
        
      } else if (permission.isDenied) {
        setState(() {
          _locationError = 'Location permission denied. Please enable location access.';
          _isLoadingLocation = false;
        });
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _locationError = 'Location permission permanently denied. Please enable from settings.';
          _isLoadingLocation = false;
        });
        openAppSettings();
      }
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
      print('Error getting location: $e');
    }
  }

  // Get exact address from coordinates
  Future<void> _getExactAddress(double latitude, double longitude) async {
    try {
      setState(() {
        _exactAddress = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
        _street = '';
        _barangay = '';
        _city = '';
        _province = '';
        _postalCode = '';
      });
      print('Exact address fallback: $_exactAddress');
    } catch (e) {
      print('Error getting exact address: $e');
      setState(() {
        _exactAddress = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
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
      imageQuality: 80,
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
      imageQuality: 80,
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
    
    if (_currentPosition == null && !_isLoadingLocation) {
      _showAlert('Location Error', 'Unable to get your location. Please enable GPS and try again.');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final report = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'emergencyType': _emergencyType,
        'severity': _severity,
        'description': _descriptionController.text,
        'images': List<String>.from(_images),
        'userData': {
          'fullName': _userData.fullName,
          'email': _userData.email,
          'address': _userData.address ?? _exactAddress,
          'phoneNumber': _userData.phoneNumber,
        },
        'location': {
          'type': 'Point',
          'coordinates': [
            _currentPosition?.longitude ?? 0.0,
            _currentPosition?.latitude ?? 0.0,
          ],
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'exactAddress': _exactAddress,
          'street': _street,
          'barangay': _barangay,
          'city': _city,
          'province': _province,
          'postalCode': _postalCode,
        },
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toString(),
      };
      
      await _sendToServer(report);
      _showSuccessDialog();
      _resetForm();
      
    } catch (e) {
      _showAlert('Error', 'Failed to save report: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendToServer(Map<String, dynamic> report) async {
    try {
      if (MongoDatabase.db == null) {
        await MongoDatabase.connect();
      }
      
      bool success = await MongoDatabase.saveEmergencyReport(report);
      
      if (!success) {
        throw Exception('Failed to save report to database');
      }
      
      print('Report successfully saved to MongoDB');
    } catch (e) {
      print('Error sending to server: $e');
      rethrow;
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
            const Text(
              'Your emergency report has been submitted successfully.',
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null && _exactAddress.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📍 EXACT LOCATION:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _exactAddress,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: getSeverityColor(_severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: getSeverityColor(_severity).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: getSeverityColor(_severity), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Severity Level: $_severity',
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold,
                      color: getSeverityColor(_severity),
                    ),
                  ),
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

  // Widget to show location status
  Widget _buildLocationStatus() {
    if (_isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Getting your location...'),
          ],
        ),
      );
    } else if (_locationError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, size: 18, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _locationError!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    } else if (_currentPosition != null && _exactAddress.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Location:',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    _exactAddress,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _getCurrentLocation,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? type.typeColor : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: type.typeColor,
                  radius: 18,
                  child: Icon(type.icon, size: 22, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  type.title,
                  style: const TextStyle(
                    fontSize: 10,
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

  // Build Severity Grid
  Widget _buildSeverityGrid() {
    return Column(
      children: _severityLevels.map((level) {
        final isSelected = _severity == level.level;
        return GestureDetector(
          onTap: () => setState(() => _severity = level.level),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? level.color : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: level.color, 
                  radius: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    level.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? level.color : Colors.black,
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
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryRow(
            label: 'Type:',
            value: Text(
              selectedEmergency.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          SummaryRow(
            label: 'Severity:',
            value: Text(
              selectedSeverity.label,
              style: TextStyle(
                color: selectedSeverity.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          SummaryRow(
            label: 'Location:',
            value: Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _exactAddress.isNotEmpty ? _exactAddress : (_userData.address ?? 'Getting location...'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (_currentPosition != null)
                    Text(
                      'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
          if (_descriptionController.text.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Description:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              _descriptionController.text,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_images.isNotEmpty) ...[
            const Divider(),
            Text(
              'Attachments: ${_images.length} image(s)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFDC2626).withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, size: 16, color: Color(0xFFDC2626)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This emergency report will be sent immediately to Navotas DRRMO emergency responders. '
              'False reports may result in legal action. In case of immediate danger, call 911 first.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF1F2937),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: CustomFont(
                text: 'What is your emergency?',
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            
            _buildLocationStatus(),
            const SizedBox(height: 12),
      
            _buildEmergencyTypeGrid(),
      
            if (_emergencyType == null) ...[
              const SizedBox(height: 16),
              _buildDisclaimer(),
            ],
      
            if (_emergencyType != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Select Severity Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSeverityGrid(),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () =>
                    setState(() => _showAdditionalInfo = !_showAdditionalInfo),
                child: Row(
                  children: [
                    Icon(
                      _showAdditionalInfo ?  Icons.expand_more : Icons.expand_less,
                    ),
                    const Text(
                      ' Additional Info (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (_showAdditionalInfo) ...[
                const SizedBox(height: 12),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                _buildDescriptionField(),
                const SizedBox(height: 12),
                const Text(
                  'Attach Photos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ImagePreviewList(images: _images, onRemove: _removeImage),
              ],
              const SizedBox(height: 20),
              const Text(
                'Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSummaryCard(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'SUBMIT REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDisclaimer(),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}