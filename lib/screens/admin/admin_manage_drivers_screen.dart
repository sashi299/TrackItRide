import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';
import 'admin_driver_edit_screen.dart';
import 'admin_register_driver_screen.dart';

/// Admin Manage Drivers Screen matching Figma AM05 · Drivers (12:3373),
/// AD05 (12:3354), AM14 · Release (12:3382), and AM15 · Reject (12:3383).
class AdminManageDriversScreen extends StatefulWidget {
  const AdminManageDriversScreen({super.key});

  @override
  State<AdminManageDriversScreen> createState() => _AdminManageDriversScreenState();
}

class _AdminManageDriversScreenState extends State<AdminManageDriversScreen> {
  List<Map<String, dynamic>> _allDrivers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Filters: 'All', 'Pending', 'Approved'
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await SupabaseService.getDrivers();
      if (mounted) {
        setState(() {
          _allDrivers = list;
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
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  int get _pendingCount => _allDrivers.where((d) => d['approved'] != true).length;
  int get _approvedCount => _allDrivers.where((d) => d['approved'] == true).length;

  List<Map<String, dynamic>> get _filteredDrivers {
    final q = _searchController.text.trim().toLowerCase();
    return _allDrivers.where((d) {
      final isApproved = d['approved'] == true;
      if (_selectedFilter == 'Pending' && isApproved) return false;
      if (_selectedFilter == 'Approved' && !isApproved) return false;

      if (q.isNotEmpty) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        final phone = (d['phone'] ?? '').toString().toLowerCase();
        final license = (d['license_number'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !phone.contains(q) && !license.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _setApproval(String email, bool approve) async {
    try {
      await SupabaseService.setDriverApproved(email: email, approved: approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Driver approved successfully!' : 'Driver rejected/revoked.'),
            backgroundColor: approve ? AppTheme.success : AppTheme.error,
          ),
        );
        _loadDrivers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// AM15 · Reject driver confirmation (12:3383)
  void _confirmRejectDriver(String email, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_rounded, color: AppTheme.error, size: 26),
            const SizedBox(width: 8),
            Text('Reject $name?', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ],
        ),
        content: Text(
          'Are you sure you want to reject and block driver application for $name ($email)?',
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
              _setApproval(email, false);
            },
            child: const Text('Reject Driver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// AM14 · Release driver confirmation (12:3382)
  void _confirmDeleteDriver(String driverId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 26),
            const SizedBox(width: 8),
            Text('Remove $name?', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ],
        ),
        content: Text(
          'Are you sure you want to delete driver record for $name? This removes access to driver portal.',
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
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await SupabaseService.deleteDriver(driverId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Driver removed successfully!'), backgroundColor: AppTheme.success),
                  );
                  _loadDrivers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              'Drivers / Faculty-Incharge',
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
                onPressed: _loadDrivers,
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
                    // Search & Filter header
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
                                      hintText: 'Name, email or license',
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

                          // Filter chips (Figma node 12:8797)
                          Row(
                            children: [
                              _buildFilterChip('All', _allDrivers.length),
                              const SizedBox(width: 8),
                              _buildFilterChip('Pending', _pendingCount),
                              const SizedBox(width: 8),
                              _buildFilterChip('Approved', _approvedCount),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Roster actions & counts
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_allDrivers.length} registered · ${_filteredDrivers.length} shown',
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
                                    label: '+ Register Driver / Faculty',
                                    height: 40,
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AdminRegisterDriverScreen(),
                                        ),
                                      );
                                      _loadDrivers();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Drivers List
                    Expanded(
                      child: _buildDriversList(),
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
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.border,
            ),
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

  Widget _buildDriversList() {
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
              Text('Failed to load drivers: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              CustomButton(label: 'Retry', height: 44, onPressed: _loadDrivers),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredDrivers;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded, size: 56, color: AppTheme.muted.withOpacity(0.5)),
              const SizedBox(height: 14),
              const Text(
                'No matching drivers found',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.text, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try adjusting search or selecting a different status filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.muted, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      );
    }

    // Driver Cards (Figma node 12:8804 & 12:8818)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final driver = filtered[index];
        final driverId = driver['id']?.toString() ?? '';
        final name = driver['name']?.toString() ?? 'Driver / Faculty-Incharge';
        final email = driver['email']?.toString() ?? '';
        final license = driver['license_number']?.toString() ?? 'Not provided';
        final phone = driver['phone']?.toString() ?? 'Not provided';
        final assignedBus = driver['bus_code'] ?? driver['assigned_bus'] ?? 'Not assigned';
        final isApproved = driver['approved'] == true;

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
              // Identity and status (Figma node 12:8805 & 12:8819)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    ),
                    child: Text(
                      isApproved ? 'Approved' : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isApproved ? AppTheme.success : const Color(0xFF854D0E),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text(email, style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter')),
              const SizedBox(height: 4),
              Text('License: $license', style: const TextStyle(fontSize: 13, color: AppTheme.text, fontFamily: 'Inter')),
              const SizedBox(height: 4),
              Text(phone, style: const TextStyle(fontSize: 13, color: AppTheme.text, fontFamily: 'Inter')),
              const SizedBox(height: 4),
              Text('Assigned bus: $assignedBus', style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter')),
              const SizedBox(height: 14),

              // Actions
              if (!isApproved) ...[
                // Approval actions: Approve (Primary) / Reject (Destructive)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _setApproval(email, true),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _confirmRejectDriver(email, name),
                        child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Approved actions: Edit, Delete
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                            builder: (context) => AdminDriverEditScreen(
                              driverId: driverId,
                              name: name,
                              email: email,
                              phone: phone,
                              licenseNumber: license,
                            ),
                          ),
                        );
                        _loadDrivers();
                      },
                      child: const Text('Edit', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _confirmDeleteDriver(driverId, name),
                      child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
