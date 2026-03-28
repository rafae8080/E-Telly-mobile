import 'package:flutter/material.dart';

class EmergencyContact extends StatelessWidget {
  const EmergencyContact({
    super.key,
    required this.id,
    required this.title,
    required this.number,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });

  final String id;
  final String title;
  final String number;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              // InkWell(
              //   onTap: type == 'text'
              //       ? () => _handleSendSMS(number)
              //       : () => _handleEmergencyCall(number),
              //   child: Container(
              //     width: 32,
              //     height: 32,
              //     decoration: BoxDecoration(
              //       color: color.withOpacity(0.1),
              //       borderRadius: BorderRadius.circular(16),
              //     ),
              //     child: Icon(
              //       type == 'text' ? Icons.chat : Icons.call,
              //       size: 14,
              //       color: color,
              //     ),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
