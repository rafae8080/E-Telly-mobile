import 'package:flutter/material.dart';
import '../screens/evacuation_screen.dart';

class EvacuationHeader extends StatelessWidget {
  final int availableCount;
  final int totalCount;

  const EvacuationHeader({
    super.key,
    required this.availableCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.pop(context),
              color: const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Evacuation Centers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$availableCount Available • $totalCount Total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFDC2626).withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Info'),
                    content: const Text(
                      'Evacuation centers are safe shelters during floods. Check availability before going.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusSummary extends StatelessWidget {
  final int availableCount;
  final int almostFullCount;
  final int fullCount;

  const StatusSummary({
    super.key,
    required this.availableCount,
    required this.almostFullCount,
    required this.fullCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SummaryItem(
            color: const Color(0xFF10B981),
            count: availableCount,
            label: 'Available',
          ),
          const SizedBox(width: 16),
          SummaryItem(
            color: const Color(0xFFF59E0B),
            count: almostFullCount,
            label: 'Almost Full',
          ),
          const SizedBox(width: 16),
          SummaryItem(
            color: const Color(0xFFDC2626),
            count: fullCount,
            label: 'Full',
          ),
        ],
      ),
    );
  }
}

class SummaryItem extends StatelessWidget {
  final Color color;
  final int count;
  final String label;

  const SummaryItem({
    super.key,
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructionsBanner extends StatelessWidget {
  const InstructionsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFDC2626).withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: const Text(
              'Check center availability before going. Bring essential items: medicines, documents, food, water.',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EvacuationCenterCard extends StatelessWidget {
  final EvacuationCenter center;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final VoidCallback onDirections;
  final VoidCallback onCall;
  final String hazardSeverityLevel;
  final bool wasRerouted;
  final String? hazardLabel;

  const EvacuationCenterCard({
    super.key,
    required this.center,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.onDirections,
    required this.onCall,
    required bool isRecommended,
    this.hazardSeverityLevel = 'none',
    this.wasRerouted = false,
    this.hazardLabel,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = (center.currentOccupancy / center.capacity) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Color(0xFF666666)),
                  const SizedBox(width: 4),
                  Text(
                    center.distance,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            center.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            center.address,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: center.currentOccupancy / center.capacity,
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${center.currentOccupancy}/${center.capacity} (${occupancyPercent.round()}%)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
          ),
          if (hazardSeverityLevel != 'none') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _badgeColor(hazardSeverityLevel),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber_rounded, size: 10, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  wasRerouted
                      ? 'Rerouted • ${hazardLabel ?? "Hazard"}'
                      : '${_badgeLabel(hazardSeverityLevel)} • ${hazardLabel ?? "Hazard"}',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...center.facilities.take(3).map((facility) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      facility,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              )),
              if (center.facilities.length > 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '+${center.facilities.length - 3} more',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: center.status == 'full' ? null : onDirections,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: statusColor,
                    side: BorderSide(
                      color: center.status == 'full'
                          ? Colors.grey[300]!
                          : statusColor.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.navigation, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Directions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCall,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: statusColor,
                    side: BorderSide(color: statusColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.call, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 12, color: Color(0xFF666666)),
              const SizedBox(width: 6),
              Text(
                center.operatingHours,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _badgeColor(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFDC2626);
      case 'high':     return const Color(0xFFF59E0B);
      case 'moderate': return const Color(0xFFEAB308);
      default:         return Colors.transparent;
    }
  }

  String _badgeLabel(String s) {
    switch (s) {
      case 'critical': return 'Critical';
      case 'high':     return 'Warning';
      case 'moderate': return 'Watch';
      default:         return '';
    }
  }
}