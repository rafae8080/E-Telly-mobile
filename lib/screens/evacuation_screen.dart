import 'package:flutter/material.dart';
import '../widgets/evacuation.dart';
import 'package:url_launcher/url_launcher.dart';

class EvacuationCenter {
  final int id;
  final String name;
  final String address;
  final int capacity;
  final int currentOccupancy;
  final String status; // 'available', 'almost_full', 'full'
  final String contact;
  final String coordinates;
  final String distance;
  final List<String> facilities;
  final String operatingHours;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.currentOccupancy,
    required this.status,
    required this.contact,
    required this.coordinates,
    required this.distance,
    required this.facilities,
    required this.operatingHours,
  });
}

class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});

  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  final List<EvacuationCenter> _evacuationCenters = [
    EvacuationCenter(
      id: 1,
      name: 'Navotas City Hall Evacuation Center',
      address: 'M. Naval St, Navotas, Metro Manila',
      capacity: 500,
      currentOccupancy: 480,
      status: 'almost_full',
      contact: '288-4567',
      coordinates: '14.6525,120.9439',
      distance: '1.2 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Power Outlets',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 2,
      name: 'Navotas Sports Complex',
      address: 'M. Naval St, Navotas, Metro Manila',
      capacity: 800,
      currentOccupancy: 320,
      status: 'available',
      contact: '288-4568',
      coordinates: '14.6489,120.9487',
      distance: '2.5 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Showers',
        'Play Area',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 3,
      name: 'Navotas National High School',
      address: 'M. Naval St, Navotas, Metro Manila',
      capacity: 1200,
      currentOccupancy: 150,
      status: 'available',
      contact: '288-4569',
      coordinates: '14.6512,120.9523',
      distance: '3.1 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Classroom Areas',
      ],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 4,
      name: 'Tangos Elementary School',
      address: 'Tangos, Navotas, Metro Manila',
      capacity: 400,
      currentOccupancy: 400,
      status: 'full',
      contact: '288-4570',
      coordinates: '14.6550,120.9500',
      distance: '0.8 km',
      facilities: ['Food & Water', 'Restrooms'],
      operatingHours: '24/7',
    ),
    EvacuationCenter(
      id: 5,
      name: 'Navotas Polytechnic College',
      address: 'Bangus St, Navotas, Metro Manila',
      capacity: 600,
      currentOccupancy: 180,
      status: 'available',
      contact: '288-4571',
      coordinates: '14.6533,120.9555',
      distance: '2.8 km',
      facilities: [
        'Medical Station',
        'Food & Water',
        'Restrooms',
        'Study Areas',
      ],
      operatingHours: '24/7',
    ),
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF10B981);
      case 'almost_full':
        return const Color(0xFFF59E0B);
      case 'full':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'almost_full':
        return 'Almost Full';
      case 'full':
        return 'FULL';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      case 'almost_full':
        return Icons.warning;
      case 'full':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _openDirections(String coordinates) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$coordinates&travelmode=driving';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Unable to open directions'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openContact(String contact) async {
    final cleanNumber = contact.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Unable to make call'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<EvacuationCenter> get _availableCenters => _evacuationCenters
      .where((center) => center.status == 'available')
      .toList();

  List<EvacuationCenter> get _almostFullCenters => _evacuationCenters
      .where((center) => center.status == 'almost_full')
      .toList();

  List<EvacuationCenter> get _fullCenters =>
      _evacuationCenters.where((center) => center.status == 'full').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              StatusSummary(
                availableCount: _availableCenters.length,
                almostFullCount: _almostFullCenters.length,
                fullCount: _fullCenters.length,
              ),
              const SizedBox(height: 16),
              const InstructionsBanner(),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _evacuationCenters.length,
                itemBuilder: (context, index) {
                  final center = _evacuationCenters[index];
                  return EvacuationCenterCard(
                    center: center,
                    statusColor: _getStatusColor(center.status),
                    statusText: _getStatusText(center.status),
                    statusIcon: _getStatusIcon(center.status),
                    onDirections: () => _openDirections(center.coordinates),
                    onCall: () => _openContact(center.contact),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
