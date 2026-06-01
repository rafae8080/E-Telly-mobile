import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sign_up.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';
import 'home_screen.dart';
import 'terms_policy_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ProfileCompletionScreen({
    super.key,
    required this.token,
    required this.userData,
  });

  @override
  _ProfileCompletionScreenState createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _streetDetailsController = TextEditingController();
  final _landmarkController      = TextEditingController();

  String? _selectedBarangay;
  bool    _isLoading        = false;
  bool    _agreedToTerms    = false;
  String? _barangayError;
  String? _streetDetailsError;
  String? _termsError;

  bool _validateForm() {
    bool isValid = true;
    setState(() {
      _barangayError      = _selectedBarangay == null ? 'Please select your barangay' : null;
      _streetDetailsError = _streetDetailsController.text.trim().isEmpty
          ? 'Street/Building details are required'
          : null;
      _termsError         = _agreedToTerms
          ? null
          : 'You must agree to the Terms & Conditions and Privacy Policy to continue';
    });
    if (_barangayError != null || _streetDetailsError != null || _termsError != null) {
      isValid = false;
    }
    return isValid;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);

    String fullAddress = _streetDetailsController.text.trim();
    if (_landmarkController.text.trim().isNotEmpty) {
      fullAddress += ' (Near: ${_landmarkController.text.trim()})';
    }
    fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

    try {
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/auth/profile'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'address':       fullAddress,
          'termsAccepted': true,
          'termsVersion':  termsVersion,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updatedUser = Map<String, dynamic>.from(
          Map<String, dynamic>.from(jsonDecode(response.body)),
        );

        final mergedUser = {...widget.userData, ...updatedUser};

        final authService = AuthService();
        await authService.saveAuthData(token: widget.token, userData: mergedUser);
        await HiveService.saveUserSession(mergedUser);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(mergedUser));

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        final body = jsonDecode(response.body);
        _showError(body['message'] ?? 'Failed to save your details. Please try again.');
      }
    } catch (e) {
      _showError('Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _selectBarangay(String barangay) {
    setState(() {
      _selectedBarangay = barangay;
      _barangayError    = null;
    });
    Navigator.pop(context);
  }

  void _showBarangayBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: BarangayModal(
            barangays:        antipoloBarangays,
            selectedBarangay: _selectedBarangay,
            onSelect:         _selectBarangay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userData['name'] ?? 'there';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0.5,
        shadowColor: Colors.grey,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Complete Your Profile'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Welcome, $name!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter your address in Antipolo City to continue.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 28),
              BarangaySelector(
                selectedBarangay: _selectedBarangay,
                barangayError:    _barangayError,
                isLoading:        _isLoading,
                onTap:            _showBarangayBottomSheet,
              ),
              const SizedBox(height: 15),
              InputField(
                label:      'Street/Building Details',
                icon:       Icons.home_outlined,
                controller: _streetDetailsController,
                fieldName:  'streetDetails',
                errorText:  _streetDetailsError,
                isLoading:  _isLoading,
                onChanged:  (field, value) => setState(() => _streetDetailsError = null),
              ),
              const SizedBox(height: 15),
              InputField(
                label:      'Landmark (Optional)',
                icon:       Icons.flag_outlined,
                controller: _landmarkController,
                fieldName:  'landmark',
                hintText:   'e.g., Near Antipolo Cathedral, beside SM Cherry',
                isLoading:  _isLoading,
                isRequired: false,
                onChanged:  (field, value) {},
              ),
              const SizedBox(height: 24),
              TermsAgreement(
                value:      _agreedToTerms,
                isLoading:  _isLoading,
                errorText:  _termsError,
                onChanged:  (v) => setState(() {
                  _agreedToTerms = v;
                  _termsError    = null;
                }),
                onTapTerms: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsPolicyScreen()),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:      const Color(0xFFDC2626).withOpacity(0.3),
                      blurRadius: 10,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor:     Colors.transparent,
                    minimumSize:     const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width:  20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streetDetailsController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }
}
