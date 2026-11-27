import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Admin Route & Stop Management Screen matching Figma AM06 · Routes & Stops (12:3374),
/// AM07 · Add stop (12:3375), and AD06–AD07 (12:3355–12:3356).
class AdminRouteManagementScreen extends StatefulWidget {
  const AdminRouteManagementScreen({super.key});

  @override
  State<AdminRouteManagementScreen> createState() => _AdminRouteManagementScreenState();
}

class _AdminRouteManagementScreenState extends State<AdminRouteManagementScreen> {
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _selectedRoute;
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = true;
  bool _isLoadingStops = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final routes = await SupabaseService.getRoutes();
      if (mounted) {
        setState(() {
          _routes = routes;
          _isLoading = false;
          if (_routes.isNotEmpty) {
            _selectRoute(_routes.first);
          }
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

  Future<void> _selectRoute(Map<String, dynamic> route) async {
    setState(() {
      _selectedRoute = route;
      _isLoadingStops = true;
    });
    try {
      final routeId = route['id']?.toString() ?? '';
      final stops = await SupabaseService.getStops(routeId);
      if (mounted) {
        setState(() {
          _stops = List.from(stops);
          _isLoadingStops = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStops = false);
      }
    }
  }

  Future<void> _addRouteDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: const Text('Create New Route', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: 'Route Name',
              controller: nameController,
              hintText: 'e.g. Tekkali - Srikakulam Express',
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Route Code',
              controller: codeController,
              hintText: 'e.g. R03, R08',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final code = codeController.text.trim();
              if (name.isNotEmpty && code.isNotEmpty) {
                await SupabaseService.addRoute(
                  routeName: name,
                  routeCode: code,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadRoutes();
              }
            },
            child: const Text('Create Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// AM07 · Add stop modal (12:3375)
  Future<void> _addStopDialog() async {
    if (_selectedRoute == null) return;
    final routeId = _selectedRoute!['id']?.toString() ?? '';

    final nameController = TextEditingController();
    final seqController = TextEditingController(text: (_stops.length + 1).toString());
    final latController = TextEditingController(text: '18.5665');
    final lngController = TextEditingController(text: '84.1952');
    final morningController = TextEditingController(text: '7:30 AM');
    final eveningController = TextEditingController(text: '5:00 PM');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: const Text('Add Stop waypoint', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'Stop Name',
                controller: nameController,
                hintText: 'e.g. Kotabommali Junction',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Sequence Number',
                controller: seqController,
                hintText: '1, 2, 3...',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Latitude',
                      controller: latController,
                      hintText: '18.5702',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      label: 'Longitude',
                      controller: lngController,
                      hintText: '84.1853',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Morning Time',
                      controller: morningController,
                      hintText: '7:30 AM',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      label: 'Evening Time',
                      controller: eveningController,
                      hintText: '5:00 PM',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final seq = int.tryParse(seqController.text.trim()) ?? 1;
              final lat = double.tryParse(latController.text.trim()) ?? 0.0;
              final lng = double.tryParse(lngController.text.trim()) ?? 0.0;

              if (name.isNotEmpty && lat != 0.0 && lng != 0.0) {
                await SupabaseService.addStop(
                  routeId: routeId,
                  name: name,
                  sequenceNo: seq,
                  latitude: lat,
                  longitude: lng,
                  scheduledMorning: morningController.text.trim(),
                  scheduledEvening: eveningController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _selectRoute(_selectedRoute!);
              }
            },
            child: const Text('Save Stop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStop(String stopId) async {
    try {
      await SupabaseService.deleteStop(stopId);
      if (_selectedRoute != null) {
        _selectRoute(_selectedRoute!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete stop: $e'), backgroundColor: AppTheme.error),
        );
      }
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
              'Routes & Stops',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
                fontFamily: 'Inter',
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                onPressed: _addRouteDialog,
                tooltip: 'Create Route',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.text),
                onPressed: _loadRoutes,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1080 : 540),
                child: Column(
                  children: [
                    // Route Selection & Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route Selector
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                              border: Border.all(color: AppTheme.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                value: _selectedRoute,
                                isExpanded: true,
                                hint: const Text('Select a route', style: TextStyle(fontFamily: 'Inter', color: AppTheme.muted)),
                                items: _routes.map((r) {
                                  final name = r['name'] ?? 'Route';
                                  final code = r['code'] ?? '';
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: r,
                                    child: Text(
                                      code.isNotEmpty ? '$code · $name' : name,
                                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: AppTheme.text),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) _selectRoute(val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Header details & Drag instruction (Figma node 12:8946 & 12:8947)
                          if (_selectedRoute != null) ...[
                            Text(
                              '${_selectedRoute!['code'] ?? 'Route'} · ${_selectedRoute!['name'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Morning / evening · Ordered stops for this transit route',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Route action buttons (Add Stop, Create Route)
                          Row(
                            children: [
                              Expanded(
                                child: CustomButton(
                                  label: '+ Add stop',
                                  height: 44,
                                  onPressed: _addStopDialog,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomButton(
                                  label: '+ New route',
                                  isSecondary: true,
                                  height: 44,
                                  onPressed: _addRouteDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Stops list
                    Expanded(
                      child: _buildStopsList(),
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

  Widget _buildStopsList() {
    if (_isLoading || _isLoadingStops) {
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
              Text('Failed to load routes: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              CustomButton(label: 'Retry', height: 44, onPressed: _loadRoutes),
            ],
          ),
        ),
      );
    }

    if (_stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route_rounded, size: 56, color: AppTheme.muted.withOpacity(0.5)),
              const SizedBox(height: 14),
              const Text(
                'No stops assigned to this route',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Click "+ Add stop" above to add waypoints, pickup coordinates, and schedules.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _stops.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final stop = _stops[index];
        final stopId = stop['id']?.toString() ?? '';
        final stopName = stop['name']?.toString() ?? 'Stop ${index + 1}';
        final seq = (index + 1).toString().padLeft(2, '0');
        final morning = stop['scheduled_morning']?.toString() ?? '7:00 AM';
        final evening = stop['scheduled_evening']?.toString() ?? '5:00 PM';

        return Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              // Drag / Grip Icon (Figma node 12:8950)
              const Icon(Icons.drag_indicator_rounded, color: AppTheme.muted, size: 22),
              const SizedBox(width: 8),

              // Sequence number badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  seq,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Stop details
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$morning / $evening',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              // Delete stop button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                onPressed: () => _deleteStop(stopId),
              ),
            ],
          ),
        );
      },
    );
  }
}
