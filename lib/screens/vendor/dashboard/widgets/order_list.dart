import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderList extends StatelessWidget {
  const OrderList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
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

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return const Center(child: Text('No orders yet'));
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            return OrderCard(
              orderId: orders[index].id,
              order: order,
            );
          },
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> order;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text('Order #${orderId.substring(0, 8)}'),
        subtitle: Text(
          'Status: ${order['status']} • ₹${order['total']}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${order['customerName']}'),
                const SizedBox(height: 8),
                const Text('Items:'),
                ...(order['items'] as List).map((item) {
                  return ListTile(
                    dense: true,
                    title: Text(item['name']),
                    trailing: Text('${item['quantity']} x ₹${item['price']}'),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Update order status
                        FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({'status': 'Processing'});
                      },
                      child: const Text('Accept'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Mark as ready
                        FirebaseFirestore.instance
                            .collection('orders')
                            .doc(orderId)
                            .update({'status': 'Ready'});
                      },
                      child: const Text('Mark Ready'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}