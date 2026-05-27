import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dbhelper/mongodb.dart';
import 'endpoint_resolver.dart';
import 'relay_queue_manager.dart';

/// Thrown when the server explicitly rejects a report (HTTP 400).
/// The report should not be retried — it has a permanent data problem.
class _PermanentUploadFailure implements Exception {
  final String message;
  _PermanentUploadFailure(this.message);
}

/// Callback fired after every upload attempt.
/// [succeeded] — number of reports successfully uploaded this cycle.
/// [failed]    — number that errored and will be retried later.
typedef UploadCycleCallback = void Function(
    {required int succeeded, required int failed});

/// Monitors network connectivity and automatically flushes the relay queue
/// whenever internet access (or a reachable local barangay server) is detected.
class InternetCheckerService {
  // ── Singleton ──────────────────────────────────────────────────────────────

  InternetCheckerService._();
  static final InternetCheckerService instance = InternetCheckerService._();

  // ── Config ─────────────────────────────────────────────────────────────────

  static const Duration _pollInterval = Duration(minutes: 2);
  static const Duration _uploadTimeout = Duration(seconds: 20);
  static const int _maxConsecutiveErrors = 3;

  // ── State ──────────────────────────────────────────────────────────────────

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _isRunning = false;
  bool _isFlushing = false;
  int _consecutiveErrors = 0;

  UploadCycleCallback? onCycleComplete;

  // ── Public API ─────────────────────────────────────────────────────────────

  void start({UploadCycleCallback? onCycleComplete}) {
    if (_isRunning) return;
    _isRunning = true;
    this.onCycleComplete = onCycleComplete;

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (await _hasConnectivity()) {
        await _flushQueue();
      }
    });

    _initialCheck();

    debugPrint('[InternetChecker] Started.');
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _isRunning = false;
    debugPrint('[InternetChecker] Disposed.');
  }

  Future<void> forceFlush() async {
    if (await _hasConnectivity()) {
      await _flushQueue();
    }
  }

  bool get hasPendingReports => RelayQueueManager.hasPending;
  int get pendingCount => RelayQueueManager.pendingCount;

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _initialCheck() async {
    await Future.delayed(const Duration(seconds: 2));
    if (await _hasConnectivity()) {
      await _flushQueue();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) {
      debugPrint('[InternetChecker] Network lost.');
      return;
    }

    debugPrint('[InternetChecker] Network change detected. Checking connectivity…');
    await Future.delayed(const Duration(seconds: 1));

    if (await _hasConnectivity()) {
      debugPrint('[InternetChecker] Connectivity confirmed. Flushing queue…');
      await _flushQueue();
    } else {
      debugPrint('[InternetChecker] Interface up but no reachable server.');
    }
  }

  /// True when the device can reach either the internet or the local barangay server.
  Future<bool> _hasConnectivity() async {
    if (await _hasRealInternet()) return true;
    // No internet — check if the barangay local server is reachable
    final url = await EndpointResolver.getBaseUrl();
    return _isLocalServerUrl(url);
  }

  /// True if [url] is a local barangay server (not cloud, not empty).
  bool _isLocalServerUrl(String url) => url.isNotEmpty && url != cloudBaseUrl;

  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    final pending = RelayQueueManager.getPending();
    if (pending.isEmpty) {
      _isFlushing = false;
      return;
    }

    debugPrint('[InternetChecker] Flushing ${pending.length} pending report(s)…');

    int succeeded = 0;
    int failed = 0;

    for (final entry in pending) {
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        debugPrint('[InternetChecker] Too many errors – skipping rest of cycle.');
        break;
      }

      final ok = await _uploadEntry(entry);
      if (ok) {
        succeeded++;
        _consecutiveErrors = 0;
        await RelayQueueManager.markAsUploaded(entry.reportId);
        debugPrint('[InternetChecker] ✅ Uploaded report ${entry.reportId}');
      } else {
        failed++;
        _consecutiveErrors++;
      }
    }

    await RelayQueueManager.pruneUploaded();

    debugPrint(
        '[InternetChecker] Cycle complete – ✅ $succeeded uploaded, ❌ $failed failed.');

    onCycleComplete?.call(succeeded: succeeded, failed: failed);

    _isFlushing = false;
  }

  /// Attempts to upload a single relay entry.
  /// Routes to the local barangay server when on ETelly WiFi,
  /// otherwise tries MongoDB Atlas then the HTTP backend.
  Future<bool> _uploadEntry(RelayEntry entry) async {
    final baseUrl = await EndpointResolver.getBaseUrl();

    if (baseUrl.isEmpty) {
      debugPrint('[InternetChecker] No connectivity for ${entry.reportId}.');
      return false;
    }

    // Build a copy of the report with the correct source tag
    final report = Map<String, dynamic>.from(entry.report);
    if (report['source'] != 'mesh_relay') {
      report['source'] = _isLocalServerUrl(baseUrl) ? 'direct_wifi' : 'online';
    }
    // Strip any pre-fix local file paths — only keep already-uploaded URLs
    final rawImages = List<String>.from(report['images'] ?? []);
    report['images'] = rawImages.where((s) => s.startsWith('http')).toList();
    // Ensure offlineSubmittedAt is present (set at creation time, but guard here)
    report.putIfAbsent(
        'offlineSubmittedAt', () => DateTime.now().toIso8601String());

    // ── Path A: Local barangay server ────────────────────────────────────────
    if (_isLocalServerUrl(baseUrl)) {
      try {
        final ok = await _postToLocalServer(baseUrl, report);
        if (!ok) {
          await RelayQueueManager.markAsFailed(
            entry.reportId,
            'Local server upload failed at ${DateTime.now().toIso8601String()}',
          );
        }
        return ok;
      } on _PermanentUploadFailure catch (e) {
        await RelayQueueManager.markAsFailed(entry.reportId, e.message,
            permanent: true);
        debugPrint('[InternetChecker] ❌ Permanent failure ${entry.reportId}: ${e.message}');
        return false;
      }
    }

    // ── Path B: Cloud (MongoDB Atlas → HTTP backend) ─────────────────────────
    try {
      if (MongoDatabase.db == null || !MongoDatabase.db!.isConnected) {
        await MongoDatabase.connect();
      }
      await MongoDatabase.saveEmergencyReport(report).timeout(_uploadTimeout);
      return true;
    } catch (mongoErr) {
      debugPrint(
          '[InternetChecker] MongoDB failed for ${entry.reportId}: $mongoErr');
    }

    try {
      final success = await _postToBackend(baseUrl, report);
      if (success) {
        return true;
      }
    } on _PermanentUploadFailure catch (e) {
      await RelayQueueManager.markAsFailed(entry.reportId, e.message,
          permanent: true);
      debugPrint('[InternetChecker] ❌ Permanent failure ${entry.reportId}: ${e.message}');
      return false;
    } catch (httpErr) {
      debugPrint(
          '[InternetChecker] HTTP fallback failed for ${entry.reportId}: $httpErr');
    }

    await RelayQueueManager.markAsFailed(
      entry.reportId,
      'Upload failed at ${DateTime.now().toIso8601String()}',
    );
    return false;
  }

  /// POSTs to the local barangay Express server's report creation endpoint.
  /// [baseUrl] is the resolved local server URL (e.g. http://192.168.137.1:5000).
  Future<bool> _postToLocalServer(String baseUrl, Map<String, dynamic> report) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/reports/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(report),
          )
          .timeout(_uploadTimeout);
      debugPrint(
          '[InternetChecker] Local server response: ${response.statusCode}');
      if (response.statusCode == 400) {
        throw _PermanentUploadFailure('400 Bad Request: ${response.body}');
      }
      return response.statusCode >= 200 && response.statusCode < 300;
    } on _PermanentUploadFailure {
      rethrow;
    } catch (e) {
      debugPrint('[InternetChecker] Local server POST failed: $e');
      return false;
    }
  }

  /// POSTs the report via HTTP.
  /// Uses [baseUrl] from [EndpointResolver.getBaseUrl()] — never hardcodes a URL.
  /// Chooses the correct endpoint based on whether [baseUrl] is local or cloud.
  Future<bool> _postToBackend(String baseUrl, Map<String, dynamic> report) async {
    final endpoint = _isLocalServerUrl(baseUrl)
        ? '/api/reports/create'
        : '/api/save-emergency-report';
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(report),
        )
        .timeout(_uploadTimeout);

    if (response.statusCode == 400) {
      throw _PermanentUploadFailure('400 Bad Request: ${response.body}');
    }
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> forceFlushIfOnline() async {
    if (await _hasConnectivity()) {
      await _flushQueue();
      return true;
    }
    return false;
  }
}
