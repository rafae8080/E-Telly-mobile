import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000'; // Change this
  final AuthService _authService = AuthService();
  
  // Make authenticated API requests
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
}