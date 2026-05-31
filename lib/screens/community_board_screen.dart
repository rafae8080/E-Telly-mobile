import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'request_detail_screen.dart';

class CommunityBoardScreen extends StatefulWidget {
  const CommunityBoardScreen({super.key});

  @override
  State<CommunityBoardScreen> createState() => _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends State<CommunityBoardScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  IO.Socket? _socket;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String? _userBarangay;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetch();
  }

  Future<void> _loadUserAndFetch() async {
    final userData = await _auth.getUserData();
    _userId = await _auth.getUserId();
    if (mounted) {
      setState(() {
        _userBarangay = userData?['barangay'] as String?;
      });
    }
    await _fetchBoard();
    _initSocket();
  }

  Future<void> _fetchBoard() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final barangay = _userBarangay ?? '';
      final query = barangay.isNotEmpty ? '?barangay=${Uri.encodeComponent(barangay)}' : '';
      final response = await _api.optionalGet('/api/community/board$query');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _requests = List<Map<String, dynamic>>.from(body['requests'] ?? []);
            _loading = false;
          });
        }
      } else {
        print('>>> CommunityBoard _fetchBoard status=${response.statusCode} body=${response.body}');
        if (mounted) setState(() { _error = 'Failed to load board (${response.statusCode})'; _loading = false; });
      }
    } catch (e) {
      print('>>> CommunityBoard _fetchBoard error: $e');
      if (mounted) setState(() { _error = 'Network error. Please try again.'; _loading = false; });
    }
  }

  void _initSocket() {
    _socket = IO.io(
      ApiService.baseUrl,
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket!.connect();
    _socket!.onConnect((_) {
      if (_userId != null) _socket!.emit('join', {'userId': _userId});
    });
    _socket!.on('new_community_request', (_) { if (mounted) _fetchBoard(); });
    _socket!.on('community_request_updated', (_) { if (mounted) _fetchBoard(); });
    _socket!.on('new_pledge', (data) {
      if (!mounted) return;
      final name = (data is Map) ? (data['pledgerName'] ?? 'Someone') : 'Someone';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name offered to help!'), backgroundColor: ET_GREEN),
      );
      _fetchBoard();
    });
    _socket!.on('pledge_accepted', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your offer was accepted!'), backgroundColor: ET_GREEN),
      );
    });
    _socket!.on('pledge_declined', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another helper was chosen. Thank you for offering!')),
      );
    });
    _socket!.on('request_delivered', (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your helper says delivered — please confirm receipt!'),
          backgroundColor: ET_ORANGE,
        ),
      );
      _fetchBoard();
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'critical': return ET_RED;
      case 'high': return ET_ORANGE;
      case 'medium': return ET_BLUE;
      default: return ET_GRAY;
    }
  }

  Color _categoryColor(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'water': return ET_CYAN;
      case 'food': return ET_YELLOW;
      case 'clothing':
      case 'clothes': return ET_GREEN;
      case 'medicine':
      case 'medical': return ET_RED;
      case 'hygiene': return ET_PURPLE;
      case 'shelter': return ET_BLUE;
      default: return ET_GRAY;
    }
  }

  String _requesterLine(Map<String, dynamic> req) {
    final name = (req['requesterName'] ?? 'Anonymous').toString();
    final brgy = (req['barangay'] ?? '').toString();
    final showBrgy = brgy.isNotEmpty && brgy.toLowerCase() != 'unknown';
    return showBrgy ? '$name · $brgy' : name;
  }

  Widget _sectionHeader(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final pledgeCount = req['pledgeCount'] ?? 0;
    final priority = req['priority'] as String? ?? 'normal';
    final urgent = req['urgent'] == true;
    final category = req['category'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(requestId: req['_id'] ?? '', initialData: req),
          ),
        ).then((_) => _fetchBoard()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _categoryBadge(category, _categoryColor(category)),
                  if (urgent) ...[
                    const SizedBox(width: 6),
                    _textBadge('URGENT', ET_RED),
                  ],
                  if (priority != 'normal') ...[
                    const SizedBox(width: 6),
                    _textBadge(priority.toUpperCase(), _priorityColor(priority)),
                  ],
                  const Spacer(),
                  if (pledgeCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.people, size: 13, color: ET_GRAY),
                        const SizedBox(width: 3),
                        Text('$pledgeCount offered', style: const TextStyle(fontSize: 11, color: ET_GRAY)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(req['itemDescription'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                '${req['quantity'] ?? ''} ${req['unit'] ?? ''} needed',
                style: const TextStyle(fontSize: 13, color: ET_GRAY),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: ET_GRAY),
                  const SizedBox(width: 4),
                  Text(
                    _requesterLine(req),
                    style: const TextStyle(fontSize: 12, color: ET_GRAY),
                  ),
                ],
              ),
              if ((req['address'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 13, color: ET_GRAY),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        req['address'],
                        style: const TextStyle(fontSize: 12, color: ET_GRAY),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryBadge(String category, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(category.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _textBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People in Need', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBoard),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: ET_RED),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchBoard, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchBoard,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader('Open Needs', _requests.length, Icons.people_alt, ET_BLUE),
                      const SizedBox(height: 8),
                      if (_requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No open requests in your area.', style: TextStyle(color: ET_GRAY), textAlign: TextAlign.center),
                        )
                      else
                        ..._requests.map(_requestCard),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
