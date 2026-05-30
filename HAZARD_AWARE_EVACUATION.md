# Hazard-Aware Evacuation Navigation — How It Works

A beginner-friendly guide to the evacuation navigation feature: **what** was built,
**why**, and **where** to find it in the code. This document reflects the code as it is
now (post-cleanup), not an old plan.

---

## 1. The big picture

When a disaster happens, a user opens the **Evacuation** screen and walks to a nearby
evacuation center. This feature makes that walk **safe and live**:

1. It shows evacuation centers and active **hazards** (floods, fires, etc.) on a map.
2. When the user taps **Navigate**, it builds a **walking** route.
3. If a hazard sits **on that route**, it automatically **reroutes** around it via other
   streets. If a hazard is only *near* the route, it just **warns** the user.
4. Everything updates **live** (via Socket.IO) — no manual refresh. New hazards appear
   on their own, and if one lands on the route you're currently walking, your phone
   gets a notification.
5. It still works **offline** using cached data.

Hazards come from two places, both managed by the web/admin system:
- **Admin alerts** (`/api/alerts`) — e.g. an officer marks a flooded street.
- **Approved community reports** (`/api/reports/approved`) — citizen reports.

---

## 2. Files involved (the "where")

| File | Role |
|------|------|
| `lib/screens/evacuation_screen.dart` | The screen: map, center list, the whole routing decision flow, and live updates. |
| `lib/services/hazard_routing_service.dart` | The "brain": hazard model, distance math, how near a hazard is to a route, detour math. |
| `lib/services/alert_service.dart` | Fetches `/api/alerts` and normalizes each alert (severity, coordinates) + caches it. |
| `lib/services/hive_service.dart` | Local cache (Hive) for alerts, reports, centers, and the last route — powers offline. |
| `lib/services/notification_service.dart` | App notifications. We added `showLocalAlert()` for the mid-walk hazard warning. |
| `packages/flutter_mapbox_navigation/.../activity/NavigationActivity.kt` | The Mapbox turn-by-turn screen (native Android). Patched to walk, not drive. |

> The Mapbox plugin lives under `packages/` and is wired in via `dependency_overrides`
> in `pubspec.yaml`, so our edits to it are part of this repo.

---

## 3. Walking navigation (not driving)

**What:** Turn-by-turn navigation follows **pedestrian** paths — footways, shortcuts,
ignoring one-way *car* rules.

**Why:** People evacuate on foot. The navigator was secretly using the
`driving-traffic` profile, so it obeyed car rules and missed shortcuts.

**Where:** `NavigationActivity.requestRoutes()` built the route with
`.applyDefaultNavigationOptions()` and **no profile** (which defaults to driving). We
pass the walking profile that the plugin already parses from our options:

```kotlin
.applyDefaultNavigationOptions(FlutterMapboxNavigationPlugin.navigationMode)
```

The Dart side already asks for walking in `_buildMapboxOptions()`
(`mode: MapBoxNavigationMode.walking`).

> ⚠️ This is **native Kotlin**. After changing it you must do a full `flutter run`
> (a hot reload/restart will NOT pick it up).

---

## 4. Loading hazards reliably

**What:** Turn raw alerts/reports into `HazardPoint`s (a location + severity + type).

**Why it was tricky:** Different backends store coordinates differently
(`lat/lng`, `latitude/longitude`, nested `location.coordinates` as an object, or a
MongoDB GeoJSON `[lng, lat]` **array**, sometimes as strings). The old code only read
one shape, so many hazards were silently dropped or placed at the wrong spot.

**Where:** `HazardAwareRoutingService.extractLatLng()` reads **all** those shapes. It's
used by `_fromAlert`, `_fromReport`, and the map-marker builder in
`evacuation_screen.dart` (`_buildHazardState`) so the map and the routing always agree.

**Severity mapping** (so "critical" means the same everywhere):
- Alerts (`alert_service.dart`): `evacuate`/`critical` → `critical`; `warning` → `high`;
  everything else → `moderate`.
- Reports (`hazard_routing_service.dart` `_fromReport`): `High` → `critical`;
  `Medium` → `high`; else → `moderate`.

A hazard is "critical" when `severity == 'critical'` (`HazardPoint.isCritical`).

---

## 5. The two radii — the heart of the logic

This is the most important idea. Each hazard has a **location** (a pin). We measure how
close the route passes to that pin and decide what to do. We use **two** distances:

| Radius | Value | Meaning | Used for |
|--------|-------|---------|----------|
| **Block radius** | **70 m** | "This street is impassable." | Forcing a reroute, and checking a reroute is clear. |
| **Warn radius** | **200 m** | "A hazard is near your route." | Just informing the user (no forced reroute). |

**Why two?** Earlier we used one big radius (the per-type "danger zone", e.g. 500 m for
a flood). That made *every* nearby route count as blocked, and **no** walking detour
could ever stay 500 m away — so the app always said "all routes blocked." Splitting it
fixes that:

- A **critical** hazard within **70 m** of the route → that street is blocked → **reroute**.
- Any hazard within **200 m** (but not blocking) → **warn** only.
- Farther than 200 m → ignored for routing.

**Where:** `blockRadius` / `warnRadius` constants and `hazardsWithin(geometry, hazards,
radius)` in `hazard_routing_service.dart`. The big per-type "danger zone"
(`effectiveRadius`) is now used **only** for cosmetic things — the colored hazard badge
on center cards and filtering out centers that sit inside a flood.

To make hazards more or less sensitive, change `_blockRadiusMeters` /
`_warnRadiusMeters` at the top of `hazard_routing_service.dart`.

---

## 6. The routing decision flow

**Where:** `_startEvacuation()` in `evacuation_screen.dart`, helped by
`_analyzeRouteOptions()` and `_tryForcedDetour()`.

Step by step when the user taps Navigate (and is online):

1. **Gather hazards** (`_hazardPoints`, falling back to cache/zones).
2. **Ask Mapbox for walking routes** between the user and the center
   (`_fetchMapboxAlternatives`, with `alternatives=true`).
3. **Tag each route** (`_analyzeRouteOptions`):
   - `criticals` = critical hazards within **70 m** (blocking).
   - `warnings` = anything within **200 m** that isn't blocking.
4. **Decide:**
   - **Blocking critical on the best route → auto-reroute.** First try another Mapbox
     alternative that's clear; if none, **force a detour** (`_tryForcedDetour`). If a
     clear path is found, use it silently ("Route adjusted for safety"). Only if
     *nothing* avoids it do we show the red **"Hazard Cannot Be Avoided"** dialog.
   - **Only warnings → ask the user**: a dialog with **Use Alternative / Continue /
     Cancel** (`_showHazardOnRouteDialog`). "Use Alternative" appears only if a clear
     path actually exists.
   - **Clean → just go.**
5. **Hand the chosen route to the Mapbox navigator** and cache it for offline.

### How a detour is found (`_tryForcedDetour`)
Mapbox often returns only **one** walking route, so we build our own detour: place a
waypoint **perpendicular** to the straight line, off to one side of the hazard, and ask
Mapbox to route through it. We try **both sides** at **two escalating offsets**
(block+150 m, then block+450 m). The first route that stays clear of the 70 m block
radius wins. Only if all four attempts fail do we declare it blocked. (Math:
`computeDetourWaypoints` in `hazard_routing_service.dart`.)

### Making the navigator actually follow the detour (`_detourViaPoints`)
The Mapbox turn-by-turn builds its *own* route through the waypoints we give it. A
single waypoint isn't enough — it could still cut back through the hazard. So when we
reroute, we drop **several silent waypoints** evenly along our safe route (≈ every ⅙ of
it, ≥150 m apart, max 8). "Silent" means they shape the route but aren't stops. This
pins the navigator to the safe corridor.

> This used to cause looping, but only because of an old bug where walking-route points
> were fed to a *driving* navigator. Now that the navigator walks (Section 3) and
> waypoint order is preserved, it follows the corridor cleanly. Clean (no-hazard) routes
> still send just start→end, so they never loop.

---

## 7. Offline support

**What:** With no internet, the screen still shows cached centers + hazards, and if a
route was navigated before, it's drawn as a blue line on the map (OpenStreetMap tiles
cached by the OS). If there's no cached route, a compass widget shows direction.

**Where:** `_loadCentersFromCache`, `_loadHazardZonesFromCache`, the offline branch of
`_startEvacuation`, and the `HiveService` cache methods. Hazard coordinates survive
offline because `alert_service.dart` stores `lat`/`lng` in the cache.

---

## 8. Live updates (Socket.IO)

**What:** The screen updates by itself when the admin posts/dismisses a hazard, a report
is approved, or a center changes — no manual refresh.

**Why it's easy:** The server **already broadcasts** these events, and the app already
uses Socket.IO elsewhere. We just listen on the evacuation screen.

**Where:** `_initLiveUpdates()` in `evacuation_screen.dart`. It connects to
`ApiService.baseUrl` over WebSocket and listens for:
- Hazard events: `new_alert`, `alert_updated`, `report_status_updated`, `report_updated`
  → reloads hazards (`_loadHazardZones`).
- Center events: `evacuation_updated`, `evacuation_center_created`
  → reloads centers (`_loadEvacuationCenters`).

**Debounce:** One admin action can fire several events at once, so we wait **800 ms**
and reload once (`_scheduleHazardRefresh` / `_scheduleCenterRefresh`).

**Mid-walk safety notification:** If you're *already navigating* and a **new critical**
hazard lands on your active route, the app fires a phone notification ("New hazard on
your route") via `NotificationService.showLocalAlert()`. It does **not** force-stop or
reroute — you re-check when ready. (`_refreshHazardsLive`; each hazard notifies once per
trip, reset in `_startEvacuation`.)

> A "Socket" is a live two-way connection that stays open, so the server can *push*
> updates to the phone instantly instead of the app having to keep asking.

---

## 9. Key numbers you can tune

| Setting | Where | Default | Effect |
|---------|-------|---------|--------|
| Block radius | `hazard_routing_service.dart` `_blockRadiusMeters` | 70 m | How close a critical hazard must be to force a reroute. |
| Warn radius | `hazard_routing_service.dart` `_warnRadiusMeters` | 200 m | How close any hazard must be to warn the user. |
| Detour offsets | `evacuation_screen.dart` `_tryForcedDetour` | block+150, block+450 | How far the detour pushes; bigger = wider go-around. |
| Corridor spacing | `evacuation_screen.dart` `_detourViaPoints` | ~total/6, ≥150 m | How tightly the navigator follows the detour. |
| Live debounce | `evacuation_screen.dart` `_schedule*Refresh` | 800 ms | How long to wait before reloading after an event. |

---

## 10. How to test

1. **Walking route:** Start navigation; the turn-by-turn should use footpaths and may
   ignore one-way *car* restrictions.
2. **On-street hazard:** Put a critical flood on the route's street with a parallel
   street open → the route detours via the other street, no "all blocked".
3. **Nearby hazard (~120 m):** You get the **Use Alternative / Continue** dialog, not a
   forced reroute.
4. **Boxed-in destination:** Hazard surrounds the destination → red "Hazard Cannot Be
   Avoided" dialog (correct — nothing can avoid it).
5. **Live:** Leave the screen open; create/dismiss an alert on the web → the map updates
   within ~1 second on its own.
6. **Mid-walk notification:** While navigating, post a critical alert on the route → a
   phone notification appears (navigation keeps running).
7. **Offline:** Turn off Wi-Fi → no crash; cached centers/hazards still show.

---

## 11. Build notes

- The walking fix is **native Android Kotlin** → run a full `flutter run` after pulling
  (not just hot reload).
- Requires `MAPBOX_ACCESS_TOKEN` in `.env` (used for the detour/alternative route
  lookups) and the Mapbox token in the Android resources (used by the navigator).
- No backend changes were needed — the server already exposes the APIs and the
  Socket.IO events this feature relies on.
