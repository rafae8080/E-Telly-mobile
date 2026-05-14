import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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
      final decoded = JwtDecoder.decode(token);
      return decoded['role'] as String?;
    } catch (e) {
      print('>>> AuthService getUserRole error: $e');
      return null;
    }
  }

  /// Returns the user's ID from the JWT token
  Future<String?> getUserId() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      final decoded = JwtDecoder.decode(token);
      return decoded['userId'] as String?;
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
}