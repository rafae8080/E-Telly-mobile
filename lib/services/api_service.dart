import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://e-telly-ca75b10e9536.herokuapp.com'; 
  final AuthService _authService = AuthService();
  

  Future<http.Response> authenticatedGet(String endpoint) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  /// GET that includes the token if available, but works without one.
  Future<http.Response> optionalGet(String endpoint) async {
    final token = await _authService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
  }
  
  Future<http.Response> authenticatedPost(String endpoint, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');
    
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
  }
  
  Future<http.Response> authenticatedPut(String endpoint, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
  }

  Future<http.Response> authenticatedPatch(String endpoint, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    return await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
  }

  Future<http.Response> authenticatedDelete(String endpoint, Map<String, dynamic> data) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
  }

  Future<void> refreshProfile() async {
    try {
      final response = await authenticatedGet('/api/auth/me');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await _authService.updateUserData(body);
      }
    } catch (_) {}
  }
}