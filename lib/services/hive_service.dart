import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static Box? _settingsBox;
  static Box? _sessionBox;
  static Box? _alertsBox;
  static Box? _evacuationCentersBox;
  static Box? _evacuationRoutesBox;
  static Box? _communityReportsBox;

  static Future<void> init() async {
    _settingsBox = Hive.box('settings');
    _sessionBox = Hive.box('user_session');
    _alertsBox = Hive.box('cached_alerts');
    _evacuationCentersBox = Hive.box('cached_evacuation_centers');
    _evacuationRoutesBox = Hive.box('cached_evacuation_routes');
    _communityReportsBox = Hive.box('cached_community_reports');
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

  // ── Evacuation Centers ────────────────────────────────────────────────────

  static Future<void> cacheEvacuationCenters(List<Map<String, dynamic>> centers) async {
    try {
      await _evacuationCentersBox?.put('data', centers);
      await _evacuationCentersBox?.put('last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching evacuation centers: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedEvacuationCenters() async {
    try {
      final dynamic data = _evacuationCentersBox?.get('data');
      if (data == null) return [];
      if (data is List) {
        final result = <Map<String, dynamic>>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            result.add(item);
          } else if (item is Map) {
            final converted = <String, dynamic>{};
            item.forEach((k, v) => converted[k.toString()] = v);
            result.add(converted);
          }
        }
        return result;
      }
      return [];
    } catch (e) {
      print('Error getting cached evacuation centers: $e');
      return [];
    }
  }

  static Future<DateTime?> getCentersLastUpdated() async {
    final v = _evacuationCentersBox?.get('last_updated');
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ── Evacuation Routes ─────────────────────────────────────────────────────

  // Stores the latest route under 'route' AND, when [centerId] is given, under a
  // per-center key so the OFFLINE path can later restore the exact Mapbox /
  // hazard-aware route the user computed for THAT specific center (rather than
  // whatever center happened to be navigated last).
  static Future<void> cacheEvacuationRoute(Map<String, dynamic> route,
      {String? centerId}) async {
    try {
      await _evacuationRoutesBox?.put('route', route);
      if (centerId != null && centerId.isNotEmpty) {
        await _evacuationRoutesBox?.put('route_$centerId', route);
      }
    } catch (e) {
      print('Error caching evacuation route: $e');
    }
  }

  static Map<String, dynamic>? _asStringMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      final converted = <String, dynamic>{};
      data.forEach((k, v) => converted[k.toString()] = v);
      return converted;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCachedEvacuationRoute() async {
    try {
      return _asStringMap(_evacuationRoutesBox?.get('route'));
    } catch (e) {
      print('Error getting cached evacuation route: $e');
      return null;
    }
  }

  // The cached Mapbox route for a SPECIFIC center, or null if none was cached
  // (e.g. the user never navigated there while online).
  static Future<Map<String, dynamic>?> getCachedEvacuationRouteForCenter(
      String centerId) async {
    try {
      return _asStringMap(_evacuationRoutesBox?.get('route_$centerId'));
    } catch (e) {
      print('Error getting cached evacuation route for $centerId: $e');
      return null;
    }
  }

  static Future<void> clearCachedEvacuationRoute() async {
    await _evacuationRoutesBox?.delete('route');
  }

  // ── Community Reports ─────────────────────────────────────────────────────

  static Future<void> cacheCommunityReports(List<Map<String, dynamic>> reports) async {
    try {
      await _communityReportsBox?.put('data', reports);
      await _communityReportsBox?.put('last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching community reports: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCachedCommunityReports() async {
    try {
      final dynamic data = _communityReportsBox?.get('data');
      if (data == null) return [];
      if (data is List) {
        final result = <Map<String, dynamic>>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            result.add(item);
          } else if (item is Map) {
            final converted = <String, dynamic>{};
            item.forEach((k, v) => converted[k.toString()] = v);
            result.add(converted);
          }
        }
        return result;
      }
      return [];
    } catch (e) {
      print('Error getting cached community reports: $e');
      return [];
    }
  }
}