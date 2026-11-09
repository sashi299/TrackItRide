import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  _StudentLoginScreenState createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

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
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              label: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Password',
              controller: passwordController,
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
                    label: 'Login',
                    onPressed: handleLogin,
                  ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/student_signup'),
              child: const Text('If not registered, Signup', style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/student_forgot_password'),
              child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}
