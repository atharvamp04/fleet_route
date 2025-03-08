import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Import your DashboardPage widget

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait 3 seconds and then navigate to the dashboard.
    Timer(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Full-screen splash with a gradient background.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Your custom logo. Make sure it's added in pubspec.yaml under assets.
              Image.asset(
                'images/logo.png',
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                "OptiRoute",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Optimized Routes for Smart Delivery",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
