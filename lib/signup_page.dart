import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  String _selectedRole = "Driver";

  Future<void> _signUp() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = response.user;

      if (user != null) {
        // Insert into Users Table (common for both Driver & Manager)
        final userInsert = await supabase.from('Users').insert({
          'user_id': user.id,
          'name': _nameController.text,
          'mobile': _mobileController.text,
          'role': _selectedRole,
        });

        print('User Insert Response: $userInsert');

        // If the role is Driver, also insert into Driver Table
        if (_selectedRole == "Driver") {
          final driverInsert = await supabase.from('driver').insert({
            'driver_id': user.id, // Same ID as Supabase Auth
            'name': _nameController.text,
            'phone': _mobileController.text,
            'email': _emailController.text,
            'license_number': null,  // Can be updated later
            'license_expiry_date': null,
            'status': 'Available',  // Default status
            'rating': 5.0,  // Default rating
            'assigned_truck_id': null, // Assigned later
          });

          print('Driver Insert Response: $driverInsert');
        }

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User creation failed, please try again')));
      }
    } catch (e) {
      print('Error during signup: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign Up failed: $e')));
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
            Text(
              "Create an Account",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text("Sign up to get started", style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 40),

            TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Full Name')),
            SizedBox(height: 20),

            TextField(controller: _mobileController, decoration: InputDecoration(labelText: 'Mobile Number')),
            SizedBox(height: 20),

            DropdownButtonFormField(
              value: _selectedRole,
              items: ['Driver', 'Manager'].map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
              onChanged: (value) => setState(() => _selectedRole = value.toString()),
              decoration: InputDecoration(labelText: 'Role'),
            ),
            SizedBox(height: 20),

            TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email')),
            SizedBox(height: 20),

            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue.shade200),
                child: Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage())),
                child: Text("Already have an account? Login", style: TextStyle(color: Colors.lightBlue.shade200)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
