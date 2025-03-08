import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'add_delivery.dart';
import 'driver_page.dart';
import 'maps_page.dart';
import 'select_truck_page.dart';
import 'track_truck.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveries = [];
  String _userName = "";

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No user found. Please login again.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('Users')
          .select('name, role')
          .eq('user_id', user.id)
          .maybeSingle();

      //print("Fetched user data: $response"); // Debugging output

      if (response != null) {
        setState(() {
          _userName = response['name'] ?? "User";
        });

        if (response['role'] == "Driver") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverPage(userId: user.id),
            ),
          );
          return;
        }
      }
      _fetchUserDeliveries();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching role: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUserDeliveries() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text('Deliveries 📦', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.lightBlue.shade200, // Change this to any color you like
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchUserDeliveries),
          IconButton(icon: Icon(Icons.exit_to_app_rounded), onPressed: () => _logout(context)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 15),
          Text(
            "Welcome, $_userName!",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 15),
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
                  truckStatus = "Truck ID: ${truckAssignment[0]['truck_id']}";
                }
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: Icon(Icons.local_shipping, color: Colors.blue, size: 40),
                    title: Text("From: ${delivery['origin_address']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("To: ${delivery['destination_address']}", style: GoogleFonts.poppins()),
                        Text("Status: ${delivery['current_status']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text("Pickup: ${delivery['scheduled_pickup_time']}", style: GoogleFonts.poppins(fontSize: 14)),
                        Text("Delivery: ${delivery['scheduled_delivery_time']}", style: GoogleFonts.poppins(fontSize: 14)),
                        Text("Capacity: ${delivery['capacity']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        Text(truckStatus, style: TextStyle(fontSize: 14, color: Colors.blueAccent)),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectTruckPage(deliveryId: delivery['delivery_id']),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TrackTruckPage()),
                  ),
                  icon: Icon(Icons.map, color: Colors.white),
                  label: Text("Track Truck", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddDeliveryPage()),
                  ),
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text("Add Delivery", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
