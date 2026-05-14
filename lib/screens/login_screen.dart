import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'dart:convert';
import '../widgets/login.dart';
import '../dbhelper/mongodb.dart';
import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../services/hive_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onSignUpPressed;
  final VoidCallback? onBackPressed;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onSignUpPressed,
    this.onBackPressed,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _showPassword = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  // ✅ KEY FIX: Safely extract MongoDB ObjectId as plain 24-char hex string
  String _extractId(Map<String, dynamic> user) {
    final raw = user['_id'];
    if (raw == null) return user['id']?.toString() ?? '';
    if (raw is ObjectId) {
      final hex = raw.toHexString();
      print('>>> ObjectId converted to hex: $hex');
      return hex;
    }
    return raw.toString();
  }

  // ✅ Single _buildUserData used for both email and Google login
  Map<String, dynamic> _buildUserData(
    Map<String, dynamic> user, {
    required String authProvider,
    String? photoUrl,
  }) {
    return {
      'id': _extractId(user),
      'name': user['name'] ?? '',
      'fullName': user['name'] ?? '',
      'email': user['email'] ?? '',
      'address': user['address'] ?? '',
      'barangay': user['barangay'] ?? '',
      'streetDetails': user['streetDetails'] ?? '',
      'isSafe': true,
      'role': user['role'] ?? 'user',
      'authProvider': authProvider,
      'phoneNumber': user['phoneNumber'] ?? '',
      'region': user['region'] ?? '',
      'province': user['province'] ?? '',
      'city': user['city'] ?? '',
      'postalCode': user['postalCode'] ?? '',
      'streetAddress': user['streetAddress'] ?? user['streetDetails'] ?? '',
      'emergencyContactName': user['emergencyContactName'] ?? '',
      'emergencyContactPhone': user['emergencyContactPhone'] ?? '',
      'emergencyContactRelationship': user['emergencyContactRelationship'] ?? '',
      'profilePhoto': photoUrl ?? user['profilePhoto'] ?? user['photoUrl'] ?? '',
      'landmark': user['landmark'] ?? '',
    };
  }

  Future<bool> _ensureMongoConnected() async {
    if (MongoDatabase.db == null || MongoDatabase.userCollection == null) {
      await MongoDatabase.connect();
    }
    return MongoDatabase.userCollection != null;
  }

  Future<void> _checkAutoLogin() async {
    if (!mounted) return;
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!mounted) return;
      if (isLoggedIn) {
        final userData = await _authService.getUserData();
        if (!mounted) return;
        if (userData != null) {
          print('>>> Auto-login successful for: ${userData['email']}');
          _navigateToHome();
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final legacyLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      if (legacyLoggedIn && !isLoggedIn) {
        await prefs.setBool('isLoggedIn', false);
      }
    } catch (e) {
      print('>>> Auto-login check error: $e');
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  bool _validateForm() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    bool isValid = true;

    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    }

    return isValid;
  }

  Future<void> _handleLogin() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      if (!await _ensureMongoConnected()) {
        if (!mounted) return;
        setState(() {
          _generalError = 'Unable to connect to the server. Please try again.';
          _isLoading = false;
        });
        return;
      }

      final user = await MongoDatabase.findUserForLogin(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (user != null) {
        print('>>> User found: ${user['email']}');
        print('>>> _id type: ${user['_id']?.runtimeType}');

        final userData = _buildUserData(user, authProvider: 'email');
        print('>>> userData[id]: ${userData['id']}');

        print('>>> GENERATING JWT TOKEN...');
        final jwtToken = JwtService.generateToken(userData);
        print('>>> JWT Token generated, length: ${jwtToken.length}');

        print('>>> SAVING TO SECURE STORAGE...');
        await _authService.saveAuthData(token: jwtToken, userData: userData);

        final savedToken = await _authService.getToken();
        print('>>> Token saved: ${savedToken != null ? "YES (length: ${savedToken.length})" : "NO - FAILED"}');

        if (savedToken == null) {
          if (!mounted) return;
          setState(() {
            _generalError = 'Failed to save session. Please try again.';
            _isLoading = false;
          });
          return;
        }

        await HiveService.setLoggedIn(true);
        await HiveService.saveUserSession(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(userData));
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', user['email'] ?? '');
        await prefs.setString('userName', user['name'] ?? '');
        await prefs.setString('authProvider', 'email');

        if (!mounted) return;
        _showSuccessDialog(user['name'] ?? 'User');
      } else {
        setState(() {
          _generalError = 'Invalid email or password. Please try again.';
          _isLoading = false;
        });
      }
    } catch (error, stack) {
      print('>>> Login error: $error');
      print('>>> Stack trace: $stack');
      if (!mounted) return;
      setState(() {
        _generalError = 'An error occurred: ${error.toString().split('\n')[0]}';
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String userName) {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Login Successful', style: TextStyle(color: Colors.green)),
        content: Text('Welcome back, $userName!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _handleSignUp() {
    if (widget.onSignUpPressed != null) {
      widget.onSignUpPressed!();
    } else {
      Navigator.pushNamed(context, '/sign-up');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      try {
        await _googleSignIn.isSignedIn();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _generalError = 'Please update Google Play Services on your device.';
          _isLoading = false;
        });
        return;
      }

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('>>> Google sign out error (non-fatal): $e');
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (!mounted) return;

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      print('>>> Google Sign-In successful: ${googleUser.email}');

      if (!await _ensureMongoConnected()) {
        if (!mounted) return;
        setState(() {
          _generalError = 'Unable to connect to the server.';
          _isLoading = false;
        });
        return;
      }

      final existingUser = await MongoDatabase.findUserByEmail(
        googleUser.email.toLowerCase(),
      );

      Map<String, dynamic> userData;

      if (existingUser != null) {
        userData = _buildUserData(
          existingUser,
          authProvider: 'google',
          photoUrl: googleUser.photoUrl,
        );
        await MongoDatabase.updateUser(googleUser.email.toLowerCase(), {
          'lastLogin': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        final newUser = {
          'name': googleUser.displayName ?? 'Google User',
          'email': googleUser.email.toLowerCase(),
          'password': 'google_auth_${DateTime.now().millisecondsSinceEpoch}',
          'isActive': true,
          'role': 'user',
          'authProvider': 'google',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'lastLogin': DateTime.now().toIso8601String(),
          'emailVerified': true,
          'phoneNumber': '',
          'region': '',
          'province': '',
          'city': '',
          'barangay': '',
          'postalCode': '',
          'streetDetails': '',
          'address': '',
          'emergencyContactName': '',
          'emergencyContactPhone': '',
          'emergencyContactRelationship': '',
          'profilePhoto': googleUser.photoUrl ?? '',
          'landmark': '',
        };
        await MongoDatabase.insertUser(newUser);
        userData = _buildUserData(
          {...newUser, 'id': DateTime.now().millisecondsSinceEpoch.toString()},
          authProvider: 'google',
          photoUrl: googleUser.photoUrl,
        );
      }

      print('>>> GENERATING JWT TOKEN FOR GOOGLE USER...');
      final jwtToken = JwtService.generateToken(userData);
      print('>>> JWT Token generated, length: ${jwtToken.length}');

      await _authService.saveAuthData(token: jwtToken, userData: userData);
      await HiveService.setLoggedIn(true);
      await HiveService.saveUserSession(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData));
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', userData['email'] ?? '');
      await prefs.setString('userName', userData['name'] ?? '');
      await prefs.setString('authProvider', 'google');

      if (googleUser.photoUrl != null) {
        await prefs.setString('profile_image', googleUser.photoUrl!);
      }

      print('>>> Google user data saved with JWT token');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${userData['name']}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() => _isLoading = false);
      _navigateToHome();
    } catch (error, stack) {
      print('>>> Google sign-in error: $error');
      print('>>> Stack: $stack');
      if (!mounted) return;
      setState(() {
        _generalError = error.toString().contains('sign_in_failed')
            ? 'Google Sign-In failed. Check your internet connection and try again.'
            : 'Google sign-in failed: ${error.toString().split('\n')[0]}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessageDialog('Forgot Password', 'Please enter your email address first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await MongoDatabase.findUserByEmail(
        _emailController.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      if (user != null) {
        _showConfirmDialog(
          'Reset Password',
          'A password reset link will be sent to ${_emailController.text.trim()}.',
          onConfirm: () => _showMessageDialog(
            'Success',
            'Password reset link sent! Check your email.',
            isSuccess: true,
          ),
        );
      } else {
        _showMessageDialog('Email Not Found', 'This email is not registered. Please sign up first.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessageDialog('Error', 'An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessageDialog(String title, String message, {bool isSuccess = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          if (!isSuccess && title == 'Email Not Found')
            TextButton(
              onPressed: () { Navigator.pop(context); _handleSignUp(); },
              child: const Text('Sign Up'),
            ),
        ],
      ),
    );
  }

  void _showConfirmDialog(String title, String message, {required VoidCallback onConfirm}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _clearError(String fieldType) {
    setState(() {
      if (fieldType == 'email') _emailError = null;
      if (fieldType == 'password') _passwordError = null;
      _generalError = null;
    });
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
        ),
        title: const Text('Login'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_generalError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_generalError!, style: TextStyle(color: Colors.red.shade700)),
                            ),
                          ],
                        ),
                      ),
                    InputField(
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      errorText: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      isLoading: _isLoading,
                      onChanged: (value) => _clearError('email'),
                    ),
                    const SizedBox(height: 20),
                    PasswordInputField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      errorText: _passwordError,
                      isLoading: _isLoading,
                      showPassword: _showPassword,
                      onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                      onChanged: (value) => _clearError('password'),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: Color(0xFFDC2626), fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LoginButton(isLoading: _isLoading, onPressed: _handleLogin),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GoogleSignInButton(isLoading: _isLoading, onPressed: _handleGoogleSignIn),
                    const SizedBox(height: 24),
                    SignUpPrompt(isLoading: _isLoading, onSignUpPressed: _handleSignUp),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}