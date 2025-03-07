import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_delivery.dart';
import 'driver_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        String userId = response.user!.id;

        // Fetch user role from 'Users' table
        final userData = await Supabase.instance.client
            .from('Users')
            .select('role')
            .eq('user_id', userId)
            .maybeSingle();

        if (userData == null) {
          throw Exception("User role not found");
        }

        String role = userData['role'];

        // Redirect based on role
        if (role == "Manager") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AddDeliveryPage()),
          );
        } else if (role == "Driver") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DriverPage(userId: userId)),
          );
        } else {
          throw Exception("Invalid role");
        }
      } else {
        throw Exception("Invalid login credentials");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              "Welcome Back! 👋",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Please login to continue",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 40),

            // Email Field
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email, color: Colors.grey),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF17CE92), width: 2),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: Colors.grey),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF17CE92), width: 2),
                ),
              ),
            ),
            SizedBox(height: 30),

            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF17CE92),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            SizedBox(height: 20),

            // Sign Up Link
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                ),
                child: Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(fontSize: 16, color: Color(0xFF17CE92)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
