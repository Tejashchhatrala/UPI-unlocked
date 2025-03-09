import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final String vendorId;
  final Map<String, dynamic> vendorData;

  const CartScreen({
    super.key,
    required this.cart,
    required this.vendorId,
    required this.vendorData,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessing = false;

  double get _totalAmount {
    return widget.cart.fold(0, (total, item) {
      return total + (item['price'] * item['quantity']);
    });
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Create order in Firestore
      final orderId = await _createOrder();

      // Generate UPI payment URL
      final upiUrl = _generateUPIUrl(orderId);

      // Launch UPI payment
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl));
        
        // Navigate to order tracking
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: orderId),
            ),
          );
        }
      } else {
        _showError('Could not launch payment app');
      }
    } catch (e) {
      _showError('Error processing payment: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _createOrder() async {
    final orderRef = await FirebaseFirestore.instance.collection('orders').add({
      'vendorId': widget.vendorId,
      'customerId': FirebaseAuth.instance.currentUser!.uid,
      'items': widget.cart.map((item) => {
        'id': item['id'],
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'],
      }).toList(),
      'total': _totalAmount,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return orderRef.id;
  }

  String _generateUPIUrl(String orderId) {
    final upiId = widget.vendorData['upiId'];
    final amount = _totalAmount.toString();
    final name = widget.vendorData['businessName'];
    final note = 'Order #${orderId.substring(0, 8)}';

    return 'upi://pay?pa=$upiId&pn=$name&tn=$note&am=$amount&cu=INR';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.cart.length,
              itemBuilder: (context, index) {
                final item = widget.cart[index];
                return CartItemCard(
                  item: item,
                  onUpdateQuantity: (quantity) {
                    setState(() {
                      if (quantity == 0) {
                        widget.cart.removeAt(index);
                      } else {
                        item['quantity'] = quantity;
                      }
                    });
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      child: _isProcessing
                          ? const CircularProgressIndicator()
                          : const Text('Proceed to Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(int) onUpdateQuantity;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Item image
            if (item['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['imageUrl'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 12),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${item['price']}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    onUpdateQuantity(item['quantity'] - 1);
                  },
                ),
                Text(
                  item['quantity'].toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    onUpdateQuantity(item['quantity'] + 1);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}