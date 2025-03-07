import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class TrackTruckPage extends StatefulWidget {
  @override
  _TrackTruckPageState createState() => _TrackTruckPageState();
}

class _TrackTruckPageState extends State<TrackTruckPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String googleApiKey = "AIzaSyDMX2Xl8EAjMSy1J9iXO9W26E86X5Jlg9k"; // Replace with your key

  List<Marker> _markers = [];
  bool _isLoading = true;
  TruckInfo? _selectedTruck;
  LatLng? _managerLocation;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _getManagerLocation(); // Fetch manager location
  }

  Future<void> _fetchData() async {
    try {
      final truckResponse = await _supabase
          .from('truck')
          .select('truck_id, latitude, longitude, status');

      final mappingResponse = await _supabase
          .from('delivery_truck_mapping')
          .select('truck_id, assignment_status, delivery(delivery_id, origin_address, destination_address)');

      Map<int, List<DeliveryInfo>> truckDeliveries = {};

      for (var record in mappingResponse) {
        int truckId = record['truck_id'];
        var delivery = record['delivery'];

        if (delivery != null) {
          LatLng? originCoords = await _getCoordinates(delivery['origin_address']);
          LatLng? destCoords = await _getCoordinates(delivery['destination_address']);

          DeliveryInfo deliveryInfo = DeliveryInfo(
            deliveryId: delivery['delivery_id'],
            originAddress: delivery['origin_address'],
            destinationAddress: delivery['destination_address'],
            originLatLng: originCoords,
            destinationLatLng: destCoords,
            status: record['assignment_status'],
          );

          truckDeliveries.putIfAbsent(truckId, () => []).add(deliveryInfo);
        }
      }

      List<Marker> markers = [];

      for (var truck in truckResponse) {
        int truckId = truck['truck_id'];
        LatLng truckLocation = LatLng(truck['latitude'], truck['longitude']);
        String status = truck['status'];

        bool hasActiveDeliveries = truckDeliveries.containsKey(truckId) &&
            truckDeliveries[truckId]!.any((d) => d.status == 'Active');

        Color truckColor = hasActiveDeliveries ? Colors.red : Colors.green;

        markers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: truckLocation,
            builder: (ctx) => GestureDetector(
              onTap: () => setState(() => _selectedTruck = TruckInfo(
                truckId: truckId,
                latitude: truckLocation.latitude,
                longitude: truckLocation.longitude,
                status: status,
                deliveries: truckDeliveries[truckId] ?? [],
              )),
              child: Icon(
                Icons.local_shipping,
                color: truckColor,
                size: 30.0,
              ),
            ),
          ),
        );

        if (truckDeliveries.containsKey(truckId)) {
          for (var delivery in truckDeliveries[truckId]!) {
            if (delivery.originLatLng != null) {
              markers.add(
                Marker(
                  width: 30.0,
                  height: 30.0,
                  point: delivery.originLatLng!,
                  builder: (ctx) => Icon(Icons.location_on, color: Colors.blue, size: 25.0),
                ),
              );
            }

            if (delivery.destinationLatLng != null) {
              markers.add(
                Marker(
                  width: 30.0,
                  height: 30.0,
                  point: delivery.destinationLatLng!,
                  builder: (ctx) => Icon(Icons.flag, color: Colors.purple, size: 25.0),
                ),
              );
            }
          }
        }
      }

      // Add manager location marker
      if (_managerLocation != null) {
        markers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: _managerLocation!,
            builder: (ctx) => Icon(Icons.person_pin_circle, color: Colors.blue, size: 35.0),
          ),
        );
      }

      setState(() {
        _markers = markers;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<LatLng?> _getCoordinates(String address) async {
    try {
      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleApiKey";

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      } else {
        print("⚠️ Google API Error: ${data['status']}");
      }
    } catch (e) {
      print("❌ API Error: $e");
    }
    return null;
  }

  Future<void> _getManagerLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _managerLocation = LatLng(position.latitude, position.longitude);
      });
      _fetchData(); // Refresh map with manager location
    } catch (e) {
      print("❌ GPS Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track Trucks')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: _managerLocation ?? LatLng(19.0760, 72.8777), // Default Mumbai
              zoom: 10.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_selectedTruck != null) _buildTruckDetailsCard(_selectedTruck!),
          if (_isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildTruckDetailsCard(TruckInfo truck) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.white.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("🚛 Truck ID: ${truck.truckId}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Divider(),
              Text("📍 Status: ${truck.status}",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ...truck.deliveries.map((d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(),
                  Text("📦 Delivery ID: ${d.deliveryId}", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("📍 Origin: ${d.originAddress}", style: TextStyle(color: Colors.blue)),
                  Text("🏁 Destination: ${d.destinationAddress}", style: TextStyle(color: Colors.purple)),
                  Text("🔄 Status: ${d.status}", style: TextStyle(color: d.status == 'Active' ? Colors.red : Colors.grey)),
                ],
              )),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => setState(() => _selectedTruck = null),
                child: Text("Close"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class TruckInfo {
  final int truckId;
  final double latitude;
  final double longitude;
  final String status;
  final List<DeliveryInfo> deliveries;

  TruckInfo({
    required this.truckId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.deliveries,
  });
}

class DeliveryInfo {
  final int deliveryId;
  final String originAddress;
  final String destinationAddress;
  final LatLng? originLatLng;
  final LatLng? destinationLatLng;
  final String status;

  DeliveryInfo({
    required this.deliveryId,
    required this.originAddress,
    required this.destinationAddress,
    this.originLatLng,
    this.destinationLatLng,
    required this.status,
  });
}
