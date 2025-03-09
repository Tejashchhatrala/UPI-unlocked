import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Order not found'),
            );
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${orderId.substring(0, 8)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _StatusChip(status: orderData['status']),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Placed on ${DateFormat('MMM d, h:mm a').format((orderData['createdAt'] as Timestamp).toDate())}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Order Progress
                const Text(
                  'Order Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _OrderProgressStepper(status: orderData['status']),
                const SizedBox(height: 24),

                // Order Items
                const Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      // Items list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (orderData['items'] as List).length,
                        itemBuilder: (context, index) {
                          final item = orderData['items'][index];
                          return ListTile(
                            title: Text(item['name']),
                            subtitle: Text('₹${item['price']} × ${item['quantity']}'),
                            trailing: Text(
                              '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      // Total amount
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${orderData['total']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Note (if any)
                if (orderData['note'] != null && orderData['note'].isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(orderData['note']),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'processing':
        color = Colors.blue;
        break;
      case 'ready':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final String status;

  const _OrderProgressStepper({required this.status});

  int get _currentStep {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'processing':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: _currentStep,
      controlsBuilder: (context, details) => Container(), // Hide default buttons
      steps: [
        Step(
          title: const Text('Order Placed'),
          content: Text(
            'Your order has been placed and is awaiting confirmation',
            style: TextStyle(color: Colors.grey[600]),
          ),
          isActive: true,
          state: _currentStep >= 0 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Processing'),
          content: Text(
            'Vendor is preparing your order',
            style: TextStyle(color: Colors.grey[600]),
          ),
          isActive: _currentStep >= 1,
          state: _currentStep >= 1 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Ready'),
          content: Text(
            'Your order is ready',
            style: TextStyle(color: Colors.grey[600]),
          ),
          isActive: _currentStep >= 2,
          state: _currentStep >= 2 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Completed'),
          content: Text(
            'Order has been completed',
            style: TextStyle(color: Colors.grey[600]),
          ),
          isActive: _currentStep >= 3,
          state: _currentStep >= 3 ? StepState.complete : StepState.indexed,
        ),
      ],
    );
  }
}