import 'package:e_telly_app/constants.dart';
import 'package:e_telly_app/screens/resources_screen.dart';
import 'package:flutter/material.dart';

class TabBar extends StatelessWidget {
  final String activeTab;
  final Function(String) onTabChanged;

  const TabBar({Key? key, required this.activeTab, required this.onTabChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildTabButton('donate', 'Donate'),
          const SizedBox(width: 12),
          _buildTabButton('request', 'Request'),
          const SizedBox(width: 12),
          _buildTabButton('myRequests', 'My Items'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String id, String label) {
    final isActive = activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(id),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? ET_RED : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DonateContent extends StatelessWidget {
  final List<ResourceItem> items;
  final Color Function(String) getCategoryColor;
  final Function(String) onItemSelect;

  const DonateContent({
    Key? key,
    required this.items,
    required this.getCategoryColor,
    required this.onItemSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What can you donate?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select items you wish to donate. DRRMO will arrange pickup within 24 hours.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            final color = getCategoryColor(item.category);
            return Column(
              children: [
                DonateItemCard(
                  item: item,
                  color: color,
                  onTap: () => onItemSelect(item.id),
                ),
                const SizedBox(height: 6),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class DonateItemCard extends StatelessWidget {
  final ResourceItem item;
  final Color color;
  final VoidCallback onTap;

  const DonateItemCard({
    Key? key,
    required this.item,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 12, color: color),
                        const SizedBox(width: 2),
                        Text(
                          'NEEDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, size: 20, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Pickup within 24hrs',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DONATE',
                          style: TextStyle(
                            fontSize: 12,
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
        ),
      ),
    );
  }
}

class RequestContent extends StatelessWidget {
  final List<ResourceItem> items;
  final Color Function(String) getCategoryColor;
  final Function(String) onItemSelect;

  const RequestContent({
    Key? key,
    required this.items,
    required this.getCategoryColor,
    required this.onItemSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Emergency Resources',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Available resources for emergency situations. Select an item to request.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            final color = getCategoryColor(item.category);
            return Column(
              children: [
                RequestItemCard(
                  item: item,
                  color: color,
                  onTap: () => onItemSelect(item.id),
                ),
                const SizedBox(height: 6),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class RequestItemCard extends StatelessWidget {
  final ResourceItem item;
  final Color color;
  final VoidCallback onTap;

  const RequestItemCard({
    Key? key,
    required this.item,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.estimatedDelivery ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'REQUEST',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyRequestsContent extends StatelessWidget {
  final List<MyRequest> requests;
  final List<ResourceItem> donatableItems;
  final List<ResourceItem> requestableItems;
  final Color Function(String) getDonateCategoryColor;
  final Color Function(String) getRequestCategoryColor;
  final Function(String) onCancelRequest;
  final Function(String, String) onShowAlert;

  const MyRequestsContent({
    Key? key,
    required this.requests,
    required this.donatableItems,
    required this.requestableItems,
    required this.getDonateCategoryColor,
    required this.getRequestCategoryColor,
    required this.onCancelRequest,
    required this.onShowAlert,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Donations & Requests',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You have ${requests.length} item${requests.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 24),
        if (requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.inventory,
                  size: 64,
                  color: const Color(0xFF9CA3AF).withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No items yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start by donating or requesting resources above',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          )
        else
          Column(
            children: requests.map((request) {
              return Column(
                children: [
                  MyRequestCard(
                    request: request,
                    donatableItems: donatableItems,
                    requestableItems: requestableItems,
                    getDonateCategoryColor: getDonateCategoryColor,
                    getRequestCategoryColor: getRequestCategoryColor,
                    onCancel: () => onCancelRequest(request.id),
                    onTrack: () => onShowAlert(
                      'Track',
                      request.type == 'donation'
                          ? 'Pickup tracking feature coming soon!'
                          : 'Delivery tracking feature coming soon!',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
}

class MyRequestCard extends StatelessWidget {
  final MyRequest request;
  final List<ResourceItem> donatableItems;
  final List<ResourceItem> requestableItems;
  final Color Function(String) getDonateCategoryColor;
  final Color Function(String) getRequestCategoryColor;
  final VoidCallback onCancel;
  final VoidCallback onTrack;

  const MyRequestCard({
    Key? key,
    required this.request,
    required this.donatableItems,
    required this.requestableItems,
    required this.getDonateCategoryColor,
    required this.getRequestCategoryColor,
    required this.onCancel,
    required this.onTrack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final resource = request.type == 'donation'
        ? donatableItems.firstWhere(
            (r) => r.id == request.resourceId,
            orElse: () => donatableItems[0],
          )
        : requestableItems.firstWhere(
            (r) => r.id == request.resourceId,
            orElse: () => requestableItems[0],
          );

    final color = request.type == 'donation'
        ? getDonateCategoryColor(resource.category)
        : getRequestCategoryColor(resource.category);

    Color statusColor;
    switch (request.status) {
      case 'delivered':
        statusColor = const Color(0xFF10B981);
        break;
      case 'processing':
        statusColor = const Color(0xFFDC2626);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              request.type == 'donation'
                                  ? Icons.favorite
                                  : Icons.inventory,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              request.type == 'donation'
                                  ? 'DONATION'
                                  : 'REQUEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resource.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${request.quantity} ${resource.unit ?? 'item'}${request.quantity > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              request.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (request.urgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'ID:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        request.id.substring(request.id.length - 6),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Date:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        request.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${request.type == 'donation' ? 'Pickup:' : 'Delivery:'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        request.type == 'donation'
                            ? 'Within 24 hours'
                            : resource.estimatedDelivery ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (request.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.notes,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1F2937),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTrack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.location_on, size: 16),
                    label: Text(
                      request.type == 'donation'
                          ? 'Track Pickup'
                          : 'Track Delivery',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: BorderSide(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResourceModal extends StatelessWidget {
  final ResourceItem? resource;
  final String activeTab;
  final String quantity;
  final bool urgent;
  final String notes;
  final Color Function(String) getCategoryColor;
  final String Function(String) getCategoryName;
  final VoidCallback onClose;
  final Function(String) onQuantityChanged;
  final Function(bool) onUrgentChanged;
  final Function(String) onNotesChanged;
  final VoidCallback onSubmit;
  final VoidCallback onContactSupport;

  const ResourceModal({
    Key? key,
    required this.resource,
    required this.activeTab,
    required this.quantity,
    required this.urgent,
    required this.notes,
    required this.getCategoryColor,
    required this.getCategoryName,
    required this.onClose,
    required this.onQuantityChanged,
    required this.onUrgentChanged,
    required this.onNotesChanged,
    required this.onSubmit,
    required this.onContactSupport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (resource == null) return Container();

    final color = getCategoryColor(resource!.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${activeTab == 'donate' ? 'Donate' : 'Request'} ${resource!.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        size: 24,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              resource!.icon,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resource!.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  getCategoryName(resource!.category),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  resource!.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  activeTab == 'donate'
                                      ? '🕐 Pickup within 24 hours'
                                      : '📦 Estimated delivery: ${resource!.estimatedDelivery}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quantity *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              final qty = int.tryParse(quantity) ?? 1;
                              if (qty > 1) {
                                onQuantityChanged((qty - 1).toString());
                              }
                            },
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: quantity)
                                ..selection = TextSelection.collapsed(
                                  offset: quantity.length,
                                ),
                              onChanged: (text) {
                                final num = int.tryParse(text);
                                if (num != null && num >= 1 && num <= 50) {
                                  onQuantityChanged(text);
                                } else if (text.isEmpty) {
                                  onQuantityChanged('1');
                                }
                              },
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: color,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final qty = int.tryParse(quantity) ?? 1;
                              if (qty < 50) {
                                onQuantityChanged((qty + 1).toString());
                              }
                            },
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                            value: urgent,
                            onChanged: (value) =>
                                onUrgentChanged(value ?? false),
                            activeColor: color,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Urgent',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  activeTab == 'donate'
                                      ? 'This donation needs immediate pickup'
                                      : 'This is an urgent emergency need',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Add any special instructions or details...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color, width: 2),
                          ),
                        ),
                        onChanged: onNotesChanged,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  size: 20,
                                  color: Color(0xFF3B82F6),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Contact Information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activeTab == 'donate'
                                  ? 'DRRMO will contact you using your profile information for pickup arrangements.'
                                  : 'DRRMO will deliver to the address in your profile. Please ensure your information is up to date.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: onContactSupport,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Need help? Contact DRRMO Support',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            activeTab == 'donate'
                                ? 'SUBMIT DONATION'
                                : 'SUBMIT REQUEST',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
