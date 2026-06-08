import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/config/theme.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/subject_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_components.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE SCREEN — Klasivo v1.7 "Take Attendance"
// ═══════════════════════════════════════════════════════════════════════════════

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  /// Local map of studentId → status before batch save.
  Map<String, String> _studentStatuses = {};

  /// Whether we are currently saving.
  bool _isSaving = false;

  /// Track if statuses have been initialized from existing records.
  bool _initializedFromSnapshot = false;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Reset the class/subject when entering the screen fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceClassIdProvider.notifier).state = null;
      ref.read(attendanceSubjectIdProvider.notifier).state = null;
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Parse the selected date string into a DateTime.
  DateTime get _selectedDate {
    final dateStr = ref.read(selectedAttendanceDateProvider);
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  /// Format a DateTime as 'yyyy-MM-dd'.
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Compute present/absent/late counts from the local status map.
  int get _presentCount => _studentStatuses.values
      .where((s) => s == AppConstants.attendanceStatusPresent)
      .length;
  int get _absentCount => _studentStatuses.values
      .where((s) => s == AppConstants.attendanceStatusAbsent)
      .length;
  int get _lateCount => _studentStatuses.values
      .where((s) => s == AppConstants.attendanceStatusLate)
      .length;
  int get _excusedCount => _studentStatuses.values
      .where((s) => s == AppConstants.attendanceStatusExcused)
      .length;

  /// Whether at least one student has a status assigned.
  bool get _hasAnyStatus => _studentStatuses.values.isNotEmpty;

  // ─── Date Picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: KlasivoColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formatted = _formatDate(picked);
      ref.read(selectedAttendanceDateProvider.notifier).state = formatted;
      _initializedFromSnapshot = false;
      _studentStatuses = {};
      setState(() {});
    }
  }

  // ─── Save Attendance ───────────────────────────────────────────────────────

  Future<void> _saveAttendance() async {
    if (_studentStatuses.isEmpty) {
      showSnackBar(context, message: 'No attendance to save', isError: true);
      return;
    }

    final classId = ref.read(attendanceClassIdProvider);
    final orgId = ref.read(currentOrganizationIdProvider);
    final date = ref.read(selectedAttendanceDateProvider);
    final subjectId = ref.read(attendanceSubjectIdProvider);
    final markedBy = ref.read(currentUserIdProvider);

    if (classId == null || orgId == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(attendanceServiceProvider).markBatchAttendance(
            organizationId: orgId,
            classId: classId,
            date: date,
            studentStatuses: _studentStatuses,
            subjectId: subjectId,
            markedBy: markedBy,
          );

      if (mounted) {
        showSnackBar(context, message: 'Attendance saved successfully');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          message: 'Failed to save attendance: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ─── Mark All Present ──────────────────────────────────────────────────────

  void _markAllPresent(List<StudentData> students) {
    setState(() {
      for (final student in students) {
        _studentStatuses[student.id] = AppConstants.attendanceStatusPresent;
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);
    final selectedClassId = ref.watch(attendanceClassIdProvider);
    final selectedSubjectId = ref.watch(attendanceSubjectIdProvider);
    final selectedDate = ref.watch(selectedAttendanceDateProvider);

    // Watch students for the selected class
    final students = selectedClassId != null
        ? ref.watch(studentsByClassListProvider(selectedClassId))
        : <StudentData>[];

    // Watch subjects for the selected class
    final subjects = selectedClassId != null
        ? ref.watch(subjectsByClassListProvider(selectedClassId))
        : <SubjectData>[];

    // Watch existing attendance snapshot for the selected class/date
    final attendanceAsync = ref.watch(classAttendanceProvider);

    // Initialize statuses from existing records when snapshot arrives
    attendanceAsync.whenData((snapshot) {
      if (!_initializedFromSnapshot && snapshot.docs.isNotEmpty) {
        final Map<String, String> existing = {};
        for (final doc in snapshot.docs) {
          final data = AttendanceData.fromFirestore(doc);
          existing[data.studentId] = data.status;
        }
        // Merge: keep local changes, fill in from server
        setState(() {
          for (final entry in existing.entries) {
            _studentStatuses.putIfAbsent(entry.key, () => entry.value);
          }
        });
        _initializedFromSnapshot = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── Top Controls Section ─────────────────────────────────────────
          _buildControlsSection(
            context: context,
            isDark: isDark,
            classes: classes,
            selectedClassId: selectedClassId,
            selectedSubjectId: selectedSubjectId,
            selectedDate: selectedDate,
            subjects: subjects,
          ),

          // ─── Summary Stats ────────────────────────────────────────────────
          if (_hasAnyStatus)
            _buildSummaryStats(isDark: isDark, totalStudents: students.length),

          // ─── Mark All Present Action ─────────────────────────────────────
          if (selectedClassId != null && students.isNotEmpty)
            _buildMarkAllPresent(students, isDark),

          // ─── Student List or Empty State ──────────────────────────────────
          Expanded(
            child: _buildStudentListOrEmpty(
              context: context,
              isDark: isDark,
              selectedClassId: selectedClassId,
              students: students,
            ),
          ),
        ],
      ),

      // ─── Bottom Action Bar ───────────────────────────────────────────────
      bottomNavigationBar: selectedClassId != null && students.isNotEmpty
          ? _buildBottomActionBar(isDark: isDark)
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLS SECTION — Class, Date, Subject selectors
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildControlsSection({
    required BuildContext context,
    required bool isDark,
    required List<ClassData> classes,
    required String? selectedClassId,
    required String? selectedSubjectId,
    required String selectedDate,
    required List<SubjectData> subjects,
  }) {
    return Container(
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Class Selector ───────────────────────────────────────────────
          Text(
            'Class',
            style: KlasivoTypography.labelMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xs),
          _buildClassDropdown(isDark, classes, selectedClassId),

          const SizedBox(height: KlasivoSpacing.md),

          // ─── Date Picker Row ──────────────────────────────────────────────
          Text(
            'Date',
            style: KlasivoTypography.labelMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xs),
          _buildDatePickerRow(isDark, selectedDate),

          // ─── Subject Selector (only if class selected and subjects exist)
          if (selectedClassId != null && subjects.isNotEmpty) ...[
            const SizedBox(height: KlasivoSpacing.md),
            Text(
              'Subject (optional)',
              style: KlasivoTypography.labelMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xs),
            _buildSubjectDropdown(isDark, subjects, selectedSubjectId),
          ],
        ],
      ),
    );
  }

  // ─── Class Dropdown ────────────────────────────────────────────────────────

  Widget _buildClassDropdown(
    bool isDark,
    List<ClassData> classes,
    String? selectedClassId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkCard : KlasivoColors.lightBackground,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        border: Border.all(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedClassId,
          isExpanded: true,
          hint: Text(
            'Select a class',
            style: KlasivoTypography.bodyMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          icon: Icon(
            Icons.expand_more,
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
          items: classes.map((cls) {
            return DropdownMenuItem<String>(
              value: cls.id,
              child: Text(
                cls.name,
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            ref.read(attendanceClassIdProvider.notifier).state = value;
            // Reset subject when class changes
            ref.read(attendanceSubjectIdProvider.notifier).state = null;
            // Reset local statuses
            _initializedFromSnapshot = false;
            _studentStatuses = {};
            setState(() {});
          },
        ),
      ),
    );
  }

  // ─── Date Picker Row ───────────────────────────────────────────────────────

  Widget _buildDatePickerRow(bool isDark, String selectedDate) {
    final displayDate = _formatDisplayDate(selectedDate);

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(KlasivoRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.md,
          vertical: KlasivoSpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: isDark ? KlasivoColors.darkCard : KlasivoColors.lightBackground,
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
          border: Border.all(
            color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            Text(
              displayDate,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  /// Format the date string for display (e.g. "Mon, Mar 10, 2026").
  String _formatDisplayDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return DateFormat('EEE, MMM d, y').format(dt);
  }

  // ─── Subject Dropdown ──────────────────────────────────────────────────────

  Widget _buildSubjectDropdown(
    bool isDark,
    List<SubjectData> subjects,
    String? selectedSubjectId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkCard : KlasivoColors.lightBackground,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        border: Border.all(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedSubjectId,
          isExpanded: true,
          hint: Text(
            'All subjects',
            style: KlasivoTypography.bodyMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          icon: Icon(
            Icons.expand_more,
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
          items: [
            // "All subjects" option to clear filter
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All subjects',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextSecondary
                      : KlasivoColors.lightTextSecondary,
                ),
              ),
            ),
            ...subjects.map((subject) {
              return DropdownMenuItem<String?>(
                value: subject.id,
                child: Text(
                  subject.name,
                  style: KlasivoTypography.bodyMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
              );
            }),
          ],
          onChanged: (value) {
            ref.read(attendanceSubjectIdProvider.notifier).state = value;
            _initializedFromSnapshot = false;
            _studentStatuses = {};
            setState(() {});
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY STATS — Present / Absent / Late / Excused pills
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryStats({
    required bool isDark,
    required int totalStudents,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            KlasivoStatPill(
              value: '$_presentCount',
              label: 'Present',
              color: KlasivoColors.secondary,
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            KlasivoStatPill(
              value: '$_absentCount',
              label: 'Absent',
              color: KlasivoColors.error,
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            KlasivoStatPill(
              value: '$_lateCount',
              label: 'Late',
              color: KlasivoColors.accent,
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            KlasivoStatPill(
              value: '$_excusedCount',
              label: 'Excused',
              color: KlasivoColors.primary,
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            KlasivoStatPill(
              value: '${totalStudents - _studentStatuses.length}',
              label: 'Unmarked',
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARK ALL PRESENT — Quick action chip
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMarkAllPresent(List<StudentData> students, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
      child: ActionChip(
        avatar: const Icon(Icons.done_all, size: 16),
        label: const Text('Mark All Present'),
        onPressed: () => _markAllPresent(students),
        backgroundColor: KlasivoColors.secondarySurface,
        side: BorderSide(
          color: KlasivoColors.secondary.withOpacity(0.3),
        ),
        labelStyle: KlasivoTypography.labelMedium.copyWith(
          color: KlasivoColors.secondary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT LIST / EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStudentListOrEmpty({
    required BuildContext context,
    required bool isDark,
    required String? selectedClassId,
    required List<StudentData> students,
  }) {
    // No class selected
    if (selectedClassId == null) {
      return const KlasivoEmptyState(
        icon: Icons.class_outlined,
        title: 'Select a Class',
        subtitle: 'Choose a class above to start taking attendance',
        iconColor: KlasivoColors.primary,
      );
    }

    // Class selected but no students
    if (students.isEmpty) {
      return const KlasivoEmptyState(
        icon: Icons.people_outline,
        title: 'No Students',
        subtitle: 'This class has no students enrolled yet',
        iconColor: KlasivoColors.accent,
      );
    }

    // Student list
    return ListView.separated(
      padding: const EdgeInsets.only(
        left: KlasivoSpacing.lg,
        right: KlasivoSpacing.lg,
        top: KlasivoSpacing.md,
        bottom: 100, // Space for bottom action bar
      ),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: KlasivoSpacing.sm),
      itemBuilder: (context, index) {
        final student = students[index];
        final status = _studentStatuses[student.id];

        return _StudentAttendanceRow(
          student: student,
          currentStatus: status,
          isDark: isDark,
          onStatusChanged: (newStatus) {
            setState(() {
              _studentStatuses[student.id] = newStatus;
            });
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM ACTION BAR — Save Attendance
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomActionBar({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: KlasivoColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  KlasivoColors.primary.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_outlined, size: 20),
                      const SizedBox(width: KlasivoSpacing.sm),
                      Text(
                        'Save Attendance (${_studentStatuses.length})',
                        style: KlasivoTypography.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STUDENT ATTENDANCE ROW — Avatar + Name + Code + 4 Status Buttons
// ═══════════════════════════════════════════════════════════════════════════════

class _StudentAttendanceRow extends StatelessWidget {
  final StudentData student;
  final String? currentStatus;
  final bool isDark;
  final ValueChanged<String> onStatusChanged;

  const _StudentAttendanceRow({
    required this.student,
    required this.currentStatus,
    required this.isDark,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KlasivoSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkCard : KlasivoColors.lightSurface,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        border: Border.all(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // ─── Student Info Row ───────────────────────────────────────────
          Row(
            children: [
              // Avatar circle with initial
              _buildAvatar(),
              const SizedBox(width: KlasivoSpacing.md),
              // Name + Code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: KlasivoTypography.titleMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (student.studentCode.isNotEmpty) ...[
                      const SizedBox(height: KlasivoSpacing.xs / 2),
                      Text(
                        student.studentCode,
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: KlasivoSpacing.sm),

          // ─── Attendance Status Buttons ──────────────────────────────────
          Row(
            children: [
              // Present (green)
              Expanded(
                child: KlasivoAttendanceButton(
                  label: 'Present',
                  icon: Icons.check_circle_outline,
                  color: KlasivoColors.secondary,
                  isSelected:
                      currentStatus == AppConstants.attendanceStatusPresent,
                  onTap: () => onStatusChanged(
                      AppConstants.attendanceStatusPresent),
                ),
              ),
              const SizedBox(width: KlasivoSpacing.xs),
              // Absent (red)
              Expanded(
                child: KlasivoAttendanceButton(
                  label: 'Absent',
                  icon: Icons.cancel_outlined,
                  color: KlasivoColors.error,
                  isSelected:
                      currentStatus == AppConstants.attendanceStatusAbsent,
                  onTap: () => onStatusChanged(
                      AppConstants.attendanceStatusAbsent),
                ),
              ),
              const SizedBox(width: KlasivoSpacing.xs),
              // Late (amber)
              Expanded(
                child: KlasivoAttendanceButton(
                  label: 'Late',
                  icon: Icons.access_time,
                  color: KlasivoColors.accent,
                  isSelected:
                      currentStatus == AppConstants.attendanceStatusLate,
                  onTap: () =>
                      onStatusChanged(AppConstants.attendanceStatusLate),
                ),
              ),
              const SizedBox(width: KlasivoSpacing.xs),
              // Excused (purple / primary indigo)
              Expanded(
                child: KlasivoAttendanceButton(
                  label: 'Excused',
                  icon: Icons.verified_outlined,
                  color: KlasivoColors.primary,
                  isSelected:
                      currentStatus == AppConstants.attendanceStatusExcused,
                  onTap: () => onStatusChanged(
                      AppConstants.attendanceStatusExcused),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    final initial = student.fullName.isNotEmpty
        ? student.fullName.trim().characters.first.toUpperCase()
        : '?';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: KlasivoColors.primarySurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: KlasivoColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: KlasivoTypography.titleMedium.copyWith(
          color: KlasivoColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
