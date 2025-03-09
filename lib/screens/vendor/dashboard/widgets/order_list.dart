import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrderList extends StatefulWidget {
  const OrderList({super.key});

  @override
  State<OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<OrderList> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'New', 'Processing', 'Ready', 'Completed'];

  Stream<QuerySnapshot> _getOrders() {
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .orderBy('createdAt', descending: true);

    if (_selectedFilter != 'All') {
      return query.where('status', isEqualTo: _selectedFilter).snapshots();
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: _filterOptions.map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Orders list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getOrders(),
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

              final orders = snapshot.data?.docs ?? [];

              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFilter == 'All'
                            ? 'No orders yet'
                            : 'No $_selectedFilter orders',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index].data() as Map<String, dynamic>;
                  return OrderCard(
                    orderId: orders[index].id,
                    orderData: order,
                    onStatusUpdate: () => _updateOrderStatus(orders[index].id, order),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateOrderStatus(String orderId, Map<String, dynamic> orderData) async {
    final currentStatus = orderData['status'] as String;
    final nextStatus = await showDialog<String>(
      context: context,
      builder: (context) => UpdateStatusDialog(currentStatus: currentStatus),
    );

    if (nextStatus != null && nextStatus != currentStatus) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
          'status': nextStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to $nextStatus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e')),
          );
        }
      }
    }
  }
}

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final VoidCallback onStatusUpdate;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = (orderData['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d, h:mm a').format(timestamp);
    final items = orderData['items'] as List;
    final total = orderData['total'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text('Order #${orderId.substring(0, 8)}'),
        subtitle: Text(
          '${orderData['status']} • $formattedDate',
          style: TextStyle(
            color: _getStatusColor(orderData['status']),
          ),
        ),
        trailing: Text(
          '₹$total',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer details
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      orderData['customerName'] ?? 'Customer',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (orderData['customerPhone'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(orderData['customerPhone']),
                    ],
                  ),
                ],
                const Divider(height: 24),

                // Order items
                const Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text('${item['quantity']}x'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item['name']),
                        ),
                        Text('₹${item['price']}'),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onStatusUpdate,
                      icon: const Icon(Icons.update),
                      label: const Text('Update Status'),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement order details view
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Details'),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'Processing':
        return Colors.orange;
      case 'Ready':
        return Colors.green;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class UpdateStatusDialog extends StatelessWidget {
  final String currentStatus;

  const UpdateStatusDialog({
    super.key,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Order Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Processing'),
            leading: const Icon(Icons.pending),
            onTap: () => Navigator.pop(context, 'Processing'),
          ),
          ListTile(
            title: const Text('Ready'),
            leading: const Icon(Icons.check_circle),
            onTap: () => Navigator.pop(context, 'Ready'),
          ),
          ListTile(
            title: const Text('Completed'),
            leading: const Icon(Icons.done_all),
            onTap: () => Navigator.pop(context, 'Completed'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}