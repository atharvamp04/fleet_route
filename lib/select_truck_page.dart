import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectTruckPage extends StatefulWidget {
  final int deliveryId;

  SelectTruckPage({required this.deliveryId});

  @override
  _SelectTruckPageState createState() => _SelectTruckPageState();
}

class _SelectTruckPageState extends State<SelectTruckPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _trucks = [];
  Map<String, dynamic>? _selectedTruckDetails;
  Map<String, dynamic>? _driverDetails;

  @override
  void initState() {
    super.initState();
    _fetchAvailableTrucks();
  }

  /// Fetch available trucks that are free
  Future<void> _fetchAvailableTrucks() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('truck')
          .select()
          .eq('status', 'Free')
          .order('truck_id', ascending: true);

      setState(() {
        _trucks = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching trucks: $e')));
    }
  }

  /// Fetch truck and driver details
  Future<void> _fetchTruckAndDriverDetails(int truckId) async {
    setState(() => _isLoading = true);

    try {
      // Fetch truck details
      final truckResponse = await Supabase.instance.client
          .from('truck')
          .select()
          .eq('truck_id', truckId)
          .single();

      // Fetch driver details assigned to this truck
      final driverResponse = await Supabase.instance.client
          .from('driver')
          .select('driver_id, license_number, status, rating')
          .eq('assigned_truck_id', truckId)
          .single();

      if (driverResponse == null) {
        throw Exception("No driver assigned to this truck.");
      }

      final String driverId = driverResponse['driver_id'];

      // Fetch driver details from Users table
      final userResponse = await Supabase.instance.client
          .from('Users')
          .select('name, mobile')
          .eq('user_id', driverId)
          .single();


      setState(() {
        _selectedTruckDetails = truckResponse;
        _driverDetails = {
          'name': userResponse['name'],
          'mobile': userResponse['mobile'],
          'license_number': driverResponse['license_number'],
          'status': driverResponse['status'],
          'rating': driverResponse['rating'],
        };
        _isLoading = false;
      });

      _showTruckDetailsDialog();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching details: $e')));
    }
  }

  /// Assign truck to the delivery
  Future<void> _assignTruck(int truckId) async {
    setState(() => _isLoading = true);

    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // Insert into delivery_truck_mapping
      await Supabase.instance.client.from('delivery_truck_mapping').insert({
        'delivery_id': widget.deliveryId,
        'truck_id': truckId,
        'assignment_status': 'Active',
        'assigned_at': timestamp,
        'updated_at': timestamp,
      });

      // Update truck status to 'Busy'
      await Supabase.instance.client.from('truck').update({
        'status': 'Busy',
        'updated_at': timestamp,
      }).eq('truck_id', truckId);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Truck $truckId assigned successfully!")));

      _fetchAvailableTrucks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error assigning truck: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Show truck & driver details in a dialog
  void _showTruckDetailsDialog() {
    if (_selectedTruckDetails == null || _driverDetails == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Truck & Driver Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("🚛 Truck ID: ${_selectedTruckDetails!['truck_id']}"),
              Text("📍 Location: (${_selectedTruckDetails!['latitude']}, ${_selectedTruckDetails!['longitude']})"),
              Text("⚡ Fuel Level: ${_selectedTruckDetails!['fuel_level']}%"),
              Text("🛠 Last Service: ${_selectedTruckDetails!['last_service_date']}"),
              Divider(),
              Text("👤 Driver: ${_driverDetails!['name']}"),
              Text("📞 Mobile: ${_driverDetails!['mobile']}"),
              Text("🚗 License No: ${_driverDetails!['license_number']}"),
              Text("⭐ Rating: ${_driverDetails!['rating']}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _assignTruck(_selectedTruckDetails!['truck_id']);
              },
              child: Text("Assign Truck"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select a Truck')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _trucks.isEmpty
          ? Center(child: Text("No available trucks"))
          : ListView.builder(
        itemCount: _trucks.length,
        itemBuilder: (context, index) {
          final truck = _trucks[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text("Truck ID: ${truck['truck_id']}"),
              subtitle: Text("Capacity: ${truck['capacity']} tons"),
              trailing: Icon(Icons.local_shipping, color: Colors.blue),
              onTap: () => _fetchTruckAndDriverDetails(truck['truck_id']),
            ),
          );
        },
      ),
    );
  }
}
