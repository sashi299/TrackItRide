import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AssignBusRouteScreen extends StatefulWidget {
  const AssignBusRouteScreen({super.key});

  @override
  _AssignBusRouteScreenState createState() => _AssignBusRouteScreenState();
}

class _AssignBusRouteScreenState extends State<AssignBusRouteScreen> {
  String? selectedBusId;
  String? selectedDriverId;
  String? selectedRouteId;

  List<Map<String, dynamic>> buses = [];
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> assignments = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      final b = await SupabaseService.getBuses();
      final d = await SupabaseService.getDrivers();
      final r = await SupabaseService.getRoutes();
      final a = await SupabaseService.getAssignedBuses();

      if (mounted) {
        setState(() {
          buses = b;
          drivers = d;
          routes = r;
          assignments = a;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveAssignment() async {
    if (selectedBusId == null || selectedDriverId == null || selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bus, a driver, and a route.')),
      );
      return;
    }

    try {
      await SupabaseService.assignBus(
        busId: selectedBusId!,
        driverId: selectedDriverId!,
        routeId: selectedRouteId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment saved to Supabase!')),
        );
        selectedBusId = null;
        selectedDriverId = null;
        selectedRouteId = null;
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Bus & Route'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create New Assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBusId,
                    hint: const Text('Select Bus'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: buses.map((b) {
                      return DropdownMenuItem<String>(
                        value: b['id'],
                        child: Text('${b['code']} - ${b['label']}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedBusId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    hint: const Text('Select Driver'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: drivers.map((d) {
                      return DropdownMenuItem<String>(
                        value: d['id'],
                        child: Text('${d['name']} (${d['email']})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedDriverId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRouteId,
                    hint: const Text('Select Route'),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: routes.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id'],
                        child: Text('${r['code']} - ${r['name']}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedRouteId = val),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveAssignment,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: const Text('Save Assignment in Supabase'),
                  ),
                  const SizedBox(height: 28),
                  const Text('Active Fleet Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  assignments.isEmpty
                      ? const Text('No assignments yet.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignments.length,
                          itemBuilder: (context, index) {
                            final a = assignments[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.airport_shuttle, color: Colors.blue),
                                title: Text('Bus: ${a['busNumber']} (${a['numberPlate']})'),
                                subtitle: Text('Driver: ${a['driverName']}\nRoute: ${a['routeName']}'),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
