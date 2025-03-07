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
  int _requiredCapacity = 0; // Capacity needed for this delivery

  @override
  void initState() {
    super.initState();
    _fetchDeliveryCapacity();
  }

  /// Fetch the required delivery capacity from the database
  Future<void> _fetchDeliveryCapacity() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('delivery')
          .select('capacity')
          .eq('delivery_id', widget.deliveryId)
          .single();

      setState(() {
        _requiredCapacity = response['capacity'];
      });

      _fetchAvailableTrucks(); // Fetch trucks after getting the required capacity
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching delivery capacity: $e')),
      );
    }
  }

  /// Fetch available trucks with sufficient capacity
  Future<void> _fetchAvailableTrucks() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      print("Fetching required capacity...");
      final deliveryResponse = await supabase
          .from('delivery')
          .select('capacity')
          .eq('delivery_id', widget.deliveryId)
          .single();

      print("Delivery Response: $deliveryResponse");

      final int requiredCapacity = (deliveryResponse['capacity'] as num).toInt();
      print("Required Capacity: $requiredCapacity");

      print("Fetching trucks...");
      final trucksResponse = await supabase
          .from('truck')
          .select('truck_id, capacity, status')
          .eq('status', 'Free')
          .order('truck_id', ascending: true);

      print("Trucks Response: $trucksResponse");

      List<Map<String, dynamic>> availableTrucks = [];

      for (var truck in trucksResponse) {
        final int truckCapacity = (truck['capacity'] as num).toInt();
        print("Checking Truck ID ${truck['truck_id']} with Capacity: $truckCapacity");

        print("Fetching total package capacity for Truck ID ${truck['truck_id']}...");

        // Use rpc() to call the custom SQL function
        final packageResponse = await supabase
            .rpc('sum_package_capacity', params: {'truck_id_param': truck['truck_id']});

        print("Package Response for Truck ${truck['truck_id']}: $packageResponse");

        final int totalPackageCapacity = ((packageResponse ?? 0) as num).toInt();
        print("Total Assigned Package Capacity: $totalPackageCapacity");

        final int remainingCapacity = truckCapacity - totalPackageCapacity;
        print("Remaining Capacity for Truck ${truck['truck_id']}: $remainingCapacity");

        if (remainingCapacity >= requiredCapacity) {
          truck['remaining_capacity'] = remainingCapacity;
          availableTrucks.add(truck);
        }
      }

      setState(() {
        _trucks = availableTrucks;
        _isLoading = false;
      });

      print("Available Trucks: $_trucks");

    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching trucks: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching trucks: $e')),
      );
    }
  }







  /// Show truck & driver details in a dialog
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
  /// Assign truck to a delivery
  Future<void> _assignTruck(int truckId) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // Fetch the driver assigned to this truck
      final driverResponse = await supabase
          .from('driver')
          .select('driver_id')
          .eq('assigned_truck_id', truckId)
          .maybeSingle();

      if (driverResponse == null || driverResponse.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No driver assigned to this truck."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final String driverId = driverResponse['driver_id'];

      // Insert into delivery_truck_mapping with driver_id
      final deliveryTruckMappingResponse = await supabase
          .from('delivery_truck_mapping')
          .insert({
        'delivery_id': widget.deliveryId,
        'truck_id': truckId,
        'driver_id': driverId, // Store driver_id here
        'assignment_status': 'Active',
        'assigned_at': timestamp,
        'updated_at': timestamp,
      })
          .select('mapping_id')
          .single();

      final int deliveryTruckMappingId = deliveryTruckMappingResponse['mapping_id'];

      // Insert into driver_mapping table
      await supabase.from('driver_mapping').insert({
        'driver_id': driverId,
        'delivery_truck_mapping_id': deliveryTruckMappingId,
        'assigned_at': timestamp,
        'updated_at': timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Truck $truckId with Driver $driverId assigned successfully!"),
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
          ? Center(child: Text("No available trucks meeting capacity requirements"))
          : ListView.builder(
        itemCount: _trucks.length,
        itemBuilder: (context, index) {
          final truck = _trucks[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text("Truck ID: ${truck['truck_id']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Capacity: ${truck['capacity']} kg"),  // Total capacity
                  Text("Remaining Capacity: ${truck['remaining_capacity']} kg"),  // Updated to show remaining capacity
                ],
              ),
              trailing: Icon(Icons.local_shipping, color: Colors.blue),
              onTap: () => _showTruckDetailsDialog(truck['truck_id']),
            ),
          );
        },
      )

    );
  }
}
