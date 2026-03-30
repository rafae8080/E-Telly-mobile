import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import '../widgets/login.dart';
import '../dbhelper/mongodb.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onSignUpPressed;
  final VoidCallback? onBackPressed;

  const LoginScreen({
    Key? key,
    this.onLoginSuccess,
    this.onSignUpPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool _showPassword = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (isLoggedIn) {
        String? authProvider = prefs.getString('authProvider');
        if (authProvider == 'google') {
          bool isSignedIn = await _googleSignIn.isSignedIn();
          if (isSignedIn) {
            GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
            if (googleUser != null) {
              print('Auto-login successful for: ${googleUser.email}');
              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Auto-login check error: $e');
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
    } else if (!emailRegex.hasMatch(_emailController.text)) {
      setState(() => _emailError = 'Please enter a valid email');
      isValid = false;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      isValid = false;
    }

    return isValid;
  }

  Future<void> _handleLogin() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      var user = await MongoDatabase.findUserForLogin(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );

      if (user != null) {
        print('User logged in: ${user['email']}');

        final userData = {
          'id': user['_id'].toString(),
          'name': user['name'] ?? '',
          'email': user['email'] ?? '',
          'address': user['address'] ?? '',
          'barangay': user['barangay'] ?? '',
          'streetDetails': user['streetDetails'] ?? '',
          'isSafe': true,
          'role': user['role'] ?? 'user',
          'authProvider': 'email',
        };

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(userData));
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', user['email']);
        await prefs.setString('userName', user['name']);
        await prefs.setString('authProvider', 'email');

        _showSuccessDialog(user['name'] ?? 'User');
      } else {
        setState(() {
          _generalError = 'Invalid email or password. Please try again.';
        });
      }
    } catch (error) {
      print('Login error: $error');
      setState(() {
        _generalError = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String userName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Login Successful',
          style: TextStyle(color: Colors.green),
        ),
        content: Text('Welcome back, $userName!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              }
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
      // Check if Google Play Services are available
      try {
        await _googleSignIn.isSignedIn();
      } catch (e) {
        print('Google Play Services check failed: $e');
        setState(() {
          _generalError = 'Please update Google Play Services on your device';
        });
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Sign out first to ensure fresh login
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Sign out error (ignored): $e');
      }

      // Attempt sign in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('✅ Google Sign-In successful!');
      print('   Email: ${googleUser.email}');
      print('   Name: ${googleUser.displayName}');
      print('   Photo: ${googleUser.photoUrl}');

      // Check if user already exists in MongoDB
      var existingUser = await MongoDatabase.findUserByEmail(googleUser.email.toLowerCase());

      Map<String, dynamic> userData;

      if (existingUser != null) {
        print('📱 Existing user found: ${existingUser['email']}');
        
        userData = {
          'id': existingUser['_id'].toString(),
          'name': existingUser['name'] ?? googleUser.displayName,
          'email': existingUser['email'],
          'address': existingUser['address'] ?? '',
          'barangay': existingUser['barangay'] ?? '',
          'streetDetails': existingUser['streetDetails'] ?? '',
          'isSafe': true,
          'role': existingUser['role'] ?? 'user',
          'photoUrl': googleUser.photoUrl,
          'authProvider': 'google',
        };
        
        // Update last login time
        await MongoDatabase.updateUser(googleUser.email.toLowerCase(), {
          'lastLogin': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        print('🆕 Creating new user for: ${googleUser.email}');
        
        Map<String, dynamic> newUser = {
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
        };

        bool created = await MongoDatabase.insertUser(newUser);

        if (created) {
          var createdUser = await MongoDatabase.findUserByEmail(googleUser.email.toLowerCase());
          userData = {
            'id': createdUser!['_id'].toString(),
            'name': createdUser['name'],
            'email': createdUser['email'],
            'address': createdUser['address'] ?? '',
            'barangay': createdUser['barangay'] ?? '',
            'streetDetails': createdUser['streetDetails'] ?? '',
            'isSafe': true,
            'role': createdUser['role'] ?? 'user',
            'photoUrl': googleUser.photoUrl,
            'authProvider': 'google',
          };
        } else {
          throw Exception('Failed to create user account');
        }
      }

      // Save user data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData));
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', userData['email']);
      await prefs.setString('userName', userData['name']);
      await prefs.setString('authProvider', 'google');
      
      if (googleUser.photoUrl != null) {
        await prefs.setString('profile_image', googleUser.photoUrl!);
      }

      print('✅ User data saved to SharedPreferences');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${userData['name']}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to home screen
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (error) {
      print('❌ Google sign-in error: $error');
      setState(() {
        if (error.toString().contains('sign_in_failed')) {
          _generalError = 'Google Sign-In failed. Please make sure:\n'
              '1. You have internet connection\n'
              '2. Google Play Services is updated\n'
              '3. Your Google account is valid';
        } else {
          _generalError = 'Google sign-in failed: ${error.toString().split('\n')[0]}';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessageDialog(
        'Forgot Password',
        'Please enter your email address first.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var user = await MongoDatabase.findUserByEmail(_emailController.text.trim().toLowerCase());

      if (user != null) {
        _showConfirmDialog(
          'Reset Password',
          'A password reset link will be sent to ${_emailController.text.trim()}.',
          onConfirm: () {
            _showMessageDialog(
              'Success',
              'Password reset link sent! Check your email.',
              isSuccess: true,
            );
          },
        );
      } else {
        _showMessageDialog(
          'Email Not Found',
          'This email is not registered. Please sign up first.',
        );
      }
    } catch (e) {
      _showMessageDialog(
        'Error',
        'An error occurred. Please try again.',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessageDialog(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (!isSuccess && title == 'Email Not Found')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleSignUp();
              },
              child: const Text('Sign Up'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _clearError(String fieldType) {
    setState(() {
      if (fieldType == 'email') {
        _emailError = null;
      } else if (fieldType == 'password') {
        _passwordError = null;
      }
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
                              child: Text(
                                _generalError!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
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
                      onTogglePassword: () =>
                          setState(() => _showPassword = !_showPassword),
                      onChanged: (value) => _clearError('password'),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LoginButton(isLoading: _isLoading, onPressed: _handleLogin),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GoogleSignInButton(
                      isLoading: _isLoading,
                      onPressed: _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 24),
                    SignUpPrompt(
                      isLoading: _isLoading,
                      onSignUpPressed: _handleSignUp,
                    ),
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