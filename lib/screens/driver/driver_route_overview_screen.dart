import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';

/// Driver Route Schedule Screen matching Figma 15 · Route schedule (2:1682)
class DriverRouteOverviewScreen extends StatefulWidget {
  final String driverEmail;
  final String busNumber;
  final String routeName;
  final String busId;
  final String routeId;

  const DriverRouteOverviewScreen({
    this.driverEmail = '',
    this.busNumber = '',
    this.routeName = '',
    this.busId = '',
    this.routeId = '',
    super.key,
  });

  @override
  State<DriverRouteOverviewScreen> createState() => _DriverRouteOverviewScreenState();
}

class _DriverRouteOverviewScreenState extends State<DriverRouteOverviewScreen> {
  late Future<List<Map<String, dynamic>>> _stopsFuture;
  String _activeRouteId = '';
  String _activeRouteName = '';
  String _activeBusCode = '';

  @override
  void initState() {
    super.initState();
    _activeRouteId = widget.routeId;
    _activeRouteName = widget.routeName;
    _activeBusCode = widget.busNumber;
    _stopsFuture = _fetchStops();
  }

  Future<List<Map<String, dynamic>>> _fetchStops() async {
    // If routeId wasn't passed directly, fetch driver assignment to resolve it
    if (_activeRouteId.isEmpty) {
      final assignment = await SupabaseService.getDriverAssignment();
      if (assignment != null && assignment['route_id'] != null) {
        _activeRouteId = '${assignment['route_id']}';
        _activeRouteName = '${assignment['route_name'] ?? 'Assigned Route'}';
        _activeBusCode = '${assignment['code'] ?? ''}';
      }
    }

    if (_activeRouteId.isEmpty) {
      return [];
    }

    return await SupabaseService.getStopsForRoute(_activeRouteId);
  }

  void _reload() {
    setState(() {
      _stopsFuture = _fetchStops();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Route schedule',
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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.text),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.text, size: 22),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _stopsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

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
                      'Could not load route schedule',
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
                      ),
                      onPressed: _reload,
                      child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          final stops = snapshot.data ?? [];

          if (stops.isEmpty) {
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
                      'No route schedule available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select an active bus from the Driver Console to view its scheduled waypoints and timings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppTheme.muted, fontFamily: 'Inter', height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            children: [
              // Route Header Banner
              Container(
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_activeBusCode.isNotEmpty)
                            Text(
                              'Bus $_activeBusCode',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                fontFamily: 'Inter',
                              ),
                            ),
                          Text(
                            _activeRouteName.isNotEmpty ? _activeRouteName : 'Campus Transit Route',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            '${stops.length} scheduled stops',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.muted,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stop List matching Figma DriverScheduledStop (2:4620)
              ...List.generate(stops.length, (idx) {
                final stop = stops[idx];
                final seq = stop['sequence_no'] ?? (idx + 1);
                final stopName = stop['name'] ?? 'Stop';
                final morningTime = stop['scheduled_morning'] ?? 'Not set';
                final eveningTime = stop['scheduled_evening'] ?? 'Not set';
                final seqStr = seq < 10 ? '0$seq' : '$seq';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(16.0),
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
                      // Stop Identity Row matching Figma node 2:4621
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              seqStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stopName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Morning and Evening Timings matching Figma node 2:4625
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Morning',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.muted,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    morningTime,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.text,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Evening',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.muted,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    eveningTime,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.text,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
