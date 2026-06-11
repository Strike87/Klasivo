import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';
import 'package:klasivo/core/tokens/app_colors.dart';

void main() {
  // ─── AppConstants ──────────────────────────────────────────────────────────

  group('AppConstants', () {
    test('role constants are consistent', () {
      expect(AppConstants.roleOwner, equals('owner'));
      expect(AppConstants.roleAdmin, equals('admin'));
      expect(AppConstants.roleTeacher, equals('teacher'));
      expect(AppConstants.roleStudent, equals('student'));
      expect(AppConstants.roleParent, equals('parent'));
    });

    test('all role constants are unique', () {
      final roles = {
        AppConstants.roleOwner,
        AppConstants.roleAdmin,
        AppConstants.roleTeacher,
        AppConstants.roleStudent,
        AppConstants.roleParent,
        AppConstants.roleCampusManager,
        AppConstants.roleObserver,
        AppConstants.roleSuperAdmin,
      };
      expect(roles.length, equals(8));
    });

    test('status constants follow expected values', () {
      expect(AppConstants.statusDraft, equals('draft'));
      expect(AppConstants.statusPublished, equals('published'));
      expect(AppConstants.statusActive, equals('active'));
      expect(AppConstants.statusCompleted, equals('completed'));
    });

    test('question type constants are distinct', () {
      final types = {
        AppConstants.questionTypeMultipleChoice,
        AppConstants.questionTypeTrueFalse,
        AppConstants.questionTypeShortAnswer,
      };
      expect(types.length, equals(3));
    });

    test('submission status constants are distinct', () {
      final statuses = {
        AppConstants.submissionStatusStarted,
        AppConstants.submissionStatusSubmitted,
        AppConstants.submissionStatusFlagged,
      };
      expect(statuses.length, equals(3));
    });

    test('violation threshold is 3', () {
      expect(AppConstants.violationThreshold, equals(3));
    });

    test('default student password is 123456', () {
      expect(AppConstants.defaultStudentPassword, equals('123456'));
    });

    test('auto save interval is 5 seconds', () {
      expect(AppConstants.autoSaveInterval, equals(5));
    });

    test('collection names are lowercase and use underscores', () {
      final collections = [
        AppConstants.organizationsCollection,
        AppConstants.usersCollection,
        AppConstants.examsCollection,
        AppConstants.questionsCollection,
        AppConstants.submissionsCollection,
        AppConstants.answersCollection,
      ];
      for (final name in collections) {
        expect(name, equals(name.toLowerCase()));
        expect(name, isNot(contains(' ')));
      }
    });

    test('navigation tab indices are sequential starting from 0', () {
      expect(AppConstants.tabDashboard, equals(0));
      expect(AppConstants.tabAcademic, equals(1));
      expect(AppConstants.tabPeople, equals(2));
      expect(AppConstants.tabInbox, equals(3));
      expect(AppConstants.tabSettings, equals(4));
    });
  });

  // ─── AppColors Helpers ─────────────────────────────────────────────────────

  group('AppColors Helpers', () {
    test('resolve returns light color for light brightness', () {
      final result = AppColors.resolve(
        brightness: Brightness.light,
        light: AppColors.lightTextPrimary,
        dark: AppColors.darkTextPrimary,
      );
      expect(result, equals(AppColors.lightTextPrimary));
    });

    test('resolve returns dark color for dark brightness', () {
      final result = AppColors.resolve(
        brightness: Brightness.dark,
        light: AppColors.lightTextPrimary,
        dark: AppColors.darkTextPrimary,
      );
      expect(result, equals(AppColors.darkTextPrimary));
    });

    test('textPrimary returns correct color for brightness', () {
      expect(
        AppColors.textPrimary(Brightness.light),
        equals(AppColors.lightTextPrimary),
      );
      expect(
        AppColors.textPrimary(Brightness.dark),
        equals(AppColors.darkTextPrimary),
      );
    });

    test('textSecondary returns correct color for brightness', () {
      expect(
        AppColors.textSecondary(Brightness.light),
        equals(AppColors.lightTextSecondary),
      );
      expect(
        AppColors.textSecondary(Brightness.dark),
        equals(AppColors.darkTextSecondary),
      );
    });

    test('subjectColor returns correct color for known subjects', () {
      expect(AppColors.subjectColor('math'), equals(AppColors.subjectMath));
      expect(AppColors.subjectColor('Math'), equals(AppColors.subjectMath));
      expect(AppColors.subjectColor('mathematics'), equals(AppColors.subjectMath));
      expect(AppColors.subjectColor('science'), equals(AppColors.subjectScience));
      expect(AppColors.subjectColor('arabic'), equals(AppColors.subjectArabic));
    });

    test('subjectColor returns default for unknown subject', () {
      expect(AppColors.subjectColor('unknown'), equals(AppColors.subjectDefault));
      expect(AppColors.subjectColor(''), equals(AppColors.subjectDefault));
    });

    test('roleColor returns correct color for known roles', () {
      expect(AppColors.roleColor('owner'), equals(AppColors.roleOwner));
      expect(AppColors.roleColor('teacher'), equals(AppColors.roleTeacher));
      expect(AppColors.roleColor('student'), equals(AppColors.roleStudent));
      expect(AppColors.roleColor('parent'), equals(AppColors.roleParent));
    });

    test('roleColor returns default for unknown role', () {
      expect(AppColors.roleColor('unknown'), equals(AppColors.subjectDefault));
    });
  });
}
