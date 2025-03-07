import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'navigation_page.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

const String mapboxAccessToken =
    "sk.eyJ1IjoiYXRoYXJ2YW1wMDQiLCJhIjoiY203bHFkNDE1MGVxNTJscXEydDVzNWI5dSJ9.cYEiC2CRD5kT2dg0r_b9gQ";
const String mapboxDirectionsAPI = "https://api.mapbox.com/directions/v5/mapbox/driving/";

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final List<TextEditingController> _checkpointControllers = [];

  Position? _currentPosition;
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _checkpoints = [];
  List<LatLng> _routeCoords = [];
  List<MapBoxPlace> _suggestions = [];

  bool _isSearchingStart = true;
  int? _currentSearchIndex;

  /// Holds the final “ordered” list of names (start, checkpoint1, checkpoint2, ..., end).
  /// We’ll show this in the UI so you know exactly which location is #1, #2, etc.
  List<String> _finalRouteOrderNames = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    try {
      Position position =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = position);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  /// Generate permutations of a list of indices [0..n-1].
  /// This is easier than permuting the LatLngs themselves, because
  /// we also want to reorder the checkpoint *names* in sync.
  List<List<int>> _permuteIndices(int n) {
    if (n <= 1) return [[0]];
    List<int> indices = List.generate(n, (i) => i);
    return _permute(indices);
  }

  /// Standard permutation function for a list of items.
  List<List<T>> _permute<T>(List<T> items) {
    if (items.length <= 1) return [items];
    final List<List<T>> result = [];
    for (int i = 0; i < items.length; i++) {
      final current = items[i];
      final remaining = List<T>.from(items)..removeAt(i);
      for (final perm in _permute(remaining)) {
        result.add([current, ...perm]);
      }
    }
    return result;
  }

  /// We’ll do the following:
  /// 1. If no checkpoints, just fetch route from start to end.
  /// 2. If checkpoints exist, try all permutations, find best route by duration.
  /// 3. Reorder `_checkpoints` AND `_checkpointControllers` to match best route.
  /// 4. Fetch final route geometry and store in `_routeCoords`.
  Future<void> _optimizeAndFetchRoute() async {
    if (_startLocation == null || _endLocation == null) return;

    // If no checkpoints, just do a simple route from start to end.
    if (_checkpoints.isEmpty) {
      final directCoords = await _fetchRouteGeometry(
        start: _startLocation!,
        checkpoints: [],
        end: _endLocation!,
      );
      if (directCoords != null) {
        setState(() {
          _routeCoords = directCoords;
          // Final order is just Start -> End
          _finalRouteOrderNames = [
            _startController.text.isNotEmpty ? _startController.text : "Start",
            _destinationController.text.isNotEmpty ? _destinationController.text : "End",
          ];
        });
      }
      return;
    }

    // Otherwise, we have to brute force all permutations of the checkpoints.
    // We'll pick the route with the smallest duration.
    final indexPermutations = _permuteIndices(_checkpoints.length);
    double bestDuration = double.infinity;
    List<int> bestPermutation = [];
    Map<String, dynamic>? bestRouteData;

    for (final permutation in indexPermutations) {
      // Build the waypoint string: start -> permutation of checkpoints -> end
      final routeData = await _fetchRouteData(
        start: _startLocation!,
        checkpoints: permutation.map((i) => _checkpoints[i]).toList(),
        end: _endLocation!,
      );
      if (routeData != null) {
        double duration = routeData['routes'][0]['duration']; // in seconds
        if (duration < bestDuration) {
          bestDuration = duration;
          bestPermutation = permutation;
          bestRouteData = routeData;
        }
      }
    }

    // Now reorder _checkpoints and _checkpointControllers based on bestPermutation.
    if (bestPermutation.isNotEmpty && bestRouteData != null) {
      // Reorder the lat-lngs
      final newCheckpointOrder = bestPermutation.map((i) => _checkpoints[i]).toList();
      final newControllerOrder =
      bestPermutation.map((i) => _checkpointControllers[i]).toList();

      setState(() {
        _checkpoints = newCheckpointOrder;
        _checkpointControllers
          ..clear()
          ..addAll(newControllerOrder);

        // Extract geometry from best route data
        final coords = bestRouteData?['routes'][0]['geometry']['coordinates'];
        _routeCoords = coords
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .toList();

        // Build a user-friendly final order list
        _finalRouteOrderNames = [];
        _finalRouteOrderNames.add(
            _startController.text.isNotEmpty ? _startController.text : "Start");
        for (int i = 0; i < _checkpoints.length; i++) {
          final name = _checkpointControllers[i].text.isNotEmpty
              ? _checkpointControllers[i].text
              : "Checkpoint ${i + 1}";
          _finalRouteOrderNames.add(name);
        }
        _finalRouteOrderNames.add(
            _destinationController.text.isNotEmpty ? _destinationController.text : "End");
      });
    }
  }

  /// Fetch the raw route data (including geometry + duration) from Mapbox Directions API.
  /// We'll do a separate function so we can compare durations from multiple permutations.
  Future<Map<String, dynamic>?> _fetchRouteData({
    required LatLng start,
    required List<LatLng> checkpoints,
    required LatLng end,
  }) async {
    // Build the waypoint string
    String waypointString = "${start.longitude},${start.latitude}";
    for (LatLng cp in checkpoints) {
      waypointString += ";${cp.longitude},${cp.latitude}";
    }
    waypointString += ";${end.longitude},${end.latitude}";

    final url = Uri.parse(
      "$mapboxDirectionsAPI$waypointString"
          "?alternatives=false&geometries=geojson&steps=false&access_token=$mapboxAccessToken",
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error fetching route data: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Route API error: $e");
      return null;
    }
  }

  /// Fetch just the geometry (list of LatLng) for a route, ignoring permutations.
  Future<List<LatLng>?> _fetchRouteGeometry({
    required LatLng start,
    required List<LatLng> checkpoints,
    required LatLng end,
  }) async {
    final data = await _fetchRouteData(start: start, checkpoints: checkpoints, end: end);
    if (data == null) return null;

    final coords = data['routes'][0]['geometry']['coordinates'];
    return coords.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
  }

  void _searchLocation(String query, bool isStart, int? index) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final placeSearch =
    PlacesSearch(apiKey: mapboxAccessToken, country: 'IN', language: 'en', limit: 5);
    final results = await placeSearch.getPlaces(query);

    if (results != null) {
      setState(() {
        _suggestions = results;
        _isSearchingStart = isStart;
        _currentSearchIndex = index;
      });
    }
  }

  void _selectLocation(MapBoxPlace place, bool isStart, int? index) {
    setState(() {
      if (isStart) {
        _startController.text = place.placeName!;
        _startLocation = LatLng(place.center![1], place.center![0]);
      } else if (index == null) {
        // Destination
        _destinationController.text = place.placeName!;
        _endLocation = LatLng(place.center![1], place.center![0]);
      } else {
        // One of the checkpoints
        _checkpointControllers[index].text = place.placeName!;
        _checkpoints[index] = LatLng(place.center![1], place.center![0]);
      }
      _suggestions = [];
    });
    // After choosing a location, optionally show the route
    // but typically we’ll wait until user clicks “Show Route”
    // so we can optimize after all inputs are done.
  }

  void _addCheckpoint() {
    setState(() {
      _checkpointControllers.add(TextEditingController());
      _checkpoints.add(LatLng(0, 0)); // Placeholder
    });
  }

  void _removeCheckpoint(int index) {
    setState(() {
      _checkpointControllers.removeAt(index);
      _checkpoints.removeAt(index);
    });
  }

  void _startNavigation() {
    if (_startLocation == null || _endLocation == null) return;

    final List<WayPoint> waypoints = [
      WayPoint(
          name: _startController.text,
          latitude: _startLocation!.latitude,
          longitude: _startLocation!.longitude),
      ..._checkpoints.map((checkpoint) => WayPoint(
        name: "Checkpoint",
        latitude: checkpoint.latitude,
        longitude: checkpoint.longitude,
      )),
      WayPoint(
          name: _destinationController.text,
          latitude: _endLocation!.latitude,
          longitude: _endLocation!.longitude),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationPage(
          waypoints: waypoints, // Ensure waypoints list is not empty
        ),
      ),
    );

  }

  /// Builds a custom marker widget (icon + small label).
  Widget _buildLabeledMarker(IconData iconData, Color color, String label) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(iconData, color: color, size: 40),
        // This small label will appear near the bottom of the pin.
        Positioned(
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(2),
            color: Colors.white,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )
      ],
    );
  }

  /// Builds the list of markers for start, checkpoints, end,
  /// each labeled with S, 1, 2, 3..., E so you can see the order.
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_startLocation != null) {
      markers.add(
        Marker(
          point: _startLocation!,
          width: 40,
          height: 40,
          builder: (ctx) => _buildLabeledMarker(Icons.location_pin, Colors.green, "S"),
        ),
      );
    }

    for (int i = 0; i < _checkpoints.length; i++) {
      markers.add(
        Marker(
          point: _checkpoints[i],
          width: 40,
          height: 40,
          builder: (ctx) => _buildLabeledMarker(
            Icons.location_pin,
            Colors.orange,
            (i + 1).toString(),
          ),
        ),
      );
    }

    if (_endLocation != null) {
      markers.add(
        Marker(
          point: _endLocation!,
          width: 40,
          height: 40,
          builder: (ctx) => _buildLabeledMarker(Icons.location_pin, Colors.red, "E"),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapbox Navigation")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Start
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: "Start Location"),
              onChanged: (value) => _searchLocation(value, true, null),
            ),

            // Checkpoints
            for (int i = 0; i < _checkpointControllers.length; i++)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _checkpointControllers[i],
                      decoration: const InputDecoration(labelText: "Checkpoint"),
                      onChanged: (value) => _searchLocation(value, false, i),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeCheckpoint(i),
                  ),
                ],
              ),

            ElevatedButton(
              onPressed: _addCheckpoint,
              child: const Text("Add Checkpoint"),
            ),

            // Destination
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: "Destination"),
              onChanged: (value) => _searchLocation(value, false, null),
            ),

            // Suggestions list
            if (_suggestions.isNotEmpty)
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index].placeName!),
                      onTap: () => _selectLocation(
                        _suggestions[index],
                        _isSearchingStart,
                        _currentSearchIndex,
                      ),
                    );
                  },
                ),
              ),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _optimizeAndFetchRoute,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Show Route"),
                ),
                if (_routeCoords.isNotEmpty)
                  ElevatedButton(
                    onPressed: _startNavigation,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text("Start Navigation"),
                  ),
              ],
            ),

            // If we have a final route order, show it
            if (_finalRouteOrderNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "Optimized Route Order:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (int i = 0; i < _finalRouteOrderNames.length; i++)
                Text("${i + 1}. ${_finalRouteOrderNames[i]}"),
              const SizedBox(height: 8),
            ],

            // Map
            Expanded(
              child: _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                options: MapOptions(
                  center: _startLocation ??
                      LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                  zoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxAccessToken",
                  ),
                  MarkerLayer(markers: _buildMarkers()),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoords,
                        color: Colors.blue,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
