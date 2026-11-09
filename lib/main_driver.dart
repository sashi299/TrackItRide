import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/driver/driver_login_screen.dart';
import 'screens/driver/driver_signup_screen.dart';
import 'screens/driver/driver_forgot_password_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart' as dashboard;
import 'screens/driver/driver_route_overview_screen.dart' as overview;
import 'screens/driver/driver_profile_screen.dart';
import 'screens/driver/driver_view_feedback_screen.dart';
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
      title: 'TrackItRide - Driver App',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/driver_login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/driver_login':
            return MaterialPageRoute(builder: (context) => const DriverLoginScreen());
          case '/driver_signup':
            return MaterialPageRoute(builder: (context) => const DriverSignupScreen());
          case '/driver_forgot_password':
            return MaterialPageRoute(builder: (context) => const DriverForgotPasswordScreen());
          case '/driver_dashboard':
            return MaterialPageRoute(builder: (context) => const dashboard.DriverDashboardScreen());
          case '/driver_route_overview':
            if (settings.arguments is Map<String, String>) {
              final args = settings.arguments as Map<String, String>;
              final driverEmail = args['driverEmail'] ?? '';
              final busNumber = args['busNumber'] ?? '';
              final routeName = args['routeName'] ?? '';
              return MaterialPageRoute(
                builder: (context) => overview.DriverRouteOverviewScreen(
                  driverEmail: driverEmail,
                  busNumber: busNumber,
                  routeName: routeName,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const overview.DriverRouteOverviewScreen(
                driverEmail: '',
                busNumber: '',
                routeName: '',
              ),
            );
          case '/driver_profile':
            return MaterialPageRoute(builder: (context) => const DriverProfileScreen());
          case '/driver_view_feedback':
            return MaterialPageRoute(builder: (context) => const DriverViewFeedbackScreen());
          default:
            return MaterialPageRoute(builder: (context) => const DriverLoginScreen());
        }
      },
    );
  }
}
