/// Klasivo v2.0 - Enhanced organization model
/// 
/// Represents an educational organization (school, university)
/// with enhanced multi-tenant support, campus hierarchy,
/// and configuration management.
library;

import "base_model.dart";

/// Organization model for multi-tenant educational institutions.
class OrganizationModel extends BaseModel {
  final String name;
  final String? description;
  final String type;
  final String? logoUrl;
  final bool isActive;
  final String country;
  final String? timezone;
  final Map<String, dynamic> settings;
  final int campusCount;
  final int userCount;

  const OrganizationModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required super.orgId,
    required super.tenantId,
    required this.name,
    this.description,
    this.type = "school",
    this.logoUrl,
    this.isActive = true,
    this.country = "SA",
    this.timezone,
    this.settings = const {},
    this.campusCount = 0,
    this.userCount = 0,
  });

  @override
  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "description": description,
        "type": type,
        "logoUrl": logoUrl,
        "isActive": isActive,
        "country": country,
        "timezone": timezone,
        "settings": settings,
        "campusCount": campusCount,
        "userCount": userCount,
        "orgId": orgId,
        "tenantId": tenantId,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
      };

  @override
  OrganizationModel copyWith({DateTime? updatedAt}) => OrganizationModel(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        orgId: orgId,
        tenantId: tenantId,
        name: name,
        description: description,
        type: type,
        logoUrl: logoUrl,
        isActive: isActive,
        country: country,
        timezone: timezone,
        settings: settings,
        campusCount: campusCount,
        userCount: userCount,
      );
}
