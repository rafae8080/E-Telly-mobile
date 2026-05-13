import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  static final _storage = FlutterSecureStorage();

  // ── Secure storage helpers ────────────────────────────────────────────────

  static Future<void> saveLoginData(Map<String, dynamic> response) async {
    final token = response['token'] as String;
    final user = response['user'] as Map<String, dynamic>;
    await Future.wait([
      _storage.write(key: 'auth_token', value: token),
      _storage.write(key: 'user_id', value: user['id']?.toString() ?? ''),
      _storage.write(key: 'user_name', value: user['name']?.toString() ?? ''),
      _storage.write(key: 'user_email', value: user['email']?.toString() ?? ''),
      _storage.write(key: 'user_role', value: user['role']?.toString() ?? ''),
    ]);
  }

  static Future<void> clearLoginData() async {
    await Future.wait([
      _storage.delete(key: 'auth_token'),
      _storage.delete(key: 'user_id'),
      _storage.delete(key: 'user_name'),
      _storage.delete(key: 'user_email'),
      _storage.delete(key: 'user_role'),
    ]);
  }

  static Future<Map<String, String?>> getStoredUser() async {
    final results = await Future.wait([
      _storage.read(key: 'auth_token'),
      _storage.read(key: 'user_name'),
      _storage.read(key: 'user_email'),
      _storage.read(key: 'user_id'),
      _storage.read(key: 'user_role'),
    ]);
    return {
      'auth_token': results[0],
      'user_name': results[1],
      'user_email': results[2],
      'user_id': results[3],
      'user_role': results[4],
    };
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
      };

  // Throws [AuthExpiredException] on 401 so callers can redirect to login.
  static void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      clearLoginData();
      throw AuthExpiredException();
    }
  }

  // ── Feature 1 — Authentication ────────────────────────────────────────────

  /// Returns the parsed response body on success.
  /// Throws [ApiException] with the server message on HTTP 400.
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw ApiException(body['message'] ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body;
    if (response.statusCode == 409) {
      throw ConflictException(
          body['message'] ?? 'An account with this email already exists.');
    }
    throw ApiException(body['message'] ?? 'Registration failed');
  }

  // ── Feature 2 — Emergency Reports ────────────────────────────────────────

  static Future<Map<String, dynamic>> submitReport(
      Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reports/create'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw ApiException(body['message'] ?? 'Failed to submit report');
  }

  // ── Feature 3 — Community Resource Sharing ───────────────────────────────

  static Future<Map<String, dynamic>> submitDonation(
      Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/community/donations'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body;
    throw ApiException(body['message'] ?? 'Failed to submit donation');
  }

  static Future<Map<String, dynamic>> submitRequest(
      Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/community/requests'),
      headers: _jsonHeaders(),
      body: jsonEncode(payload),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body;
    if (response.statusCode == 409) {
      throw ConflictException(
          body['message'] ?? 'You already have an active request in this category.');
    }
    throw ApiException(body['message'] ?? 'Failed to submit request');
  }

  static Future<List<dynamic>> getMyRequests() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/community/requests/mine'),
      headers: headers,
    );
    _checkUnauthorized(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (body['requests'] as List?) ?? [];
    }
    throw ApiException(body['message'] ?? 'Failed to load requests');
  }

  static Future<List<dynamic>> getMyDonations() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/community/donations/mine'),
      headers: headers,
    );
    _checkUnauthorized(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (body['donations'] as List?) ?? [];
    }
    throw ApiException(body['message'] ?? 'Failed to load donations');
  }

  static Future<void> cancelRequest(String id, {String note = ''}) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/community/requests/$id/cancel'),
      headers: headers,
      body: jsonEncode({'note': note}),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw ApiException(body['message'] ?? 'Failed to cancel request');
  }

  static Future<void> cancelDonation(String id, {String note = ''}) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/community/donations/$id/cancel'),
      headers: headers,
      body: jsonEncode({'note': note}),
    );
    _checkUnauthorized(response);
    if (response.statusCode == 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw ApiException(body['message'] ?? 'Failed to cancel donation');
  }

  static Future<List<dynamic>> fetchInventory(String barangayKey) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/inventory?barangay=$barangayKey'),
      headers: headers,
    );
    _checkUnauthorized(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (body['items'] as List?) ?? [];
    }
    throw ApiException(body['message'] ?? 'Failed to load inventory');
  }
}

// ── Exception types ───────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ConflictException extends ApiException {
  ConflictException(super.message);
}

class AuthExpiredException implements Exception {}
