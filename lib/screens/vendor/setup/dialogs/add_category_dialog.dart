import 'package:flutter/material.dart';
import '../../../../models/catalog_models.dart';

class AddCategoryDialog extends StatefulWidget {
  final Category? initialCategory;

  const AddCategoryDialog({
    super.key,
    this.initialCategory,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _nameController.text = widget.initialCategory!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) return;

    final category = Category(
      id: widget.initialCategory?.id ?? DateTime.now().toString(),
      name: _nameController.text,
      products: widget.initialCategory?.products ?? [],
    );

    Navigator.of(context).pop(category);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialCategory != null 
          ? 'Edit Category' 
          : 'Add New Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Enter category name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter category name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveCategory,
          child: const Text('Save'),
        ),
      ],
    );
  }
}