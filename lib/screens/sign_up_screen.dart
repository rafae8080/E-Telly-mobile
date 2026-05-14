import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sign_up.dart';
import '../dbhelper/mongodb.dart';
import 'home_screen.dart';

// Antipolo City specific barangays (Updated)
final List<Map<String, String>> antipoloBarangays = [
  {'id': 'mayamot', 'name': 'Mayamot', 'value': 'Mayamot'},
  {'id': 'munting_dilaw', 'name': 'Munting Dilaw', 'value': 'Munting Dilaw'},
  {'id': 'san_jose', 'name': 'San Jose', 'value': 'San Jose'},
  {'id': 'san_luis', 'name': 'San Luis', 'value': 'San Luis'},
];

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
  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _streetDetailsController = TextEditingController();
  final _landmarkController = TextEditingController();

  // State variables
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _selectedBarangay;

  // Validation errors
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _barangayError;
  String? _streetDetailsError;

  bool _validateForm() {
    bool isValid = true;
    final errors = <String, String?>{};

    // Name validation
    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Name is required';
      isValid = false;
    }

    // Email validation
    if (_emailController.text.trim().isEmpty) {
      errors['email'] = 'Email is required';
      isValid = false;
    } else if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      errors['email'] = 'Please enter a valid email';
      isValid = false;
    }

    // Barangay validation - Check against Antipolo barangays
    if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
      errors['barangay'] = 'Please select your barangay in Antipolo City';
      isValid = false;
    } else if (!antipoloBarangays.any((b) => b['value'] == _selectedBarangay!.trim())) {
      errors['barangay'] = 'Please select a valid barangay in Antipolo City';
      isValid = false;
    }

    // Street Details validation
    if (_streetDetailsController.text.trim().isEmpty) {
      errors['streetDetails'] = 'Street/Building details are required';
      isValid = false;
    }

    // Password validation
    if (_passwordController.text.trim().isEmpty) {
      errors['password'] = 'Password is required';
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      errors['password'] = 'Password must be at least 6 characters';
      isValid = false;
    }

    // Confirm password validation
    if (_confirmPasswordController.text.trim().isEmpty) {
      errors['confirmPassword'] = 'Please confirm your password';
      isValid = false;
    } else if (_passwordController.text != _confirmPasswordController.text) {
      errors['confirmPassword'] = 'Passwords do not match';
      isValid = false;
    }

    setState(() {
      _nameError = errors['name'];
      _emailError = errors['email'];
      _barangayError = errors['barangay'];
      _streetDetailsError = errors['streetDetails'];
      _passwordError = errors['password'];
      _confirmPasswordError = errors['confirmPassword'];
    });

    return isValid;
  }

  Future<void> _handleSignUp() async {
    print('SIGN UP BUTTON PRESSED');
    print('Name: ${_nameController.text}');
    print('Email: ${_emailController.text}');
    print('Barangay: $_selectedBarangay');
    
    if (!_validateForm()) {
      print('Validation failed');
      return;
    }
    
    print('Validation passed');

    setState(() {
      _isLoading = true;
    });

    try {
      print('Checking if email exists...');
      var existingUser = await MongoDatabase.findUserByEmail(
        _emailController.text.trim().toLowerCase()
      );
      
      if (existingUser != null) {
        print('Email already exists');
        _showErrorDialog(
          'Email Already Registered',
          'This email is already registered. Please use a different email or sign in.'
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('Preparing user data...');
      String fullAddress = _streetDetailsController.text.trim();
      if (_landmarkController.text.trim().isNotEmpty) {
        fullAddress += ' (Near: ${_landmarkController.text.trim()})';
      }
      fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
        'address': fullAddress,
        'barangay': _selectedBarangay!.trim(),
        'streetDetails': _streetDetailsController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'region': 'CALABARZON (Region IV-A)',
        'province': 'Rizal',
        'city': 'Antipolo City',
        'postalCode': '1870',
        'isActive': true,
        'role': 'resident',
        'createdAt': DateTime.now().toIso8601String(),
        'emailVerified': false,
      };

      print('Inserting user to MongoDB...');
      bool success = await MongoDatabase.insertUser(userData);

      if (success) {
        print('User inserted successfully');
        
        // Save user data to SharedPreferences
        await _saveUserDataToPreferences();
        
        // Show success message first
        await _showSuccessMessageAndAutoSignIn();
        
      } else {
        print('Failed to insert user');
        _showErrorDialog(
          'Registration Failed',
          'Failed to create account. Please try again.'
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Signup error: $error');
      print('Stack trace: ${StackTrace.current}');
      _showErrorDialog(
        'Registration Error',
        'Error: ${error.toString()}\n\nPlease check your internet connection and try again.'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSuccessMessageAndAutoSignIn() async {
    String fullAddress = _streetDetailsController.text.trim();
    if (_landmarkController.text.trim().isNotEmpty) {
      fullAddress += ' (Near: ${_landmarkController.text.trim()})';
    }
    fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

    // Show success dialog with auto-sign in message
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text(
              'Successful!',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to E-Telly!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Name: ${_nameController.text.trim()}'),
            Text('Email: ${_emailController.text.trim()}'),
            Text('Barangay: ${_selectedBarangay!.trim()}'),
            Text('Address: $fullAddress'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You will be automatically signed in to your account.',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _autoSignIn(); // Proceed with auto sign in
            },
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _autoSignIn() async {
    try {
      print('Auto signing in user...');
      setState(() {
        _isLoading = true;
      });
      
      // Save login state using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', _emailController.text.trim().toLowerCase());
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setString('userRole', 'resident');
      
      print('Auto sign in successful');
      
      // Show snackbar message before navigating
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Signed in successfully! Redirecting...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Wait a moment for snackbar to show
        await Future.delayed(const Duration(seconds: 1));
        
        // Navigate to home screen directly and remove all previous routes
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
      
    } catch (e) {
      print('Auto sign in error: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(
        'Auto Sign In Failed',
        'Account created successfully but auto sign in failed. Please login manually.'
      );
    }
  }

  Future<void> _saveUserDataToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('full_name', _nameController.text.trim());
      await prefs.setString('email', _emailController.text.trim().toLowerCase());
      await prefs.setString('phone_number', ''); 
      await prefs.setString('region', 'CALABARZON (Region IV-A)');
      await prefs.setString('province', 'Rizal'); 
      await prefs.setString('city', 'Antipolo City'); 
      await prefs.setString('barangay', _selectedBarangay!.trim());
      await prefs.setString('postal_code', '1870'); 
      await prefs.setString('street_address', _streetDetailsController.text.trim());
      await prefs.setString('landmark', _landmarkController.text.trim());
      await prefs.setString('emergency_contact_name', ''); 
      await prefs.setString('emergency_contact_phone', ''); 
      await prefs.setString('emergency_contact_relationship', ''); 
      await prefs.setString('role', 'resident');
      await prefs.setString('userEmail', _emailController.text.trim().toLowerCase());
      
      print('User data saved to SharedPreferences successfully!');
      print('Name: ${_nameController.text.trim()}');
      print('Email: ${_emailController.text.trim().toLowerCase()}');
      
    } catch (error) {
      print('Error saving to SharedPreferences: $error');
    }
  }

  void _showErrorDialog(String title, String message) {
    setState(() {
      _isLoading = false;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Error',
              style: TextStyle(color: Colors.red),
            ),
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
        case 'name':
          _nameError = null;
          break;
        case 'email':
          _emailError = null;
          break;
        case 'streetDetails':
          _streetDetailsError = null;
          break;
        case 'password':
          _passwordError = null;
          break;
        case 'confirmPassword':
          _confirmPasswordError = null;
          break;
      }
    });
  }

  void _selectBarangay(String barangay) {
    setState(() {
      _selectedBarangay = barangay;
      _barangayError = null;
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => BarangayModal(
        barangays: antipoloBarangays,
        selectedBarangay: _selectedBarangay,
        onSelect: _selectBarangay,
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
                
                Column(
                  children: [
                    InputField(
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      controller: _nameController,
                      fieldName: 'name',
                      errorText: _nameError,
                      isLoading: _isLoading,
                      onChanged: _updateField,
                    ),
                    const SizedBox(height: 15),

                    InputField(
                      label: 'Email Address',
                      icon: Icons.mail_outline,
                      controller: _emailController,
                      fieldName: 'email',
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      isLoading: _isLoading,
                      onChanged: _updateField,
                    ),
                    const SizedBox(height: 15),

                    BarangaySelector(
                      selectedBarangay: _selectedBarangay,
                      barangayError: _barangayError,
                      isLoading: _isLoading,
                      onTap: _showBarangayBottomSheet,
                    ),
                    const SizedBox(height: 15),

                    InputField(
                      label: 'Street/Building Details',
                      icon: Icons.home_outlined,
                      controller: _streetDetailsController,
                      fieldName: 'streetDetails',
                      errorText: _streetDetailsError,
                      isLoading: _isLoading,
                      onChanged: _updateField,
                    ),
                    const SizedBox(height: 15),

                    InputField(
                      label: 'Landmark (Optional)',
                      icon: Icons.flag_outlined,
                      controller: _landmarkController,
                      fieldName: 'landmark',
                      hintText: 'e.g., Near Antipolo Cathedral, beside SM Cherry',
                      isLoading: _isLoading,
                      onChanged: (field, value) {},
                    ),
                    const SizedBox(height: 15),

                    InputField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      fieldName: 'password',
                      isPassword: true,
                      showPassword: _showPassword,
                      onTogglePassword: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      errorText: _passwordError,
                      isLoading: _isLoading,
                      onChanged: _updateField,
                    ),
                    const SizedBox(height: 15),

                    InputField(
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      controller: _confirmPasswordController,
                      fieldName: 'confirmPassword',
                      isPassword: true,
                      showPassword: _showConfirmPassword,
                      onTogglePassword: () {
                        setState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                      errorText: _confirmPasswordError,
                      isLoading: _isLoading,
                      onChanged: _updateField,
                    ),
                    const SizedBox(height: 25),

                    SignUpButton(
                      isLoading: _isLoading,
                      onPressed: _handleSignUp,
                    ),
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