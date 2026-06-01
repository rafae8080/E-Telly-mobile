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

  /// How long to collect discovered peers before picking the best one to send
  /// to. Without this we would connect to whichever peer happens to be found
  /// first, ignoring whether a barangay-reachable (_LOCAL/_ONLINE) device is
  /// also in range.
  static const Duration _selectWindow = Duration(milliseconds: 2500);

  // ── Exposed state (read by UI) ─────────────────────────────────────────────

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier(false);
  final ValueNotifier<String> statusMessageNotifier =
      ValueNotifier('Auto-Relay Standby');

  // ── Internal state ─────────────────────────────────────────────────────────

  bool _isConnecting = false;
  Timer? _autoStopTimer;
  Timer? _selectTimer;

  /// This device's own connectivity level, resolved in [_activate]. A device
  /// that can reach a server (_LOCAL/_ONLINE) should upload directly rather
  /// than initiate an outbound P2P relay.
  ConnectivitySuffix _ownSuffix = ConnectivitySuffix.offline;

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
    } else if (isActiveNotifier.value) {
      // Already advertising/scanning — a previous report activated the relay.
      // Don't just sit idle: kick a fresh relay cycle so this new report is
      // sent without the user having to Stop/Start the relay.
      debugPrint('[AutoRelay] Already active — kicking relay cycle for new report.');
      _resetAutoStopTimer();
      _kickRelayCycle();
    } else {
      debugPrint('[AutoRelay] No connectivity — activating P2P relay.');
      await _activate();
    }
  }

  /// Re-arms the select → connect path for a newly queued report while the
  /// relay is already running. Peers are already discovered, so no new
  /// `_onEndpointFound` fires; without this the report would wait until the
  /// user manually restarted the relay. If no peers are in range yet,
  /// discovery is still running and [_onPeerDiscovered] will pick it up.
  void _kickRelayCycle() {
    if (_ownSuffix != ConnectivitySuffix.offline) return; // connected → uploads directly
    if (_isConnecting) return;
    if (_selectTimer?.isActive ?? false) return;
    if (!RelayQueueManager.hasRelayableReports) return;
    if (P2PRelayService.instance.peers.isEmpty) return;

    _setStatus('New report queued — finding a device…');
    _selectTimer = Timer(_selectWindow, _selectAndConnect);
  }

  /// Manually starts P2P advertising and discovery regardless of connectivity.
  /// Used by Phone B (receiver) to make itself discoverable without submitting a report.
  Future<void> startManualRelay() async {
    await _activate();
  }

  /// Stops auto-relay and clears all state. Safe to call when idle.
  Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _selectTimer?.cancel();
    _selectTimer = null;
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
    _ownSuffix = suffix;

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
      debugPrint('[AutoRelay] Already connecting — not interrupting.');
      return;
    }

    // Don't connect to the first peer we see. Open a short window so other
    // peers can be discovered too, then pick the best-connected one.
    if (_selectTimer?.isActive ?? false) return;
    _setStatus('Evaluating nearby devices…');
    _selectTimer = Timer(_selectWindow, _selectAndConnect);
  }

  /// Picks the highest-priority discovered peer and connects to it.
  /// Priority: _ONLINE > _LOCAL > _OFFLINE.
  void _selectAndConnect() {
    _selectTimer = null;

    if (_isConnecting) return;
    if (!RelayQueueManager.hasRelayableReports) return;

    // A device that can already reach a server uploads directly (handled in
    // onReportEnqueued / _onReportsReceived). It should not initiate an
    // outbound relay — it just advertises so offline senders can reach it.
    if (_ownSuffix != ConnectivitySuffix.offline) {
      debugPrint(
          '[AutoRelay] Local device is ${_ownSuffix.name} — not initiating outbound relay.');
      return;
    }

    final candidates = P2PRelayService.instance.peers
        .where((p) =>
            p.state == PeerState.discovered ||
            p.state == PeerState.disconnected)
        .toList();

    if (candidates.isEmpty) {
      debugPrint('[AutoRelay] No candidate peers to connect to.');
      return;
    }

    candidates
        .sort((a, b) => _score(b.connectivity).compareTo(_score(a.connectivity)));
    final best = candidates.first;

    _isConnecting = true;
    _setStatus('Connecting to ${best.displayName} (${best.connectivity.name})…');
    debugPrint(
        '[AutoRelay] Selected best of ${candidates.length} peer(s): '
        '${best.displayName} (${best.connectivity.name}).');

    P2PRelayService.instance.connectAndSend(best.endpointId);
  }

  /// Routing priority for a peer's advertised connectivity.
  int _score(ConnectivitySuffix c) {
    switch (c) {
      case ConnectivitySuffix.online:
        return 2;
      case ConnectivitySuffix.local:
        return 1;
      case ConnectivitySuffix.offline:
        return 0;
    }
  }

  /// Fired by [P2PRelayService] when an outbound relay attempt ends (success,
  /// rejection, failure, or disconnect). Releases the connecting lock so the
  /// next peer can be considered, and retries if there is still work to do.
  void _onRelayCycleComplete() {
    if (!_isConnecting && (_selectTimer?.isActive ?? false)) return;
    debugPrint('[AutoRelay] Relay cycle complete — releasing lock.');
    _isConnecting = false;
    _resetAutoStopTimer();

    if (isActiveNotifier.value &&
        RelayQueueManager.hasRelayableReports &&
        P2PRelayService.instance.peers.isNotEmpty &&
        !(_selectTimer?.isActive ?? false)) {
      _setStatus('Looking for the next device…');
      _selectTimer = Timer(_selectWindow, _selectAndConnect);
    }
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
    P2PRelayService.instance.onRelayCycleComplete = _onRelayCycleComplete;
  }

  void _unwireCallbacks() {
    P2PRelayService.instance.onPeerDiscoveredAuto = null;
    P2PRelayService.instance.onReportsReceivedForRelay = null;
    P2PRelayService.instance.onRelayCycleComplete = null;
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
