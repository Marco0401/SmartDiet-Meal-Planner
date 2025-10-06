import 'package:flutter/material.dart';
import '../../services/nutrition_service.dart';

class ComprehensiveRecipeDialog extends StatefulWidget {
  final Map<String, dynamic>? recipe; // null for add new
  final String title;
  final Function(Map<String, dynamic>) onSave;

  const ComprehensiveRecipeDialog({
    super.key,
    required this.recipe,
    required this.title,
    required this.onSave,
  });

  @override
  State<ComprehensiveRecipeDialog> createState() => _ComprehensiveRecipeDialogState();
}

class _ComprehensiveRecipeDialogState extends State<ComprehensiveRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _cookingTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _cuisineController;
  late TextEditingController _difficultyController;
  late TextEditingController _tagsController;
  late List<TextEditingController> _ingredientControllers;
  late String _selectedMealType;
  bool _isLoading = false;

  // Nutrition data
  final Map<String, dynamic> _nutritionData = {};
  final Map<String, dynamic> _additionalData = {};

  final List<String> _mealTypes = [
    'breakfast', 'lunch', 'dinner', 'snack', 'salad', 
    'soup', 'appetizer', 'dessert', 'beverage'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.recipe?['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.recipe?['description'] ?? '');
    _instructionsController = TextEditingController(text: widget.recipe?['instructions'] ?? '');
    _cookingTimeController = TextEditingController(text: widget.recipe?['cookingTime']?.toString() ?? '');
    _servingsController = TextEditingController(text: widget.recipe?['servings']?.toString() ?? '');
    _imageUrlController = TextEditingController(text: widget.recipe?['image'] ?? '');
    _cuisineController = TextEditingController(text: widget.recipe?['cuisine'] ?? '');
    _difficultyController = TextEditingController(text: widget.recipe?['difficulty'] ?? '');
    _tagsController = TextEditingController(text: (widget.recipe?['tags'] as List<dynamic>?)?.join(', ') ?? '');
    
    final recipeMealType = widget.recipe?['mealType'] ?? 'breakfast';
    _selectedMealType = _mealTypes.contains(recipeMealType) ? recipeMealType : 'breakfast';
    
    final ingredients = widget.recipe?['ingredients'] as List<dynamic>? ?? [];
    _ingredientControllers = ingredients.map((ingredient) => 
      TextEditingController(text: ingredient.toString())
    ).toList();
    
    if (_ingredientControllers.isEmpty) {
      _ingredientControllers.add(TextEditingController());
    }

    // Initialize nutrition data
    final nutrition = widget.recipe?['nutrition'] as Map<String, dynamic>? ?? {};
    _nutritionData['calories'] = nutrition['calories']?.toString() ?? '';
    _nutritionData['protein'] = nutrition['protein']?.toString() ?? '';
    _nutritionData['carbs'] = nutrition['carbs']?.toString() ?? '';
    _nutritionData['fat'] = nutrition['fat']?.toString() ?? '';
    _nutritionData['fiber'] = nutrition['fiber']?.toString() ?? '';
    _nutritionData['sugar'] = nutrition['sugar']?.toString() ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    _imageUrlController.dispose();
    _cuisineController.dispose();
    _difficultyController.dispose();
    _tagsController.dispose();
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 600,
        height: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information Section
                _buildSectionHeader('Basic Information'),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Title *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Chicken Adobo',
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    hintText: 'Brief description of the recipe...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMealType,
                        decoration: const InputDecoration(
                          labelText: 'Meal Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: _mealTypes.map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedMealType = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cookingTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Cooking Time (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _servingsController,
                        decoration: const InputDecoration(
                          labelText: 'Servings',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com/image.jpg',
                  ),
                ),

                // Ingredients Section
                const SizedBox(height: 24),
                _buildSectionHeader('Ingredients'),
                ..._ingredientControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Ingredient ${index + 1}',
                              border: const OutlineInputBorder(),
                              hintText: 'e.g., 2 cups rice, 1 onion, 3 cloves garlic',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            if (_ingredientControllers.length > 1) {
                              setState(() {
                                controller.dispose();
                                _ingredientControllers.removeAt(index);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _ingredientControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ingredient'),
                ),

                // Instructions Section
                const SizedBox(height: 24),
                _buildSectionHeader('Instructions'),
                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Cooking Instructions *',
                    border: OutlineInputBorder(),
                    hintText: 'Step-by-step cooking instructions...',
                  ),
                  maxLines: 6,
                  validator: (value) => value?.isEmpty == true ? 'Instructions are required' : null,
                ),

                // Nutrition Section
                const SizedBox(height: 24),
                _buildSectionHeader('Nutrition Information'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['calories']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Calories',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['calories'] = int.tryParse(value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['protein']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['protein'] = double.tryParse(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['carbs']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['carbs'] = double.tryParse(value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['fat']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['fat'] = double.tryParse(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['fiber']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Fiber (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['fiber'] = double.tryParse(value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _nutritionData['sugar']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Sugar (g)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _nutritionData['sugar'] = double.tryParse(value),
                      ),
                    ),
                  ],
                ),

                // Additional Information Section
                const SizedBox(height: 24),
                _buildSectionHeader('Additional Information'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cuisineController,
                        decoration: const InputDecoration(
                          labelText: 'Cuisine Type',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Filipino, Italian, Chinese',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _difficultyController,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty Level',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Easy, Medium, Hard',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., healthy, quick, vegetarian, spicy',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveRecipe,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.recipe == null ? 'Add Recipe' : 'Save Changes'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final ingredients = _ingredientControllers
          .map((controller) => controller.text.trim())
          .where((ingredient) => ingredient.isNotEmpty)
          .toList();

      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final recipeData = {
        if (widget.recipe != null) ...widget.recipe!, // Preserve existing fields for updates
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'ingredients': ingredients,
        'mealType': _selectedMealType,
        'cookingTime': int.tryParse(_cookingTimeController.text.trim()) ?? 0,
        'servings': int.tryParse(_servingsController.text.trim()) ?? 1,
        'image': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        'cuisine': _cuisineController.text.trim(),
        'difficulty': _difficultyController.text.trim(),
        'tags': tags,
        'nutrition': {
          'calories': _nutritionData['calories'],
          'protein': _nutritionData['protein'],
          'carbs': _nutritionData['carbs'],
          'fat': _nutritionData['fat'],
          'fiber': _nutritionData['fiber'],
          'sugar': _nutritionData['sugar'],
        },
        'updatedAt': DateTime.now().toIso8601String(),
      };

      widget.onSave(recipeData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recipe == null ? 'Recipe added successfully!' : 'Recipe updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
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
}
