import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';
import '../../shared/custom_button.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _busInputController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Profile data
  String _role = 'student';
  String? _currentEmail;
  String? _selectedBusId;
  String? _selectedBusCode;
  String? _selectedBusLabel;
  String? _selectedRouteId;
  String? _selectedRouteName;
  String? _selectedStopId;
  String? _selectedStopName;

  // Search & dynamic sync
  Timer? _debounce;
  List<Map<String, dynamic>> _busSearchResults = [];
  bool _isSearchingBuses = false;
  List<Map<String, dynamic>> _routeStops = [];
  bool _isLoadingStops = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busInputController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await SupabaseService.getMyCommuterProfile();
      if (!mounted) return;

      if (profile != null) {
        _role = (profile['role'] ?? 'student').toString().toLowerCase();
        if (_role != 'student' && _role != 'faculty') {
          _role = 'student';
        }
        _currentEmail = profile['email'] ?? SupabaseService.currentEmail;
        _nameController.text = profile['name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';

        _selectedBusId = profile['default_bus_id'];
        _selectedBusCode = profile['bus_code'];
        _selectedBusLabel = profile['bus_label'];
        _selectedRouteId = profile['route_id'];
        _selectedRouteName = profile['route_name'];
        _selectedStopId = profile['boarding_stop_id'];
        _selectedStopName = profile['stop_name'];

        if (_selectedBusCode != null) {
          _busInputController.text = _selectedBusCode!;
        }

        if (_selectedRouteId != null) {
          await _loadStopsForRoute(_selectedRouteId!);
        }
      } else {
        _currentEmail = SupabaseService.currentEmail;
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = 'Failed to load profile: $e';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStopsForRoute(String routeId) async {
    setState(() => _isLoadingStops = true);
    try {
      final stops = await SupabaseService.getStopsForRoute(routeId);
      if (mounted) {
        setState(() {
          _routeStops = stops;
          if (_selectedStopId != null) {
            final exists = stops.any((s) => '${s['id']}' == _selectedStopId);
            if (!exists) {
              _selectedStopId = null;
              _selectedStopName = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStops = false);
    }
  }

  void _onBusInputChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _searchBuses(query));
  }

  Future<void> _searchBuses(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      if (mounted) setState(() => _busSearchResults = []);
      return;
    }

    setState(() => _isSearchingBuses = true);
    try {
      final results = await SupabaseService.findBusesByQuery(clean);
      if (!mounted) return;
      setState(() => _busSearchResults = results);
    } catch (e) {
      debugPrint('Error searching buses: $e');
    } finally {
      if (mounted) setState(() => _isSearchingBuses = false);
    }
  }

  void _selectBus(Map<String, dynamic> bus) async {
    final busId = '${bus['id']}';
    final code = '${bus['code']}';
    final label = '${bus['label'] ?? ''}';
    final routeId = bus['default_route_id'] as String?;

    setState(() {
      _selectedBusId = busId;
      _selectedBusCode = code;
      _selectedBusLabel = label;
      _selectedRouteId = routeId;
      _selectedStopId = null;
      _selectedStopName = null;
      _busInputController.text = code;
      _busSearchResults = [];
    });

    if (routeId != null && routeId.isNotEmpty) {
      await _loadStopsForRoute(routeId);
    } else {
      setState(() => _routeStops = []);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.updateCommuterProfile(
        busId: _selectedBusId,
        routeId: _selectedRouteId,
        stopId: _selectedStopId,
        role: _role,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile and bus sync settings saved!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Commuter Profile'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter')),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          onPressed: _loadProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 16),

                      // Role Selector Card
                      _buildRoleSelectorCard(),
                      const SizedBox(height: 16),

                      // Current Sync Status Card
                      _buildSyncStatusCard(),
                      const SizedBox(height: 16),

                      // Enter Bus Number Card
                      _buildEnterBusCard(),
                      const SizedBox(height: 16),

                      // Boarding Stop Selection Card
                      _buildBoardingStopCard(),
                      const SizedBox(height: 24),

                      // Save Button
                      CustomButton(
                        label: 'Save & Sync Bus Settings',
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
            child: Icon(
              _role == 'faculty' ? Icons.school_rounded : Icons.person_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isNotEmpty ? _nameController.text : (_currentEmail ?? 'Commuter'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentEmail ?? '',
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  ),
                  child: Text(
                    _role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'I am commuting as:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter', color: AppTheme.text),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _role = 'student'),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _role == 'student' ? AppTheme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: _role == 'student' ? Colors.white : AppTheme.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _role == 'student' ? Colors.white : AppTheme.muted,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _role = 'faculty'),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _role == 'faculty' ? AppTheme.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: _role == 'faculty' ? Colors.white : AppTheme.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Faculty',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _role == 'faculty' ? Colors.white : AppTheme.muted,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    final hasBus = _selectedBusCode != null && _selectedBusCode!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasBus ? AppTheme.successBg : AppTheme.warningBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Row(
        children: [
          Icon(
            hasBus ? Icons.check_circle_rounded : Icons.info_rounded,
            color: hasBus ? AppTheme.success : AppTheme.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBus ? 'Active Sync: Bus $_selectedBusCode' : 'No Default Bus Selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: hasBus ? AppTheme.success : AppTheme.warning,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasBus
                      ? 'Route: ${_selectedRouteName ?? "College Route"} • Stop: ${_selectedStopName ?? "All stops"}'
                      : 'Enter your bus number below to receive live departure and proximity notifications.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasBus ? AppTheme.success.withOpacity(0.9) : AppTheme.warning.withOpacity(0.9),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterBusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'Enter Your Bus No',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', color: AppTheme.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Type your college bus number or license plate to sync automatically.',
            style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            ),
            child: TextField(
              controller: _busInputController,
              onChanged: _onBusInputChanged,
              decoration: InputDecoration(
                hintText: 'e.g. 112, 1, 2, AP 30 TC 1001...',
                hintStyle: const TextStyle(color: AppTheme.muted, fontSize: 14, fontFamily: 'Inter'),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.muted, size: 20),
                suffixIcon: _isSearchingBuses
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        ),
                      )
                    : _busInputController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.muted, size: 18),
                            onPressed: () {
                              _busInputController.clear();
                              setState(() => _busSearchResults = []);
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          // Live Search Results
          if (_busSearchResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Matching Buses (Tap to sync):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.muted, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight),
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _busSearchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final b = _busSearchResults[idx];
                  final code = '${b['code']}';
                  final label = '${b['label'] ?? ''}';
                  final isSel = _selectedBusId == '${b['id']}';
                  return ListTile(
                    dense: true,
                    selected: isSel,
                    leading: Icon(
                      Icons.directions_bus_rounded,
                      color: isSel ? AppTheme.primaryColor : AppTheme.muted,
                    ),
                    title: Text(
                      'Bus $code',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                    subtitle: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'Inter')),
                    trailing: isSel
                        ? const Icon(Icons.check_rounded, color: AppTheme.primaryColor)
                        : const Text('Select', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    onTap: () => _selectBus(b),
                  );
                },
              ),
            ),
          ],

          // Currently Selected Bus Preview
          if (_selectedBusCode != null && _busSearchResults.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primarySubtle,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: Bus $_selectedBusCode (${_selectedBusLabel ?? ""})',
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedBusId = null;
                        _selectedBusCode = null;
                        _selectedBusLabel = null;
                        _selectedRouteId = null;
                        _selectedStopId = null;
                        _routeStops = [];
                        _busInputController.clear();
                      });
                    },
                    child: const Text('Change', style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoardingStopCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8),
              Text(
                'My Boarding Stop',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', color: AppTheme.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select where you board the bus. You will receive an alert when the bus is ~1.5 km away.',
            style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 12),
          if (_isLoadingStops)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            )
          else if (_routeStops.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Text(
                _selectedBusCode != null
                    ? 'No specific route stops assigned to this bus yet. The app will alert you whenever this bus starts moving!'
                    : 'Please enter your bus number first to load your route stops.',
                style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontFamily: 'Inter'),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedStopId,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                filled: true,
                fillColor: AppTheme.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              hint: const Text('Select your boarding stop', style: TextStyle(fontFamily: 'Inter')),
              items: _routeStops.map((s) {
                final id = '${s['id']}';
                final name = '${s['name']}';
                final seq = s['sequence_no'] != null ? 'Stop #${s['sequence_no']}' : '';
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text('$name ($seq)', style: const TextStyle(fontFamily: 'Inter')),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final match = _routeStops.firstWhere((s) => '${s['id']}' == val);
                setState(() {
                  _selectedStopId = val;
                  _selectedStopName = '${match['name']}';
                });
              },
            ),
        ],
      ),
    );
  }
}
