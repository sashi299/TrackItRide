import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Admin Feedback Inbox Screen matching Figma AM10 · Feedback inbox (12:3378) and AD10 (12:3359).
class AdminViewFeedbackScreen extends StatefulWidget {
  const AdminViewFeedbackScreen({super.key});

  @override
  State<AdminViewFeedbackScreen> createState() => _AdminViewFeedbackScreenState();
}

class _AdminViewFeedbackScreenState extends State<AdminViewFeedbackScreen> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Open', 'Resolved'
  final Set<String> _locallyResolvedIds = {};

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await SupabaseService.getFeedbacks();
      if (mounted) {
        setState(() {
          _feedbacks = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFeedbacks {
    final q = _searchController.text.trim().toLowerCase();
    return _feedbacks.where((item) {
      final id = item['id']?.toString() ?? '';
      final isResolved = _locallyResolvedIds.contains(id) || item['resolved'] == true;

      if (_selectedFilter == 'Open' && isResolved) return false;
      if (_selectedFilter == 'Resolved' && !isResolved) return false;

      if (q.isNotEmpty) {
        final meta = item['metadata_json'] is Map ? item['metadata_json'] : {};
        final feedbackText = (meta['feedback'] ?? item['action'] ?? '').toString().toLowerCase();
        final email = (meta['email'] ?? item['entity_id'] ?? '').toString().toLowerCase();
        if (!feedbackText.contains(q) && !email.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _markResolved(String id) {
    setState(() {
      _locallyResolvedIds.add(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback marked as resolved.'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        final openCount = _feedbacks.where((f) => !_locallyResolvedIds.contains(f['id']?.toString())).length;
        final resolvedCount = _feedbacks.length - openCount;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Feedback inbox',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.text),
                onPressed: _loadFeedback,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 540),
                child: Column(
                  children: [
                    // Search & Filters Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          // Search Box (Figma node 12:3898)
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                              border: Border.all(color: AppTheme.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: AppTheme.muted, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText: 'Student email or message',
                                      hintStyle: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(fontSize: 15, color: AppTheme.text, fontFamily: 'Inter'),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: AppTheme.muted, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Filter chips (Figma node 12:9306)
                          Row(
                            children: [
                              _buildFilterChip('All', _feedbacks.length),
                              const SizedBox(width: 8),
                              _buildFilterChip('Open', openCount),
                              const SizedBox(width: 8),
                              _buildFilterChip('Resolved', resolvedCount),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Feedback List Body
                    Expanded(
                      child: _buildFeedbackList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.border),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.text,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Error loading feedback: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              CustomButton(label: 'Retry', height: 44, onPressed: _loadFeedback),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredFeedbacks;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 56, color: AppTheme.muted.withOpacity(0.5)),
              const SizedBox(height: 14),
              const Text(
                'No feedback found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Reports submitted from commuter or driver apps will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      );
    }

    // Feedback Cards List (Figma node 12:9313 & 12:9322)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final id = item['id']?.toString() ?? index.toString();
        final meta = item['metadata_json'] is Map ? item['metadata_json'] : {};
        final feedbackText = meta['feedback'] ?? item['action'] ?? 'Feedback report';
        final email = meta['email'] ?? item['entity_id'] ?? 'Commuter';
        final timestamp = item['created_at']?.toString() ?? 'Today';
        final isResolved = _locallyResolvedIds.contains(id) || item['resolved'] == true;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User email & status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    email.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResolved ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                    child: Text(
                      isResolved ? 'Resolved' : 'Open',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isResolved ? AppTheme.success : const Color(0xFF1D4ED8),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Feedback text
              Text(
                feedbackText.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),

              // Timestamp & Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timestamp.length > 16 ? timestamp.substring(0, 16) : timestamp,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                  ),
                  if (!isResolved)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () => _markResolved(id),
                      child: const Text('Mark as resolved', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
