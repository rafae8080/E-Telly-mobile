// lib/services/alert_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class AlertService {
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    try {
      final url = Uri.parse('$API_BASE_URL$API_ALERTS_ENDPOINT');
      print('Fetching alerts from: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Received ${data.length} alerts from API');
        
        // Convert to your app's format
        final List<Map<String, dynamic>> convertedAlerts = [];
        for (var alert in data) {
          convertedAlerts.add(_convertAlert(alert));
        }
        return convertedAlerts;
      } else if (response.statusCode == 404) {
        print('❌ API endpoint not found. Make sure backend is running.');
        return [];
      } else {
        print('❌ Failed to load alerts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching alerts: $e');
      return [];
    }
  }

  Map<String, dynamic> _convertAlert(Map<String, dynamic> alert) {
    // Map severity
    String severity = 'moderate';
    switch (alert['severity']) {
      case 'evacuate':
      case 'critical':
        severity = 'critical';
        break;
      case 'warning':
        severity = 'high';
        break;
      case 'watch':
        severity = 'moderate';
        break;
    }

    // Map type
    String type = alert['type'] ?? 'other';
    if (type == 'flood') type = 'flood';
    else if (type == 'river') type = 'water_level';
    else if (type == 'rainfall') type = 'rain';
    else if (type == 'evacuate') type = 'evacuate';
    else if (type == 'earthquake') type = 'earthquake';
    else if (type == 'typhoon') type = 'typhoon';

    // Format barangays
    List<String> barangays = List<String>.from(alert['barangays'] ?? []);
    String barangayText = barangays.isNotEmpty 
        ? barangays.join(', ')
        : alert['location'] ?? 'Antipolo City';

    // Format timestamp
    DateTime createdAt = DateTime.tryParse(alert['createdAt'] ?? '') ?? DateTime.now();
    String timeAgo = _timeAgo(createdAt);

    // Extract water level from description
    String? waterLevel = _extractWaterLevel(alert['description'] ?? '');

    return {
      'id': alert['_id'] ?? alert['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'title': alert['title'] ?? 'Alert',
      'message': alert['description'] ?? 'No description provided',
      'barangay': barangayText,
      'timestamp': timeAgo,
      'severity': severity,
      'active': alert['isActive'] ?? true,
      'read': false,
      'waterLevel': waterLevel,
      'evacuationCenter': null,
      'source': alert['source'] ?? 'system',
      'location': alert['location'] ?? '',
      'createdAt': createdAt,
      'expiresAt': alert['expiresAt'] != null ? DateTime.tryParse(alert['expiresAt']) : null,
    };
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  String? _extractWaterLevel(String description) {
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|meter|meters)', caseSensitive: false),
      RegExp(r'water level:?\s*(\d+(?:\.\d+)?)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        return '${match.group(1)}m';
      }
    }
    
    if (description.toLowerCase().contains('rising')) return 'Rising';
    if (description.toLowerCase().contains('critical')) return 'Critical';
    return null;
  }

  Future<bool> dismissAlert(String alertId) async {
    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL$API_ALERTS_ENDPOINT/$alertId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error dismissing alert: $e');
      return false;
    }
  }
}