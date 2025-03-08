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
  List<Polyline> _routes = [];
  bool _isLoading = true;
  TruckInfo? _selectedTruck;
  LatLng? _managerLocation;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _getManagerLocation();
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
      List<Marker> markers = [];
      List<Polyline> polylines = [];

      // Define a set of colors for trucks
      List<Color> routeColors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];
      Map<int, Color> truckRouteColors = {}; // Store assigned colors for each truck

      int colorIndex = 0;

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

      for (var truck in truckResponse) {
        int truckId = truck['truck_id'];
        LatLng truckLocation = LatLng(truck['latitude'], truck['longitude']);
        String status = truck['status'];

        bool hasActiveDeliveries = truckDeliveries.containsKey(truckId) &&
            truckDeliveries[truckId]!.any((d) => d.status == 'Active');

        Color truckColor = hasActiveDeliveries ? Colors.red : Colors.green;

        // Assign a unique route color for this truck
        if (!truckRouteColors.containsKey(truckId)) {
          truckRouteColors[truckId] = routeColors[colorIndex % routeColors.length];
          colorIndex++;
        }
        Color routeColor = truckRouteColors[truckId]!;

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

            // 🚛 Fetch and draw route for each truck using its assigned color
            if (delivery.originLatLng != null && delivery.destinationLatLng != null) {
              List<LatLng> routeToPickup = await _getRoute(truckLocation, delivery.originLatLng!);
              List<LatLng> routeToDestination = await _getRoute(delivery.originLatLng!, delivery.destinationLatLng!);

              polylines.add(Polyline(
                points: routeToPickup,
                strokeWidth: 4.0,
                color: routeColor, // Use assigned truck color
              ));

              polylines.add(Polyline(
                points: routeToDestination,
                strokeWidth: 4.0,
                color: routeColor, // Use assigned truck color
              ));
            }
          }
        }
      }

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
        _routes = polylines;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<List<LatLng>> _getRoute(LatLng start, LatLng end) async {
    try {
      final url = "https://maps.googleapis.com/maps/api/directions/json?"
          "origin=${start.latitude},${start.longitude}"
          "&destination=${end.latitude},${end.longitude}"
          "&key=$googleApiKey";

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        List<LatLng> routePoints = [];
        var steps = data['routes'][0]['legs'][0]['steps'];

        for (var step in steps) {
          var location = step['end_location'];
          routePoints.add(LatLng(location['lat'], location['lng']));
        }

        return routePoints;
      } else {
        print("⚠️ Directions API Error: ${data['status']}");
      }
    } catch (e) {
      print("❌ Route API Error: $e");
    }
    return [];
  }

  Future<LatLng?> _getCoordinates(String address) async {
    try {
      final url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleApiKey";
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
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
      _fetchData();
    } catch (e) {
      print("❌ GPS Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
        title: Text('Track Trucks 🗺', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.lightBlue.shade200, // Change this to any color you like
        ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(center: _managerLocation ?? LatLng(19.0760, 72.8777), zoom: 10.0),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',subdomains: ['a', 'b', 'c'],),
              // TileLayer(
              //   urlTemplate: "https://maps.googleapis.com/maps/vt?x={x}&y={y}&z={z}&key=AIzaSyDMX2Xl8EAjMSy1J9iXO9W26E86X5Jlg9k",
              //   subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
              // ),
              PolylineLayer(polylines: _routes),
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
