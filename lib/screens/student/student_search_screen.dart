import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

/// Search routes by name / code / stop name.
/// Visuals match Figma 05 · Fields & search (2:105), 06 · Search focused (2:1673),
/// and S20 · Routes · No results (7:1551).
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _token = 0;
  List<Map<String, dynamic>> _routes = [];
  final Map<String, Future<List<Map<String, dynamic>>>> _stopsCache = {};
  final Set<String> _expandedRouteIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.searchRoutes(q, limit: 30);
      if (!mounted || token != _token) return;
      setState(() => _routes = rows);
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() => _error = 'Could not load routes. Check your connection.');
    } finally {
      if (mounted && token == _token) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _stopsFor(String routeId) =>
      _stopsCache.putIfAbsent(routeId, () => SupabaseService.getStopsForRoute(routeId));

  void _toggleExpanded(String routeId) {
    setState(() {
      if (_expandedRouteIds.contains(routeId)) {
        _expandedRouteIds.remove(routeId);
      } else {
        _expandedRouteIds.add(routeId);
      }
    });
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
          'Search Routes & Stops',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar matching Figma 05 · Fields & search (2:105) & 06 · Search focused (2:1673)
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.text,
                  fontFamily: 'Inter',
                ),
                decoration: InputDecoration(
                  hintText: 'Search by route name, code, or stop...',
                  hintStyle: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.muted, size: 22),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.muted, size: 20),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: AppTheme.primarySubtle,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _search(_controller.text),
                    child: const Text('Retry', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: (!_loading && _routes.isEmpty && _error == null)
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    itemCount: _routes.length,
                    itemBuilder: (context, index) {
                      final route = _routes[index];
                      final routeId = '${route['id']}';
                      final isExpanded = _expandedRouteIds.contains(routeId);
                      return _buildRouteCard(route, routeId, isExpanded);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Empty state matching Figma S20 · Routes · No results (7:1551)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching routes found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with a different route name, code, or stop location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.muted,
                fontFamily: 'Inter',
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Route Card matching Figma StudentRouteCard (7:3231)
  Widget _buildRouteCard(Map<String, dynamic> route, String routeId, bool isExpanded) {
    final routeCode = route['code'] ?? 'R';
    final routeName = route['name'] ?? 'Route';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => _toggleExpanded(routeId),
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route $routeCode',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.muted,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          routeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.muted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Stops List matching Figma S18 · Routes · Expanded (7:1549)
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _stopsFor(routeId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        ),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Could not load stops for this route.',
                          style: TextStyle(color: AppTheme.error, fontSize: 13, fontFamily: 'Inter'),
                        ),
                      ),
                    );
                  }
                  final stops = snap.data ?? [];
                  if (stops.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No stops configured for this route yet.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 13, fontFamily: 'Inter'),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: List.generate(stops.length, (idx) {
                        final stop = stops[idx];
                        final seq = stop['sequence_no'] ?? (idx + 1);
                        final stopName = stop['name'] ?? 'Stop';
                        final time = stop['scheduled_morning'] ?? '';
                        final isLast = idx == stops.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sequence circle with vertical timeline line
                            Column(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    seq < 10 ? '0$seq' : '$seq',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.muted,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 24,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4.0, bottom: 12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        stopName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.text,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.muted,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
