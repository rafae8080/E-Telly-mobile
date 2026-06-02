import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'request_chat_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? initialData;

  const RequestDetailScreen(
      {super.key, required this.requestId, this.initialData});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  IO.Socket? _socket;
  String? _userId;

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _myPledge;
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _request = widget.initialData;
    _loadAndCheck();
    _initSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _loadAndCheck() async {
    await _checkMyPledgeStatus();
    if (mounted)
      setState(() {
        _loading = false;
      });
  }

  /// Live updates so this view reflects the requester's decision the moment it
  /// happens — when our pledge is accepted or declined (another helper chosen),
  /// or the request's status changes — without the pledger doing anything.
  /// Mirrors the community board's socket setup.
  Future<void> _initSocket() async {
    _userId = await _auth.getUserId();
    _socket = IO.io(
      ApiService.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) {
      if (_userId != null) _socket!.emit('join', {'userId': _userId});
    });
    _socket!.on('pledge_accepted', (_) {
      if (mounted) _checkMyPledgeStatus();
    });
    _socket!.on('pledge_declined', (_) {
      if (!mounted) return;
      _checkMyPledgeStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Another helper was chosen. Thank you for offering!')),
      );
    });
    _socket!.on('community_request_updated', (_) {
      if (mounted) _checkMyPledgeStatus();
    });
  }

  Future<void> _checkMyPledgeStatus() async {
    try {
      final response =
          await _api.authenticatedGet('/api/community/pledges/mine');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = List<Map<String, dynamic>>.from(body['requests'] ?? []);
        final found = list.where((r) => r['_id'] == widget.requestId).toList();
        if (found.isNotEmpty && mounted) {
          setState(() {
            _myPledge = found.first['myPledge'] as Map<String, dynamic>?;
            // Also update request status/data from the pledge list
            final updatedReq = Map<String, dynamic>.from(found.first);
            updatedReq.remove('myPledge');
            if (_request != null) {
              _request = {..._request!, ...updatedReq};
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _withdrawPledge() async {
    setState(() {
      _actionLoading = true;
    });
    try {
      final response = await _api.authenticatedDelete(
        '/api/community/requests/${widget.requestId}/pledge',
        {},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your offer has been withdrawn.')),
          );
          setState(() {
            _myPledge = null;
          });
        }
      } else if (response.statusCode == 400) {
        _showAlert('Cannot Withdraw',
            'Cannot withdraw an accepted pledge — please contact CDRRMO.');
      } else {
        _showAlert(
            'Error', 'Failed to withdraw offer (${response.statusCode}).');
      }
    } catch (e) {
      _showAlert('Error', 'Failed to withdraw: $e');
    } finally {
      if (mounted)
        setState(() {
          _actionLoading = false;
        });
    }
  }

  /// Best-effort current location so the requester can see how far this helper
  /// is and prioritize the closest. Returns null (and the offer still goes
  /// through) if location services are off or permission is denied — helping
  /// must never be blocked by a missing permission.
  Future<Position?> _getPledgerPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  void _showPledgeForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PledgeFormSheet(
        onSubmit: (message, phone) async {
          setState(() {
            _actionLoading = true;
          });
          try {
            final position = await _getPledgerPosition();
            final response = await _api.authenticatedPost(
              '/api/community/requests/${widget.requestId}/pledge',
              {
                'message': message,
                'phone': phone,
                if (position != null) 'pledgerLat': position.latitude,
                if (position != null) 'pledgerLng': position.longitude,
              },
            );
            if (response.statusCode == 201) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Your offer was sent! The requester will be notified.'),
                    backgroundColor: ET_GREEN,
                  ),
                );
                Navigator.pop(context);
                await _checkMyPledgeStatus();
              }
            } else if (response.statusCode == 409) {
              _showAlert('Already Offered',
                  'You\'ve already offered to help with this request.');
            } else if (response.statusCode == 403) {
              _showAlert('Not Allowed',
                  'You don\'t have permission to offer on this request.');
            } else {
              _showAlert(
                  'Error', 'Failed to submit offer (${response.statusCode}).');
            }
          } catch (e) {
            _showAlert('Error', 'Failed to submit: $e');
          } finally {
            if (mounted)
              setState(() {
                _actionLoading = false;
              });
          }
        },
      ),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Color _categoryColor(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'water':
        return ET_CYAN;
      case 'food':
        return ET_YELLOW;
      case 'clothing':
      case 'clothes':
        return ET_GREEN;
      case 'medicine':
      case 'medical':
        return ET_RED;
      case 'communication':
        return ET_BLUE;
      default:
        return ET_GRAY;
    }
  }

  String _locationText(Map<String, dynamic> req) {
    final addr = (req['address'] ?? '').toString();
    if (addr.isNotEmpty) return addr;
    final brgy = (req['barangay'] ?? '').toString();
    if (brgy.isNotEmpty && brgy.toLowerCase() != 'unknown') return brgy;
    return 'Location not provided';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final req = _request;
    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Detail')),
        body: const Center(child: Text('Request not found.')),
      );
    }

    final status = req['status'] as String? ?? 'open';
    final category = req['category'] as String? ?? '';
    final pledgeStatus = _myPledge?['status'] as String?;
    final hasPledge = _myPledge != null && pledgeStatus != 'withdrawn';
    final isOpen =
        status == 'open' || status == 'pending' || status == 'approved';
    final isMatched = status == 'matched';
    final isTerminal = status == 'fulfilled' || status == 'cancelled';
    final pledgeAccepted = pledgeStatus == 'accepted';

    return Scaffold(
      appBar: AppBar(title: const Text('Request Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(
                  label: category.toUpperCase(),
                  color: _categoryColor(category),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
                if (req['urgent'] == true) ...[
                  const SizedBox(width: 8),
                  _Badge(label: 'URGENT', color: ET_RED),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              req['itemDescription'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${req['quantity'] ?? ''} ${req['unit'] ?? ''} needed',
              style: const TextStyle(fontSize: 15, color: ET_GRAY),
            ),
            const SizedBox(height: 10),
            _InfoRow(
                icon: Icons.person, text: req['requesterName'] ?? 'Anonymous'),
            _InfoRow(
              icon: Icons.location_on,
              text: _locationText(req),
            ),
            if ((req['pledgeCount'] ?? 0) > 0)
              _InfoRow(
                  icon: Icons.people,
                  text: '${req['pledgeCount']} people offered to help'),
            const SizedBox(height: 24),

            // Action area
            if (isTerminal)
              _StatusBox(
                message: status == 'fulfilled'
                    ? 'This request has been fulfilled. Thank you to everyone who helped!'
                    : 'This request has been cancelled.',
                color: status == 'fulfilled' ? ET_GREEN : ET_GRAY,
              )
            else if (isOpen && !hasPledge)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _actionLoading ? null : _showPledgeForm,
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('I Can Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ET_RED,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (pledgeStatus == 'declined')
              const _StatusBox(
                message:
                    'Another helper was chosen for this request. Your offer is now closed.',
                color: ET_GRAY,
              )
            else if (isOpen && hasPledge && pledgeStatus == 'pending') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ET_RED.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ET_RED.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _StatusBadge(status: pledgeStatus ?? 'pending'),
                    const SizedBox(height: 6),
                    const Text(
                      'Your offer is waiting for the requester\'s decision.',
                      style: TextStyle(fontSize: 13, color: ET_GRAY),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionLoading
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Withdraw Offer'),
                              content: const Text(
                                  'Are you sure you want to withdraw your offer?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _withdrawPledge();
                                  },
                                  style: TextButton.styleFrom(
                                      foregroundColor: ET_RED),
                                  child: const Text('Withdraw'),
                                ),
                              ],
                            ),
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ET_RED,
                    side: const BorderSide(color: ET_RED),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Withdraw Offer'),
                ),
              ),
            ] else if (isMatched && pledgeAccepted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestChatScreen(
                          requestId: widget.requestId,
                          requestData: req,
                          participantRole: 'pledger'),
                    ),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Go to Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ET_RED,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (isMatched)
              _StatusBox(
                message: 'This request has been matched with a helper.',
                color: ET_GREEN,
              ),
          ],
        ),
      ),
    );
  }
}

class _PledgeFormSheet extends StatefulWidget {
  final Future<void> Function(String message, String phone) onSubmit;

  const _PledgeFormSheet({required this.onSubmit});

  @override
  State<_PledgeFormSheet> createState() => _PledgeFormSheetState();
}

class _PledgeFormSheetState extends State<_PledgeFormSheet> {
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    await widget.onSubmit(
        _messageController.text.trim(), _phoneController.text.trim());
    if (mounted)
      setState(() {
        _submitting = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Offer to Help',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Text('Tell the requester how you can help.',
              style: TextStyle(color: ET_GRAY)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.location_on, size: 14, color: ET_GRAY),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Sharing your location helps the requester pick the nearest helper.',
                  style: TextStyle(fontSize: 11, color: ET_GRAY),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Message (optional)',
              hintText: 'e.g. I have extra bottled water I can bring tomorrow',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number (optional)',
              hintText: '09171234567',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ET_RED,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Offer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'open':
      case 'pending':
      case 'approved':
        color = ET_RED;
        label = 'OPEN';
        break;
      case 'matched':
        color = ET_BLUE;
        label = 'MATCHED';
        break;
      case 'fulfilled':
        color = ET_GREEN;
        label = 'FULFILLED';
        break;
      case 'accepted':
        color = ET_YELLOW;
        label = 'ACCEPTED';
        break;
      case 'declined':
        color = ET_GRAY;
        label = 'DECLINED';
        break;
      default:
        color = ET_GRAY;
        label = status.toUpperCase();
    }
    return _Badge(label: label, color: color);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: ET_GRAY),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: ET_GRAY))),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String message;
  final Color color;
  const _StatusBox({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(message,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }
}
