import 'package:flutter/material.dart';
import 'dart:math';

// Custom Painters
class GridPainter extends CustomPainter {
  final Color color;
  
  GridPainter({this.color = const Color(0xFFE0E0E0)});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaterwayPainter extends CustomPainter {
  final double curve;
  
  WaterwayPainter({required this.curve});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF3B82F6).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..cubicTo(
        curve, 0,
        size.width - curve, size.height,
        size.width, size.height / 2,
      )
      ..cubicTo(
        size.width - curve, size.height,
        curve, 0,
        0, size.height / 2,
      );
    
    canvas.drawPath(path, paint);
    
    final wavePaint = Paint()
      ..color = Color(0xFF2563EB).withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < 3; i++) {
      final wavePath = Path()
        ..moveTo(0, size.height / 2 + i * 5)
        ..cubicTo(
          curve, i * 5,
          size.width - curve, size.height - i * 5,
          size.width, size.height / 2 + i * 5,
        );
      canvas.drawPath(wavePath, wavePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoutePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  
  RoutePainter({
    required this.start,
    required this.end,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final dashPath = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    
    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final pathMetrics = dashPath.computeMetrics();
    for (final pathMetric in pathMetrics) {
      double distance = 0;
      while (distance < pathMetric.length) {
        final startOffset = pathMetric.getTangentForOffset(distance)!.position;
        distance += 10;
        if (distance > pathMetric.length) break;
        final endOffset = pathMetric.getTangentForOffset(distance)!.position;
        distance += 5;
        canvas.drawLine(startOffset, endOffset, dashPaint);
      }
    }
    
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final arrowSize = 10.0;
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * cos(angle - pi / 6),
        end.dy - arrowSize * sin(angle - pi / 6),
      )
      ..lineTo(
        end.dx - arrowSize * cos(angle + pi / 6),
        end.dy - arrowSize * sin(angle + pi / 6),
      )
      ..close();
    
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(arrowPath, arrowPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TrianglePainter extends CustomPainter {
  final Color color;
  
  TrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reusable Widgets
class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.blue[700]!),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class RoadWidget extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final bool isVertical;

  const RoadWidget({
    super.key,
    required this.width,
    required this.height,
    this.label = '',
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300]!,
        border: Border.all(color: Colors.grey[500]!, width: 1),
      ),
      child: label.isNotEmpty
          ? Center(
              child: Transform.rotate(
                angle: isVertical ? 1.5708 : 0,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700]!,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class MapLegend extends StatelessWidget {
  final bool isEvacMap;
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;
  final Color criticalColor;
  final Color mainCenterColor;
  final Color secondaryCenterColor;
  final Color medicalCenterColor;

  const MapLegend({
    super.key,
    required this.isEvacMap,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
    required this.criticalColor,
    required this.mainCenterColor,
    required this.secondaryCenterColor,
    required this.medicalCenterColor,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> legendItems = isEvacMap
        ? [
            {'color': mainCenterColor, 'label': 'Main Center'},
            {'color': secondaryCenterColor, 'label': 'Secondary'},
            {'color': medicalCenterColor, 'label': 'Medical'},
            {'color': criticalColor, 'label': 'Critical Area'},
          ]
        : [
            {'color': safeColor, 'label': 'Safe'},
            {'color': warningColor, 'label': 'Warning'},
            {'color': dangerColor, 'label': 'Danger'},
            {'color': criticalColor, 'label': 'Critical'},
          ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEvacMap ? 'Evacuation Map Legend' : 'Flood Status Legend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: legendItems.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: item['color'],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    item['label'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class RouteStatus extends StatelessWidget {
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;

  const RouteStatus({
    super.key,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 20, color: Color(0xFF1F2937)),
              SizedBox(width: 8),
              Text(
                'Route Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                RouteCard(
                  name: 'Main Evacuation Route',
                  status: 'open',
                  distance: 1.2,
                  safeColor: safeColor,
                  warningColor: warningColor,
                  dangerColor: dangerColor,
                ),
                SizedBox(width: 12),
                RouteCard(
                  name: 'Daanghari Emergency Route',
                  status: 'congested',
                  distance: 0.8,
                  safeColor: safeColor,
                  warningColor: warningColor,
                  dangerColor: dangerColor,
                ),
                SizedBox(width: 12),
                RouteCard(
                  name: 'Coastal Evacuation Path',
                  status: 'open',
                  distance: 0.5,
                  safeColor: safeColor,
                  warningColor: warningColor,
                  dangerColor: dangerColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RouteCard extends StatelessWidget {
  final String name;
  final String status;
  final double distance;
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;

  const RouteCard({
    super.key,
    required this.name,
    required this.status,
    required this.distance,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
  });

  Color get statusColor {
    switch (status) {
      case 'open':
        return safeColor;
      case 'congested':
        return warningColor;
      case 'closed':
        return dangerColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50]!,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.directions, size: 14, color: Colors.grey[600]!),
                  SizedBox(width: 4),
                  Text(
                    '$distance km',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color dangerColor;

  const TabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.dangerColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFFEE2E2) : Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? dangerColor : Color(0xFFE5E7EB),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: dangerColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? dangerColor : Color(0xFF6B7280),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? dangerColor : Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: color),
                ),
              ),
              SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}