import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/app_constants.dart';
import '../core/services/academic_year_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final academicYearServiceProvider = Provider<AcademicYearService>((ref) => AcademicYearService());

// ─── Data Model ────────────────────────────────────────────────────────────

class AcademicYearData {
  final String id;
  final String organizationId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final bool isArchived;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AcademicYearData({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
    this.isArchived = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory AcademicYearData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AcademicYearData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isCurrent: data['isCurrent'] ?? false,
      isArchived: data['isArchived'] ?? false,
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'name': name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'isCurrent': isCurrent,
    'isArchived': isArchived,
    'createdBy': createdBy,
  };

  /// Display label: "2026/2027" style
  String get label => name;

  /// Date range display
  String get dateRange {
    final s = startDate;
    final e = endDate;
    return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
  }

  /// Whether this year is currently active (between start and end)
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Duration in days
  int get durationInDays => endDate.difference(startDate).inDays;
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final academicYearsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(academicYearServiceProvider).getAcademicYearsStream(orgId);
});

// ─── Derived Providers ─────────────────────────────────────────────────────

final academicYearsProvider = Provider<List<AcademicYearData>>((ref) {
  final asyncYears = ref.watch(academicYearsStreamProvider);
  return asyncYears.when(
    data: (snapshot) => snapshot.docs.map((doc) => AcademicYearData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Academic years provider error: $e'); return []; },
  );
});

final currentAcademicYearProvider = Provider<AcademicYearData?>((ref) {
  final years = ref.watch(academicYearsProvider);
  try {
    return years.firstWhere((y) => y.isCurrent);
  } catch (_) {
    return null;
  }
});

final activeAcademicYearsProvider = Provider<List<AcademicYearData>>((ref) {
  final years = ref.watch(academicYearsProvider);
  return years.where((y) => !y.isArchived).toList();
});

final archivedAcademicYearsProvider = Provider<List<AcademicYearData>>((ref) {
  final years = ref.watch(academicYearsProvider);
  return years.where((y) => y.isArchived).toList();
});
