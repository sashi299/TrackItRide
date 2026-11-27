import 'package:flutter/material.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Admin Signup / Policy Screen matching System 1.0 Security Policy (AM01 / SYS08 styling).
class AdminSignupScreen extends StatelessWidget {
  const AdminSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Admin Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.security_rounded, size: 36, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Restricted Registration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'To maintain campus transit security and protect real-time operational controls, '
                      'Administrator accounts cannot be registered publicly.\n\n'
                      'Transport Administrators are provisioned directly by the institution transport officer '
                      'via the Supabase Console.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                        fontFamily: 'Inter',
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    CustomButton(
                      label: 'Return to Admin Login',
                      height: 48,
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/admin_login',
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    CustomButton(
                      label: 'Go to Student App',
                      isSecondary: true,
                      height: 48,
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/student_login',
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
