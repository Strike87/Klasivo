import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_constants.dart';
import '../core/services/unit_service.dart';
import '../core/services/firebase_service.dart';
import 'auth_provider.dart';

// ─── Unit Service Provider ────────────────────────────────────────────────────

final unitServiceProvider = Provider<UnitService>((ref) => UnitService());

// ─── Unit Data Model ──────────────────────────────────────────────────────────

class UnitData {
  final String id;
  final String organizationId;
  final String subjectId;
  final String classId;
  final String? stageId;
  final String title;
  final String? description;
  final int order;
  final String? createdBy;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UnitData({
    required this.id,
    required this.organizationId,
    required this.subjectId,
    required this.classId,
    this.stageId,
    required this.title,
    this.description,
    this.order = 0,
    this.createdBy,
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory UnitData.fromMap(String id, Map<String, dynamic> data) {
    return UnitData(
      id: id,
      organizationId: data['organizationId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      stageId: data['stageId'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      order: data['order'] as int? ?? 0,
      createdBy: data['createdBy'] as String?,
      isArchived: data['isArchived'] as bool? ?? false,
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      archivedBy: data['archivedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  UnitData copyWith({
    String? title,
    String? description,
    int? order,
    bool? isArchived,
  }) {
    return UnitData(
      id: id,
      organizationId: organizationId,
      subjectId: subjectId,
      classId: classId,
      stageId: stageId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      createdBy: createdBy,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt,
      archivedBy: archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// ─── Unit Stream Providers ────────────────────────────────────────────────────

/// Units by subject (for LMS content browser)
final unitsBySubjectProvider = StreamProvider.family<List<UnitData>, String>((ref, subjectId) {
  final service = ref.watch(unitServiceProvider);
  return service.getUnitsBySubjectStream(subjectId).map((snapshot) =>
      snapshot.docs.map((doc) =>
          UnitData.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
});

/// Units by class
final unitsByClassProvider = StreamProvider.family<List<UnitData>, String>((ref, classId) {
  final service = ref.watch(unitServiceProvider);
  return service.getUnitsByClassStream(classId).map((snapshot) =>
      snapshot.docs.map((doc) =>
          UnitData.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
});

/// All units for an organization
final unitsByOrgProvider = StreamProvider.family<List<UnitData>, String>((ref, orgId) {
  final service = ref.watch(unitServiceProvider);
  return service.getUnitsByOrganizationStream(orgId).map((snapshot) =>
      snapshot.docs.map((doc) =>
          UnitData.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
});

/// Units list (non-stream) for current org
final unitsProvider = AsyncNotifierProvider<UnitsNotifier, List<UnitData>>(UnitsNotifier.new);

class UnitsNotifier extends AsyncNotifier<List<UnitData>> {
  @override
  Future<List<UnitData>> build() async {
    final orgId = ref.watch(organizationIdProvider);
    if (orgId == null) return [];
    final service = ref.watch(unitServiceProvider);
    final snapshot = await _firestore
        .collection(AppConstants.unitsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) =>
        UnitData.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
}
