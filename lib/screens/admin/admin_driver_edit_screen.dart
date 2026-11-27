import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Admin Driver Edit Screen matching System 1.0 specifications.
class AdminDriverEditScreen extends StatefulWidget {
  final String driverId;
  final String name;
  final String email;
  final String phone;
  final String licenseNumber;

  const AdminDriverEditScreen({
    super.key,
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    required this.licenseNumber,
  });

  @override
  State<AdminDriverEditScreen> createState() => _AdminDriverEditScreenState();
}

class _AdminDriverEditScreenState extends State<AdminDriverEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _licenseController = TextEditingController(text: widget.licenseNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _updateDriver() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final license = _licenseController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      setState(() => _errorMessage = 'Driver / Faculty-Incharge name and email cannot be empty.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.updateDriver(
        driverId: widget.driverId,
        name: name,
        email: email,
        phone: phone.isNotEmpty ? phone : null,
        licenseNumber: license.isNotEmpty ? license : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver / Faculty-Incharge details updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Edit Driver / Faculty-Incharge: ${widget.name}',
          style: const TextStyle(
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    CustomTextField(
                      label: 'Driver / Faculty-Incharge Name',
                      controller: _nameController,
                      hintText: 'Driver / Faculty-Incharge name',
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'driver@college.ac.in',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'Phone number',
                      controller: _phoneController,
                      hintText: '+91 98765 43210',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'License number',
                      controller: _licenseController,
                      hintText: 'e.g. AP3020200012345',
                    ),
                    const SizedBox(height: 28),

                    CustomButton(
                      label: 'Save changes',
                      height: 48,
                      isLoading: _isLoading,
                      onPressed: _updateDriver,
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
