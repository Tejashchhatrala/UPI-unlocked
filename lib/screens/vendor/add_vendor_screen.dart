import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddVendorScreen extends StatefulWidget {
  const AddVendorScreen({super.key});

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('vendors').add({
        'name': _nameController.text,
        'upiId': _upiIdController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor added successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding vendor: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Vendor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter vendor name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _upiIdController,
                decoration: const InputDecoration(labelText: 'UPI ID'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter UPI ID' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter address' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveVendor,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Vendor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}