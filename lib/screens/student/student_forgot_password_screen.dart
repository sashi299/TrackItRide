import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';

class StudentForgotPasswordScreen extends StatefulWidget {
  const StudentForgotPasswordScreen({super.key});

  @override
  _StudentForgotPasswordScreenState createState() =>
      _StudentForgotPasswordScreenState();
}

class _StudentForgotPasswordScreenState
    extends State<StudentForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.resetPassword(email);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset Email Sent'),
          content: Text(
            'A Supabase password reset link has been sent to $email. Please check your inbox.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/student_login');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address to receive password reset instructions.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Registered Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
                    label: 'Send Reset Link',
                    onPressed: sendResetLink,
                  ),
          ],
        ),
      ),
    );
  }
}
