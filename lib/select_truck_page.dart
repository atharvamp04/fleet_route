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

  @override
  void initState() {
    super.initState();
    _fetchAvailableTrucks();
  }

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
              onTap: () => _assignTruck(truck['truck_id']),
            ),
          );
        },
      ),
    );
  }
}
