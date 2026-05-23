import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

/// Relay statuses for a queued report.
///
/// pending   → saved locally, not yet relayed or uploaded
/// relayed   → handed off to a peer device via P2P; awaiting upload by that peer
/// uploaded  → successfully sent to MongoDB / backend
/// failed    → upload attempted but failed (will retry)
enum RelayStatus { pending, relayed, uploaded, failed }

/// A thin wrapper that adds relay metadata on top of an existing emergency report.
class RelayEntry {
  final String reportId;
  final Map<String, dynamic> report; // the original report map
  RelayStatus status;
  final DateTime createdAt;
  DateTime updatedAt;
  int hopCount;
  List<Map<String, dynamic>> relayChain; // [{deviceId, deviceName, timestamp}]
  int uploadAttempts;
  String? lastError;

  RelayEntry({
    required this.reportId,
    required this.report,
    this.status = RelayStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.hopCount = 0,
    List<Map<String, dynamic>>? relayChain,
    this.uploadAttempts = 0,
    this.lastError,
  }) : relayChain = relayChain ?? [];

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'report': report,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hopCount': hopCount,
      'relayChain': relayChain,
      'uploadAttempts': uploadAttempts,
      if (lastError != null) 'lastError': lastError,
    };
  }

  factory RelayEntry.fromMap(Map<dynamic, dynamic> raw) {
    // Hive may give back Map<dynamic,dynamic> – normalise keys first
    final m = _normalise(raw);

    RelayStatus parseStatus(String s) {
      return RelayStatus.values.firstWhere(
        (e) => e.name == s,
        orElse: () => RelayStatus.pending,
      );
    }

    List<Map<String, dynamic>> parseChain(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => e is Map ? _normalise(e) : <String, dynamic>{})
            .toList();
      }
      return [];
    }

    return RelayEntry(
      reportId: m['reportId']?.toString() ?? '',
      report: m['report'] is Map
          ? _normalise(m['report'] as Map)
          : <String, dynamic>{},
      status: parseStatus(m['status']?.toString() ?? 'pending'),
      createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      hopCount: (m['hopCount'] as num?)?.toInt() ?? 0,
      relayChain: parseChain(m['relayChain']),
      uploadAttempts: (m['uploadAttempts'] as num?)?.toInt() ?? 0,
      lastError: m['lastError']?.toString(),
    );
  }

  /// Deep-converts Map<dynamic,dynamic> → Map<String,dynamic> recursively.
  static Map<String, dynamic> _normalise(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      final key = k.toString();
      if (v is Map) {
        out[key] = _normalise(v);
      } else if (v is List) {
        out[key] = v.map((e) => e is Map ? _normalise(e) : e).toList();
      } else {
        out[key] = v;
      }
    });
    return out;
  }
}

/// Manages the relay queue stored in a dedicated Hive box.
///
/// Usage:
///   await RelayQueueManager.init();
///   await RelayQueueManager.enqueue(report);
///   final pending = RelayQueueManager.getPending();
class RelayQueueManager {
  // ── Box setup ──────────────────────────────────────────────────────────────

  static const String _boxName = 'relay_queue';
  static Box<Map>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static Box<Map> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
          'RelayQueueManager not initialised. Call RelayQueueManager.init() first.');
    }
    return _box!;
  }

  // ── Write operations ───────────────────────────────────────────────────────

  /// Adds a new report to the relay queue with [RelayStatus.pending].
  /// Safe to call multiple times – duplicate [reportId]s are silently ignored.
  static Future<void> enqueue(Map<String, dynamic> report) async {
    final id = report['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('report must contain a non-empty "id" field');
    }

    // Deduplication – don't queue the same report twice
    if (_findKeyById(id) != null) return;

    final entry = RelayEntry(
      reportId: id,
      report: report,
      status: RelayStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _safeBox.add(entry.toMap());
  }

  /// Adds an incoming relayed report (received from a peer device).
  /// Enriches [relayChain] with [peerInfo] before storing.
  static Future<void> enqueueRelayed({
    required Map<String, dynamic> report,
    required Map<String, dynamic> peerInfo,
  }) async {
    final id = report['id']?.toString();
    if (id == null || id.isEmpty) return;

    if (_findKeyById(id) != null) return; // already have it

    final chain = List<Map<String, dynamic>>.from(
      (report['relayChain'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    )..add({
        ...peerInfo,
        'receivedAt': DateTime.now().toIso8601String(),
      });

    final entry = RelayEntry(
      reportId: id,
      report: {...report, 'relayChain': chain},
      status: RelayStatus.pending,
      hopCount: (report['relayHops'] as num?)?.toInt() ?? chain.length,
      relayChain: chain,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _safeBox.add(entry.toMap());
  }

  /// Marks a report as successfully uploaded to the server.
  static Future<void> markAsUploaded(String reportId) async {
    await _updateStatus(reportId, RelayStatus.uploaded);
  }

  /// Marks a report as relayed to a peer (intermediate hop, not yet uploaded).
  static Future<void> markAsRelayed(
      String reportId, Map<String, dynamic> peerInfo) async {
    final key = _findKeyById(reportId);
    if (key == null) return;

    final raw = _safeBox.get(key);
    if (raw == null) return;

    final entry = RelayEntry.fromMap(raw);
    entry.status = RelayStatus.relayed;
    entry.hopCount++;
    entry.relayChain.add({
      ...peerInfo,
      'relayedAt': DateTime.now().toIso8601String(),
    });
    entry.updatedAt = DateTime.now();

    await _safeBox.put(key, entry.toMap());
  }

  /// Records a failed upload attempt; bumps [uploadAttempts].
  /// Pass [permanent] = true for unrecoverable failures (e.g. HTTP 400) — sets
  /// [uploadAttempts] above the retry threshold so the entry is never retried.
  static Future<void> markAsFailed(String reportId, String error,
      {bool permanent = false}) async {
    final key = _findKeyById(reportId);
    if (key == null) return;

    final raw = _safeBox.get(key);
    if (raw == null) return;

    final entry = RelayEntry.fromMap(raw);
    entry.status = RelayStatus.failed;
    entry.uploadAttempts = permanent ? 999 : entry.uploadAttempts + 1;
    entry.lastError = error;
    entry.updatedAt = DateTime.now();

    await _safeBox.put(key, entry.toMap());
  }

  /// Resets a [RelayStatus.failed] entry back to [RelayStatus.pending]
  /// so the internet checker will retry it.
  static Future<void> requeueFailed(String reportId) async {
    await _updateStatus(reportId, RelayStatus.pending);
  }

  // ── Read operations ────────────────────────────────────────────────────────

  /// All reports that still need to be uploaded (pending + failed with
  /// fewer than [maxAttempts] retries).
  static List<RelayEntry> getPending({int maxAttempts = 5}) {
    return _allEntries()
        .where((e) =>
            e.status == RelayStatus.pending ||
            (e.status == RelayStatus.failed &&
                e.uploadAttempts < maxAttempts))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// All reports marked [RelayStatus.relayed] (peer received them but may not
  /// have uploaded yet – useful for UI display).
  static List<RelayEntry> getRelayed() {
    return _allEntries()
        .where((e) => e.status == RelayStatus.relayed)
        .toList();
  }

  /// All entries regardless of status – useful for a history/debug view.
  static List<RelayEntry> getAll() => _allEntries();

  /// How many reports are waiting to be uploaded.
  static int get pendingCount => getPending().length;

  /// Whether there is anything that needs uploading right now.
  static bool get hasPending => pendingCount > 0;

  // ── Maintenance ────────────────────────────────────────────────────────────

  /// Removes all uploaded entries older than [olderThan] to keep Hive lean.
  static Future<void> pruneUploaded({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final keysToDelete = <dynamic>[];

    for (final key in _safeBox.keys) {
      final raw = _safeBox.get(key);
      if (raw == null) continue;
      final entry = RelayEntry.fromMap(raw);
      if (entry.status == RelayStatus.uploaded &&
          entry.updatedAt.isBefore(cutoff)) {
        keysToDelete.add(key);
      }
    }

    await _safeBox.deleteAll(keysToDelete);
  }

  /// Wipes the entire relay queue (use with care).
  static Future<void> clear() async => _safeBox.clear();

  // ── Serialise a [RelayEntry] for P2P transfer ──────────────────────────────

  /// Returns the raw [report] map enriched with relay metadata,
  /// ready to be JSON-encoded and sent over Nearby Connections.
  static Map<String, dynamic> prepareForTransfer(RelayEntry entry) {
    return {
      ...entry.report,
      'relayChain': entry.relayChain,
      'relayHops': entry.hopCount,
      'relayStatus': entry.status.name,
    };
  }

  /// Reconstructs a [RelayEntry] from a JSON string received over P2P.
  /// Returns `null` if parsing fails.
  static RelayEntry? fromTransferJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return null;
      final report = Map<String, dynamic>.from(decoded);
      final id = report['id']?.toString();
      if (id == null || id.isEmpty) return null;

      return RelayEntry(
        reportId: id,
        report: report,
        status: RelayStatus.pending,
        hopCount:
            (report['relayHops'] as num?)?.toInt() ?? 0,
        relayChain: _parseChain(report['relayChain']),
        createdAt: DateTime.tryParse(
                report['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static List<RelayEntry> _allEntries() {
    final entries = <RelayEntry>[];
    for (final key in _safeBox.keys) {
      final raw = _safeBox.get(key);
      if (raw != null) {
        try {
          entries.add(RelayEntry.fromMap(raw));
        } catch (_) {
          // skip malformed entries
        }
      }
    }
    return entries;
  }

  /// Returns the Hive box key for a given [reportId], or `null` if not found.
  static dynamic _findKeyById(String reportId) {
    for (final key in _safeBox.keys) {
      final raw = _safeBox.get(key);
      if (raw == null) continue;
      if (raw['reportId']?.toString() == reportId) return key;
    }
    return null;
  }

  static Future<void> _updateStatus(
      String reportId, RelayStatus newStatus) async {
    final key = _findKeyById(reportId);
    if (key == null) return;

    final raw = _safeBox.get(key);
    if (raw == null) return;

    final entry = RelayEntry.fromMap(raw);
    entry.status = newStatus;
    entry.updatedAt = DateTime.now();

    await _safeBox.put(key, entry.toMap());
  }

  static List<Map<String, dynamic>> _parseChain(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e is Map
              ? RelayEntry._normalise(e)
              : <String, dynamic>{})
          .toList();
    }
    return [];
  }
}
