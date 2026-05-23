import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

const String cloudBaseUrl = 'https://e-telly-ca75b10e9536.herokuapp.com';

/// SSID prefix that all barangay emergency WiFi networks must use (e.g. "ETelly-BagongNayon").
const String _localSsidPrefix = 'ETelly-';

/// Candidate local server URLs, probed in order.
/// Windows Mobile Hotspot always assigns 192.168.137.1 to the laptop.
/// Physical WiFi router deployment uses 192.168.1.100.
const List<String> _localCandidates = [
  'http://192.168.137.1:5000', // Windows Mobile Hotspot (testing/demo)
  'http://192.168.1.100:5000', // Physical WiFi router (deployment)
];

class EndpointResolver {
  /// Returns the correct base URL for the current network state:
  /// - local server URL → phone is on a barangay ETelly WiFi and a server responds
  /// - [cloudBaseUrl]   → phone has internet (ETelly WiFi but server down, or regular internet)
  /// - `''`             → no connectivity at all
  static Future<String> getBaseUrl() async {
    final ssid = await _getWifiSsid();
    final onBarangayNet = ssid != null && ssid.startsWith(_localSsidPrefix);

    if (onBarangayNet) {
      debugPrint('[EndpointResolver] On barangay WiFi: $ssid');
      final serverUrl = await _findReachableLocalServer();
      if (serverUrl != null) {
        debugPrint('[EndpointResolver] Local server reachable: $serverUrl');
        return serverUrl;
      }

      // Server unreachable on barangay WiFi.
      // Fall back to cloud if internet is available (covers testing setups
      // where the laptop also provides internet via its hotspot).
      // In a real deployment with no internet on barangay WiFi this branch
      // returns '' — which is correct (offline queue / P2P relay).
      debugPrint('[EndpointResolver] ⚠️  Local server NOT reachable. '
          'Make sure the server is running on the laptop and port 5000 is '
          'allowed through Windows Firewall.');
      final results = await Connectivity().checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        debugPrint('[EndpointResolver] Internet available — falling back to cloud.');
        return cloudBaseUrl;
      }
      debugPrint('[EndpointResolver] No internet and no local server. Offline.');
      return '';
    }

    // Not on ETelly WiFi — use cloud if internet is available.
    final results = await Connectivity().checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    debugPrint('[EndpointResolver] Not on barangay WiFi (SSID: ${ssid ?? "null"}). '
        'Using ${hasNetwork ? "cloud" : "offline (no network)"}.');
    return hasNetwork ? cloudBaseUrl : '';
  }

  /// Returns the current WiFi SSID with surrounding quotes stripped, or null.
  /// Android requires ACCESS_FINE_LOCATION to read the SSID.
  static Future<String?> _getWifiSsid() async {
    try {
      final raw = await NetworkInfo().getWifiName();
      return raw?.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// Probes each candidate local server URL in order.
  /// Returns the first URL that responds with HTTP 200, or null if none respond.
  static Future<String?> _findReachableLocalServer() async {
    for (final url in _localCandidates) {
      try {
        debugPrint('[EndpointResolver] Probing $url …');
        final response = await http
            .get(Uri.parse('$url/api/health'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) return url;
        debugPrint('[EndpointResolver] $url responded ${response.statusCode}');
      } catch (e) {
        debugPrint('[EndpointResolver] $url unreachable: $e');
      }
    }
    return null;
  }
}
