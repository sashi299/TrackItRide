import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Admin Announcements & Analytics Screen matching Figma AM09 · Announcements (12:3377),
/// AM11 · Analytics (12:3379), AD09, and AD11.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPosting = false;
  String _selectedAudience = 'All'; // 'All', 'Students', 'Drivers'

  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  // Analytics Metrics
  int _busesCount = 0;
  int _driversCount = 0;
  int _routesCount = 0;
  int _tripsCount = 0;

  int _selectedTab = 0; // 0: Broadcast Announcement, 1: Analytics

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getAnnouncements(),
        SupabaseService.getBuses(),
        SupabaseService.getDrivers(),
        SupabaseService.getRoutes(),
      ]);

      if (mounted) {
        setState(() {
          _announcements = results[0];
          _busesCount = results[1].length;
          _driversCount = results[2].length;
          _routesCount = results[3].length;
          _tripsCount = results[1].where((b) => b['active'] == true).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postAnnouncement() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter announcement title and message body.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      String audience = 'all';
      if (_selectedAudience == 'Students') audience = 'student';
      if (_selectedAudience == 'Drivers') audience = 'driver';

      await SupabaseService.createAnnouncement(
        title: title,
        message: body,
        audienceRole: audience,
      );

      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement broadcasted to commuters and drivers!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
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
              'Announcements & Analytics',
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
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 520),
                child: Column(
                  children: [
                    // Tab Selector: Announcements vs Analytics
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 0),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0 ? AppTheme.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedTab == 0
                                        ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Announcements',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.w500,
                                      color: _selectedTab == 0 ? AppTheme.primaryColor : AppTheme.muted,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedTab = 1),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1 ? AppTheme.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedTab == 1
                                        ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Fleet Analytics',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.w500,
                                      color: _selectedTab == 1 ? AppTheme.primaryColor : AppTheme.muted,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: _selectedTab == 0 ? _buildAnnouncementsTab() : _buildAnalyticsTab(),
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

  /// AM09 · Announcements (12:3377)
  Widget _buildAnnouncementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Field (Figma node 12:9204)
          CustomTextField(
            label: 'Title',
            controller: _titleController,
            hintText: 'e.g. Morning service reminder',
          ),
          const SizedBox(height: 16),

          // Message Field (Figma node 12:3903 & 12:3905 - 160px height)
          const Text(
            'Message',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 8),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Please be at your stop 5 minutes before scheduled pickup time…',
                hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14, fontFamily: 'Inter'),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14, color: AppTheme.text, fontFamily: 'Inter'),
            ),
          ),
          const SizedBox(height: 16),

          // Audience Choices (Figma node 12:9240)
          Row(
            children: [
              _buildAudienceChip('All'),
              const SizedBox(width: 8),
              _buildAudienceChip('Students'),
              const SizedBox(width: 8),
              _buildAudienceChip('Drivers'),
            ],
          ),
          const SizedBox(height: 20),

          // Publish announcement Button (Figma node 2:572)
          CustomButton(
            label: 'Publish announcement',
            height: 48,
            isLoading: _isPosting,
            onPressed: _postAnnouncement,
          ),
          const SizedBox(height: 28),

          // Past Announcements Header (Figma node 12:9249)
          const Text(
            'Past announcements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 12),

          if (_isLoading) ...[
            const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          ] else if (_announcements.isEmpty) ...[
            const Text('No announcements published yet.', style: TextStyle(color: AppTheme.muted, fontFamily: 'Inter')),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _announcements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _announcements[index];
                final title = item['title'] ?? 'Announcement';
                final body = item['message'] ?? item['body'] ?? '';
                final date = item['created_at']?.toString() ?? 'Today';

                return Container(
                  padding: const EdgeInsets.all(14),
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
                          Expanded(
                            child: Text(
                              title.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Inter'),
                            ),
                          ),
                          Text(
                            date.length > 10 ? date.substring(0, 10) : date,
                            style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body.toString(),
                        style: const TextStyle(color: AppTheme.text, fontSize: 13, fontFamily: 'Inter', height: 1.4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String label) {
    final isSelected = _selectedAudience == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAudience = label),
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
            label,
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

  /// AM11 · Analytics (12:3379)
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range indicator
          const Text(
            'Active fleet overview · College transit system',
            style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 12),

          // KPIs (Figma node 12:9374)
          Row(
            children: [
              Expanded(
                child: _buildKpiBox('Total Buses', _busesCount.toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox('Active Trips', _tripsCount.toString()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiBox('Drivers Roster', _driversCount.toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiBox('Active Routes', _routesCount.toString()),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Trips Per Day Chart Card (Figma node 12:9383 & 12:9385)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trips per day',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 16),

                // Bar Chart Visual matching Figma 12:9385
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildChartBar('6', 812, 1000, 0.81),
                      _buildChartBar('7', 640, 1000, 0.64),
                      _buildChartBar('8', 416, 1000, 0.42),
                      _buildChartBar('9', 896, 1000, 0.90),
                      _buildChartBar('10', 920, 1000, 0.92),
                      _buildChartBar('11', 908, 1000, 0.91),
                      _buildChartBar('12', 832, 1000, 0.83),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Transit Week · Completed student pickup trips',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(String label, String value) {
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
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter')),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, int count, int max, double fraction) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 10, color: AppTheme.muted, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 4),
          Container(
            height: 110 * fraction,
            width: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.muted, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}
