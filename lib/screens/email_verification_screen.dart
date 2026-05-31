import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _resendCooldown;
  int _resendCooldownSeconds = 0;
  bool _isChecking  = false;
  bool _isSending   = false;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-check every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _autoCheck());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendCooldown?.cancel();
    // Sign out of Firebase when leaving this screen without completing verification
    FirebaseAuth.instance.signOut().catchError((_) {});
    super.dispose();
  }

  Future<void> _autoCheck() async {
    if (_isLoggingIn) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _pollTimer?.cancel();
      await _completeLogin();
    }
  }

  Future<void> _onIveVerified() async {
    setState(() { _isChecking = true; _errorMessage = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'Session expired. Please sign in again.');
        return;
      }
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        _pollTimer?.cancel();
        await _completeLogin();
      } else {
        setState(() => _errorMessage = 'Email not verified yet. Check your inbox and click the link.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not check status. Try again.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _completeLogin() async {
    if (!mounted) return;
    setState(() => _isLoggingIn = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken(true);

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

        final authService = AuthService();
        await authService.saveAuthData(token: token, userData: userData);
        await HiveService.setLoggedIn(true);
        await HiveService.saveUserSession(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData',     jsonEncode(userData));
        await prefs.setBool('isLoggedIn',     true);
        await prefs.setString('userEmail',    userData['email'] ?? '');
        await prefs.setString('userName',     userData['name'] ?? '');
        await prefs.setString('authProvider', 'email');

        await NotificationService.postLoginSetup();
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _errorMessage = body['message'] ?? 'Login failed. Please try again.';
          _isLoggingIn  = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred. Check your connection and try again.';
        _isLoggingIn  = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    if (_resendCooldownSeconds > 0) return;
    setState(() { _isSending = true; _errorMessage = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'Session expired. Please sign in again.');
        return;
      }
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'too-many-requests') {
        setState(() => _errorMessage = 'Too many requests. Please wait a moment before resending.');
        _startResendCooldown();
      } else {
        setState(() => _errorMessage = 'Failed to send email. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to send email. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCooldownSeconds--;
        if (_resendCooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _isChecking || _isSending || _isLoggingIn;

    return WillPopScope(
      onWillPop: () async {
        await FirebaseAuth.instance.signOut().catchError((_) {});
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: true,
          elevation: 0.5,
          shadowColor: Colors.grey,
          backgroundColor: Colors.white,
          title: const Text('Verify Your Email'),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.mark_email_unread_outlined, size: 72, color: Color(0xFFDC2626)),
                const SizedBox(height: 24),
                const Text(
                  'Check your inbox',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to\n${widget.email}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click the link in the email, then tap the button below.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null)
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
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Primary action: I've verified
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: busy ? null : _onIveVerified,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor:     Colors.transparent,
                      minimumSize:     const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isChecking || _isLoggingIn
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            "I've Verified My Email",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend
                OutlinedButton.icon(
                  onPressed: (busy || _resendCooldownSeconds > 0) ? null : _resendEmail,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend in ${_resendCooldownSeconds}s'
                        : 'Resend verification email',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checking automatically...',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
