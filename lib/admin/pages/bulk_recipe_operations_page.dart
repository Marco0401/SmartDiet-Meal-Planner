import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/filipino_recipe_service.dart';
import '../../services/recipe_service.dart';

class BulkRecipeOperationsPage extends StatefulWidget {
  const BulkRecipeOperationsPage({super.key});

  @override
  State<BulkRecipeOperationsPage> createState() => _BulkRecipeOperationsPageState();
}

class _BulkRecipeOperationsPageState extends State<BulkRecipeOperationsPage> {
  final List<String> _selectedRecipeIds = [];
  bool _isLoading = false;
  String _selectedOperation = 'update_nutrition';
  String _selectedRecipeType = 'filipino';

  final Map<String, dynamic> _bulkUpdateData = {
    'cookingTime': null,
    'servings': null,
    'mealType': null,
    'cuisine': null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Recipe Operations'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedRecipeIds.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildOperationSelector(),
          _buildBulkUpdateForm(),
          Expanded(
            child: _buildRecipeList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Operation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedOperation,
                  decoration: const InputDecoration(
                    labelText: 'Operation Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'update_nutrition', child: Text('Update Nutrition')),
                    DropdownMenuItem(value: 'update_meal_type', child: Text('Update Meal Type')),
                    DropdownMenuItem(value: 'update_cooking_time', child: Text('Update Cooking Time')),
                    DropdownMenuItem(value: 'update_servings', child: Text('Update Servings')),
                    DropdownMenuItem(value: 'add_tags', child: Text('Add Tags')),
                    DropdownMenuItem(value: 'bulk_delete', child: Text('Bulk Delete')),
                  ],
                  onChanged: (value) => setState(() => _selectedOperation = value!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRecipeType,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'filipino', child: Text('Filipino Recipes')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin Recipes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRecipeType = value!;
                      _selectedRecipeIds.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkUpdateForm() {
    if (_selectedRecipeIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Select recipes to perform bulk operations',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_work, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                '${_selectedRecipeIds.length} recipes selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildUpdateFields(),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _executeBulkOperation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_getOperationButtonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _clearSelection,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Selection'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateFields() {
    switch (_selectedOperation) {
      case 'update_nutrition':
        return _buildNutritionFields();
      case 'update_meal_type':
        return _buildMealTypeField();
      case 'update_cooking_time':
        return _buildCookingTimeField();
      case 'update_servings':
        return _buildServingsField();
      case 'add_tags':
        return _buildTagsField();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNutritionFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bulkUpdateData['calories'] = int.tryParse(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Protein (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bulkUpdateData['protein'] = double.tryParse(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Carbs (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bulkUpdateData['carbs'] = double.tryParse(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Fat (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bulkUpdateData['fat'] = double.tryParse(value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealTypeField() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Meal Type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
        DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
        DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
        DropdownMenuItem(value: 'snack', child: Text('Snack')),
      ],
      onChanged: (value) => _bulkUpdateData['mealType'] = value,
    );
  }

  Widget _buildCookingTimeField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Cooking Time (minutes)',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => _bulkUpdateData['cookingTime'] = int.tryParse(value),
    );
  }

  Widget _buildServingsField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Servings',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => _bulkUpdateData['servings'] = int.tryParse(value),
    );
  }

  Widget _buildTagsField() {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Tags (comma-separated)',
        border: OutlineInputBorder(),
        hintText: 'healthy, quick, vegetarian',
      ),
      onChanged: (value) => _bulkUpdateData['tags'] = value.split(',').map((e) => e.trim()).toList(),
    );
  }

  Widget _buildRecipeList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading recipes: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final recipes = snapshot.data ?? [];

        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final isSelected = _selectedRecipeIds.contains(recipe['id']);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedRecipeIds.add(recipe['id']);
                    } else {
                      _selectedRecipeIds.remove(recipe['id']);
                    }
                  });
                },
                title: Text(recipe['title'] ?? 'Untitled'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe['description'] ?? ''),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(recipe['mealType']?.toString().toUpperCase() ?? 'UNKNOWN'),
                          backgroundColor: _getMealTypeColor(recipe['mealType']),
                        ),
                        const SizedBox(width: 8),
                        if (recipe['cookingTime'] != null)
                          Chip(
                            label: Text('${recipe['cookingTime']} min'),
                            backgroundColor: Colors.blue[100],
                          ),
                        const SizedBox(width: 8),
                        if (recipe['servings'] != null)
                          Chip(
                            label: Text('${recipe['servings']} servings'),
                            backgroundColor: Colors.green[100],
                          ),
                      ],
                    ),
                  ],
                ),
                secondary: CircleAvatar(
                  backgroundColor: isSelected ? Colors.blue[600] : Colors.grey[300],
                  child: Icon(
                    isSelected ? Icons.check : Icons.restaurant_menu,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getMealTypeColor(String? mealType) {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return Colors.orange[100]!;
      case 'lunch': return Colors.green[100]!;
      case 'dinner': return Colors.blue[100]!;
      case 'snack': return Colors.purple[100]!;
      default: return Colors.grey[100]!;
    }
  }

  String _getOperationButtonText() {
    switch (_selectedOperation) {
      case 'update_nutrition': return 'Update Nutrition';
      case 'update_meal_type': return 'Update Meal Type';
      case 'update_cooking_time': return 'Update Cooking Time';
      case 'update_servings': return 'Update Servings';
      case 'add_tags': return 'Add Tags';
      case 'bulk_delete': return 'Delete Selected';
      default: return 'Execute Operation';
    }
  }

  Future<List<Map<String, dynamic>>> _getRecipes() async {
    if (_selectedRecipeType == 'filipino') {
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = data?['data'] as List<dynamic>? ?? [];
        return recipes.cast<Map<String, dynamic>>();
      }
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    }
    
    return [];
  }

  void _clearSelection() {
    setState(() {
      _selectedRecipeIds.clear();
    });
  }

  Future<void> _executeBulkOperation() async {
    if (_selectedRecipeIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;

      for (final recipeId in _selectedRecipeIds) {
        try {
          if (_selectedOperation == 'bulk_delete') {
            await _deleteRecipe(recipeId);
          } else {
            await _updateRecipe(recipeId);
          }
          successCount++;
        } catch (e) {
          print('Error processing recipe $recipeId: $e');
          errorCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk operation completed: $successCount successful, $errorCount errors',
            ),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        
        _clearSelection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error executing bulk operation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRecipe(String recipeId) async {
    final updateData = Map<String, dynamic>.from(_bulkUpdateData);
    updateData.removeWhere((key, value) => value == null);

    if (updateData.isEmpty) return;

    if (_selectedRecipeType == 'filipino') {
      // Get current recipe data
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        final recipeIndex = recipes.indexWhere((recipe) => recipe['id'] == recipeId);
        
        if (recipeIndex != -1) {
          final updatedRecipe = {
            ...recipes[recipeIndex],
            ...updateData,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          
          await FilipinoRecipeService.updateSingleCuratedFilipinoRecipe(updatedRecipe);
        }
      }
    } else {
      await RecipeService.updateSingleAdminRecipe(recipeId, updateData);
    }
  }

  Future<void> _deleteRecipe(String recipeId) async {
    if (_selectedRecipeType == 'filipino') {
      await FilipinoRecipeService.deleteCuratedFilipinoRecipe(recipeId);
    } else {
      await FirebaseFirestore.instance
          .collection('admin_recipes')
          .doc(recipeId)
          .delete();
    }
  }
}
