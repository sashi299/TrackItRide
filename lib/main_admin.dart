import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_signup_screen.dart';
import 'screens/admin/admin_forgot_password_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_manage_buses_screen.dart' as buses_screen;
import 'screens/admin/admin_manage_drivers_screen.dart' as drivers_screen;
import 'screens/admin/admin_driver_edit_screen.dart';
import 'screens/admin/admin_register_driver_screen.dart';
import 'screens/admin/admin_route_management_screen.dart';
import 'screens/admin/admin_analytics_screen.dart';
import 'screens/admin/admin_view_feedback_screen.dart';
import 'screens/admin/assign_bus_route_screen.dart';
import 'shared/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackItRide - Admin Portal',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/admin_login',
      routes: {
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_signup': (context) => const AdminSignupScreen(),
        '/admin_forgot_password': (context) => const AdminForgotPasswordScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/admin_manage_buses': (context) => const buses_screen.AdminManageBusesScreen(),
        '/admin_manage_drivers': (context) => const drivers_screen.AdminManageDriversScreen(),
        '/admin_driver_edit': (context) => const AdminDriverEditScreen(
              driverId: '',
              name: '',
              email: '',
              phone: '',
              licenseNumber: '',
            ),
        '/admin_register_driver': (context) => const AdminRegisterDriverScreen(),
        '/admin_route_management': (context) => const AdminRouteManagementScreen(),
        '/admin_analytics': (context) => const AdminAnalyticsScreen(),
        '/admin_view_feedback': (context) => const AdminViewFeedbackScreen(),
        '/assign_bus_route': (context) => const AssignBusRouteScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const AdminLoginScreen(),
      ),
    );
  }
}
