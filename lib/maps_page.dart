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

  // Normal checkpoints
  final List<TextEditingController> _checkpointControllers = [];
  final List<LatLng> _checkpoints = [];

  // Priority location
  bool _usePriority = false;
  final TextEditingController _priorityController = TextEditingController();
  LatLng? _priorityLocation;

  Position? _currentPosition;
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _routeCoords = [];
  List<MapBoxPlace> _suggestions = [];

  bool _isSearchingStart = true;
  int? _currentSearchIndex;

  /// Final order of location names: Start, Priority, Checkpoints..., End
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

  // ------------------------------
  // Priority logic + permutations
  // ------------------------------

  List<List<int>> _permuteIndices(int n) {
    if (n <= 1) return [List.generate(n, (i) => i)];
    List<int> indices = List.generate(n, (i) => i);
    return _permute(indices);
  }

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

  /// 1. If priority is enabled, fix the route as: Start -> Priority -> [Permutation of others] -> End
  /// 2. Otherwise, brute force with all checkpoints.
  Future<void> _optimizeAndFetchRoute() async {
    if (_startLocation == null || _endLocation == null) return;

    // If user wants to use a priority location
    if (_usePriority && _priorityLocation != null) {
      // We'll brute force only the OTHER checkpoints. Priority is forced second.
      if (_checkpoints.isEmpty) {
        // Just Start -> Priority -> End
        final coords = await _fetchRouteGeometry(
          start: _startLocation!,
          checkpoints: [_priorityLocation!],
          end: _endLocation!,
        );
        if (coords != null) {
          setState(() {
            _routeCoords = coords;
            _finalRouteOrderNames = [
              _startController.text.isNotEmpty ? _startController.text : "Start",
              _priorityController.text.isNotEmpty
                  ? _priorityController.text
                  : "Priority",
              _destinationController.text.isNotEmpty
                  ? _destinationController.text
                  : "End",
            ];
          });
        }
        return;
      }

      // Otherwise, permutations of the other checkpoints
      final indexPermutations = _permuteIndices(_checkpoints.length);
      double bestDuration = double.infinity;
      List<int> bestPermutation = [];
      Map<String, dynamic>? bestRouteData;

      for (final permutation in indexPermutations) {
        final currentCheckpoints = [for (int i in permutation) _checkpoints[i]];
        final routeData = await _fetchRouteData(
          start: _startLocation!,
          checkpoints: [_priorityLocation!, ...currentCheckpoints],
          end: _endLocation!,
        );
        if (routeData != null) {
          double duration = routeData['routes'][0]['duration'];
          if (duration < bestDuration) {
            bestDuration = duration;
            bestPermutation = permutation;
            bestRouteData = routeData;
          }
        }
      }

      if (bestPermutation.isNotEmpty && bestRouteData != null) {
        final newCheckpointOrder = bestPermutation.map((i) => _checkpoints[i]).toList();
        final newControllerOrder =
        bestPermutation.map((i) => _checkpointControllers[i]).toList();

        setState(() {
          _checkpoints
            ..clear()
            ..addAll(newCheckpointOrder);
          _checkpointControllers
            ..clear()
            ..addAll(newControllerOrder);

          final coords = bestRouteData?['routes'][0]['geometry']['coordinates'];
          _routeCoords = coords
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();

          _finalRouteOrderNames = [
            _startController.text.isNotEmpty ? _startController.text : "Start",
            _priorityController.text.isNotEmpty
                ? _priorityController.text
                : "Priority",
          ];
          for (int i = 0; i < _checkpoints.length; i++) {
            final name = _checkpointControllers[i].text.isNotEmpty
                ? _checkpointControllers[i].text
                : "Checkpoint ${i + 1}";
            _finalRouteOrderNames.add(name);
          }
          _finalRouteOrderNames.add(
            _destinationController.text.isNotEmpty
                ? _destinationController.text
                : "End",
          );
        });
      }
    } else {
      // Priority not in use => normal brute force
      if (_checkpoints.isEmpty) {
        final directCoords = await _fetchRouteGeometry(
          start: _startLocation!,
          checkpoints: [],
          end: _endLocation!,
        );
        if (directCoords != null) {
          setState(() {
            _routeCoords = directCoords;
            _finalRouteOrderNames = [
              _startController.text.isNotEmpty ? _startController.text : "Start",
              _destinationController.text.isNotEmpty
                  ? _destinationController.text
                  : "End",
            ];
          });
        }
        return;
      }

      final indexPermutations = _permuteIndices(_checkpoints.length);
      double bestDuration = double.infinity;
      List<int> bestPermutation = [];
      Map<String, dynamic>? bestRouteData;

      for (final permutation in indexPermutations) {
        final currentCheckpoints = [for (int i in permutation) _checkpoints[i]];
        final routeData = await _fetchRouteData(
          start: _startLocation!,
          checkpoints: currentCheckpoints,
          end: _endLocation!,
        );
        if (routeData != null) {
          double duration = routeData['routes'][0]['duration'];
          if (duration < bestDuration) {
            bestDuration = duration;
            bestPermutation = permutation;
            bestRouteData = routeData;
          }
        }
      }

      if (bestPermutation.isNotEmpty && bestRouteData != null) {
        final newCheckpointOrder = bestPermutation.map((i) => _checkpoints[i]).toList();
        final newControllerOrder =
        bestPermutation.map((i) => _checkpointControllers[i]).toList();

        setState(() {
          _checkpoints
            ..clear()
            ..addAll(newCheckpointOrder);
          _checkpointControllers
            ..clear()
            ..addAll(newControllerOrder);

          final coords = bestRouteData?['routes'][0]['geometry']['coordinates'];
          _routeCoords = coords
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();

          _finalRouteOrderNames = [
            _startController.text.isNotEmpty ? _startController.text : "Start",
          ];
          for (int i = 0; i < _checkpoints.length; i++) {
            final name = _checkpointControllers[i].text.isNotEmpty
                ? _checkpointControllers[i].text
                : "Checkpoint ${i + 1}";
            _finalRouteOrderNames.add(name);
          }
          _finalRouteOrderNames.add(
            _destinationController.text.isNotEmpty
                ? _destinationController.text
                : "End",
          );
        });
      }
    }
  }

  // ----------------------
  // Fetch route data
  // ----------------------
  Future<Map<String, dynamic>?> _fetchRouteData({
    required LatLng start,
    required List<LatLng> checkpoints,
    required LatLng end,
  }) async {
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

  // ----------------------
  // Search + UI
  // ----------------------

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

        // We'll use a special index of -1 for "priority"
        if (index == -1) {
          _currentSearchIndex = -1;
        } else {
          _isSearchingStart = isStart;
          _currentSearchIndex = index;
        }
      });
    }
  }

  void _selectLocation(MapBoxPlace place, bool isStart, int? index) {
    setState(() {
      if (index == -1) {
        // Priority
        _priorityController.text = place.placeName!;
        _priorityLocation = LatLng(place.center![1], place.center![0]);
      } else if (isStart) {
        // Start
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
  }

  void _addCheckpoint() {
    setState(() {
      _checkpointControllers.add(TextEditingController());
      _checkpoints.add(LatLng(0, 0)); // placeholder
    });
  }

  void _removeCheckpoint(int index) {
    setState(() {
      _checkpointControllers.removeAt(index);
      _checkpoints.removeAt(index);
    });
  }

  // ----------------------
  // Navigation
  // ----------------------
  void _startNavigation() {
    if (_startLocation == null || _endLocation == null) return;

    if (_usePriority && _priorityLocation != null) {
      // Start, Priority, then the checkpoints, then End
      final List<WayPoint> waypoints = [
        WayPoint(
          name: _startController.text,
          latitude: _startLocation!.latitude,
          longitude: _startLocation!.longitude,
        ),
        WayPoint(
          name: _priorityController.text,
          latitude: _priorityLocation!.latitude,
          longitude: _priorityLocation!.longitude,
        ),
        ..._checkpoints.map(
              (checkpoint) => WayPoint(
            name: "Checkpoint",
            latitude: checkpoint.latitude,
            longitude: checkpoint.longitude,
          ),
        ),
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

  // ----------------------
  // Map UI
  // ----------------------
  Widget _buildLabeledMarker(IconData iconData, Color color, String label) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(iconData, color: color, size: 40),
        Positioned(
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(2),
            color: Colors.white,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        )
      ],
    );
  }

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

    // If priority is set, mark it as P
    if (_priorityLocation != null && _usePriority) {
      markers.add(
        Marker(
          point: _priorityLocation!,
          width: 40,
          height: 40,
          builder: (ctx) => _buildLabeledMarker(Icons.location_pin, Colors.purple, "P"),
        ),
      );
    }

    // Checkpoints
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

  // ----------------------
  // Build with DraggableScrollableSheet
  // ----------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapbox Navigation")),
      body: Stack(
        children: [
          // If we don't yet have a currentPosition, show a spinner.
          // Otherwise, show the map behind the bottom sheet.
          if (_currentPosition == null)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              options: MapOptions(
                center: _startLocation ??
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
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
                    Polyline(points: _routeCoords, color: Colors.blue, strokeWidth: 5.0),
                  ],
                ),
              ],
            ),

          // Draggable bottom panel for the UI (fields, buttons, route info)
          DraggableScrollableSheet(
            initialChildSize: 0.3,   // how much of the screen it takes initially
            minChildSize: 0.15,      // how far down it can be dragged
            maxChildSize: 0.9,       // how high it can be dragged
            builder: (context, scrollController) {
              return Container(
                color: Colors.white,
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Start
                    TextField(
                      controller: _startController,
                      decoration: const InputDecoration(labelText: "Start Location"),
                      onChanged: (value) => _searchLocation(value, true, null),
                    ),

                    // Priority Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _usePriority,
                          onChanged: (bool? val) {
                            setState(() {
                              _usePriority = val ?? false;
                              if (!_usePriority) {
                                _priorityController.clear();
                                _priorityLocation = null;
                              }
                            });
                          },
                        ),
                        const Text("Priority Delivery?")
                      ],
                    ),

                    // Priority Field (only visible if checkbox is selected)
                    if (_usePriority)
                      TextField(
                        controller: _priorityController,
                        decoration: const InputDecoration(labelText: "Priority Location"),
                        onChanged: (value) => _searchLocation(value, false, -1),
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
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


