import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

class AdminRegisterBusScreen extends StatefulWidget {
  final String? busId;
  final String? busNumber;
  final String? numberPlate;

  const AdminRegisterBusScreen({
    super.key,
    this.busId,
    this.busNumber,
    this.numberPlate,
  });

  @override
  _AdminRegisterBusScreenState createState() =>
      _AdminRegisterBusScreenState();
}

class _AdminRegisterBusScreenState extends State<AdminRegisterBusScreen> {
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _numberPlateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.busId != null) {
      _busNumberController.text = widget.busNumber ?? '';
      _numberPlateController.text = widget.numberPlate ?? '';
    }
  }

  Future<void> _saveBus() async {
    final busNumber = _busNumberController.text.trim();
    final numberPlate = _numberPlateController.text.trim();

    if (busNumber.isNotEmpty && numberPlate.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        if (widget.busId != null) {
          await SupabaseService.updateBus(
            busId: widget.busId!,
            busNumber: busNumber,
            numberPlate: numberPlate,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bus updated successfully in Supabase!')),
            );
          }
        } else {
          await SupabaseService.addBus(
            busNumber: busNumber,
            numberPlate: numberPlate,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bus added successfully to Supabase!')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving bus: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.busId == null ? 'Register New Bus' : 'Edit Bus'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _busNumberController,
              decoration: const InputDecoration(
                labelText: 'Bus Number (e.g. BUS-12)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberPlateController,
              decoration: const InputDecoration(
                labelText: 'Number Plate (e.g. KA-25-F-1234)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveBus,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(widget.busId == null ? 'Save Bus' : 'Update Bus'),
                  ),
          ],
        ),
      ),
    );
  }
}
