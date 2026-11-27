import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/gps_tracking_service.dart';
import '../../shared/custom_button.dart';
import '../../shared/theme.dart';

/// Driver Profile Screen matching Figma 16 · Driver profile (2:1683)
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  late Future<Map<String, dynamic>?> _driverData;

  Future<Map<String, dynamic>?> _fetchDriverData() async {
    final email = SupabaseService.currentEmail;
    if (email == null) return null;

    try {
      final user = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      final assignment = await SupabaseService.getDriverAssignment(email);

      return {
        'name': user?['name'] ?? 'Campus Driver',
        'email': email,
        'phone': user?['phone'] ?? 'Not added',
        'license_number': user?['license_number'] ?? user?['license'] ?? 'Verified on record',
        'bus_code': assignment?['code'] ?? assignment?['busNumber'] ?? 'No bus selected',
        'number_plate': assignment?['label'] ?? assignment?['numberPlate'] ?? '',
        'route_name': assignment?['route_name'] ?? assignment?['routeName'] ?? 'No route assigned',
      };
    } catch (e) {
      debugPrint('Error fetching driver profile: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _driverData = _fetchDriverData();
  }

  Future<void> _logout() async {
    await GpsTrackingService.stopTracking();
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver_login', (_) => false);
    }
  }

  Future<void> _changeBus() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: const Text('Change bus?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text(
          'This ends your active trip and frees this bus for other drivers.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await GpsTrackingService.stopTracking();
    try {
      await SupabaseService.releaseBus();
    } catch (_) {}
    if (mounted) Navigator.pushReplacementNamed(context, '/driver_select_bus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Driver / Faculty-Incharge Profile',
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
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _driverData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final data = snapshot.data ?? {};
          final name = data['name'] ?? 'Driver / Faculty-Incharge';
          final email = data['email'] ?? SupabaseService.currentEmail ?? 'driver@college.ac.in';
          final phone = data['phone'] ?? 'Not added';
          final license = data['license_number'] ?? 'AP30 2020 0012345';
          final busCode = data['bus_code'] ?? 'Not selected';
          final numberPlate = data['number_plate'] ?? '';
          final routeName = data['route_name'] ?? 'Not selected';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Identity Header matching Figma node 2:4769
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.primaryColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Driver / Faculty-Incharge',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.muted,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Account and Assignment Details matching Figma node 2:4778
                Container(
                  padding: const EdgeInsets.all(20.0),
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
                      _buildProfileRow('Phone', phone),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildProfileRow('Driving license number', license),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildProfileRow(
                        'Current bus',
                        numberPlate.isNotEmpty ? '$busCode  ·  $numberPlate' : busCode,
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _buildProfileRow('Assigned route', routeName),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons matching Figma node 2:616 & 2:627 (56px Driver touch target)
                CustomButton(
                  label: 'Change bus',
                  isSecondary: true,
                  height: 56,
                  onPressed: _changeBus,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  label: 'Log out',
                  height: 56,
                  backgroundColor: AppTheme.error,
                  onPressed: _logout,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.muted,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.text,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
