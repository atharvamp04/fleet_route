import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'maps_page.dart';

class DriverPage extends StatefulWidget {
  final String userId;

  const DriverPage({Key? key, required this.userId}) : super(key: key);

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _packages = [];
  String _userName = "Driver";

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> _fetchDriverData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch driver's name
      final userResponse = await Supabase.instance.client
          .from('Users')
          .select('name')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (userResponse != null) {
        setState(() {
          _userName = userResponse['name'] ?? "Driver";
        });
      }

      // Fetch deliveries assigned to this driver
      final response = await Supabase.instance.client
          .from('delivery')
          .select('*')
          .eq('driver_id', widget.userId)
          .order('scheduled_pickup_time', ascending: true);

      setState(() {
        _packages = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text('Driver Dashboard 🚛', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.lightBlue.shade200,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchDriverData),
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
                : _packages.isEmpty
                ? Center(child: Text("No deliveries assigned to you."))
                : ListView.builder(
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final package = _packages[index];

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: Icon(Icons.local_shipping, color: Colors.blue, size: 40),
                    title: Text("From: ${package['origin_address']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("To: ${package['destination_address']}", style: GoogleFonts.poppins()),
                        Text("Status: ${package['current_status']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text("Pickup: ${package['scheduled_pickup_time']}", style: GoogleFonts.poppins(fontSize: 14)),
                        Text("Delivery: ${package['scheduled_delivery_time']}", style: GoogleFonts.poppins(fontSize: 14)),
                        Text("Capacity: ${package['capacity']} kg", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
                    onTap: () {
                      // You can add navigation to package details here
                    },
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
                    MaterialPageRoute(builder: (context) => MapsPage()),
                  ),
                  icon: Icon(Icons.map, color: Colors.white),
                  label: Text("View Map", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
