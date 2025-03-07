import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'add_delivery.dart';
import 'driver_page.dart';
import 'maps_page.dart';
import 'select_truck_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _fetchUserDeliveries();
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> _fetchUserDeliveries() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user found. Please login again.')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('delivery')
          .select('*, delivery_truck_mapping(truck_id, assignment_status)')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _deliveries = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching deliveries: $e')),
      );
    }
  }

  Future<void> _navigateBasedOnRole(BuildContext context) async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user found. Please login again.')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('Users')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() => _isLoading = false);

      if (response == null || response['role'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User role not found!')),
        );
        return;
      }

      String role = response['role'];

      if (role == "Manager") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddDeliveryPage()),
        );
      } else if (role == "Driver") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DriverPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role not recognized!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching role: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchUserDeliveries,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          Text(
            "Your Deliveries",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _deliveries.isEmpty
                ? Center(child: Text("No deliveries found."))
                : ListView.builder(
              itemCount: _deliveries.length,
              itemBuilder: (context, index) {
                final delivery = _deliveries[index];
                final truckAssignment = delivery['delivery_truck_mapping'];

                String truckStatus = "No Truck Assigned";
                if (truckAssignment != null && truckAssignment.isNotEmpty) {
                  truckStatus =
                  "Truck ID: ${truckAssignment[0]['truck_id']} (${truckAssignment[0]['assignment_status']})";
                }

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text("From: ${delivery['origin_address']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("To: ${delivery['destination_address']}"),
                        Text(
                          "Status: ${delivery['current_status']}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("Scheduled Pickup: ${delivery['scheduled_pickup_time']}"),
                        Text("Scheduled Delivery: ${delivery['scheduled_delivery_time']}"),
                        Text(
                          "Capacity: ${delivery['capacity']} kg",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        Text(
                          truckStatus,
                          style: TextStyle(fontSize: 16, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.local_shipping, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SelectTruckPage(deliveryId: delivery['delivery_id']),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => _navigateBasedOnRole(context),
                  child: Text("Go to Role Page"),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MapsPage()),
                  ),
                  child: Text("Open Maps"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
