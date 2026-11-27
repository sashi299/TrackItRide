import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';
import 'admin_bus_edit_screen.dart';
import 'admin_register_bus_screen.dart';

/// Admin Manage Buses Screen matching Figma AM03 · Buses (12:3371),
/// AD03 · Buses (12:3352), AT02 (12:3390), and AM13 · Delete confirmation (12:3381).
class AdminManageBusesScreen extends StatefulWidget {
  const AdminManageBusesScreen({super.key});

  @override
  State<AdminManageBusesScreen> createState() => _AdminManageBusesScreenState();
}

class _AdminManageBusesScreenState extends State<AdminManageBusesScreen> {
  List<Map<String, dynamic>> _buses = [];
  Map<String, String> _routeNames = {};
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Filter state: 'All', 'Assigned', 'Unassigned', 'No route'
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.getBuses(query: _searchController.text),
        SupabaseService.getRoutes(),
      ]);

      final buses = results[0];
      final routes = results[1];

      final routeMap = <String, String>{};
      for (final r in routes) {
        if (r['id'] != null) {
          routeMap[r['id'].toString()] = (r['name'] ?? 'Route').toString();
        }
      }

      if (mounted) {
        setState(() {
          _buses = buses;
          _routeNames = routeMap;
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

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadBusesOnly(query);
    });
  }

  Future<void> _loadBusesOnly(String query) async {
    setState(() => _isLoading = true);
    try {
      final buses = await SupabaseService.getBuses(query: query);
      if (mounted) {
        setState(() {
          _buses = buses;
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

  List<Map<String, dynamic>> get _filteredBuses {
    return _buses.where((b) {
      if (_selectedFilter == 'Assigned') {
        return b['assigned_driver_id'] != null || b['driver_email'] != null;
      } else if (_selectedFilter == 'Unassigned') {
        return b['assigned_driver_id'] == null && b['driver_email'] == null;
      } else if (_selectedFilter == 'No route') {
        return b['default_route_id'] == null && b['route_id'] == null;
      }
      return true;
    }).toList();
  }

  Future<void> _deleteBus(String busId) async {
    try {
      await SupabaseService.deleteBus(busId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus removed from fleet successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadBusesOnly(_searchController.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bus: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// AM13 · Delete bus confirmation dialog (12:3381)
  void _confirmDeleteBus(String busId, String busCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 26),
            const SizedBox(width: 8),
            Text('Delete $busCode?', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove $busCode from the fleet? This action cannot be undone.',
          style: const TextStyle(fontFamily: 'Inter', color: AppTheme.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteBus(busId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _releaseBus(String busId, String busCode) async {
    try {
      await SupabaseService.adminReleaseBus(busId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver released from $busCode.'), backgroundColor: AppTheme.success),
        );
        _loadBusesOnly(_searchController.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release driver: $e'), backgroundColor: AppTheme.error),
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
              'Buses',
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
                constraints: BoxConstraints(maxWidth: isDesktop ? 1080 : 540),
                child: Column(
                  children: [
                    // Top Search & Filter Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    onChanged: _onSearchChanged,
                                    decoration: const InputDecoration(
                                      hintText: 'Bus number or plate',
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
                                      _loadBusesOnly('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Filter Chips (Figma node 12:8562)
                          Row(
                            children: [
                              _buildFilterChip('All'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Assigned'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Unassigned'),
                              const SizedBox(width: 8),
                              _buildFilterChip('No route'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Action Buttons & Count Row (Figma node 12:8571 & 12:8576)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_buses.length} buses · ${_filteredBuses.length} shown',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.muted,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Row(
                                children: [
                                  CustomButton(
                                    label: '+ Add bus',
                                    height: 40,
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AdminRegisterBusScreen(),
                                        ),
                                      );
                                      _loadData();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Buses List Body
                    Expanded(
                      child: _buildBody(),
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

  Widget _buildFilterChip(String label) {
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
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.border,
            ),
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

  Widget _buildBody() {
    // Loading State (AM16)
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    // Error State (AM18)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load buses: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Retry',
                height: 44,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredBuses;

    // Empty State (AM17)
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_bus_outlined, size: 56, color: AppTheme.muted.withOpacity(0.5)),
              const SizedBox(height: 14),
              const Text(
                'No matching buses found',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try adjusting your search query or active filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.muted, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Reset Filters',
                isSecondary: true,
                height: 44,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedFilter = 'All');
                  _loadBusesOnly('');
                },
              ),
            ],
          ),
        ),
      );
    }

    // Bus Cards List (Figma node 12:8577 & 12:8592)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bus = filtered[index];
        final busId = bus['id']?.toString() ?? '';
        final busCode = bus['bus_number']?.toString() ?? 'Bus';
        final plate = bus['number_plate']?.toString() ?? '';
        final capacity = bus['capacity']?.toString() ?? '48';
        final routeId = bus['default_route_id']?.toString() ?? bus['route_id']?.toString();
        final routeName = routeId != null ? (_routeNames[routeId] ?? 'Route $routeId') : 'No route assigned';
        final driverName = bus['driver_name'] ?? bus['driver_email'] ?? 'Unassigned';
        final isActive = bus['active'] == true;
        final isRunning = bus['status'] == 'running';

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
              // Bus identity row & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    busCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                    ),
                  ),
                  _buildStatusBadge(isRunning, isActive),
                ],
              ),
              const SizedBox(height: 4),

              // Plate and capacity
              Text(
                '$plate · $capacity seats',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 6),

              // Route name
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 16, color: AppTheme.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      routeName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.text,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Driver / Faculty-Incharge
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Driver / Faculty-Incharge: $driverName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Action buttons row (Edit, Release, Delete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminBusEditScreen(
                            busId: busId,
                            busNumber: busCode,
                            numberPlate: plate,
                          ),
                        ),
                      );
                      _loadData();
                    },
                    child: const Text('Edit', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),

                  // Release (if driver assigned)
                  if (driverName != 'Unassigned') ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.muted),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _releaseBus(busId, busCode),
                      child: const Text('Release', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Delete (Figma node 12:8585)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _confirmDeleteBus(busId, busCode),
                    child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isRunning, bool isActive) {
    if (isRunning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: const Text(
          'Running',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success, fontFamily: 'Inter'),
        ),
      );
    } else if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: const Text(
          'Active',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB), fontFamily: 'Inter'),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        ),
        child: const Text(
          'Inactive',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.muted, fontFamily: 'Inter'),
        ),
      );
    }
  }
}
