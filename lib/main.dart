import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/student/student_login_screen.dart';
import 'screens/student/student_signup_screen.dart';
import 'screens/student/student_forgot_password_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/student_profile_screen.dart';
import 'screens/driver/driver_login_screen.dart';
import 'screens/driver/driver_signup_screen.dart';
import 'screens/driver/driver_forgot_password_screen.dart';
import 'screens/driver/driver_select_bus_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_signup_screen.dart';
import 'screens/admin/admin_forgot_password_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_manage_buses_screen.dart' as buses_screen;
import 'screens/admin/admin_manage_drivers_screen.dart' as drivers_screen;
import 'screens/admin/admin_route_management_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/admin/admin_view_feedback_screen.dart';
import 'screens/admin/assign_bus_route_screen.dart';
import 'shared/role_guard.dart';
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
        '/student_home': (context) => const RoleGuard(
              allowedRoles: ['student', 'faculty', 'admin'],
              routeName: 'Commuter Portal',
              child: StudentHomeScreen(),
            ),
        '/student_profile': (context) => const RoleGuard(
              allowedRoles: ['student', 'faculty', 'admin'],
              routeName: 'Profile & Bus Settings',
              child: StudentProfileScreen(),
            ),
        '/driver_login': (context) => const DriverLoginScreen(),
        '/driver_signup': (context) => const DriverSignupScreen(),
        '/driver_forgot_password': (context) => const DriverForgotPasswordScreen(),
        '/driver_select_bus': (context) => const RoleGuard(
              allowedRoles: ['driver', 'admin'],
              routeName: 'Select Bus',
              child: DriverSelectBusScreen(),
            ),
        '/driver_dashboard': (context) => const RoleGuard(
              allowedRoles: ['driver', 'admin'],
              routeName: 'Driver Console',
              child: DriverDashboardScreen(),
            ),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_signup': (context) => const AdminSignupScreen(),
        '/admin_forgot_password': (context) => const AdminForgotPasswordScreen(),
        '/admin_dashboard': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Admin Console',
              child: AdminDashboardScreen(),
            ),
        '/admin_manage_buses': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Manage Buses',
              child: buses_screen.AdminManageBusesScreen(),
            ),
        '/admin_manage_drivers': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Manage Drivers',
              child: drivers_screen.AdminManageDriversScreen(),
            ),
        '/admin_route_management': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Route Management',
              child: AdminRouteManagementScreen(),
            ),
        '/assign_bus_route': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Assign Bus Route',
              child: AssignBusRouteScreen(),
            ),
        '/admin_analytics': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'Announcements',
              child: AdminAnalyticsScreen(),
            ),
        '/admin_view_feedback': (context) => const RoleGuard(
              allowedRoles: ['admin'],
              routeName: 'View Feedback',
              child: AdminViewFeedbackScreen(),
            ),
      },
    );
  }
}
