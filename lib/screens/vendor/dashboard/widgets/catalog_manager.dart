import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CatalogManager extends StatefulWidget {
  const CatalogManager({super.key});

  @override
  State<CatalogManager> createState() => _CatalogManagerState();
}

class _CatalogManagerState extends State<CatalogManager> {
  final List<String> _viewOptions = ['Grid', 'List'];
  String _currentView = 'Grid';
  String _selectedCategory = 'All';
  bool _isLoading = false;

  Future<void> _addNewItem() async {
    await showDialog(
      context: context,
      builder: (context) => const AddEditItemDialog(),
    );
  }

  Future<void> _addNewCategory() async {
    await showDialog(
      context: context,
      builder: (context) => const AddEditCategoryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top toolbar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category dropdown
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('vendors')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('categories')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Error loading categories');
                    }

                    List<String> categories = ['All'];
                    if (snapshot.hasData) {
                      categories.addAll(
                        snapshot.data!.docs.map((doc) => doc['name'] as String),
                      );
                    }

                    return DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value!);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // View toggle
              SegmentedButton<String>(
                segments: _viewOptions.map((view) {
                  return ButtonSegment<String>(
                    value: view,
                    icon: Icon(
                      view == 'Grid' ? Icons.grid_view : Icons.list,
                    ),
                  );
                }).toList(),
                selected: {_currentView},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _currentView = newSelection.first);
                },
              ),
            ],
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addNewCategory,
                  icon: const Icon(Icons.category),
                  label: const Text('Add Category'),
                ),
              ),
            ],
          ),
        ),

        // Catalog items
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getCatalogStream(),
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

              final items = snapshot.data?.docs ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items in catalog',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _addNewItem,
                        child: const Text('Add First Item'),
                      ),
                    ],
                  ),
                );
              }

              return _currentView == 'Grid'
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return ItemCard(
                          item: items[index].data() as Map<String, dynamic>,
                          itemId: items[index].id,
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return ItemListTile(
                          item: items[index].data() as Map<String, dynamic>,
                          itemId: items[index].id,
                        );
                      },
                    );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getCatalogStream() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final baseQuery = FirebaseFirestore.instance
        .collection('vendors')
        .doc(userId)
        .collection('items');

    if (_selectedCategory == 'All') {
      return baseQuery.orderBy('name').snapshots();
    }

    return baseQuery
        .where('category', isEqualTo: _selectedCategory)
        .orderBy('name')
        .snapshots();
  }
}

class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String itemId;

  const ItemCard({
    super.key,
    required this.item,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editItem(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            AspectRatio(
              aspectRatio: 1,
              child: item['imageUrl'] != null
                  ? Image.network(
                      item['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, size: 50),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${item['price']}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['category'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Switch(
                        value: item['isAvailable'] ?? true,
                        onChanged: (value) => _updateAvailability(value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AddEditItemDialog(
        initialItem: item,
        itemId: itemId,
      ),
    );
  }

  Future<void> _updateAvailability(bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('items')
          .doc(itemId)
          .update({'isAvailable': value});
    } catch (e) {
      print('Error updating availability: $e');
    }
  }
}

class ItemListTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String itemId;

  const ItemListTile({
    super.key,
    required this.item,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: item['imageUrl'] != null
          ? Image.network(
              item['imageUrl'],
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported),
            )
          : const Icon(Icons.image_not_supported),
      title: Text(item['name']),
      subtitle: Text('₹${item['price']} • ${item['category']}'),
      trailing: Switch(
        value: item['isAvailable'] ?? true,
        onChanged: (value) => _updateAvailability(value),
      ),
      onTap: () => _editItem(context),
    );
  }

  Future<void> _editItem(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AddEditItemDialog(
        initialItem: item,
        itemId: itemId,
      ),
    );
  }

  Future<void> _updateAvailability(bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('vendors')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('items')
          .doc(itemId)
          .update({'isAvailable': value});
    } catch (e) {
      print('Error updating availability: $e');
    }
  }
}