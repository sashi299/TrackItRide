import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Student Forgot Password Screen matching Figma S03 · Confirm your email (7:1534)
/// and System 1.0 Auth layout.
class StudentForgotPasswordScreen extends StatefulWidget {
  const StudentForgotPasswordScreen({super.key});

  @override
  State<StudentForgotPasswordScreen> createState() => _StudentForgotPasswordScreenState();
}

class _StudentForgotPasswordScreenState extends State<StudentForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid college email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.resetPassword(email);
      if (!mounted) return;
      setState(() {
        _isSent = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not send reset link: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _isSent ? _buildSentConfirmationView() : _buildFormView(),
        ),
      ),
    );
  }

  /// Form input view
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Wordmark matching Figma S01 / S03
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

        // Headings
        const Text(
          'Forgot your password?',
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
          'Enter your college email address to receive password recovery instructions.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            fontFamily: 'Inter',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Email Input field
        CustomTextField(
          label: 'College email',
          controller: _emailController,
          hintText: 'name@college.ac.in',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
          ),
        ],

        const SizedBox(height: 24),

        // Send Reset Link Button
        CustomButton(
          label: 'Send reset link',
          isLoading: _isLoading,
          onPressed: _sendResetLink,
        ),
        const SizedBox(height: 16),

        // Return to login link
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Remember your password? Log in',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sent confirmation view matching Figma S03 · Confirm your email (7:1534)
  Widget _buildSentConfirmationView() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Confirmation Badge matching Figma node 7:2056 (64x64 rounded 12px)
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: AppTheme.success,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),

        // Heading matching Figma node 7:2060
        const Text(
          'Check your college email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
            fontFamily: 'Inter',
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle matching Figma node 7:2061
        Text(
          'We sent a password reset link to $email',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),

        // Body matching Figma node 7:2062
        const Text(
          'Follow the link in the email to set a new password and regain access to campus bus tracking.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            fontFamily: 'Inter',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Primary Action
        CustomButton(
          label: 'Back to login',
          onPressed: () => Navigator.pushReplacementNamed(context, '/student_login'),
        ),
        const SizedBox(height: 12),

        // Secondary Action
        CustomButton(
          label: 'Resend reset link',
          isSecondary: true,
          isLoading: _isLoading,
          onPressed: _sendResetLink,
        ),
      ],
    );
  }
}
