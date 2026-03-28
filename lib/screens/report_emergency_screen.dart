import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/custom_font.dart';
import '../widgets/report.dart';
import '../services/offline_report_storage.dart';

class ReportEmergencyScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const ReportEmergencyScreen({super.key, this.onBackPressed});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  String? _emergencyType;
  int _severity = 2;
  bool _isSubmitting = false;
  UserData _userData = UserData();
  bool _loading = true;
  final List<String> _images = [];
  bool _showAdditionalInfo = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();

  bool _hasInternet = true;
  bool _isCheckingInternet = true;
  
  final List<EmergencyType> _emergencyTypes = [
    EmergencyType(
      id: 'flood',
      title: 'Flood',
      icon: Icons.flood,
      typeColor: const Color(0xFF06B6D4),
    ),
    EmergencyType(
      id: 'storm-surge',
      title: 'Storm Surge',
      icon: Icons.water,
      typeColor: const Color(0xFF0EA5E9),
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
      id: 'typhoon',
      title: 'Typhoon',
      icon: Icons.cloud,
      typeColor: const Color(0xFF3B82F6),
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

  final List<SeverityLevel> _severityLevels = [
    SeverityLevel(
      level: 1,
      label: 'Low',
      description: 'Minor issue, no immediate danger',
      color: const Color(0xFF10B981),
    ),
    SeverityLevel(
      level: 2,
      label: 'Medium',
      description: 'Significant issue, monitor closely',
      color: const Color(0xFFF59E0B),
    ),
    SeverityLevel(
      level: 3,
      label: 'High',
      description: 'Urgent, immediate action needed',
      color: const Color(0xFFDC2626),
    ),
    SeverityLevel(
      level: 4,
      label: 'Critical',
      description: 'Life-threatening, immediate response',
      color: const Color(0xFFDC2626),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _CheckInternetConnection();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userData = UserData(
          fullName: prefs.getString('full_name'),
          address: prefs.getString('address'),
          phoneNumber: prefs.getString('phone_number'),
        );
        _loading = false;
      });
    } catch (error) {
      setState(() => _loading = false);
    }
  }

  // ADDED: Check internet connection
  Future<void> _CheckInternetConnection() async {
    setState(() => _isCheckingInternet = true);
    
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
      _isCheckingInternet = false;
    });
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _hasInternet = result != ConnectivityResult.none;
      });
      
      // If internet comes back, try to sync pending reports
      if (_hasInternet) {
        _syncPendingReports();
      }
    });
  }

  // ADDED: Sync pending reports
  Future<void> _syncPendingReports() async {
    final pendingCount = OfflineReportStorage.getPendingSyncCount();
    if (pendingCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syncing $pendingCount pending reports...'),
          duration: const Duration(seconds: 2),
        ),
      );
      await OfflineReportStorage.syncReportsToServer();
    }
  }

  // ADDED: View saved reports
  void _viewSavedReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedReportsScreen(),
      ),
    );
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
      _severity = 2;
      _images.clear();
      _showAdditionalInfo = false;
      _descriptionController.clear();
    });
  }

  // MODIFIED: Handle submit with offline support
  Future<void> _handleSubmit() async {
    if (_emergencyType == null) {
      _showAlert('Error', 'Please select an emergency type');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      // Create report object
      final report = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'emergencyType': _emergencyType,
        'severity': _severity,
        'severityLabel': _severityLevels.firstWhere(
          (s) => s.level == _severity,
          orElse: () => _severityLevels[1],
        ).label,
        'description': _descriptionController.text,
        'images': List<String>.from(_images),
        'userData': {
          'fullName': _userData.fullName,
          'address': _userData.address,
          'phoneNumber': _userData.phoneNumber,
        },
        'timestamp': DateTime.now().toIso8601String(),
        'date': DateTime.now().toString(),
        'synced': false,
        'hasInternet': _hasInternet,
      };
      
      // Save to offline storage
      await OfflineReportStorage.saveReport(report);
      
      // Show appropriate success message
      if (!_hasInternet) {
        _showOfflineSuccessDialog();
      } else {
        // If online, try to send immediately
        await _sendToServer(report);
        _showSuccessDialog();
      }
      
      // Reset form after successful save
      _resetForm();
      
    } catch (e) {
      _showAlert('Error', 'Failed to save report: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ADDED: Send to server (placeholder - implement your actual API call)
  Future<void> _sendToServer(Map<String, dynamic> report) async {
    // TODO: Implement your actual API call to MongoDB/backend
    // This is a placeholder - replace with your actual server logic
    print('Sending report to server: $report');
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mark as synced if successful
    // In real implementation, you'd update the report in Hive
    // You can implement this in your sync method
  }

  // ADDED: Show offline success dialog
  void _showOfflineSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save, color: Colors.orange),
            SizedBox(width: 10),
            Text('Saved Offline'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ You are currently offline.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your emergency report has been saved locally. '
              'It will be automatically submitted when you reconnect to the internet.',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.orange.shade50,
              child: const Text(
                '💡 Tip: Enable internet connection to submit immediately.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _viewSavedReports();
              },
              child: const Text('View Saved Reports'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ADDED: Show online success dialog
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
        content: const Text(
          'Your emergency report has been submitted successfully. '
          'Authorities will be notified immediately.',
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

  // ADDED: Build offline warning banner
  Widget _buildOfflineWarning() {
    if (_hasInternet) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: const Text(
              'You are offline. Reports will be saved and submitted when internet is restored.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _viewSavedReports,
            child: const Text('View Pending'),
          ),
        ],
      ),
    );
  }

  // ADDED: Build pending reports indicator
  Widget _buildPendingReportsIndicator() {
    final pendingCount = OfflineReportStorage.getPendingSyncCount();
    if (pendingCount == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$pendingCount report(s) pending sync. They will be submitted when online.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _viewSavedReports,
            child: const Text('View'),
          ),
        ],
      ),
    );
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
                CircleAvatar(backgroundColor: level.color, radius: 8),
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
              child: Text(
                _userData.address ?? 'Current Location',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
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
            // ADDED: Offline warning banner
            if (!_isCheckingInternet) _buildOfflineWarning(),
            
            // ADDED: Pending reports indicator
            if (!_isCheckingInternet) _buildPendingReportsIndicator(),
            
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
      
            _buildEmergencyTypeGrid(),
      
            // Disclaimer - show here only when no emergency type is selected
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
                    backgroundColor: _hasInternet 
                        ? const Color(0xFFDC2626) 
                        : Colors.orange,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasInternet ? Icons.send : Icons.save,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _hasInternet ? 'SUBMIT REPORT' : 'SAVE OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              // Disclaimer - show at bottom when emergency type is selected
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

// ADDED: Saved Reports Screen
class SavedReportsScreen extends StatelessWidget {
  const SavedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = OfflineReportStorage.getAllReports();
    final unsyncedCount = OfflineReportStorage.getPendingSyncCount();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
        backgroundColor: const Color(0xFFDC2626),
        actions: [
          if (unsyncedCount > 0)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing reports...')),
                );
                await OfflineReportStorage.syncReportsToServer();
                // Refresh the screen
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedReportsScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Reports'),
                  content: const Text('Are you sure you want to delete all saved reports?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await OfflineReportStorage.clearAllReports();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All reports cleared')),
                );
              }
            },
          ),
        ],
      ),
      body: reports.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No saved reports',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final isSynced = report['synced'] == true;
                
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSynced ? Colors.green : Colors.orange,
                      child: Icon(
                        isSynced ? Icons.check : Icons.pending,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      _getEmergencyTypeTitle(report['emergencyType']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Severity: ${report['severityLabel']}'),
                        Text(
                          'Date: ${DateTime.parse(report['timestamp']).toLocal()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (!isSynced)
                          const Text(
                            '⚠️ Pending Sync',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await OfflineReportStorage.deleteReport(index);
                        // Refresh
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedReportsScreen(),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      _showReportDetails(context, report);
                    },
                  ),
                );
              },
            ),
    );
  }
  
  String _getEmergencyTypeTitle(String? id) {
    switch (id) {
      case 'flood': return 'Flood';
      case 'storm-surge': return 'Storm Surge';
      case 'rescue': return 'Rescue';
      case 'medical': return 'Medical';
      case 'typhoon': return 'Typhoon';
      case 'earthquake': return 'Earthquake';
      case 'fire': return 'Fire';
      case 'seawall': return 'Seawall';
      default: return 'Emergency Report';
    }
  }
  
  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getEmergencyTypeTitle(report['emergencyType'])),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Severity: ${report['severityLabel']}'),
              const SizedBox(height: 8),
              Text('Location: ${report['userData']['address'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              if (report['description'].isNotEmpty) ...[
                const Text('Description:'),
                Text(report['description']),
                const SizedBox(height: 8),
              ],
              Text('Time: ${report['timestamp']}'),
              const SizedBox(height: 8),
              if (report['synced'] == true)
                const Text('✅ Synced', style: TextStyle(color: Colors.green))
              else
                const Text('⚠️ Pending Sync', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}