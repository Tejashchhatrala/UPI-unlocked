import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vendor.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get vendor data by UPI ID
  Future<Vendor?> getVendorByUpiId(String upiId) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('vendors')
          .where('upiId', isEqualTo: upiId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      // Get categories for this vendor
      final categoriesSnapshot = await _firestore
          .collection('vendors')
          .doc(doc.id)
          .collection('categories')
          .get();

      List<Category> categories = [];
      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryData = categoryDoc.data();
        
        // Get products for this category
        final productsSnapshot = await _firestore
            .collection('vendors')
            .doc(doc.id)
            .collection('categories')
            .doc(categoryDoc.id)
            .collection('products')
            .get();

        List<Product> products = productsSnapshot.docs.map((productDoc) {
          final productData = productDoc.data();
          return Product(
            id: productDoc.id,
            name: productData['name'] ?? '',
            price: (productData['price'] ?? 0).toDouble(),
            description: productData['description'] ?? '',
            imageUrl: productData['imageUrl'],
            isAvailable: productData['isAvailable'] ?? true,
          );
        }).toList();

        categories.add(Category(
          id: categoryDoc.id,
          name: categoryData['name'] ?? '',
          products: products,
        ));
      }

      return Vendor(
        id: doc.id,
        name: data['name'] ?? '',
        upiId: data['upiId'] ?? '',
        phone: data['phone'] ?? '',
        address: data['address'] ?? '',
        categories: categories,
      );
    } catch (e) {
      print('Error getting vendor: $e');
      return null;
    }
  }
}