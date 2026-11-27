import 'package:flutter/material.dart';
import '../../services/feedback_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Driver Feedback Screen strictly matching Figma 18 · Driver feedback (2:1685).
/// Preserves feedback submission, validation, and historical feedback retrieval.
class DriverViewFeedbackScreen extends StatefulWidget {
  const DriverViewFeedbackScreen({super.key});

  @override
  State<DriverViewFeedbackScreen> createState() => _DriverViewFeedbackScreenState();
}

class _DriverViewFeedbackScreenState extends State<DriverViewFeedbackScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSent = false;
  String? _errorMessage;
  bool _showPastFeedback = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      setState(() => _errorMessage = 'Please describe the issue before sending.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = SupabaseService.currentEmail ?? 'driver';
      final combinedFeedback = subject.isNotEmpty
          ? '[$subject] $message'
          : message;

      await FeedbackService().submitFeedback(
        email,
        combinedFeedback,
        'driver',
      );

      if (!mounted) return;
      setState(() {
        _isSent = true;
        _isSubmitting = false;
        _subjectController.clear();
        _messageController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted to transport admin successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to submit feedback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Feedback',
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
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showPastFeedback = !_showPastFeedback),
            icon: Icon(
              _showPastFeedback ? Icons.edit_note : Icons.history,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            label: Text(
              _showPastFeedback ? 'Compose' : 'History',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _showPastFeedback ? _buildPastFeedbackList() : _buildComposeForm(),
      ),
    );
  }

  Widget _buildComposeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title (Figma node 2:4838)
              const Text(
                'Help improve your ride',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle (Figma node 2:4839)
              const Text(
                'Report a route, bus or app issue.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Success Confirmation Banner if sent
              if (_isSent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Feedback sent. The transport team has received your report.',
                          style: TextStyle(
                            color: Colors.green[900],
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _isSent = false),
                      ),
                    ],
                  ),
                ),
              ],

              // Error Banner
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
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Driver / Compact field: Subject (Figma node 2:3496 & 2:4840)
              const Text(
                'Subject',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    hintText: 'What went wrong? (e.g. Traffic delay, App GPS sync)',
                    hintStyle: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Driver / Message field (Figma node 2:4845)
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.border),
                ),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Tell your transport team what happened…',
                    hintStyle: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Button: Send feedback (56px Driver touch target, Figma node 2:605)
              CustomButton(
                label: 'Send feedback',
                height: 56,
                isLoading: _isSubmitting,
                onPressed: _submitFeedback,
              ),
              const SizedBox(height: 14),

              // Disclaimer text (Figma node 2:4855)
              const Text(
                'Send only when safely stopped. For urgent help, contact your transport admin.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastFeedbackList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FeedbackService().getFeedbackList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final feedbackList = snapshot.data ?? [];
        if (feedbackList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 56, color: AppTheme.muted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text(
                    'No feedback recorded yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Reports submitted to your transport admin will show here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: 'Write feedback',
                    height: 48,
                    onPressed: () => setState(() => _showPastFeedback = false),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: feedbackList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = feedbackList[index];
            final meta = item['metadata_json'] is Map ? item['metadata_json'] : {};
            final feedbackText = meta['feedback'] ?? item['action'] ?? 'Feedback';
            final email = meta['email'] ?? item['entity_id'] ?? 'Driver';
            final timestamp = item['created_at']?.toString() ?? '';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        email.toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        timestamp.length > 16 ? timestamp.substring(0, 16) : timestamp,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedbackText.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
