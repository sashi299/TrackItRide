import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminBusEditScreen extends StatefulWidget {
  final String busId;
  final String busNumber;
  final String numberPlate;

  const AdminBusEditScreen({
    super.key,
    required this.busId,
    required this.busNumber,
    required this.numberPlate,
  });

  @override
  _AdminBusEditScreenState createState() => _AdminBusEditScreenState();
}

class _AdminBusEditScreenState extends State<AdminBusEditScreen> {
  final _busNumberController = TextEditingController();
  final _numberPlateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _busNumberController.text = widget.busNumber;
    _numberPlateController.text = widget.numberPlate;
  }

  Future<void> _updateBus() async {
    final busNumber = _busNumberController.text.trim();
    final numberPlate = _numberPlateController.text.trim();

    if (busNumber.isEmpty || numberPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateBus(
        busId: widget.busId,
        busNumber: busNumber,
        numberPlate: numberPlate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus updated successfully in Supabase!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating bus: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _busNumberController,
              decoration: const InputDecoration(
                labelText: 'Bus Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberPlateController,
              decoration: const InputDecoration(
                labelText: 'Number Plate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _updateBus,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Update Bus'),
                  ),
          ],
        ),
      ),
    );
  }
}
