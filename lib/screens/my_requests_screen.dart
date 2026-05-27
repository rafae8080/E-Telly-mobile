import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants.dart';
import '../services/api_service.dart';
import 'request_chat_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _api.authenticatedGet('/api/community/requests/mine');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body is Map) ? (body['requests'] as List? ?? []) : (body is List ? body : []);
        if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(list); _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'Failed to load (${response.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Network error. Please try again.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _byStatus(String tab) {
    if (tab == 'open') {
      return _requests.where((r) {
        final s = r['status'] as String? ?? '';
        return s == 'open' || s == 'pending' || s == 'approved';
      }).toList();
    }
    return _requests.where((r) => r['status'] == tab).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Matched'),
            Tab(text: 'Fulfilled'),
            Tab(text: 'Cancelled'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRequests),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, size: 48, color: ET_RED),
                    const SizedBox(height: 12),
                    Text(_error!),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _fetchRequests, child: const Text('Retry')),
                  ]),
                )
              : TabBarView(
                  controller: _tabController,
                  children: ['open', 'matched', 'fulfilled', 'cancelled'].map((tab) =>
                    _RequestList(requests: _byStatus(tab), onRefresh: _fetchRequests),
                  ).toList(),
                ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRefresh;

  const _RequestList({required this.requests, required this.onRefresh});

  Color _categoryColor(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'water': return ET_CYAN;
      case 'food': return ET_YELLOW;
      case 'clothes': return ET_GREEN;
      case 'medical': return ET_RED;
      default: return ET_GRAY;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text('No requests in this category.', style: TextStyle(color: ET_GRAY)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final req = requests[i];
          final pledges = req['pledges'] as List? ?? [];
          final activePledgeCount = pledges.where((p) => p['status'] != 'withdrawn').length;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _categoryColor(req['category']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2, color: _categoryColor(req['category'])),
              ),
              title: Text(
                req['itemDescription'] ?? req['resourceName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${req['quantity'] ?? ''} ${req['unit'] ?? ''} · ${req['barangay'] ?? ''}'),
                  if (activePledgeCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.people, size: 12, color: ET_PURPLE),
                        const SizedBox(width: 4),
                        Text(
                          '$activePledgeCount ${activePledgeCount == 1 ? 'offer' : 'offers'}',
                          style: const TextStyle(fontSize: 12, color: ET_PURPLE, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyRequestDetailScreen(requestId: req['_id'] ?? '', initialData: req),
                ),
              ).then((_) => onRefresh()),
            ),
          );
        },
      ),
    );
  }
}

class MyRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? initialData;

  const MyRequestDetailScreen({super.key, required this.requestId, this.initialData});

  @override
  State<MyRequestDetailScreen> createState() => _MyRequestDetailScreenState();
}

class _MyRequestDetailScreenState extends State<MyRequestDetailScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _request;
  bool _loading = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _request = widget.initialData;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (mounted) setState(() { _loading = true; });
    try {
      final response = await _api.authenticatedGet('/api/community/requests/mine');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body is Map) ? (body['requests'] as List? ?? []) : (body is List ? body : []);
        final found = list.firstWhere((r) => r['_id'] == widget.requestId, orElse: () => null);
        if (found != null && mounted) {
          setState(() { _request = Map<String, dynamic>.from(found); });
        }
      }
    } catch (_) {}
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _acceptPledge(String pledgeId) async {
    setState(() { _actionLoading = true; });
    try {
      final response = await _api.authenticatedPatch(
        '/api/community/requests/${widget.requestId}/accept-pledge',
        {'pledgeId': pledgeId},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Helper selected! Chat is now open.'), backgroundColor: ET_GREEN),
        );
        await _fetchDetail();
      } else if (response.statusCode == 400) {
        _showAlert('Error', 'This pledge is no longer available.');
      } else {
        print('>>> acceptPledge ${response.statusCode}: ${response.body}');
        _showAlert('Error', 'Failed to accept pledge (${response.statusCode}).');
      }
    } catch (e) {
      _showAlert('Error', 'Error: $e');
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  Future<void> _cancelRequest() async {
    setState(() { _actionLoading = true; });
    try {
      final response = await _api.authenticatedPatch(
        '/api/community/requests/${widget.requestId}/cancel',
        {},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled.')),
          );
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 400) {
        _showAlert('Cannot Cancel', 'This request cannot be cancelled in its current state.');
      } else {
        print('>>> cancelRequest ${response.statusCode}: ${response.body}');
        _showAlert('Error', 'Failed to cancel request (${response.statusCode}).');
      }
    } catch (e) {
      _showAlert('Error', 'Error: $e');
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Color _categoryColor(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'water': return ET_CYAN;
      case 'food': return ET_YELLOW;
      case 'clothes': return ET_GREEN;
      case 'medical': return ET_RED;
      default: return ET_GRAY;
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;
    if (req == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Request')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = req['status'] as String? ?? 'open';
    final pledges = List<Map<String, dynamic>>.from(
      (req['pledges'] as List? ?? []).where((p) => p['status'] != 'withdrawn'),
    );
    final isOpen = status == 'open' || status == 'pending' || status == 'approved';
    final isMatched = status == 'matched';
    final isTerminal = status == 'fulfilled' || status == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Request'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _Badge(label: (req['category'] ?? '').toUpperCase(), color: _categoryColor(req['category'])),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              req['itemDescription'] ?? req['resourceName'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${req['quantity'] ?? ''} ${req['unit'] ?? ''} · ${req['barangay'] ?? ''}',
              style: const TextStyle(fontSize: 14, color: ET_GRAY),
            ),
            if ((req['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(req['reason'] ?? '', style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 24),

            // Open Chat button for matched
            if (isMatched) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestChatScreen(requestId: widget.requestId, requestData: req, participantRole: 'requester'),
                    ),
                  ).then((_) => _fetchDetail()),
                  icon: const Icon(Icons.chat),
                  label: const Text('Open Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ET_PURPLE,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Pledges section
            Row(
              children: [
                const Text('Community Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (pledges.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: ET_PURPLE.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${pledges.length}', style: const TextStyle(fontSize: 12, color: ET_PURPLE, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (pledges.isEmpty)
              const Text('No offers yet.', style: TextStyle(color: ET_GRAY))
            else
              ...pledges.map((pledge) {
                final pStatus = pledge['status'] as String? ?? 'pending';
                Color badgeColor;
                switch (pStatus) {
                  case 'accepted': badgeColor = ET_PURPLE; break;
                  case 'declined': badgeColor = ET_GRAY; break;
                  default: badgeColor = ET_ORANGE;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: pStatus == 'accepted' ? const BorderSide(color: ET_PURPLE, width: 1.5) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(pledge['name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            _Badge(label: pStatus.toUpperCase(), color: badgeColor),
                          ],
                        ),
                        if ((pledge['phone'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 13, color: ET_GRAY),
                              const SizedBox(width: 4),
                              Text(pledge['phone'] ?? '', style: const TextStyle(fontSize: 12, color: ET_GRAY)),
                            ],
                          ),
                        ],
                        if ((pledge['message'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(pledge['message'] ?? '', style: const TextStyle(fontSize: 13)),
                        ],
                        if (isOpen && pStatus == 'pending') ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _actionLoading ? null : () => _acceptPledge(pledge['_id'] ?? ''),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ET_GREEN,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _actionLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Accept This Helper'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            if (!isTerminal) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _actionLoading ? null : () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Cancel Request'),
                      content: const Text('Are you sure you want to cancel this request?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
                        TextButton(
                          onPressed: () { Navigator.pop(context); _cancelRequest(); },
                          style: TextButton.styleFrom(foregroundColor: ET_RED),
                          child: const Text('Yes, Cancel'),
                        ),
                      ],
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ET_RED,
                    side: const BorderSide(color: ET_RED),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
            ],
          ],
        ),
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
        color = ET_BLUE; label = 'OPEN'; break;
      case 'matched':
        color = ET_PURPLE; label = 'MATCHED'; break;
      case 'fulfilled':
        color = ET_GREEN; label = 'FULFILLED'; break;
      case 'cancelled':
        color = ET_GRAY; label = 'CANCELLED'; break;
      default:
        color = ET_GRAY; label = status.toUpperCase();
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
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
