import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionalDataValidationPage extends StatefulWidget {
  const NutritionalDataValidationPage({super.key});

  @override
  State<NutritionalDataValidationPage> createState() => _NutritionalDataValidationPageState();
}

class _NutritionalDataValidationPageState extends State<NutritionalDataValidationPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritional Data Validation'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Review', icon: Icon(Icons.pending)),
            Tab(text: 'Validated', icon: Icon(Icons.check_circle)),
            Tab(text: 'Flagged', icon: Icon(Icons.flag)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients and recipes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNutritionalDataList('pending'),
                _buildNutritionalDataList('validated'),
                _buildNutritionalDataList('flagged'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionalDataList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNutritionalDataStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = _searchQuery.isEmpty
            ? docs
            : docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toString().toLowerCase() ?? '';
                final type = data['type']?.toString().toLowerCase() ?? '';
                return name.contains(_searchQuery.toLowerCase()) ||
                       type.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending' ? Icons.pending : 
                  status == 'validated' ? Icons.check_circle : Icons.flag,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending' ? 'No nutritional data pending validation' :
                  status == 'validated' ? 'No validated nutritional data' :
                  'No flagged nutritional data',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNutritionalDataCard(doc.id, data, status);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getNutritionalDataStream(String status) {
    return FirebaseFirestore.instance
        .collection('nutritional_data_validation')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Widget _buildNutritionalDataCard(String docId, Map<String, dynamic> data, String status) {
    final name = data['name'] ?? 'Unknown';
    final type = data['type'] ?? 'Unknown';
    final calories = data['calories'] ?? 0;
    final protein = data['protein'] ?? 0;
    final carbs = data['carbs'] ?? 0;
    final fat = data['fat'] ?? 0;
    final fiber = data['fiber'] ?? 0;
    final sugar = data['sugar'] ?? 0;
    final sodium = data['sodium'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    final lastUpdated = data['lastUpdated'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: _getTypeColor(type),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Nutritional Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nutritional Information (per 100g)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildNutritionItem('Calories', '${calories.toStringAsFixed(0)} kcal')),
                      Expanded(child: _buildNutritionItem('Protein', '${protein.toStringAsFixed(1)}g')),
                      Expanded(child: _buildNutritionItem('Carbs', '${carbs.toStringAsFixed(1)}g')),
                      Expanded(child: _buildNutritionItem('Fat', '${fat.toStringAsFixed(1)}g')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildNutritionItem('Fiber', '${fiber.toStringAsFixed(1)}g')),
                      Expanded(child: _buildNutritionItem('Sugar', '${sugar.toStringAsFixed(1)}g')),
                      Expanded(child: _buildNutritionItem('Sodium', '${sodium.toStringAsFixed(0)}mg')),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Validation Notes
            if (data['validationNotes'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Validation Notes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['validationNotes'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Timestamps
            Row(
              children: [
                if (createdAt != null) ...[
                  Text(
                    'Created: ${_formatDate(createdAt.toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (lastUpdated != null) ...[
                  const Spacer(),
                  Text(
                    'Updated: ${_formatDate(lastUpdated.toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                if (status == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _flagNutritionalData(docId),
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('Flag'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _validateNutritionalData(docId),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Validate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (status == 'flagged') ...[
                  ElevatedButton.icon(
                    onPressed: () => _validateNutritionalData(docId),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Validate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editNutritionalData(docId, data),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'ingredient':
        return Colors.blue;
      case 'recipe':
        return Colors.green;
      case 'meal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'validated':
        return Colors.green;
      case 'flagged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _validateNutritionalData(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('nutritional_data_validation')
          .doc(docId)
          .update({
        'status': 'validated',
        'validatedAt': FieldValue.serverTimestamp(),
        'validatedBy': 'nutritionist',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nutritional data validated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _flagNutritionalData(String docId) async {
    final notesController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag Nutritional Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for flagging this data:'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reason for flagging',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Flag'),
          ),
        ],
      ),
    );

    if (result == true && notesController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('nutritional_data_validation')
            .doc(docId)
            .update({
          'status': 'flagged',
          'flaggedAt': FieldValue.serverTimestamp(),
          'flaggedBy': 'nutritionist',
          'validationNotes': notesController.text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nutritional data flagged successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error flagging data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editNutritionalData(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _NutritionalDataEditDialog(
        docId: docId,
        data: data,
        onSave: () => setState(() {}),
      ),
    );
  }
}

class _NutritionalDataEditDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onSave;

  const _NutritionalDataEditDialog({
    required this.docId,
    required this.data,
    required this.onSave,
  });

  @override
  State<_NutritionalDataEditDialog> createState() => _NutritionalDataEditDialogState();
}

class _NutritionalDataEditDialogState extends State<_NutritionalDataEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.data['name'] ?? '';
    _caloriesController.text = (widget.data['calories'] ?? 0).toString();
    _proteinController.text = (widget.data['protein'] ?? 0).toString();
    _carbsController.text = (widget.data['carbs'] ?? 0).toString();
    _fatController.text = (widget.data['fat'] ?? 0).toString();
    _fiberController.text = (widget.data['fiber'] ?? 0).toString();
    _sugarController.text = (widget.data['sugar'] ?? 0).toString();
    _sodiumController.text = (widget.data['sodium'] ?? 0).toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Nutritional Data'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(
                        labelText: 'Protein',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: 'Carbs',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: 'Fat',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fiberController,
                      decoration: const InputDecoration(
                        labelText: 'Fiber',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _sugarController,
                      decoration: const InputDecoration(
                        labelText: 'Sugar',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sodiumController,
                decoration: const InputDecoration(
                  labelText: 'Sodium',
                  border: OutlineInputBorder(),
                  suffixText: 'mg',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('nutritional_data_validation')
          .doc(widget.docId)
          .update({
        'name': _nameController.text,
        'calories': double.tryParse(_caloriesController.text) ?? 0,
        'protein': double.tryParse(_proteinController.text) ?? 0,
        'carbs': double.tryParse(_carbsController.text) ?? 0,
        'fat': double.tryParse(_fatController.text) ?? 0,
        'fiber': double.tryParse(_fiberController.text) ?? 0,
        'sugar': double.tryParse(_sugarController.text) ?? 0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': 'nutritionist',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nutritional data updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
