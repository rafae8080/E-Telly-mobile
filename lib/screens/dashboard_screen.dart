import 'package:e_telly_app/widgets/custom_font.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/actions.dart';
import '../widgets/emergency_contacts.dart';
import '../services/p2p_auto_relay_controller.dart';
import '../screens/p2p_relay_screen.dart';

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
      id: 'disaster-monitor',
      title: 'Disaster Monitoring',
      icon: Icons.cyclone,
      color: ET_BLUE,
    ),
    QuickAction(
      id: 'safety-tips',
      title: 'Safety Tips',
      icon: Icons.info,
      color: ET_GREEN,
    ),
  ];

  // Antipolo City Emergency Contacts Data
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
      id: 'antipolo_drrrmo',
      title: 'Antipolo DRRMO',
      number: '8734-2470',
      subtitle: 'Emergency Hotline',
      icon: Icons.warning,
      color: ET_ORANGE,
      type: 'hotline',
    ),
    EmergencyContact(
      id: 'antipolo_bfp',
      title: 'BFP - Antipolo',
      number: '8260-0182',
      subtitle: 'Bureau of Fire Protection',
      icon: Icons.local_fire_department,
      color: ET_RED,
      type: 'fire',
    ),
    EmergencyContact(
      id: 'antipolo_pnp',
      title: 'PNP - Antipolo',
      number: '0917-157-7627',
      subtitle: 'Philippine National Police',
      icon: Icons.shield,
      color: ET_BLUE,
      type: 'police',
    ),
    EmergencyContact(
      id: 'antipolo_city_hall',
      title: 'Antipolo City Hall',
      number: '8401-3496',
      subtitle: 'City Government Office',
      icon: Icons.business,
      color: ET_GREEN,
      type: 'hotline',
    ),
  ];

  final List<EmergencyContact> _jrtContacts = [
    EmergencyContact(
      id: 'antipolo_opss',
      title: 'OPSS Mobile',
      number: '0917-854-0842',
      subtitle: 'Office of Public Safety',
      icon: Icons.security,
      color: ET_BLUE,
      type: 'hotline',
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
            _buildP2PRelayCard(),
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
                'Antipolo City Emergency',
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
                          'OPSS Emergency',
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
              'OPSS Emergency Numbers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._jrtContacts.map((contact) => _buildContactItem(contact)),
          ],
        ),
      ),
    );
  }

  Widget _buildP2PRelayCard() {
    final controller = P2PAutoRelayController.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isActiveNotifier,
      builder: (context, isActive, _) {
        return ValueListenableBuilder<int>(
          valueListenable: controller.pendingCountNotifier,
          builder: (context, pendingCount, _) {
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const P2PRelayScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDC2626).withOpacity(0.06)
                      : const Color(0xFF06B6D4).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFDC2626).withOpacity(0.25)
                        : const Color(0xFF06B6D4).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFDC2626).withOpacity(0.1)
                            : const Color(0xFF06B6D4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bluetooth_searching,
                        size: 22,
                        color: isActive
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isActive ? 'P2P Relay Active' : 'P2P Mesh Relay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? const Color(0xFFDC2626)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isActive
                                ? '$pendingCount report${pendingCount != 1 ? 's' : ''} relaying — tap to monitor'
                                : 'Tap to receive or send offline reports',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFFDC2626),
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleQuickActionTap(String actionId) {
    if (actionId == 'report-emergency' && widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(2);
    } else {
      final routeMapping = {
        'alerts': '/alerts',
        'disaster-monitor': '/disaster-monitor',
        'safety-tips': '/safety-tips',
      };

      final route = routeMapping[actionId];
      if (route != null) {
        Navigator.pushNamed(context, route);
      }
    }
  }
}