import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_go/shared/theme.dart';
import 'package:campus_go/shared/status_chip.dart';
import 'package:campus_go/shared/custom_button.dart';

void main() {
  group('Figma System 1.0 Design Tokens & Component Tests', () {
    test('Design tokens match Figma System 1.0 exact specifications', () {
      expect(AppTheme.primaryColor, const Color(0xFF800000)); // Maroon / 700
      expect(AppTheme.primarySubtle, const Color(0xFFFFF1F2)); // Maroon / 50
      expect(AppTheme.liveMarker, const Color(0xFFF59E0B)); // Amber Bus Marker
      expect(AppTheme.background, const Color(0xFFF8FAFC)); // Slate 50
      expect(AppTheme.radiusControl, 12.0); // 12px radius
      expect(AppTheme.targetMin, 48.0); // 48px touch targets
    });

    testWidgets('StatusChip renders LIVE chip correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusChip(type: StatusChipType.live),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('StatusChip renders Select, Taken, Yours correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusChip(type: StatusChipType.select),
                StatusChip(type: StatusChipType.taken),
                StatusChip(type: StatusChipType.yours),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Yours'), findsOneWidget);
    });

    testWidgets('CustomButton renders 48px primary button', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData,
          home: Scaffold(
            body: CustomButton(
              label: 'Track bus',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Track bus'), findsOneWidget);
      await tester.tap(find.text('Track bus'));
      expect(pressed, isTrue);
    });
  });
}
