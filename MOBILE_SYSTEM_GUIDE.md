# E‑Telly — System Guide (Beginner‑Friendly)

> A plain‑language tour of the **E‑Telly Mobile** disaster‑response app: what it is, what
> technology it uses, *why* each technology was chosen, *how* it is built, and *where* in the
> code you can see it. Written so that a **non‑technical reader (panel, evaluator, barangay
> official)** can follow along, while still being precise enough for developers.
>
> All diagrams in this guide are **plain text** so they read the same everywhere (no special
> viewer needed).

---

## Table of Contents

1. [What is E‑Telly? (1‑minute summary)](#1-what-is-e-telly-1-minute-summary)
2. [The Big Idea: Working Even Without Internet](#2-the-big-idea-working-even-without-internet)
3. [Technology Stack — What, Why, Where](#3-technology-stack--what-why-where)
4. [Comparative Matrices — “Why this, not that?”](#4-comparative-matrices--why-this-not-that)
5. [System Architecture (Text Diagrams)](#5-system-architecture-text-diagrams)
6. [How the Core Features Work (Logic + Diagrams)](#6-how-the-core-features-work-logic--diagrams)
   - 6.1 [Submitting an Emergency Report](#61-submitting-an-emergency-report-offline-first)
   - 6.2 [The P2P “Human Mesh” Relay — Deep Dive](#62-the-p2p-human-mesh-relay--deep-dive)
   - 6.3 [Hazard‑Aware Evacuation Routing — Deep Dive](#63-hazard-aware-evacuation-routing--deep-dive-mapbox)
   - 6.4 [How Hazards Are Shown on the Map](#64-how-hazards-are-shown-on-the-map)
   - 6.5 [Alerts: From Sensor Data to Plain Language](#65-alerts-from-sensor-data-to-plain-language)
   - 6.6 [Resource Sharing](#66-resource-sharing-request--pledge--chat)
7. [Folder Structure (One Line Each)](#7-folder-structure-one-line-each)
8. [Data & Security](#8-data--security)
9. [Limitations of the System](#9-limitations-of-the-system)
10. [Possible Panel Questions (with Answers)](#10-possible-panel-questions-with-answers)
11. [Glossary](#11-glossary)

---

## 1. What is E‑Telly? (1‑minute summary)

**E‑Telly** is a mobile app for residents of **Antipolo City, Philippines**, built to help people
**before, during, and after disasters** (floods, typhoons, earthquakes, landslides, volcanic
activity, fire).

It is the **resident‑facing app** that talks to a **CDRRMO** (City Disaster Risk Reduction and
Management Office) back‑end and admin dashboard. The phone app lets a resident:

| # | Feature | What it does |
|---|---------|--------------|
| 🔔 | **Alerts** | Receive official hazard warnings (color‑coded like PAGASA: 🟡 Advisory, 🟠 Be Prepared, 🔴 Emergency / Evacuate). |
| 🧭 | **Evacuation Navigation** | Turn‑by‑turn walking directions to the nearest **safe** evacuation center, **automatically avoiding hazard zones**. |
| 📸 | **Report Emergency** | Submit a photo + location report of a hazard, **even with no internet**. |
| 🏠 | **Evacuation Centers** | See live capacity (Available / Almost Full / Full) and call the center. |
| 🤝 | **Resources** | Request relief goods or pledge/donate them, and **chat** with the other party. |
| 📋 | **Safety Tips** | Offline first‑aid, earthquake, and flood guidance (with videos). |
| 📡 | **P2P Relay** | Pass reports phone‑to‑phone when there is no signal at all (a “human mesh network”). |

The single most important design goal: **the app keeps working when the network does not.**

---

## 2. The Big Idea: Working Even Without Internet

Disasters break communication infrastructure exactly when people need it most. E‑Telly is built
around **three levels of connectivity**, and it automatically picks the best one available. This is
decided in one place: `lib/services/endpoint_resolver.dart`.

```
   ┌─────────────────────────────────────────────────────────────────────┐
   │  HOW E-TELLY DECIDES WHERE TO SEND DATA                              │
   │  (lib/services/endpoint_resolver.dart → getBaseUrl())               │
   └─────────────────────────────────────────────────────────────────────┘

   Is the phone on a barangay "ETelly-..." WiFi?
        │
        ├── YES ──► Is the local barangay server reachable? (http://192.168.x.x:5000)
        │              ├── YES ──►  🟢 LOCAL MODE  (send to barangay laptop/server)
        │              └── NO  ──►  fall through ↓
        │
        └── NO / server down
               │
               Does the phone have real internet?
                     ├── YES ──►  🔵 CLOUD MODE  (send to Heroku cloud server)
                     └── NO  ──►  🔴 OFFLINE MODE (save locally + pass phone-to-phone)
```

| Mode | When it happens | Where data goes | Code |
|------|-----------------|-----------------|------|
| 🔵 **Cloud** | Normal internet | Heroku server + MongoDB Atlas | `api_service.dart`, `endpoint_resolver.dart` |
| 🟢 **Local** | On a barangay emergency WiFi, internet is down | A laptop/server inside the barangay (`192.168.137.1` or `192.168.1.100`) | `internet_checker_service.dart` |
| 🔴 **Offline** | No internet, no local server | Saved in the phone (Hive), then relayed phone‑to‑phone | `relay_queue_manager.dart`, `p2p_relay_service.dart` |

**How each step is actually checked (so the panel can trust it):**
- *“On barangay WiFi?”* → reads the WiFi network name (SSID) and checks it starts with `ETelly-`
  (`_getWifiSsid`, needs location permission on Android).
- *“Local server reachable?”* → sends a quick `GET /api/health` to each candidate IP with a 3‑second
  timeout (`_findReachableLocalServer`).
- *“Real internet?”* → does a DNS lookup of `google.com` with a 5‑second timeout
  (`_hasRealInternet` in `internet_checker_service.dart`). This catches “WiFi connected but no actual
  internet,” which a simple connectivity check would miss.

This is what makes E‑Telly different from an ordinary “report a problem” app — it has a **fallback
plan for the fallback plan.**

---

## 3. Technology Stack — What, Why, Where

> **Legend:** **What** = the tool · **Why** = the reason it was chosen · **Where** = file(s) to look at.

### 3.1 App Framework

| What | Why | Where |
|------|-----|-------|
| **Flutter + Dart** (`pubspec.yaml`) | One codebase → Android (and later iOS). Compiles to fast native code. Huge package ecosystem. Strong UI toolkit for the responsive emergency UI. | Entire `lib/` folder; entry point `lib/main.dart` |
| **flutter_screenutil** | Makes the UI scale correctly across different phone sizes (design size 412×715). | `lib/main.dart` (`ScreenUtilInit`) |
| **provider** | Lightweight state sharing between widgets. | `lib/providers/alert_provider.dart` |

### 3.2 Maps & Navigation

| What | Why | Where |
|------|-----|-------|
| **Mapbox Navigation SDK** (`flutter_mapbox_navigation`, vendored in `packages/`) | Real **turn‑by‑turn voice navigation** with a **walking profile** (residents evacuate on foot through narrow streets, not by car). Lets us **reroute live** around hazards mid‑trip. | `lib/screens/evacuation_screen.dart` |
| **Mapbox Directions API** (called via `http`) | Returns multiple **alternative walking routes** + detailed road geometry, so the app can check which streets pass through hazards and force detours. | `_fetchMapboxAlternatives`, `_fetchMapboxRouteViaMany` in `evacuation_screen.dart` |
| **flutter_map + OpenStreetMap + latlong2** | A **free, offline‑capable** map widget used to draw hazard markers, evacuation centers, and the cached route when there is no internet for Mapbox. | `evacuation_screen.dart` (`FlutterMap` in `build()`), `lib/utils/geo_utils.dart` |
| **geolocator / geocoding** | Get the phone’s GPS location (and a live position stream) and turn coordinates into addresses. | `evacuation_screen.dart`, `resources_screen.dart` |

### 3.3 Data & Backend

| What | Why | Where |
|------|-----|-------|
| **Node/Express backend on Heroku** (external repo) | Central API for alerts, reports, evacuation centers, resources, push. | Base URL in `lib/services/api_service.dart` |
| **MongoDB Atlas** (`mongo_dart`) | The shared database. The app can talk **directly** to MongoDB as a fallback when the HTTP backend is unreachable. | `lib/dbhelper/mongodb.dart`, `lib/dbhelper/constant.dart` |
| **HTTP REST** (`http`) | Standard, simple way to call the backend endpoints. | `api_service.dart`, `alert_service.dart`, `report_service.dart` |
| **Socket.IO** (`socket_io_client`) | **Live updates** — new alerts, route changes, and resource chat appear instantly without refreshing. | `evacuation_screen.dart` (`_initLiveUpdates`), `request_chat_screen.dart` |

### 3.4 Offline Storage

| What | Why | Where |
|------|-----|-------|
| **Hive** (`hive`, `hive_flutter`) | Fast, lightweight on‑device database (no SQL needed). Caches alerts, centers, routes, reports, and the relay queue so the app works offline. | `lib/services/hive_service.dart`, `relay_queue_manager.dart`, `offline_report_storage.dart` |
| **shared_preferences** | Small key/value storage (e.g. user’s name for P2P identity). | `p2p_relay_service.dart` |

### 3.5 Identity & Notifications

| What | Why | Where |
|------|-----|-------|
| **JWT (JSON Web Token)** (`jwt_decoder`) + **flutter_secure_storage** | Securely keep the user logged in. The token is stored **encrypted** and checked for expiry on every launch. | `lib/services/auth_service.dart` |
| **Google Sign‑In** (`google_sign_in`) | One‑tap login option. | `auth_service.dart`, `google_auth_service.dart` |
| **Firebase Auth + Firebase Cloud Messaging (FCM)** | FCM **push notifications** deliver emergency alerts even when the app is closed. | `lib/services/notification_service.dart`, `lib/firebase_options.dart` |
| **flutter_local_notifications** | Shows the notification banner/sound on the device. | `notification_service.dart` |

### 3.6 Peer‑to‑Peer (the “no‑signal” superpower)

| What | Why | Where |
|------|-----|-------|
| **Nearby Connections** (`nearby_connections`) | Uses **Bluetooth + WiFi Direct** to send reports **phone‑to‑phone with zero internet**. Reports “hop” between people until one phone with signal uploads them. | `lib/services/p2p_relay_service.dart`, `p2p_auto_relay_controller.dart` |
| **device_info_plus / network_info_plus / connectivity_plus** | Identify the device, read the WiFi name (to detect barangay WiFi), and detect connectivity changes. | `p2p_relay_service.dart`, `endpoint_resolver.dart`, `internet_checker_service.dart` |
| **uuid** | Generate unique IDs for reports so duplicates can be detected across hops. | report creation flow |

### 3.7 Media

| What | Why | Where |
|------|-----|-------|
| **camera / image_picker** | Take or pick photos for emergency reports. | `report_emergency_screen.dart` |
| **video_player** | Play offline safety‑tip videos (first aid, earthquake, flood). | `safety_tips` widgets; assets in `pubspec.yaml` |
| **url_launcher** | Tap‑to‑call evacuation centers and open external links. | `evacuation.dart`, resources |

---

## 4. Comparative Matrices — “Why this, not that?”

This section answers the classic panel question: *“Why did you pick X instead of Y?”*

### 4.1 Evacuation Navigation — **Why Mapbox?**

| Criterion | **Mapbox (chosen)** | Google Maps SDK | Pure OSM / GraphHopper | flutter_map only |
|-----------|--------------------|-----------------|------------------------|------------------|
| Turn‑by‑turn **voice** nav in‑app | ✅ Built‑in SDK | ⚠️ Limited in‑app; pushes to Google Maps app | ⚠️ Self‑host required | ❌ None |
| **Walking** profile (foot evacuation) | ✅ Native | ✅ | ✅ | ❌ |
| **Live reroute** mid‑trip around hazards | ✅ `reroute()` API | ❌ Hard to control | ⚠️ Manual | ❌ |
| Custom **hazard markers** on the nav map | ✅ (`updateHazardMarkers`) | ❌ | ⚠️ | ✅ (draw only) |
| **Multiple alternative routes** for hazard checking | ✅ Directions API `alternatives=true` | ⚠️ Restricted | ✅ | ❌ |
| Cost / free tier for a thesis project | ✅ Generous free tier | 💲 Card required, costly | ✅ Free but ops‑heavy | ✅ Free |
| Offline drawing fallback | ✅ pairs with flutter_map | ⚠️ | ⚠️ | ✅ |

**Verdict:** Mapbox is the only option that combines **in‑app voice walking navigation** with the
**programmatic control** needed to *automatically detour around hazards* and *reroute live*.
flutter_map (free OSM) is kept **alongside** it for the offline map display — best of both worlds.

> See it: `lib/screens/evacuation_screen.dart` and `lib/services/hazard_routing_service.dart`.

### 4.2 Phone‑to‑Phone Relay — **Why Nearby Connections?**

| Criterion | **Nearby Connections (chosen)** | Plain Bluetooth (RFCOMM) | WiFi Direct (raw) | LoRa / hardware radios |
|-----------|--------------------------------|--------------------------|-------------------|------------------------|
| Works with **no internet / no cell tower** | ✅ | ✅ | ✅ | ✅ |
| **No extra hardware** (just the phone) | ✅ | ✅ | ✅ | ❌ Needs devices |
| Auto **discovery + connection** of peers | ✅ Built‑in | ❌ Manual pairing | ⚠️ Complex | ⚠️ |
| Switches between **Bluetooth & WiFi** automatically | ✅ (`P2P_CLUSTER`) | ❌ | ❌ | ❌ |
| Good for **many‑to‑many “mesh” hops** | ✅ | ⚠️ | ⚠️ | ✅ |
| Easy Flutter integration | ✅ package | ⚠️ | ⚠️ | ❌ |

**Verdict:** Nearby Connections gives a **zero‑hardware, auto‑forming mesh** using radios already in
every Android phone — ideal for a community where the only guaranteed device is a smartphone.

> See it: `lib/services/p2p_relay_service.dart` (the `P2P_CLUSTER` strategy, `_maxHops = 3`).

### 4.3 On‑Device Storage — **Why Hive?**

| Criterion | **Hive (chosen)** | SQLite (sqflite) | shared_preferences | SecureStorage |
|-----------|-------------------|------------------|--------------------|---------------|
| Store **complex JSON** (reports, routes) | ✅ Native maps/lists | ⚠️ Needs schema + SQL | ❌ strings only | ❌ small secrets |
| **Speed** (NoSQL key‑value) | ✅ Very fast | ✅ | ✅ | ⚠️ |
| **No boilerplate** / no SQL | ✅ | ❌ | ✅ | ✅ |
| Multiple named “boxes” (alerts, routes, queue) | ✅ | ⚠️ tables | ❌ | ❌ |
| Good fit for **offline‑first cache** | ✅ | ✅ | ⚠️ | ❌ |

**Verdict:** Reports and routes are deeply nested JSON. Hive stores them **as‑is** with almost no
code, and supports many independent boxes — perfect for an offline cache + relay queue.
`flutter_secure_storage` is used **only** for the sensitive JWT token.

> See it: `lib/services/hive_service.dart` (6 cache boxes), `relay_queue_manager.dart`.

### 4.4 App Framework — **Why Flutter?**

| Criterion | **Flutter (chosen)** | React Native | Native Android (Kotlin) |
|-----------|----------------------|--------------|-------------------------|
| One codebase, multi‑platform | ✅ | ✅ | ❌ |
| Native performance (compiled) | ✅ AOT | ⚠️ JS bridge | ✅ |
| Rich built‑in UI widgets | ✅ | ⚠️ | ⚠️ |
| Mapbox / Nearby / Firebase packages | ✅ Mature | ✅ | ✅ |
| Single language for whole team | ✅ Dart | ✅ JS | ❌ |

**Verdict:** Flutter delivers **near‑native speed** (critical during an emergency) with **one
codebase** and first‑class packages for every capability we need.

### 4.5 Notifications — **Why Firebase Cloud Messaging?**

| Criterion | **FCM (chosen)** | Polling the server | SMS gateway |
|-----------|------------------|--------------------|-------------|
| Delivers when app is **closed** | ✅ | ❌ | ✅ |
| **Free** at scale | ✅ | ⚠️ battery/data heavy | 💲 per message |
| Rich payload → deep link to a screen | ✅ (`data['route']`) | ⚠️ | ❌ |
| Battery‑friendly | ✅ | ❌ | ✅ |

**Verdict:** FCM is the standard, free, battery‑efficient way to push **life‑critical alerts** to a
device even when the app is not open. (SMS could be a future *complement* for total‑offline reach.)

---

## 5. System Architecture (Text Diagrams)

### 5.1 High‑Level Map (who talks to whom)

```
                          ┌──────────────────────────────────────────┐
                          │        📱  E-TELLY MOBILE APP (Flutter)   │
                          │                                          │
                          │   Screens / Widgets   (lib/screens, …)   │
                          │            │                             │
                          │            ▼                             │
                          │   Services "brain"    (lib/services)     │
                          │       │        │                         │
                          │       ▼        ▼                         │
                          │   [Hive cache] [Secure Storage = JWT]    │
                          └───┬───────┬───────┬───────┬──────────────┘
                              │       │       │       │
        🔵 Cloud (HTTP +      │       │       │       │   🔴 Offline (Bluetooth /
        Socket.IO)           │       │       │       │       WiFi Direct)
                              ▼       │       │       ▼
                  ┌────────────────┐  │       │   ┌─────────────────────┐
                  │ ☁️ Heroku       │  │       │   │ 📱 Nearby Phone      │
                  │ Node/Express    │  │       │   │ (P2P relay peer)    │
                  └───────┬─────────┘  │       │   └─────────┬───────────┘
                          │            │       │             │ hops until a
                          ▼            │       │             │ phone has signal
                  ┌────────────────┐   │       │             ▼
                  │ 🍃 MongoDB Atlas│◄──┘       │      (eventually uploads to
                  └────────────────┘           │       Heroku / MongoDB)
                          ▲                     │
        🟢 Local (WiFi)   │                     │   🗺️ Mapbox Directions / Nav SDK
                  ┌────────────────┐            └────────► (walking routes + voice nav)
                  │ 🏠 Barangay     │
                  │ Local Server    │            🔔 Firebase Cloud Messaging
                  │ 192.168.x.x:5000│──► pushes alerts ──► back into the app
                  └────────────────┘
```

### 5.2 Layered View (inside the app)

```
┌──────────────────────────────────────────────────────────────────┐
│  PRESENTATION   lib/screens/*  +  lib/widgets/*                    │
│  (Dashboard, Alerts, Evacuation, Report, Resources, Profile…)     │
├──────────────────────────────────────────────────────────────────┤
│  SERVICES (the "brain")   lib/services/*                          │
│  Auth · Api · Alert · Notification · EndpointResolver ·          │
│  InternetChecker · RelayQueueManager · P2PRelay · HazardRouting   │
├──────────────────────────────────────────────────────────────────┤
│  DATA / STORAGE                                                   │
│  Hive boxes · SecureStorage · MongoDB helper (lib/dbhelper)       │
├──────────────────────────────────────────────────────────────────┤
│  PLATFORM / EXTERNAL                                              │
│  Mapbox · Firebase · Nearby Connections · GPS · Camera           │
└──────────────────────────────────────────────────────────────────┘
```

### 5.3 App Startup Sequence (`lib/main.dart`)

```
main()
 1. Load .env (secret keys: MAPBOX_ACCESS_TOKEN, MONGO_CONN_URL)
 2. Init Firebase + Notifications (push alerts)
 3. Open Hive boxes (alerts, centers, routes, reports, relay queue)
 4. Init offline storage + relay queue + P2P service
 5. Start InternetCheckerService (auto-uploads queued reports when online)
 6. Check saved JWT → valid? → go to /home   :   not valid? → go to /welcome
```

---

## 6. How the Core Features Work (Logic + Diagrams)

### 6.1 Submitting an Emergency Report (Offline‑First)

**The logic:** *Never lose a report.* A report is **always saved to the phone first**, then the app
tries to deliver it by the best available path.

```
  User submits report (photo + GPS + type)
            │
            ▼
  Save to Hive relay queue          ◄── nothing is lost from here on
  (relay_queue_manager.enqueue)
            │
            ▼
  Ask EndpointResolver: what connectivity do we have?
            │
   ┌────────┴──────────────────────────────┐
   │                                        │
   ▼                                        ▼
 Internet OR Local server               No connectivity at all
   │                                        │
   ▼                                        ▼
 Upload now                            Activate P2P relay
 (InternetCheckerService.flush)        (P2PAutoRelayController)
   │                                        │
   │                                        ▼
   │                                Find nearby phones (Bluetooth/WiFi Direct)
   │                                        │
   │                                        ▼
   │                                Send report to BEST peer
   │                                (priority: _ONLINE > _LOCAL > _OFFLINE)
   │                                        │
   │                                        ▼
   │                                That peer (or a later hop) uploads it
   │                                        │
   ▼                                        ▼
  ┌─────────────────────────────────────────────┐
  │   Report marked 'uploaded' ✅  (then pruned   │
  │   from the queue after 7 days)                │
  └─────────────────────────────────────────────┘
```

**Key safeguards (in code):**
- **Deduplication** — each report has a unique `id`; the same report is never queued or relayed twice (`relay_queue_manager.dart`).
- **Hop limit** — a report can be passed at most **3 times** (`_maxHops = 3`) so it can’t bounce forever.
- **Retry with limits** — failed uploads retry up to 5 times; a server “400 Bad Request” is marked **permanent** and never retried (`internet_checker_service.dart`).
- **Auto‑flush** — when the phone regains signal, the queue uploads automatically (every 2 min poll + on connectivity change).

---

### 6.2 The P2P “Human Mesh” Relay — Deep Dive

This is the most novel part of the system, so here is exactly **how it works**, step by step.

#### a) The idea in one picture

```
  Phone A (NO signal)        Phone B (NO signal)        Phone C (HAS WiFi/data)
  ┌───────────────┐  Blue-   ┌───────────────┐  WiFi    ┌───────────────────┐
  │ report saved  │  tooth   │ stores +      │  Direct  │ receives + UPLOADS │
  │ tag: _OFFLINE │ ───────► │ carries it    │ ───────► │ to server/MongoDB ✅│
  └───────────────┘          │ tag: _OFFLINE │          │ tag: _ONLINE       │
                             └───────────────┘          └───────────────────┘

  A report "hops" toward whoever can actually reach the internet.
```

Every phone, while relaying, **advertises its own connectivity** by adding a suffix to the name it
broadcasts: `Juan_OFFLINE`, `Maria_LOCAL`, `Pedro_ONLINE`. So other phones can *see at a glance*
which neighbor is closest to having real internet.

#### b) The two Nearby Connections roles (every phone does both)

```
  ADVERTISING  = "Here I am, you can connect to me"   (Nearby().startAdvertising)
  DISCOVERY    = "Who else is around?"                (Nearby().startDiscovery)

  Both run at the same time using Strategy.P2P_CLUSTER, which lets one phone be
  connected to several peers and freely use Bluetooth OR WiFi, whichever works.
```

#### c) The full relay cycle (the orchestration brain: `p2p_auto_relay_controller.dart`)

```
 1. A report is queued.
      └─ If THIS phone can already reach a server → just upload, skip P2P.
      └─ Else → activate P2P (ask for Bluetooth/Location/Nearby permissions first).

 2. Start ADVERTISING + DISCOVERY. Status: "Scanning for nearby devices…"

 3. A peer is found.  ►  Don't grab the first one!
      └─ Open a 2.5-second "selection window" so several peers can be discovered.

 4. When the window closes, pick the BEST peer by connectivity score:
            _ONLINE = 2   >   _LOCAL = 1   >   _OFFLINE = 0
      (P2PAutoRelayController._score)

 5. Connect to that peer and SEND the pending reports (sender drives the transfer):
            ── "__COUNT__:3"   (I'm about to send 3 reports)
            ── { report 1 json }
            ── { report 2 json }
            ── { report 3 json }
            ── "__DONE__"       (that's all)
      Each report's hopCount is increased by 1 as it leaves.

 6. Receiver stores each report (de-duplicated by id), tags source = "mesh_relay".
      └─ If the receiver HAS connectivity → it flushes them to the server.
      └─ If not → it keeps carrying them and re-advertises for the next hop.

 7. Sender disconnects, releases its lock, and looks for the next peer if there
    are still reports to pass.

 8. AUTO-STOP after 10 minutes of no activity (saves battery).
```

#### d) Why each rule exists (the panel will ask “what stops X?”)

| Rule | Value | What it prevents |
|------|-------|------------------|
| **Hop limit** | `_maxHops = 3` | A report bouncing between phones forever. After 3 hops it stops being relayed. |
| **Deduplication by `id`** | every report has a UUID | The same report being stored or counted twice as it spreads. |
| **Connectivity tags + scoring** | `_ONLINE > _LOCAL > _OFFLINE` | Wasting hops — data always moves *toward* internet, not randomly. |
| **2.5 s selection window** | `_selectWindow` | Connecting to a weak `_OFFLINE` peer when a better `_ONLINE` one is also nearby. |
| **Sender‑drives‑transfer** | only the initiator sends + disconnects | Both phones sending at once (a “ping‑pong” duplicate storm). |
| **10‑min auto‑stop** | `_autoStopTimeout` | Battery drain from advertising/scanning forever. |

> Manual mode also exists: a “receiver” phone (one that *has* signal) can tap **Start** on the P2P
> screen to make itself discoverable so offline neighbors can dump their reports onto it
> (`startManualRelay`). See `lib/screens/p2p_relay_screen.dart`.

---

### 6.3 Hazard‑Aware Evacuation Routing — Deep Dive (Mapbox)

**The logic:** don’t just route to the nearest center — route to the nearest **safe** center, on a
path that **avoids active hazards**, and keep checking **while you walk**.

#### a) What counts as a “hazard”?

Hazards come from two sources, merged into a single list of `HazardPoint`s
(`hazard_routing_service.dart → loadAllHazardPoints`):
1. **Official alerts** from CDRRMO/PAGASA feeds (`/api/alerts`).
2. **Approved community reports** from other residents, only `High`/`Medium` severity and only from
   the **last 7 days** (`/api/reports/approved`).

#### b) The three distances that make it precise

```
   ┌─ HAZARD (e.g. a flooded street) ────────────────────────────┐
   │                                                              │
   │   ●  ← exact hazard point                                    │
   │  ╱ ╲                                                         │
   │ 40m  → BLOCK RADIUS: a CRITICAL hazard this close to a       │
   │        street makes that ONE street impassable → reroute.    │
   │        (small on purpose: blocks only the affected street,   │
   │         not the whole neighborhood)                          │
   │                                                              │
   │ 200m → WARN RADIUS: hazard is just "near your route" →       │
   │        show a heads-up, let the user decide.                 │
   │                                                              │
   │ 500m+→ DANGER ZONE (per type: flood 500m, lahar 600m,        │
   │        volcano 800m…) → used ONLY to flag whether an         │
   │        evacuation CENTER itself is unsafe, not to block      │
   │        streets.                                              │
   └──────────────────────────────────────────────────────────────┘
```

#### c) Decision flow when you tap “Directions” (`_startEvacuation`)

```
  Tap "Directions" to a center
        │
        ▼
  Is the center FULL? ── yes ──► Refuse, tell user to pick another
        │ no
        ▼
  Load hazards (alerts + recent approved reports)
        │
        ▼
  Is the CENTER ITSELF inside a critical zone? ── yes ──► auto-pick next SAFE center
        │ no
        ▼
  Ask Mapbox Directions API for SEVERAL walking routes (alternatives=true)
        │
        ▼
  Look at the best route. What's on it?
        │
        ├── CRITICAL hazard on the street (≤40m)
        │        │
        │        ▼
        │   Try to build a SAFE route automatically:
        │     1) check Mapbox's own alternative routes
        │     2) if none clear, build CORRIDOR DETOURS (see (d) below)
        │        │
        │        ├── found a clear route ──► 🟢 start nav on the safe route
        │        │                            (show "Route adjusted for safety")
        │        └── nothing clears ───────► ⚠️ ask user "hazard cannot be
        │                                       avoided — proceed anyway?"
        │
        ├── only a WARNING/WATCH hazard nearby (≤200m)
        │        ▼
        │   Ask the user: "Use alternative route" or "Continue"?  (or Cancel)
        │
        └── nothing on the route ──► 🟢 start nav on the normal route
```

#### d) How the automatic detour is built (`_findSafeWalkingRoute`)

A single side‑step waypoint is **not** enough — Mapbox would just route straight back through the
hazard street. So the app uses **corridor detours**: it places **two** invisible via‑points that
**straddle** the hazard (one before it, one after it, both pushed to the same side), forcing the
walking path to swing around the whole blocked span.

```
        origin ●─────────────●  hazard  ●─────────────● destination
                       │   ▲             │
                       │   │ straight route goes THROUGH the hazard ✗
                       │
        With corridor via-points (both on one side):
                          ╭───────────────╮
        origin ●─────────╯  via1     via2 ╰────────● destination
                          (before)   (after)
                       the path is forced to bend AROUND the hazard ✓
```

It tries escalating offsets (60 m, 120 m, 200 m, 350 m) on **both** sides, re‑queries Mapbox for
each, and keeps every route that clears all criticals. It then picks the **shortest** clear route.
HTTP probes are capped (≤10) so the search stays fast. If nothing clears, it returns “no safe route”
and the user is asked to decide.

#### e) Live rerouting WHILE you are walking

This is the part the panel finds most impressive. While navigation is running, the screen holds a
**Socket.IO** connection (`_initLiveUpdates`). When the admin posts a new alert or a new report is
approved, the server emits an event; the app:

```
  Socket event: "new_alert" / "report_status_updated" / …
        │
        ▼ (debounced 0.8s so a burst of events = one refresh)
  Reload hazards  →  push fresh hazard markers onto the nav map
        │
        ▼
  Is a NEW critical hazard now sitting on my ACTIVE route (≤40m)?
        │ yes (and I haven't already been warned about it)
        ▼
  Compute a safe detour to the SAME destination (same corridor logic)
        │
        ├── safe route found ──► call Mapbox reroute(wayPoints: …)
        │                         + toast "Hazard ahead — rerouting"  🟠
        └── none found ───────► local notification:
                                 "New hazard on your route — re-check your route"
```

So a resident who started walking on a clear route is **automatically bent around a flood that
appears after they set off**, without restarting navigation. (`_refreshHazardsLive`,
`_liveRerouteAround`, `_mapboxNavigation.reroute`).

#### f) What happens with no internet at navigation time

```
  Start navigation while OFFLINE
        │
        ▼
  Did I cache a route for THIS exact center earlier (while online)?
        ├── yes ──► draw that cached route on the OSM map (blue line) 🟢
        └── no  ──► "Compass mode": show a black card with the center name,
                    straight-line distance, and bearing (e.g. "320 m • 47°").
                    NOTE: compass mode points in a direction; it does NOT
                    follow roads.
```

Routes are cached **per center** in Hive (`route_<centerId>`), so the offline route matches the one
Mapbox suggested for *that* center — not whatever was navigated last.

---

### 6.4 How Hazards Are Shown on the Map

E‑Telly actually shows hazards on **two different maps**, depending on what you’re doing:

#### Map 1 — The browse/overview map (OpenStreetMap via `flutter_map`)

This is the map you see on the Evacuation tab *before* you start navigating (`build()` in
`evacuation_screen.dart`). On it:

```
  🔵 Blue dot + ring      = your current GPS location
  🔴/🟢/🟡 colored pins    = evacuation centers, colored by status
                            (green = available, amber = almost full, red = full)
                            → tap a pin to open its details sheet
  ⚠️ colored hazard pins   = each hazard's EXACT location, shown as a round
                            badge with a warning icon. Color = severity:
                               red    = critical / evacuate
                               orange = warning / high
                               yellow = watch / moderate
  🟩 green flag            = the destination while a route is being calculated
  🔵 blue line             = the cached offline route (offline mode only)
```

There is also an **orange strip** above the center list saying e.g. *“3 active hazard zone(s) in
area. Route will auto‑avoid critical zones.”*, and each center card/list item gets a small **hazard
badge** (e.g. “Critical • flood” or “Rerouted • flood”) when a hazard is near it
(`annotateCentersWithHazards`).

> Design note: the code uses **exact‑location pins** rather than big translucent circles, on purpose,
> so the map stays readable. (You can see leftover circle‑opacity helpers like `_getHazardOpacity`,
> but the live UI draws pins — see the `MarkerLayer` in `build()`.)

#### Map 2 — The Mapbox turn‑by‑turn navigation map (full screen)

When you tap **Start Navigation**, the native Mapbox screen takes over. The app pushes the hazard
list onto it as markers:

```
  evacuation_screen.dart
        │  _hazardMarkerPayload()  →  [{lat, lng, severity}, …]
        ▼
  _mapboxNavigation.updateHazardMarkers(hazards: payload)
        │
        ▼
  Native Mapbox map draws a hazard marker at each point, colored by severity,
  right on top of the turn-by-turn route.
```

These markers are kept **in sync live**: every time hazards are refreshed (including from Socket.IO
events mid‑trip), `_pushHazardMarkersToNav()` re‑sends the updated list so the navigation map always
shows the current danger picture (`route_built` event and `_refreshHazardsLive`).

---

### 6.5 Alerts: From Sensor Data to Plain Language

**The logic:** the backend produces technical, PAGASA‑grade severities; the app **re‑presents** them
as plain, actionable words for residents — **without inventing new risk levels**.

```
Backend severity   →   Resident band      →   Color   →   Example action
─────────────────      ────────────────       ───────     ─────────────────────────
watch              →   ADVISORY           →   🟡 Yellow → "Stay aware, monitor updates"
warning            →   BE PREPARED        →   🟠 Orange → "Ready your go-bag"
critical           →   EMERGENCY          →   🔴 Red    → "Move to higher ground now"
evacuate           →   EVACUATE NOW       →   🔴 Red    → "Evacuate immediately"
```

- Auto‑generated alerts (from `system`, `USGS`, `GDACS` feeds) get a friendly rewrite.
- Human‑written alerts (CDRRMO / barangay) are shown **word‑for‑word**.
- Alerts are **cached** so they’re readable offline, and **read/unread** marks survive refreshes.

> See it: `lib/utils/alert_presentation.dart`, `lib/services/alert_service.dart`.

---

### 6.6 Resource Sharing (Request ↔ Pledge ↔ Chat)

**The logic:** connect people who **need** relief goods with people who can **give** them, with a
private chat to coordinate pickup.

```
  Person A: "I need 5 water gallons" (request)  ──►  posted to Community Board
  Person B: "I can give them" (pledge)          ──►  accepts the request
          └──────────────► Private real-time chat (Socket.IO) to arrange handover
```

> See it: `resources_screen.dart`, `my_requests_screen.dart`, `my_pledges_screen.dart`,
> `request_chat_screen.dart`, `community_board_screen.dart`.

---

## 7. Folder Structure (One Line Each)

```
etelly-mobile/
├── lib/                         # All Dart source code
│   ├── main.dart                # App entry point: startup, routes, theme
│   ├── constants.dart           # App colors + cloud API base URL + terms version
│   ├── firebase_options.dart    # Auto-generated Firebase config
│   │
│   ├── screens/                 # Full-page UI (one file per screen)
│   │   ├── welcome_screen.dart          # First-launch welcome
│   │   ├── login_screen.dart            # Email / Google login
│   │   ├── sign_up_screen.dart          # Account creation
│   │   ├── email_verification_screen.dart # Verify email step
│   │   ├── profile_completion_screen.dart # Fill in barangay/profile after signup
│   │   ├── terms_policy_screen.dart     # Terms & privacy (versioned consent)
│   │   ├── home_screen.dart             # Bottom-nav shell (5 tabs)
│   │   ├── dashboard_screen.dart        # Home tab: quick actions + summaries
│   │   ├── alerts_screen.dart           # Hazard alerts list ("Near You")
│   │   ├── evacuation_screen.dart       # Map + hazard-aware Mapbox navigation ⭐
│   │   ├── report_emergency_screen.dart # Submit a hazard report (photo+GPS)
│   │   ├── view_reports_screen.dart     # Browse submitted reports
│   │   ├── community_board_screen.dart  # Community resource board
│   │   ├── resources_screen.dart        # Request / pledge relief goods
│   │   ├── my_requests_screen.dart      # My resource requests
│   │   ├── my_pledges_screen.dart       # Resources I pledged to give
│   │   ├── request_detail_screen.dart   # Details of one request
│   │   ├── request_chat_screen.dart     # Real-time chat (requester ↔ pledger)
│   │   ├── flood_monitoring_screen.dart # Flood/disaster monitoring view
│   │   ├── safety_tips_screen.dart      # Offline safety guides + videos
│   │   ├── profile_screen.dart          # User profile + settings
│   │   └── p2p_relay_screen.dart        # Manual phone-to-phone relay control
│   │
│   ├── services/                # The "brain": logic, networking, storage
│   │   ├── auth_service.dart            # JWT login/logout + Google sign-in
│   │   ├── google_auth_service.dart     # Google sign-in helper
│   │   ├── jwt_service.dart             # JWT helper utilities
│   │   ├── api_service.dart             # Authenticated HTTP calls to backend
│   │   ├── endpoint_resolver.dart       # Picks cloud / local / offline target ⭐
│   │   ├── internet_checker_service.dart# Auto-uploads queued reports when online ⭐
│   │   ├── alert_service.dart           # Fetches + caches alerts
│   │   ├── report_service.dart          # Fetches approved community reports
│   │   ├── offline_report_storage.dart  # Hive storage for offline reports/registrations
│   │   ├── relay_queue_manager.dart     # The report queue + relay metadata ⭐
│   │   ├── p2p_relay_service.dart       # Bluetooth/WiFi phone-to-phone transfer ⭐
│   │   ├── p2p_auto_relay_controller.dart # Decides when/whom to relay to ⭐
│   │   ├── hazard_routing_service.dart  # Distance math + hazard zone detection ⭐
│   │   ├── hive_service.dart            # All on-device cache boxes ⭐
│   │   ├── notification_service.dart    # Firebase push + local notifications ⭐
│   │   └── navigation_service.dart      # Global navigator key for deep links
│   │
│   ├── widgets/                 # Reusable UI pieces (not full pages)
│   │   ├── evacuation.dart              # Evacuation center cards/headers
│   │   ├── report.dart                  # Report form sub-widgets (photo list…)
│   │   ├── resources.dart               # Resource cards/forms
│   │   ├── login.dart / sign_up.dart    # Auth form widgets
│   │   ├── profile.dart                 # Profile widgets
│   │   ├── safety_tips.dart             # Safety tip cards + video players
│   │   ├── flood_monitoring.dart        # Monitoring widgets
│   │   ├── emergency_contacts.dart      # Emergency hotline list
│   │   ├── actions.dart                 # Quick-action buttons
│   │   ├── custom_font.dart             # Shared text styling
│   │   ├── walkie_talkie_icon.dart      # P2P/relay icon
│   │   └── welcome.dart / mongodb.dart  # Misc UI helpers
│   │
│   ├── models/                  # Data shapes
│   │   ├── alert.dart                   # Alert data model
│   │   └── user.dart                    # User data model
│   │
│   ├── providers/
│   │   └── alert_provider.dart          # Shared alert state (provider)
│   │
│   ├── dbhelper/                # Direct MongoDB access (fallback path)
│   │   ├── mongodb.dart                 # MongoDB Atlas connection + CRUD
│   │   └── constant.dart                # DB name + collection names
│   │
│   └── utils/                   # Small shared helpers
│       ├── geo_utils.dart               # Haversine distance (km)
│       └── alert_presentation.dart      # PAGASA severity → plain resident text ⭐
│
├── packages/
│   └── flutter_mapbox_navigation/  # Vendored Mapbox nav plugin (customized) ⭐
├── android/                      # Android project (permissions, manifest, Mapbox token)
├── assets/                       # Images, icons, fonts, safety videos
├── .env                          # Secret keys (MAPBOX_ACCESS_TOKEN, MONGO_CONN_URL)
└── pubspec.yaml                  # Dependencies + asset declarations

⭐ = the files most worth reading to understand the system’s “smart” behavior.
```

---

## 8. Data & Security

| Topic | How E‑Telly handles it | Where |
|-------|------------------------|-------|
| **Login state** | JWT stored **encrypted** (AndroidKeystore); checked for expiry on every launch; auto‑logout on stale/expired/malformed token. | `auth_service.dart`, `main.dart` |
| **Secret keys** | Mapbox token & Mongo URL kept in `.env` (not hard‑coded in logic) and Android `meta-data`. | `.env`, `AndroidManifest.xml` |
| **Permissions requested** | Location (fine/coarse), Notifications, Bluetooth (scan/advertise/connect), Nearby WiFi, Network state. | `AndroidManifest.xml`, `p2p_auto_relay_controller.dart` |
| **Consent** | Terms & Privacy are **versioned** (`termsVersion = '1.0'`); the version a user agreed to is recorded. | `constants.dart`, `terms_policy_screen.dart` |
| **Offline data** | Cached in Hive on the device; uploaded reports older than 7 days are pruned. | `hive_service.dart`, `relay_queue_manager.dart` |
| **Password handling note** | Email/password is checked by the backend; the direct‑MongoDB login path compares a plain field — see Limitations. | `mongodb.dart` |

---

## 9. Limitations of the System

> Stated honestly — these are the realistic boundaries and known trade‑offs.

### Platform & device
1. **Android‑only in practice.** P2P relay (Nearby Connections) and the SSID/manifest setup target Android; iOS is not wired up. `device_info_plus` reads **Android** info only.
2. **P2P needs nearby people.** The phone‑to‑phone mesh only works if **other E‑Telly users are physically within Bluetooth/WiFi range** (tens of meters). In a sparsely populated area with no signal, a report may sit in the queue until someone passes by.
3. **P2P range & battery.** Continuous advertising/scanning drains battery; the app auto‑stops after 10 minutes of inactivity, which can also mean a relay opportunity is missed if it happens later.

### Navigation
4. **Hazard‑aware routing needs internet at start.** The smart detour logic calls the **Mapbox Directions API**. Fully offline, the app can only replay a **previously cached** route for that center, or fall back to a **straight‑line compass**, which does **not** follow roads.
5. **Walking profile only.** Routing assumes evacuation on foot; it does not optimize for vehicles.
6. **Hazard data is only as good as its inputs.** Detours rely on alerts + approved community reports having **accurate coordinates**; a hazard with a missing/zero location can’t block a street. Reports older than 7 days are ignored.
7. **Detour search is capped** (≤10 HTTP probes, 2 nearest hazards) to stay responsive — in a very dense grid of hazards it may report “cannot be avoided” rather than searching exhaustively.

### Data & connectivity
8. **Direct‑MongoDB fallback is sensitive.** The app can connect straight to MongoDB Atlas; the connection string lives in `.env` and Atlas IP‑whitelisting must be configured. The direct login query compares the password field directly (`mongodb.dart`) — backend‑mediated auth is the secure path and should be preferred.
9. **Local barangay server is hard‑coded** to specific IPs (`192.168.137.1`, `192.168.1.100`) and an `ETelly-` WiFi name prefix; a different network layout needs config changes.
10. **No guaranteed delivery offline.** A queued report is delivered on a *best‑effort* basis; until a phone with connectivity is reached, it is not on the server.

### Scope
11. **Resident app only.** Creating alerts, approving reports, and managing centers happen in the **separate admin/web system**, not here.
12. **Photo upload depends on a live endpoint.** Some report‑photo upload changes are pending the web upload endpoint going live.
13. **Cleartext traffic enabled** (`usesCleartextTraffic="true"`) to allow the local `http://` barangay server — acceptable for LAN, but means cloud calls should remain on HTTPS (they do).

---

## 10. Possible Panel Questions (with Answers)

**Q1. What problem does E‑Telly solve that existing apps don’t?**
> It keeps working when the network fails. Through a **3‑tier fallback (cloud → local barangay
> server → phone‑to‑phone relay)**, a resident can still send a report and still get evacuation
> guidance during a disaster — exactly when normal apps go dark.

**Q2. Why Mapbox instead of Google Maps for navigation?**
> We needed **in‑app voice walking navigation** plus the ability to **programmatically reroute around
> hazards live**. Google’s SDK pushes you to the external Maps app and gives little control; Mapbox’s
> Navigation SDK + Directions API (with `alternatives=true`) lets us check every candidate street for
> hazards and build a forced detour. See §4.1 and §6.3.

**Q3. How exactly does the app avoid a hazard on the route?**
> It loads hazards (alerts + approved reports), asks Mapbox for several walking routes, and checks
> each against a **40 m block radius** for *critical* hazards. If the best route is blocked, it builds
> **corridor detour via‑points** that straddle the hazard on one side and re‑queries Mapbox until it
> finds a clear, shortest route. If nothing clears, it warns the user. (§6.3 (c) and (d);
> `hazard_routing_service.dart`, `_findSafeWalkingRoute`.)

**Q4. How does auto‑rerouting work *while* the user is already walking?**
> The evacuation screen keeps a **Socket.IO** connection open during navigation. When a new alert or
> approved report arrives, it reloads hazards (debounced 0.8 s) and checks whether a **new critical
> hazard now sits on the active route** (≤40 m). If so, it computes a safe detour to the same
> destination and calls Mapbox **`reroute()`**, showing “Hazard ahead — rerouting.” If no safe route
> exists, it sends a local notification telling the user to re‑check. The navigation map’s hazard
> markers are also refreshed live. (§6.3 (e); `_refreshHazardsLive`, `_liveRerouteAround`.)

**Q5. How are hazards shown on the map?**
> On **two** maps. (1) The browse map (OpenStreetMap via `flutter_map`) shows each hazard as a
> **colored warning pin at its exact location** (red = critical, orange = warning, yellow = watch),
> plus evacuation‑center pins colored by status, your blue location dot, an orange “N active hazard
> zones” strip, and per‑center hazard badges. (2) The Mapbox turn‑by‑turn map receives the hazard
> list via **`updateHazardMarkers`** and draws them right on the route, kept in sync live. (§6.4.)

**Q6. How does the phone‑to‑phone relay actually move data?**
> Using **Nearby Connections** (Bluetooth + WiFi Direct, `P2P_CLUSTER` strategy). Every phone both
> **advertises** and **discovers** at once, broadcasting its connectivity as a name suffix
> (`_ONLINE/_LOCAL/_OFFLINE`). The sender transmits a small protocol — `__COUNT__:n`, then each
> report as JSON, then `__DONE__` — and the receiver stores them (de‑duplicated). The first phone
> with real signal uploads the whole batch. Reports hop at most **3 times**. (§6.2.)

**Q7. In the relay, how does a phone decide *who* to send to?**
> When a peer is found, it does **not** grab the first one. It opens a **2.5‑second selection window**
> to discover several peers, then connects to the **best‑connected** one by score
> (`_ONLINE = 2 > _LOCAL = 1 > _OFFLINE = 0`). A phone that can already reach a server uploads
> directly instead of relaying. (§6.2 (c); `p2p_auto_relay_controller.dart`.)

**Q8. What stops the same report from being uploaded many times or looping forever?**
> Every report has a **unique UUID**. The queue ignores duplicates on enqueue and on receive; a
> **hop counter** (max 3) stops infinite relaying; only the **sender** drives a transfer (prevents a
> two‑way duplicate storm); and once uploaded it’s marked `uploaded` and pruned after 7 days.
> (§6.2 (d); `relay_queue_manager.dart`.)

**Q9. Is user data secure?**
> The login **JWT is stored encrypted** via `flutter_secure_storage` and validated for expiry every
> launch. Secrets live in `.env`, not in code. Cloud traffic is HTTPS. (We also note honest
> limitations around the direct‑MongoDB fallback in §9.)

**Q10. What happens to a report if there is truly no signal and no other phones around?**
> It is **saved safely in Hive** with status `pending`. The `InternetCheckerService` polls every
> 2 minutes and also reacts to connectivity changes, so the moment any path (internet, local server,
> or a passing peer) becomes available, the report uploads automatically. Nothing is lost.

**Q11. Why both Mapbox AND flutter_map (OpenStreetMap)?**
> Mapbox provides **navigation**; flutter_map provides a **free, offline‑friendly map canvas** to draw
> hazard pins, centers, and the cached route when Mapbox can’t be reached. They complement each
> other. (§4.1, §6.4.)

**Q12. How does the app know whether to use cloud, local, or offline?**
> `EndpointResolver` reads the **WiFi name** (is it an `ETelly-` barangay network?), probes the
> **local server**’s `/api/health`, and checks **real internet** via a DNS lookup — then returns the
> right base URL (or an empty string meaning “go offline”). Everything else routes through that single
> decision. (§2.)

**Q13. How are alerts kept understandable for ordinary residents?**
> The backend classifies severity using official **PAGASA/PHIVOLCS** thresholds; the app’s
> `AlertPresentation` layer **re‑labels** those into 🟡 Advisory / 🟠 Be Prepared / 🔴 Emergency /
> Evacuate Now with a plain “what’s happening” and “what to do” line — **without inventing new risk
> levels**. Human‑written alerts are shown verbatim. (§6.5.)

**Q14. Is it real‑time?**
> Yes, for the key flows. **Socket.IO** pushes new alerts and resource‑chat messages instantly, and
> drives **live rerouting** if a hazard appears mid‑navigation. **Firebase Cloud Messaging** delivers
> alerts even when the app is closed.

**Q15. Why store data with Hive instead of SQLite?**
> Reports and routes are nested JSON. Hive stores them directly with almost no boilerplate and supports
> many independent “boxes” (alerts, centers, routes, queue) — a better fit for an offline‑first cache.
> (§4.3.)

**Q16. What happens when navigating offline?**
> If a route for that exact center was cached earlier (while online), the app redraws it as a blue
> line on the OSM map. If not, it switches to **compass mode**: a card showing the center’s name,
> straight‑line distance, and bearing. Compass mode gives a direction, not road‑by‑road steps. (§6.3 (f).)

**Q17. What are the biggest risks/limitations you acknowledge?**
> Android‑only P2P, hazard‑aware routing needing internet at trip start (offline falls back to cached
> route or compass), P2P depending on nearby users, and the operational care needed for the
> direct‑MongoDB fallback. Full list in §9.

**Q18. Can it scale to a whole city?**
> The cloud tier (Heroku + MongoDB Atlas) scales like any web backend; FCM scales to large audiences.
> The local‑server and P2P tiers are **per‑barangay / per‑crowd** by design, which is appropriate —
> they’re meant for localized outages, not city‑wide load.

**Q19. What would you add next?**
> iOS support for P2P, an **SMS fallback** for total‑offline alert reach, encrypted/authenticated P2P
> payloads, configurable barangay server discovery, and richer offline road routing.

---

## 11. Glossary

| Term | Plain meaning |
|------|---------------|
| **CDRRMO** | City Disaster Risk Reduction and Management Office — the local government body the app serves. |
| **PAGASA / PHIVOLCS** | Philippine weather and volcano/earthquake agencies whose warning levels the app mirrors. |
| **Hive** | A small fast database that lives inside the phone (used for offline storage). |
| **JWT** | A secure “digital ID card” that proves you’re logged in. |
| **FCM (Firebase Cloud Messaging)** | Google’s system for pushing notifications to phones. |
| **Nearby Connections** | Android tech for sending data phone‑to‑phone over Bluetooth/WiFi without internet. |
| **P2P relay / mesh** | Reports “hopping” from phone to phone until one with signal uploads them. |
| **Hop / hop count** | One phone‑to‑phone pass. Capped at 3 so reports don’t circulate forever. |
| **Connectivity tag** | The `_ONLINE/_LOCAL/_OFFLINE` suffix a phone broadcasts so the mesh routes toward internet. |
| **Socket.IO** | A live, two‑way connection for instant updates (alerts, chat, reroutes). |
| **Mapbox Directions API** | An online service that returns walking routes and road shapes. |
| **Corridor detour** | Two via‑points placed before and after a hazard to force the route around it. |
| **Block radius / Warn radius** | 40 m = “this street is blocked by a hazard”; 200 m = “hazard nearby, just a heads‑up.” |
| **Endpoint** | The address the app sends data to (cloud, local server, or none). |
| **Barangay** | The smallest local government unit in the Philippines (a village/district). |

---

*Generated as a deployment‑readiness system guide for E‑Telly Mobile. For implementation details,
follow the ⭐ files in §7 — start with `endpoint_resolver.dart`, `relay_queue_manager.dart`,
`p2p_auto_relay_controller.dart`, and `evacuation_screen.dart`.*
