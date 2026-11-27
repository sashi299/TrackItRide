import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Admin Login Screen matching Figma AM01 · Admin login (12:3369)
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signIn(email: email, password: password, requiredRole: 'admin');
      final role = await SupabaseService.getUserRole(email);
      if (role != 'admin') {
        await SupabaseService.signOut();
        throw const AuthException('Access Denied: Your account does not have Administrator privileges.');
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String message = 'Admin Login failed: $errStr';

        if (errStr.contains('Invalid login credentials')) {
          message = 'Invalid administrator email or password.';
        } else if (errStr.contains('Access Denied') || errStr.contains('Access restricted')) {
          message = 'Access Denied: This portal requires Administrator privileges.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin login'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TrackItRide Brand Wordmark matching Figma 12:8395
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'TrackItRide',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  'Transport administrator access',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to manage the college fleet, routes, drivers, and announcements.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 28),

                // Email Field
                CustomTextField(
                  label: 'Administrator email',
                  hintText: 'admin@college.ac.in',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Admin email is required' : null,
                ),
                const SizedBox(height: 16),

                // Password Field
                CustomTextField(
                  label: 'Password',
                  hintText: '••••••••',
                  controller: passwordController,
                  obscureText: !_passwordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppTheme.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Password is required' : null,
                ),
                const SizedBox(height: 28),

                // Login Button
                CustomButton(
                  label: 'Login',
                  isLoading: _isLoading,
                  onPressed: handleLogin,
                ),
                const SizedBox(height: 24),

                // Admin Security Notice matching Figma 12:8414
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20, color: AppTheme.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Admin accounts are managed directly by the transport authority.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
