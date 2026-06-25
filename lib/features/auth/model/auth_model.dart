class LaundryTenant {
  final String id;
  final String name;
  final bool isActive;
  final String email;
  final String laundryCode;

  LaundryTenant({
    required this.id,
    required this.name,
    required this.isActive,
    required this.email,
    required this.laundryCode,
  });

  factory LaundryTenant.fromMap(String id, Map<String, dynamic> map) {
    return LaundryTenant(
      id: id,
      name: map['laundryName'] ?? 'مغسلة سجاد',
      isActive: map['isActive'] ?? false,
      email: map['email'] ?? '',
      laundryCode: map['laundryCode'] ?? 'أ',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'laundryName': name,
      'isActive': isActive,
      'email': email,
      'laundryCode': laundryCode,
    };
  }
}
