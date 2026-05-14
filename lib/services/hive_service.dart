import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static Box? _settingsBox;
  static Box? _sessionBox;
  static Box? _alertsBox;

  static Future<void> init() async {
    _settingsBox = Hive.box('settings');
    _sessionBox = Hive.box('user_session');
    _alertsBox = Hive.box('cached_alerts');
  }

  static bool isLoggedIn() {
    return _sessionBox?.get('isLoggedIn', defaultValue: false) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    await _sessionBox?.put('isLoggedIn', value);
  }

  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    await _sessionBox?.put('user', userData);
    await _sessionBox?.put('isLoggedIn', true);
  }

  static Map<String, dynamic>? getUserSession() {
    final user = _sessionBox?.get('user');
    if (user is Map<String, dynamic>) {
      return user;
    }
    return null;
  }

  static Future<void> clearSession() async {
    await _sessionBox?.clear();
  }

  static Future<void> cacheAlerts(List<Map<String, dynamic>> alerts) async {
    try {
      await _alertsBox?.put('cached_alerts', alerts);
      await _alertsBox?.put('last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching alerts: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedAlerts() async {
    try {
      final dynamic cachedData = _alertsBox?.get('cached_alerts');
      
      if (cachedData == null) {
        return [];
      }
      
      if (cachedData is List) {
        final List<Map<String, dynamic>> result = [];
        for (final item in cachedData) {
          if (item is Map<String, dynamic>) {
            result.add(item);
          } else if (item is Map) {
            final Map<String, dynamic> converted = {};
            item.forEach((key, value) {
              converted[key.toString()] = value;
            });
            result.add(converted);
          }
        }
        return result;
      }
      
      return [];
    } catch (e) {
      print('Error getting cached alerts: $e');
      return [];
    }
  }

  static Future<DateTime?> getLastUpdated() async {
    final lastUpdated = _alertsBox?.get('last_updated');
    if (lastUpdated == null) return null;
    if (lastUpdated is String) {
      return DateTime.tryParse(lastUpdated);
    }
    return null;
  }

  static Future<void> clearCachedAlerts() async {
    await _alertsBox?.delete('cached_alerts');
    await _alertsBox?.delete('last_updated');
  }
}