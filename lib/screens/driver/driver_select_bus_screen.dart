import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../shared/theme.dart';
import '../../shared/status_chip.dart';

/// Driver Select Bus Screen matching Figma 05 · Select your bus (2:1672)
class DriverSelectBusScreen extends StatefulWidget {
  const DriverSelectBusScreen({super.key});

  @override
  State<DriverSelectBusScreen> createState() => _DriverSelectBusScreenState();
}

class _DriverSelectBusScreenState extends State<DriverSelectBusScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  String? _claiming;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final token = ++_searchToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.searchBuses(q, limit: 30);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = rows);
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() => _error = 'Could not load buses. Check connection.');
    } finally {
      if (mounted && token == _searchToken) setState(() => _loading = false);
    }
  }

  Future<void> _claim(Map<String, dynamic> bus) async {
    final code = '${bus['code']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
        title: Text(
          'Confirm Bus $code',
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate: ${bus['label'] ?? '-'}', style: const TextStyle(fontFamily: 'Inter')),
            const SizedBox(height: 4),
            Text('Route: ${bus['route_name'] ?? 'Not set'}', style: const TextStyle(fontFamily: 'Inter')),
            const SizedBox(height: 12),
            const Text(
              'Only select the bus you actually drive. Students will see your live location on it.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13, fontFamily: 'Inter'),
            ),
          ],
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
            child: const Text('Confirm & Drive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _claiming = code);
    try {
      await SupabaseService.claimBus(code);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (_) => false);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error, duration: const Duration(seconds: 5)),
      );
      _search(_controller.text);
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  Future<void> _openAddBusDialog() async {
    final busNumCtrl = TextEditingController(text: _controller.text.trim());
    final plateCtrl = TextEditingController();
    String? selectedRouteId;
    List<Map<String, dynamic>> routes = [];
    bool loadingRoutes = true;

    try {
      routes = await SupabaseService.getRoutes();
      if (routes.isNotEmpty) selectedRouteId = routes.first['id'] as String?;
      loadingRoutes = false;
    } catch (_) {
      loadingRoutes = false;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            title: const Row(
              children: [
                Icon(Icons.directions_bus_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Add & Claim My Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your bus details to register and start sharing location:',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: busNumCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Bus Number (e.g. 112)',
                      labelStyle: const TextStyle(fontFamily: 'Inter'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Number Plate (e.g. AP 30 TC 1001)',
                      labelStyle: const TextStyle(fontFamily: 'Inter'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loadingRoutes)
                    const Center(child: LinearProgressIndicator(color: AppTheme.primaryColor))
                  else
                    DropdownButtonFormField<String>(
                      value: selectedRouteId,
                      decoration: InputDecoration(
                        labelText: 'Assigned Route',
                        labelStyle: const TextStyle(fontFamily: 'Inter'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: routes.map((r) {
                        return DropdownMenuItem<String>(
                          value: r['id'] as String,
                          child: Text((r['name'] ?? 'Route').toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedRouteId = val),
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
                onPressed: () {
                  final code = busNumCtrl.text.trim();
                  if (code.isEmpty) return;
                  Navigator.pop(ctx, {
                    'code': code,
                    'plate': plateCtrl.text.trim(),
                    'routeId': selectedRouteId,
                  });
                },
                child: const Text('Register & Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    final code = result['code'] as String;
    final plate = result['plate'] as String;
    final routeId = result['routeId'] as String?;

    setState(() => _claiming = code);
    try {
      await SupabaseService.driverRegisterAndClaimBus(
        busCode: code,
        plate: plate,
        routeId: routeId,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/driver_dashboard', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver_login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Select Your Bus'),
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Register My Bus',
            onPressed: _openAddBusDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Focused Search Input matching Figma DriverFocusedSearch (2:3517)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                  border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  autofocus: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Type your bus number or plate',
                    hintStyle: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryColor, size: 24),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.muted, size: 20),
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppTheme.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),

            // Results count info matching Figma S05
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                '${_results.length} buses · Up to 30 results',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.muted,
                  fontFamily: 'Inter',
                ),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontFamily: 'Inter')),
              ),

            // Bus List matching Figma DriverBusResult (2:3522)
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppTheme.primarySubtle,
                                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                              ),
                              child: const Icon(Icons.directions_bus_rounded, size: 36, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bus not in list yet?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.text,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add your bus number and select your route right now:',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted, fontSize: 14, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Register My Bus & Route'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                ),
                              ),
                              onPressed: _openAddBusDialog,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = _results[i];
                        final mine = b['is_mine'] == true;
                        final taken = b['is_taken'] == true && !mine;
                        final isClaimingThis = _claiming == '${b['code']}';

                        return GestureDetector(
                          onTap: (taken || _claiming != null) ? null : () => _claim(b),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A0F172A),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Bus icon avatar (48x48 rounded 12px)
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: taken ? AppTheme.surfaceSubtle : AppTheme.primarySubtle,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                                      ),
                                      child: Icon(
                                        Icons.directions_bus_rounded,
                                        color: taken ? AppTheme.muted : AppTheme.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Bus number & plate
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bus ${b['code']}',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: taken ? AppTheme.muted : AppTheme.text,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${b['label'] ?? 'Plate not registered'}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.muted,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Chip matching Figma
                                    if (isClaimingThis)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                      )
                                    else
                                      StatusChip(
                                        type: mine
                                            ? StatusChipType.yours
                                            : (taken ? StatusChipType.taken : StatusChipType.select),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Route Name
                                Text(
                                  'Route: ${b['route_name'] ?? 'College Express Shuttle'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                    color: taken ? AppTheme.muted.withOpacity(0.7) : AppTheme.text,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer safety notes matching Figma 2:3939 & 2:3940
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppTheme.surface,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Taken buses can’t be selected.',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted, fontFamily: 'Inter'),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Select only while the bus is safely stopped.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.text, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
