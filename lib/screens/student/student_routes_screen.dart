import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

/// Campus Bus Routes Screen matching Figma S18 · Routes · Expanded (7:1549)
/// with sub-states S19 (Loading), S20 (No results), S21 (Offline), S22 (Error).
class StudentRoutesScreen extends StatefulWidget {
  const StudentRoutesScreen({super.key});

  @override
  State<StudentRoutesScreen> createState() => _StudentRoutesScreenState();
}

class _StudentRoutesScreenState extends State<StudentRoutesScreen> {
  late Future<List<Map<String, dynamic>>> _routesFuture;
  final TextEditingController _filterController = TextEditingController();
  final Map<String, Future<List<Map<String, dynamic>>>> _stopsCache = {};
  final Set<String> _expandedRouteIds = {};
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _loadRoutes() {
    setState(() {
      _routesFuture = SupabaseService.getRoutes();
    });
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
          'Campus Routes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          _stopsCache.clear();
          _loadRoutes();
          await _routesFuture;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            // S19 · Routes · Loading stops (7:1550)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            // S22 · Routes · Error (7:1553)
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.errorBg,
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        ),
                        child: const Icon(Icons.cloud_off_rounded, color: AppTheme.error, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not load campus routes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _loadRoutes,
                        child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allRoutes = snapshot.data ?? [];

            // S20 · Routes · No results (7:1551)
            if (allRoutes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
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
                        child: const Icon(Icons.alt_route_rounded, size: 32, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No routes registered yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Campus transit routes will be displayed here once scheduled by the transport office.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.muted, fontFamily: 'Inter', height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Filter routes based on search text
            final filteredRoutes = _filterText.isEmpty
                ? allRoutes
                : allRoutes.where((r) {
                    final name = (r['name'] ?? '').toString().toLowerCase();
                    final code = (r['code'] ?? '').toString().toLowerCase();
                    final query = _filterText.toLowerCase();
                    return name.contains(query) || code.contains(query);
                  }).toList();

            return Column(
              children: [
                // Search filter field
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
                      controller: _filterController,
                      onChanged: (val) => setState(() => _filterText = val.trim()),
                      style: const TextStyle(fontSize: 15, color: AppTheme.text, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        hintText: 'Filter routes by name or code...',
                        hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 14, fontFamily: 'Inter'),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.muted, size: 22),
                        suffixIcon: _filterController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppTheme.muted, size: 20),
                                onPressed: () {
                                  _filterController.clear();
                                  setState(() => _filterText = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),

                // Routes List
                Expanded(
                  child: filteredRoutes.isEmpty
                      ? Center(
                          child: Text(
                            'No routes match "$_filterText"',
                            style: const TextStyle(fontSize: 15, color: AppTheme.muted, fontFamily: 'Inter'),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredRoutes.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          itemBuilder: (context, index) {
                            final route = filteredRoutes[index];
                            final routeId = '${route['id']}';
                            final isExpanded = _expandedRouteIds.contains(routeId);
                            return _buildRouteCard(route, routeId, isExpanded);
                          },
                        ),
                ),
              ],
            );
          },
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

          // Expanded Stops Timeline matching Figma S18 · Routes · Expanded (7:1549)
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                          child: Text(
                            'SCHEDULED STOPS (${stops.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: 0.5,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        ...List.generate(stops.length, (idx) {
                          final stop = stops[idx];
                          final seq = stop['sequence_no'] ?? (idx + 1);
                          final stopName = stop['name'] ?? 'Stop';
                          final morningTime = stop['scheduled_morning'] ?? '';
                          final isLast = idx == stops.length - 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      if (morningTime.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            morningTime,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.muted,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
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
