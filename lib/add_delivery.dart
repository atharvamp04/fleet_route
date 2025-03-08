import 'package:flutter/material.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddDeliveryPage extends StatefulWidget {
  @override
  _AddDeliveryPageState createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _packageDetailsController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController();

  DateTime? _pickupTime;
  DateTime? _deliveryTime;

  List<MapBoxPlace> _suggestions = [];
  bool _isOrigin = true;

  final String mapboxApiKey = "sk.eyJ1IjoiYXRoYXJ2YW1wMDQiLCJhIjoiY203bHFkNDE1MGVxNTJscXEydDVzNWI5dSJ9.cYEiC2CRD5kT2dg0r_b9gQ";

  void _searchAddress(String query, bool isOrigin) async {
    if (query.isEmpty) return;

    var placesSearch = PlacesSearch(apiKey: mapboxApiKey, country: "IN", limit: 5);
    List<MapBoxPlace> places = await placesSearch.getPlaces(query) ?? [];

    setState(() {
      _suggestions = places;
      _isOrigin = isOrigin;
    });
  }

  Future<void> _submitDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('delivery').insert({
        'origin_address': _originController.text,
        'destination_address': _destinationController.text,
        'scheduled_pickup_time': _pickupTime?.toIso8601String(),
        'scheduled_delivery_time': _deliveryTime?.toIso8601String(),
        'current_status': 'Pending',
        'capacity': _packageDetailsController.text,
        'priority_level': int.tryParse(_priorityController.text) ?? 0,
        'created_by': supabase.auth.currentUser?.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delivery Added Successfully!'), backgroundColor: Colors.green),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _pickDateTime(bool isPickup) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    DateTime finalDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute,
    );

    setState(() {
      if (isPickup) {
        _pickupTime = finalDateTime;
      } else {
        _deliveryTime = finalDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
        title: Text('Add Delivery 📦', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.lightBlue.shade200, // Change this to any color you like
        ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _originController,
                decoration: InputDecoration(labelText: 'Origin Address', prefixIcon: Icon(Icons.location_on)),
                onChanged: (value) => _searchAddress(value, true),
                validator: (value) => value!.isEmpty ? 'Enter origin address' : null,
              ),
              TextFormField(
                controller: _destinationController,
                decoration: InputDecoration(labelText: 'Destination Address', prefixIcon: Icon(Icons.location_on)),
                onChanged: (value) => _searchAddress(value, false),
                validator: (value) => value!.isEmpty ? 'Enter destination address' : null,
              ),

              if (_suggestions.isNotEmpty) ..._suggestions.map((place) {
                return ListTile(
                  title: Text(place.placeName ?? ''),
                  onTap: () {
                    setState(() {
                      if (_isOrigin) {
                        _originController.text = place.placeName ?? '';
                      } else {
                        _destinationController.text = place.placeName ?? '';
                      }
                      _suggestions = [];
                    });
                  },
                );
              }),

              ListTile(
                title: Text(_pickupTime == null
                    ? 'Select Pickup Time'
                    : 'Pickup: ${_pickupTime!.toLocal()}'),
                leading: Icon(Icons.access_time),
                onTap: () => _pickDateTime(true),
              ),

              ListTile(
                title: Text(_deliveryTime == null
                    ? 'Select Delivery Time'
                    : 'Delivery: ${_deliveryTime!.toLocal()}'),
                leading: Icon(Icons.delivery_dining),
                onTap: () => _pickDateTime(false),
              ),

              TextFormField(
                controller: _packageDetailsController,
                decoration: InputDecoration(labelText: 'Capacity', prefixIcon: Icon(Icons.inventory)),
                  keyboardType: TextInputType.number,
              ),

              TextFormField(
                controller: _priorityController,
                decoration: InputDecoration(labelText: 'Priority Level (0-5)', prefixIcon: Icon(Icons.priority_high)),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isNotEmpty && int.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitDelivery,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue.shade200, padding: EdgeInsets.all(14)),
                child: Text('Submit Delivery', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
