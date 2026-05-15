import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import '../lib/services/relay_queue_manager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); 
  // Use hive_test's in-memory setup — no real disk needed
  setUp(() async {
    await setUpTestHive();
    await RelayQueueManager.init();
  });

  tearDown(() async {
    await RelayQueueManager.clear();
    await tearDownTestHive();
  });

  // ── Enqueue ────────────────────────────────────────────────────────────────

  group('Enqueue', () {
    test('adds a report with pending status', () async {
      await RelayQueueManager.enqueue(_makeReport('001'));

      expect(RelayQueueManager.pendingCount, 1);
      expect(RelayQueueManager.getPending().first.reportId, '001');
      expect(
        RelayQueueManager.getPending().first.status,
        RelayStatus.pending,
      );
    });

    test('is idempotent — same report queued twice stays as one', () async {
      final report = _makeReport('002');
      await RelayQueueManager.enqueue(report);
      await RelayQueueManager.enqueue(report);

      expect(RelayQueueManager.pendingCount, 1);
    });

    test('multiple different reports all enqueue', () async {
      await RelayQueueManager.enqueue(_makeReport('003'));
      await RelayQueueManager.enqueue(_makeReport('004'));
      await RelayQueueManager.enqueue(_makeReport('005'));

      expect(RelayQueueManager.pendingCount, 3);
    });
  });

  // ── Upload ─────────────────────────────────────────────────────────────────

  group('Upload', () {
    test('markAsUploaded removes report from pending', () async {
      await RelayQueueManager.enqueue(_makeReport('006'));
      await RelayQueueManager.markAsUploaded('006');

      expect(RelayQueueManager.pendingCount, 0);
    });

    test('uploaded report still exists in getAll()', () async {
      await RelayQueueManager.enqueue(_makeReport('007'));
      await RelayQueueManager.markAsUploaded('007');

      final all = RelayQueueManager.getAll();
      expect(all.any((e) => e.reportId == '007'), true);
      expect(all.first.status, RelayStatus.uploaded);
    });
  });

  // ── Failure and retry ──────────────────────────────────────────────────────

  group('Failure and retry', () {
    test('markAsFailed increments uploadAttempts', () async {
      await RelayQueueManager.enqueue(_makeReport('008'));
      await RelayQueueManager.markAsFailed('008', 'network error');

      final entry = RelayQueueManager.getAll().first;
      expect(entry.uploadAttempts, 1);
      expect(entry.status, RelayStatus.failed);
    });

    test('failed report still in getPending if under maxAttempts', () async {
      await RelayQueueManager.enqueue(_makeReport('009'));
      await RelayQueueManager.markAsFailed('009', 'timeout');

      expect(RelayQueueManager.getPending().length, 1);
    });

    test('failed report drops from getPending after 5 failures', () async {
      await RelayQueueManager.enqueue(_makeReport('010'));
      for (int i = 0; i < 5; i++) {
        await RelayQueueManager.markAsFailed('010', 'error $i');
      }

      expect(RelayQueueManager.getPending().length, 0);
    });

    test('requeueFailed resets status back to pending', () async {
      await RelayQueueManager.enqueue(_makeReport('011'));
      await RelayQueueManager.markAsFailed('011', 'error');
      await RelayQueueManager.requeueFailed('011');

      final entry = RelayQueueManager.getAll().first;
      expect(entry.status, RelayStatus.pending);
    });
  });

  // ── Relay hop ──────────────────────────────────────────────────────────────

  group('Relay hop', () {
    test('markAsRelayed updates status and increments hopCount', () async {
      await RelayQueueManager.enqueue(_makeReport('012'));
      await RelayQueueManager.markAsRelayed('012', {
        'deviceId': 'device_abc',
        'deviceName': 'Juan dela Cruz',
      });

      final entry = RelayQueueManager.getAll().first;
      expect(entry.status, RelayStatus.relayed);
      expect(entry.hopCount, 1);
      expect(entry.relayChain.length, 1);
      expect(entry.relayChain.first['deviceName'], 'Juan dela Cruz');
    });

    test('enqueueRelayed stores received report with peer info', () async {
      await RelayQueueManager.enqueueRelayed(
        report: _makeReport('013'),
        peerInfo: {
          'deviceId': 'device_xyz',
          'deviceName': 'Maria Santos',
        },
      );

      expect(RelayQueueManager.pendingCount, 1);
      final entry = RelayQueueManager.getPending().first;
      expect(entry.relayChain.first['deviceName'], 'Maria Santos');
    });
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  group('Transfer serialisation', () {
    test('prepareForTransfer and fromTransferJson round-trip', () {
      final entry = RelayEntry(
        reportId: '014',
        report: _makeReport('014'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = jsonEncode(RelayQueueManager.prepareForTransfer(entry));
      final restored = RelayQueueManager.fromTransferJson(json);

      expect(restored, isNotNull);
      expect(restored!.reportId, '014');
      expect(restored.report['emergencyType'], 'flood');
    });

    test('fromTransferJson returns null for invalid json', () {
      final result = RelayQueueManager.fromTransferJson('not valid {{ json');
      expect(result, isNull);
    });

    test('fromTransferJson returns null when id field is missing', () {
      final result = RelayQueueManager.fromTransferJson(
        jsonEncode({'emergencyType': 'flood'}),
      );
      expect(result, isNull);
    });
  });

  // ── Pruning ────────────────────────────────────────────────────────────────

  group('Pruning', () {
    test('pruneUploaded removes old uploaded entries', () async {
      await RelayQueueManager.enqueue(_makeReport('015'));
      await RelayQueueManager.markAsUploaded('015');
      await RelayQueueManager.pruneUploaded(olderThan: Duration.zero);

      final all = RelayQueueManager.getAll();
      expect(all.any((e) => e.reportId == '015'), false);
    });

    test('pruneUploaded keeps pending entries untouched', () async {
      await RelayQueueManager.enqueue(_makeReport('016'));
      await RelayQueueManager.pruneUploaded(olderThan: Duration.zero);

      expect(RelayQueueManager.pendingCount, 1);
    });
  });

  // ── hasPending ─────────────────────────────────────────────────────────────

  group('hasPending flag', () {
    test('is false when queue is empty', () {
      expect(RelayQueueManager.hasPending, false);
    });

    test('is true after enqueue', () async {
      await RelayQueueManager.enqueue(_makeReport('017'));
      expect(RelayQueueManager.hasPending, true);
    });

    test('is false after all reports uploaded', () async {
      await RelayQueueManager.enqueue(_makeReport('018'));
      await RelayQueueManager.markAsUploaded('018');
      expect(RelayQueueManager.hasPending, false);
    });
  });
}

// ── Helper ─────────────────────────────────────────────────────────────────────

Map<String, dynamic> _makeReport(String id) {
  return {
    'id': id,
    'emergencyType': 'flood',
    'severity': 'High',
    'description': 'Test report $id',
    'timestamp': DateTime.now().toIso8601String(),
    'status': 'pending',
    'userData': {
      'fullName': 'Test User',
      'email': 'test@example.com',
    },
    'location': {
      'barangay': 'Barangay 1',
      'city': 'Quezon City',
    },
  };
}