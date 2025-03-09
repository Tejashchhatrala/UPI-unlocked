import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_screen.dart';

class VendorMenuScreen extends StatefulWidget {
  final String upiId;
  final String vendorName;

  const VendorMenuScreen({
    super.key,
    required this.upiId,
    required this.vendorName,
  });

  @override
  State<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends State<VendorMenuScreen> {
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;
  String? _vendorId;
  Map<String, dynamic>? _vendorData;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
    try {
      // Find vendor by UPI ID
      final vendorQuery = await FirebaseFirestore.instance
          .collection('vendors')
          .where('upiId', isEqualTo: widget.upiId)
          .limit(1)
          .get();

      if (vendorQuery.docs.isEmpty) {
        _showError('Vendor not found');
        return;
      }

      setState(() {
        _vendorId = vendorQuery.docs.first.id;
        _vendorData = vendorQuery.docs.first.data();
        _isLoading = false;
      });
    } catch (e) {
      _showError('Error loading vendor data');
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final existingItemIndex = _cart.indexWhere(
        (cartItem) => cartItem['id'] == item['id'],
      );

      if (existingItemIndex == -1) {
        _cart.add({
          ...item,
          'quantity': 1,
        });
      } else {
        _cart[existingItemIndex]['quantity']++;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['name']} added to cart'),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () => _viewCart(),
        ),
      ),
    );
  }

  void _viewCart() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          cart: _cart,
          vendorId: _vendorId!,
          vendorData: _vendorData!,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_vendorData?['businessName'] ?? widget.vendorName),
            if (_vendorData?['address'] != null)
              Text(
                _vendorData!['address'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (_cart.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: _viewCart,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      _cart.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vendors')
                .doc(_vendorId)
                .collection('categories')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              final categories = ['All', ...snapshot.data!.docs.map((doc) => doc['name'] as String)];

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() => _selectedCategory = category);
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          // Menu items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMenuItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data?.docs ?? [];

                if (items.isEmpty) {
                  return const Center(child: Text('No items available'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index].data() as Map<String, dynamic>;
                    return MenuItemCard(
                      item: {
                        'id': items[index].id,
                        ...item,
                      },
                      onAdd: _addToCart,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getMenuItemsStream() {
    Query query = FirebaseFirestore.instance
        .collection('vendors')
        .doc(_vendorId)
        .collection('items')
        .where('isAvailable', isEqualTo: true);

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }
}

class MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onAdd;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => onAdd(item),
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
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                          width: 80,
                          height: 80,
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
                    if (item['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item['description'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '₹${item['price']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Add button
              ElevatedButton(
                onPressed: () => onAdd(item),
                child: const Text('ADD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}