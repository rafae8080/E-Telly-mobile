import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'endpoint_resolver.dart';
import 'internet_checker_service.dart';
import 'p2p_relay_service.dart';
import 'relay_queue_manager.dart';

/// Orchestration brain for the auto-relay mesh.
///
/// Entry point: [onReportEnqueued] — call this after every [RelayQueueManager.enqueue].
/// The controller decides whether to upload directly or activate P2P advertising.
class P2PAutoRelayController {
  P2PAutoRelayController._();
  static final P2PAutoRelayController instance = P2PAutoRelayController._();

  static const Duration _autoStopTimeout = Duration(minutes: 10);

  // ── Exposed state (read by UI) ─────────────────────────────────────────────

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier =
      ValueNotifier('Auto-Relay Standby');

  // ── Internal state ─────────────────────────────────────────────────────────

  bool _isConnecting = false;
  Timer? _autoStopTimer;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called after every [RelayQueueManager.enqueue].
  /// Uploads directly if connectivity is available; otherwise activates P2P.
  Future<void> onReportEnqueued() async {
    _refreshPendingCount();

    final url = await EndpointResolver.getBaseUrl();
    if (url.isNotEmpty) {
      debugPrint('[AutoRelay] Connectivity detected — flushing directly.');
      _setStatus('Uploading report directly…');
      await InternetCheckerService.instance.forceFlushIfOnline();
      _refreshPendingCount();
      _setStatus('Upload complete.');
    } else {
      debugPrint('[AutoRelay] No connectivity — activating P2P relay.');
      await _activate();
    }
  }

  /// Stops auto-relay and clears all state. Safe to call when idle.
  Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _isConnecting = false;
    _unwireCallbacks();
    await P2PRelayService.instance.stop();
    isActiveNotifier.value = false;
    _setStatus('Auto-Relay Standby');
    debugPrint('[AutoRelay] Stopped.');
  }

  // ── Activation ─────────────────────────────────────────────────────────────

  Future<void> _activate() async {
    if (isActiveNotifier.value) {
      debugPrint('[AutoRelay] Already active — skipping re-activation.');
      _resetAutoStopTimer();
      return;
    }

    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );

    if (!allGranted) {
      _setStatus('P2P permissions not granted. Open the P2P screen to allow them.');
      debugPrint('[AutoRelay] Permissions not granted — aborting activation.');
      return;
    }

    debugPrint('[AutoRelay] Activating.');
    _setStatus('Activating P2P relay…');
    isActiveNotifier.value = true;
    _isConnecting = false;

    _wireCallbacks();

    final url = await EndpointResolver.getBaseUrl();
    final ConnectivitySuffix suffix;
    if (url.isNotEmpty && url.contains('192.168')) {
      suffix = ConnectivitySuffix.local;
    } else if (url.isNotEmpty) {
      suffix = ConnectivitySuffix.online;
    } else {
      suffix = ConnectivitySuffix.offline;
    }

    try {
      await P2PRelayService.instance.startAdvertisingAndDiscovery(
        connectivitySuffix: suffix,
      );
      _setStatus('Scanning for nearby devices…');
      _resetAutoStopTimer();
    } catch (e) {
      debugPrint('[AutoRelay] Failed to start advertising: $e');
      _setStatus('Failed to start P2P relay: $e');
      isActiveNotifier.value = false;
    }
  }

  // ── Peer discovery handler ─────────────────────────────────────────────────

  void _onPeerDiscovered(PeerDevice peer) {
    debugPrint(
        '[AutoRelay] Peer discovered: ${peer.displayName} (${peer.connectivity.name})');
    _resetAutoStopTimer();

    if (!RelayQueueManager.hasRelayableReports) {
      debugPrint('[AutoRelay] No relayable reports — skipping connection.');
      return;
    }

    if (_isConnecting) {
      debugPrint('[AutoRelay] Already connecting — skipping ${peer.displayName}.');
      return;
    }

    _isConnecting = true;
    _setStatus('Connecting to ${peer.displayName}…');
    debugPrint('[AutoRelay] Connecting to ${peer.displayName}.');

    P2PRelayService.instance.connectAndSend(peer.endpointId);
  }

  // ── Reports received handler ───────────────────────────────────────────────

  Future<void> _onReportsReceived() async {
    debugPrint('[AutoRelay] Reports received — checking connectivity.');
    _isConnecting = false;
    _refreshPendingCount();

    final url = await EndpointResolver.getBaseUrl();
    if (url.isNotEmpty) {
      debugPrint('[AutoRelay] Connectivity available — flushing queue.');
      _setStatus('Uploading received reports…');
      await InternetCheckerService.instance.forceFlushIfOnline();
      _refreshPendingCount();
      _setStatus('Reports uploaded. Staying active for more relays.');
    } else {
      debugPrint('[AutoRelay] No connectivity — staying active for next hop.');
      _setStatus('Reports received. Scanning for next hop…');
    }
  }

  // ── Callbacks wiring ───────────────────────────────────────────────────────

  void _wireCallbacks() {
    P2PRelayService.instance.onPeerDiscoveredAuto = _onPeerDiscovered;
    P2PRelayService.instance.onReportsReceivedForRelay = _onReportsReceived;
  }

  void _unwireCallbacks() {
    P2PRelayService.instance.onPeerDiscoveredAuto = null;
    P2PRelayService.instance.onReportsReceivedForRelay = null;
  }

  // ── Auto-stop timer ────────────────────────────────────────────────────────

  void _resetAutoStopTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_autoStopTimeout, () {
      debugPrint('[AutoRelay] Auto-stop: no activity for 10 minutes.');
      _setStatus('Auto-Relay stopped (no activity).');
      stop();
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setStatus(String message) {
    statusMessageNotifier.value = message;
  }

  void _refreshPendingCount() {
    pendingCountNotifier.value = RelayQueueManager.pendingCount;
  }
}
