class Vendor {
  final String id;
  final String name;
  final String upiId;
  final String phone;
  final String address;
  final List<Category> categories;

  Vendor({
    required this.id,
    required this.name,
    required this.upiId,
    required this.phone,
    required this.address,
    required this.categories,
  });
}

class Category {
  final String id;
  final String name;
  final List<Product> products;

  Category({
    required this.id,
    required this.name,
    required this.products,
  });
}

class Product {
  final String id;
  final String name;
  final double price;
  final String description;
  final String? imageUrl;
  bool isAvailable;
  
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.imageUrl,
    this.isAvailable = true,
  });
}