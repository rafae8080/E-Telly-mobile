import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../screens/evacuation_screen.dart' show EvacuationCenter;
import 'hive_service.dart';

class HazardPoint {
  final String id;
  final String type;
  final String severity;
  final String source;
  final String label;
  final LatLng location;
  final DateTime createdAt;

  const HazardPoint({
    required this.id,
    required this.type,
    required this.severity,
    required this.source,
    required this.label,
    required this.location,
    required this.createdAt,
  });

  bool get isCritical => severity == 'critical';
}

class HazardAwareRoutingService {

  static const Map<String, double> _criticalRadii = {
    'flood':       500.0,
    'lahar':       600.0,
    'volcano':     800.0,
    'typhoon':     400.0,
    'landslide':   350.0,
    'fire':        200.0,
    'earthquake':  150.0,
    'river':       450.0,
    'rainfall':    450.0,
    'water_level': 450.0,
    'evacuate':    400.0,
    'other':       300.0,
  };

  static const double _warningMultiplier = 0.60;
  static const double _watchMultiplier   = 0.30;
  static const double _sampleIntervalMeters = 20.0;  // tighter sampling to catch 25 m zones
  static const double _detourOffsetMeters   = 550.0;

  // Two route radii (decoupled on purpose — see HAZARD plan):
  //  • blockRadius: a CRITICAL hazard within this of the route makes that street
  //    impassable → forces a reroute, and a reroute must stay outside it to count
  //    as clear. STREET-LEVEL: ~one street width + GPS slack, so a hazard blocks
  //    only its own street and the adjacent street (~50 m away) qualifies as a
  //    valid reroute — i.e. we block one street at a time, not whole grids.
  //  • warnRadius: any hazard within this (but not blocking) just informs the user.
  // The large per-type danger zone (effectiveRadius) is only for center badges and
  // safe-center filtering, NOT for route blocking.
  static const double _blockRadiusMeters = 40.0;
  static const double _warnRadiusMeters  = 200.0;

  static double get blockRadius => _blockRadiusMeters;
  static double get warnRadius  => _warnRadiusMeters;

  static double criticalRadiusFor(String type) =>
      _criticalRadii[type.toLowerCase()] ?? _criticalRadii['other']!;

  static double effectiveRadius(HazardPoint h) {
    final base = criticalRadiusFor(h.type);
    switch (h.severity) {
      case 'critical': return base;
      case 'high':     return base * _warningMultiplier;
      case 'moderate': return base * _watchMultiplier;
      default:         return base;
    }
  }

  static double distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final s = sin(dLat / 2);
    final t = sin(dLng / 2);
    final h = s * s + cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * t * t;
    return 2 * R * asin(sqrt(h));
  }

  static double _rad(double d) => d * pi / 180.0;


  static Future<List<HazardPoint>> loadAllHazardPoints() async {
    final out = <HazardPoint>[];
    final alerts  = await HiveService.getCachedAlerts();
    final reports = await HiveService.getCachedCommunityReports();
    for (final a in alerts) {
      final p = _fromAlert(a);
      if (p != null) out.add(p);
    }
    for (final r in reports) {
      final p = _fromReport(r);
      if (p != null) out.add(p);
    }
    return out;
  }

  // Tolerant coordinate reader. Handles every shape the web/admin backends use:
  //   { lat, lng } / { latitude, longitude }
  //   { location: { lat/latitude, lng/longitude } }
  //   { location: { coordinates: { latitude, longitude } } }
  //   { location: { coordinates: [lng, lat] } }   ← MongoDB GeoJSON
  //   { coordinates: [lng, lat] }
  // Values may be num or String. Returns null when nothing usable is found.
  static LatLng? extractLatLng(Map<String, dynamic> m) {
    num? lat = _num(m['lat']) ?? _num(m['latitude']);
    num? lng = _num(m['lng']) ?? _num(m['longitude']);

    final loc = m['location'];
    if ((lat == null || lng == null) && loc is Map) {
      lat ??= _num(loc['lat']) ?? _num(loc['latitude']);
      lng ??= _num(loc['lng']) ?? _num(loc['longitude']);
      final c = loc['coordinates'];
      if ((lat == null || lng == null)) {
        if (c is Map) {
          lat ??= _num(c['latitude']) ?? _num(c['lat']);
          lng ??= _num(c['longitude']) ?? _num(c['lng']);
        } else if (c is List && c.length >= 2) {
          lng ??= _num(c[0]); // GeoJSON is [lng, lat]
          lat ??= _num(c[1]);
        }
      }
    }

    final topCoords = m['coordinates'];
    if ((lat == null || lng == null) && topCoords is List && topCoords.length >= 2) {
      lng ??= _num(topCoords[0]);
      lat ??= _num(topCoords[1]);
    }

    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static num? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static HazardPoint? _fromAlert(Map<String, dynamic> a) {
    try {
      final loc = extractLatLng(a) ??
          _barangayCenter((a['barangay'] as String? ?? '').split(',').first.trim());
      final severity = a['severity'] as String? ?? 'moderate';
      final type     = a['alertType'] as String? ?? a['type'] as String? ?? 'other';
      return HazardPoint(
        id: a['id'] as String? ?? '',
        type: type,
        severity: severity,
        source: 'alert',
        label: '${_cap(type)} ${_sevLabel(severity)}',
        location: loc,
        createdAt: DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('[HazardRouting] alert parse error: $e');
      return null;
    }
  }

  static HazardPoint? _fromReport(Map<String, dynamic> r) {
    try {
      final loc = extractLatLng(r);
      if (loc == null) return null; // report has no usable coordinates
      final rawSev  = (r['severity'] as String? ?? 'Low').toLowerCase();
      final severity = rawSev == 'high' ? 'critical' : rawSev == 'medium' ? 'high' : 'moderate';
      final type = r['emergencyType'] as String? ?? r['type'] as String? ?? 'other';
      return HazardPoint(
        id: r['_id']?.toString() ?? r['id']?.toString() ?? '',
        type: type,
        severity: severity,
        source: 'community_report',
        label: '${_cap(type)} ${_sevLabel(severity)} (Report)',
        location: loc,
        createdAt: DateTime.tryParse(r['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('[HazardRouting] report parse error: $e');
      return null;
    }
  }

  static List<EvacuationCenter> filterSafeCenters(
      List<EvacuationCenter> centers, List<HazardPoint> hazards) {
    final crits = hazards.where((h) => h.isCritical).toList();
    return centers.where((c) => !crits.any(
        (h) => distanceMeters(c.latLng, h.location) <= criticalRadiusFor(h.type))).toList();
  }

  static List<EvacuationCenter> annotateCentersWithHazards(
      List<EvacuationCenter> centers, List<HazardPoint> hazards) {
    for (final c in centers) {
      HazardPoint? nearest;
      double nearestDist = double.infinity;
      for (final h in hazards) {
        final d = distanceMeters(c.latLng, h.location);
        if (d <= effectiveRadius(h) && d < nearestDist) {
          nearest = h;
          nearestDist = d;
        }
      }
      if (nearest != null) {
        c.hazardSeverityLevel = nearest.severity;
        c.hazardType = nearest.type;
        c.isHazardAffected = true;
      } else {
        c.hazardSeverityLevel = 'none';
        c.isHazardAffected = false;
      }
    }
    return centers;
  }

  // Hazards whose location comes within [radiusMeters] of the route geometry.
  // Caller chooses the radius: blockRadius for impassable detection / reroute
  // clearance, warnRadius for informational "near your route" detection.
  static List<HazardPoint> hazardsWithin(
      List<LatLng> geometry, List<HazardPoint> hazards, double radiusMeters) {
    if (geometry.isEmpty) return [];
    final samples = _sampleRoute(geometry);
    final found = <HazardPoint>{};
    for (final pt in samples) {
      for (final h in hazards) {
        if (distanceMeters(pt, h.location) <= radiusMeters) found.add(h);
      }
    }
    return found.toList();
  }

  // Fallback when Mapbox Directions geometry is unavailable. Samples the straight
  // line every 50 m and flags hazards within [radiusMeters] of it.
  static List<HazardPoint> getHazardsNearStraightLine(
      LatLng a, LatLng b, List<HazardPoint> hazards, double radiusMeters) {
    final totalDist = distanceMeters(a, b);
    final steps = max(10, (totalDist / 50).ceil());
    final found = <HazardPoint>{};
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final pt = LatLng(
        a.latitude  + t * (b.latitude  - a.latitude),
        a.longitude + t * (b.longitude - a.longitude),
      );
      for (final h in hazards) {
        if (distanceMeters(pt, h.location) <= radiusMeters) found.add(h);
      }
    }
    return found.toList();
  }

  static List<LatLng> _sampleRoute(List<LatLng> geo) {
    final out = <LatLng>[geo.first];
    double acc = 0;
    LatLng prev = geo.first;
    for (int i = 1; i < geo.length; i++) {
      final curr = geo[i];
      final seg = distanceMeters(prev, curr);
      acc += seg;
      while (acc >= _sampleIntervalMeters) {
        final t = 1.0 - (acc - _sampleIntervalMeters) / seg;
        out.add(LatLng(
          prev.latitude  + t * (curr.latitude  - prev.latitude),
          prev.longitude + t * (curr.longitude - prev.longitude),
        ));
        acc -= _sampleIntervalMeters;
      }
      prev = curr;
    }
    return out;
  }

  // Both perpendicular detour waypoints around [hazardCenter], offset to either
  // side of the inbound→outbound line. Ordered farther-from-hazard first so a
  // caller that only tries one gets the more promising side. Empty if degenerate.
  static List<LatLng> computeDetourWaypoints(
      LatLng hazardCenter, LatLng inbound, LatLng outbound,
      {double? offsetMeters}) {
    final dx = outbound.longitude - inbound.longitude;
    final dy = outbound.latitude  - inbound.latitude;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return const [];
    final perpX = dy / len;
    final perpY = -dx / len;
    final deg = (offsetMeters ?? _detourOffsetMeters) / 111320.0;
    final cA = LatLng(hazardCenter.latitude + perpX * deg, hazardCenter.longitude + perpY * deg);
    final cB = LatLng(hazardCenter.latitude - perpX * deg, hazardCenter.longitude - perpY * deg);
    return distanceMeters(cA, hazardCenter) >= distanceMeters(cB, hazardCenter)
        ? [cA, cB]
        : [cB, cA];
  }

  // Corridor detour waypoint PAIRS around [hazardCenter]. A single side via-point
  // can't make a walking route avoid a hazard AREA — Mapbox routes via→dest
  // straight back through the hazard street. So we straddle the hazard: place two
  // via-points, one BEFORE and one AFTER the hazard along the origin→dest line,
  // both pushed to the SAME side, forcing the path to swing around the whole
  // hazard span. Returns one [via1, via2] pair per (offset × side), ordered
  // nearest-offset first and via1 (toward origin) first within each pair. Empty if
  // degenerate.
  static List<List<LatLng>> computeCorridorWaypoints(
      LatLng hazardCenter, LatLng origin, LatLng dest,
      {List<double> offsetsMeters = const [60, 120, 200, 350]}) {
    final dx = dest.longitude - origin.longitude; // longitude delta
    final dy = dest.latitude  - origin.latitude;  // latitude  delta
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return const [];

    // Unit direction (lat,lng components) and a unit perpendicular to it.
    final dirLat = dy / len, dirLng = dx / len;
    final perpLat = dx / len, perpLng = -dy / len;
    const mPerDeg = 111320.0;

    LatLng pt(double sideSign, double alongSign, double side, double span) => LatLng(
          hazardCenter.latitude +
              alongSign * dirLat * (span / mPerDeg) +
              sideSign * perpLat * (side / mPerDeg),
          hazardCenter.longitude +
              alongSign * dirLng * (span / mPerDeg) +
              sideSign * perpLng * (side / mPerDeg),
        );

    final out = <List<LatLng>>[];
    for (final off in offsetsMeters) {
      final span = off + _blockRadiusMeters; // straddle clear of the block radius
      for (final side in const [1.0, -1.0]) {
        out.add([pt(side, -1.0, off, span), pt(side, 1.0, off, span)]);
      }
    }
    return out;
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _sevLabel(String s) {
    switch (s) {
      case 'critical': return 'Critical';
      case 'high':     return 'Warning';
      case 'moderate': return 'Watch';
      default:         return 'Alert';
    }
  }

  static LatLng _barangayCenter(String barangay) {
    const m = {
      'san roque':    LatLng(14.5832, 121.1719),
      'mambugan':     LatLng(14.6206, 121.1416),
      'mayamot':      LatLng(14.6247, 121.1233),
      'san jose':     LatLng(14.6236, 121.2598),
      'cupang':       LatLng(14.6360, 121.1239),
      'dela paz':     LatLng(14.5901, 121.1703),
      'muntindilaw':  LatLng(14.5989, 121.1301),
      'bagong nayon': LatLng(14.6261, 121.1687),
      'beverly hills':LatLng(14.5843, 121.1582),
      'calawis':      LatLng(14.6731, 121.2423),
      'dalig':        LatLng(14.5763, 121.1820),
      'inarawan':     LatLng(14.6248, 121.1950),
      'san isidro':   LatLng(14.5916, 121.1838),
      'san juan':     LatLng(14.6278, 121.1770),
      'san luis':     LatLng(14.6043, 121.1981),
      'santa cruz':   LatLng(14.6157, 121.1694),
    };
    return m[barangay.toLowerCase()] ?? const LatLng(14.5832, 121.1719);
  }
}
