// lib/services/alert_service.dart
import 'package:e_telly_app/dbhelper/mongodb.dart';
import 'package:e_telly_app/services/hive_service.dart';

class AlertService {
  
  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    try {
      print('Fetching alerts directly from MongoDB...');
      
      if (!MongoDatabase.isConnected) {
        print('MongoDB not connected, attempting to connect...');
        await MongoDatabase.connect();
      }
      
      final alerts = await MongoDatabase.getAllAlerts();
      
      print('=== RAW ALERTS FROM MONGODB ===');
      print('Total alerts in collection: ${alerts.length}');
      
      // Print each alert's details
      for (var i = 0; i < alerts.length; i++) {
        print('Alert ${i+1}:');
        print('  Title: ${alerts[i]['title']}');
        print('  isActive: ${alerts[i]['isActive']}');
        print('  Type: ${alerts[i]['type']}');
        print('  Severity: ${alerts[i]['severity']}');
        print('  Source: ${alerts[i]['source']}');
        print('  ---');
      }
      
      if (alerts.isEmpty) {
        print('No alerts found in MongoDB');
        final cachedAlerts = await HiveService.getCachedAlerts();
        if (cachedAlerts.isNotEmpty) {
          print('Loading ${cachedAlerts.length} alerts from cache');
          return cachedAlerts;
        }
        return [];
      }
      
      final convertedAlerts = <Map<String, dynamic>>[];
      
      for (var alert in alerts) {
        final converted = _convertMongoAlert(alert);
        if (converted != null) {
          convertedAlerts.add(converted);
          print('Converted: ${converted['title']} - active: ${converted['active']} - type: ${converted['type']}');
        } else {
          print('Failed to convert alert: ${alert['title']}');
        }
      }
      
      print('=== CONVERTED ALERTS ===');
      print('Successfully converted ${convertedAlerts.length} alerts');
      
      await HiveService.cacheAlerts(convertedAlerts);
      
      return convertedAlerts;
    } catch (e) {
      print('Error fetching alerts: $e');
      final cachedAlerts = await HiveService.getCachedAlerts();
      if (cachedAlerts.isNotEmpty) {
        print('Returning ${cachedAlerts.length} cached alerts');
        return cachedAlerts;
      }
      return [];
    }
  }
  
  Map<String, dynamic>? _convertMongoAlert(Map<String, dynamic> mongoAlert) {
    try {
      // Extract ID
      String id = mongoAlert['_id'].toString();
      if (id.contains('ObjectId')) {
        final match = RegExp(r'[a-fA-F0-9]{24}').firstMatch(id);
        if (match != null) id = match.group(0)!;
      }
      
      // Map severity
      String severity = 'moderate';
      String rawSeverity = mongoAlert['severity'] ?? 'watch';
      switch (rawSeverity) {
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
        default:
          severity = 'moderate';
      }
      
      // Map type
      String type = mongoAlert['type'] ?? 'other';
      String mappedType = 'other';
      switch (type) {
        case 'flood': 
          mappedType = 'flood'; 
          break;
        case 'river': 
          mappedType = 'water_level'; 
          break;
        case 'rainfall': 
          mappedType = 'rain'; 
          break;
        case 'evacuate': 
          mappedType = 'evacuate'; 
          break;
        case 'earthquake': 
          mappedType = 'earthquake'; 
          break;
        case 'typhoon': 
          mappedType = 'typhoon'; 
          break;
        case 'volcano': 
          mappedType = 'volcano'; 
          break;
        default:
          mappedType = 'other';
      }
      
      // Format barangays
      List<String> barangays = List<String>.from(mongoAlert['barangays'] ?? []);
      String barangayText = barangays.isNotEmpty 
          ? barangays.join(', ')
          : mongoAlert['location'] ?? 'Antipolo City';
      
      // Handle createdAt (DateTime or String)
      DateTime createdAt;
      final createdAtRaw = mongoAlert['createdAt'];
      if (createdAtRaw is DateTime) {
        createdAt = createdAtRaw;
      } else if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
      
      String timeAgo = _timeAgo(createdAt);
      
      // Extract water level
      String? waterLevel = _extractWaterLevel(mongoAlert['description'] ?? '');
      
      // Get active status
      bool isActive = mongoAlert['isActive'] ?? true;
      
      return {
        'id': id,
        'type': mappedType,
        'title': mongoAlert['title'] ?? 'Alert',
        'message': mongoAlert['description'] ?? 'No description provided',
        'barangay': barangayText,
        'timestamp': timeAgo,
        'severity': severity,
        'active': isActive,
        'read': false,
        'waterLevel': waterLevel,
        'evacuationCenter': null,
        'source': mongoAlert['source'] ?? 'system',
        'location': mongoAlert['location'] ?? '',
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': mongoAlert['expiresAt'] is DateTime 
            ? (mongoAlert['expiresAt'] as DateTime).toIso8601String()
            : mongoAlert['expiresAt'] as String?,
      };
    } catch (e) {
      print('Error converting alert: $e');
      print('Alert data: $mongoAlert');
      return null;
    }
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
    return null;
  }
  
  Future<bool> dismissAlert(String alertId) async {
    try {
      if (!MongoDatabase.isConnected) {
        await MongoDatabase.connect();
      }
      return await MongoDatabase.dismissAlert(alertId);
    } catch (e) {
      print('Error dismissing alert: $e');
      return false;
    }
  }
}