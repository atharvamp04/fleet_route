import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fleet_route/login_page.dart'; // Adjust the path as needed
import 'package:fleet_route/maps_page.dart'; // Import MapsPage

class DriverPage extends StatefulWidget {
  final String userId; // Ensure userId is required

  const DriverPage({Key? key, required this.userId}) : super(key: key);

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  bool _isLoading = false;
  List<String> _driverIds = [];
  List<String> _truckIds = [];
  List<String> _deliveryIds = [];
  List<Map<String, dynamic>> _packages = [];

  @override
  void initState() {
    super.initState();
    _fetchDriverIds();
  }

  Future<void> _fetchDriverIds() async {
    setState(() => _isLoading = true);

    try {
      print("Fetching Driver IDs for User ID: ${widget.userId}...");

      final driverResponse = await Supabase.instance.client
          .from('driver_mapping')
          .select('driver_id')
          .eq('driver_id', widget.userId);

      if (driverResponse.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No driver ID found for this user.')),
        );
        return;
      }

      _driverIds = driverResponse.map((row) => row['driver_id'].toString()).toList();
      print("Driver IDs Found: $_driverIds");

      _fetchTruckIds();
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching driver IDs: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching driver IDs: $e')),
      );
    }
  }

  Future<void> _fetchTruckIds() async {
    try {
      print("Fetching Truck IDs for Driver IDs: $_driverIds...");

      final truckResponse = await Supabase.instance.client
          .from('delivery_truck_mapping')
          .select('truck_id')
          .filter('driver_id', 'in', _driverIds);

      if (truckResponse.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trucks assigned to this driver.')),
        );
        return;
      }

      _truckIds = truckResponse.map((row) => row['truck_id'].toString()).toList();
      print("Truck IDs Found: $_truckIds");

      _fetchDeliveryIds();
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching truck IDs: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching truck IDs: $e')),
      );
    }
  }

  Future<void> _fetchDeliveryIds() async {
    try {
      print("Fetching Delivery IDs for Truck IDs: $_truckIds...");

      final deliveryResponse = await Supabase.instance.client
          .from('delivery_truck_mapping')
          .select('delivery_id')
          .filter('truck_id', 'in', _truckIds);

      if (deliveryResponse.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No deliveries found for these trucks.')),
        );
        return;
      }

      _deliveryIds = deliveryResponse.map((row) => row['delivery_id'].toString()).toList();
      print("Delivery IDs Found: $_deliveryIds");

      _fetchDeliveries();
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching delivery IDs: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching delivery IDs: $e')),
      );
    }
  }

  Future<void> _fetchDeliveries() async {
    try {
      print("Fetching deliveries for Delivery IDs: $_deliveryIds...");

      final deliveriesResponse = await Supabase.instance.client
          .from('delivery')
          .select('*')
          .filter('delivery_id', 'in', _deliveryIds)
          .order('scheduled_pickup_time', ascending: true);

      print("Deliveries fetched: $deliveriesResponse");

      setState(() {
        _packages = deliveriesResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching deliveries: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching deliveries: $e')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _navigateToMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _driverIds.isEmpty
          ? const Center(child: Text("No driver assigned to this account."))
          : _packages.isEmpty
          ? const Center(child: Text("No deliveries assigned to you."))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final package = _packages[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    title: Text("From: ${package['origin_address']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("To: ${package['destination_address']}"),
                        Text("Status: ${package['current_status']}"),
                        Text("Pickup Time: ${package['scheduled_pickup_time']}"),
                        Text("Delivery Time: ${package['scheduled_delivery_time']}"),
                        Text(
                          "Capacity: ${package['capacity']} kg",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.local_shipping, color: Colors.blue),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToMaps,
        child: const Icon(Icons.map),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
