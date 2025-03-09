import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'order_tracking_screen.dart';

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
  final _noteController = TextEditingController();

  double get _subtotal {
    return widget.cart.fold(0, (total, item) {
      return total + (item['price'] * item['quantity']);
    });
  }

  void _updateQuantity(int index, int quantity) {
    setState(() {
      if (quantity == 0) {
        widget.cart.removeAt(index);
      } else {
        widget.cart[index]['quantity'] = quantity;
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Create order in Firestore
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'vendorId': widget.vendorId,
        'customerId': FirebaseAuth.instance.currentUser!.uid,
        'customerName': FirebaseAuth.instance.currentUser!.displayName,
        'items': widget.cart.map((item) => {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'],
          'category': item['category'],
        }).toList(),
        'subtotal': _subtotal,
        'total': _subtotal, // Add taxes/fees here if needed
        'note': _noteController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Generate UPI payment URL
      final upiUrl = _generateUPIUrl(orderRef.id);

      // Launch UPI payment
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl));
        
        if (mounted) {
          // Navigate to order tracking
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: orderRef.id),
            ),
          );
        }
      } else {
        throw 'Could not launch payment app';
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Error placing order: $e');
    }
  }

  String _generateUPIUrl(String orderId) {
    final upiId = widget.vendorData['upiId'];
    final amount = _subtotal.toString();
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
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
      ),
      body: widget.cart.isEmpty
          ? const Center(
              child: Text('Your cart is empty'),
            )
          : Column(
              children: [
                // Cart items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final item = widget.cart[index];
                      return CartItemCard(
                        item: item,
                        onUpdateQuantity: (quantity) {
                          _updateQuantity(index, quantity);
                        },
                      );
                    },
                  ),
                ),

                // Note input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Add note (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),

                // Order summary
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
                              '₹${_subtotal.toStringAsFixed(2)}',
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
                            onPressed: _isProcessing ? null : _placeOrder,
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Place Order'),
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
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
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