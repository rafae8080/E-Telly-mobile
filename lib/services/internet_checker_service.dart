import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dbhelper/mongodb.dart';
import 'relay_queue_manager.dart';

/// Callback fired after every upload attempt.
/// [succeeded] — number of reports successfully uploaded this cycle.
/// [failed]    — number that errored and will be retried later.
typedef UploadCycleCallback = void Function(
    {required int succeeded, required int failed});

/// Monitors network connectivity and automatically flushes the relay queue
/// whenever internet access is restored.
///
/// Lifecycle:
///   InternetCheckerService.instance.start();   // typically in main() or home screen
///   InternetCheckerService.instance.dispose();  // on app exit
///
/// The service uses two complementary mechanisms:
///   1. connectivity_plus stream  — fires quickly on Wi-Fi / mobile toggle.
///   2. Periodic timer           — catches cases where the stream doesn't fire
///      (e.g. the device had a network interface but no actual internet).
class InternetCheckerService {
  // ── Singleton ──────────────────────────────────────────────────────────────

  InternetCheckerService._();
  static final InternetCheckerService instance = InternetCheckerService._();

  // ── Config ─────────────────────────────────────────────────────────────────

  /// How often the periodic check runs even when connectivity hasn't changed.
  static const Duration _pollInterval = Duration(minutes: 2);

  /// Timeout for a single HTTP upload attempt.
  static const Duration _uploadTimeout = Duration(seconds: 20);

  /// Base URL of your Express backend (matches the one in report_emergency_screen).
  static const String _backendBase = 'https://e-telly-ca75b10e9536.herokuapp.com';

  /// Maximum consecutive upload failures before the service backs off for one
  /// poll cycle.
  static const int _maxConsecutiveErrors = 3;

  // ── State ──────────────────────────────────────────────────────────────────

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _isRunning = false;
  bool _isFlushing = false; // guard against concurrent flushes
  int _consecutiveErrors = 0;

  /// Set this callback to be notified after each upload cycle completes.
  UploadCycleCallback? onCycleComplete;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Starts listening for connectivity changes and polls periodically.
  /// Safe to call multiple times – re-entrant calls are ignored.
  void start({UploadCycleCallback? onCycleComplete}) {
    if (_isRunning) return;
    _isRunning = true;
    this.onCycleComplete = onCycleComplete;

    // 1. React to connectivity changes immediately
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // 2. Poll periodically as a safety net
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (await _hasRealInternet()) {
        await _flushQueue();
      }
    });

    // 3. Run once right now in case we already have internet
    _initialCheck();

    debugPrint('[InternetChecker] Started.');
  }

  /// Stops all listeners and timers. Call this in your widget's dispose or
  /// when the user logs out.
  void dispose() {
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    _isRunning = false;
    debugPrint('[InternetChecker] Disposed.');
  }

  /// Force an immediate flush attempt (e.g. after the user taps a "Retry" button).
  Future<void> forceFlush() async {
    if (await _hasRealInternet()) {
      await _flushQueue();
    }
  }

  /// Whether there is currently at least one pending report waiting to upload.
  bool get hasPendingReports => RelayQueueManager.hasPending;

  /// Current count of reports waiting to be uploaded.
  int get pendingCount => RelayQueueManager.pendingCount;

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _initialCheck() async {
    await Future.delayed(const Duration(seconds: 2)); // let app settle
    if (await _hasRealInternet()) {
      await _flushQueue();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) {
      debugPrint('[InternetChecker] Network lost.');
      return;
    }

    // The interface is up – but verify there's actual internet
    debugPrint('[InternetChecker] Network change detected. Verifying internet…');
    await Future.delayed(const Duration(seconds: 1)); // brief settle delay

    if (await _hasRealInternet()) {
      debugPrint('[InternetChecker] Internet confirmed. Flushing queue…');
      await _flushQueue();
    } else {
      debugPrint('[InternetChecker] Interface up but no real internet.');
    }
  }

  /// Sends a lightweight HEAD request to verify actual internet connectivity,
  /// avoiding false positives on captive portals or aeroplane-mode edges.
  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Iterates over all pending relay entries and tries to upload each one.
  Future<void> _flushQueue() async {
    if (_isFlushing) return; // already in progress
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
      // Back-off if we've had too many consecutive errors
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        debugPrint(
            '[InternetChecker] Too many errors – skipping rest of cycle.');
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

    // Housekeeping: remove stale uploaded entries
    await RelayQueueManager.pruneUploaded();

    debugPrint(
        '[InternetChecker] Cycle complete – ✅ $succeeded uploaded, ❌ $failed failed.');

    onCycleComplete?.call(succeeded: succeeded, failed: failed);

    _isFlushing = false;
  }

  /// Attempts to upload a single relay entry.
  /// Tries MongoDB first, then falls back to the HTTP backend.
  /// Returns `true` on success.
  Future<bool> _uploadEntry(RelayEntry entry) async {
  try {
    // Only connect if not already connected
    if (MongoDatabase.db == null || !MongoDatabase.db!.isConnected) {
      await MongoDatabase.connect();
    }
    await MongoDatabase.saveEmergencyReport(entry.report)
        .timeout(_uploadTimeout);
    _notifyBackend(entry.report);
    return true;
  } catch (mongoErr) {
    debugPrint('[InternetChecker] MongoDB failed for ${entry.reportId}: $mongoErr');
  }

    // ── Step 2: HTTP backend fallback ────────────────────────────────────────
    try {
      final success = await _postToBackend(entry.report);
      if (success) return true;
    } catch (httpErr) {
    debugPrint('[InternetChecker] HTTP fallback failed for ${entry.reportId}: $httpErr');
    }

    await RelayQueueManager.markAsFailed(
    entry.reportId,
    'Upload failed at ${DateTime.now().toIso8601String()}',
  );
    return false;
}

  /// POSTs the report to the Express backend's save endpoint.
  Future<bool> _postToBackend(Map<String, dynamic> report) async {
    final response = await http
        .post(
          Uri.parse('$_backendBase/api/save-emergency-report'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(report),
        )
        .timeout(_uploadTimeout);

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> forceFlushIfOnline() async {
    if (await _hasRealInternet()) {
      await _flushQueue();
      return true;
    }
    return false;
  }

  /// Fire-and-forget notification to the backend's notify endpoint.
  /// Matches the existing call in report_emergency_screen.dart.
  void _notifyBackend(Map<String, dynamic> report) {
    http
        .post(
          Uri.parse('$_backendBase/api/notify-emergency'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'reportId': report['id'],
            'emergencyType': report['emergencyType'],
            'severity': report['severity'],
            'location': report['location']?['exactAddress'],
            'detailedAddress': report['location']?['detailedAddress'],
            'barangay': report['location']?['barangay'],
            'city': report['location']?['city'],
            'timestamp': report['timestamp'],
            'userName': report['userData']?['fullName'],
            'phoneNumber': report['userData']?['phoneNumber'],
            'description': report['description'],
            'relayedReport': true,
            'relayHops': report['relayHops'] ?? 0,
          }),
        )
        .timeout(_uploadTimeout)
        .then((res) {
          debugPrint(
              '[InternetChecker] Backend notified – status ${res.statusCode}');
        })
        .catchError((e) {
          debugPrint('[InternetChecker] Backend notify failed: $e');
        });
  }
}
