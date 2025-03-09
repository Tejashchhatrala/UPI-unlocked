import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class BasicInfoStep extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic> initialData;

  const BasicInfoStep({
    super.key,
    required this.onSave,
    required this.initialData,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedStoreType = 'Restaurant'; // Default value
  LatLng? _selectedLocation;
  bool _isLoadingLocation = false;

  // Store types - you can expand this list
  final List<String> _storeTypes = [
    'Restaurant',
    'Grocery Store',
    'Retail Shop',
    'Services',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if any
    _businessNameController.text = widget.initialData['businessName'] ?? '';
    _addressController.text = widget.initialData['address'] ?? '';
    _phoneController.text = widget.initialData['phone'] ?? '';
    _selectedStoreType = widget.initialData['storeType'] ?? _storeTypes[0];
    
    // If location exists in initial data
    if (widget.initialData['latitude'] != null && 
        widget.initialData['longitude'] != null) {
      _selectedLocation = LatLng(
        widget.initialData['latitude'],
        widget.initialData['longitude'],
      );
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      final locationData = await location.getLocation();
      setState(() {
        _selectedLocation = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
      });

      _saveData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _saveData() {
    widget.onSave({
      'businessName': _businessNameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'storeType': _selectedStoreType,
      'latitude': _selectedLocation?.latitude,
      'longitude': _selectedLocation?.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              hintText: 'Enter your business name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business name';
              }
              return null;
            },
            onChanged: (_) => _saveData(),
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _selectedStoreType,
            decoration: const InputDecoration(
              labelText: 'Store Type',
            ),
            items: _storeTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStoreType = value;
                  _saveData();
                });
              }
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Enter your business address',
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business address';
              }
              return null;
            },
            onChanged: (_) => _saveData(),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            icon: const Icon(Icons.location_on),
            label: Text(_isLoadingLocation 
              ? 'Getting Location...' 
              : 'Use Current Location'),
          ),
          
          if (_selectedLocation != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('store'),
                    position: _selectedLocation!,
                  ),
                },
              ),
            ),
          ],

          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              hintText: 'Enter business contact number',
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter contact number';
              }
              return null;
            },
            onChanged: (_) => _saveData(),
          ),
        ],
      ),
    );
  }
}