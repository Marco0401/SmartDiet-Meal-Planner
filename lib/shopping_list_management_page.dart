import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListManagementPage extends StatefulWidget {
  final List<Map<String, dynamic>> shoppingList;
  final DateTime startDate;
  final DateTime endDate;

  const ShoppingListManagementPage({
    super.key,
    required this.shoppingList,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<ShoppingListManagementPage> createState() => _ShoppingListManagementPageState();
}

class _ShoppingListManagementPageState extends State<ShoppingListManagementPage> {
  late List<Map<String, dynamic>> _shoppingList;
  double _totalCost = 0.0;
  String? _savedListId;
  bool _isAutoSaving = false;

  @override
  void initState() {
    super.initState();
    _shoppingList = List.from(widget.shoppingList);
    _calculateTotal();
    _autoSave(); // Auto-save on load
  }

  void _calculateTotal() {
    _totalCost = _shoppingList.fold(0.0, (sum, item) {
      final price = (item['price'] ?? 0.0) as double;
      return sum + price;
    });
  }

  Future<void> _autoSave() async {
    if (_isAutoSaving) return;
    
    setState(() {
      _isAutoSaving = true;
    });

    try {
      await _saveShoppingList(autoSave: true);
    } catch (e) {
      print('Auto-save error: $e');
    } finally {
      setState(() {
        _isAutoSaving = false;
      });
    }
  }

  Future<void> _saveShoppingList({bool autoSave = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final shoppingListData = {
        'items': _shoppingList,
        'startDate': widget.startDate.toIso8601String(),
        'endDate': widget.endDate.toIso8601String(),
        'totalCost': _totalCost,
        'itemCount': _shoppingList.length,
        'boughtCount': _shoppingList.where((item) => item['checked'] == true).length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'name': 'Shopping List - ${DateFormat('MMM dd').format(widget.startDate)} to ${DateFormat('MMM dd').format(widget.endDate)}',
      };

      if (_savedListId != null) {
        // Update existing list
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('shopping_lists')
            .doc(_savedListId)
            .update(shoppingListData);
      } else {
        // Create new list
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('shopping_lists')
            .add(shoppingListData);
        _savedListId = docRef.id;
      }

      if (!autoSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shopping list saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!autoSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shopping list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSavedShoppingLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shopping_lists')
          .orderBy('updatedAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved shopping lists found')),
        );
        return;
      }

      final savedLists = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Shopping List',
          'itemCount': data['itemCount'] ?? 0,
          'totalCost': data['totalCost'] ?? 0.0,
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
          'items': data['items'] ?? [],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        };
      }).toList();

      _showLoadDialog(savedLists);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading saved lists: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoadDialog(List<Map<String, dynamic>> savedLists) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Saved Shopping List'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: savedLists.length,
            itemBuilder: (context, index) {
              final list = savedLists[index];
              final createdAt = list['createdAt'] as Timestamp?;
              final updatedAt = list['updatedAt'] as Timestamp?;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(list['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${list['itemCount']} items • ₱${(list['totalCost'] as double).toStringAsFixed(2)}'),
                      if (createdAt != null)
                        Text('Created: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}'),
                      if (updatedAt != null)
                        Text('Updated: ${DateFormat('MMM dd, yyyy').format(updatedAt.toDate())}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSavedList(list['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _loadShoppingList(list),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadShoppingList(Map<String, dynamic> savedList) async {
    Navigator.of(context).pop(); // Close dialog
    
    setState(() {
      _shoppingList = List<Map<String, dynamic>>.from(savedList['items'] ?? []);
      _savedListId = savedList['id'];
    });
    
    _calculateTotal();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shopping list loaded successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteSavedList(String listId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shopping_lists')
          .doc(listId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shopping list deleted successfully!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting shopping list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleItemChecked(int index) {
    setState(() {
      _shoppingList[index]['checked'] = !(_shoppingList[index]['checked'] ?? false);
    });
    _calculateTotal();
    _autoSave(); // Auto-save after changes
  }

  void _editItem(int index) {
    final item = _shoppingList[index];
    final nameController = TextEditingController(text: item['name']);
    final quantityController = TextEditingController(text: item['quantity'].toString());
    final unitController = TextEditingController(text: item['unit']);
    final priceController = TextEditingController(text: item['price']?.toString() ?? '0.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unitController.text,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'piece', child: Text('piece')),
                        DropdownMenuItem(value: 'cup', child: Text('cup')),
                        DropdownMenuItem(value: 'tbsp', child: Text('tbsp')),
                        DropdownMenuItem(value: 'tsp', child: Text('tsp')),
                        DropdownMenuItem(value: 'lb', child: Text('lb')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'oz', child: Text('oz')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'L', child: Text('L')),
                        DropdownMenuItem(value: 'slice', child: Text('slice')),
                        DropdownMenuItem(value: 'serving', child: Text('serving')),
                        DropdownMenuItem(value: 'servings', child: Text('servings')),
                        DropdownMenuItem(value: 'can', child: Text('can')),
                        DropdownMenuItem(value: 'jar', child: Text('jar')),
                        DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                        DropdownMenuItem(value: 'package', child: Text('package')),
                        DropdownMenuItem(value: 'bag', child: Text('bag')),
                        DropdownMenuItem(value: 'box', child: Text('box')),
                        DropdownMenuItem(value: 'head', child: Text('head')),
                        DropdownMenuItem(value: 'clove', child: Text('clove')),

                      ],
                      onChanged: (value) {
                        if (value != null) {
                          unitController.text = value;
                          // Trigger rebuild to update the dropdown
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per Unit',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
            onPressed: () {
              setState(() {
                _shoppingList[index] = {
                  ...item,
                  'name': nameController.text,
                  'quantity': double.tryParse(quantityController.text) ?? 1.0,
                  'unit': unitController.text,
                  'price': double.tryParse(priceController.text) ?? 0.0,
                };
              });
              _calculateTotal();
              _autoSave(); // Auto-save after changes
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addNewItem() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'piece');
    final priceController = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unitController.text,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'piece', child: Text('piece')),
                        DropdownMenuItem(value: 'cup', child: Text('cup')),
                        DropdownMenuItem(value: 'tbsp', child: Text('tbsp')),
                        DropdownMenuItem(value: 'tsp', child: Text('tsp')),
                        DropdownMenuItem(value: 'lb', child: Text('lb')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'oz', child: Text('oz')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'L', child: Text('L')),
                        DropdownMenuItem(value: 'slice', child: Text('slice')),
                        DropdownMenuItem(value: 'servings', child: Text('servings')),
                        DropdownMenuItem(value: 'serving', child: Text('serving')),
                        DropdownMenuItem(value: 'can', child: Text('can')),
                        DropdownMenuItem(value: 'jar', child: Text('jar')),
                        DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                        DropdownMenuItem(value: 'package', child: Text('package')),
                        DropdownMenuItem(value: 'bag', child: Text('bag')),
                        DropdownMenuItem(value: 'box', child: Text('box')),
                        DropdownMenuItem(value: 'head', child: Text('head')),
                        DropdownMenuItem(value: 'clove', child: Text('clove')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          unitController.text = value;
                          // Trigger rebuild to update the dropdown
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per Unit',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _shoppingList.add({
                    'name': nameController.text,
                    'quantity': double.tryParse(quantityController.text) ?? 1.0,
                    'unit': unitController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'category': 'Other',
                    'checked': false,
                  });
                });
                _calculateTotal();
                _autoSave(); // Auto-save after changes
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${_shoppingList[index]['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _shoppingList.removeAt(index);
              });
              _calculateTotal();
              _autoSave(); // Auto-save after changes
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleAllItems() {
    final allChecked = _shoppingList.every((item) => item['checked'] == true);
    setState(() {
      for (final item in _shoppingList) {
        item['checked'] = !allChecked;
      }
    });
  }

  void _shareShoppingList() {
    final uncheckedItems = _shoppingList.where((item) => item['checked'] != true).toList();
    final checkedItems = _shoppingList.where((item) => item['checked'] == true).toList();
    
    // Group items by category
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in uncheckedItems) {
      final category = item['category'] ?? 'Other';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }
    
    String listText = '🛒 Shopping List\n';
    listText += '📅 ${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}\n\n';
    
    if (uncheckedItems.isNotEmpty) {
      listText += '📝 To Buy:\n';
      
      // Sort categories for consistent ordering
      final sortedCategories = groupedItems.keys.toList()..sort();
      
      for (final category in sortedCategories) {
        final items = groupedItems[category]!;
        listText += '\n${_getCategoryIcon(category)} $category:\n';
        for (final item in items) {
          final price = (item['price'] ?? 0.0) as double;
          final quantity = double.tryParse(item['quantity'].toString()) ?? 1.0;
          final totalPrice = price * quantity;
          listText += '• ${item['quantity']} ${item['unit']} ${item['name']} - ₱${totalPrice.toStringAsFixed(2)}\n';
        }
      }
      
      if (checkedItems.isNotEmpty) {
        listText += '\n✅ Already Bought:\n';
        for (final item in checkedItems) {
          listText += '• ${item['quantity']} ${item['unit']} ${item['name']}\n';
        }
      }
      
      listText += '\n💰 Total Estimated Cost: ₱${_totalCost.toStringAsFixed(2)}';
    } else if (checkedItems.isNotEmpty) {
      listText += '✅ All items bought!\n';
      for (final item in checkedItems) {
        listText += '• ${item['quantity']} ${item['unit']} ${item['name']}\n';
      }
    } else {
      listText += 'No items in shopping list.';
    }
    
    // Show share dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shopping List'),
        content: SingleChildScrollView(
          child: SelectableText(
            listText,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shopping list copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Grains':
        return Icons.grain;
      case 'Meat':
        return Icons.restaurant;
      case 'Vegetables':
        return Icons.eco;
      case 'Dairy':
        return Icons.local_drink;
      case 'Condiments':
        return Icons.local_bar;
      case 'Fruits':
        return Icons.apple;
      case 'Filipino':
        return Icons.flag;
      default:
        return Icons.shopping_basket;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Grains':
        return Colors.amber;
      case 'Meat':
        return Colors.red;
      case 'Vegetables':
        return Colors.green;
      case 'Dairy':
        return Colors.blue;
      case 'Condiments':
        return Colors.orange;
      case 'Fruits':
        return Colors.pink;
      case 'Filipino':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Shopping List Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _loadSavedShoppingLists,
              tooltip: 'Load Saved Lists',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveShoppingList(),
              tooltip: 'Save List',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleAllItems,
              tooltip: 'Toggle All',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareShoppingList,
              tooltip: 'Share List',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Shopping Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₱${_totalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Total Cost',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.list_alt,
                          label: 'Total Items',
                          value: '${_shoppingList.length}',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.check_circle,
                          label: 'Bought',
                          value: '${_shoppingList.where((item) => item['checked'] == true).length}',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildSummaryItem(
                          icon: Icons.schedule,
                          label: 'Remaining',
                          value: '${_shoppingList.where((item) => item['checked'] != true).length}',
                        ),
                      ),
                    ],
                  ),
                  if (_isAutoSaving) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Auto-saving...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Shopping List
          Expanded(
              child: _shoppingList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No items in shopping list',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the folder icon to load saved lists',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadSavedShoppingLists,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Load Saved Lists'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _shoppingList.length,
                    itemBuilder: (context, index) {
                      final item = _shoppingList[index];
                      final isChecked = item['checked'] ?? false;
                      final price = (item['price'] ?? 0.0) as double;
                      final quantity = double.tryParse(item['quantity'].toString()) ?? 1.0;
                      final totalPrice = price * quantity;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isChecked ? Colors.green.shade50 : Colors.white,
                          border: Border.all(
                            color: isChecked ? Colors.green.shade300 : Colors.grey.shade200,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(item['category']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getCategoryIcon(item['category']),
                              color: _getCategoryColor(item['category']),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item['name'],
                            style: TextStyle(
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                              color: isChecked ? Colors.grey.shade600 : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['quantity']} ${item['unit']}',
                                style: TextStyle(
                                  color: isChecked ? Colors.grey.shade500 : Colors.grey.shade600,
                                ),
                              ),
                              if (price > 0)
                                Text(
                                  '₱${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editItem(index),
                                tooltip: 'Edit Item',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _deleteItem(index),
                                tooltip: 'Delete Item',
                              ),
                            ],
                          ),
                          onTap: () => _toggleItemChecked(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
