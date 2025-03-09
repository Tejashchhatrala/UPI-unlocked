import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class VendorProfileSettings extends StatefulWidget {
  const VendorProfileSettings({super.key});

  @override
  State<VendorProfileSettings> createState() => _VendorProfileSettingsState();
}

class _VendorProfileSettingsState extends State<VendorProfileSettings> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  File? _imageFile;
  
  // Controllers
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _currentImageUrl;
  
  // Business Hours
  final Map<String, BusinessHours> _businessHours = {};
  
  @override
  void initState() {
    super.initState();
    _loadVendorData();
    _initializeBusinessHours();
  }

  void _initializeBusinessHours() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (var day in days) {
      _businessHours[day] = BusinessHours(isOpen: true, open: '09:00', close: '18:00');
    }
  }

  Future<void> _loadVendorData() async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (vendorDoc.exists) {
        final data = vendorDoc.data()!;
        setState(() {
          _businessNameController.text = data['businessName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _currentImageUrl = data['imageUrl'];
          
          // Load business hours
          if (data['businessHours'] != null) {
            final hours = data['businessHours'] as Map<String, dynamic>;
            hours.forEach((day, value) {
              _businessHours[day] = BusinessHours(
                isOpen: value['isOpen'] ?? true,
                open: value['open'] ?? '09:00',
                close: value['close'] ?? '18:00',
              );
            });
          }
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl = _currentImageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('vendor_profiles')
            .child('${FirebaseAuth.instance.currentUser!.uid}.jpg');

        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'businessName': _businessNameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'imageUrl': imageUrl,
        'businessHours': _businessHours.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentImageUrl != null
                              ? NetworkImage(_currentImageUrl!)
                              : null) as ImageProvider?,
                      child: (_imageFile == null && _currentImageUrl == null)
                          ? const Icon(Icons.store, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _pickImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Business Details
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter business name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Business Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Business Hours
              const Text(
                'Business Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ..._businessHours.entries.map((entry) {
                return BusinessHoursWidget(
                  day: entry.key,
                  hours: entry.value,
                  onChanged: (hours) {
                    setState(() {
                      _businessHours[entry.key] = hours;
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessHours {
  bool isOpen;
  String open;
  String close;

  BusinessHours({
    required this.isOpen,
    required this.open,
    required this.close,
  });

  Map<String, dynamic> toMap() {
    return {
      'isOpen': isOpen,
      'open': open,
      'close': close,
    };
  }
}

class BusinessHoursWidget extends StatelessWidget {
  final String day;
  final BusinessHours hours;
  final Function(BusinessHours) onChanged;

  const BusinessHoursWidget({
    super.key,
    required this.day,
    required this.hours,
    required this.onChanged,
  });

  Future<void> _selectTime(BuildContext context, bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(isOpenTime ? hours.open : hours.close),
    );

    if (picked != null) {
      final newHours = BusinessHours(
        isOpen: hours.isOpen,
        open: isOpenTime ? _formatTime(picked) : hours.open,
        close: isOpenTime ? hours.close : _formatTime(picked),
      );
      onChanged(newHours);
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(day),
            ),
            Switch(
              value: hours.isOpen,
              onChanged: (value) {
                onChanged(BusinessHours(
                  isOpen: value,
                  open: hours.open,
                  close: hours.close,
                ));
              },
            ),
            if (hours.isOpen) ...[
              TextButton(
                onPressed: () => _selectTime(context, true),
                child: Text(hours.open),
              ),
              const Text(' - '),
              TextButton(
                onPressed: () => _selectTime(context, false),
                child: Text(hours.close),
              ),
            ] else
              const Text('Closed'),
          ],
        ),
      ),
    );
  }
}