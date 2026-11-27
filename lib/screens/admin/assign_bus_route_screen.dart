import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Admin Assign Bus Override Screen matching Figma AM08 · Assign bus override (12:3376),
/// AM20 · Route picker (12:3388), and AD08 (12:3357).
class AssignBusRouteScreen extends StatefulWidget {
  const AssignBusRouteScreen({super.key});

  @override
  State<AssignBusRouteScreen> createState() => _AssignBusRouteScreenState();
}

class _AssignBusRouteScreenState extends State<AssignBusRouteScreen> {
  String? _selectedBusId;
  String? _selectedDriverId;
  String? _selectedRouteId;

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _assignments = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.getBuses(),
        SupabaseService.getDrivers(),
        SupabaseService.getRoutes(),
        SupabaseService.getAssignedBuses(),
      ]);

      final b = results[0];
      final d = results[1].where((x) => x['approved'] == true).toList();
      final r = results[2];
      final a = results[3];

      if (mounted) {
        setState(() {
          _buses = b;
          _drivers = d;
          _routes = r;
          _assignments = a;
          _isLoading = false;

          if (_buses.isNotEmpty && _selectedBusId == null) {
            _selectedBusId = _buses.first['id']?.toString();
          }
          if (_drivers.isNotEmpty && _selectedDriverId == null) {
            _selectedDriverId = _drivers.first['id']?.toString();
          }
          if (_routes.isNotEmpty && _selectedRouteId == null) {
            _selectedRouteId = _routes.first['id']?.toString();
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

  Map<String, dynamic>? get _currentSelectedBus {
    if (_selectedBusId == null) return null;
    try {
      return _buses.firstWhere((b) => b['id']?.toString() == _selectedBusId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _currentSelectedDriver {
    if (_selectedDriverId == null) return null;
    try {
      return _drivers.firstWhere((d) => d['id']?.toString() == _selectedDriverId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmOverride() async {
    if (_selectedBusId == null || _selectedDriverId == null || _selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bus, an approved driver / faculty-incharge, and a route.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.assignBus(
        busId: _selectedBusId!,
        driverId: _selectedDriverId!,
        routeId: _selectedRouteId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus assigned & active route updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _releaseCurrentBus() async {
    if (_selectedBusId == null) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.adminReleaseBus(_selectedBusId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus released from active driver / faculty-incharge.'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Release failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        final currentBus = _currentSelectedBus;
        final currentDriver = _currentSelectedDriver;

        final busCode = currentBus?['bus_number'] ?? currentBus?['code'] ?? 'Bus';
        final driverName = currentDriver?['name'] ?? 'Selected driver';

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
              'Assign Bus Override',
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
                onPressed: _loadAllData,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                            const SizedBox(height: 12),
                            Text('Failed to load fleet data: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
                            const SizedBox(height: 16),
                            CustomButton(label: 'Retry', height: 44, onPressed: _loadAllData),
                          ],
                        ),
                      ),
                    )
                  : SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bus selector (Figma node 12:9151)
                            const Text(
                              'Bus fleet vehicle',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(color: AppTheme.border),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBusId,
                                  isExpanded: true,
                                  items: _buses.map((b) {
                                    final code = b['bus_number'] ?? b['code'] ?? 'Bus';
                                    final plate = b['number_plate'] ?? b['label'] ?? '';
                                    return DropdownMenuItem<String>(
                                      value: b['id']?.toString(),
                                      child: Text(
                                        plate.isNotEmpty ? '$code · $plate' : code.toString(),
                                        style: const TextStyle(fontFamily: 'Inter', color: AppTheme.text),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedBusId = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Approved driver selector (Figma node 12:9162)
                            const Text(
                              'Approved Driver / Faculty-Incharge',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(color: AppTheme.border),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDriverId,
                                  isExpanded: true,
                                  items: _drivers.map((d) {
                                    final name = d['name'] ?? 'Driver / Faculty-Incharge';
                                    final email = d['email'] ?? '';
                                    return DropdownMenuItem<String>(
                                      value: d['id']?.toString(),
                                      child: Text(
                                        '$name · $email',
                                        style: const TextStyle(fontFamily: 'Inter', color: AppTheme.text),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedDriverId = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Route selector (Figma node 12:9173)
                            const Text(
                              'Target Route',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.text, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(color: AppTheme.border),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRouteId,
                                  isExpanded: true,
                                  items: _routes.map((r) {
                                    final name = r['name'] ?? 'Route';
                                    final code = r['code'] ?? '';
                                    return DropdownMenuItem<String>(
                                      value: r['id']?.toString(),
                                      child: Text(
                                        code.isNotEmpty ? '$code · $name' : name.toString(),
                                        style: const TextStyle(fontFamily: 'Inter', color: AppTheme.text),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedRouteId = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Override warning banner (Figma node 12:9184 & 12:9185)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                border: Border.all(color: const Color(0xFFFDBA74)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: Color(0xFF9A3412), size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '$busCode’s active trip will re-synchronize. $driverName will be assigned to this vehicle and route.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9A3412),
                                        fontFamily: 'Inter',
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Actions row (Figma node 12:9186)
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    label: 'Confirm override',
                                    height: 48,
                                    isLoading: _isSaving,
                                    onPressed: _confirmOverride,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomButton(
                                    label: 'Release bus',
                                    height: 48,
                                    backgroundColor: AppTheme.error,
                                    onPressed: _releaseCurrentBus,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Current Fleet Assignments
                            const Text(
                              'Current Active Pairings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_assignments.isEmpty) ...[
                              const Text('No bus assignments active.', style: TextStyle(color: AppTheme.muted, fontFamily: 'Inter')),
                            ] else ...[
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _assignments.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = _assignments[index];
                                  final code = item['busNumber'] ?? 'Bus';
                                  final driver = item['driverName'] ?? 'Driver / Faculty-Incharge';
                                  final route = item['routeName'] ?? 'Route';

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('$code · $route', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                        Text(driver, style: const TextStyle(color: AppTheme.muted, fontFamily: 'Inter', fontSize: 13)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
