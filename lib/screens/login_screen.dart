import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/login.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'profile_completion_screen.dart';
import 'email_verification_screen.dart';

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
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '927012189317-ljjmpf3d0c4ssatebm8sv3ht0rt9eml3.apps.googleusercontent.com',
  );

  bool _showPassword = false;
  bool _isLoading    = false;
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

  Future<void> _checkAutoLogin() async {
    if (!mounted) return;
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!mounted) return;
      if (isLoggedIn) {
        final userData = await _authService.getUserData();
        if (!mounted) return;
        if (userData != null) {
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
      // ignore auto-login errors
    }
  }

  Future<void> _postLoginSetup() async {
    await NotificationService.postLoginSetup();
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
      _emailError   = null;
      _passwordError = null;
      _generalError  = null;
    });

    bool isValid = true;

    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      isValid = false;
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      isValid = false;
    }

    return isValid;
  }

  Future<void> _handleLogin() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading     = true;
      _generalError  = null;
    });

    try {
      // Sign in with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );

      final firebaseUser = userCredential.user!;

      // Check email verification — route to the waiting screen (keeps session alive
      // so the user can resend the link and we can auto-detect verification).
      if (!firebaseUser.emailVerified) {
        await firebaseUser.sendEmailVerification();
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim().toLowerCase(),
            ),
          ),
        );
        return;
      }

      // Get Firebase ID token and exchange for backend JWT
      final idToken = await firebaseUser.getIdToken();
      if (!mounted) return;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body     = jsonDecode(response.body);
        final token    = body['token'] as String;
        final userData = Map<String, dynamic>.from(body['user'] as Map);

        await _authService.saveAuthData(token: token, userData: userData);
        await HiveService.setLoggedIn(true);
        await HiveService.saveUserSession(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(userData));
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', userData['email'] ?? '');
        await prefs.setString('userName',  userData['name'] ?? '');
        await prefs.setString('authProvider', 'email');

        await _postLoginSetup();
        if (!mounted) return;
        _showSuccessDialog(userData['name'] ?? 'User');
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _generalError = body['message'] ?? 'Sign in failed. Please try again.';
          _isLoading    = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email. Please sign up first.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled. Contact support.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = 'Sign in failed. Please try again.';
      }
      setState(() {
        _generalError = message;
        _isLoading    = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generalError = 'An error occurred. Check your connection and try again.';
        _isLoading    = false;
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
      _isLoading    = true;
      _generalError = null;
    });

    try {
      // Verify Google Play Services availability
      try {
        await _googleSignIn.isSignedIn();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _generalError = 'Please update Google Play Services on your device.';
          _isLoading    = false;
        });
        return;
      }

      // Fresh sign-in
      try { await _googleSignIn.signOut(); } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (!mounted) return;
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Link Google credentials to Firebase Auth
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken        = await userCredential.user?.getIdToken();

      if (idToken == null) {
        if (!mounted) return;
        setState(() {
          _generalError = 'Failed to get authentication token. Please try again.';
          _isLoading    = false;
        });
        return;
      }

      final authResponse = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (!mounted) return;

      if (authResponse.statusCode != 200) {
        final errBody = jsonDecode(authResponse.body);
        setState(() {
          _generalError = errBody['message'] ?? 'Google sign-in failed. Please try again.';
          _isLoading    = false;
        });
        return;
      }

      final authBody  = jsonDecode(authResponse.body);
      final token     = authBody['token'] as String;
      final userData  = Map<String, dynamic>.from(authBody['user'] as Map);
      final isNewUser = authBody['isNewUser'] as bool? ?? false;

      await _authService.saveAuthData(token: token, userData: userData);
      await HiveService.setLoggedIn(true);
      await HiveService.saveUserSession(userData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData',     jsonEncode(userData));
      await prefs.setBool('isLoggedIn',     true);
      await prefs.setString('userEmail',    userData['email'] ?? '');
      await prefs.setString('userName',     userData['name'] ?? '');
      await prefs.setString('authProvider', 'google');

      if (googleUser.photoUrl != null) {
        await prefs.setString('profile_image', googleUser.photoUrl!);
      }

      await _postLoginSetup();
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (isNewUser) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileCompletionScreen(
              token:    token,
              userData: userData,
            ),
          ),
        );
      } else {
        _navigateToHome();
      }
    } on PlatformException catch (e) {
      // Native Google Sign-In failures surface here (e.g. ApiException: 10).
      debugPrint('>>> Google sign-in PlatformException: code=${e.code} message=${e.message} details=${e.details}');
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'sign_in_failed':
          // Code 10 = DEVELOPER_ERROR → SHA-1 / OAuth client / google-services.json mismatch
          errorMessage = e.message?.contains('10') == true
              ? 'Google sign-in is not configured for this build (error 10). The app\'s SHA-1 fingerprint must be added in Firebase.'
              : 'Google sign-in failed (${e.message ?? e.code}).';
          break;
        case 'network_error':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        case 'sign_in_canceled':
          setState(() => _isLoading = false);
          return;
        default:
          errorMessage = 'Google sign-in failed: ${e.code}${e.message != null ? ' — ${e.message}' : ''}';
      }
      setState(() {
        _generalError = errorMessage;
        _isLoading    = false;
      });
    } on FirebaseAuthException catch (e) {
      debugPrint('>>> Google sign-in FirebaseAuthException: code=${e.code} message=${e.message}');
      if (!mounted) return;
      setState(() {
        _generalError = 'Firebase rejected the Google credential: ${e.code}. ${e.message ?? ''}';
        _isLoading    = false;
      });
    } catch (error) {
      debugPrint('>>> Google sign-in error: $error');
      if (!mounted) return;
      setState(() {
        _generalError = 'Google sign-in failed: ${error.toString().split('\n').first}';
        _isLoading    = false;
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
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      _showMessageDialog(
        'Reset Email Sent',
        'A password reset link has been sent to ${_emailController.text.trim()}. Check your inbox and follow the instructions.',
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'user-not-found'
          ? 'No account found with this email address.'
          : 'Failed to send reset email. Please try again.';
      _showMessageDialog('Error', message);
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
          if (!isSuccess && title == 'Error' && message.contains('No account found'))
            TextButton(
              onPressed: () { Navigator.pop(context); _handleSignUp(); },
              child: const Text('Sign Up'),
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
                        margin: const EdgeInsets.only(bottom: 8),
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
                      label:        'Email Address',
                      icon:         Icons.email_outlined,
                      controller:   _emailController,
                      errorText:    _emailError,
                      keyboardType: TextInputType.emailAddress,
                      isLoading:    _isLoading,
                      onChanged:    (value) => _clearError('email'),
                    ),
                    const SizedBox(height: 20),
                    PasswordInputField(
                      label:            'Password',
                      icon:             Icons.lock_outline,
                      controller:       _passwordController,
                      errorText:        _passwordError,
                      isLoading:        _isLoading,
                      showPassword:     _showPassword,
                      onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                      onChanged:        (value) => _clearError('password'),
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
                      children: const [
                        Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE5E7EB))),
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
