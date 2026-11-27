import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signIn(email: email, password: password);
      final profile = await SupabaseService.getMyProfile();
      if (!mounted) return;

      final role = (profile?['role'] ?? 'student').toString().toLowerCase();

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (role == 'driver') {
        Navigator.pushReplacementNamed(context, '/driver_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student_home');
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String message = 'Login failed: $errStr';
        SnackBarAction? action;

        if (errStr.contains('email_not_confirmed')) {
          message = 'Email not confirmed yet! Please check your Gmail inbox (including Spam folder) or tap RESEND.';
          action = SnackBarAction(
            label: 'RESEND',
            textColor: Colors.yellow,
            onPressed: () async {
              try {
                await SupabaseService.resendConfirmation(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Confirmation link resent to your email.')),
                  );
                }
              } catch (reErr) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resend failed: $reErr')),
                  );
                }
              }
            },
          );
        } else if (errStr.contains('Invalid login credentials')) {
          message = 'Incorrect email or password. Please verify your credentials.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
            action: action,
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand Wordmark matching Figma S01 (node 7:1975)
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
                      Icons.directions_bus,
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

              // Headings matching Figma S01 (node 7:1982)
              const Text(
                'Where’s your bus?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Log in to find your bus and arrival time.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),

              // College Email Input
              CustomTextField(
                label: 'College email',
                controller: emailController,
                hintText: 'name@college.ac.in',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
              ),
              const SizedBox(height: 16),

              // Password Input
              CustomTextField(
                label: 'Password',
                controller: passwordController,
                hintText: '••••••••',
                obscureText: !_passwordVisible,
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.muted, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.muted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              const SizedBox(height: 8),

              // Forgot Password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/student_forgot_password'),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Primary Login Button
              CustomButton(
                label: 'Login',
                isLoading: _isLoading,
                onPressed: handleLogin,
              ),
              const SizedBox(height: 12),

              // Secondary Sign Up Button
              CustomButton(
                label: 'New commuter? Sign up',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pushNamed(context, '/student_signup'),
              ),
              const SizedBox(height: 32),

              // Footer Note matching Figma S01 (node 7:1998)
              const Center(
                child: Text(
                  'Your location is shown only to you.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
