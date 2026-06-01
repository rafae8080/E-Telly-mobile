import 'dart:math';

/// Great-circle distance in kilometers between two lat/lng points (haversine).
///
/// Mirrors the formula already used in `lib/screens/evacuation_screen.dart`,
/// extracted here so the alerts "Near You" radius filter can reuse it.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371; // km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double degree) => degree * (pi / 180);
