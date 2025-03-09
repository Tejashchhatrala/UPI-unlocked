import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../../models/catalog_models.dart';

class CatalogSetupStep extends StatefulWidget {
  final Function(List<Category>) onSave;
  final VoidCallback onSkip;
  final List<Category>? initialCategories;

  const CatalogSetupStep({
    super.key,
    required this.onSave,
    required this.onSkip,
    this.initialCategories,
  });

  @override
  State<CatalogSetupStep> createState() => _CatalogSetupStepState();
}

class _CatalogSetupStepState extends State<CatalogSetupStep> {
  final List<Category> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategories != null) {
      _categories.addAll(widget.initialCategories!);
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
        widget.onSave(_categories);
      });
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
        widget.onSave(_categories);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: widget.onSkip,
              child: const Text('Skip for now'),
            ),
            ElevatedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _categories.isEmpty
              ? const Center(
                  child: Text('Add categories to organize your products'),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return CategoryCard(
                      category: category,
                      onAddProduct: () => _addProduct(category),
                      onEdit: () async {
                        final result = await showDialog<Category>(
                          context: context,
                          builder: (context) => AddCategoryDialog(
                            initialCategory: category,
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _categories[index] = result;
                            widget.onSave(_categories);
                          });
                        }
                      },
                      onDelete: () {
                        setState(() {
                          _categories.removeAt(index);
                          widget.onSave(_categories);
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onAddProduct;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onAddProduct,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
          ),
          if (category.products.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.products.length,
              itemBuilder: (context, index) {
                final product = category.products[index];
                return ProductListItem(
                  product: product,
                  onEdit: () async {
                    final result = await showDialog<Product>(
                      context: context,
                      builder: (context) => AddProductDialog(
                        initialProduct: product,
                      ),
                    );
                    if (result != null) {
                      category.products[index] = result;
                    }
                  },
                  onDelete: () {
                    category.products.removeAt(index);
                  },
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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