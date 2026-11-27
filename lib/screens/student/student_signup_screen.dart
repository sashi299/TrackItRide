import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Student / Faculty Sign Up matching Figma S02 · Student sign up (7:1533)
class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});

  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController(text: '+91');
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  String _selectedRole = 'student';

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool isValidFullName(String name) {
    return RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$').hasMatch(name.trim());
  }

  bool isValidPhoneNumber(String phone) {
    final clean = phone.replaceFirst('+91', '').replaceAll(' ', '').trim();
    return RegExp(r'^[0-9]{10}$').hasMatch(clean);
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  bool isValidPassword(String password) {
    return password.length >= 6;
  }

  bool doPasswordsMatch() {
    return passwordController.text == confirmPasswordController.text;
  }

  Future<void> _signUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.signUp(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          role: _selectedRole,
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
        );

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            title: const Text('Sign Up Successful', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            content: Text(
              'Your ${_selectedRole == 'faculty' ? 'Faculty' : 'Student'} account has been created successfully!',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/student_login',
                    (route) => false,
                  );
                },
                child: const Text('Proceed to Login', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
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
                title: const Text('Account Created'),
                content: const Text(
                  'Your account was created! You can now log in directly with your email and password.',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/student_login',
                        (route) => false,
                      );
                    },
                    child: const Text('Go to Login', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            return;
          } else if (errStr.contains('User already registered')) {
            message = 'This email is already registered. Please go to Login.';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Student sign up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand wordmark matching Figma S02
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
                  'Your campus ride starts here.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create an account with your college email.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.muted,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),

                // Role Selector (Student vs Faculty)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'student'),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: _selectedRole == 'student' ? AppTheme.primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: _selectedRole == 'student' ? Colors.white : AppTheme.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedRole == 'student' ? Colors.white : AppTheme.muted,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'faculty'),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: _selectedRole == 'faculty' ? AppTheme.primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 18,
                                  color: _selectedRole == 'faculty' ? Colors.white : AppTheme.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Faculty',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedRole == 'faculty' ? Colors.white : AppTheme.muted,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Name Field
                CustomTextField(
                  label: 'Full Name',
                  hintText: 'Ananya Rao',
                  controller: nameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[A-Za-z\s]*$')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // College Email Field
                CustomTextField(
                  label: 'College email',
                  hintText: 'name@college.ac.in',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    } else if (!isValidEmail(value)) {
                      return 'Enter a valid college email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Field
                CustomTextField(
                  label: 'Phone number',
                  hintText: '+91 9876543210',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-9+ ]*$')),
                    LengthLimitingTextInputFormatter(14),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone Number is required';
                    } else if (!isValidPhoneNumber(value)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password Field
                CustomTextField(
                  label: 'Password',
                  hintText: 'Create a password (min 6 chars)',
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    } else if (!isValidPassword(value)) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm Password Field
                CustomTextField(
                  label: 'Confirm password',
                  hintText: 'Repeat your password',
                  controller: confirmPasswordController,
                  obscureText: !_confirmPasswordVisible,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppTheme.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    } else if (!doPasswordsMatch()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Primary Create Account Button
                CustomButton(
                  label: 'Create account',
                  isLoading: _isLoading,
                  onPressed: _signUp,
                ),
                const SizedBox(height: 12),

                // Secondary Login Button
                CustomButton(
                  label: 'Already registered? Login',
                  isSecondary: true,
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/student_login');
                  },
                ),
                const SizedBox(height: 20),

                // Privacy footer matching Figma S02
                const Center(
                  child: Text(
                    'Your location is shown only to you.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
