import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/rating_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class RateOrderScreen extends StatefulWidget {
  final String orderId;
  final String vendorId;

  const RateOrderScreen({
    super.key,
    required this.orderId,
    required this.vendorId,
  });

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images if any
      List<String> imageUrls = [];
      for (var image in _selectedImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('ratings')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create rating document
      final rating = Rating(
        id: '', // Will be set by Firestore
        orderId: widget.orderId,
        customerId: FirebaseAuth.instance.currentUser!.uid,
        vendorId: widget.vendorId,
        rating: _rating,
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
        images: imageUrls,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('ratings')
          .add(rating.toMap());

      // Update order status
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'isRated': true});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How was your experience?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add a comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photos'),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.file(
                            _selectedImages[index],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.red,
                            onPressed: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}