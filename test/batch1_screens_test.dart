import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_go/shared/theme.dart';
import 'package:campus_go/screens/student/student_feedback_screen.dart';
import 'package:campus_go/screens/student/student_forgot_password_screen.dart';

void main() {
  group('Batch 1 Student Screens UI & Interaction Tests', () {
    testWidgets('StudentForgotPasswordScreen renders initial form with Figma S03 tokens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData,
          home: const StudentForgotPasswordScreen(),
        ),
      );

      // Verify Header, Brand, and Inputs
      expect(find.text('TrackItRide'), findsOneWidget);
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('College email'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Remember your password? Log in'), findsOneWidget);

      // Tap Send without email -> shows error
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Please enter a valid college email address.'), findsOneWidget);
    });

    testWidgets('StudentFeedbackScreen renders Figma S28 layout with multiline input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData,
          home: const StudentFeedbackScreen(),
        ),
      );

      // Verify Figma S28 text elements
      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('How was your ride?'), findsOneWidget);
      expect(find.text('Your feedback goes directly to the transport administrator.'), findsOneWidget);
      expect(find.text('Your feedback'), findsOneWidget);
      expect(find.text('What would make your bus journey better?'), findsOneWidget);
      expect(find.text('Submit feedback'), findsOneWidget);
      expect(find.text('Don’t include passwords or sensitive personal information.'), findsOneWidget);

      // Tap submit with empty input -> validation error
      await tester.tap(find.text('Submit feedback'));
      await tester.pump();
      expect(find.text('Please enter your feedback before submitting.'), findsOneWidget);
    });
  });
}
