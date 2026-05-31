import 'package:e_telly_app/constants.dart';
import 'package:flutter/material.dart';

class ResourceItem {
  final String id;
  final String name;
  final String category;
  final String? description;
  final IconData icon;
  final bool available;
  final String? estimatedDelivery;
  final String? unit;

  ResourceItem({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.icon,
    required this.available,
    this.estimatedDelivery,
    this.unit,
  });
}

class RequestContent extends StatelessWidget {
  final List<ResourceItem> items;
  final Color Function(String) getCategoryColor;
  final Function(String) onItemSelect;

  const RequestContent({
    super.key,
    required this.items,
    required this.getCategoryColor,
    required this.onItemSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Resources',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select what you need and your neighbors can offer to help.',
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
    super.key,
    required this.item,
    required this.color,
    required this.onTap,
  });

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
                            item.description ?? '',
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
  final Widget? customContent;

  const ResourceModal({
    super.key,
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
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    if (resource == null && customContent == null) return Container();

    final color = resource != null ? getCategoryColor(resource!.category) : ET_RED;

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
              // Header
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
                      customContent != null && resource == null
                          ? (activeTab == 'donate' ? 'Donation Form' : 'Request Form')
                          : '${activeTab == 'donate' ? 'Donate' : 'Request'} ${resource?.name ?? ''}',
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
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: customContent ?? _buildDefaultContent(color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultContent(Color color) {
    return Column(
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
                    resource!.description ?? '',
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
                        : '📦 Estimated delivery: ${resource?.estimatedDelivery ?? "N/A"}',
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
              onChanged: (value) => onUrgentChanged(value ?? false),
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
            hintText: 'Add any special instructions or details...',
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
                    ? 'Your neighbors will coordinate pickup with you using your profile information.'
                    : 'Neighbors who offer to help will coordinate delivery with you directly.',
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
                  'Need help? Contact support',
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
    );
  }
}