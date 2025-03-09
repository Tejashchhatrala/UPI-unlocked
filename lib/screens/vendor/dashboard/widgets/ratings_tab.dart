import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/rating_model.dart';

class RatingsTab extends StatelessWidget {
  const RatingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('vendorId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ratings = snapshot.data?.docs ?? [];

        if (ratings.isEmpty) {
          return const Center(child: Text('No ratings yet'));
        }

        return ListView.builder(
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = Rating.fromMap(
              ratings[index].id,
              ratings[index].data() as Map<String, dynamic>,
            );

            return RatingCard(rating: rating);
          },
        );
      },
    );
  }
}

class RatingCard extends StatelessWidget {
  final Rating rating;

  const RatingCard({
    super.key,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  );
                }),
                const Spacer(),
                Text(
                  rating.createdAt.toString().split('.')[0],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (rating.comment != null) ...[
              const SizedBox(height: 8),
              Text(rating.comment!),
            ],
            if (rating.images?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: rating.images!.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.network(
                        rating.images![index],
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
            if (rating.vendorResponse == null) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Show response dialog
                  showDialog(
                    context: context,
                    builder: (context) => _ResponseDialog(rating: rating),
                  );
                },
                child: const Text('Respond to Review'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Your Response:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(rating.vendorResponse!.response),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponseDialog extends StatefulWidget {
  final Rating rating;

  const _ResponseDialog({required this.rating});

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final _responseController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitResponse() async {
    if (_responseController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final response = VendorResponse(
        response: _responseController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('ratings')
          .doc(widget.rating.id)
          .update({
        'vendorResponse': response.toMap(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting response: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Respond to Review'),
      content: TextField(
        controller: _responseController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Type your response...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitResponse,
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('Submit'),
        ),
      ],
    );
  }
}