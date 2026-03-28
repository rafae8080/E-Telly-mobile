import 'package:flutter/material.dart';
import '../screens/safety_tips_screen.dart';

class SafetyTipCard extends StatelessWidget {
  final SafetyTip tip;
  final VoidCallback onTap;
  final Color Function(String) getRiskLevelColor;

  const SafetyTipCard({
    Key? key,
    required this.tip,
    required this.onTap,
    required this.getRiskLevelColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: tip.color, width: 3)),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tip.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(tip.icon, size: 20, color: tip.color),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tip.color,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        tip.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        tip.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.list_outlined, size: 14, color: tip.color),
                          SizedBox(width: 4),
                          Text(
                            '${tip.steps} steps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: getRiskLevelColor(
                                tip.riskLevel,
                              ).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tip.riskLevel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: getRiskLevelColor(tip.riskLevel),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Icon(Icons.chevron_right, size: 18, color: tip.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SafetyTipDetailModal extends StatelessWidget {
  final SafetyTip tip;
  final Color Function(String) getRiskLevelColor;
  final VoidCallback onClose;
  final Function(String) onEmergencyCall;

  const SafetyTipDetailModal({
    Key? key,
    required this.tip,
    required this.getRiskLevelColor,
    required this.onClose,
    required this.onEmergencyCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  DetailModalHeader(
                    tip: tip,
                    getRiskLevelColor: getRiskLevelColor,
                    onClose: onClose,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 20),
                          StepsSection(tip: tip),
                          if (tip.emergencyNumber != null)
                            EmergencyContactSection(
                              tip: tip,
                              onEmergencyCall: onEmergencyCall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class DetailModalHeader extends StatelessWidget {
  final SafetyTip tip;
  final Color Function(String) getRiskLevelColor;
  final VoidCallback onClose;

  const DetailModalHeader({
    Key? key,
    required this.tip,
    required this.getRiskLevelColor,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 40, 20, 24),
      decoration: BoxDecoration(
        color: tip.color,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 20,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.close, size: 24, color: Colors.white),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(tip.icon, size: 32, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                tip.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tip.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: getRiskLevelColor(tip.riskLevel),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tip.riskLevel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

class StepsSection extends StatelessWidget {
  final SafetyTip tip;

  const StepsSection({Key? key, required this.tip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_outlined, size: 20, color: tip.color),
            SizedBox(width: 8),
            Text(
              'STEP-BY-STEP GUIDE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: tip.color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Divider(height: 1, color: Color(0xFFE5E7EB)),
        SizedBox(height: 12),
        ...tip.detailedSteps!.asMap().entries.map((entry) {
          int index = entry.key;
          String step = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: tip.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class EmergencyContactSection extends StatelessWidget {
  final SafetyTip tip;
  final Function(String) onEmergencyCall;

  const EmergencyContactSection({
    Key? key,
    required this.tip,
    required this.onEmergencyCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.warning, size: 20, color: tip.color),
            SizedBox(width: 8),
            Text(
              'EMERGENCY CONTACT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: tip.color,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Divider(height: 1, color: Color(0xFFE5E7EB)),
        SizedBox(height: 10),
        GestureDetector(
          onTap: () => onEmergencyCall(tip.emergencyNumber!),
          child: Container(
            decoration: BoxDecoration(
              color: tip.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.call, size: 24, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.emergencyNumber!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap to call emergency services',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
