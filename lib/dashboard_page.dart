import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We want a custom gradient background, so remove default Scaffold background.
      backgroundColor: Colors.transparent,
      body: Container(
        // White–green gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFA5D6A7)], // White to light green
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // SafeArea keeps content below status bar on iOS/Android
        child: SafeArea(
          // Make entire page scrollable
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 1) Top row with "Login" on the left and "Sign Up" on the right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  LoginPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17CE92), // custom green
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Login"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  SignUpPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17CE92), // custom green
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Sign Up"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2) Title & Tagline
                  const Text(
                    "FleetFlow",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Delivering Efficiency and Reliability",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3) Branding Description
                  const Text(
                    "Welcome to FleetFlow — your all-in-one solution for optimized routes "
                        "and smart fleet management. Our algorithms ensure real-time "
                        "monitoring, efficient load handling, and minimized operational costs. "
                        "Join us and revolutionize your logistics for maximum efficiency.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Roboto',
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4) Features in rows
                  // First row (two features)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _FeatureCard(
                        iconData: Icons.route,
                        title: "Optimized Delivery Routes",
                      ),
                      _FeatureCard(
                        iconData: Icons.monitor_heart,
                        title: "Real-Time Fleet Monitoring",
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Second row (two features)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _FeatureCard(
                        iconData: Icons.account_tree_outlined,
                        title: "Enhanced Load Management",
                      ),
                      _FeatureCard(
                        iconData: Icons.show_chart,
                        title: "Improved Efficiency",
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Last row (single feature in center)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FeatureCard(
                        iconData: Icons.money_off_csred_rounded,
                        title: "Reduced Costs",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A simple reusable widget for each feature card.
class _FeatureCard extends StatelessWidget {
  final IconData iconData;
  final String title;

  const _FeatureCard({
    Key? key,
    required this.iconData,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: SizedBox(
        width: 140, // Keep cards at a consistent width
        height: 130, // Reduced height to prevent overflow
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 48, color: Colors.green),
              const SizedBox(height: 8), // Reduced spacing
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal, // More corporate style
                  letterSpacing: 0.5,
                  fontFamily: 'Roboto', // Or any corporate font you prefer
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

