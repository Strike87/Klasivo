import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain model for a Klasivo campus (physical location within an organization).
///
/// Multi-campus schools use this to represent distinct physical sites,
/// each with its own address, head, and student/teacher counts.
class CampusModel {
  final String id;
  final String organizationId;
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final bool isActive;
  final bool isMain;
  final String? headId; // userId of campus head
  final int? studentCount;
  final int? teacherCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CampusModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.isActive = true,
    this.isMain = false,
    this.headId,
    this.studentCount,
    this.teacherCount,
    this.createdAt,
    this.updatedAt,
  });

  /// Construct from a Firestore document snapshot.
  factory CampusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CampusModel(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String?,
      city: data['city'] as String?,
      country: data['country'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isMain: data['isMain'] as bool? ?? false,
      headId: data['headId'] as String?,
      studentCount: data['studentCount'] as int?,
      teacherCount: data['teacherCount'] as int?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Construct from a raw map (e.g. from QuerySnapshot doc.data()).
  factory CampusModel.fromMap(Map<String, dynamic> data, String id) {
    return CampusModel(
      id: id,
      organizationId: data['organizationId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      address: data['address'] as String?,
      city: data['city'] as String?,
      country: data['country'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isMain: data['isMain'] as bool? ?? false,
      headId: data['headId'] as String?,
      studentCount: data['studentCount'] as int?,
      teacherCount: data['teacherCount'] as int?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      'isActive': isActive,
      'isMain': isMain,
      if (headId != null) 'headId': headId,
      if (studentCount != null) 'studentCount': studentCount,
      if (teacherCount != null) 'teacherCount': teacherCount,
    };
  }

  /// Create a copy with optional field overrides.
  CampusModel copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool? isActive,
    bool? isMain,
    String? headId,
    int? studentCount,
    int? teacherCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampusModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      isMain: isMain ?? this.isMain,
      headId: headId ?? this.headId,
      studentCount: studentCount ?? this.studentCount,
      teacherCount: teacherCount ?? this.teacherCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convenience: returns a display-friendly location string.
  String get locationText {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.isEmpty ? 'No location set' : parts.join(', ');
  }
}
