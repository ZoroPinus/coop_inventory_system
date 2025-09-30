import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/hybrid_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _supplierController = TextEditingController();

  List<Category> categories = [];
  Category? selectedCategory;
  String selectedUnitOfMeasure = 'pieces';
  bool isLoading = false;
  bool isLoadingCategories = true;

  final List<Map<String, dynamic>> unitsOfMeasure = [
    {'value': 'pieces', 'label': 'Pieces', 'icon': Icons.inventory},
    {'value': 'kg', 'label': 'Kilograms (kg)', 'icon': Icons.scale},
    {'value': 'grams', 'label': 'Grams (g)', 'icon': Icons.scale},
    {'value': 'liters', 'label': 'Liters (L)', 'icon': Icons.water_drop},
    {'value': 'ml', 'label': 'Milliliters (ml)', 'icon': Icons.water_drop},
    {'value': 'meters', 'label': 'Meters (m)', 'icon': Icons.straighten},
    {'value': 'cm', 'label': 'Centimeters (cm)', 'icon': Icons.straighten},
    {'value': 'bags', 'label': 'Bags', 'icon': Icons.shopping_bag},
    {'value': 'boxes', 'label': 'Boxes', 'icon': Icons.inventory_2},
    {'value': 'bottles', 'label': 'Bottles', 'icon': Icons.local_drink},
  ];

  bool get isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (isEditMode) {
      _populateFields();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final loadedCategories = await HybridService.getCategories();

      if (!mounted) return;

      setState(() {
        categories = loadedCategories;
        isLoadingCategories = false;

        if (isEditMode && widget.product!.categoryId != null) {
          selectedCategory = categories.firstWhere(
            (cat) => cat.id == widget.product!.categoryId,
            orElse:
                () =>
                    categories.isNotEmpty
                        ? categories.first
                        : Category(name: 'General'),
          );
        } else if (categories.isNotEmpty) {
          selectedCategory = categories.first;
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (!mounted) return;

      setState(() => isLoadingCategories = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load categories. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _populateFields() {
    final product = widget.product!;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _costPriceController.text = product.costPrice?.toString() ?? '';
    _sellingPriceController.text = product.sellingPrice.toString();
    _stockController.text = product.currentStock.toString();
    _minStockController.text = product.minimumStockLevel.toString();
    _supplierController.text = product.supplierName ?? '';
    selectedUnitOfMeasure = product.unitOfMeasure;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || selectedCategory == null) {
      if (selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a category'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => isLoading = true);

    try {
      final product = Product(
        id: isEditMode ? widget.product!.id : null,
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        categoryId: selectedCategory!.id!,
        costPrice:
            _costPriceController.text.isEmpty
                ? null
                : double.parse(_costPriceController.text),
        sellingPrice: double.parse(_sellingPriceController.text),
        currentStock: int.parse(_stockController.text),
        minimumStockLevel: int.parse(_minStockController.text),
        unitOfMeasure: selectedUnitOfMeasure,
        supplierName:
            _supplierController.text.trim().isEmpty
                ? null
                : _supplierController.text.trim(),
      );

      if (isEditMode) {
        await HybridService.updateProduct(product);
      } else {
        await HybridService.addProduct(product);
      }

      if (!mounted) return;

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditMode
                      ? 'Product updated successfully'
                      : 'Product added successfully',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error saving product: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Unable to save product. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.category, color: Colors.blue[700]),
                SizedBox(width: 12),
                Text('Add New Category'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Vegetables, Tools',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (categoryController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a category name'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    final newCategory = Category(
                      name: categoryController.text.trim(),
                      description:
                          descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                    );

                    final addedCategory = await HybridService.addCategory(
                      newCategory,
                    );

                    if (!mounted) return;

                    setState(() {
                      categories.add(addedCategory);
                      selectedCategory = addedCategory;
                    });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Category added successfully'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[700],
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to add category'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Product' : 'Add New Product'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body:
          isLoadingCategories
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              )
              : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    // Info Card
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Fill in the details below. Fields marked with * are required.',
                                style: TextStyle(color: Colors.blue[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Basic Information Section
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),

                    // Product Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name *',
                        hintText: 'e.g., Tomato Seeds',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the product name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Additional details about the product',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: 16),

                    // Category with Add Button
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<Category>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items:
                                categories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category.name),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a category';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _showAddCategoryDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Pricing Section
                    Text(
                      'Pricing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            decoration: InputDecoration(
                              labelText: 'Cost Price',
                              hintText: '0.00',
                              helperText: 'How much you paid',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.shopping_cart),
                              prefixText: '₱ ',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            decoration: InputDecoration(
                              labelText: 'Selling Price *',
                              hintText: '0.00',
                              helperText: 'How much you sell',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: '₱ ',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Stock Information Section
                    Text(
                      'Stock Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            decoration: InputDecoration(
                              labelText: 'Current Stock *',
                              hintText: '0',
                              helperText: 'Amount in stock now',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final stock = int.tryParse(value);
                              if (stock == null || stock < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minStockController,
                            decoration: InputDecoration(
                              labelText: 'Alert Level *',
                              hintText: '0',
                              helperText: 'Alert when this low',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final stock = int.tryParse(value);
                              if (stock == null || stock < 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Unit of Measure
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnitOfMeasure,
                      decoration: InputDecoration(
                        labelText: 'Unit of Measure',
                        helperText: 'How you count/measure this product',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items:
                          unitsOfMeasure.map<DropdownMenuItem<String>>((unit) {
                            return DropdownMenuItem<String>(
                              value: unit['value'] as String,
                              child: Row(
                                children: [
                                  Icon(unit['icon'] as IconData, size: 20),
                                  SizedBox(width: 12),
                                  Text(unit['label'] as String),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedUnitOfMeasure = value!;
                        });
                      },
                    ),
                    SizedBox(height: 24),

                    // Supplier Section
                    Text(
                      'Supplier (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 12),

                    TextFormField(
                      controller: _supplierController,
                      decoration: InputDecoration(
                        labelText: 'Supplier Name',
                        hintText: 'Where you get this product',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isLoading
                                ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEditMode ? Icons.save : Icons.add,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      isEditMode
                                          ? 'Save Changes'
                                          : 'Add Product',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
    );
  }
}
