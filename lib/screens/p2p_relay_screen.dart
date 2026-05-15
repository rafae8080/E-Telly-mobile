import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isScanning = false;
  bool _permissionsGranted = false;
  List<PeerDevice> _peers = [];
  TransferProgress _transfer =
      const TransferProgress(state: TransferState.idle);
  int _pendingCount = 0;
  String? _selectedEndpointId;

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

    _refreshPendingCount();
    _resetFailedReports();
    _initService();
  }


  @override
  void dispose() {
    _pulseController.dispose();
    P2PRelayService.instance.onPeersChanged = null;
    P2PRelayService.instance.onTransferProgress = null;
    P2PRelayService.instance.onReportReceived = null;
    if (_isScanning) P2PRelayService.instance.stop();
    super.dispose();
  }

  // ── Init ─────────────────────────────────────────────────────────────────────

  Future<void> _initService() async {
    await P2PRelayService.instance.init();

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

    setState(() => _permissionsGranted = allGranted);

    if (!allGranted) {
      _showPermissionDeniedDialog();
    }

    return allGranted;
  }

  // ── Scan controls ─────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    final granted = await _requestPermissions();
    if (!granted) return;

    setState(() {
      _isScanning = true;
      _peers = [];
      _transfer = const TransferProgress(state: TransferState.idle);
      _selectedEndpointId = null;
    });

    try {
      await P2PRelayService.instance.startAdvertisingAndDiscovery();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showErrorSnackbar('Failed to start scanning: $e');
    }
  }

  Future<void> _stopScan() async {
    await P2PRelayService.instance.stop();
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _peers = [];
      _selectedEndpointId = null;
    });
  }

  Future<void> _sendToPeer(String endpointId) async {
    if (_pendingCount == 0) {
      _showErrorSnackbar('No pending reports to send.');
      return;
    }

    setState(() {
      _selectedEndpointId = endpointId;
      _transfer = const TransferProgress(
        state: TransferState.sending,
        message: 'Connecting…',
      );
    });

    await P2PRelayService.instance.connectAndSend(endpointId);
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

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 13.sp)),
        backgroundColor: const Color(0xFFDC2626),
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
              'Scan for nearby devices running this app.',
              Icons.bluetooth_searching,
            ),
            SizedBox(height: 12.h),
            _howItWorksStep(
              '3',
              'Select a nearby device and send your report to them.',
              Icons.send,
            ),
            SizedBox(height: 12.h),
            _howItWorksStep(
              '4',
              'When that device gets internet, it automatically uploads '
              'the report to the admin.',
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
            _buildScanButton(),
            SizedBox(height: 20.h),
            if (_peers.isNotEmpty || _isScanning) _buildPeerList(),
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
                      ? 'Find a nearby device with internet to relay them.'
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
    return Center(
      child: SizedBox(
        width: 180.w,
        height: 180.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring (only animates while scanning)
            if (_isScanning)
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
            // Middle ring
            Container(
              width: 130.w,
              height: 130.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isScanning
                      ? const Color(0xFFDC2626).withOpacity(0.25)
                      : Colors.grey.withOpacity(0.2),
                  width: 1.5.w,
                ),
              ),
            ),
            // Inner ring
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning
                    ? const Color(0xFFDC2626).withOpacity(0.07)
                    : Colors.grey.withOpacity(0.05),
                border: Border.all(
                  color: _isScanning
                      ? const Color(0xFFDC2626).withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 1.5.w,
                ),
              ),
              child: Icon(
                Icons.bluetooth_searching,
                size: 32.sp,
                color: _isScanning
                    ? const Color(0xFFDC2626)
                    : Colors.grey,
              ),
            ),
            // Peer dots around the radar
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
      Offset(0, -75),   // top
      Offset(65, -35),  // top-right
      Offset(65, 35),   // bottom-right
      Offset(0, 75),    // bottom
      Offset(-65, 35),  // bottom-left
      Offset(-65, -35), // top-left
    ];

    for (int i = 0; i < _peers.length && i < positions.length; i++) {
      final peer = _peers[i];
      final pos = positions[i];
      final isSelected = peer.endpointId == _selectedEndpointId;
      final isConnected = peer.state == PeerState.connected;

      dots.add(
        Transform.translate(
          offset: Offset(pos.dx.w, pos.dy.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isSelected ? 18.w : 14.w,
                height: isSelected ? 18.w : 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? Colors.green
                      : isSelected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF06B6D4),
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected
                              ? Colors.green
                              : const Color(0xFF06B6D4))
                          .withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                peer.endpointName.split(' ').first, // first name only
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

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton.icon(
        onPressed: _isScanning ? _stopScan : _startScan,
        icon: Icon(
          _isScanning ? Icons.stop : Icons.radar,
          size: 20.sp,
          color: Colors.white,
        ),
        label: Text(
          _isScanning ? 'Stop Scanning' : 'Scan for Nearby Devices',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isScanning ? Colors.grey[700] : const Color(0xFFDC2626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildPeerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.devices_other,
                size: 16.sp, color: Colors.grey[600]),
            SizedBox(width: 6.w),
            Text(
              _isScanning
                  ? 'Searching for nearby devices…'
                  : 'Nearby Devices',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            if (_isScanning) ...[
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
    final isSelected = peer.endpointId == _selectedEndpointId;
    final isConnecting = peer.state == PeerState.connecting;
    final isConnected = peer.state == PeerState.connected;
    final isSending = _transfer.state == TransferState.sending &&
        peer.endpointId == _selectedEndpointId;
    final isDone = _transfer.state == TransferState.done &&
        peer.endpointId == _selectedEndpointId;

    Color stateColor() {
      if (isConnected || isDone) return Colors.green;
      if (isConnecting || isSending) return const Color(0xFFF59E0B);
      return const Color(0xFF06B6D4);
    }

    String stateLabel() {
      if (isDone) return 'Sent';
      if (isSending) return 'Sending…';
      if (isConnecting) return 'Connecting…';
      if (isConnected) return 'Connected';
      return 'Tap to send';
    }

    IconData stateIcon() {
      if (isDone) return Icons.check_circle;
      if (isSending || isConnecting) return Icons.sync;
      if (isConnected) return Icons.bluetooth_connected;
      return Icons.send;
    }

    return GestureDetector(
      onTap: (isConnecting || isSending || isDone)
          ? null
          : () => _sendToPeer(peer.endpointId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected
              ? stateColor().withOpacity(0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? stateColor().withOpacity(0.4)
                : Colors.grey.shade200,
            width: isSelected ? 1.5.w : 1.w,
          ),
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
            // Avatar
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
            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.endpointName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
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
            // Action icon
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
              Icon(
                stateIcon(),
                color: stateColor(),
                size: 22.sp,
              ),
          ],
        ),
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
