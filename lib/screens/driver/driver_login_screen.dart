import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  _DriverLoginScreenState createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _isLoading = false;

  Future<void> _loginDriver() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      try {
        await SupabaseService.signIn(email: email, password: password);
        final assignment = await SupabaseService.getDriverAssignment(email);

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/driver_dashboard',
          arguments: {
            'driverEmail': email,
            'busNumber': assignment?['busNumber'] ?? 'BUS-12',
            'routeName': assignment?['routeName'] ?? 'Main Campus Route',
            'tripId': assignment?['tripId'] ?? '',
          },
        );
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
                      const SnackBar(
                        content: Text('Confirmation email resent! Please check your Gmail.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (resendErr) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to resend: $resendErr'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          } else if (errStr.contains('Invalid login credentials')) {
            message = 'Invalid email or password. Please verify your credentials.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
              action: action,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Login'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back, Driver!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please log in to stream GPS and view your route.',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 32),
                CustomTextField(
                  label: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Email is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: !_passwordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Password is required' : null,
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomButton(
                        label: 'Login',
                        onPressed: _loginDriver,
                        color: AppTheme.primaryColor,
                        textColor: Colors.white,
                      ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/driver_forgot_password');
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/driver_signup');
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
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
