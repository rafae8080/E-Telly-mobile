class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? region;
  final String? province;
  final String? city;
  final String? barangay;
  final String? postalCode;
  final String? streetAddress;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelationship;
  final String? profilePhoto;
  final String? authProvider;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.region,
    this.province,
    this.city,
    this.barangay,
    this.postalCode,
    this.streetAddress,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelationship,
    this.profilePhoto,
    this.authProvider,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['name'] ?? json['fullName'] ?? '',
      role: json['role'] ?? 'user',
      phoneNumber: json['phoneNumber'] ?? '',
      region: json['region'] ?? '',
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      barangay: json['barangay'] ?? '',
      postalCode: json['postalCode'] ?? '',
      streetAddress: json['streetAddress'] ?? json['streetDetails'] ?? '',
      emergencyContactName: json['emergencyContactName'] ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] ?? '',
      emergencyContactRelationship: json['emergencyContactRelationship'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
      authProvider: json['authProvider'] ?? 'email',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': fullName,
      'role': role,
      'phoneNumber': phoneNumber ?? '',
      'region': region ?? '',
      'province': province ?? '',
      'city': city ?? '',
      'barangay': barangay ?? '',
      'postalCode': postalCode ?? '',
      'streetAddress': streetAddress ?? '',
      'emergencyContactName': emergencyContactName ?? '',
      'emergencyContactPhone': emergencyContactPhone ?? '',
      'emergencyContactRelationship': emergencyContactRelationship ?? '',
      'profilePhoto': profilePhoto ?? '',
      'authProvider': authProvider ?? 'email',
    };
  }
}