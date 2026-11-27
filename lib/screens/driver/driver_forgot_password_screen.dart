import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Driver Forgot Password Screen matching Figma 03 · Email confirmation (2:1670)
/// and System 1.0 Driver Auth specifications.
class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({super.key});

  @override
  State<DriverForgotPasswordScreen> createState() => _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState extends State<DriverForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
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
        title: const Text(
          'Password Recovery',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.text),
          onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Wordmark matching Figma 01
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
            'Driver Password Recovery',
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
            'Enter your registered driver email to receive password reset instructions.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.muted,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Email Input
          CustomTextField(
            label: 'Driver email',
            controller: _emailController,
            hintText: 'driver@college.ac.in',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
            validator: (value) =>
                value == null || !value.contains('@') ? 'Please enter a valid driver email' : null,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
            ),
          ],

          const SizedBox(height: 24),

          // Send Reset Link Button (56px Driver Touch Target)
          CustomButton(
            label: 'Send reset link',
            height: 56,
            isLoading: _isLoading,
            onPressed: _sendResetLink,
          ),
          const SizedBox(height: 16),

          // Return to login link
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Remember your password? Login',
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
      ),
    );
  }

  Widget _buildSentConfirmationView() {
    final email = _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Confirmation Badge matching Figma node 2:4875 (64x64 rounded 12px)
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

        // Heading
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
            fontFamily: 'Inter',
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
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

        // Body
        const Text(
          'Follow the link in your email to reset your driver credentials and resume route tracking.',
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
          label: 'Back to Driver Login',
          height: 56,
          onPressed: () => Navigator.pushReplacementNamed(context, '/driver_login'),
        ),
        const SizedBox(height: 12),

        // Secondary Action
        CustomButton(
          label: 'Resend link',
          isSecondary: true,
          height: 56,
          isLoading: _isLoading,
          onPressed: _sendResetLink,
        ),
      ],
    );
  }
}
