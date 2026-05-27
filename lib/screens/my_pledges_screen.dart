import 'package:flutter/material.dart';
import 'dart:convert';
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'request_chat_screen.dart';
import 'login_screen.dart';

class MyPledgesScreen extends StatefulWidget {
  const MyPledgesScreen({super.key});

  @override
  State<MyPledgesScreen> createState() => _MyPledgesScreenState();
}

class _MyPledgesScreenState extends State<MyPledgesScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late TabController _tabController;

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPledges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPledges() async {
    setState(() { _loading = true; _error = null; });

    final loggedIn = await _auth.isLoggedIn();
    if (!loggedIn) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      final response = await _api.authenticatedGet('/api/community/pledges/mine');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _requests = List<Map<String, dynamic>>.from(body['requests'] ?? []);
            _loading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        print('>>> MyPledges _fetchPledges status=${response.statusCode} body=${response.body}');
        if (mounted) setState(() { _error = 'Failed to load pledges (${response.statusCode})'; _loading = false; });
      }
    } catch (e) {
      print('>>> MyPledges _fetchPledges error: $e');
      if (mounted) setState(() { _error = 'Network error. Please try again.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _byPledgeStatus(String status) {
    return _requests.where((req) {
      final pledge = req['myPledge'] as Map?;
      return pledge?['status'] == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pledges', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Declined'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPledges),
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
                    ElevatedButton(onPressed: _fetchPledges, child: const Text('Retry')),
                  ]),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PledgeList(requests: _byPledgeStatus('pending'), pledgeStatus: 'pending', onRefresh: _fetchPledges),
                    _PledgeList(requests: _byPledgeStatus('accepted'), pledgeStatus: 'accepted', onRefresh: _fetchPledges),
                    _PledgeList(requests: _byPledgeStatus('declined'), pledgeStatus: 'declined', onRefresh: _fetchPledges),
                  ],
                ),
    );
  }
}

class _PledgeList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final String pledgeStatus;
  final VoidCallback onRefresh;

  const _PledgeList({required this.requests, required this.pledgeStatus, required this.onRefresh});

  Color _categoryColor(String? cat) {
    switch ((cat ?? '').toLowerCase()) {
      case 'water': return ET_CYAN;
      case 'food': return ET_YELLOW;
      case 'clothes': return ET_GREEN;
      case 'medical': return ET_RED;
      default: return ET_GRAY;
    }
  }

  Color _badgeColor(String status) {
    switch (status) {
      case 'accepted': return ET_PURPLE;
      case 'declined': return ET_GRAY;
      default: return ET_ORANGE;
    }
  }

  String _emptyMessage(String status) {
    switch (status) {
      case 'accepted': return 'No accepted offers yet.';
      case 'declined': return 'No declined offers.';
      default: return 'No pending offers.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volunteer_activism, size: 48, color: ET_GRAY),
            const SizedBox(height: 12),
            Text(_emptyMessage(pledgeStatus), style: const TextStyle(color: ET_GRAY)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final req = requests[i];
          final myPledge = req['myPledge'] as Map? ?? {};
          final category = req['category'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: pledgeStatus == 'accepted'
                  ? const BorderSide(color: ET_PURPLE, width: 1.5)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _categoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: _categoryColor(category), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _badgeColor(pledgeStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pledgeStatus.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: _badgeColor(pledgeStatus), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    req['itemDescription'] ?? req['resourceName'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${req['barangay'] ?? ''} · requested by ${req['requesterName'] ?? 'Anonymous'}',
                    style: const TextStyle(fontSize: 12, color: ET_GRAY),
                  ),
                  if ((myPledge['message'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${myPledge['message']}"',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ET_GRAY),
                    ),
                  ],
                  if (pledgeStatus == 'accepted') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RequestChatScreen(requestId: req['_id'] ?? '', requestData: req, participantRole: 'pledger'),
                          ),
                        ).then((_) => onRefresh()),
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('Open Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ET_PURPLE,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
