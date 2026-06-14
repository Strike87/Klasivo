/// Klasivo v2.0 - Campus model
/// 
/// Represents a campus within an organization.
/// Organizations can have multiple campuses, each with
/// its own classes, teachers, and students.
library;

import "base_model.dart";

/// Campus model for organization campus hierarchy.
class CampusModel extends BaseModel {
  final String name;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final String organizationId;
  final Map<String, dynamic> settings;
  final int classCount;
  final int studentCount;
  final int teacherCount;

  const CampusModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required super.orgId,
    required super.tenantId,
    required this.name,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.isActive = true,
    required this.organizationId,
    this.settings = const {},
    this.classCount = 0,
    this.studentCount = 0,
    this.teacherCount = 0,
  });

  @override
  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "address": address,
        "city": city,
        "latitude": latitude,
        "longitude": longitude,
        "isActive": isActive,
        "organizationId": organizationId,
        "settings": settings,
        "classCount": classCount,
        "studentCount": studentCount,
        "teacherCount": teacherCount,
        "orgId": orgId,
        "tenantId": tenantId,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
      };

  @override
  CampusModel copyWith({DateTime? updatedAt}) => CampusModel(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        orgId: orgId,
        tenantId: tenantId,
        name: name,
        address: address,
        city: city,
        latitude: latitude,
        longitude: longitude,
        isActive: isActive,
        organizationId: organizationId,
        settings: settings,
        classCount: classCount,
        studentCount: studentCount,
        teacherCount: teacherCount,
      );
}
