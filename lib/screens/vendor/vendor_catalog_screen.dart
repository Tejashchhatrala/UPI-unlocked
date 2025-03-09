import 'package:flutter/material.dart';
import '../../models/vendor.dart';
import '../../services/firebase_service.dart';

class VendorCatalogScreen extends StatefulWidget {
  final String upiId;

  const VendorCatalogScreen({
    super.key,
    required this.upiId,
  });

  @override
  State<VendorCatalogScreen> createState() => _VendorCatalogScreenState();
}

class _VendorCatalogScreenState extends State<VendorCatalogScreen> {
  Vendor? _vendor;
  bool _isLoading = true;
  final List<Product> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
  try {
    final firebaseService = FirebaseService();
    final vendor = await firebaseService.getVendorByUpiId(widget.upiId);
    
    if (mounted) {
      setState(() {
        _vendor = vendor;
        _isLoading = false;
      });

      if (vendor == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor not found'),
          ),
        );
        Navigator.pop(context);
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading vendor: $e'),
        ),
      );
    }
  }
}

  void _addToCart(Product product) {
    setState(() {
      _cart.add(product);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _viewCart() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => CartBottomSheet(
        cart: _cart,
        vendor: _vendor!,
        onCheckout: () {
          // TODO: Implement checkout
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_vendor?.name ?? 'Vendor Catalog'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text(_cart.length.toString()),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: _viewCart,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _vendor?.categories.length ?? 0,
        itemBuilder: (context, categoryIndex) {
          final category = _vendor!.categories[categoryIndex];
          return ExpansionTile(
            title: Text(category.name),
            children: category.products.map((product) {
              return ListTile(
                title: Text(product.name),
                subtitle: Text(product.description),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${product.price}'),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => _addToCart(product),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class CartBottomSheet extends StatelessWidget {
  final List<Product> cart;
  final Vendor vendor;
  final VoidCallback onCheckout;

  const CartBottomSheet({
    super.key,
    required this.cart,
    required this.vendor,
    required this.onCheckout,
  });

  double get _total => cart.fold(
        0,
        (sum, product) => sum + product.price,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Cart',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final product = cart[index];
                return ListTile(
                  title: Text(product.name),
                  trailing: Text('₹${product.price}'),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Total'),
            trailing: Text(
              '₹$_total',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onCheckout,
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );
  }
}