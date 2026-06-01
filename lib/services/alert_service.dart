import 'dart:convert';
import 'package:e_telly_app/services/api_service.dart';
import 'package:e_telly_app/services/hive_service.dart';
import 'package:e_telly_app/utils/alert_presentation.dart';

class AlertService {

  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    try {
      final response = await ApiService().authenticatedGet('/api/alerts');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // Backend may return { "alerts": [...] } or directly [...]
        final List<dynamic> raw = body is List ? body : (body['alerts'] ?? []);

        final converted = <Map<String, dynamic>>[];
        for (final item in raw) {
          final alert = _convertAlert(Map<String, dynamic>.from(item as Map));
          if (alert != null) converted.add(alert);
        }

        // Preserve read/unread state across refreshes. _convertAlert always
        // sets read:false for freshly fetched alerts, so without this merge a
        // refresh would wipe the user's "read" marks (and reset the badge).
        final prior = await HiveService.getCachedAlerts();
        final readMap = <String, bool>{
          for (final p in prior)
            (p['id'] ?? '').toString(): (p['read'] as bool?) ?? false,
        };
        for (final c in converted) {
          c['read'] = readMap[(c['id'] ?? '').toString()] ?? false;
        }

        await HiveService.cacheAlerts(converted);
        return converted;
      }

      // Non-200 — fall through to cache
    } catch (e) {
      print('[AlertService] Fetch error: $e');
    }

    final cached = await HiveService.getCachedAlerts();
    if (cached.isNotEmpty) {
      print('[AlertService] Returning ${cached.length} cached alerts');
    }
    return cached;
  }

  Map<String, dynamic>? _convertAlert(Map<String, dynamic> alert) {
    try {
      final id = (alert['_id'] ?? alert['id'] ?? '').toString();

      // Severity mapping. `rawSeverity` (watch/warning/critical/evacuate) is the
      // PAGASA-derived band kept for the resident presentation layer; `severity`
      // is the legacy collapsed value still used for card styling fallbacks.
      final rawSeverity = (alert['severity'] ?? 'watch') as String;
      final String severity;
      switch (rawSeverity) {
        case 'evacuate':
        case 'critical':
          severity = 'critical';
          break;
        case 'warning':
          severity = 'high';
          break;
        default:
          severity = 'moderate';
      }

      final rawType = (alert['type'] ?? 'other') as String;

      // Type mapping
      final String mappedType;
      switch (rawType) {
        case 'flood':      mappedType = 'flood';       break;
        case 'river':      mappedType = 'water_level'; break;
        case 'rainfall':   mappedType = 'rain';        break;
        case 'evacuate':   mappedType = 'evacuate';    break;
        case 'earthquake': mappedType = 'earthquake';  break;
        case 'typhoon':    mappedType = 'typhoon';     break;
        case 'volcano':    mappedType = 'volcano';     break;
        default:           mappedType = 'other';
      }

      final barangays = List<String>.from(alert['barangays'] ?? []);
      final barangayText = barangays.isNotEmpty
          ? barangays.join(', ')
          : (alert['location'] ?? 'Antipolo City') as String;

      final createdAt = alert['createdAt'] is String
          ? DateTime.tryParse(alert['createdAt'] as String) ?? DateTime.now()
          : DateTime.now();

      final source = (alert['source'] ?? 'system') as String;
      final isManual = (alert['isManual'] ?? false) as bool;
      final officialDetail = (alert['description'] ?? '') as String;

      // Auto/system alerts carry a CDRRMO-grade technical description. Replace it
      // with a plain, resident-friendly line (faithful to the PAGASA severity).
      // Manual operator alerts already read plainly — keep their message as-is.
      final isAuto = AlertPresentation.isAutoAlert(source, isManual);
      final message = isAuto
          ? AlertPresentation.residentMessage(rawType, rawSeverity)
          : (officialDetail.isNotEmpty
              ? officialDetail
              : 'No description provided');

      return {
        'id': id,
        'type': mappedType,
        'rawType': rawType,
        'rawSeverity': rawSeverity,
        'isManual': isManual,
        'title': alert['title'] ?? 'Alert',
        'message': message,
        'officialDetail': officialDetail,
        'barangay': barangayText,
        'timestamp': _timeAgo(createdAt),
        'severity': severity,
        'active': alert['isActive'] ?? true,
        'read': false,
        'waterLevel': _extractWaterLevel(officialDetail),
        'evacuationCenter': null,
        'source': source,
        'location': alert['location'] ?? '',
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': alert['expiresAt'] as String?,
        'lat': alert['lat'],
        'lng': alert['lng'],
        'alertType': rawType,
      };
    } catch (e) {
      print('[AlertService] Convert error: $e — $alert');
      return null;
    }
  }

  Future<bool> dismissAlert(String alertId) async {
    try {
      final response = await ApiService().authenticatedPut(
        '/api/alerts/$alertId/dismiss',
        {},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[AlertService] Dismiss error: $e');
      return false;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String? _extractWaterLevel(String description) {
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|meter|meters)', caseSensitive: false),
      RegExp(r'water level:?\s*(\d+(?:\.\d+)?)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(description);
      if (m != null) return '${m.group(1)}m';
    }
    return null;
  }
}
