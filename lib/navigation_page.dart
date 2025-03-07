import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class NavigationPage extends StatefulWidget {
  /// List of waypoints (start, checkpoints, destination)
  final List<WayPoint> waypoints;

  const NavigationPage({Key? key, required this.waypoints}) : super(key: key);

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late MapBoxNavigation _mapBoxNavigation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _mapBoxNavigation = MapBoxNavigation.instance;
    _startNavigation();
  }

  /// Starts navigation using Mapbox
  Future<void> _startNavigation() async {
    try {
      await _mapBoxNavigation.startNavigation(
        wayPoints: widget.waypoints,
        options: MapBoxOptions(
          mode: MapBoxNavigationMode.driving,
          simulateRoute: false,
          language: "en",
          units: VoiceUnits.metric,
        ),
      );

      setState(() {
        _isNavigating = true;
      });
    } catch (e) {
      debugPrint("Error starting navigation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Navigation")),
      body: Center(
        child: _isNavigating
            ? const Text("Navigating...")
            : const CircularProgressIndicator(),
      ),
    );
  }
}
