// lib/models/alert.dart
class AlertItem {
  final String id;
  final String source;      // "system", "PAGASA", "PHIVOLCS", "NDRRMC"
  final String type;        // "flood", "river", "rainfall", "earthquake", "lahar", "typhoon", "other"
  final String severity;    // "evacuate", "critical", "warning", "watch"
  final String title;
  final String description;
  final String location;
  final List<String> barangays;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  bool read;
  
  // Additional fields from your backend
  final String? waterLevel;
  final String? evacuationCenter;
  final String? rawData;     // Original feed text (for debugging)

  AlertItem({
    required this.id,
    required this.source,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
    required this.barangays,
    required this.createdAt,
    this.expiresAt,
    required this.isActive,
    required this.read,
    this.waterLevel,
    this.evacuationCenter,
    this.rawData,
  });

  // Convert backend severity to your UI severity levels
  String get uiSeverity {
    switch (severity) {
      case 'evacuate':
        return 'critical';
      case 'critical':
        return 'critical';
      case 'warning':
        return 'high';
      case 'watch':
        return 'moderate';
      default:
        return 'moderate';
    }
  }

  // Convert backend type to your UI type
  String get uiType {
    switch (type) {
      case 'flood':
        return 'flood';
      case 'river':
        return 'water_level';
      case 'rainfall':
        return 'rain';
      case 'evacuate':
        return 'evacuate';
      case 'earthquake':
        return 'earthquake';
      case 'typhoon':
        return 'typhoon';
      default:
        return type;
    }
  }

  // Helper to get affected barangays as string
  String get barangayList {
    if (barangays.isEmpty) return location;
    if (barangays.length <= 3) return barangays.join(', ');
    return '${barangays.take(3).join(', ')} +${barangays.length - 3} more';
  }

  // Extract water level from description if present
  String? get extractedWaterLevel {
    if (waterLevel != null) return waterLevel;
    
    // Look for water level patterns in description
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:m|meter|meters)', caseSensitive: false),
      RegExp(r'water level:?\s*(\d+(?:\.\d+)?)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(description);
      if (match != null) {
        return '${match.group(1)}m';
      }
    }
    
    if (description.toLowerCase().contains('rising')) return 'Rising';
    if (description.toLowerCase().contains('critical')) return 'Critical';
    return null;
  }

  // Format time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  // Check if alert is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['_id'] ?? json['id'] ?? '',
      source: json['source'] ?? 'system',
      type: json['type'] ?? 'other',
      severity: json['severity'] ?? 'watch',
      title: json['title'] ?? 'Alert',
      description: json['description'] ?? '',
      location: json['location'] ?? 'Antipolo City, Rizal',
      barangays: List<String>.from(json['barangays'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      isActive: json['isActive'] ?? true,
      read: false, // Track read status locally
      waterLevel: json['waterLevel'],
      evacuationCenter: json['evacuationCenter'],
      rawData: json['raw'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'source': source,
      'type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'location': location,
      'barangays': barangays,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}