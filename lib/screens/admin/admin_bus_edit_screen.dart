import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Admin Bus Edit Screen matching Figma AM04 · Edit bus (12:3372) and AD04 (12:3353).
class AdminBusEditScreen extends StatefulWidget {
  final String busId;
  final String busNumber;
  final String numberPlate;
  final String? routeId;
  final int? capacity;
  final bool? active;

  const AdminBusEditScreen({
    super.key,
    required this.busId,
    required this.busNumber,
    required this.numberPlate,
    this.routeId,
    this.capacity,
    this.active,
  });

  @override
  State<AdminBusEditScreen> createState() => _AdminBusEditScreenState();
}

class _AdminBusEditScreenState extends State<AdminBusEditScreen> {
  late final TextEditingController _busNumberController;
  late final TextEditingController _numberPlateController;
  late final TextEditingController _capacityController;

  String? _selectedRouteId;
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = false;
  bool _loadingRoutes = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _busNumberController = TextEditingController(text: widget.busNumber);
    _numberPlateController = TextEditingController(text: widget.numberPlate);
    _capacityController = TextEditingController(text: widget.capacity?.toString() ?? '48');
    _selectedRouteId = widget.routeId;
    _isActive = widget.active ?? true;
    _loadRoutes();
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _numberPlateController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await SupabaseService.getRoutes();
      if (mounted) {
        setState(() {
          _routes = routes;
          _loadingRoutes = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRoutes = false);
      }
    }
  }

  Future<void> _updateBus() async {
    final busNumber = _busNumberController.text.trim();
    final numberPlate = _numberPlateController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 48;

    if (busNumber.isEmpty || numberPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both bus number and plate!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateBus(
        busId: widget.busId,
        busNumber: busNumber,
        numberPlate: numberPlate,
        routeId: _selectedRouteId,
        capacity: capacity,
        active: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating bus: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Edit bus ${widget.busNumber}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus number field
                  CustomTextField(
                    label: 'Bus number',
                    controller: _busNumberController,
                    hintText: 'e.g. 112, 104, Shuttle 1',
                  ),
                  const SizedBox(height: 16),

                  // Plate field
                  CustomTextField(
                    label: 'Number Plate',
                    controller: _numberPlateController,
                    hintText: 'e.g. AP 30 TC 1001',
                  ),
                  const SizedBox(height: 16),

                  // Capacity field
                  CustomTextField(
                    label: 'Capacity (Seats)',
                    controller: _capacityController,
                    hintText: 'e.g. 48',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Default route dropdown
                  const Text(
                    'Default route',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.text,
                      fontFamily: 'Inter',
                    ),
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
                    child: _loadingRoutes
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedRouteId,
                              isExpanded: true,
                              hint: const Text(
                                'Select default route',
                                style: TextStyle(color: AppTheme.muted, fontFamily: 'Inter', fontSize: 15),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('No route assigned', style: TextStyle(fontFamily: 'Inter', color: AppTheme.muted)),
                                ),
                                ..._routes.map((r) {
                                  return DropdownMenuItem<String?>(
                                    value: r['id']?.toString(),
                                    child: Text(
                                      r['name']?.toString() ?? 'Route',
                                      style: const TextStyle(fontFamily: 'Inter', color: AppTheme.text),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (val) => setState(() => _selectedRouteId = val),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Active Switch toggle (Figma node 12:3937)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bus active in fleet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.text,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Changes Button (Figma node 2:572)
                  CustomButton(
                    label: 'Save changes',
                    height: 48,
                    isLoading: _isLoading,
                    onPressed: _updateBus,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
