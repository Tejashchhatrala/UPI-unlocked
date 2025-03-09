import 'package:flutter/material.dart';
import '../../../../models/catalog_models.dart';
import '../../../../services/storage_service.dart';
import '../../setup/dialogs/add_category_dialog.dart';
import '../../setup/dialogs/add_product_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CatalogManager extends StatefulWidget {
  const CatalogManager({super.key});

  @override
  State<CatalogManager> createState() => _CatalogManagerState();
}

class _CatalogManagerState extends State<CatalogManager> {
  final StorageService _storageService = StorageService();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await _storageService.getCatalog(
        FirebaseAuth.instance.currentUser!.uid,
      );
      setState(() {
        _categories = catalog ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading catalog: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Category>(
      context: context,
      builder: (context) => const AddCategoryDialog(),
    );

    if (result != null) {
      setState(() {
        _categories.add(result);
      });
      await _saveCatalog();
    }
  }

  Future<void> _addProduct(Category category) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => const AddProductDialog(),
    );

    if (result != null) {
      setState(() {
        category.products.add(result);
      });
      await _saveCatalog();
    }
  }

  Future<void> _saveCatalog() async {
    try {
      await _storageService.saveCatalog(
        FirebaseAuth.instance.currentUser!.uid,
        _categories,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving catalog: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? const Center(
                  child: Text('No categories yet. Add your first category!'),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return CategoryTile(
                      category: category,
                      onAddProduct: () => _addProduct(category),
                      onEditCategory: () async {
                        final result = await showDialog<Category>(
                          context: context,
                          builder: (context) => AddCategoryDialog(
                            initialCategory: category,
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _categories[index] = result;
                          });
                          await _saveCatalog();
                        }
                      },
                      onDeleteCategory: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Category'),
                            content: Text(
                              'Are you sure you want to delete "${category.name}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          setState(() {
                            _categories.removeAt(index);
                          });
                          await _saveCatalog();
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onAddProduct;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;

  const CategoryTile({
    super.key,
    required this.category,
    required this.onAddProduct,
    required this.onEditCategory,
    required this.onDeleteCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEditCategory,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDeleteCategory,
            ),
          ],
        ),
        children: [
          ...category.products.map((product) => ProductTile(
                product: product,
                onEdit: () async {
                  final result = await showDialog<Product>(
                    context: context,
                    builder: (context) => AddProductDialog(
                      initialProduct: product,
                    ),
                  );
                  if (result != null) {
                    // Update product
                    final index = category.products.indexOf(product);
                    category.products[index] = result;
                  }
                },
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Product'),
                      content: Text(
                        'Are you sure you want to delete "${product.name}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    category.products.remove(product);
                  }
                },
              )),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: onAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductTile({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: product.imageUrl != null
          ? Image.network(
              product.imageUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported),
            )
          : const Icon(Icons.image_not_supported),
      title: Text(product.name),
      subtitle: Text('₹${product.price}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: product.isAvailable,
            onChanged: (value) {
              product.isAvailable = value;
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}