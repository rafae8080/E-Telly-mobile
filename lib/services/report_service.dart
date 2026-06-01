import 'dart:convert';
import 'package:e_telly_app/services/api_service.dart';

/// Fetches approved community emergency reports for the "Near You" tab.
///
/// `GET /api/reports/approved` is unauthenticated, so `optionalGet` is used
/// (works with or without a token). Each report reliably carries numeric
/// `latitude` / `longitude`, which the alerts screen uses for radius filtering.
class ReportService {
  Future<List<Map<String, dynamic>>> fetchApprovedReports() async {
    try {
      final response = await ApiService().optionalGet('/api/reports/approved');
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body);
      final List<dynamic> raw =
          body is Map<String, dynamic> ? (body['reports'] ?? []) : [];

      final reports = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          reports.add(Map<String, dynamic>.from(item));
        }
      }
      return reports;
    } catch (e) {
      print('[ReportService] Fetch error: $e');
      return [];
    }
  }
}
