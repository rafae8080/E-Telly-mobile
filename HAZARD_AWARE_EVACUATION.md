# Hazard-Aware Evacuation Navigation — How It Works

A beginner-friendly guide to the evacuation navigation feature: **what** was built,
**why**, and **where** to find it in the code. This reflects the code as it is **now**.

If you read nothing else, read **Section 2 (the two maps)** and **Section 4 (why there's a
`packages/flutter_mapbox_navigation` folder)** — those two ideas explain most of the
project's structure.

---

## 1. The big picture

When a disaster happens, a user opens the **Evacuation** screen and walks to a nearby
evacuation center. This feature makes that walk **safe and live**:

1. It shows evacuation centers and active **hazards** (floods, fires, etc.) on a map.
2. When the user taps **Navigate**, it builds a **walking** route.
3. If a hazard sits **on that route**, it automatically **reroutes** around it down another
   street, picking the **shortest safe** path. If a hazard is only *near* the route, it
   just **warns** the user.
4. While you are walking, hazard **markers appear on the navigation map**, and if a new
   hazard lands on the street ahead, the route **reroutes live** — you do **not** have to
   exit and restart navigation.
5. Everything updates **live** over Socket.IO — no manual refresh.
6. It still works **offline** using cached data, and the offline route matches the route
   Mapbox suggested online.

Hazards come from two places, both managed by the web/admin system:
- **Admin alerts** (`/api/alerts`) — e.g. an officer marks a flooded street.
- **Approved community reports** (`/api/reports/approved`) — citizen reports.

---

## 2. The two maps (the single most important concept)

This feature uses **two completely different maps**, and confusing them is the #1 source
of confusion. Keep them straight:

| | **Planning map** | **Navigation map** |
|---|---|---|
| What you see | The big scrollable map with center pins + hazard dots, before you start | The full-screen turn-by-turn screen *after* you tap Navigate |
| Technology | `flutter_map` drawing **OpenStreetMap (OSM)** tiles | **Mapbox Navigation SDK** (native Android), the blue-line turn-by-turn |
| Written in | Dart (`evacuation_screen.dart`) | Native Kotlin (`packages/flutter_mapbox_navigation/...`) |
| Lives where | Inside the Flutter app | A separate full-screen Android screen launched on top |

So "show markers on the map" had to be done **twice**, in two different technologies: the
OSM planning map (easy, pure Dart) **and** the native Mapbox navigation screen (harder,
needs Kotlin). When earlier the user said "markers show on OSM but not on Mapbox," that's
exactly this split — the OSM one worked first; the Mapbox one needed native work.

---

## 3. What "online" routing actually uses

A subtle but important point: even on the planning map (OSM tiles), the **route line and
detour math are computed by calling Mapbox's Directions web API** (`api.mapbox.com`) over
HTTP. OSM only provides the *background tiles*; Mapbox provides the *routes*. That's why a
`MAPBOX_ACCESS_TOKEN` is required in `.env` even though the planning map looks like OSM.

---

## 4. Why there's a `packages/flutter_mapbox_navigation` folder

**Short version:** it's our own editable copy of a Mapbox turn-by-turn plugin, because the
public version can't do what we need.

**Longer version, for a beginner:**
- Flutter apps normally pull plugins from the internet (pub.dev) and you **can't edit**
  them — they're read-only downloads.
- The turn-by-turn navigation screen comes from a plugin called
  `flutter_mapbox_navigation`. Out of the box it can only: start navigation, listen to
  progress, and stop. It **cannot** swap the route while you're walking, and it **cannot**
  draw custom hazard markers on its map.
- We needed both. So we **vendored** the plugin: we copied its source code into
  `packages/flutter_mapbox_navigation/` inside this repo, and told Flutter "use my local
  copy instead of the internet one." That switch is in `pubspec.yaml`:

  ```yaml
  dependency_overrides:
    flutter_mapbox_navigation:
      path: packages/flutter_mapbox_navigation
  ```

- Now the plugin's native Kotlin code is **part of our project**, so we can add features to
  it. The trade-off: **we** now maintain it.

> ⚠️ Because parts of this folder are **native Kotlin/Java**, editing them requires a full
> `flutter run` (stop the app and run again). A **hot reload/restart does NOT recompile
> native code** — this caused a lot of "I changed it but nothing happened" confusion.

---

## 5. The Dart ↔ native bridge (how Flutter talks to the navigation screen)

Flutter (Dart) and the navigation screen (Kotlin) are two different worlds. They talk
through a **MethodChannel** — think of it as a phone line where Dart can "call a function"
that runs in Kotlin.

We added two new "calls" on that line:

| Dart call | What Kotlin does |
|-----------|------------------|
| `reroute(wayPoints)` | Rebuilds the active route from new waypoints and **swaps it live**. |
| `updateHazardMarkers(hazards)` | Draws/updates the hazard dots on the navigation map. |

**An important lesson learned (delivery):** Our first attempt sent these as Android
*broadcasts*. On the test device the broadcasts were **silently dropped** and never
arrived — that's why live reroute and markers "did nothing" for a while. The fix: the
plugin now calls the running navigation screen **directly** through a static reference
(`NavigationActivity.instance`), which is reliable because both live in the same app
process.

**Where:**
- Dart side: `MapBoxNavigation.reroute()` / `.updateHazardMarkers()` in
  `packages/flutter_mapbox_navigation/lib/...` (platform interface + method channel).
- Kotlin side: `FlutterMapboxNavigationPlugin.kt` handles the calls and forwards to
  `NavigationActivity.instance?.applyReroute(...)` / `applyHazards(...)`.

---

## 6. Files involved (the "where")

| File | Role |
|------|------|
| `lib/screens/evacuation_screen.dart` | The screen: planning map, center list, the whole routing decision flow, live updates, offline logic. |
| `lib/services/hazard_routing_service.dart` | The "brain": hazard model, distance math, "is a hazard near this route?", detour/corridor math, the radii. |
| `lib/services/alert_service.dart` | Fetches `/api/alerts`, normalizes each alert (severity, coordinates), caches it. |
| `lib/services/hive_service.dart` | Local cache (Hive) for alerts, reports, centers, and routes — powers offline. Now caches routes **per center**. |
| `lib/services/notification_service.dart` | App notifications (`showLocalAlert()` for the "no safe route" fallback). |
| `packages/flutter_mapbox_navigation/.../activity/NavigationActivity.kt` | The native Mapbox turn-by-turn screen. Patched to walk, to reroute live, and to draw hazard markers. |
| `packages/flutter_mapbox_navigation/.../FlutterMapboxNavigationPlugin.kt` | The Dart↔native bridge (MethodChannel handlers). |

---

## 7. Walking navigation (not driving)

**What:** Turn-by-turn follows **pedestrian** paths — footways, shortcuts, ignoring
one-way *car* rules.

**Why:** People evacuate on foot. The navigator was secretly using the `driving-traffic`
profile, so it obeyed car rules and missed shortcuts.

**Where:** `NavigationActivity.requestRoutes()` passes the walking profile the plugin
parses from our options. The Dart side asks for walking in `_buildMapboxOptions()`
(`mode: MapBoxNavigationMode.walking`).

---

## 8. Loading hazards reliably

**What:** Turn raw alerts/reports into `HazardPoint`s (location + severity + type).

**Why it was tricky:** Backends store coordinates in many shapes (`lat/lng`,
`latitude/longitude`, nested `location.coordinates` object, or MongoDB GeoJSON
`[lng, lat]` array, sometimes as strings). The old code read one shape, so many hazards
were dropped or misplaced.

**Where:** `HazardAwareRoutingService.extractLatLng()` reads **all** those shapes, used by
`_fromAlert`, `_fromReport`, and the marker builder so the map and routing always agree.

**Severity mapping** (so "critical" means the same everywhere):
- Alerts: `evacuate`/`critical` → `critical`; `warning` → `high`; else → `moderate`.
- Reports: `High` → `critical`; `Medium` → `high`; else → `moderate`.

A hazard is "critical" when `severity == 'critical'` (`HazardPoint.isCritical`). **Only
critical hazards force a reroute**; lower severities only warn.

---

## 9. The two radii — the heart of the logic

Each hazard is a **pin** (a single point). We measure how close the route passes to that
pin and decide what to do, using **two** distances:

| Radius | Value | Meaning | Used for |
|--------|-------|---------|----------|
| **Block radius** | **40 m** | "This street is impassable." | Forcing a reroute, and checking a reroute is clear. |
| **Warn radius** | **200 m** | "A hazard is near your route." | Just informing the user. |

**Why 40 m (it used to be 70 m)?** The reroute must stay *outside* the block radius to
count as "safe." In a city, the next parallel street is often only ~50 m away. At 70 m,
that parallel street still counted as blocked, so **no detour ever qualified** and the app
wrongly said "all routes blocked." At **40 m**, a hazard blocks only **its own street**,
and the neighbouring street becomes a valid reroute. This is the "block one street at a
time" behaviour.

**Where:** `_blockRadiusMeters` / `_warnRadiusMeters` and `hazardsWithin(geometry,
hazards, radius)` in `hazard_routing_service.dart`. The big per-type "danger zone"
(`effectiveRadius`, e.g. 500 m for floods) is used **only** for cosmetic center badges and
filtering out centers sitting inside a hazard — **not** for route blocking.

---

## 10. The routing decision flow (when you tap Navigate, online)

**Where:** `_startEvacuation()` in `evacuation_screen.dart`, with `_analyzeRouteOptions()`
and `_findSafeWalkingRoute()`.

1. **Gather hazards** (`_hazardPoints`, falling back to cache/zones).
2. **Ask Mapbox for walking routes** (`_fetchMapboxAlternatives`, `alternatives=true`).
3. **Tag each route** (`_analyzeRouteOptions`):
   - `criticals` = critical hazards within **40 m** (blocking).
   - `warnings` = anything within **200 m** that isn't blocking.
4. **Decide:**
   - **Blocking critical → auto-reroute** to the **shortest safe** route via
     `_findSafeWalkingRoute` (Section 11). Only if *nothing* clears do we show the red
     **"Hazard Cannot Be Avoided"** dialog.
   - **Only warnings → ask the user**: **Use Alternative / Continue / Cancel**
     (`_showHazardOnRouteDialog`). "Use Alternative" appears only if a clear path exists.
   - **Clean → just go.**
5. **Hand the chosen route to the navigator** and **cache it per center** for offline.

---

## 11. How a safe detour is found — `_findSafeWalkingRoute` + corridor detours

This is the part that finally made rerouting reliable.

**The earlier bug:** detours used a **single** side waypoint (`origin → via → dest`).
Mapbox honoured the via but then routed `via → dest` straight back through the hazard
street (shortest way to the goal), so the detour never actually avoided the hazard.

**The fix — a "corridor" (two waypoints):** we place **two** waypoints that **straddle**
the hazard (one before it, one after it, both pushed to the *same* side). The route
`origin → via1 → via2 → dest` is forced to swing around the **whole** hazard span.
We try **both sides** at escalating offsets (**60/120/200/350 m**), keep only routes that
clear the 40 m block radius, and return the **shortest** one. If none clears → null
(genuine dead-end). (Math: `computeCorridorWaypoints` in `hazard_routing_service.dart`.)

**Making the navigator follow it — `_detourViaPoints`:** the native navigator builds its
*own* route through whatever waypoints we hand it. If we give it too few, it cuts corners
*between* them — back through the hazard — which looked like "no reroute at all." So we
drop **up to 22 silent waypoints** densely along our safe route (≈ every route/22, ≥100 m
apart; Mapbox allows 25 coordinates total). "Silent" = they shape the path but aren't
stops. This pins the navigator tightly to the safe corridor.

> `_tryForcedDetour` (the older single-via helper) still exists, but only for the
> *warning* case ("is there any cleaner alternative to offer?"). Critical reroutes use the
> stronger corridor search.

---

## 12. Hazard markers on the navigation map

**What:** While you're in the full-screen Mapbox navigation, hazards show as **red discs
with a white "!"** on top of the blue route line.

**How (native, in `NavigationActivity.kt`):**
- When the map attaches, we wait for its **style to finish loading**, then create a
  `PointAnnotationManager` (the thing that draws point icons). Creating it before the
  style is ready silently draws nothing — another lesson learned.
- `applyHazards(...)` (called from Dart via the bridge) stores the hazards and
  `renderHazards()` draws one marker per hazard. The icon is generated in code
  (`hazardBitmap`) — no image asset needed — coloured by severity.
- `bringHazardsToFront()` re-creates the marker layer **after** the route line is drawn,
  so markers sit **above** the blue line instead of being hidden under it.

**From Dart:** `_pushHazardMarkersToNav()` sends the current hazards to the map whenever a
route is built and on every live hazard update (`evacuation_screen.dart`).

---

## 13. Live updates + live rerouting (Socket.IO)

**What:** The screen updates by itself when the admin posts/dismisses a hazard, a report
is approved, or a center changes — no manual refresh.

**Where:** `_initLiveUpdates()` connects to `ApiService.baseUrl` over WebSocket and listens
for:
- Hazard events: `new_alert`, `alert_updated`, `report_status_updated`, `report_updated`
  → reloads hazards.
- Center events: `evacuation_updated`, `evacuation_center_created` → reloads centers.

**Debounce:** one admin action can fire several events, so we wait **800 ms** and reload
once (`_scheduleHazardRefresh` / `_scheduleCenterRefresh`).

**Live rerouting (the headline feature) — `_refreshHazardsLive` → `_liveRerouteAround`:**
If you are **already navigating** and a **new critical** hazard lands within 40 m of your
**active route**, the app:
1. recomputes the **shortest safe** route with the same `_findSafeWalkingRoute`,
2. calls `reroute(...)` over the bridge so the navigator **swaps the route live**,
3. shows a brief **"Hazard ahead — rerouting"** banner.

If **no** safe route exists (a true dead-end), it does **not** invent a risky path — it
keeps the current route and fires a notification ("New hazard on your route — re-check
your route"). Each hazard triggers at most once per trip (reset in `_startEvacuation`).

> A "Socket" is a live two-way connection kept open so the server can *push* updates to the
> phone instantly, instead of the app repeatedly asking.

---

## 14. Offline support (now matches the online Mapbox route)

**What:** With no internet, the screen still shows cached centers + hazards. If you
previously navigated to a center **while online**, going offline and choosing that center
redraws the **exact same Mapbox/hazard-aware route** (including its detours) on the OSM
map. If a center was never routed online, it falls back to a straight-line compass.

**The earlier bug:** the app cached only **one** route (the last one) and offline drew
that route **no matter which center you picked** — so it often showed the wrong center's
path.

**The fix:** routes are cached **per center** (key `route_<centerId>`) in
`hive_service.dart` (`cacheEvacuationRoute(..., centerId)`), and the offline branch of
`_startEvacuation` loads the route for the **selected** center
(`getCachedEvacuationRouteForCenter`).

**Limitation:** offline can only show centers you've routed to at least once online (that's
when the route gets cached). Pre-fetching routes for all centers is a possible future
add-on.

---

## 15. Key numbers you can tune

| Setting | Where | Default | Effect |
|---------|-------|---------|--------|
| Block radius | `hazard_routing_service.dart` `_blockRadiusMeters` | 40 m | How close a critical hazard must be to block a street / force a reroute. |
| Warn radius | `hazard_routing_service.dart` `_warnRadiusMeters` | 200 m | How close any hazard must be to warn the user. |
| Corridor offsets | `hazard_routing_service.dart` `computeCorridorWaypoints` | 60/120/200/350 m | How far the detour swings out from the hazard. |
| Route pinning density | `evacuation_screen.dart` `_detourViaPoints` | ≤22 pts, ≥100 m apart | How tightly the navigator follows the safe corridor. |
| Live debounce | `evacuation_screen.dart` `_schedule*Refresh` | 800 ms | How long to wait before reloading after an event. |
| Marker look | `NavigationActivity.kt` `hazardBitmap` | red/orange/yellow disc + "!" | Marker colour/size on the nav map. |

---

## 16. How to test

1. **Walking route:** Start navigation; turn-by-turn uses footpaths, may ignore one-way
   *car* rules.
2. **On-street hazard with a parallel street:** Put a **critical** hazard on the route's
   street → it detours via the parallel street; no "all blocked".
3. **Live reroute:** While navigating, post a critical hazard on the street ahead → the
   route swaps live + "Hazard ahead — rerouting" banner, **without** exiting navigation.
4. **Markers:** During navigation, hazards show as red "!" dots on top of the blue line.
5. **Nearby hazard (~120 m):** You get the **Use Alternative / Continue** dialog (a warning,
   not a forced reroute).
6. **Boxed-in destination:** Hazard surrounds the destination → red "Hazard Cannot Be
   Avoided" dialog, or live: notification + keep current route.
7. **Offline match:** Navigate to a center online (caches it) → airplane mode → navigate to
   the **same** center → OSM shows the same route (with detours).

---

## 17. Troubleshooting with logs

We left lightweight logs in so behaviour is observable. Two streams:

- **Dart** (in the `flutter run` console, or `adb logcat` tag `flutter`):
  - `[Reroute] token=… blocking=… criticals=…` / `clearedLengths=[…]` / `chosen length=…m`
    or `no clear route -> null (dead-end)` — shows the safe-route search result.
  - `[LiveReroute] triggered / applying / no safe route` — shows the live path firing.
  - `[Markers] pushing N hazards to nav` — Dart asked the map to draw N markers.
- **Native** (`adb logcat -s EvacHazard`):
  - `applyHazards: N` → `renderHazards: drew N markers` — markers reached and drew.
  - `applyReroute: N waypoints` → `routes built: N; swapping active route` — live swap ran.

To see both at once on Windows PowerShell:
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" logcat -v brief |
  Select-String "EvacHazard","Reroute","Markers"
```

Reading the result: if `[Reroute] chosen length` appears but you saw no detour, the route
pinning was too sparse (Section 11). If `applyHazards: 0`, the Dart hazard list was empty.
If you see `[Markers] pushing N` but no `applyHazards`, the bridge call didn't reach the
navigation screen.

---

## 18. Build notes

- Native Kotlin lives in `packages/flutter_mapbox_navigation/` → after pulling or editing
  it, do a **full `flutter run`** (hot reload/restart will NOT recompile native code).
- Requires `MAPBOX_ACCESS_TOKEN` in `.env` (declared as an asset in `pubspec.yaml`, loaded
  in `main.dart`) for the Directions/detour lookups, plus the Mapbox token in the Android
  resources for the navigator itself.
- No backend changes were needed — the server already exposes the APIs and Socket.IO
  events this feature relies on (`new_alert` is emitted from
  `etelly-mern/server/routes/alerts.js`).
- Currently **Android-only** for the live-reroute and marker features; iOS parity (Swift)
  is a future task.
