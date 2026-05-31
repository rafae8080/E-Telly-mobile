import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Google Sign-in instance with your Web Client ID
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '927012189317-ljjmpf3d0c4ssatebm8sv3ht0rt9eml3.apps.googleusercontent.com',
  );

  /// Sign in with Google
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('>>> Google Sign-in cancelled by user');
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Here you would typically send the ID token to your backend
      // to create/authenticate the user and get your JWT token
      
      // For now, let's create a user data map from Google account
      final userData = {
        'userId': googleUser.id,
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'authProvider': 'google',
      };

      // If you have a backend that issues JWT tokens, you would call it here:
      // final response = await yourApiService.authenticateWithGoogle(googleAuth.idToken);
      // final jwtToken = response['token'];
      
      // For testing without backend, you might create a mock token
      // But in production, you should get a real JWT from your backend
      
      // Save auth data
      await saveAuthData(
        token: googleAuth.idToken ?? 'mock_token_for_testing',
        userData: userData,
      );

      print('>>> Google Sign-in successful for: ${googleUser.email}');
      return userData;
      
    } catch (e) {
      print('>>> Google Sign-in error: $e');
      return null;
    }
  }

  /// Sign out from Google and clear local storage
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await logout();
      print('>>> Signed out from Google and cleared local data');
    } catch (e) {
      print('>>> Google Sign-out error: $e');
    }
  }

  /// Saves JWT token and user data to secure storage
  Future<void> saveAuthData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _storage.write(key: _jwtTokenKey, value: token);
      await _storage.write(key: _userDataKey, value: jsonEncode(userData));
      await _storage.write(key: _isLoggedInKey, value: 'true');
      print('>>> AuthService: Auth data saved successfully');
    } catch (e) {
      print('>>> AuthService saveAuthData error: $e');
      rethrow;
    }
  }

  /// Returns the stored JWT token, or null if not found
  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _jwtTokenKey);
      print('>>> AuthService: getToken → ${token != null ? "found (length: ${token.length})" : "null"}');
      return token;
    } catch (e) {
      print('>>> AuthService getToken error: $e');
      return null;
    }
  }

  /// Returns true if user is logged in and token is still valid (not expired)
  Future<bool> isLoggedIn() async {
    try {
      final isLoggedIn = await _storage.read(key: _isLoggedInKey);
      if (isLoggedIn != 'true') {
        print('>>> AuthService: isLoggedIn flag is not set');
        return false;
      }

      final token = await getToken();
      if (token == null || token.isEmpty) {
        print('>>> AuthService: No token found');
        return false;
      }

      // For Google Sign-in with mock token, skip expiration check
      if (token == 'mock_token_for_testing') {
        print('>>> AuthService: Using mock token (testing mode)');
        return true;
      }

      // Validate token structure
      final parts = token.split('.');
      if (parts.length != 3) {
        print('>>> AuthService: Malformed token, clearing auth data');
        await logout();
        return false;
      }

      // Check expiry
      if (JwtDecoder.isExpired(token)) {
        print('>>> AuthService: Token expired, logging out');
        await logout();
        return false;
      }

      print('>>> AuthService: User is logged in with valid token');
      return true;
    } catch (e) {
      print('>>> AuthService isLoggedIn error: $e');
      // Clear potentially corrupted data
      await logout();
      return false;
    }
  }

  /// Returns stored user data as a Map, or null if not found
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userDataString = await _storage.read(key: _userDataKey);
      if (userDataString == null || userDataString.isEmpty) return null;
      return jsonDecode(userDataString) as Map<String, dynamic>;
    } catch (e) {
      print('>>> AuthService getUserData error: $e');
      return null;
    }
  }

  /// Returns the token expiration date, or null if unavailable
  Future<DateTime?> getTokenExpiration() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      // Skip for mock token
      if (token == 'mock_token_for_testing') return null;
      
      return JwtDecoder.getExpirationDate(token);
    } catch (e) {
      print('>>> AuthService getTokenExpiration error: $e');
      return null;
    }
  }

  /// Returns the user's role from the JWT token
  Future<String?> getUserRole() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      // Skip for mock token
      if (token == 'mock_token_for_testing') return 'user';
      
      final decoded = JwtDecoder.decode(token);
      return decoded['role'] as String?;
    } catch (e) {
      print('>>> AuthService getUserRole error: $e');
      return null;
    }
  }

  /// Returns the user's ID from the JWT token or stored user data.
  /// The server signs the claim as `id` (see signJwt in server/routes/auth.js)
  /// and the stored user payload also uses `id`; older code looked for
  /// `userId`, which never exists — leaving this null and breaking socket
  /// room joins and "is this my message" checks. Fall back across key names
  /// for safety.
  Future<String?> getUserId() async {
    try {
      // First try to get from token
      final token = await getToken();
      if (token != null && token != 'mock_token_for_testing') {
        final decoded = JwtDecoder.decode(token);
        return (decoded['id'] ?? decoded['userId'] ?? decoded['_id'])?.toString();
      }

      // If no token or mock token, get from user data
      final userData = await getUserData();
      return (userData?['id'] ?? userData?['userId'] ?? userData?['_id'])?.toString();
    } catch (e) {
      print('>>> AuthService getUserId error: $e');
      return null;
    }
  }

  /// Clears all auth data from secure storage (logout)
  Future<void> logout() async {
    try {
      await _storage.delete(key: _jwtTokenKey);
      await _storage.delete(key: _userDataKey);
      await _storage.delete(key: _isLoggedInKey);
      print('>>> AuthService: Logged out, auth data cleared');
    } catch (e) {
      print('>>> AuthService logout error: $e');
    }
  }

  /// Updates stored user data without changing the token
  Future<void> updateUserData(Map<String, dynamic> updatedUserData) async {
    try {
      await _storage.write(key: _userDataKey, value: jsonEncode(updatedUserData));
      print('>>> AuthService: User data updated');
    } catch (e) {
      print('>>> AuthService updateUserData error: $e');
      rethrow;
    }
  }

  /// Get the currently signed-in Google user (if any)
  GoogleSignInAccount? getCurrentGoogleUser() {
    return _googleSignIn.currentUser;
  }

  /// Silent sign-in with Google (no UI prompt)
  Future<GoogleSignInAccount?> silentSignInWithGoogle() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      print('>>> Silent Google sign-in error: $e');
      return null;
    }
  }
}