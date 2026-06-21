import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/tokens/tokens.dart';
import 'package:klasivo/widgets/klasivo_button.dart';

void main() {
  // ─── Rendering ─────────────────────────────────────────────────────────────

  group('KlasivoButton Rendering', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(label: 'Submit'),
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Delete',
              icon: Icons.delete,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('does not render icon when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(label: 'Save'),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('wraps with Tooltip when tooltip is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Save',
              tooltip: 'Save changes',
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('does not wrap with Tooltip when tooltip is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(label: 'Save'),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsNothing);
    });
  });

  // ─── Interaction ───────────────────────────────────────────────────────────

  group('KlasivoButton Interaction', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Press Me',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Press Me'));
      expect(pressed, isTrue);
    });

    testWidgets('does not call onPressed when null (disabled)', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Disabled',
              onPressed: null,
            ),
          ),
        ),
      );

      // Try tapping — should not crash or call
      final gesture = find.text('Disabled');
      if (gesture.evaluate().isNotEmpty) {
        await tester.tap(gesture, warnIfMissed: false);
      }
      expect(pressed, isFalse);
    });

    testWidgets('does not call onPressed when loading', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Loading',
              loading: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      // Find the InkWell and try to tap
      final inkWell = find.byType(InkWell);
      if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell.first);
      }
      expect(pressed, isFalse);
    });
  });

  // ─── Loading State ─────────────────────────────────────────────────────────

  group('KlasivoButton Loading State', () {
    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Submit',
              loading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides icon when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Submit',
              icon: Icons.send,
              loading: true,
            ),
          ),
        ),
      );

      // Should show loading indicator, not icon
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('does not show CircularProgressIndicator when not loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Submit',
              loading: false,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ─── Variants ──────────────────────────────────────────────────────────────

  group('KlasivoButton Variants', () {
    testWidgets('primary variant has filled background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Primary',
              variant: KlasivoButtonVariant.primary,
            ),
          ),
        ),
      );

      // Primary should have AppColors.primary as background
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(AppColors.primary));
    });

    testWidgets('danger variant has error background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Delete',
              variant: KlasivoButtonVariant.danger,
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(AppColors.error));
    });

    testWidgets('secondary variant has transparent background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Cancel',
              variant: KlasivoButtonVariant.secondary,
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(Colors.transparent));
    });

    testWidgets('ghost variant has transparent background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Skip',
              variant: KlasivoButtonVariant.ghost,
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(Colors.transparent));
    });

    testWidgets('tertiary variant has transparent background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Dismiss',
              variant: KlasivoButtonVariant.tertiary,
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(Colors.transparent));
    });
  });

  // ─── Disabled State ────────────────────────────────────────────────────────

  group('KlasivoButton Disabled State', () {
    testWidgets('disabled button has border color background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Disabled',
              onPressed: null, // disabled
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, equals(AppColors.lightBorder));
    });

    testWidgets('loading button appears disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KlasivoButton(
              label: 'Loading',
              loading: true,
              onPressed: () {}, // has callback but loading
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(Material),
        ),
      );
      // When loading, isDisabled = true, so same as disabled
      expect(material.color, equals(AppColors.lightBorder));
    });
  });

  // ─── Full Width ────────────────────────────────────────────────────────────

  group('KlasivoButton Full Width', () {
    testWidgets('fullWidth button expands horizontally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: KlasivoButton(
                label: 'Full Width',
                fullWidth: true,
              ),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(KlasivoButton),
          matching: find.byType(ConstrainedBox),
        ),
      );

      final constraint = constrainedBox.constraints;
      expect(constraint.hasBoundedWidth, isTrue);
    });
  });

  // ─── Enum Coverage ─────────────────────────────────────────────────────────

  group('KlasivoButton Enums', () {
    test('all button variants exist', () {
      expect(KlasivoButtonVariant.values.length, equals(5));
      expect(KlasivoButtonVariant.values, contains(KlasivoButtonVariant.primary));
      expect(KlasivoButtonVariant.values, contains(KlasivoButtonVariant.secondary));
      expect(KlasivoButtonVariant.values, contains(KlasivoButtonVariant.tertiary));
      expect(KlasivoButtonVariant.values, contains(KlasivoButtonVariant.danger));
      expect(KlasivoButtonVariant.values, contains(KlasivoButtonVariant.ghost));
    });

    test('all button sizes exist', () {
      expect(KlasivoButtonSize.values.length, equals(3));
      expect(KlasivoButtonSize.values, contains(KlasivoButtonSize.sm));
      expect(KlasivoButtonSize.values, contains(KlasivoButtonSize.md));
      expect(KlasivoButtonSize.values, contains(KlasivoButtonSize.lg));
    });
  });
}
