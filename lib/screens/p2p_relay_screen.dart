import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/p2p_auto_relay_controller.dart';
import '../services/p2p_relay_service.dart';
import '../services/relay_queue_manager.dart';

class P2PRelayScreen extends StatefulWidget {
  const P2PRelayScreen({super.key});

  @override
  State<P2PRelayScreen> createState() => _P2PRelayScreenState();
}

class _P2PRelayScreenState extends State<P2PRelayScreen>
    with SingleTickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────────────────────────
  final _controller = P2PAutoRelayController.instance;

  List<PeerDevice> _peers = [];
  TransferProgress _transfer =
      const TransferProgress(state: TransferState.idle);
  int _pendingCount = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.isActiveNotifier.addListener(_onControllerStateChanged);
    _controller.statusMessageNotifier.addListener(_onControllerStateChanged);
    _controller.pendingCountNotifier.addListener(_onControllerStateChanged);

    _refreshPendingCount();
    _resetFailedReports();
    _initService();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.isActiveNotifier.removeListener(_onControllerStateChanged);
    _controller.statusMessageNotifier.removeListener(_onControllerStateChanged);
    _controller.pendingCountNotifier.removeListener(_onControllerStateChanged);
    P2PRelayService.instance.onPeersChanged = null;
    P2PRelayService.instance.onTransferProgress = null;
    P2PRelayService.instance.onReportReceived = null;
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    setState(() {
      _pendingCount = _controller.pendingCountNotifier.value;
    });
  }

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> _initService() async {
    P2PRelayService.instance.onPeersChanged = (peers) {
      if (!mounted) return;
      setState(() => _peers = peers);
    };

    P2PRelayService.instance.onTransferProgress = (progress) {
      if (!mounted) return;
      setState(() => _transfer = progress);

      if (progress.state == TransferState.done) {
        _refreshPendingCount();
        _showTransferResultSnackbar(progress);
      }
    };

    P2PRelayService.instance.onReportReceived = (reportId) {
      if (!mounted) return;
      _refreshPendingCount();
    };
  }

  void _refreshPendingCount() {
    if (!mounted) return;
    setState(() => _pendingCount = RelayQueueManager.pendingCount);
  }

  Future<void> _resetFailedReports() async {
    final all = RelayQueueManager.getAll();
    for (final entry in all) {
      if (entry.status == RelayStatus.failed) {
        await RelayQueueManager.requeueFailed(entry.reportId);
      }
    }
    _refreshPendingCount();
  }

  // ── Permissions ───────────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();
    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );

    if (!allGranted) {
      _showPermissionDeniedDialog();
    }

    return allGranted;
  }

  // ── Manual trigger (capstone demo) ────────────────────────────────────────────

  Future<void> _triggerManualRelay() async {
    final granted = await _requestPermissions();
    if (!granted) return;
    await _controller.onReportEnqueued();
  }

  // ── UI helpers ────────────────────────────────────────────────────────────────

  void _showTransferResultSnackbar(TransferProgress progress) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                progress.message ?? 'Transfer complete.',
                style: TextStyle(fontSize: 13.sp),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth, location, and nearby Wi-Fi permissions are needed '
          'to discover and connect to nearby devices.\n\n'
          'Please grant them in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('How P2P Relay Works'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _howItWorksStep(
              '1',
              'You submit a report with no internet.',
              Icons.report_problem_outlined,
            ),
            SizedBox(height: 12.h),
            _howItWorksStep(
              '2',
              'Auto-Relay activates and scans for nearby devices automatically.',
              Icons.bluetooth_searching,
            ),
            SizedBox(height: 12.h),
            _howItWorksStep(
              '3',
              'A nearby device receives your report and carries it closer to the barangay hall.',
              Icons.send,
            ),
            SizedBox(height: 12.h),
            _howItWorksStep(
              '4',
              'When any relay device reaches WiFi or internet, it automatically uploads the report.',
              Icons.cloud_upload_outlined,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.07),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                'Both devices must have this app installed.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksStep(String step, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24.w,
          height: 24.h,
          decoration: const BoxDecoration(
            color: Color(0xFFDC2626),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13.sp)),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isActive = _controller.isActiveNotifier.value;
    final statusMessage = _controller.statusMessageNotifier.value;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'P2P Report Relay',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFFDC2626)),
            onPressed: _showHowItWorksDialog,
            tooltip: 'How it works',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPendingBanner(),
            SizedBox(height: 16.h),
            _buildRadarSection(),
            SizedBox(height: 20.h),
            _buildAutoRelayStatusCard(isActive, statusMessage),
            SizedBox(height: 12.h),
            _buildManualScanButton(isActive),
            SizedBox(height: 20.h),
            if (_peers.isNotEmpty || isActive) _buildPeerList(isActive),
            if (_transfer.state != TransferState.idle) ...[
              SizedBox(height: 16.h),
              _buildTransferStatus(),
            ],
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // ── Section widgets ───────────────────────────────────────────────────────────

  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _pendingCount > 0
            ? const Color(0xFFDC2626).withOpacity(0.08)
            : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _pendingCount > 0
              ? const Color(0xFFDC2626).withOpacity(0.25)
              : Colors.green.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _pendingCount > 0
                ? Icons.cloud_off_rounded
                : Icons.cloud_done_rounded,
            color: _pendingCount > 0
                ? const Color(0xFFDC2626)
                : Colors.green,
            size: 28.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingCount > 0
                      ? '$_pendingCount report${_pendingCount > 1 ? 's' : ''} waiting to be sent'
                      : 'No pending reports',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: _pendingCount > 0
                        ? const Color(0xFFDC2626)
                        : Colors.green,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _pendingCount > 0
                      ? 'Auto-Relay will find a nearby device to forward them.'
                      : 'All reports have been uploaded.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSection() {
    final isActive = _controller.isActiveNotifier.value;

    return Center(
      child: SizedBox(
        width: 180.w,
        height: 180.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 180.w,
                    height: 180.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.15),
                        width: 2.w,
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              width: 130.w,
              height: 130.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFDC2626).withOpacity(0.25)
                      : Colors.grey.withOpacity(0.2),
                  width: 1.5.w,
                ),
              ),
            ),
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFFDC2626).withOpacity(0.07)
                    : Colors.grey.withOpacity(0.05),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFDC2626).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 1.5.w,
                ),
              ),
              child: Icon(
                Icons.bluetooth_searching,
                size: 32.sp,
                color: isActive
                    ? const Color(0xFFDC2626)
                    : Colors.grey,
              ),
            ),
            ..._buildPeerDots(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPeerDots() {
    if (_peers.isEmpty) return [];

    final dots = <Widget>[];
    const positions = [
      Offset(0, -75),
      Offset(65, -35),
      Offset(65, 35),
      Offset(0, 75),
      Offset(-65, 35),
      Offset(-65, -35),
    ];

    for (int i = 0; i < _peers.length && i < positions.length; i++) {
      final peer = _peers[i];
      final pos = positions[i];
      final isConnected = peer.state == PeerState.connected;

      Color dotColor() {
        switch (peer.connectivity) {
          case ConnectivitySuffix.online:
            return Colors.green;
          case ConnectivitySuffix.local:
            return const Color(0xFF3B82F6);
          case ConnectivitySuffix.offline:
            return const Color(0xFF06B6D4);
        }
      }

      dots.add(
        Transform.translate(
          offset: Offset(pos.dx.w, pos.dy.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isConnected ? 18.w : 14.w,
                height: isConnected ? 18.w : 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : dotColor(),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor().withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                peer.displayName.split(' ').first,
                style: TextStyle(
                  fontSize: 8.sp,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return dots;
  }

  Widget _buildAutoRelayStatusCard(bool isActive, String statusMessage) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDC2626).withOpacity(0.07)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isActive
              ? const Color(0xFFDC2626).withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.radar : Icons.radar_outlined,
                color: isActive ? const Color(0xFFDC2626) : Colors.grey,
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  isActive ? 'Auto-Relay Active' : 'Auto-Relay Standby',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? const Color(0xFFDC2626)
                        : Colors.grey[700],
                  ),
                ),
              ),
              if (isActive)
                SizedBox(
                  width: 14.w,
                  height: 14.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    color: const Color(0xFFDC2626),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            statusMessage,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          if (isActive) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 36.h,
              child: ElevatedButton.icon(
                onPressed: () => _controller.stop(),
                icon: Icon(Icons.stop, size: 16.sp, color: Colors.white),
                label: Text(
                  'Stop Auto-Relay',
                  style: TextStyle(fontSize: 13.sp, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualScanButton(bool isActive) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: OutlinedButton.icon(
        onPressed: isActive ? null : _triggerManualRelay,
        icon: Icon(
          Icons.radar,
          size: 18.sp,
          color: isActive ? Colors.grey : const Color(0xFFDC2626),
        ),
        label: Text(
          'Manual Relay Trigger',
          style: TextStyle(
            fontSize: 13.sp,
            color: isActive ? Colors.grey : const Color(0xFFDC2626),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isActive
                ? Colors.grey.shade300
                : const Color(0xFFDC2626).withOpacity(0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }

  Widget _buildPeerList(bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.devices_other, size: 16.sp, color: Colors.grey[600]),
            SizedBox(width: 6.w),
            Text(
              isActive ? 'Searching for nearby devices…' : 'Nearby Devices',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (isActive) ...[
              SizedBox(width: 10.w),
              SizedBox(
                width: 12.w,
                height: 12.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 10.h),
        if (_peers.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.bluetooth_disabled,
                    size: 32.sp, color: Colors.grey[400]),
                SizedBox(height: 8.h),
                Text(
                  'No devices found yet.\nMake sure the other device\nhas this app open.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...(_peers.map((peer) => _buildPeerTile(peer))),
      ],
    );
  }

  Widget _buildPeerTile(PeerDevice peer) {
    final isConnecting = peer.state == PeerState.connecting;
    final isConnected = peer.state == PeerState.connected;
    final isSending = _transfer.state == TransferState.sending && isConnected;

    Color stateColor() {
      if (isConnected) return Colors.green;
      if (isConnecting || isSending) return const Color(0xFFF59E0B);
      return const Color(0xFF06B6D4);
    }

    String stateLabel() {
      if (isSending) return 'Sending…';
      if (isConnecting) return 'Connecting…';
      if (isConnected) return 'Connected';
      return 'Discovered';
    }

    IconData stateIcon() {
      if (isSending || isConnecting) return Icons.sync;
      if (isConnected) return Icons.bluetooth_connected;
      return Icons.bluetooth;
    }

    Widget _connectivityBadge() {
      Color badgeColor;
      String badgeLabel;
      switch (peer.connectivity) {
        case ConnectivitySuffix.online:
          badgeColor = Colors.green;
          badgeLabel = 'ONLINE';
          break;
        case ConnectivitySuffix.local:
          badgeColor = const Color(0xFF3B82F6);
          badgeLabel = 'LOCAL';
          break;
        case ConnectivitySuffix.offline:
          badgeColor = const Color(0xFFF97316);
          badgeLabel = 'OFFLINE';
          break;
      }
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: badgeColor.withOpacity(0.4)),
        ),
        child: Text(
          badgeLabel,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: badgeColor,
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: stateColor().withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: stateColor(),
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peer.displayName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    _connectivityBadge(),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Container(
                      width: 7.w,
                      height: 7.h,
                      decoration: BoxDecoration(
                        color: stateColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      stateLabel(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: stateColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isConnecting || isSending)
            SizedBox(
              width: 20.w,
              height: 20.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                color: stateColor(),
              ),
            )
          else
            Icon(stateIcon(), color: stateColor(), size: 22.sp),
        ],
      ),
    );
  }

  Widget _buildTransferStatus() {
    final state = _transfer.state;
    final isDone = state == TransferState.done;
    final isError = state == TransferState.error;
    final isSending = state == TransferState.sending;
    final isReceiving = state == TransferState.receiving;

    Color barColor() {
      if (isDone) return Colors.green;
      if (isError) return const Color(0xFFDC2626);
      return const Color(0xFFDC2626);
    }

    IconData headerIcon() {
      if (isDone) return Icons.check_circle_outline;
      if (isError) return Icons.error_outline;
      if (isReceiving) return Icons.download_rounded;
      return Icons.upload_rounded;
    }

    String headerText() {
      if (isDone) return 'Transfer Complete';
      if (isError) return 'Transfer Failed';
      if (isReceiving) return 'Receiving Reports';
      return 'Sending Reports';
    }

    final showProgress =
        (isSending || isReceiving) && _transfer.total > 0;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: barColor().withOpacity(0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: barColor().withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon(), color: barColor(), size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                headerText(),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: barColor(),
                ),
              ),
            ],
          ),
          if (_transfer.message != null) ...[
            SizedBox(height: 6.h),
            Text(
              _transfer.message!,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
          if (showProgress) ...[
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: _transfer.current / _transfer.total,
                backgroundColor: barColor().withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor()),
                minHeight: 6.h,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '${_transfer.current} / ${_transfer.total}',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
            ),
          ],
          if (!showProgress && (isSending || isReceiving)) ...[
            SizedBox(height: 10.h),
            LinearProgressIndicator(
              backgroundColor: barColor().withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor()),
              minHeight: 5.h,
            ),
          ],
        ],
      ),
    );
  }
}
