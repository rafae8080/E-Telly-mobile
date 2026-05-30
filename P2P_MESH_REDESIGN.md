# P2P Mesh Redesign — Architecture & Implementation Plan

> **Purpose:** Documents what is wrong with the current P2P relay, why, and exactly what to change.
> This file is the single source of truth. Read this before touching any P2P-related file.

---

## The Problem in One Sentence

The current P2P implementation is a **manual send tool** — it requires the user to navigate to a screen, tap scan, and tap a peer. It is not a mesh. Reports do not route automatically. There is no routing preference for peers who can reach the barangay server.

---

## How the System Is Supposed to Work (Full Flow)

### Total Internet Shutdown Scenario

```
Barangay Hall
  └─ Laptop running Express server (192.168.1.100:5000)
  └─ WiFi router (no internet) broadcasting: ETelly-BagongNayon
       └─ Phones in WiFi range → submit directly to 192.168.1.100:5000
       └─ Phones out of WiFi range → need P2P mesh relay

Far Away (out of WiFi range)
  [Phone A] — no internet, not on barangay WiFi
  Submits report → queued locally → P2P advertising starts automatically

Near Barangay Hall (in WiFi range)
  [Phone B] — connected to ETelly-BagongNayon WiFi
  Has no internet but CAN reach 192.168.1.100:5000 (same local network)
  Advertises as _LOCAL

Relay:
  Phone A discovers Phone B (_LOCAL)
  → Auto-connects (no user tap needed)
  → Sends report to Phone B
  
  Phone B receives report
  → EndpointResolver returns http://192.168.1.100:5000
  → InternetCheckerService uploads to local server
  → source: 'mesh_relay'
  
  Barangay dashboard shows the report immediately ✅
  When internet returns → local server syncs to MongoDB Atlas ✅
```

### The Key Bridge: EndpointResolver

`EndpointResolver.getBaseUrl()` is the function that makes this work. It does NOT only detect internet — it also detects the barangay local WiFi:

```
Is phone on ETelly-* WiFi SSID?
  YES → ping 192.168.1.100:5000/api/health (3s timeout)
    → server responds → return "http://192.168.1.100:5000"   ← LOCAL, no internet needed
  NO → check internet → cloud URL or empty string (offline)
```

A phone on the barangay's local WiFi can reach the server **without internet**. The P2P mesh gets reports from phones too far from the router to phones near the router.

### Store-Carry-Forward (nobody on WiFi yet)

If no phone is currently on barangay WiFi:

```
Phone A → sends to Phone B (both _OFFLINE)
Phone B carries the report while walking
Phone B enters barangay WiFi range → joins ETelly-BagongNayon
InternetCheckerService detects _LOCAL on connectivity change
→ auto-uploads all queued reports to 192.168.1.100:5000
```

This is the **carry** in store-carry-forward DTN (Delay Tolerant Networking).

---

## What Exists and What Is Wrong

### What Exists (Correct, Keep)

| Component | File | Status |
|-----------|------|--------|
| Nearby Connections P2P transport | `p2p_relay_service.dart` | Correct technology |
| Offline queue with hopCount, relayChain | `relay_queue_manager.dart` | Well-designed |
| Auto-upload when internet/local detected | `internet_checker_service.dart` | Works correctly |
| Server selection (local vs cloud vs offline) | `endpoint_resolver.dart` | Correct logic |

### What Is Wrong (Must Change)

| Problem | Location | Impact |
|---------|----------|--------|
| Manual peer selection — user must tap a peer | `p2p_relay_screen.dart` | Unusable in disaster |
| No internet-aware routing — all peers look identical | `p2p_relay_service.dart:_onEndpointFound()` | Cannot prefer barangay-connected peers |
| No auto-trigger — user must navigate to P2P screen | `report_emergency_screen.dart` | Too many steps |
| No hop chain forwarding — received reports not re-advertised | `p2p_relay_service.dart:_onPayloadReceived()` | Relay chain breaks |
| No hop limit enforcement — hopCount tracked but never checked | `p2p_relay_service.dart:_sendPendingReports()` | Potential infinite relay |

---

## The Redesign

### Three Core Changes

1. **Connectivity Suffix** — devices advertise their connectivity level in the endpoint name
2. **Auto-Relay Controller** — new singleton that drives relay automatically
3. **P2P Screen → Status Display** — screen shows state, does not drive it

### Connectivity Suffix Pattern

When a device starts advertising via Nearby Connections, it appends its connectivity level:

| Suffix | Meaning | Priority |
|--------|---------|----------|
| `_ONLINE` | Has cloud internet (can upload to Atlas) | Highest |
| `_LOCAL` | On ETelly-* WiFi (can upload to 192.168.1.100) | High |
| `_OFFLINE` | No connectivity (can relay via P2P only) | Low |

Examples:
- `Juan Dela Cruz_LOCAL` → Juan is near the barangay hall on local WiFi
- `Maria Santos_ONLINE` → Maria has mobile internet
- `Pedro Reyes_OFFLINE` → Pedro has no connectivity

Priority when auto-connecting: **ONLINE > LOCAL > OFFLINE**

Connecting to an OFFLINE peer is still useful — they may carry the report and later find connectivity, or relay to a fourth peer who has connectivity.

---

## Files to Change

### NEW FILE: `lib/services/p2p_auto_relay_controller.dart`

**Role:** Orchestration brain. Drives the auto-relay lifecycle. Does not own any Nearby Connections state.

**Entry point:** `P2PAutoRelayController.instance.onReportEnqueued()` — called from `report_emergency_screen.dart` after every `RelayQueueManager.enqueue()`.

**Core logic:**

```
onReportEnqueued():
  url = EndpointResolver.getBaseUrl()
  if url is not empty:
    InternetCheckerService.forceFlushIfOnline()   // upload directly, skip P2P
  else:
    _activate()                                    // start P2P

_activate():
  resolve own suffix via EndpointResolver
  wire callbacks on P2PRelayService
  call P2PRelayService.startAdvertisingAndDiscovery(suffix: _OFFLINE/_LOCAL/_ONLINE)
  start 10-min auto-stop timer

onPeerDiscovered(peer):
  if no pending reports → do nothing
  if already connecting → skip (guard)
  else → P2PRelayService.connectAndSend(peer.endpointId)
  (priority: peer.connectivity == _ONLINE/_LOCAL wins over _OFFLINE)

onReportsReceived():
  url = EndpointResolver.getBaseUrl()
  if url not empty:
    InternetCheckerService.forceFlushIfOnline()   // upload now
  else:
    stay advertising                               // hop chain continues
  _isConnecting = false                            // allow next peer
```

**Exposed state (for UI):**
```dart
ValueNotifier<int> pendingCountNotifier
ValueNotifier<bool> isActiveNotifier
ValueNotifier<String> statusMessageNotifier
```

**Auto-stop:** After 10 minutes of no peer activity, stops advertising to save battery. Resets timer on every peer discovery event.

---

### MODIFY: `lib/services/p2p_relay_service.dart`

**1. Add `ConnectivitySuffix` enum + helper functions**

```dart
enum ConnectivitySuffix { online, local, offline }

ConnectivitySuffix parseConnectivitySuffix(String name) {
  if (name.endsWith('_ONLINE')) return ConnectivitySuffix.online;
  if (name.endsWith('_LOCAL'))  return ConnectivitySuffix.local;
  return ConnectivitySuffix.offline;
}

String stripConnectivitySuffix(String name) {
  for (final s in ['_ONLINE', '_LOCAL', '_OFFLINE']) {
    if (name.endsWith(s)) return name.substring(0, name.length - s.length);
  }
  return name;
}
```

**2. Add `connectivity` field and `displayName` getter to `PeerDevice`**

```dart
class PeerDevice {
  // ... existing fields ...
  ConnectivitySuffix connectivity;            // NEW
  String get displayName => stripConnectivitySuffix(endpointName);  // NEW
}
```

**3. Add two new callbacks (alongside existing `onPeersChanged`, `onTransferProgress`)**

```dart
void Function(PeerDevice peer)? onPeerDiscoveredAuto;
void Function()? onReportsReceivedForRelay;
```

**4. Change `startAdvertisingAndDiscovery()` to accept and broadcast the suffix**

```dart
Future<void> startAdvertisingAndDiscovery({
  ConnectivitySuffix connectivitySuffix = ConnectivitySuffix.offline,
}) async {
  final advertisedName = '${_localDeviceName}_${connectivitySuffix.name.toUpperCase()}';
  // Use advertisedName in both Nearby().startAdvertising() and Nearby().startDiscovery()
}
```

**5. In `_onEndpointFound()` — parse the suffix, fire new callback**

```dart
void _onEndpointFound(String id, String name, String serviceId) {
  final peer = PeerDevice(
    endpointId: id,
    endpointName: name,
    connectivity: parseConnectivitySuffix(name),   // NEW
  );
  _peers[id] = peer;
  _notifyPeersChanged();
  onPeerDiscoveredAuto?.call(peer);                 // NEW → wakes controller
}
```

**6. In `_sendPendingReports()` (line 311) — enforce hop limit**

Add at the very start:

```dart
const int maxHops = 3;
final pending = RelayQueueManager.getPending()
    .where((e) => e.hopCount < maxHops)
    .toList();

if (pending.isEmpty) {
  onTransferProgress?.call(const TransferProgress(
    state: TransferState.done,
    message: 'No eligible reports (hop limit reached or queue empty).',
  ));
  await disconnect(endpointId);
  return;
}
// Use `pending` list throughout the rest of the method
```

**7. In `_onPayloadReceived()` — replace direct flush call with callback**

After `onReportReceived?.call(entry.reportId)`, replace any `InternetCheckerService.instance.forceFlushIfOnline()` with:

```dart
onReportsReceivedForRelay?.call();   // controller decides what to do
```

---

### MODIFY: `lib/services/relay_queue_manager.dart`

Add after line 267:

```dart
/// Reports eligible for P2P relay (under the hop limit).
static List<RelayEntry> getPendingEligibleForRelay({int maxHops = 3}) =>
    getPending().where((e) => e.hopCount < maxHops).toList();

static bool get hasRelayableReports => getPendingEligibleForRelay().isNotEmpty;
```

No other changes.

---

### MODIFY: `lib/screens/report_emergency_screen.dart`

After line 992 (`RelayQueueManager.enqueue(report)`):

```dart
// NEW: triggers auto-relay or direct upload depending on connectivity
await P2PAutoRelayController.instance.onReportEnqueued();
```

Remove line 1004 (`InternetCheckerService.instance.forceFlushIfOnline()`) — the controller now calls it internally, removing the double-flush.

---

### MODIFY: `lib/main.dart`

Add after `RelayQueueManager.init()`:

```dart
await P2PRelayService.instance.init();  // pre-loads device name/ID at startup
```

Without this, the first report submission incurs an extra async delay while the service loads the device name.

---

### MODIFY: `lib/screens/p2p_relay_screen.dart`

**Remove:**
- `bool _isScanning` state variable
- `String? _selectedEndpointId` state variable
- The "tap peer to send" interaction
- The call to `P2PRelayService.instance.stop()` in `dispose()`

**Add:**
- `final _controller = P2PAutoRelayController.instance;`
- In `initState()`: subscribe to `pendingCountNotifier`, `isActiveNotifier`, `statusMessageNotifier`
- In `dispose()`: unsubscribe from those notifiers
- In `build()`: replace `_isScanning` with `_controller.isActiveNotifier.value`

**Replace `_buildScanButton()` with two widgets:**

1. **Auto-mode status card** (primary):
   - Shows "Auto-Relay Active" with pulsing radar when `isActiveNotifier.value == true`
   - Shows "Auto-Relay Standby" when inactive
   - Shows current `statusMessageNotifier.value` as subtitle
   - "Stop Auto-Relay" button when active

2. **Manual scan button** (secondary, `OutlinedButton`):
   - Calls `_controller.onReportEnqueued()` — for capstone demo purposes
   - Disabled when auto-relay is already active

**Update `_buildPeerTile()`** — add connectivity badge:
- `_ONLINE` → green badge labeled "ONLINE"
- `_LOCAL` → blue badge labeled "LOCAL"
- `_OFFLINE` → orange badge labeled "OFFLINE"

**Update `_buildRadarSection()`:**
- Replace `if (_isScanning)` with `if (_controller.isActiveNotifier.value)`

**Do NOT change:** Transfer status widget, peer list structure, radar visual, snackbar helpers.

---

## Hop Limit

- **Max hops: 3** — enforced in `_sendPendingReports()` before sending
- Reports at `hopCount == 3` are skipped during P2P send
- They remain in queue and will upload if the holding device eventually reaches any server

---

## Peer Priority Logic

For the capstone: connect to the **first discovered peer** (already acceptable). The controller's `_isConnecting` guard prevents double-connections.

If a peer with `_ONLINE` or `_LOCAL` is discovered while considering an `_OFFLINE` peer, prefer the higher-priority one. Simple scoring:

```dart
int _score(ConnectivitySuffix c) {
  switch (c) {
    case ConnectivitySuffix.online:  return 2;
    case ConnectivitySuffix.local:   return 1;
    case ConnectivitySuffix.offline: return 0;
  }
}
```

Connect to the highest-scoring discovered peer. Skip if `_isConnecting == true` (current transfer in progress).

---

## What Each Connectivity State Does When Receiving Reports

| Receiver State | What Happens |
|----------------|-------------|
| `_ONLINE` | InternetCheckerService uploads to MongoDB Atlas (cloud) |
| `_LOCAL` | InternetCheckerService uploads to 192.168.1.100:5000 (barangay) |
| `_OFFLINE` | Report stays in queue, device keeps advertising to find next hop |

---

## Permission Handling for Auto-Relay

The controller's `_activate()` calls `startAdvertisingAndDiscovery()` with no BuildContext — it cannot show a dialog asking the user for permissions. Handle this in `_activate()` silently using `permission_handler` (already a dependency):

```dart
Future<void> _activate() async {
  // Request permissions silently before advertising
  final statuses = await [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
  ].request();

  final allGranted = statuses.values.every(
    (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
  );

  if (!allGranted) {
    _setStatus('P2P permissions not granted. Open the P2P screen to allow them.');
    return;  // silent fail — user will see the message in the P2P screen status
  }

  // proceed with _isActive = true, _wireCallbacks(), startAdvertisingAndDiscovery()
}
```

**Practical reality:** Bluetooth and nearby permissions are sticky after first grant. The first time the user opens the P2P screen and taps "Manual Scan", permissions are granted. Every auto-relay invocation after that succeeds without user interaction. If permissions are never granted, the status notifier will show the message above and the P2P screen will surface it.

---

## End-to-End Verification

**Test 1 — Auto-trigger on submission:**
Turn off WiFi + mobile data → submit report → check debug log for `[AutoRelay] Activating.` without opening P2P screen.

**Test 2 — Connectivity suffix:**
Device A (no internet) starts relay → check Nearby advertised name ends in `_OFFLINE`. Device B (on ETelly WiFi) → check it ends in `_LOCAL`.

**Test 3 — Full relay to barangay server (no internet):**
Device A offline → Device B on ETelly WiFi → submit from A → report appears on barangay dashboard. Check `source: 'mesh_relay'` in server data.

**Test 4 — Hop limit:**
Set a report's `hopCount = 3` manually in Hive. Device A finds Device B. Verify in log: `No eligible reports (hop limit reached)`. Device B does not receive the report.

**Test 5 — Auto-stop:**
Activate relay, leave devices apart. After 10 minutes, verify log shows `[AutoRelay] Auto-stop: no activity` and advertising stops.

**Test 6 — Store-carry-forward:**
Device A sends to Device B (both offline). Walk Device B into ETelly WiFi range. Connectivity change fires. Verify report auto-uploads to local server.

---

## iOS Limitation (Accepted, Cannot Fix in Software)

iOS cannot join Android's Nearby Connections mesh. This is a Google Nearby Connections platform limitation.

iOS behavior:
- Within ETelly WiFi range → submits directly to 192.168.1.100:5000 (`direct_wifi`)
- Out of range, internet available → submits to cloud
- Out of range, no internet → queues locally, uploads when connectivity returns

iOS cannot act as a P2P relay hop for Android devices. This is documented and accepted.

---

## Summary of All Changed Files

| File | Change Type | What Changes |
|------|-------------|-------------|
| `lib/services/p2p_auto_relay_controller.dart` | **NEW** | Full auto-relay orchestrator |
| `lib/services/p2p_relay_service.dart` | Modify | Connectivity suffix, new callbacks, hop limit, `_onEndpointFound` |
| `lib/services/relay_queue_manager.dart` | Modify | Add `getPendingEligibleForRelay()`, `hasRelayableReports` |
| `lib/screens/report_emergency_screen.dart` | Modify | Call `onReportEnqueued()` after enqueue, remove double-flush |
| `lib/main.dart` | Modify | Add `P2PRelayService.instance.init()` at startup |
| `lib/screens/p2p_relay_screen.dart` | Modify | Status display, remove manual send, peer connectivity badges |
| `lib/services/internet_checker_service.dart` | No change | Already works correctly |
| `lib/services/endpoint_resolver.dart` | No change | Already works correctly |
