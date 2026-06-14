/// Domain model for a Klasivo organization (school).
class OrganizationModel {
  final String id;
  final String name;
  final String slug;
  final String ownerId;
  final String? logoUrl;
  final String? website;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    this.logoUrl,
    this.website,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrganizationModel(
      id: id,
      name: data['name'] as String? ?? '',
      slug: data['slug'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      logoUrl: data['logoUrl'] as String?,
      website: data['website'] as String?,
      description: data['description'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime?
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'ownerId': ownerId,
      'logoUrl': logoUrl,
      'website': website,
      'description': description,
      'isActive': isActive,
    };
  }
}
