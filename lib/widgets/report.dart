import 'package:flutter/material.dart';
import 'dart:io';

// --- MODELS ---

class EmergencyType {
  final String id;
  final String title;
  final IconData icon;
  final Color typeColor;

  EmergencyType({
    required this.id,
    required this.title,
    required this.icon,
    required this.typeColor,
  });
}

class SeverityLevel {
  final int level;
  final String label;
  final String description;
  final Color color;

  SeverityLevel({
    required this.level,
    required this.label,
    required this.description,
    required this.color,
  });
}

class UserData {
  final String? fullName;
  final String? address;
  final String? phoneNumber;
  UserData({this.fullName, this.address, this.phoneNumber});
}

// --- WIDGETS ---

class ImagePreviewList extends StatelessWidget {
  final List<String> images;
  final Function(int) onRemove;

  const ImagePreviewList({
    Key? key,
    required this.images,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: images.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            return Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${images.length} of 5 photos uploaded',
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
        ],
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final Widget value;

  const SummaryRow({Key? key, required this.label, required this.value})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          value,
        ],
      ),
    );
  }
}
