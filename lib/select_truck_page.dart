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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching trucks: $e')),
      );
    }
  }

  Future<void> _showTruckDetailsDialog(int truckId) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Fetch truck details
      final truckResponse = await supabase
          .from('truck')
          .select('capacity, status')
          .eq('truck_id', truckId)
          .single();

      // Fetch driver details assigned to this truck
      final driverResponse = await supabase
          .from('driver')
          .select('name, phone, email, license_number, rating')
          .eq('assigned_truck_id', truckId)
          .maybeSingle();

      setState(() => _isLoading = false);

      // Show dialog box with truck and driver details
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Truck & Driver Details"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("🚛 Truck ID: $truckId"),
                Text("🔋 Capacity: ${truckResponse['capacity']} kg"),
                Text("📌 Status: ${truckResponse['status']}"),
                SizedBox(height: 10),
                driverResponse != null
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👤 Driver: ${driverResponse['name']}"),
                    Text("📞 Phone: ${driverResponse['phone']}"),
                    Text("📧 Email: ${driverResponse['email']}"),
                    Text("🚗 License: ${driverResponse['license_number']}"),
                    Text("⭐ Rating: ${driverResponse['rating'] ?? 'N/A'}/5"),
                  ],
                )
                    : Text("❌ No driver assigned to this truck"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _assignTruck(truckId);
                },
                child: Text("Assign"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching truck details: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching details: $e')));
    }
  }

  /// Assign truck to the delivery
  Future<void> _assignTruck(int truckId) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // Fetch the delivery's capacity
      final deliveryResponse = await supabase
          .from('delivery')
          .select('capacity')
          .eq('delivery_id', widget.deliveryId)
          .single();

      double deliveryCapacity = (deliveryResponse['capacity'] ?? 0.0).toDouble();

      // Fetch the current truck capacity
      final truckResponse = await supabase
          .from('truck')
          .select('capacity')
          .eq('truck_id', truckId)
          .single();

      double truckCapacity = (truckResponse['capacity'] ?? 0.0).toDouble();

      // Fetch total assigned capacity for this truck
      final assignedDeliveries = await supabase
          .from('delivery_truck_mapping')
          .select('delivery_id')
          .eq('truck_id', truckId)
          .eq('assignment_status', 'Active');

      double totalAssignedCapacity = 0.0;

      for (var delivery in assignedDeliveries) {
        final deliveryData = await supabase
            .from('delivery')
            .select('capacity')
            .eq('delivery_id', delivery['delivery_id'])
            .single();

        totalAssignedCapacity += (deliveryData['capacity'] ?? 0.0);
      }

      double remainingCapacity = truckCapacity - totalAssignedCapacity;

      // Check if the truck has enough capacity
      if (remainingCapacity < deliveryCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Truck $truckId does not have enough capacity!"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Insert into delivery_truck_mapping
      await supabase.from('delivery_truck_mapping').insert({
        'delivery_id': widget.deliveryId,
        'truck_id': truckId,
        'assignment_status': 'Active',
        'assigned_at': timestamp,
        'updated_at': timestamp,
      });


      // Update truck capacity and status
      remainingCapacity -= deliveryCapacity;

      await supabase.from('truck').update({
        'capacity': remainingCapacity,
        'status': remainingCapacity > 0 ? 'Free' : 'Busy',

        'updated_at': timestamp,
      }).eq('truck_id', truckId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Truck $truckId assigned successfully!"),
          backgroundColor: Colors.green,
        ),
      );


      _fetchAvailableTrucks(); // Refresh truck list

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning truck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
              subtitle: Text("Capacity: ${truck['capacity']} kg"),
              trailing: Icon(Icons.local_shipping, color: Colors.blue),

              onTap: () => _showTruckDetailsDialog(truck['truck_id']),

            ),
          );
        },
      ),
    );
  }
}
