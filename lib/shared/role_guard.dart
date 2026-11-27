import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'theme.dart';

class RoleGuard extends StatefulWidget {
  final Widget child;
  final List<String> allowedRoles;
  final String routeName;

  const RoleGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.routeName = 'Portal',
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;
  String _userRole = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
          _errorMessage = 'Authentication required. Please sign in to access this page.';
        });
      }
      return;
    }

    try {
      final role = await SupabaseService.getUserRole(user.email);
      final normalizedRole = role.toLowerCase().trim();
      final normalizedAllowed = widget.allowedRoles.map((r) => r.toLowerCase().trim()).toList();

      final hasAccess = normalizedAllowed.contains(normalizedRole) || normalizedRole == 'admin';

      if (mounted) {
        setState(() {
          _userRole = normalizedRole;
          _isAuthorized = hasAccess;
          _isLoading = false;
          if (!hasAccess) {
            _errorMessage = 'Access Denied: Your account role ($normalizedRole) is not permitted to access this ${widget.routeName}.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
          _errorMessage = 'Error verifying authorization: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 72,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Unauthorized Portal Access',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'You do not have permission to view this portal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to appropriate home based on real role
                    if (_userRole == 'driver') {
                      Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (_) => false);
                    } else if (_userRole == 'admin') {
                      Navigator.pushNamedAndRemoveUntil(context, '/admin_dashboard', (_) => false);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(context, '/student_home', (_) => false);
                    }
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Return to Permitted Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await SupabaseService.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/student_login', (_) => false);
                    }
                  },
                  child: const Text('Sign out and use another account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
