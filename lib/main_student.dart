import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/student/student_feedback_screen.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_signup_screen.dart';
import 'screens/student/student_forgot_password_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/student_location_screen.dart';
import 'screens/student/student_notifications_screen.dart';
import 'screens/student/student_routes_screen.dart';
import 'screens/student/student_search_screen.dart';
import 'shared/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackItRide - Student App',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/student_login',
      routes: {
        '/student_login': (context) => const StudentLoginScreen(),
        '/student_signup': (context) => const StudentSignupScreen(),
        '/student_forgot_password': (context) => const StudentForgotPasswordScreen(),
        '/student_home': (context) => const StudentHomeScreen(),
        '/student_location': (context) => const StudentLocationScreen(),
        '/student_notifications': (context) => const StudentNotificationsScreen(),
        '/student_search': (context) => const StudentSearchScreen(),
        '/student_routes': (context) => const StudentRoutesScreen(),
        '/student_feedback': (context) => const StudentFeedbackScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const StudentLoginScreen(),
      ),
    );
  }
}
