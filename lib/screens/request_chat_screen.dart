import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class RequestChatScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;
  /// 'requester' = Person A (owns the request), 'pledger' = Person B (accepted pledge)
  final String? participantRole;

  const RequestChatScreen({
    super.key,
    required this.requestId,
    this.requestData,
    this.participantRole,
  });

  @override
  State<RequestChatScreen> createState() => _RequestChatScreenState();
}

class _RequestChatScreenState extends State<RequestChatScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  IO.Socket? _socket;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _request;
  bool _loadingMessages = true;
  bool _sending = false;
  bool _actionLoading = false;
  String? _userId;
  String? _userName;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _request = widget.requestData;
    _init();
  }

  Future<void> _init() async {
    _userId = await _auth.getUserId();
    final userData = await _auth.getUserData();
    _userName = userData?['name'] as String?
        ?? userData?['displayName'] as String?
        ?? 'User';
    _userRole = userData?['role'] as String? ?? 'resident';
    if (mounted) {
      _initSocket();
      await Future.wait([_fetchMessages(), _refreshRequest()]);
    }
  }

  // Extracts a plain string ID from either a String or a Mongoose {"$oid": "..."} object.
  static String? _extractId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return (value[r'$oid'] ?? value['_id'])?.toString();
    return value.toString();
  }

  void _initSocket() {
    // forceNew avoids reusing a cached/disposed manager when the chat is
    // re-opened; polling is kept as a fallback so live updates still work on
    // networks where the websocket upgrade is blocked. Handlers are registered
    // BEFORE connect() so no early event is missed.
    _socket = IO.io(
      ApiService.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    _socket!.onConnect((_) {
      if (_userId != null) {
        _socket!.emit('join', {'userId': _userId});
      }
      // (Re)join the request room on every connect AND reconnect so we keep
      // receiving live messages after a dropped connection.
      _socket!.emit('join_request', {'requestId': widget.requestId});
    });
    _socket!.on('new_message', (data) {
      if (!mounted) return;
      Map<String, dynamic>? msg;
      if (data is Map) {
        msg = data['message'] != null
            ? Map<String, dynamic>.from(data['message'] as Map)
            : Map<String, dynamic>.from(data);
      }
      if (msg == null) return;
      // Skip the echo of our own message — it's already shown optimistically
      // and replaced with the real one by _sendMessage. Normalize the id so a
      // String or {"$oid": "..."} shape both compare correctly.
      final senderId = _extractId(msg['senderId']);
      if (senderId != null && senderId == _userId) return;
      // Safety net: never append a message we already have.
      final msgId = _extractId(msg['_id']);
      if (msgId != null && _messages.any((m) => _extractId(m['_id']) == msgId)) return;
      setState(() { _messages.add(msg!); });
      _scrollToBottom();
    });
    _socket!.on('request_delivered', (_) {
      if (mounted) _refreshRequest();
    });
    _socket!.on('community_request_updated', (_) {
      if (mounted) _refreshRequest();
    });
    _socket!.connect();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await _api.authenticatedGet('/api/community/requests/${widget.requestId}/messages');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(body['messages'] ?? []);
            _loadingMessages = false;
          });
          _scrollToBottom();
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          setState(() { _loadingMessages = false; });
          _showAlert('Access Denied', 'You don\'t have access to this chat thread.');
        }
      } else {
        if (mounted) setState(() { _loadingMessages = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingMessages = false; });
    }
  }

  Future<void> _refreshRequest() async {
    try {
      // Try requester endpoint first.
      final resp1 = await _api.authenticatedGet('/api/community/requests/mine');
      if (resp1.statusCode == 200) {
        final body = jsonDecode(resp1.body);
        final list = (body is Map) ? (body['requests'] as List? ?? []) : (body is List ? body : []);
        final found = list.cast<Map>().firstWhere(
          (r) => r['_id']?.toString() == widget.requestId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty && mounted) {
          setState(() { _request = Map<String, dynamic>.from(found); });
          return;
        }
      }
      // Fall back to pledger endpoint (Person B).
      final resp2 = await _api.authenticatedGet('/api/community/pledges/mine');
      if (resp2.statusCode == 200) {
        final body = jsonDecode(resp2.body);
        final list = (body is Map) ? (body['requests'] as List? ?? []) : (body is List ? body : []);
        final found = list.cast<Map>().firstWhere(
          (r) => r['_id']?.toString() == widget.requestId,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty && mounted) {
          setState(() { _request = Map<String, dynamic>.from(found); });
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (text.length > 1000) {
      _showAlert('Too Long', 'Message must be 1000 characters or less.');
      return;
    }

    setState(() { _sending = true; });
    _inputController.clear();

    // Optimistic update
    final optimistic = {
      '_id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'senderId': _userId,
      'senderName': _userName ?? 'You',
      'senderRole': _userRole ?? 'resident',
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() { _messages.add(optimistic); });
    _scrollToBottom();

    try {
      final response = await _api.authenticatedPost(
        '/api/community/requests/${widget.requestId}/messages',
        {'text': text},
      );
      if (response.statusCode == 201) {
        // Replace optimistic message with real one from response
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final realMsg = body['message'] as Map<String, dynamic>?;
        if (realMsg != null && mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m['_id'] == optimistic['_id']);
            if (idx >= 0) _messages[idx] = realMsg;
          });
        }
      } else {
        // Remove optimistic message on failure
        if (mounted) {
          setState(() { _messages.removeWhere((m) => m['_id'] == optimistic['_id']); });
          _inputController.text = text;
          if (response.statusCode == 403) {
            _showAlert('Not Allowed', 'You don\'t have permission to message in this thread.');
          } else {
            _showAlert('Error', 'Failed to send message. Please try again.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _messages.removeWhere((m) => m['_id'] == optimistic['_id']); });
        _inputController.text = text;
        _showAlert('Error', 'Failed to send message: $e');
      }
    } finally {
      if (mounted) setState(() { _sending = false; });
    }
  }

  Future<void> _markDelivered() async {
    setState(() { _actionLoading = true; });
    try {
      final response = await _api.authenticatedPatch(
        '/api/community/requests/${widget.requestId}/deliver',
        {},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as delivered! Waiting for requester to confirm.'),
            backgroundColor: ET_GREEN,
          ),
        );
        await _refreshRequest();
      } else if (response.statusCode == 400) {
        _showAlert('Already Marked', 'This request has already been marked as delivered.');
      } else {
        _showAlert('Error', 'Failed to mark as delivered (${response.statusCode}).');
      }
    } catch (e) {
      _showAlert('Error', 'Error: $e');
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  Future<void> _confirmReceipt() async {
    setState(() { _actionLoading = true; });
    try {
      final response = await _api.authenticatedPatch(
        '/api/community/requests/${widget.requestId}/confirm',
        {},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt confirmed! Request marked as fulfilled.'),
            backgroundColor: ET_GREEN,
          ),
        );
        await _refreshRequest();
      } else {
        _showAlert('Error', 'Failed to confirm receipt (${response.statusCode}).');
      }
    } catch (e) {
      _showAlert('Error', 'Error: $e');
    } finally {
      if (mounted) setState(() { _actionLoading = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isRequester {
    if (widget.participantRole == 'requester') return true;
    if (widget.participantRole == 'pledger') return false;
    // Fallback: compare IDs when no role hint was passed
    final req = _request;
    if (req == null || _userId == null) return false;
    final ownerId = _extractId(req['userId'])
        ?? _extractId(req['requesterId'])
        ?? _extractId(req['user']);
    return ownerId == _userId;
  }

  bool get _isPledger {
    if (widget.participantRole == 'pledger') return true;
    if (widget.participantRole == 'requester') return false;
    // Fallback: compare IDs when no role hint was passed
    final req = _request;
    if (req == null || _userId == null) return false;
    return _extractId(req['matchedPledgerId']) == _userId;
  }

  @override
  Widget build(BuildContext context) {
    final req = _request;
    final status = req?['status'] as String? ?? 'matched';
    final deliveredAt = req?['deliveredAt'];
    final isMatched = status == 'matched';
    final isFulfilled = status == 'fulfilled';
    final isClosed = isFulfilled || status == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                req?['itemDescription'] ?? req?['resourceName'] ?? 'Chat',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                req?['barangay'] ?? '',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Privacy disclaimer — messages are visible to CDRRMO/admins.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            color: ET_BLUE.withOpacity(0.06),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: ET_BLUE),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Messages in this chat can be viewed by CDRRMO for your safety.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: ET_BLUE, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (isFulfilled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: ET_GREEN.withOpacity(0.08),
              child: const Text(
                'This request has been fulfilled. Thank you!',
                textAlign: TextAlign.center,
                style: TextStyle(color: ET_GREEN, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),

          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation!', style: TextStyle(color: ET_GRAY)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMine = _extractId(msg['senderId']) == _userId;
                          final role = msg['senderRole'] as String? ?? '';
                          final isAdmin = role == 'admin' || role == 'barangay_official';
                          return _ChatBubble(message: msg, isMine: isMine, isAdmin: isAdmin);
                        },
                      ),
          ),

          // Action buttons
          if (isMatched) ...[
            if (_isPledger && deliveredAt == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _markDelivered,
                    icon: _actionLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.local_shipping, size: 18),
                    label: const Text("I've Delivered It"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ET_GREEN,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            if (_isPledger && deliveredAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: ET_GREEN.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ET_GREEN.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: ET_GREEN),
                      SizedBox(width: 6),
                      Text('Delivery marked — waiting for confirmation', style: TextStyle(color: ET_GREEN, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            if (_isRequester && deliveredAt == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: ET_GRAY.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ET_GRAY.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, size: 16, color: ET_GRAY),
                      SizedBox(width: 6),
                      Text('Waiting for your helper to deliver...', style: TextStyle(color: ET_GRAY, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            if (_isRequester && deliveredAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _confirmReceipt,
                    icon: _actionLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle, size: 18),
                    label: const Text('Confirm Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ET_BLUE,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
          ],

          // Message input
          if (!isClosed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 1000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _sending ? ET_GRAY : ET_BLUE,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final bool isAdmin;

  const _ChatBubble({required this.message, required this.isMine, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final text = message['text'] as String? ?? '';
    final senderName = message['senderName'] as String? ?? '';
    final createdAt = message['createdAt'] as String? ?? '';
    DateTime? time;
    try { time = DateTime.parse(createdAt).toLocal(); } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: isAdmin ? ET_RED.withOpacity(0.12) : ET_BLUE.withOpacity(0.1),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 16,
                color: isAdmin ? ET_RED : ET_BLUE,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ET_GRAY)),
                        if (isAdmin) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: ET_RED.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('CDRRMO', style: TextStyle(fontSize: 9, color: ET_RED, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? ET_BLUE
                        : isAdmin
                            ? ET_RED.withOpacity(0.06)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: ET_GRAY),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
