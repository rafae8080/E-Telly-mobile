import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../widgets/sign_up.dart';
import '../services/api_service.dart';
import 'email_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onSignUpSuccess;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onBackPressed;

  const SignUpScreen({
    super.key,
    this.onSignUpSuccess,
    this.onLoginPressed,
    this.onBackPressed,
  });

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController         = TextEditingController();
  final _emailController        = TextEditingController();
  final _passwordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _streetDetailsController = TextEditingController();
  final _landmarkController     = TextEditingController();

  bool _showPassword        = false;
  bool _showConfirmPassword = false;
  bool _isLoading           = false;
  String? _selectedBarangay;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _barangayError;
  String? _streetDetailsError;

  bool _isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};,.<>/?`~\\]'))) return false;
    return true;
  }

  bool _validateForm() {
    bool isValid = true;
    final errors = <String, String?>{};

    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Name is required';
      isValid = false;
    }

    if (_emailController.text.trim().isEmpty) {
      errors['email'] = 'Email is required';
      isValid = false;
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text.trim())) {
      errors['email'] = 'Please enter a valid email';
      isValid = false;
    }

    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      errors['barangay'] = 'Please select your barangay in Antipolo City';
      isValid = false;
    }

    if (_streetDetailsController.text.trim().isEmpty) {
      errors['streetDetails'] = 'Street/Building details are required';
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      errors['password'] = 'Password is required';
      isValid = false;
    } else if (!_isStrongPassword(_passwordController.text)) {
      errors['password'] = 'Password must be 8+ characters with uppercase, lowercase, number, and special character';
      isValid = false;
    }

    if (_confirmPasswordController.text.isEmpty) {
      errors['confirmPassword'] = 'Please confirm your password';
      isValid = false;
    } else if (_passwordController.text != _confirmPasswordController.text) {
      errors['confirmPassword'] = 'Passwords do not match';
      isValid = false;
    }

    setState(() {
      _nameError            = errors['name'];
      _emailError           = errors['email'];
      _barangayError        = errors['barangay'];
      _streetDetailsError   = errors['streetDetails'];
      _passwordError        = errors['password'];
      _confirmPasswordError = errors['confirmPassword'];
    });

    return isValid;
  }

  Future<void> _handleSignUp() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);

    String fullAddress = _streetDetailsController.text.trim();
    if (_landmarkController.text.trim().isNotEmpty) {
      fullAddress += ' (Near: ${_landmarkController.text.trim()})';
    }
    fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

    UserCredential? userCredential;

    try {
      // Create Firebase user
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      // Send verification email
      await userCredential.user?.sendEmailVerification();

      // Get Firebase ID token (may be unverified — backend allows this for registration)
      final idToken = await userCredential.user?.getIdToken();

      // Register on backend
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'name':    _nameController.text.trim(),
          'address': fullAddress,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 202) {
        // Keep Firebase session active — waiting screen needs it
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim().toLowerCase(),
            ),
          ),
        );
        return;
      } else {
        final body = jsonDecode(response.body);
        await userCredential.user?.delete();
        _showErrorDialog(
          response.statusCode == 409 ? 'Account Exists' : 'Registration Failed',
          body['message'] ?? 'Failed to create account. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please sign in instead.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Please choose a stronger password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = 'Registration failed. Please try again.';
      }
      _showErrorDialog('Registration Failed', message);
    } catch (error) {
      // Clean up Firebase user if backend call failed
      try { await userCredential?.user?.delete(); } catch (_) {}
      _showErrorDialog('Registration Error', 'Please check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.red)),
          ],
        ),
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

  void _updateField(String field, String value) {
    setState(() {
      switch (field) {
        case 'name':          _nameError          = null; break;
        case 'email':         _emailError         = null; break;
        case 'streetDetails': _streetDetailsError = null; break;
        case 'password':      _passwordError      = null; break;
        case 'confirmPassword': _confirmPasswordError = null; break;
      }
    });
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: BarangayModal(
            barangays:         antipoloBarangays,
            selectedBarangay:  _selectedBarangay,
            onSelect:          _selectBarangay,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0.5,
        shadowColor: Colors.grey,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isLoading ? Colors.grey : Colors.black,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  if (widget.onBackPressed != null) {
                    widget.onBackPressed!();
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
        title: const Text('Create Account'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                InputField(
                  label:      'Full Name',
                  icon:       Icons.person_outline,
                  controller: _nameController,
                  fieldName:  'name',
                  errorText:  _nameError,
                  isLoading:  _isLoading,
                  onChanged:  _updateField,
                ),
                const SizedBox(height: 15),
                InputField(
                  label:        'Email Address',
                  icon:         Icons.mail_outline,
                  controller:   _emailController,
                  fieldName:    'email',
                  keyboardType: TextInputType.emailAddress,
                  errorText:    _emailError,
                  isLoading:    _isLoading,
                  onChanged:    _updateField,
                ),
                const SizedBox(height: 15),
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
                  onChanged:  _updateField,
                ),
                const SizedBox(height: 15),
                InputField(
                  label:     'Landmark (Optional)',
                  icon:      Icons.flag_outlined,
                  controller: _landmarkController,
                  fieldName:  'landmark',
                  hintText:   'e.g., Near Antipolo Cathedral, beside SM Cherry',
                  isLoading:  _isLoading,
                  isRequired: false,
                  onChanged:  (field, value) {},
                ),
                const SizedBox(height: 15),
                InputField(
                  label:            'Password',
                  icon:             Icons.lock_outline,
                  controller:       _passwordController,
                  fieldName:        'password',
                  isPassword:       true,
                  showPassword:     _showPassword,
                  onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                  errorText:        _passwordError,
                  isLoading:        _isLoading,
                  onChanged:        _updateField,
                ),
                const SizedBox(height: 15),
                InputField(
                  label:            'Confirm Password',
                  icon:             Icons.lock_outline,
                  controller:       _confirmPasswordController,
                  fieldName:        'confirmPassword',
                  isPassword:       true,
                  showPassword:     _showConfirmPassword,
                  onTogglePassword: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  errorText:        _confirmPasswordError,
                  isLoading:        _isLoading,
                  onChanged:        _updateField,
                ),
                const SizedBox(height: 25),
                SignUpButton(isLoading: _isLoading, onPressed: _handleSignUp),
                const SizedBox(height: 20),
                LoginLink(
                  isLoading: _isLoading,
                  onPressed: () {
                    if (widget.onLoginPressed != null) {
                      widget.onLoginPressed!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _streetDetailsController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }
}
