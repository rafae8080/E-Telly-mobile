import 'package:flutter/material.dart';
import 'dart:io';
import '../screens/profile_screen.dart';

class ProfileHeader extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onAction;

  const ProfileHeader({
    Key? key,
    required this.isEditing,
    required this.onBack,
    required this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 24,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage your account',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onAction,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Icon(
                isEditing ? Icons.check : Icons.edit,
                size: 24,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePhotoSection extends StatelessWidget {
  final bool isEditing;
  final bool isUploading;
  final String? profileImage;
  final UserProfile profile;
  final TextEditingController nameController;
  final Function(String) onEditedNameChanged;
  final VoidCallback? onTap;

  const ProfilePhotoSection({
    Key? key,
    required this.isEditing,
    required this.isUploading,
    required this.profileImage,
    required this.profile,
    required this.nameController,
    required this.onEditedNameChanged,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              if (isUploading)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xFFDC2626),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFDC2626)),
                  ),
                )
              else if (profileImage != null)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xFFDC2626),
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: FileImage(File(profileImage!)),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: const Color(0xFFDC2626),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      profile.fullName
                              ?.split(' ')
                              .map((n) => n[0])
                              .join('')
                              .toUpperCase() ??
                          'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isEditing)
          SizedBox(
            width: 200,
            child: TextField(
              controller: nameController,
              onChanged: onEditedNameChanged,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          )
        else
          Text(
            profile.fullName ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          profile.email ?? '',
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 4),
        Text(
          profile.role == 'lgu_admin' ? 'LGU Admin' : 'Resident',
          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
        ),
      ],
    );
  }
}

class PersonalInfoSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController phoneController;
  final Function(String) onPhoneChanged;

  const PersonalInfoSection({
    Key? key,
    required this.isEditing,
    required this.profile,
    required this.phoneController,
    required this.onPhoneChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: InfoItem(
              label: 'Phone Number',
              value: profile.phoneNumber,
              onChanged: onPhoneChanged,
              keyboardType: TextInputType.phone,
              controller: phoneController,
              isEditing: isEditing,
            ),
          ),
        ],
      ),
    );
  }
}

class AddressSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController regionController;
  final TextEditingController provinceController;
  final TextEditingController cityController;
  final TextEditingController barangayController;
  final TextEditingController postalCodeController;
  final TextEditingController streetAddressController;
  final Function(String) onRegionChanged;
  final Function(String) onProvinceChanged;
  final Function(String) onCityChanged;
  final Function(String) onBarangayChanged;
  final Function(String) onPostalCodeChanged;
  final Function(String) onStreetAddressChanged;
  final VoidCallback onCurrentLocation;

  const AddressSection({
    Key? key,
    required this.isEditing,
    required this.profile,
    required this.regionController,
    required this.provinceController,
    required this.cityController,
    required this.barangayController,
    required this.postalCodeController,
    required this.streetAddressController,
    required this.onRegionChanged,
    required this.onProvinceChanged,
    required this.onCityChanged,
    required this.onBarangayChanged,
    required this.onPostalCodeChanged,
    required this.onStreetAddressChanged,
    required this.onCurrentLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 20,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              if (isEditing)
                OutlinedButton.icon(
                  onPressed: onCurrentLocation,
                  icon: const Icon(
                    Icons.navigation,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Use Current Location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color(0xFFDC2626).withOpacity(0.2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                InfoItem(
                  label: 'Region',
                  value: profile.region,
                  onChanged: onRegionChanged,
                  controller: regionController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Province',
                  value: profile.province,
                  onChanged: onProvinceChanged,
                  controller: provinceController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'City',
                  value: profile.city,
                  onChanged: onCityChanged,
                  controller: cityController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Barangay',
                  value: profile.barangay,
                  onChanged: onBarangayChanged,
                  controller: barangayController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Postal Code',
                  value: profile.postalCode,
                  onChanged: onPostalCodeChanged,
                  keyboardType: TextInputType.number,
                  controller: postalCodeController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Street Address',
                  value: profile.streetAddress,
                  onChanged: onStreetAddressChanged,
                  multiline: true,
                  controller: streetAddressController,
                  isEditing: isEditing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmergencyContactSection extends StatelessWidget {
  final bool isEditing;
  final UserProfile profile;
  final TextEditingController emergencyNameController;
  final TextEditingController emergencyPhoneController;
  final TextEditingController emergencyRelationshipController;
  final Function(String) onEmergencyNameChanged;
  final Function(String) onEmergencyPhoneChanged;
  final Function(String) onEmergencyRelationshipChanged;
  final VoidCallback onInfoPressed;

  const EmergencyContactSection({
    Key? key,
    required this.isEditing,
    required this.profile,
    required this.emergencyNameController,
    required this.emergencyPhoneController,
    required this.emergencyRelationshipController,
    required this.onEmergencyNameChanged,
    required this.onEmergencyPhoneChanged,
    required this.onEmergencyRelationshipChanged,
    required this.onInfoPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medical_services,
                    size: 20,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Emergency Contact',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onInfoPressed,
                icon: const Icon(
                  Icons.info,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                InfoItem(
                  label: 'Name',
                  value: profile.emergencyContactName,
                  onChanged: onEmergencyNameChanged,
                  controller: emergencyNameController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Phone',
                  value: profile.emergencyContactPhone,
                  onChanged: onEmergencyPhoneChanged,
                  keyboardType: TextInputType.phone,
                  controller: emergencyPhoneController,
                  isEditing: isEditing,
                ),
                InfoItem(
                  label: 'Relationship',
                  value: profile.emergencyContactRelationship,
                  onChanged: onEmergencyRelationshipChanged,
                  controller: emergencyRelationshipController,
                  isEditing: isEditing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoItem extends StatelessWidget {
  final String label;
  final String? value;
  final Function(String) onChanged;
  final bool multiline;
  final TextInputType? keyboardType;
  final TextEditingController controller;
  final bool isEditing;

  const InfoItem({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.multiline = false,
    this.keyboardType,
    required this.controller,
    required this.isEditing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          if (isEditing)
            TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: multiline ? 3 : 1,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Enter ${label.toLowerCase()}',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value?.isNotEmpty == true ? value! : 'Not provided',
                      style: TextStyle(
                        fontSize: 15,
                        color: value?.isNotEmpty == true
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ActionButtons extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onCancel;
  final VoidCallback onLogout;

  const ActionButtons({
    Key? key,
    required this.isEditing,
    required this.onCancel,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isEditing)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF1F2937)),
              label: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 20, color: Color(0xFFDC2626)),
            label: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: const Color(0xFFDC2626).withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }
}

class EmergencyModal extends StatelessWidget {
  final VoidCallback onClose;

  const EmergencyModal({Key? key, required this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, size: 24, color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your emergency contact information will be shared with responders when you report an emergency. Ensure this information is accurate and up-to-date.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning, size: 20, color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure your emergency contact is aware that they are listed as your emergency contact.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('Close'))],
    );
  }
}
