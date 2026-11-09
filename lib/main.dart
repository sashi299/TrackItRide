import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_signup_screen.dart';
import 'screens/student/student_forgot_password_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/driver/driver_login_screen.dart';
import 'screens/driver/driver_signup_screen.dart';
import 'screens/driver/driver_forgot_password_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_signup_screen.dart';
import 'screens/admin/admin_forgot_password_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
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
      title: 'TrackItRide - Smart College Bus Tracking',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/student_login',
      routes: {
        '/student_login': (context) => const StudentLoginScreen(),
        '/student_signup': (context) => const StudentSignupScreen(),
        '/student_forgot_password': (context) => const StudentForgotPasswordScreen(),
        '/student_home': (context) => const StudentHomeScreen(),
        '/driver_login': (context) => const DriverLoginScreen(),
        '/driver_signup': (context) => const DriverSignupScreen(),
        '/driver_forgot_password': (context) => const DriverForgotPasswordScreen(),
        '/driver_dashboard': (context) => const DriverDashboardScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_signup': (context) => const AdminSignupScreen(),
        '/admin_forgot_password': (context) => const AdminForgotPasswordScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}
