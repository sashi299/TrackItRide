import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_textfield.dart';
import '../../shared/theme.dart';

/// Admin Register Bus Screen matching Figma AM19 · Add bus (12:3387) and AD19 (12:3368).
class AdminRegisterBusScreen extends StatefulWidget {
  final String? busId;
  final String? busNumber;
  final String? numberPlate;
  final String? routeId;
  final int? capacity;

  const AdminRegisterBusScreen({
    super.key,
    this.busId,
    this.busNumber,
    this.numberPlate,
    this.routeId,
    this.capacity,
  });

  @override
  State<AdminRegisterBusScreen> createState() => _AdminRegisterBusScreenState();
}

class _AdminRegisterBusScreenState extends State<AdminRegisterBusScreen> {
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _numberPlateController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '48');
  String? _selectedRouteId;
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = false;
  bool _loadingRoutes = true;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.busId != null) {
      _busNumberController.text = widget.busNumber ?? '';
      _numberPlateController.text = widget.numberPlate ?? '';
      _capacityController.text = widget.capacity?.toString() ?? '48';
      _selectedRouteId = widget.routeId;
    }
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
          if (_selectedRouteId == null && _routes.isNotEmpty && widget.busId == null) {
            _selectedRouteId = _routes.first['id'] as String?;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRoutes = false);
      }
    }
  }

  Future<void> _saveBus() async {
    final busNumber = _busNumberController.text.trim();
    final numberPlate = _numberPlateController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim()) ?? 48;

    if (busNumber.isEmpty || numberPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a bus number and number plate!'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.busId == null) {
        // Register brand new bus
        await SupabaseService.addBus(
          busNumber: busNumber,
          numberPlate: numberPlate,
          capacity: capacity,
          routeId: _selectedRouteId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bus registered to fleet successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Update existing bus
        await SupabaseService.updateBus(
          busId: widget.busId!,
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bus: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.busId != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit bus ${widget.busNumber}' : 'Add bus',
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
                  // Bus number field (Figma node 12:8687)
                  CustomTextField(
                    label: 'Bus number',
                    controller: _busNumberController,
                    hintText: 'Enter bus number (e.g. 112)',
                  ),
                  const SizedBox(height: 16),

                  // Plate field
                  CustomTextField(
                    label: 'Plate',
                    controller: _numberPlateController,
                    hintText: 'AP 30 TC 0000',
                  ),
                  const SizedBox(height: 16),

                  // Capacity field
                  CustomTextField(
                    label: 'Capacity',
                    controller: _capacityController,
                    hintText: 'Number of seats (e.g. 48)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Default route dropdown (Figma node 12:8729 & 12:8740)
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
                  const SizedBox(height: 4),
                  const Text(
                    'Search by name or code · routes configured in system',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active toggle
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

                  // Add bus button (Figma node 2:572)
                  CustomButton(
                    label: isEditing ? 'Save changes' : 'Add bus',
                    height: 48,
                    isLoading: _isLoading,
                    onPressed: _saveBus,
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
