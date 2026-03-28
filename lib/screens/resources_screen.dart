import 'package:flutter/material.dart';
import '../widgets/resources.dart' as resources;

class ResourceItem {
  final String id;
  final String name;
  final String category;
  final String description;
  final IconData icon;
  final bool available;
  final String? estimatedDelivery;
  final String? unit;

  ResourceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.available,
    this.estimatedDelivery,
    this.unit,
  });
}

class MyRequest {
  final String id;
  final String resourceId;
  final int quantity;
  final bool urgent;
  final String notes;
  final String status;
  final String date;
  final String type;

  MyRequest({
    required this.id,
    required this.resourceId,
    required this.quantity,
    required this.urgent,
    required this.notes,
    required this.status,
    required this.date,
    required this.type,
  });
}

class ResourcesScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final ValueChanged<String>? onTabSelected;

  const ResourcesScreen({Key? key, this.onBackPressed, this.onTabSelected})
    : super(key: key);

  @override
  _ResourcesScreenState createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  String _activeTab = 'donate';
  String? _selectedResource;
  String _quantity = '1';
  bool _urgent = false;
  String _notes = '';
  bool _showModal = false;

  final List<MyRequest> _myRequests = [];
  final ScrollController _scrollController = ScrollController();

  // Donatable Items
  final List<ResourceItem> _donatableItems = [
    ResourceItem(
      id: 'd1',
      name: 'Clothes',
      category: 'clothes',
      description: 'Clean and wearable clothes for all ages',
      icon: Icons.checkroom,
      available: true,
      unit: 'piece',
    ),
    ResourceItem(
      id: 'd2',
      name: 'Canned Goods',
      category: 'food',
      description: 'Non-perishable canned foods',
      icon: Icons.restaurant,
      available: true,
      unit: 'can',
    ),
    ResourceItem(
      id: 'd3',
      name: 'Bottled Water',
      category: 'water',
      description: 'Sealed bottled water',
      icon: Icons.water_drop,
      available: true,
      unit: 'bottle',
    ),
    ResourceItem(
      id: 'd4',
      name: 'Blankets',
      category: 'clothes',
      description: 'Clean blankets for warmth',
      icon: Icons.bed,
      available: true,
      unit: 'blanket',
    ),
    ResourceItem(
      id: 'd5',
      name: 'First Aid Supplies',
      category: 'kit',
      description: 'Bandages, antiseptics, basic medicines',
      icon: Icons.medical_services,
      available: true,
      unit: 'item',
    ),
    ResourceItem(
      id: 'd6',
      name: 'Hygiene Kits',
      category: 'other',
      description: 'Soap, toothpaste, sanitary products',
      icon: Icons.clean_hands,
      available: true,
      unit: 'kit',
    ),
    ResourceItem(
      id: 'd7',
      name: 'Infant Supplies',
      category: 'other',
      description: 'Baby formula, diapers, baby clothes',
      icon: Icons.child_care,
      available: true,
      unit: 'item',
    ),
    ResourceItem(
      id: 'd8',
      name: 'Cooked Food',
      category: 'food',
      description: 'Prepared meals (properly packed)',
      icon: Icons.restaurant_menu,
      available: true,
      unit: 'meal',
    ),
    ResourceItem(
      id: 'd9',
      name: 'Flashlights',
      category: 'kit',
      description: 'Working flashlights with batteries',
      icon: Icons.flashlight_on,
      available: true,
      unit: 'piece',
    ),
    ResourceItem(
      id: 'd10',
      name: 'Emergency Tools',
      category: 'kit',
      description: 'Whistles, multi-tools, rope',
      icon: Icons.build,
      available: true,
      unit: 'tool',
    ),
  ];

  // Requestable Items
  final List<ResourceItem> _requestableItems = [
    ResourceItem(
      id: '1',
      name: 'Drinking Water',
      category: 'water',
      description: '5-gallon purified water containers with essential minerals',
      icon: Icons.water_damage,
      available: true,
      estimatedDelivery: 'Within 1-2 hours',
      unit: 'container',
    ),
    ResourceItem(
      id: '2',
      name: 'Canned Goods Pack',
      category: 'food',
      description: 'Assorted canned goods (sardines, corned beef, beans)',
      icon: Icons.restaurant,
      available: true,
      estimatedDelivery: 'Within 1-2 hours',
      unit: 'pack',
    ),
    ResourceItem(
      id: '3',
      name: 'Emergency Clothes Set',
      category: 'clothes',
      description:
          'Complete set of emergency clothing (shirt, pants, underwear)',
      icon: Icons.checkroom,
      available: true,
      estimatedDelivery: 'Within 2-3 hours',
      unit: 'set',
    ),
    ResourceItem(
      id: '4',
      name: 'Basic Emergency Kit',
      category: 'kit',
      description: 'First aid, flashlight, whistle, thermal blanket, batteries',
      icon: Icons.medical_services,
      available: true,
      estimatedDelivery: 'Within 1-2 hours',
      unit: 'kit',
    ),
    ResourceItem(
      id: '5',
      name: 'Clean Water Pack',
      category: 'water',
      description: 'Pack of 12 bottled water (500ml each)',
      icon: Icons.water_drop,
      available: true,
      estimatedDelivery: 'Within 2-3 hours',
      unit: 'pack',
    ),
    ResourceItem(
      id: '6',
      name: 'Ready-to-Eat Meals',
      category: 'food',
      description: '24-hour food pack (instant noodles, biscuits, coffee)',
      icon: Icons.restaurant_menu,
      available: true,
      estimatedDelivery: 'Within 1-2 hours',
      unit: 'pack',
    ),
    ResourceItem(
      id: '7',
      name: 'Warm Blankets',
      category: 'clothes',
      description: 'Thermal emergency blankets for cold weather',
      icon: Icons.bed,
      available: true,
      estimatedDelivery: 'Within 1-2 hours',
      unit: 'blanket',
    ),
    ResourceItem(
      id: '8',
      name: 'Advanced First Aid Kit',
      category: 'kit',
      description:
          'Complete medical supplies including bandages, antiseptics, medicines',
      icon: Icons.medical_information,
      available: true,
      estimatedDelivery: 'Within 2-3 hours',
      unit: 'kit',
    ),
    ResourceItem(
      id: '9',
      name: 'Infant Survival Kit',
      category: 'kit',
      description: 'Baby formula, diapers, clothes, and essential supplies',
      icon: Icons.child_care,
      available: true,
      estimatedDelivery: 'Within 2-3 hours',
      unit: 'kit',
    ),
    ResourceItem(
      id: '10',
      name: 'Hygiene Kit',
      category: 'other',
      description: 'Soap, toothpaste, sanitary pads, toilet paper',
      icon: Icons.clean_hands,
      available: true,
      estimatedDelivery: 'Within 2-3 hours',
      unit: 'kit',
    ),
  ];

  Color _getDonateCategoryColor(String category) {
    switch (category) {
      case 'water':
        return const Color(0xFF06B6D4);
      case 'food':
        return const Color(0xFFF59E0B);
      case 'clothes':
        return const Color(0xFF10B981);
      case 'kit':
        return const Color(0xFF8B5CF6);
      case 'other':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF666666);
    }
  }

  Color _getRequestCategoryColor(String category) {
    switch (category) {
      case 'water':
        return const Color(0xFF3B82F6);
      case 'food':
        return const Color(0xFFF59E0B);
      case 'clothes':
        return const Color(0xFF10B981);
      case 'kit':
        return const Color(0xFFDC2626);
      case 'other':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF666666);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'water':
        return Icons.water_drop;
      case 'food':
        return Icons.restaurant;
      case 'clothes':
        return Icons.checkroom;
      case 'kit':
        return Icons.medical_services;
      case 'other':
        return Icons.inventory;
      default:
        return Icons.inventory;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'water':
        return 'Water';
      case 'food':
        return 'Food';
      case 'clothes':
        return 'Clothes';
      case 'kit':
        return 'Emergency Kit';
      case 'other':
        return 'Other Supplies';
      default:
        return category;
    }
  }

  void _handleDonationSelect(String resourceId) {
    if (_activeTab == 'donate') {
      setState(() {
        _selectedResource = resourceId;
        _showModal = true;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleRequestSelect(String resourceId) {
    if (_activeTab == 'request') {
      setState(() {
        _selectedResource = resourceId;
        _showModal = true;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleSubmitDonation() {
    if (_selectedResource == null) return;

    final resource = _donatableItems.firstWhere(
      (r) => r.id == _selectedResource,
      orElse: () => _donatableItems[0],
    );

    final qty = int.tryParse(_quantity) ?? 1;

    if (qty < 1) {
      _showAlert('Error', 'Quantity must be at least 1');
      return;
    }

    final newDonation = MyRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      resourceId: _selectedResource!,
      quantity: qty,
      urgent: _urgent,
      notes: _notes.trim(),
      status: 'pending',
      date: _formatDateTime(DateTime.now()),
      type: 'donation',
    );

    setState(() {
      _myRequests.insert(0, newDonation);
    });

    _showAlert(
      'Donation Submitted!',
      'Thank you for your generous donation of $qty ${resource.name}${qty > 1 ? 's' : ''}!\n\n'
          'DRRMO will contact you for pickup arrangements.\n'
          '${_urgent ? '🚨 URGENT DONATION - Priority pickup' : ''}',
      onOk: () {
        setState(() {
          _showModal = false;
          _quantity = '1';
          _urgent = false;
          _notes = '';
          _selectedResource = null;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          setState(() {
            _activeTab = 'myRequests';
          });
        });
      },
    );
  }

  void _handleSubmitRequest() {
    if (_selectedResource == null) return;

    final resource = _requestableItems.firstWhere(
      (r) => r.id == _selectedResource,
      orElse: () => _requestableItems[0],
    );

    final qty = int.tryParse(_quantity) ?? 1;

    if (qty < 1) {
      _showAlert('Error', 'Quantity must be at least 1');
      return;
    }

    if (!resource.available) {
      _showAlert(
        'Not Available',
        'Sorry, ${resource.name} is currently out of stock.',
      );
      return;
    }

    final newRequest = MyRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      resourceId: _selectedResource!,
      quantity: qty,
      urgent: _urgent,
      notes: _notes.trim(),
      status: 'pending',
      date: _formatDateTime(DateTime.now()),
      type: 'request',
    );

    setState(() {
      _myRequests.insert(0, newRequest);
    });

    _showAlert(
      'Request Submitted!',
      'Your request for $qty ${resource.name}${qty > 1 ? 's' : ''} has been submitted.\n\n'
          'Estimated delivery: ${resource.estimatedDelivery}\n'
          '${_urgent ? '🚨 URGENT REQUEST - Priority handling' : ''}',
      onOk: () {
        setState(() {
          _showModal = false;
          _quantity = '1';
          _urgent = false;
          _notes = '';
          _selectedResource = null;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          setState(() {
            _activeTab = 'myRequests';
          });
        });
      },
    );
  }

  void _handleCancelRequest(String requestId) {
    _showConfirmDialog(
      'Cancel',
      'Are you sure you want to cancel this?',
      onConfirm: () {
        setState(() {
          _myRequests.removeWhere((r) => r.id == requestId);
        });
        _showAlert('Cancelled', 'Your item has been cancelled.');
      },
    );
  }

  void _handleContactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('Select contact method:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAlert('Call', 'Would call DRRMO hotline');
            },
            child: const Text('📞 Call Hotline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAlert('SMS', 'Would send SMS to DRRMO');
            },
            child: const Text('📱 SMS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAlert(
                'DRRMO Office',
                'Navotas City Hall Compound\nM. Naval Street, Navotas City\nOpen 24/7 during emergencies',
              );
            },
            child: const Text('📍 Visit DRRMO Office'),
          ),
        ],
      ),
    );
  }

  ResourceItem? _getSelectedResourceDetails() {
    if (_selectedResource == null) return null;

    return _activeTab == 'donate'
        ? _donatableItems.firstWhere(
            (r) => r.id == _selectedResource,
            orElse: () => _donatableItems[0],
          )
        : _requestableItems.firstWhere(
            (r) => r.id == _selectedResource,
            orElse: () => _requestableItems[0],
          );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    String title,
    String message, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 3),
              resources.TabBar(
                activeTab: _activeTab,
                onTabChanged: (tab) => setState(() => _activeTab = tab),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
          if (_showModal)
            GestureDetector(
              onTap: () => setState(() => _showModal = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_showModal)
            Positioned.fill(
              child: resources.ResourceModal(
                resource: _getSelectedResourceDetails(),
                activeTab: _activeTab,
                quantity: _quantity,
                urgent: _urgent,
                notes: _notes,
                getCategoryColor: _activeTab == 'donate'
                    ? _getDonateCategoryColor
                    : _getRequestCategoryColor,
                getCategoryName: _getCategoryName,
                onClose: () => setState(() => _showModal = false),
                onQuantityChanged: (qty) => setState(() => _quantity = qty),
                onUrgentChanged: (value) => setState(() => _urgent = value),
                onNotesChanged: (text) => setState(() => _notes = text),
                onSubmit: _activeTab == 'donate'
                    ? _handleSubmitDonation
                    : _handleSubmitRequest,
                onContactSupport: _handleContactSupport,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case 'donate':
        return resources.DonateContent(
          items: _donatableItems,
          getCategoryColor: _getDonateCategoryColor,
          onItemSelect: _handleDonationSelect,
        );
      case 'request':
        return resources.RequestContent(
          items: _requestableItems,
          getCategoryColor: _getRequestCategoryColor,
          onItemSelect: _handleRequestSelect,
        );
      case 'myRequests':
        return resources.MyRequestsContent(
          requests: _myRequests,
          donatableItems: _donatableItems,
          requestableItems: _requestableItems,
          getDonateCategoryColor: _getDonateCategoryColor,
          getRequestCategoryColor: _getRequestCategoryColor,
          onCancelRequest: _handleCancelRequest,
          onShowAlert: _showAlert,
        );
      default:
        return Container();
    }
  }
}
