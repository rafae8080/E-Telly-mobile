import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

// Shared color palette for the Navotas disaster map screen.
const Color floodColor = Color(0xFF3B82F6);
const Color earthquakeColor = Color(0xFFF59E0B);
const Color typhoonColor = Color(0xFF8B5CF6);
const Color landslideColor = Color(0xFF10B981);
const Color fireColor = Color(0xFFDC2626);

const Color safeColor = Color(0xFF10B981);
const Color lowColor = Color(0xFF34D399);
const Color moderateColor = Color(0xFFFBBF24);
const Color warningColor = Color(0xFFF59E0B);
const Color highColor = Color(0xFFF97316);
const Color dangerColor = Color(0xFFDC2626);
const Color criticalColor = Color(0xFF7F1D1D);

const Color mainCenterColor = Color(0xFFDC2626);
const Color secondaryCenterColor = Color(0xFFF59E0B);
const Color medicalCenterColor = Color(0xFF3B82F6);

class DisasterMonitoringScreen extends StatefulWidget {
  const DisasterMonitoringScreen({super.key});

  @override
  State<DisasterMonitoringScreen> createState() => _DisasterMonitoringScreenState();
}

// Data Models
class HazardZone {
  final String id;
  final String name;
  final String hazardType;
  final String severity;
  final double intensity;
  final int affectedPopulation;
  final double posX;
  final double posY;
  final double radius;

  HazardZone({
    required this.id,
    required this.name,
    required this.hazardType,
    required this.severity,
    required this.intensity,
    required this.affectedPopulation,
    required this.posX,
    required this.posY,
    required this.radius,
  });
}

class MonitoringStation {
  final String id;
  final String name;
  final String location;
  final String hazardType;
  final double currentReading;
  final double threshold;
  final String status;
  final String trend;
  final String lastUpdated;
  final double posX;
  final double posY;
  final String areaName;

  MonitoringStation({
    required this.id,
    required this.name,
    required this.location,
    required this.hazardType,
    required this.currentReading,
    required this.threshold,
    required this.status,
    required this.trend,
    required this.lastUpdated,
    required this.posX,
    required this.posY,
    required this.areaName,
  });
}

class EvacuationCenter {
  final String id;
  final String name;
  final String type;
  final int capacity;
  final int currentOccupants;
  final double posX;
  final double posY;
  final String contact;
  final String address;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.currentOccupants,
    required this.posX,
    required this.posY,
    required this.contact,
    required this.address,
  });
}

class _DisasterMonitoringScreenState extends State<DisasterMonitoringScreen> {
  String _activeTab = 'hazard';
  String _selectedHazard = 'all';
  bool _loading = false;
  double _mapScale = 1.0;
  Offset _mapOffset = Offset(0, 0);
  bool _isDragging = false;
  Offset _lastOffset = Offset.zero;

  // Navotas Hazard Zones (Based on actual barangays)
  final List<HazardZone> _hazardZones = [
    HazardZone(
      id: '1',
      name: 'Barangay Tanza',
      hazardType: 'flood',
      severity: 'critical',
      intensity: 2.3,
      affectedPopulation: 8250,
      posX: 120,
      posY: 150,
      radius: 85,
    ),
    HazardZone(
      id: '2',
      name: 'Barangay Daanghari',
      hazardType: 'flood',
      severity: 'danger',
      intensity: 1.8,
      affectedPopulation: 5200,
      posX: 220,
      posY: 260,
      radius: 75,
    ),
    HazardZone(
      id: '3',
      name: 'Barangay Bangkulasi',
      hazardType: 'typhoon',
      severity: 'critical',
      intensity: 185,
      affectedPopulation: 4300,
      posX: 310,
      posY: 110,
      radius: 80,
    ),
    HazardZone(
      id: '4',
      name: 'Barangay San Roque',
      hazardType: 'flood',
      severity: 'moderate',
      intensity: 0.8,
      affectedPopulation: 3800,
      posX: 160,
      posY: 360,
      radius: 65,
    ),
    HazardZone(
      id: '5',
      name: 'Barangay Tangos',
      hazardType: 'flood',
      severity: 'warning',
      intensity: 1.2,
      affectedPopulation: 6200,
      posX: 280,
      posY: 410,
      radius: 70,
    ),
    HazardZone(
      id: '6',
      name: 'Barangay Navotas East',
      hazardType: 'earthquake',
      severity: 'moderate',
      intensity: 4.2,
      affectedPopulation: 3100,
      posX: 380,
      posY: 320,
      radius: 60,
    ),
    HazardZone(
      id: '7',
      name: 'Barangay Sipac-Almacen',
      hazardType: 'fire',
      severity: 'high',
      intensity: 75,
      affectedPopulation: 2800,
      posX: 420,
      posY: 180,
      radius: 55,
    ),
  ];

  // Monitoring Stations in Navotas
  List<MonitoringStation> _stations = [
    MonitoringStation(
      id: '1',
      name: 'Tanza River Gauge',
      location: 'Tanza, Navotas City',
      hazardType: 'flood',
      currentReading: 2.3,
      threshold: 3.0,
      status: 'critical',
      trend: 'rising',
      lastUpdated: '5 min ago',
      posX: 130,
      posY: 170,
      areaName: 'Tanza',
    ),
    MonitoringStation(
      id: '2',
      name: 'Daanghari Water Level',
      location: 'Daanghari, Navotas',
      hazardType: 'flood',
      currentReading: 1.8,
      threshold: 2.5,
      status: 'danger',
      trend: 'rising',
      lastUpdated: '8 min ago',
      posX: 230,
      posY: 280,
      areaName: 'Daanghari',
    ),
    MonitoringStation(
      id: '3',
      name: 'Bangkulasi Weather Station',
      location: 'Bangkulasi Coastal',
      hazardType: 'typhoon',
      currentReading: 165,
      threshold: 200,
      status: 'warning',
      trend: 'rising',
      lastUpdated: '10 min ago',
      posX: 330,
      posY: 130,
      areaName: 'Bangkulasi',
    ),
    MonitoringStation(
      id: '4',
      name: 'San Roque Flood Sensor',
      location: 'San Roque, Navotas',
      hazardType: 'flood',
      currentReading: 0.8,
      threshold: 1.5,
      status: 'moderate',
      trend: 'stable',
      lastUpdated: '12 min ago',
      posX: 180,
      posY: 380,
      areaName: 'San Roque',
    ),
    MonitoringStation(
      id: '5',
      name: 'Tangos Monitoring Station',
      location: 'Tangos, Navotas',
      hazardType: 'flood',
      currentReading: 1.2,
      threshold: 2.0,
      status: 'warning',
      trend: 'rising',
      lastUpdated: '7 min ago',
      posX: 290,
      posY: 430,
      areaName: 'Tangos',
    ),
    MonitoringStation(
      id: '6',
      name: 'Navotas Seismic Station',
      location: 'Navotas East',
      hazardType: 'earthquake',
      currentReading: 2.1,
      threshold: 5.0,
      status: 'low',
      trend: 'stable',
      lastUpdated: '15 min ago',
      posX: 390,
      posY: 340,
      areaName: 'Navotas East',
    ),
  ];

  // Evacuation Centers in Navotas
  final List<EvacuationCenter> _evacuationCenters = [
    EvacuationCenter(
      id: 'ec1',
      name: 'Navotas City Hall',
      type: 'main',
      capacity: 800,
      currentOccupants: 420,
      posX: 410,
      posY: 210,
      contact: '828-31-111',
      address: 'M. Naval St., Navotas City',
    ),
    EvacuationCenter(
      id: 'ec2',
      name: 'Tanza Elementary School',
      type: 'main',
      capacity: 500,
      currentOccupants: 310,
      posX: 140,
      posY: 190,
      contact: '828-32-222',
      address: 'Tanza, Navotas City',
    ),
    EvacuationCenter(
      id: 'ec3',
      name: 'Navotas National High School',
      type: 'secondary',
      capacity: 600,
      currentOccupants: 280,
      posX: 360,
      posY: 300,
      contact: '828-33-333',
      address: 'M. Naval St., Navotas',
    ),
    EvacuationCenter(
      id: 'ec4',
      name: 'Daanghari Health Center',
      type: 'medical',
      capacity: 150,
      currentOccupants: 78,
      posX: 250,
      posY: 230,
      contact: '828-34-444',
      address: 'Daanghari, Navotas City',
    ),
    EvacuationCenter(
      id: 'ec5',
      name: 'Bangkulasi Covered Court',
      type: 'secondary',
      capacity: 300,
      currentOccupants: 145,
      posX: 340,
      posY: 70,
      contact: '828-35-555',
      address: 'Bangkulasi, Navotas City',
    ),
    EvacuationCenter(
      id: 'ec6',
      name: 'San Roque Parish Church',
      type: 'secondary',
      capacity: 250,
      currentOccupants: 98,
      posX: 170,
      posY: 400,
      contact: '828-36-666',
      address: 'San Roque, Navotas City',
    ),
    EvacuationCenter(
      id: 'ec7',
      name: 'Navotas General Hospital',
      type: 'medical',
      capacity: 200,
      currentOccupants: 112,
      posX: 440,
      posY: 250,
      contact: '828-37-777',
      address: 'North Bay Blvd., Navotas',
    ),
  ];

  Color _getHazardColor(String hazardType) {
    switch (hazardType) {
      case 'flood': return floodColor;
      case 'earthquake': return earthquakeColor;
      case 'typhoon': return typhoonColor;
      case 'landslide': return landslideColor;
      case 'fire': return fireColor;
      default: return Colors.grey;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'low': return lowColor;
      case 'moderate': return moderateColor;
      case 'warning': return warningColor;
      case 'high': return highColor;
      case 'danger': return dangerColor;
      case 'critical': return criticalColor;
      default: return safeColor;
    }
  }

  String _getSeverityText(String severity) {
    switch (severity) {
      case 'low': return 'LOW RISK';
      case 'moderate': return 'MODERATE';
      case 'warning': return 'WARNING';
      case 'high': return 'HIGH RISK';
      case 'danger': return 'DANGER';
      case 'critical': return 'CRITICAL';
      default: return 'SAFE';
    }
  }

  IconData _getHazardIcon(String hazardType) {
    switch (hazardType) {
      case 'flood': return Icons.water_drop;
      case 'earthquake': return Icons.terrain;
      case 'typhoon': return Icons.air;
      case 'landslide': return Icons.landslide;
      case 'fire': return Icons.local_fire_department;
      default: return Icons.warning;
    }
  }

  List<HazardZone> get _filteredZones {
    if (_selectedHazard == 'all') return _hazardZones;
    return _hazardZones.where((z) => z.hazardType == _selectedHazard).toList();
  }

  List<MonitoringStation> get _filteredStations {
    if (_selectedHazard == 'all') return _stations;
    return _stations.where((s) => s.hazardType == _selectedHazard).toList();
  }

  int get _totalAffectedPopulation {
    return _hazardZones.fold(0, (sum, zone) => sum + zone.affectedPopulation);
  }

  int get _criticalZonesCount {
    return _hazardZones.where((z) => z.severity == 'critical' || z.severity == 'danger').length;
  }

  void _showHazardDetails(HazardZone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getHazardIcon(zone.hazardType), color: _getHazardColor(zone.hazardType)),
            SizedBox(width: 8),
            Expanded(child: Text(zone.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('⚠️ Hazard Type', zone.hazardType.toUpperCase()),
            _buildInfoRow('📊 Severity', _getSeverityText(zone.severity)),
            _buildInfoRow('📈 Intensity', zone.hazardType == 'earthquake' ? '${zone.intensity} Magnitude' : 
                          zone.hazardType == 'typhoon' ? '${zone.intensity} km/h' : 
                          '${zone.intensity}m'),
            _buildInfoRow('👥 Affected', '${zone.affectedPopulation} people'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getSeverityColor(zone.severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getSeverityColor(zone.severity)),
              ),
              child: Text(
                zone.severity == 'critical' 
                    ? '🚨 IMMEDIATE EVACUATION ORDER\nHigh risk area - Leave immediately'
                    : zone.severity == 'danger'
                    ? '⚠️ PREPARE FOR EVACUATION\nMonitor official announcements'
                    : zone.severity == 'warning'
                    ? '📢 BE ALERT\nStay updated on weather conditions'
                    : 'ℹ️ MONITOR SITUATION\nNo immediate action needed',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final url = 'https://www.google.com/maps/search/?api=1&query=Navotas+${zone.name.replaceAll(' ', '+')}';
              if (await canLaunch(url)) await launch(url);
            },
            icon: Icon(Icons.directions),
            label: Text('Navigate'),
            style: ElevatedButton.styleFrom(backgroundColor: _getSeverityColor(zone.severity)),
          ),
        ],
      ),
    );
  }

  void _showStationDetails(MonitoringStation station) {
    double percentage = (station.currentReading / station.threshold) * 100;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(station.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('📍 Location', station.location),
            _buildInfoRow('📊 Reading', '${station.currentReading.toStringAsFixed(1)} / ${station.threshold}'),
            _buildInfoRow('📈 Trend', station.trend.toUpperCase()),
            _buildInfoRow('⏰ Updated', station.lastUpdated),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(_getSeverityColor(station.status)),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text('${percentage.toStringAsFixed(0)}% of threshold'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  void _showCenterDetails(EvacuationCenter center) {
    double occupancy = (center.currentOccupants / center.capacity) * 100;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('🏢 Type', center.type.toUpperCase()),
            _buildInfoRow('📍 Address', center.address),
            _buildInfoRow('👥 Capacity', '${center.capacity} people'),
            _buildInfoRow('📊 Current', '${center.currentOccupants} people'),
            _buildInfoRow('📞 Contact', center.contact),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: occupancy / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                occupancy > 90 ? criticalColor : occupancy > 70 ? warningColor : safeColor,
              ),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text('${occupancy.toStringAsFixed(0)}% occupied'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final url = 'https://www.google.com/maps/search/?api=1&query=${center.name.replaceAll(' ', '+')}+Navotas';
              if (await canLaunch(url)) await launch(url);
            },
            icon: Icon(Icons.directions),
            label: Text('Navigate'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleRefresh() {
    setState(() => _loading = true);
    Future.delayed(Duration(seconds: 1), () {
      final random = Random();
      setState(() {
        _stations = _stations.map((station) {
          double change = (random.nextDouble() - 0.5) * 0.2;
          double newReading = (station.currentReading + change).clamp(0.0, station.threshold * 1.1);
          double percentage = (newReading / station.threshold) * 100;
          String status = percentage < 30 ? 'low' : percentage < 50 ? 'moderate' : 
                          percentage < 70 ? 'warning' : percentage < 85 ? 'high' : 
                          percentage < 95 ? 'danger' : 'critical';
          
          return MonitoringStation(
            id: station.id, name: station.name, location: station.location,
            hazardType: station.hazardType, currentReading: newReading,
            threshold: station.threshold, status: status,
            trend: change > 0 ? 'rising' : change < 0 ? 'falling' : 'stable',
            lastUpdated: 'Just now', posX: station.posX, posY: station.posY,
            areaName: station.areaName,
          );
        }).toList();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Navotas disaster data updated!'),
        backgroundColor: safeColor,
        duration: Duration(seconds: 2),
      ));
    });
  }

  Widget _buildHazardMap() {
    return Column(
      children: [
        // Hazard Filter Chips
        Container(
          height: 45,
          margin: EdgeInsets.only(bottom: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('All Hazards', 'all', Colors.grey),
              SizedBox(width: 8),
              _buildFilterChip('🌊 Flood', 'flood', floodColor),
              SizedBox(width: 8),
              _buildFilterChip('🌍 Quake', 'earthquake', earthquakeColor),
              SizedBox(width: 8),
              _buildFilterChip('🌀 Typhoon', 'typhoon', typhoonColor),
              SizedBox(width: 8),
              _buildFilterChip('🔥 Fire', 'fire', fireColor),
            ],
          ),
        ),
        
        Expanded(
          child: GestureDetector(
            onScaleStart: (details) {
              _isDragging = true;
              _lastOffset = details.focalPoint;
            },
            onScaleUpdate: (details) {
              if (_isDragging) {
                setState(() {
                  _mapOffset += details.focalPoint - _lastOffset;
                  _lastOffset = details.focalPoint;
                });
              }
            },
            onScaleEnd: (details) => _isDragging = false,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE5E7EB)),
                image: DecorationImage(
                  image: NetworkImage('https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/Ph_locator_ncr_navotas.svg/1200px-Ph_locator_ncr_navotas.svg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.15,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Base grid
                    CustomPaint(painter: NavotasGridPainter()),
                    
                    // Navotas Title Overlay
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('NAVOTAS CITY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    // Hazard Zones
                    for (final zone in _filteredZones)
                      Positioned(
                        left: zone.posX + _mapOffset.dx - zone.radius,
                        top: zone.posY + _mapOffset.dy - zone.radius,
                        child: Transform.scale(
                          scale: _mapScale,
                          child: GestureDetector(
                            onTap: () => _showHazardDetails(zone),
                            child: Stack(
                              children: [
                                // Glow effect for critical zones
                                if (zone.severity == 'critical' || zone.severity == 'danger')
                                  Container(
                                    width: zone.radius * 2,
                                    height: zone.radius * 2,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getSeverityColor(zone.severity).withOpacity(0.6),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  width: zone.radius * 2,
                                  height: zone.radius * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getSeverityColor(zone.severity).withOpacity(0.3),
                                    border: Border.all(
                                      color: _getSeverityColor(zone.severity),
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getHazardIcon(zone.hazardType), 
                                             color: _getSeverityColor(zone.severity), size: 24),
                                        Container(
                                          margin: EdgeInsets.only(top: 4),
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            zone.name.replaceAll('Barangay ', ''),
                                            style: TextStyle(fontSize: 9, color: Colors.white),
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
                      ),

                    // Monitoring Stations
                    for (final station in _filteredStations)
                      Positioned(
                        left: station.posX + _mapOffset.dx,
                        top: station.posY + _mapOffset.dy,
                        child: GestureDetector(
                          onTap: () => _showStationDetails(station),
                          child: Transform.scale(
                            scale: _mapScale,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getSeverityColor(station.status),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Center(
                                child: Icon(_getHazardIcon(station.hazardType), size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Map Controls
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        children: [
                          MapControlButton(icon: Icons.add, onPressed: () => setState(() => _mapScale = (_mapScale * 1.2).clamp(0.5, 3.0))),
                          SizedBox(height: 8),
                          MapControlButton(icon: Icons.remove, onPressed: () => setState(() => _mapScale = (_mapScale / 1.2).clamp(0.5, 3.0))),
                          SizedBox(height: 8),
                          MapControlButton(icon: Icons.center_focus_strong, onPressed: () => setState(() { _mapOffset = Offset.zero; _mapScale = 1.0; })),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        NavotasColorLegend(),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: _selectedHazard == value,
      onSelected: (_) => setState(() => _selectedHazard = value),
      backgroundColor: Colors.grey[100],
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }

  Widget _buildEvacMapView() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onScaleStart: (details) {
              _isDragging = true;
              _lastOffset = details.focalPoint;
            },
            onScaleUpdate: (details) {
              if (_isDragging) setState(() { _mapOffset += details.focalPoint - _lastOffset; _lastOffset = details.focalPoint; });
            },
            onScaleEnd: (details) => _isDragging = false,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE5E7EB)),
                color: Color(0xFFFEF3C7),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CustomPaint(painter: NavotasGridPainter(color: Colors.orange[100]!)),
                    
                    // Main Roads in Navotas
                    Positioned(left: 50, top: 200, child: RoadWidget(width: 350, height: 6, label: 'M. Naval St')),
                    Positioned(left: 200, top: 100, child: RoadWidget(width: 6, height: 250, isVertical: true)),
                    Positioned(left: 350, top: 150, child: RoadWidget(width: 6, height: 200, isVertical: true)),
                    Positioned(left: 100, top: 350, child: RoadWidget(width: 250, height: 6, label: 'North Bay Blvd')),

                    // Evacuation Centers
                    for (final center in _evacuationCenters)
                      Positioned(
                        left: center.posX + _mapOffset.dx,
                        top: center.posY + _mapOffset.dy,
                        child: GestureDetector(
                          onTap: () => _showCenterDetails(center),
                          child: Transform.scale(
                            scale: _mapScale,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: center.type == 'main' ? mainCenterColor : 
                                       center.type == 'medical' ? medicalCenterColor : secondaryCenterColor,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                              ),
                              child: Center(
                                child: Icon(center.type == 'medical' ? Icons.medical_services : 
                                           center.type == 'main' ? Icons.account_balance : Icons.church,
                                           size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // High Risk Areas Overlay
                    for (final zone in _hazardZones.where((z) => z.severity == 'critical' || z.severity == 'danger'))
                      Positioned(
                        left: zone.posX + _mapOffset.dx - zone.radius,
                        top: zone.posY + _mapOffset.dy - zone.radius,
                        child: Transform.scale(
                          scale: _mapScale,
                          child: Container(
                            width: zone.radius * 2,
                            height: zone.radius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getSeverityColor(zone.severity).withOpacity(0.25),
                              border: Border.all(color: _getSeverityColor(zone.severity), width: 2, style: BorderStyle.solid),
                            ),
                            child: Center(
                              child: Icon(Icons.warning_amber_rounded, color: _getSeverityColor(zone.severity), size: 28),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 16, right: 16,
                      child: Column(
                        children: [
                          MapControlButton(icon: Icons.add, onPressed: () => setState(() => _mapScale = (_mapScale * 1.2).clamp(0.5, 3.0))),
                          SizedBox(height: 8),
                          MapControlButton(icon: Icons.remove, onPressed: () => setState(() => _mapScale = (_mapScale / 1.2).clamp(0.5, 3.0))),
                          SizedBox(height: 8),
                          MapControlButton(icon: Icons.center_focus_strong, onPressed: () => setState(() { _mapOffset = Offset.zero; _mapScale = 1.0; })),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        EvacLegend(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: criticalColor, size: 24),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Navotas City', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text('Disaster Monitoring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.refresh, color: Colors.black),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: SafeArea(
          child: Column(
            children: [
              // Summary Cards
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        icon: Icons.warning,
                        count: _criticalZonesCount,
                        label: 'Critical Zones',
                        color: criticalColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SummaryCard(
                        icon: Icons.people,
                        count: _totalAffectedPopulation,
                        label: 'Affected',
                        color: dangerColor,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SummaryCard(
                        icon: Icons.exit_to_app,
                        count: _evacuationCenters.length,
                        label: 'Evac Centers',
                        color: mainCenterColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab Selector
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TabButton(
                        icon: Icons.map,
                        label: 'Hazard Map',
                        isActive: _activeTab == 'hazard',
                        onTap: () => setState(() => _activeTab = 'hazard'),
                        dangerColor: criticalColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TabButton(
                        icon: Icons.exit_to_app,
                        label: 'Evacuation',
                        isActive: _activeTab == 'evac',
                        onTap: () => setState(() => _activeTab = 'evac'),
                        dangerColor: criticalColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _activeTab == 'hazard' ? _buildHazardMap() : _buildEvacMapView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Widgets
class NavotasColorLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📍 NAVOTAS HAZARD MAP LEGEND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(safeColor, 'Safe'),
              _legendItem(warningColor, 'Warning'),
              _legendItem(dangerColor, 'Danger'),
              _legendItem(criticalColor, 'Critical'),
            ],
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hazardItem(floodColor, 'Flood', Icons.water_drop),
              SizedBox(width: 16),
              _hazardItem(earthquakeColor, 'Quake', Icons.terrain),
              SizedBox(width: 16),
              _hazardItem(typhoonColor, 'Typhoon', Icons.air),
              SizedBox(width: 16),
              _hazardItem(fireColor, 'Fire', Icons.local_fire_department),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 10)),
  ]);
  
  Widget _hazardItem(Color color, String label, IconData icon) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color),
    SizedBox(width: 2), Text(label, style: TextStyle(fontSize: 9)),
  ]);
}

class EvacLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(mainCenterColor, 'Main Center', Icons.account_balance),
          _legendItem(secondaryCenterColor, 'Secondary', Icons.church),
          _legendItem(medicalCenterColor, 'Medical', Icons.medical_services),
          _legendItem(dangerColor, 'High Risk', Icons.warning),
        ],
      ),
    );
  }
  
  Widget _legendItem(Color color, String label, IconData icon) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    SizedBox(width: 4), Icon(icon, size: 10, color: color),
    SizedBox(width: 2), Text(label, style: TextStyle(fontSize: 9)),
  ]);
}

class MapControlButton extends StatelessWidget {
  final IconData icon; final VoidCallback onPressed;
  const MapControlButton({required this.icon, required this.onPressed});
  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
      child: IconButton(icon: Icon(icon, size: 20), onPressed: onPressed, constraints: BoxConstraints.tight(Size(38, 38)), padding: EdgeInsets.zero),
    );
  }
}

class NavotasGridPainter extends CustomPainter {
  final Color? color;
  NavotasGridPainter({this.color});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color ?? Colors.grey.withOpacity(0.15)..strokeWidth = 0.5;
    for (int i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoadWidget extends StatelessWidget {
  final double width, height; final String? label; final bool isVertical;
  const RoadWidget({required this.width, required this.height, this.label, this.isVertical = false});
  @override Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(color: Colors.grey[400], border: Border.all(color: Colors.white, width: 1)),
      child: label != null ? Center(child: Text(label!, style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))) : null,
    );
  }
}

class TabButton extends StatelessWidget {
  final IconData icon; final String label; final bool isActive; final VoidCallback onTap; final Color dangerColor;
  const TabButton({required this.icon, required this.label, required this.isActive, required this.onTap, required this.dangerColor});
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? dangerColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? dangerColor : Colors.grey[300]!),
        ),
        child: Column(children: [
          Icon(icon, color: isActive ? dangerColor : Colors.grey[600], size: 20),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isActive ? dangerColor : Colors.grey[600])),
        ]),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final IconData icon; final int count; final String label; final Color color;
  const SummaryCard({required this.icon, required this.count, required this.label, required this.color});
  @override Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        SizedBox(height: 4),
        Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ]),
    );
  }
}