import 'package:e_telly_app/widgets/custom_font.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/actions.dart';
import '../widgets/emergency_contacts.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Quick Actions Data
  final List<QuickAction> _quickActions = [
    QuickAction(
      id: 'alerts',
      title: 'Alerts',
      icon: Icons.notifications,
      color: ET_ORANGE,
    ),
    QuickAction(
      id: 'report-emergency',
      title: 'Report Emergency',
      icon: Icons.warning,
      color: ET_RED,
    ),
    QuickAction(
      id: 'flood-monitor',
      title: 'Flood Monitoring',
      icon: Icons.flood,
      color: ET_BLUE,
    ),
    QuickAction(
      id: 'safety-tips',
      title: 'Safety Tips',
      icon: Icons.info,
      color: ET_GREEN,
    ),
  ];

  // Emergency Contacts Data
  final List<EmergencyContact> _emergencyContacts = [
    EmergencyContact(
      id: '911',
      title: 'Unified 911',
      number: '911',
      subtitle: 'Nationwide Emergency Hotline',
      icon: Icons.sos,
      color: ET_GREEN,
      type: 'hotline',
    ),
    EmergencyContact(
      id: 'redcross',
      title: 'Red Cross',
      number: '143',
      subtitle: 'Philippine Red Cross',
      icon: Icons.medical_services,
      color: ET_RED,
      type: 'hotline',
    ),
    EmergencyContact(
      id: 'pnp',
      title: 'PNP',
      number: '117',
      subtitle: 'Philippine National Police',
      icon: Icons.shield,
      color: ET_BLUE,
      type: 'hotline',
    ),
    EmergencyContact(
      id: 'navotas_drrrmo',
      title: 'Navotas DRRMO',
      number: '8-281-1111',
      subtitle: 'Emergency Hotline',
      icon: Icons.warning,
      color: ET_ORANGE,
      type: 'hotline',
    ),
    EmergencyContact(
      id: 'navotas_bfp',
      title: 'BFP - Navotas',
      number: '8-281-0854',
      subtitle: 'Bureau of Fire Protection',
      icon: Icons.local_fire_department,
      color: ET_RED,
      type: 'fire',
    ),
    EmergencyContact(
      id: 'navotas_pnp',
      title: 'PNP - Navotas',
      number: '0998 598 7866',
      subtitle: 'Philippine National Police',
      icon: Icons.shield,
      color: ET_BLUE,
      type: 'police',
    ),
    EmergencyContact(
      id: 'navotas_city_hall',
      title: 'Navotas City Hall',
      number: '8-283-7415',
      subtitle: 'City Government Office',
      icon: Icons.business,
      color: ET_GREEN,
      type: 'hotline',
    ),
  ];

  final List<EmergencyContact> _jrtContacts = [
    EmergencyContact(
      id: 'jrt_globe',
      title: 'Globe',
      number: '0917 521 8578',
      subtitle: 'JRT Text Emergency',
      icon: Icons.chat,
      color: ET_BLUE,
      type: 'text',
    ),
    EmergencyContact(
      id: 'jrt_smart',
      title: 'Smart',
      number: '0908 886 8578',
      subtitle: 'JRT Text Emergency',
      icon: Icons.chat,
      color: ET_ORANGE,
      type: 'text',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: CustomFont(
                text: 'What would you like to do?',
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 0,
                mainAxisExtent: 130,
              ),
              itemCount: _quickActions.length,
              itemBuilder: (context, index) {
                return _buildQuickAction(_quickActions[index]);
              },
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: CustomFont(
                text: 'EMERGENCY CONTACTS',
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Navotas City Emergency',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _emergencyContacts
                    .sublist(3)
                    .map((contact) => _buildContactItem(contact))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showJRTModal,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Text JRT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.info, size: 16, color: Color(0xFF666666)),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Color(0xFF666666),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _jrtContacts
                    .map((contact) => _buildContactItem(contact))
                    .toList(),
              ),
            ),
            const SizedBox(height: 3),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'National Emergency',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: _emergencyContacts
                    .sublist(0, 3)
                    .map((contact) => _buildContactItem(contact))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(QuickAction action) {
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Handle action tap - navigate to corresponding tab
          _handleQuickActionTap(action.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, size: 35, color: action.color),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(EmergencyContact contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: contact.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(contact.icon, size: 16, color: contact.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  contact.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Text(
            contact.number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: contact.color,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              // Handle call/SMS
            },
            child: Icon(
              contact.type == 'text' ? Icons.message : Icons.call,
              size: 16,
              color: contact.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showJRTModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JRT Text Emergency Numbers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._jrtContacts.map((contact) => _buildContactItem(contact)),
          ],
        ),
      ),
    );
  }

  void _handleQuickActionTap(String actionId) {
    // Only report-emergency navigates to a tab
    if (actionId == 'report-emergency' && widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(2); // Report Emergency tab
    } else {
      // All other actions navigate to separate screens
      final routeMapping = {
        'alerts': '/alerts',
        'flood-monitor': '/flood-monitor',
        'safety-tips': '/safety-tips',
      };

      final route = routeMapping[actionId];
      if (route != null) {
        Navigator.pushNamed(context, route);
      }
    }
  }
}
