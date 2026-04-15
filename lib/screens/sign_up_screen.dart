import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/sign_up.dart';
import '../dbhelper/mongodb.dart';

// Antipolo City specific barangays
final List<Map<String, String>> antipoloBarangays = [
  {'id': 'bagong_nayon', 'name': 'Bagong Nayon', 'value': 'Bagong Nayon'},
  {'id': 'beverly_hills', 'name': 'Beverly Hills', 'value': 'Beverly Hills'},
  {'id': 'calumpang', 'name': 'Calumpang', 'value': 'Calumpang'},
  {'id': 'cupang', 'name': 'Cupang', 'value': 'Cupang'},
  {'id': 'dalig', 'name': 'Dalig', 'value': 'Dalig'},
  {'id': 'dela_paz', 'name': 'Dela Paz', 'value': 'Dela Paz'},
  {'id': 'inarawan', 'name': 'Inarawan', 'value': 'Inarawan'},
  {'id': 'ligaya', 'name': 'Ligaya', 'value': 'Ligaya'},
  {'id': 'mambugan', 'name': 'Mambugan', 'value': 'Mambugan'},
  {'id': 'muntingdilaw', 'name': 'Muntingdilaw', 'value': 'Muntingdilaw'},
  {'id': 'san_isidro', 'name': 'San Isidro', 'value': 'San Isidro'},
  {'id': 'san_jose', 'name': 'San Jose', 'value': 'San Jose'},
  {'id': 'san_juan', 'name': 'San Juan', 'value': 'San Juan'},
  {'id': 'san_luis', 'name': 'San Luis', 'value': 'San Luis'},
  {'id': 'san_roque', 'name': 'San Roque', 'value': 'San Roque'},
  {'id': 'santa_cruz', 'name': 'Santa Cruz', 'value': 'Santa Cruz'},
  {'id': 'santa_elena', 'name': 'Santa Elena', 'value': 'Santa Elena'},
  {'id': 'taytay', 'name': 'Taytay', 'value': 'Taytay'},
  {'id': 'tumana', 'name': 'Tumana', 'value': 'Tumana'},
  {'id': 'villa_carissa', 'name': 'Villa Carissa', 'value': 'Villa Carissa'},
];

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onSignUpSuccess;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onBackPressed;

  const SignUpScreen({
    Key? key,
    this.onSignUpSuccess,
    this.onLoginPressed,
    this.onBackPressed,
  }) : super(key: key);

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
  final _landmarkController = TextEditingController(); // New for Antipolo

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
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if email already exists in MongoDB
      var existingUser = await MongoDatabase.findUserByEmail(
        _emailController.text.trim().toLowerCase()
      );
      
      if (existingUser != null) {
        _showErrorDialog(
          'Email Already Registered',
          'This email is already registered. Please use a different email or sign in.'
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Combine street details, landmark, and barangay into full address
      String fullAddress = _streetDetailsController.text.trim();
      if (_landmarkController.text.trim().isNotEmpty) {
        fullAddress += ' (Near: ${_landmarkController.text.trim()})';
      }
      fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

      // Prepare user data for MongoDB
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

      // Insert user to MongoDB
      bool success = await MongoDatabase.insertUser(userData);

      if (success) {
        // Save user data to SharedPreferences
        await _saveUserDataToPreferences();
        
        // Show success dialog
        _showSuccessDialog();
      } else {
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
      _showErrorDialog(
        'Registration Error',
        'An unexpected error occurred. Please try again.'
      );
      setState(() {
        _isLoading = false;
      });
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
      print('  Name: ${_nameController.text.trim()}');
      print('  Email: ${_emailController.text.trim().toLowerCase()}');
      print('  Barangay: ${_selectedBarangay!.trim()}');
      print('  Street: ${_streetDetailsController.text.trim()}');
      print('  Landmark: ${_landmarkController.text.trim()}');
      print('  Location: Antipolo City, Rizal');
      
    } catch (error) {
      print('Error saving to SharedPreferences: $error');
    }
  }

  void _showSuccessDialog() {
    String fullAddress = _streetDetailsController.text.trim();
    if (_landmarkController.text.trim().isNotEmpty) {
      fullAddress += ' (Near: ${_landmarkController.text.trim()})';
    }
    fullAddress += ', ${_selectedBarangay!.trim()}, Antipolo City, Rizal';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Registration Successful!',
          style: TextStyle(color: Colors.green),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to E-Telly, ${_nameController.text.trim()}!'),
            const SizedBox(height: 10),
            Text('Email: ${_emailController.text.trim()}'),
            Text('Location: Antipolo City'),
            Text('Barangay: ${_selectedBarangay!.trim()}'),
            Text('Address: $fullAddress'),
            const SizedBox(height: 15),
            const Text(
              'Please check your email to verify your account before signing in.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              if (widget.onSignUpSuccess != null) {
                widget.onSignUpSuccess!();
              } else if (widget.onLoginPressed != null) {
                widget.onLoginPressed!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Sign In',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    setState(() {
      _isLoading = false;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(color: Colors.red),
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
                    // Name
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

                    // Email
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

                    // Barangay Selector (Antipolo Barangays)
                    BarangaySelector(
                      selectedBarangay: _selectedBarangay,
                      barangayError: _barangayError,
                      isLoading: _isLoading,
                      onTap: _showBarangayBottomSheet,
                    ),
                    const SizedBox(height: 15),

                    // Street Details
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

                    // Landmark (New for Antipolo)
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

                    // Password
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

                    // Confirm Password
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

                    // Sign Up Button
                    SignUpButton(
                      isLoading: _isLoading,
                      onPressed: _handleSignUp,
                    ),
                    const SizedBox(height: 20),

                    // Login Link
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