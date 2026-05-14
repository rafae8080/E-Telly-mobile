import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

enum DisasterType { flood, typhoon, earthquake, landslide }

class HeatPoint {
  final double lat;
  final double lng;
  final double intensity;
  final DisasterType type;
  final String source;
  final DateTime timestamp;

  const HeatPoint({
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.type,
    required this.source,
    required this.timestamp,
  });
}

class DisasterMonitoringScreen extends StatefulWidget {
  const DisasterMonitoringScreen({super.key});

  @override
  State<DisasterMonitoringScreen> createState() =>
      _DisasterMonitoringScreenState();
}

class _DisasterMonitoringScreenState extends State<DisasterMonitoringScreen> {
  static const LatLng _defaultAntipoloCenter = LatLng(14.5874, 121.1761);
  static const LatLng _parFocusCenter = LatLng(15.8, 124.6);
  static const double _parFocusZoom = 5.9;
  static const List<String> _floodWmsLayers = ['geonode:marikina_fh100yr_10m'];
  static const String _philGeoportalWmsUrl =
      'https://geoserver.geoportal.gov.ph/geoserver/geoportal/wms?';
  static const List<String> _landslideWmsLayers = [
    'landslide10ksusceptibility',
  ];
  static const double _landslideOverlayOpacity = 0.32;
  static const double _philippinesLatitudeMin = 4.0;
  static const double _philippinesLatitudeMax = 21.5;
  static const double _philippinesLongitudeMin = 116.0;
  static const double _philippinesLongitudeMax = 127.5;

  final MapController _mapController = MapController();
  final String _backendBaseUrl = 'http://10.0.2.2:3000';

  DisasterType _selectedDisaster = DisasterType.flood;
  String _selectedBaseMap = 'cartoLight';

  bool _loading = false;
  LatLng? _userLocation;
  LatLng _mapCenter = _defaultAntipoloCenter;
  DateTime? _lastUpdated;
  TyphoonDetails? _typhoonDetails;
  bool _isTyphoonDetailsExpanded = false;

  List<HeatPoint> _heatPoints = const [];
  static const List<MapSourceLink> _typhoonSources = [
    MapSourceLink(
      label: 'Storm tracking',
      href: 'https://www.gdacs.org',
      text: 'GDACS',
    ),
    MapSourceLink(
      label: 'PH classification',
      href: 'https://www.pagasa.dost.gov.ph',
      text: 'PAGASA-DOST',
    ),
    MapSourceLink(
      label: 'Regional alerts',
      href: 'https://www.jma.go.jp/en/typh/',
      text: 'JMA RSMC Tokyo',
    ),
  ];
  static const List<MapSourceLink> _floodSources = [
    MapSourceLink(
      label: 'Flood discharge API',
      href: 'https://open-meteo.com/en/docs/flood-api',
      text: 'Open-Meteo Flood API',
    ),
    MapSourceLink(
      label: 'Flood hazard WMS',
      href: 'https://lipad-fmc.dream.upd.edu.ph/geoserver/wms?',
      text: 'LiPAD / UP DREAM',
    ),
  ];
  static const List<MapSourceLink> _earthquakeSources = [
    MapSourceLink(
      label: 'Earthquake feed',
      href: 'https://earthquake.usgs.gov/fdsnws/event/1/',
      text: 'USGS FDSN API',
    ),
  ];
  static const List<MapSourceLink> _landslideSources = [
    MapSourceLink(
      label: 'Landslide susceptibility WMS',
      href: 'https://geoserver.geoportal.gov.ph/geoserver/geoportal/wms?',
      text: 'PhilGeoportal',
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_initializeLocationAndData());
  }

  Future<void> _initializeLocationAndData() async {
    setState(() => _loading = true);
    final position = await _getCurrentLocation();

    if (!mounted) return;

    if (position != null &&
        _isWithinPhilippines(position.latitude, position.longitude)) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _lastUpdated = DateTime.now();
    });
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 8),
    );
  }

  bool _isWithinPhilippines(double latitude, double longitude) {
    return latitude >= _philippinesLatitudeMin &&
        latitude <= _philippinesLatitudeMax &&
        longitude >= _philippinesLongitudeMin &&
        longitude <= _philippinesLongitudeMax;
  }

  Future<List<HeatPoint>> _fetchLiveEarthquakePoints(LatLng center) async {
    final uri = Uri.parse(
      'https://earthquake.usgs.gov/fdsnws/event/1/query'
      '?format=geojson'
      '&latitude=${center.latitude}'
      '&longitude=${center.longitude}'
      '&maxradiuskm=350'
      '&minmagnitude=1.0'
      '&orderby=time'
      '&limit=50',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _buildMockPoints(center, DisasterType.earthquake);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>? ?? <dynamic>[];
      if (features.isEmpty) {
        return _buildMockPoints(center, DisasterType.earthquake);
      }

      final points = <HeatPoint>[];
      for (final rawFeature in features) {
        final feature = rawFeature as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;

        if (coordinates == null || coordinates.length < 2) continue;

        final magnitude = (properties?['mag'] as num?)?.toDouble() ?? 1.0;
        final timestampMillis = (properties?['time'] as num?)?.toInt();
        final lat = (coordinates[1] as num).toDouble();
        final lng = (coordinates[0] as num).toDouble();

        points.add(
          HeatPoint(
            lat: lat,
            lng: lng,
            intensity: (magnitude / 7.5).clamp(0.0, 1.0),
            type: DisasterType.earthquake,
            source: 'usgs-geojson',
            timestamp: timestampMillis == null
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(timestampMillis),
          ),
        );
      }

      return points.isEmpty
          ? _buildMockPoints(center, DisasterType.earthquake)
          : points;
    } catch (_) {
      return _buildMockPoints(center, DisasterType.earthquake);
    }
  }

  Future<void> _loadEarthquakeOverlay({required bool fitViewport}) async {
    setState(() => _loading = true);

    try {
      final points = await _fetchLiveEarthquakePoints(_defaultAntipoloCenter);

      if (!mounted) return;
      setState(() {
        _heatPoints = points;
        _lastUpdated = DateTime.now();
      });

      if (fitViewport && points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _selectedDisaster != DisasterType.earthquake) {
            return;
          }

          final coordinates = points
              .map((point) => LatLng(point.lat, point.lng))
              .toList();

          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: coordinates,
              padding: const EdgeInsets.all(48),
              minZoom: 8,
              maxZoom: 12.5,
              forceIntegerZoomLevel: false,
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _heatPoints = _buildMockPoints(_mapCenter, DisasterType.earthquake);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<HeatPoint>> _fetchFloodPoints(LatLng center) async {
    const offsets = <double>[-0.03, -0.015, 0.0, 0.015, 0.03];
    final samplePoints = <LatLng>[
      for (final latOffset in offsets)
        for (final lngOffset in offsets)
          LatLng(center.latitude + latOffset, center.longitude + lngOffset),
    ];

    final discharges = await Future.wait(
      samplePoints.map(_fetchFloodDischargeAt),
      eagerError: false,
    );

    final valid = discharges.whereType<double>().toList();
    if (valid.isEmpty) {
      return _buildMockPoints(center, DisasterType.flood);
    }

    final minVal = valid.reduce((a, b) => a < b ? a : b);
    final maxVal = valid.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();

    final points = <HeatPoint>[];
    for (var i = 0; i < samplePoints.length; i++) {
      final discharge = discharges[i];
      if (discharge == null) continue;

      final normalized = range < 0.0001
          ? 0.45
          : pow(
              ((discharge - minVal) / range).clamp(0.0, 1.0),
              0.85,
            ).toDouble();

      if (normalized < 0.22) continue;

      points.add(
        HeatPoint(
          lat: samplePoints[i].latitude,
          lng: samplePoints[i].longitude,
          intensity: normalized,
          type: DisasterType.flood,
          source: 'open-meteo-flood-grid',
          timestamp: DateTime.now(),
        ),
      );
    }

    return points.isEmpty
        ? _buildMockPoints(center, DisasterType.flood)
        : points;
  }

  Future<double?> _fetchFloodDischargeAt(LatLng point) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=${point.latitude}'
      '&longitude=${point.longitude}'
      '&daily=river_discharge'
      '&forecast_days=2'
      '&timezone=auto',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>?;
      final values = (daily?['river_discharge'] as List? ?? <dynamic>[])
          .cast<num>();
      if (values.isEmpty) return null;

      return values.reduce((a, b) => a > b ? a : b).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<List<HeatPoint>> _fetchTyphoonPoints() async {
    final now = DateTime.now();
    final fromDate = now.subtract(const Duration(days: 180));
    final eventListUri = Uri.parse(
      'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH'
      '?fromdate=${_formatDate(fromDate)}&todate=${_formatDate(now)}',
    );

    try {
      final eventResponse = await http
          .get(eventListUri)
          .timeout(const Duration(seconds: 12));
      if (eventResponse.statusCode != 200) {
        return _buildFallbackTyphoonTrack();
      }

      final eventData = jsonDecode(eventResponse.body) as Map<String, dynamic>;
      final features = eventData['features'] as List<dynamic>? ?? <dynamic>[];
      final tcFeatures = features
          .map((item) => item as Map<String, dynamic>)
          .where((feature) {
            final properties = feature['properties'] as Map<String, dynamic>?;
            final eventType = (properties?['eventtype'] as String?) ?? '';
            return eventType.toUpperCase() == 'TC';
          })
          .toList();

      if (tcFeatures.isEmpty) return _buildFallbackTyphoonTrack();

      tcFeatures.sort((a, b) {
        final pa = a['properties'] as Map<String, dynamic>?;
        final pb = b['properties'] as Map<String, dynamic>?;

        final aCurrent = '${pa?['iscurrent']}'.toLowerCase() == 'true';
        final bCurrent = '${pb?['iscurrent']}'.toLowerCase() == 'true';
        if (aCurrent != bCurrent) return bCurrent ? 1 : -1;

        final aDate =
            DateTime.tryParse('${pa?['todate'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse('${pb?['todate'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      final selected = tcFeatures.first;
      final selectedProps = selected['properties'] as Map<String, dynamic>?;
      _typhoonDetails = _extractTyphoonDetails(selectedProps);
      final eventId = selectedProps?['eventid'];
      final episodeId = selectedProps?['episodeid'];
      if (eventId == null || episodeId == null) {
        _typhoonDetails = _fallbackTyphoonDetails();
        return _buildFallbackTyphoonTrack();
      }

      final geometryUri = Uri.parse(
        'https://www.gdacs.org/gdacsapi/api/polygons/getgeometry'
        '?eventtype=TC&eventid=$eventId&episodeid=$episodeId',
      );

      final geometryResponse = await http
          .get(geometryUri)
          .timeout(const Duration(seconds: 12));
      if (geometryResponse.statusCode != 200) {
        _typhoonDetails = _fallbackTyphoonDetails();
        return _buildFallbackTyphoonTrack();
      }

      final geometryData =
          jsonDecode(geometryResponse.body) as Map<String, dynamic>;
      final geometryFeatures =
          geometryData['features'] as List<dynamic>? ?? <dynamic>[];

      final trackSegments = geometryFeatures
          .map((item) => item as Map<String, dynamic>)
          .where((feature) {
            final geometry = feature['geometry'] as Map<String, dynamic>?;
            if ((geometry?['type'] as String?) != 'LineString') return false;

            final properties = feature['properties'] as Map<String, dynamic>?;
            final name = '${properties?['name'] ?? ''}';
            final label = '${properties?['polygonlabel'] ?? ''}';
            final trackLikeName = name.contains('Tropical Cyclone');
            final trackLikeLabel =
                label == 'HU' || label == 'TS' || label == 'TD';

            return trackLikeName && trackLikeLabel;
          })
          .toList();

      if (trackSegments.isEmpty) return _buildFallbackTyphoonTrack();

      trackSegments.sort((a, b) {
        final classA = (a['properties'] as Map<String, dynamic>?)?['Class'];
        final classB = (b['properties'] as Map<String, dynamic>?)?['Class'];
        return _parseLineClassIndex(
          classA,
        ).compareTo(_parseLineClassIndex(classB));
      });

      final orderedCoordinates = <LatLng>[];
      for (final segment in trackSegments) {
        final geometry = segment['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;

        final start = coordinates.first as List<dynamic>;
        final end = coordinates.last as List<dynamic>;
        if (start.length < 2 || end.length < 2) continue;

        final startLat = (start[1] as num).toDouble();
        final startLng = (start[0] as num).toDouble();
        final endLat = (end[1] as num).toDouble();
        final endLng = (end[0] as num).toDouble();

        _pushUniquePoint(orderedCoordinates, LatLng(startLat, startLng));
        _pushUniquePoint(orderedCoordinates, LatLng(endLat, endLng));
      }

      final westPacificPath = orderedCoordinates.where((point) {
        return point.latitude >= 0 &&
            point.latitude <= 35 &&
            point.longitude >= 110 &&
            point.longitude <= 170;
      }).toList();

      if (westPacificPath.length < 2) return _buildFallbackTyphoonTrack();

      final trackLength = westPacificPath.length;
      return List<HeatPoint>.generate(trackLength, (index) {
        final point = westPacificPath[index];
        final intensity = (0.42 + (index / max(trackLength, 2)) * 0.48).clamp(
          0.0,
          1.0,
        );
        return HeatPoint(
          lat: point.latitude,
          lng: point.longitude,
          intensity: intensity,
          type: DisasterType.typhoon,
          source: 'gdacs-track',
          timestamp: now.subtract(Duration(hours: trackLength - index)),
        );
      });
    } catch (_) {
      _typhoonDetails = _fallbackTyphoonDetails();
      return _buildFallbackTyphoonTrack();
    }
  }

  TyphoonDetails _extractTyphoonDetails(Map<String, dynamic>? properties) {
    if (properties == null) return _fallbackTyphoonDetails();

    final severity = properties['severitydata'] as Map<String, dynamic>?;
    final severityText = '${severity?['severitytext'] ?? ''}'.trim();
    final classification = severityText.isNotEmpty
        ? severityText.split('(').first.trim()
        : 'Tropical Cyclone';

    final eventName =
        '${properties['eventname'] ?? properties['name'] ?? 'Typhoon'}'
            .replaceFirst('Tropical Cyclone ', '')
            .trim();

    final windKph = (severity?['severity'] as num?)?.toDouble();
    final alertLevel = '${properties['alertlevel'] ?? 'Unknown'}'.trim();
    final country = '${properties['country'] ?? ''}'.trim();
    final source = '${properties['source'] ?? 'GDACS'}'.trim();

    final fromDate = DateTime.tryParse('${properties['fromdate'] ?? ''}');
    final toDate = DateTime.tryParse('${properties['todate'] ?? ''}');

    return TyphoonDetails(
      name: eventName.isEmpty ? 'Typhoon' : eventName,
      classification: classification,
      alertLevel: alertLevel,
      windKph: windKph,
      country: country,
      source: source,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  TyphoonDetails _fallbackTyphoonDetails() {
    return TyphoonDetails(
      name: 'Typhoon (fallback)',
      classification: 'Tropical Cyclone',
      alertLevel: 'Unknown',
      windKph: null,
      country: 'Western Pacific',
      source: 'Fallback data',
      fromDate: null,
      toDate: null,
    );
  }

  int _parseLineClassIndex(dynamic classValue) {
    final raw = '$classValue';
    final match = RegExp(r'Line_Line_(\d+)').firstMatch(raw);
    if (match == null) return 1 << 20;
    return int.tryParse(match.group(1) ?? '') ?? (1 << 20);
  }

  void _pushUniquePoint(List<LatLng> points, LatLng candidate) {
    if (points.isEmpty) {
      points.add(candidate);
      return;
    }

    final last = points.last;
    if ((last.latitude - candidate.latitude).abs() < 0.0001 &&
        (last.longitude - candidate.longitude).abs() < 0.0001) {
      return;
    }

    points.add(candidate);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<HeatPoint> _buildFallbackTyphoonTrack() {
    _typhoonDetails ??= _fallbackTyphoonDetails();
    final now = DateTime.now();
    const track = <(double, double, double)>[
      (20.0, 139.2, 0.46),
      (19.1, 137.3, 0.58),
      (18.3, 135.4, 0.71),
      (17.5, 133.4, 0.83),
      (16.7, 131.6, 0.77),
      (16.0, 129.8, 0.66),
    ];

    return List<HeatPoint>.generate(track.length, (index) {
      final (lat, lng, intensity) = track[index];
      return HeatPoint(
        lat: lat,
        lng: lng,
        intensity: intensity,
        type: DisasterType.typhoon,
        source: 'fallback-typhoon-track',
        timestamp: now.subtract(Duration(hours: track.length - index)),
      );
    });
  }

  Future<List<HeatPoint>> _fetchBackendOrMockPoints(
    LatLng center,
    DisasterType type,
  ) async {
    final endpointType = type == DisasterType.earthquake
        ? 'earthquake'
        : type == DisasterType.landslide
        ? 'landslide'
        : 'fire';
    final uri = Uri.parse(
      '$_backendBaseUrl/api/disaster/$endpointType'
      '?lat=${center.latitude}&lng=${center.longitude}&radiusKm=8',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return _buildMockPoints(center, type);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> points =
          decoded['points'] as List<dynamic>? ?? <dynamic>[];

      if (points.isEmpty) {
        return _buildMockPoints(center, type);
      }

      return points.map((raw) {
        final item = raw as Map<String, dynamic>;
        return HeatPoint(
          lat: (item['lat'] as num).toDouble(),
          lng: (item['lng'] as num).toDouble(),
          intensity: ((item['intensity'] as num?)?.toDouble() ?? 0.45).clamp(
            0.0,
            1.0,
          ),
          type: type,
          source: (item['source'] as String?) ?? 'backend',
          timestamp:
              DateTime.tryParse((item['timestamp'] as String?) ?? '') ??
              DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return _buildMockPoints(center, type);
    }
  }

  List<HeatPoint> _buildMockPoints(LatLng center, DisasterType type) {
    final seed = switch (type) {
      DisasterType.flood => 22,
      DisasterType.typhoon => 33,
      DisasterType.earthquake => 44,
      DisasterType.landslide => 55,
    };

    final random = Random(seed);
    return List<HeatPoint>.generate(8, (_) {
      final angle = random.nextDouble() * pi * 2;
      final distance = 0.004 + random.nextDouble() * 0.02;
      return HeatPoint(
        lat: center.latitude + cos(angle) * distance,
        lng: center.longitude + sin(angle) * distance,
        intensity: (0.35 + random.nextDouble() * 0.6).clamp(0.0, 1.0),
        type: type,
        source: 'fallback-local',
        timestamp: DateTime.now(),
      );
    });
  }

  Future<void> _fetchDisasterData(LatLng center, DisasterType type) async {
    if (type == DisasterType.earthquake) {
      await _loadEarthquakeOverlay(fitViewport: false);
      return;
    }

    setState(() => _loading = true);
    try {
      final points = switch (type) {
        DisasterType.flood => await _fetchFloodPoints(center),
        DisasterType.typhoon => await _fetchTyphoonPoints(),
        DisasterType.landslide => await _fetchBackendOrMockPoints(center, type),
        DisasterType.earthquake => const <HeatPoint>[],
      };

      if (!mounted) return;
      setState(() {
        if (type != DisasterType.typhoon) {
          _typhoonDetails = null;
          _isTyphoonDetailsExpanded = false;
        }
        _heatPoints = points;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (type == DisasterType.typhoon) {
          _typhoonDetails ??= _fallbackTyphoonDetails();
        } else {
          _typhoonDetails = null;
          _isTyphoonDetailsExpanded = false;
        }
        _heatPoints = _buildMockPoints(center, type);
        _lastUpdated = DateTime.now();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _disasterColor(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return const Color(0xFF2563EB);
      case DisasterType.typhoon:
        return const Color(0xFF6D28D9);
      case DisasterType.earthquake:
        return const Color(0xFFD97706);
      case DisasterType.landslide:
        return const Color(0xFFB91C1C);
    }
  }

  IconData _disasterIcon(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return Icons.flood;
      case DisasterType.typhoon:
        return Icons.cyclone;
      case DisasterType.earthquake:
        return Icons.warning_amber_rounded;
      case DisasterType.landslide:
        return Icons.terrain;
    }
  }

  String _disasterLabel(DisasterType type) {
    switch (type) {
      case DisasterType.flood:
        return 'Flood';
      case DisasterType.typhoon:
        return 'Typhoon';
      case DisasterType.earthquake:
        return 'Earthquake';
      case DisasterType.landslide:
        return 'Landslide';
    }
  }

  List<LegendEntry> get _legendEntries {
    switch (_selectedDisaster) {
      case DisasterType.flood:
        return const [
          LegendEntry(color: Color(0xFFFACC15), label: 'Low'),
          LegendEntry(color: Color(0xFFF59E0B), label: 'Moderate'),
          LegendEntry(color: Color(0xFFEF4444), label: 'High'),
          LegendEntry(color: Color(0xFFB91C1C), label: 'Critical'),
        ];
      case DisasterType.typhoon:
        return const [
          LegendEntry(color: Color(0xFFD8B4FE), label: 'Light'),
          LegendEntry(color: Color(0xFFA78BFA), label: 'Moderate'),
          LegendEntry(color: Color(0xFF7C3AED), label: 'Strong'),
          LegendEntry(color: Color(0xFF5B21B6), label: 'Severe'),
        ];
      case DisasterType.earthquake:
        return const [
          LegendEntry(color: Color(0xFFFDE68A), label: 'M1-2.9'),
          LegendEntry(color: Color(0xFFFBBF24), label: 'M3-4.9'),
          LegendEntry(color: Color(0xFFFB7185), label: 'M5-6.9'),
          LegendEntry(color: Color(0xFFDC2626), label: 'M7+'),
        ];
      case DisasterType.landslide:
        return const [
          LegendEntry(color: Color(0xFFB91C1C), label: 'High'),
          LegendEntry(color: Color(0xFFFACC15), label: 'Medium'),
          LegendEntry(color: Color(0xFF15803D), label: 'Low'),
        ];
    }
  }

  String get _baseMapUrlTemplate {
    switch (_selectedBaseMap) {
      case 'cartoDark':
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case 'esriImagery':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'openTopo':
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      default:
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }
  }

  void _zoomBy(double delta) {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom + delta).clamp(4.5, 18.0);
    _mapController.move(_mapCenter, targetZoom);
  }

  Future<void> _openSourceLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened || !mounted) return;
  }

  Color get _mapUiAccentColor {
    switch (_selectedDisaster) {
      case DisasterType.flood:
        return const Color(0xFF2563EB);
      case DisasterType.typhoon:
        return const Color(0xFF6D28D9);
      case DisasterType.earthquake:
        return const Color(0xFFD97706);
      case DisasterType.landslide:
        return const Color(0xFFB91C1C);
    }
  }

  String get _mapUiSubtitle {
    switch (_selectedDisaster) {
      case DisasterType.flood:
        return 'Flood Hazard';
      case DisasterType.typhoon:
        return 'Typhoon Track (PAR View)';
      case DisasterType.earthquake:
        return 'Earthquake Activity';
      case DisasterType.landslide:
        return 'Landslide Susceptibility';
    }
  }

  List<MapSourceLink> get _activeSourceLinks {
    switch (_selectedDisaster) {
      case DisasterType.flood:
        return _floodSources;
      case DisasterType.typhoon:
        return _typhoonSources;
      case DisasterType.earthquake:
        return _earthquakeSources;
      case DisasterType.landslide:
        return _landslideSources;
    }
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 14.0,
        minZoom: 4.5,
        maxZoom: 18,
        onPositionChanged: (position, hasGesture) {
          final center = position.center;
          if (!hasGesture) return;
          setState(() {
            _mapCenter = center;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _baseMapUrlTemplate,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.etelly.disaster.monitoring',
        ),
        if (_selectedDisaster == DisasterType.flood) _buildFloodWmsTileLayer(),
        if (_selectedDisaster == DisasterType.landslide)
          _buildLandslideWmsTileLayer(),
        if (_selectedDisaster == DisasterType.typhoon) _buildParBoundaryLayer(),
        if (_selectedDisaster == DisasterType.earthquake &&
            _heatPoints.isNotEmpty)
          _MapHeatmapOverlayLayer(
            points: _heatPoints,
            disasterType: _selectedDisaster,
          ),
        if (_selectedDisaster == DisasterType.typhoon && _heatPoints.isNotEmpty)
          _TyphoonTrackLayer(
            points: _heatPoints,
            details: _typhoonDetails,
            isExpanded: _isTyphoonDetailsExpanded,
            onToggleExpanded: () {
              setState(() {
                _isTyphoonDetailsExpanded = !_isTyphoonDetailsExpanded;
              });
            },
          ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildParBoundaryLayer() {
    const parPoints = <LatLng>[
      LatLng(25.0, 120.0),
      LatLng(25.0, 135.0),
      LatLng(5.0, 135.0),
      LatLng(5.0, 115.0),
      LatLng(15.0, 115.0),
      LatLng(21.0, 120.0),
      LatLng(25.0, 120.0),
    ];

    return Stack(
      children: [
        PolygonLayer(
          polygons: [
            Polygon(
              points: parPoints,
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              borderColor: const Color(0xFF6D28D9).withValues(alpha: 0.55),
              borderStrokeWidth: 1.6,
            ),
          ],
        ),
        const MarkerLayer(
          markers: [
            Marker(
              point: LatLng(20.3, 124.8),
              width: 44,
              height: 22,
              child: _ParLabel(),
            ),
          ],
        ),
      ],
    );
  }

  TileLayer _buildFloodWmsTileLayer() {
    return TileLayer(
      userAgentPackageName: 'com.etelly.disaster.monitoring',
      wmsOptions: WMSTileLayerOptions(
        baseUrl: 'https://lipad-fmc.dream.upd.edu.ph/geoserver/wms?',
        layers: _floodWmsLayers,
        styles: const ['fhm_rb'],
        format: 'image/png',
        transparent: true,
        version: '1.1.1',
        otherParameters: const {'tiled': 'true'},
      ),
      maxZoom: 18,
      minZoom: 6,
    );
  }

  Widget _buildLandslideWmsTileLayer() {
    return Opacity(
      opacity: _landslideOverlayOpacity,
      child: TileLayer(
        userAgentPackageName: 'com.etelly.disaster.monitoring',
        wmsOptions: WMSTileLayerOptions(
          baseUrl: _philGeoportalWmsUrl,
          layers: _landslideWmsLayers,
          format: 'image/png',
          transparent: true,
          version: '1.1.1',
          otherParameters: const {'tiled': 'true'},
        ),
        maxZoom: 18,
        minZoom: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Antipolo City',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Text(
              'Disaster Monitoring',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              if (_selectedDisaster == DisasterType.earthquake) {
                unawaited(_loadEarthquakeOverlay(fitViewport: false));
                return;
              }

              unawaited(_fetchDisasterData(_mapCenter, _selectedDisaster));
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.black),
            onPressed: () async {
              if (_selectedDisaster == DisasterType.typhoon) {
                setState(() {
                  _mapCenter = _parFocusCenter;
                });
                _mapController.move(_mapCenter, _parFocusZoom);
                await _fetchDisasterData(_mapCenter, _selectedDisaster);
                return;
              }

              final position = await _getCurrentLocation();
              if (position == null ||
                  !_isWithinPhilippines(
                    position.latitude,
                    position.longitude,
                  )) {
                setState(() {
                  _userLocation = null;
                  _mapCenter = _defaultAntipoloCenter;
                });
                _mapController.move(_mapCenter, 14.0);
                await _fetchDisasterData(_mapCenter, _selectedDisaster);
                return;
              }

              setState(() {
                _userLocation = LatLng(position.latitude, position.longitude);
                _mapCenter = _userLocation!;
              });

              _mapController.move(_mapCenter, 14.0);
              await _fetchDisasterData(_mapCenter, _selectedDisaster);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 3.7,
                children: DisasterType.values.map((type) {
                  final color = _disasterColor(type);
                  final isSelected = _selectedDisaster == type;

                  return Material(
                    color: isSelected
                        ? color.withValues(alpha: 0.16)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        setState(() => _selectedDisaster = type);
                        if (type == DisasterType.earthquake) {
                          _mapCenter = _defaultAntipoloCenter;
                          _mapController.move(_mapCenter, 14.0);
                          await _loadEarthquakeOverlay(fitViewport: false);
                        } else if (type == DisasterType.typhoon) {
                          _mapCenter = _parFocusCenter;
                          _mapController.move(_mapCenter, _parFocusZoom);
                          await _fetchDisasterData(_mapCenter, type);
                        } else {
                          await _fetchDisasterData(_mapCenter, type);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isSelected
                                ? color.withValues(alpha: 0.95)
                                : const Color(0xFFD1D5DB),
                            width: isSelected ? 1.4 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_disasterIcon(type), size: 15, color: color),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _disasterLabel(type),
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF374151),
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Basemap:',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedBaseMap,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    items: const [
                      DropdownMenuItem(
                        value: 'cartoLight',
                        child: Text('Carto Light'),
                      ),
                      DropdownMenuItem(
                        value: 'cartoDark',
                        child: Text('Carto Dark'),
                      ),
                      DropdownMenuItem(
                        value: 'esriImagery',
                        child: Text('Esri Imagery'),
                      ),
                      DropdownMenuItem(
                        value: 'openTopo',
                        child: Text('OpenTopo'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedBaseMap = value);
                    },
                  ),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(
                      'Updated ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      _buildMap(),
                      Positioned(
                        top: _MapOverlayLayoutFrame.headerTop,
                        left: _MapOverlayLayoutFrame.leftInset,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _mapUiAccentColor.withValues(alpha: 0.45),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hazard Map',
                                style: TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _mapUiSubtitle,
                                style: TextStyle(
                                  color: _mapUiAccentColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_activeSourceLinks.isNotEmpty)
                        Positioned(
                          top: _MapOverlayLayoutFrame.headerTop + 58,
                          left: _MapOverlayLayoutFrame.leftInset,
                          child: _SourceLinksCard(
                            title: 'Sources / APIs',
                            accentColor: _mapUiAccentColor,
                            links: _activeSourceLinks,
                            onOpen: _openSourceLink,
                          ),
                        ),
                      Positioned(
                        right: _MapOverlayLayoutFrame.rightInset,
                        bottom: _MapOverlayLayoutFrame.zoomBottom,
                        child: Column(
                          children: [
                            _MapZoomButton(
                              icon: Icons.add,
                              onTap: () => _zoomBy(1),
                              accentColor: _mapUiAccentColor,
                            ),
                            const SizedBox(height: 8),
                            _MapZoomButton(
                              icon: Icons.remove,
                              onTap: () => _zoomBy(-1),
                              accentColor: _mapUiAccentColor,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedDisaster == DisasterType.earthquake &&
                          _heatPoints.isEmpty)
                        Positioned(
                          top: _MapOverlayLayoutFrame.statusTop,
                          right: _MapOverlayLayoutFrame.statusRight,
                          child: _OverlayStatusBadge(
                            text: 'No nearby earthquake events',
                            accentColor: _mapUiAccentColor,
                          ),
                        ),
                      if (_selectedDisaster == DisasterType.typhoon)
                        Positioned(
                          top: _MapOverlayLayoutFrame.statusTop,
                          right: _MapOverlayLayoutFrame.statusRight,
                          child: _OverlayStatusBadge(
                            text: 'Typhoon track shown relative to PAR',
                            accentColor: _mapUiAccentColor,
                          ),
                        ),
                      if (_selectedDisaster != DisasterType.typhoon)
                        Positioned(
                          left: _MapOverlayLayoutFrame.leftInset,
                          bottom: _MapOverlayLayoutFrame.legendBottom,
                          child: _LegendCard(
                            entries: _legendEntries,
                            title: _selectedDisaster == DisasterType.earthquake
                                ? 'Magnitude'
                                : 'Severity Level',
                            accentColor: _mapUiAccentColor,
                            vertical: true,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapOverlayLayoutFrame {
  static const double leftInset = 10;
  static const double rightInset = 12;
  static const double headerTop = 10;
  static const double zoomBottom = 12;
  static const double legendBottom = 12;
  static const double statusTop = headerTop;
  static const double statusRight = 12;

  const _MapOverlayLayoutFrame();
}

class _LegendCard extends StatelessWidget {
  final List<LegendEntry> entries;
  final String? title;
  final Color? accentColor;
  final bool vertical;
  final bool compact;

  const _LegendCard({
    required this.entries,
    this.title,
    this.accentColor,
    this.vertical = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _legendChip(entry.color, entry.label),
                  ),
                )
                .toList(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: entries
                .map((entry) => _legendChip(entry.color, entry.label))
                .toList(),
          );

    return Container(
      width: compact ? 134 : null,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: compact
            ? Border.all(
                color: (accentColor ?? const Color(0xFFE5E7EB)).withValues(
                  alpha: 0.35,
                ),
              )
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: accentColor ?? const Color(0xFF111827),
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
          ],
          content,
        ],
      ),
    );
  }

  Widget _legendChip(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
        ),
      ],
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const _MapZoomButton({
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.42)),
            ),
            child: Icon(icon, size: 22, color: accentColor),
          ),
        ),
      ),
    );
  }
}

class _OverlayStatusBadge extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _OverlayStatusBadge({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 9,
        ),
      ),
    );
  }
}

class LegendEntry {
  final Color color;
  final String label;

  const LegendEntry({required this.color, required this.label});
}

class MapSourceLink {
  final String label;
  final String href;
  final String text;

  const MapSourceLink({
    required this.label,
    required this.href,
    required this.text,
  });
}

class TyphoonDetails {
  final String name;
  final String classification;
  final String alertLevel;
  final double? windKph;
  final String country;
  final String source;
  final DateTime? fromDate;
  final DateTime? toDate;

  const TyphoonDetails({
    required this.name,
    required this.classification,
    required this.alertLevel,
    required this.windKph,
    required this.country,
    required this.source,
    required this.fromDate,
    required this.toDate,
  });
}

class _SourceLinksCard extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<MapSourceLink> links;
  final Future<void> Function(String href) onOpen;

  const _SourceLinksCard({
    required this.title,
    required this.accentColor,
    required this.links,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 184),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          ...links.map(
            (link) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: InkWell(
                onTap: () => onOpen(link.href),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${link.label}: ',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: link.text,
                        style: TextStyle(
                          fontSize: 9,
                          color: accentColor,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyphoonTrackLayer extends StatelessWidget {
  final List<HeatPoint> points;
  final TyphoonDetails? details;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const _TyphoonTrackLayer({
    required this.points,
    required this.details,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final ordered = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = ordered.last;
    final latestLatLng = LatLng(latest.lat, latest.lng);
    final headline = (details?.name ?? 'Typhoon').trim();
    final category =
        (details?.classification ?? _intensityLabel(latest.intensity)).trim();
    final alert = (details?.alertLevel ?? 'Unknown').trim();
    final windText = details?.windKph == null
        ? '-- km/h'
        : '${details!.windKph!.round()} km/h';
    final locationText =
        '${latest.lat.toStringAsFixed(1)}°N ${latest.lng.toStringAsFixed(1)}°E';
    final sourceText = details?.source ?? latest.source;
    final coverageText = details?.country.isNotEmpty == true
        ? details!.country
        : 'Western Pacific';
    final updated =
        '${latest.timestamp.hour.toString().padLeft(2, '0')}:${latest.timestamp.minute.toString().padLeft(2, '0')}';

    final markerWidth = isExpanded ? 340.0 : 320.0;
    final markerHeight = isExpanded ? 290.0 : 172.0;
    final infoCardWidth = isExpanded ? 236.0 : 220.0;
    final earliestLatLng = LatLng(ordered.first.lat, ordered.first.lng);
    final hasDistinctStart =
        (earliestLatLng.latitude - latestLatLng.latitude).abs() > 0.0001 ||
        (earliestLatLng.longitude - latestLatLng.longitude).abs() > 0.0001;
    final rangeRadiusMeters =
        (120000 + (latest.intensity.clamp(0.0, 1.0) * 180000)).toDouble();
    final rangePolylines = _buildDashedCirclePolylines(
      center: latestLatLng,
      radiusMeters: rangeRadiusMeters,
      dashCount: 38,
    );
    final trackLine = !hasDistinctStart
        ? const <Polyline>[]
        : _buildDashedTrackLine(
            earliestLatLng,
            latestLatLng,
            dashCount: 20,
            dashRatio: 0.56,
          );

    return Stack(
      children: [
        CircleLayer(
          circles: [
            CircleMarker(
              point: latestLatLng,
              radius: rangeRadiusMeters,
              useRadiusInMeter: true,
              color: const Color(0xFFB91C1C).withValues(alpha: 0.10),
              borderStrokeWidth: 0,
            ),
          ],
        ),
        PolylineLayer(polylines: [...trackLine, ...rangePolylines]),
        MarkerLayer(
          markers: [
            Marker(
              point: latestLatLng,
              width: 36,
              height: 36,
              child: const _TyphoonBullseyeMarker(),
            ),
            Marker(
              point: latestLatLng,
              width: markerWidth,
              height: markerHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(88, -24),
                    child: GestureDetector(
                      onTap: onToggleExpanded,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: infoCardWidth,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF312E81,
                          ).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFC4B5FD,
                            ).withValues(alpha: 0.9),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    headline,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (!isExpanded)
                              Row(
                                children: [
                                  Text(
                                    '$alert Alert',
                                    style: TextStyle(
                                      color: _alertColor(alert),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tap to view details',
                                    style: TextStyle(
                                      color: Color(0xFFC4B5FD),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            if (isExpanded) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _alertColor(
                                        alert,
                                      ).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _alertColor(
                                          alert,
                                        ).withValues(alpha: 0.65),
                                      ),
                                    ),
                                    child: Text(
                                      '$alert Alert',
                                      style: TextStyle(
                                        color: _alertColor(alert),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                category,
                                style: const TextStyle(
                                  color: Color(0xFFE9D5FF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _detailsRow('Wind', windText),
                              _detailsRow('Position', locationText),
                              _detailsRow('Coverage', coverageText),
                              _detailsRow('Status', _parStatus(latestLatLng)),
                              const SizedBox(height: 4),
                              Text(
                                'Updated $updated • $sourceText',
                                style: const TextStyle(
                                  color: Color(0xFFC4B5FD),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Polyline> _buildDashedTrackLine(
    LatLng start,
    LatLng end, {
    required int dashCount,
    required double dashRatio,
  }) {
    final polylines = <Polyline>[];
    final ratio = dashRatio.clamp(0.1, 0.9);

    for (var i = 0; i < dashCount; i++) {
      final segStart = i / dashCount;
      final segEnd = segStart + ((1 / dashCount) * ratio);

      polylines.add(
        Polyline(
          points: [
            _lerpTrackPoint(start, end, segStart),
            _lerpTrackPoint(start, end, segEnd),
          ],
          strokeWidth: 1.9,
          color: const Color(0xFFB91C1C).withValues(alpha: 0.86),
        ),
      );
    }

    return polylines;
  }

  LatLng _lerpTrackPoint(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + ((end.latitude - start.latitude) * t),
      start.longitude + ((end.longitude - start.longitude) * t),
    );
  }

  List<Polyline> _buildDashedCirclePolylines({
    required LatLng center,
    required double radiusMeters,
    required int dashCount,
  }) {
    final segmentSweep = (2 * pi) / dashCount;
    const dashRatio = 0.64;
    final polylines = <Polyline>[];

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * segmentSweep;
      final endAngle = startAngle + (segmentSweep * dashRatio);
      final startBearing = (startAngle * 180 / pi) % 360;
      final endBearing = (endAngle * 180 / pi) % 360;
      polylines.add(
        Polyline(
          points: [
            _offsetLatLng(center, startBearing, radiusMeters),
            _offsetLatLng(center, endBearing, radiusMeters),
          ],
          strokeWidth: 2.2,
          color: const Color(0xFF991B1B).withValues(alpha: 0.9),
        ),
      );
    }

    return polylines;
  }

  LatLng _offsetLatLng(LatLng start, double bearingDegrees, double distanceM) {
    const earthRadiusM = 6371000.0;
    final bearing = bearingDegrees * pi / 180;
    final distanceRatio = distanceM / earthRadiusM;

    final startLat = start.latitude * pi / 180;
    final startLon = start.longitude * pi / 180;

    final endLat = asin(
      (sin(startLat) * cos(distanceRatio)) +
          (cos(startLat) * sin(distanceRatio) * cos(bearing)),
    );

    final endLon =
        startLon +
        atan2(
          sin(bearing) * sin(distanceRatio) * cos(startLat),
          cos(distanceRatio) - (sin(startLat) * sin(endLat)),
        );

    return LatLng(endLat * 180 / pi, endLon * 180 / pi);
  }

  Widget _detailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC4B5FD),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE9D5FF),
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TyphoonBullseyeMarker extends StatelessWidget {
  const _TyphoonBullseyeMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFEE2E2).withValues(alpha: 0.92),
          border: Border.all(color: const Color(0xFFB91C1C), width: 2.2),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDC2626),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _alertColor(String alert) {
  switch (alert.toLowerCase()) {
    case 'red':
      return const Color(0xFFEF4444);
    case 'orange':
      return const Color(0xFFF97316);
    case 'yellow':
      return const Color(0xFFF59E0B);
    case 'green':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFFA78BFA);
  }
}

String _intensityLabel(double intensity) {
  if (intensity >= 0.78) return 'Severe intensity';
  if (intensity >= 0.58) return 'Strong intensity';
  if (intensity >= 0.38) return 'Moderate intensity';
  return 'Light intensity';
}

String _parStatus(LatLng point) {
  final inLat = point.latitude >= 5 && point.latitude <= 25;
  final inLon = point.longitude >= 115 && point.longitude <= 135;
  final westBoundary = point.latitude > 21 ? 120.0 : 115.0;
  final insideCore = inLat && inLon && point.longitude >= westBoundary;

  if (insideCore) return 'Inside PAR';
  if (inLat && point.longitude > 135 && point.longitude <= 140) {
    return 'Entering PAR';
  }

  return 'Outside PAR';
}

class _ParLabel extends StatelessWidget {
  const _ParLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6D28D9).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'PAR',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapHeatmapOverlayLayer extends StatelessWidget {
  final List<HeatPoint> points;
  final DisasterType disasterType;

  const _MapHeatmapOverlayLayer({
    required this.points,
    required this.disasterType,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);
    if (camera == null || points.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _HeatmapPainter(
              points: points,
              camera: camera,
              disasterType: disasterType,
            ),
          ),
        ),
      ),
    );
  }
}

class _LandslideHazardOverlayLayer extends StatelessWidget {
  final List<HeatPoint> points;

  const _LandslideHazardOverlayLayer({required this.points});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.maybeOf(context);
    if (camera == null || points.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LandslideHazardPainter(points: points, camera: camera),
          ),
        ),
      ),
    );
  }
}

class _LandslideHazardPainter extends CustomPainter {
  final List<HeatPoint> points;
  final MapCamera camera;

  const _LandslideHazardPainter({required this.points, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final projected = <MapEntry<Offset, double>>[];
    for (final point in points) {
      projected.add(
        MapEntry(
          camera.latLngToScreenOffset(LatLng(point.lat, point.lng)),
          point.intensity.clamp(0.0, 1.0),
        ),
      );
    }

    final zoomFactor = (camera.zoom - 10).clamp(0.0, 5.0);
    final cellSize = (28.0 - (zoomFactor * 1.8)).clamp(18.0, 28.0);
    final influenceSigma = (94.0 - (zoomFactor * 6.0)).clamp(58.0, 94.0);
    final sigmaDenominator = 2 * influenceSigma * influenceSigma;

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final center = Offset(x + (cellSize / 2), y + (cellSize / 2));

        double risk = 0;
        for (final entry in projected) {
          final dx = entry.key.dx - center.dx;
          final dy = entry.key.dy - center.dy;
          final distSquared = (dx * dx) + (dy * dy);
          final weight = exp(-(distSquared / sigmaDenominator));
          risk = max(risk, entry.value * weight);
        }

        if (risk < 0.12) continue;

        final fillColor = _classColor(
          risk,
        ).withValues(alpha: _classAlpha(risk));
        final cellRect = Rect.fromLTWH(x, y, cellSize, cellSize);
        final cellRRect = RRect.fromRectAndRadius(
          cellRect,
          const Radius.circular(4),
        );

        final fillPaint = Paint()
          ..color = fillColor
          ..blendMode = BlendMode.srcOver;
        canvas.drawRRect(cellRRect, fillPaint);

        if (risk >= 0.56) {
          final edgePaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = const Color(0xFF78350F).withValues(alpha: 0.32);
          canvas.drawRRect(cellRRect, edgePaint);
        }
      }
    }
  }

  Color _classColor(double risk) {
    if (risk >= 0.62) return const Color(0xFFB91C1C);
    if (risk >= 0.36) return const Color(0xFFF97316);
    return const Color(0xFF15803D);
  }

  double _classAlpha(double risk) {
    if (risk >= 0.62) return 0.30;
    if (risk >= 0.36) return 0.24;
    return 0.18;
  }

  @override
  bool shouldRepaint(covariant _LandslideHazardPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.rotation != camera.rotation;
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatPoint> points;
  final MapCamera camera;
  final DisasterType disasterType;

  const _HeatmapPainter({
    required this.points,
    required this.camera,
    required this.disasterType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    if (disasterType == DisasterType.earthquake) {
      _paintEarthquakeHotspots(canvas);
      return;
    }

    for (final point in points) {
      final offset = camera.latLngToScreenOffset(LatLng(point.lat, point.lng));
      final intensity = point.intensity.clamp(0.0, 1.0);
      if (intensity < 0.08) continue;

      final isFlood = disasterType == DisasterType.flood;
      final radius = isFlood
          ? 16.0 + (intensity * 18.0)
          : 28.0 + (intensity * 36.0);
      final blurSigma = isFlood
          ? 3.0 + (intensity * 4.0)
          : 8.0 + (intensity * 8.0);

      final outerPaint = Paint()
        ..color = _heatColorFor(intensity).withValues(
          alpha: isFlood
              ? 0.06 + (intensity * 0.08)
              : 0.12 + (intensity * 0.18),
        )
        ..blendMode = BlendMode.srcOver
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

      canvas.drawCircle(offset, radius * 1.05, outerPaint);

      final coreGradient = RadialGradient(
        colors: [
          _heatColorFor(intensity).withValues(
            alpha: isFlood
                ? 0.20 + (intensity * 0.16)
                : 0.36 + (intensity * 0.34),
          ),
          _heatColorFor(intensity).withValues(
            alpha: isFlood
                ? 0.09 + (intensity * 0.12)
                : 0.18 + (intensity * 0.22),
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      final corePaint = Paint()
        ..shader = coreGradient.createShader(
          Rect.fromCircle(center: offset, radius: radius),
        )
        ..blendMode = BlendMode.srcOver;

      canvas.drawCircle(offset, radius, corePaint);
    }
  }

  void _paintEarthquakeHotspots(Canvas canvas) {
    for (final point in points) {
      final offset = camera.latLngToScreenOffset(LatLng(point.lat, point.lng));
      final intensity = point.intensity.clamp(0.0, 1.0);
      if (intensity < 0.08) continue;

      final color = _heatColorFor(intensity);
      final radius = 12.0 + (intensity * 20.0);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.14 + (intensity * 0.10))
        ..maskFilter =
            ui.MaskFilter.blur(ui.BlurStyle.normal, 9 + (intensity * 5));
      canvas.drawCircle(offset, radius * 1.28, glowPaint);

      final bodyPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.72),
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: offset, radius: radius));
      canvas.drawCircle(offset, radius, bodyPaint);

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..color = Colors.white.withValues(alpha: 0.50);
      canvas.drawCircle(offset, radius * 0.56, ringPaint);

      final corePaint = Paint()..color = color.withValues(alpha: 0.95);
      canvas.drawCircle(offset, 3.0 + (intensity * 2.2), corePaint);
    }
  }

  Color _heatColorFor(double intensity) {
    switch (disasterType) {
      case DisasterType.flood:
        if (intensity < 0.45) return const Color(0xFFFACC15);
        if (intensity < 0.72) return const Color(0xFFF59E0B);
        return const Color(0xFFEF4444);
      case DisasterType.landslide:
        return Color.lerp(
              const Color(0xFFFDE68A),
              const Color(0xFF78350F),
              intensity,
            ) ??
            const Color(0xFF78350F);
      case DisasterType.typhoon:
        return Color.lerp(
              const Color(0xFFD8B4FE),
              const Color(0xFF7C3AED),
              intensity,
            ) ??
            const Color(0xFF7C3AED);
      case DisasterType.earthquake:
        if (intensity < 0.38) return const Color(0xFFFDE68A);
        if (intensity < 0.58) return const Color(0xFFFBBF24);
        if (intensity < 0.78) return const Color(0xFFFB7185);
        return const Color(0xFFDC2626);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.camera.rotation != camera.rotation ||
        oldDelegate.disasterType != disasterType;
  }
}
