import 'package:flutter/material.dart';
import '../../services/feedback_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Student Feedback Screen matching Figma S28 · Feedback (7:1559)
/// and S29 · Feedback · Sent (7:1560).
class StudentFeedbackScreen extends StatefulWidget {
  const StudentFeedbackScreen({super.key});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your feedback before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = SupabaseService.currentEmail ?? 'student';
      await FeedbackService().submitFeedback(
        email,
        text,
        'student',
      );
      if (!mounted) return;
      setState(() {
        _isSent = true;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Could not submit feedback: $e';
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
          'Feedback',
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
          child: _isSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  /// Feedback input view matching Figma S28 · Feedback (7:1559)
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading matching Figma node 7:4140
        const Text(
          'How was your ride?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
            fontFamily: 'Inter',
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        // Subtitle matching Figma node 7:4141
        const Text(
          'Your feedback goes directly to the transport administrator.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 24),

        // Message field label
        const Text(
          'Your feedback',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),

        // Multiline input matching Figma node 7:4142
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: _errorMessage != null ? AppTheme.error : AppTheme.border,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _feedbackController,
            maxLines: null,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.text,
              fontFamily: 'Inter',
            ),
            decoration: const InputDecoration(
              hintText: 'What would make your bus journey better?',
              hintStyle: TextStyle(
                color: AppTheme.muted,
                fontSize: 15,
                fontFamily: 'Inter',
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
          ),
        ],

        const SizedBox(height: 24),

        // Submit Button matching Figma node 2:572
        CustomButton(
          label: 'Submit feedback',
          isLoading: _isSubmitting,
          onPressed: _submitFeedback,
        ),
        const SizedBox(height: 12),

        // Disclaimer matching Figma node 7:4148
        const Center(
          child: Text(
            'Don’t include passwords or sensitive personal information.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.muted,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }

  /// Success confirmation matching Figma S29 · Feedback · Sent (7:1560)
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        // Confirmation Badge (64x64 rounded 12px)
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: AppTheme.success,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        const Text(
          'Feedback sent!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
            fontFamily: 'Inter',
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Description
        const Text(
          'Thank you for helping us improve campus transit. Your response has been recorded and delivered to the transport coordinator.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.muted,
            fontFamily: 'Inter',
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Action button
        CustomButton(
          label: 'Back to Home',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
