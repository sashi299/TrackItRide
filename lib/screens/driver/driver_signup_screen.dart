import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Driver Signup Screen matching Figma 02 · Driver sign up (2:1669)
class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController(text: '+91 ');
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final licenseNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _signUpDriver() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pwd = passwordController.text.trim();
    final cpwd = confirmPasswordController.text.trim();
    if (pwd != cpwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signUp(
        email: emailController.text.trim(),
        password: pwd,
        role: 'driver',
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        licenseNumber: licenseNumberController.text.trim(),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registration Submitted',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter'),
              ),
            ],
          ),
          content: const Text(
            'Your driver registration has been submitted. Check your email for confirmation. An administrator will review and approve your account before you can select a bus.',
            style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: AppTheme.text, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/driver_login');
              },
              child: const Text('Go to Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        String message = 'Signup failed: $errStr';

        if (errStr.contains('over_email_send_rate_limit')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
              title: const Text('Email Rate Limit (429)'),
              content: const Text(
                'Driver account was created, but Supabase reached its hourly email limit. You may proceed to login if auto-confirm is active.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/driver_login');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
          return;
        } else if (errStr.contains('User already registered')) {
          message = 'This email is already registered. Please go to Login or reset your password.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 6),
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
        title: const Text(
          'Driver Sign Up',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Wordmark matching Figma 01 / 02
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

                // Headings matching Figma 02 · Driver sign up
                const Text(
                  'Join as Campus Driver',
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
                  'Register your profile to drive college transit buses.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),

                // 1. Name
                CustomTextField(
                  label: 'Name',
                  controller: nameController,
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.muted, size: 20),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),

                // 2. Email
                CustomTextField(
                  label: 'Email',
                  controller: emailController,
                  hintText: 'driver@college.ac.in',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted, size: 20),
                  validator: (val) => val == null || !val.contains('@') ? 'Please enter a valid email' : null,
                ),
                const SizedBox(height: 16),

                // 3. Phone
                CustomTextField(
                  label: 'Phone',
                  controller: phoneController,
                  hintText: '+91 Enter phone number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.muted, size: 20),
                  validator: (val) => val == null || val.trim().length < 8 ? 'Please enter a valid phone number' : null,
                ),
                const SizedBox(height: 16),

                // 4. Driving license number
                CustomTextField(
                  label: 'Driving license number',
                  controller: licenseNumberController,
                  hintText: 'Enter license number (e.g. AP30 2020 0012345)',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.muted, size: 20),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your driving license number' : null,
                ),
                const SizedBox(height: 16),

                // 5. Password
                CustomTextField(
                  label: 'Password',
                  controller: passwordController,
                  hintText: 'Create a password',
                  obscureText: !_passwordVisible,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.muted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppTheme.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 16),

                // 6. Confirm password
                CustomTextField(
                  label: 'Confirm password',
                  controller: confirmPasswordController,
                  hintText: 'Re-enter your password',
                  obscureText: !_confirmPasswordVisible,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.muted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppTheme.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please confirm your password' : null,
                ),
                const SizedBox(height: 24),

                // Create account Button (56px Driver touch target)
                CustomButton(
                  label: 'Create account',
                  height: 56,
                  isLoading: _isLoading,
                  onPressed: _signUpDriver,
                ),
                const SizedBox(height: 16),

                // Link to Login
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/driver_login'),
                    child: const Text(
                      'Already registered? Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Inter',
                      ),
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
