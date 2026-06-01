import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'relay_queue_manager.dart';

// ── Connectivity suffix ───────────────────────────────────────────────────────

enum ConnectivitySuffix { online, local, offline }

ConnectivitySuffix parseConnectivitySuffix(String name) {
  if (name.endsWith('_ONLINE')) return ConnectivitySuffix.online;
  if (name.endsWith('_LOCAL')) return ConnectivitySuffix.local;
  return ConnectivitySuffix.offline;
}

String stripConnectivitySuffix(String name) {
  for (final s in ['_ONLINE', '_LOCAL', '_OFFLINE']) {
    if (name.endsWith(s)) return name.substring(0, name.length - s.length);
  }
  return name;
}

// ── Event models ─────────────────────────────────────────────────────────────

enum PeerState { discovered, connecting, connected, disconnected }

class PeerDevice {
  final String endpointId;
  final String endpointName;
  PeerState state;
  int reportsSent;
  int reportsReceived;
  ConnectivitySuffix connectivity;

  PeerDevice({
    required this.endpointId,
    required this.endpointName,
    this.state = PeerState.discovered,
    this.reportsSent = 0,
    this.reportsReceived = 0,
    this.connectivity = ConnectivitySuffix.offline,
  });

  String get displayName => stripConnectivitySuffix(endpointName);
}

enum TransferState { idle, sending, receiving, done, error }

class TransferProgress {
  final TransferState state;
  final int total;
  final int current;
  final String? message;

  const TransferProgress({
    required this.state,
    this.total = 0,
    this.current = 0,
    this.message,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class P2PRelayService {
  // ── Singleton ───────────────────────────────────────────────────────────────
  P2PRelayService._();
  static final P2PRelayService instance = P2PRelayService._();

  // ── Constants ───────────────────────────────────────────────────────────────
  static const String _serviceId = 'com.android.application.etelly.relay';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;
  static const int _maxHops = 3;

  // ── State ────────────────────────────────────────────────────────────────────
  String? _localDeviceId;
  String? _localDeviceName;
  bool _isRunning = false;

  final Map<String, PeerDevice> _peers = {};

  /// Endpoints we initiated a connection to (via [connectAndSend]). Only the
  /// initiator drives the transfer + disconnect; the accepting (inbound) side
  /// just listens, so it never tears down an incoming transfer prematurely.
  final Set<String> _outboundEndpoints = {};

  // ── Callbacks (set by the UI layer) ──────────────────────────────────────────

  /// Called whenever the peer list changes (device found / lost / state change).
  void Function(List<PeerDevice>)? onPeersChanged;

  /// Called with progress updates during a send/receive operation.
  void Function(TransferProgress)? onTransferProgress;

  /// Called when a report is successfully received from a peer.
  void Function(String reportId)? onReportReceived;

  // ── Callbacks (set by P2PAutoRelayController) ─────────────────────────────

  /// Fires when a new peer is discovered — wakes the auto-relay controller.
  void Function(PeerDevice peer)? onPeerDiscoveredAuto;

  /// Fires after reports are received — controller decides whether to upload or keep advertising.
  void Function()? onReportsReceivedForRelay;

  /// Fires when an outgoing relay attempt ends — success, rejection, failure,
  /// or disconnect. Lets the controller release its connecting lock and move
  /// on to the next (best) peer. Safe to fire more than once per cycle.
  void Function()? onRelayCycleComplete;

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Initialises the local device identity from SharedPreferences + DeviceInfo.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _localDeviceName = prefs.getString('full_name') ?? 'Unknown User';

    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    _localDeviceId = android.id;
    debugPrint('[P2P] Initialised as "$_localDeviceName" (id: $_localDeviceId)');
  }

  /// Starts both advertising (so others find us) and discovery (so we find
  /// others). Appends [connectivitySuffix] to the advertised device name.
  /// Safe to call multiple times — stops first if already running.
  Future<void> startAdvertisingAndDiscovery({
    ConnectivitySuffix connectivitySuffix = ConnectivitySuffix.offline,
  }) async {
    await stop(); // always clean up OS-level session before starting
    if (_localDeviceName == null) await init();

    final advertisedName =
        '${_localDeviceName}_${connectivitySuffix.name.toUpperCase()}';

    try {
      await Nearby().startAdvertising(
        advertisedName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      await Nearby().startDiscovery(
        advertisedName,
        _strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      _isRunning = true;
      debugPrint('[P2P] Advertising + Discovery started as "$advertisedName".');
    } catch (e) {
      debugPrint('[P2P] Failed to start: $e');
      rethrow;
    }
  }

  /// Stops advertising, discovery, and all active connections.
  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    _peers.clear();
    _outboundEndpoints.clear();
    _isRunning = false;
    debugPrint('[P2P] Stopped.');
  }

  /// Connects to [endpointId] and sends all pending relay reports.
  /// Progress is reported via [onTransferProgress].
  Future<void> connectAndSend(String endpointId) async {
    final peer = _peers[endpointId];
    if (peer == null) return;

    _updatePeerState(endpointId, PeerState.connecting);
    _outboundEndpoints.add(endpointId);

    try {
      await Nearby().requestConnection(
        _localDeviceName!,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      // Actual sending happens in _onConnectionResult once accepted
    } catch (e) {
      debugPrint('[P2P] Connection request failed: $e');
      _outboundEndpoints.remove(endpointId);
      _updatePeerState(endpointId, PeerState.discovered);
      onTransferProgress?.call(TransferProgress(
        state: TransferState.error,
        message: 'Connection failed: $e',
      ));
      onRelayCycleComplete?.call();
    }
  }

  /// Disconnects from a specific endpoint.
  Future<void> disconnect(String endpointId) async {
    try {
      await Nearby().disconnectFromEndpoint(endpointId);
    } catch (_) {}
    _outboundEndpoints.remove(endpointId);
    _updatePeerState(endpointId, PeerState.disconnected);
  }

  List<PeerDevice> get peers => List.unmodifiable(_peers.values);
  bool get isRunning => _isRunning;

  // ── Nearby Connections callbacks ─────────────────────────────────────────────

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    debugPrint('[P2P] Found peer: $endpointName ($endpointId)');
    final peer = PeerDevice(
      endpointId: endpointId,
      endpointName: endpointName,
      connectivity: parseConnectivitySuffix(endpointName),
    );
    _peers[endpointId] = peer;
    _notifyPeersChanged();
    onPeerDiscoveredAuto?.call(peer);
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    debugPrint('[P2P] Lost peer: $endpointId');
    _peers.remove(endpointId);
    _notifyPeersChanged();
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('[P2P] Connection initiated with ${info.endpointName}');
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
    _updatePeerState(endpointId, PeerState.connecting);
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('[P2P] Connection result for $endpointId: $status');
    if (status == Status.CONNECTED) {
      _updatePeerState(endpointId, PeerState.connected);
      // Only the side that initiated the connection sends + drives the
      // disconnect. The accepting (inbound) side just listens; the sender
      // closes the link once it has sent __DONE__. This avoids the receiver
      // tearing down an incoming transfer and the dedup ping-pong that
      // happened when both sides ran _sendPendingReports.
      if (_outboundEndpoints.contains(endpointId)) {
        _sendPendingReports(endpointId);
      } else {
        onTransferProgress?.call(const TransferProgress(
          state: TransferState.receiving,
          message: 'Connected. Receiving reports…',
        ));
      }
    } else {
      _outboundEndpoints.remove(endpointId);
      _updatePeerState(endpointId, PeerState.discovered);
      onTransferProgress?.call(const TransferProgress(
        state: TransferState.error,
        message: 'Connection was rejected or failed.',
      ));
      onRelayCycleComplete?.call();
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[P2P] Disconnected from $endpointId');
    _outboundEndpoints.remove(endpointId);
    _updatePeerState(endpointId, PeerState.disconnected);
    onRelayCycleComplete?.call();
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES) return;
    final bytes = payload.bytes;
    if (bytes == null) return;

    try {
      final jsonString = utf8.decode(bytes);

      if (jsonString.startsWith('__COUNT__:')) {
        final count = int.tryParse(jsonString.split(':')[1]) ?? 0;
        debugPrint('[P2P] Peer will send $count report(s).');
        onTransferProgress?.call(TransferProgress(
          state: TransferState.receiving,
          total: count,
          current: 0,
          message: 'Receiving $count report(s)…',
        ));
        return;
      }

      if (jsonString == '__DONE__') {
        final peer = _peers[endpointId];
        final received = peer?.reportsReceived ?? 0;
        onTransferProgress?.call(TransferProgress(
          state: TransferState.done,
          total: received,
          current: received,
          message: 'Received $received report(s) successfully.',
        ));
        debugPrint('[P2P] Transfer complete from $endpointId.');
        onReportsReceivedForRelay?.call();
        return;
      }

      final entry = RelayQueueManager.fromTransferJson(jsonString);
      if (entry != null) {
        final peerInfo = {
          'deviceId': endpointId,
          'deviceName': _peers[endpointId]?.endpointName ?? 'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        };

        final relayedReport = Map<String, dynamic>.from(entry.report);
        relayedReport['source'] = 'mesh_relay';
        relayedReport.putIfAbsent(
            'offlineSubmittedAt', () => DateTime.now().toIso8601String());

        await RelayQueueManager.enqueueRelayed(
          report: relayedReport,
          peerInfo: peerInfo,
        );

        _peers[endpointId]?.reportsReceived++;
        final received = _peers[endpointId]?.reportsReceived ?? 1;

        onReportReceived?.call(entry.reportId);
        onTransferProgress?.call(TransferProgress(
          state: TransferState.receiving,
          total: received,
          current: received,
          message: 'Received report ${entry.reportId}',
        ));
        debugPrint('[P2P] Stored relayed report: ${entry.reportId}');
      }
    } catch (e) {
      debugPrint('[P2P] Error processing payload: $e');
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // Progress for BYTES payloads is tracked via __COUNT__ / __DONE__ sentinels.
  }

  // ── Sending logic ────────────────────────────────────────────────────────────

  Future<void> _sendPendingReports(String endpointId) async {
    final allPending = RelayQueueManager.getPending();
    final pending =
        allPending.where((e) => e.hopCount < _maxHops).toList();

    if (pending.isEmpty) {
      // Distinguish a genuinely empty queue from one where every report has
      // already reached the hop limit — they are very different situations.
      final message = allPending.isEmpty
          ? 'No reports to send right now.'
          : 'Reports reached the relay hop limit.';
      onTransferProgress?.call(TransferProgress(
        state: TransferState.done,
        total: 0,
        current: 0,
        message: message,
      ));
      await disconnect(endpointId);
      onRelayCycleComplete?.call();
      return;
    }

    onTransferProgress?.call(TransferProgress(
      state: TransferState.sending,
      total: pending.length,
      current: 0,
      message: 'Sending ${pending.length} report(s)…',
    ));

    await _sendBytes(endpointId, '__COUNT__:${pending.length}');

    int sent = 0;
    final peerInfo = {
      'deviceId': _localDeviceId ?? 'unknown',
      'deviceName': _localDeviceName ?? 'Unknown',
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final entry in pending) {
      try {
        final transfer = RelayQueueManager.prepareForTransfer(entry);
        final json = jsonEncode(transfer);
        await _sendBytes(endpointId, json);

        await RelayQueueManager.markAsRelayed(entry.reportId, peerInfo);
        _peers[endpointId]?.reportsSent++;
        sent++;

        onTransferProgress?.call(TransferProgress(
          state: TransferState.sending,
          total: pending.length,
          current: sent,
          message: 'Sent $sent of ${pending.length}…',
        ));

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('[P2P] Failed to send report ${entry.reportId}: $e');
      }
    }

    await _sendBytes(endpointId, '__DONE__');

    onTransferProgress?.call(TransferProgress(
      state: TransferState.done,
      total: pending.length,
      current: sent,
      message: 'Sent $sent of ${pending.length} report(s).',
    ));

    debugPrint('[P2P] Sent $sent/${pending.length} reports to $endpointId.');
    await Future.delayed(const Duration(seconds: 1));
    await disconnect(endpointId);
    onRelayCycleComplete?.call();
  }

  Future<void> _sendBytes(String endpointId, String data) async {
    final bytes = Uint8List.fromList(utf8.encode(data));
    await Nearby().sendBytesPayload(endpointId, bytes);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _updatePeerState(String endpointId, PeerState state) {
    if (_peers.containsKey(endpointId)) {
      _peers[endpointId]!.state = state;
    } else {
      _peers[endpointId] = PeerDevice(
        endpointId: endpointId,
        endpointName: 'Unknown Device',
        state: state,
      );
    }
    _notifyPeersChanged();
  }

  void _notifyPeersChanged() {
    onPeersChanged?.call(List.unmodifiable(_peers.values));
  }
}
