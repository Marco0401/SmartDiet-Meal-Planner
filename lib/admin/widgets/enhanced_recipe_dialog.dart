import 'package:flutter/material.dart';
import '../../services/nutrition_service.dart';

class EnhancedRecipeDialog extends StatefulWidget {
  final Map<String, dynamic>? recipe; // null for add new
  final String title;
  final Function(Map<String, dynamic>) onSave;

  const EnhancedRecipeDialog({
    super.key,
    required this.recipe,
    required this.title,
    required this.onSave,
  });

  @override
  State<EnhancedRecipeDialog> createState() => _EnhancedRecipeDialogState();
}

class _EnhancedRecipeDialogState extends State<EnhancedRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _cookingTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _imageUrlController;
  late List<IngredientController> _ingredientControllers;
  late String _selectedMealType;
  late String _selectedCuisine;
  late String _selectedDifficulty;
  late String _selectedDietType;
  bool _isLoading = false;
  bool _autoCalculateNutrition = true;

  // Nutrition data
  Map<String, double> _calculatedNutrition = {};

  final List<String> _mealTypes = [
    'breakfast', 'lunch', 'dinner', 'snack', 'salad', 
    'soup', 'appetizer', 'dessert', 'beverage'
  ];

  final List<String> _cuisines = [
    'Filipino', 'Italian', 'Chinese', 'Japanese', 'Korean', 'Thai', 'Indian',
    'Mexican', 'American', 'French', 'Mediterranean', 'Middle Eastern',
    'Vietnamese', 'Spanish', 'German', 'Other'
  ];

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Expert'];

  final List<String> _dietTypes = [
    'Regular', 'Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free',
    'Keto', 'Paleo', 'Low-Carb', 'High-Protein', 'Mediterranean'
  ];

  final List<String> _units = [
    'cup', 'tbsp', 'tsp', 'oz', 'lb', 'g', 'kg', 'ml', 'l', 'piece',
    'slice', 'clove', 'bunch', 'head', 'can', 'package', 'pinch', 'dash'
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
    _servingsController = TextEditingController(text: widget.recipe?['servings']?.toString() ?? '1');
    _imageUrlController = TextEditingController(text: widget.recipe?['image'] ?? '');
    
    final recipeMealType = widget.recipe?['mealType'] ?? 'breakfast';
    _selectedMealType = _mealTypes.contains(recipeMealType) ? recipeMealType : 'breakfast';
    
    _selectedCuisine = widget.recipe?['cuisine'] ?? 'Filipino';
    _selectedDifficulty = widget.recipe?['difficulty'] ?? 'Easy';
    _selectedDietType = widget.recipe?['dietType'] ?? 'Regular';
    
    // Initialize ingredients
    final ingredients = widget.recipe?['ingredients'] as List<dynamic>? ?? [];
    _ingredientControllers = [];
    
    if (ingredients.isNotEmpty) {
      for (final ingredient in ingredients) {
        if (ingredient is Map<String, dynamic>) {
          _ingredientControllers.add(IngredientController(
            amount: TextEditingController(text: ingredient['amount']?.toString() ?? '1'),
            unit: ingredient['unit'] ?? 'cup',
            name: TextEditingController(text: ingredient['name'] ?? ''),
          ));
        } else {
          _ingredientControllers.add(IngredientController(
            amount: TextEditingController(text: '1'),
            unit: 'cup',
            name: TextEditingController(text: ingredient.toString()),
          ));
        }
      }
    }
    
    if (_ingredientControllers.isEmpty) {
      _ingredientControllers.add(IngredientController(
        amount: TextEditingController(text: '1'),
        unit: 'cup',
        name: TextEditingController(),
      ));
    }

    // Initialize nutrition with safe type conversion
    final nutritionData = widget.recipe?['nutrition'] as Map<String, dynamic>? ?? {};
    _calculatedNutrition = {
      'calories': _safeDouble(nutritionData['calories']),
      'protein': _safeDouble(nutritionData['protein']),
      'carbs': _safeDouble(nutritionData['carbs']),
      'fat': _safeDouble(nutritionData['fat']),
      'fiber': _safeDouble(nutritionData['fiber']),
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    _imageUrlController.dispose();
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 900,
        height: 700,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.purple[50]!],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),
                      _buildIngredientsSection(),
                      const SizedBox(height: 24),
                      _buildInstructionsSection(),
                      const SizedBox(height: 24),
                      _buildNutritionSection(),
                      const SizedBox(height: 24),
                      _buildAdditionalInfoSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.purple[600]!],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.recipe == null ? 'Create a new recipe' : 'Edit existing recipe',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Recipe Title *',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedMealType,
                decoration: InputDecoration(
                  labelText: 'Meal Type *',
                  prefixIcon: const Icon(Icons.schedule),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _mealTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                )).toList(),
                onChanged: (value) => setState(() => _selectedMealType = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cookingTimeController,
                        decoration: InputDecoration(
                          labelText: 'Cooking Time (min)',
                          prefixIcon: const Icon(Icons.timer, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _servingsController,
                        decoration: InputDecoration(
                          labelText: 'Servings',
                          prefixIcon: const Icon(Icons.people, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _calculateNutrition(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          prefixIcon: const Icon(Icons.image, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return _buildSection(
      title: 'Ingredients',
      icon: Icons.list_alt,
      children: [
        ..._ingredientControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: controller.amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _calculateNutrition(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: controller.unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    items: _units.map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => controller.unit = value!);
                      _calculateNutrition();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: controller.name,
                    decoration: const InputDecoration(
                      labelText: 'Ingredient Name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                    onChanged: (value) => _calculateNutrition(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    if (_ingredientControllers.length > 1) {
                      setState(() {
                        controller.dispose();
                        _ingredientControllers.removeAt(index);
                        _calculateNutrition();
                      });
                    }
                  },
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _ingredientControllers.add(IngredientController(
                amount: TextEditingController(text: '1'),
                unit: 'cup',
                name: TextEditingController(),
              ));
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Ingredient'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return _buildSection(
      title: 'Instructions',
      icon: Icons.format_list_numbered,
      children: [
        TextFormField(
          controller: _instructionsController,
          decoration: InputDecoration(
            labelText: 'Cooking Instructions *',
            prefixIcon: const Icon(Icons.article),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Step-by-step cooking instructions...',
          ),
          maxLines: 6,
          validator: (value) => value?.isEmpty == true ? 'Instructions are required' : null,
        ),
      ],
    );
  }

  Widget _buildNutritionSection() {
    return _buildSection(
      title: 'Nutrition Information',
      icon: Icons.analytics,
      children: [
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Auto-calculate from ingredients'),
                value: _autoCalculateNutrition,
                onChanged: (value) {
                  setState(() {
                    _autoCalculateNutrition = value ?? true;
                    if (_autoCalculateNutrition) {
                      _calculateNutrition();
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            if (!_autoCalculateNutrition)
              ElevatedButton.icon(
                onPressed: _calculateNutrition,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionField('Calories', _calculatedNutrition['calories'] ?? 0.0, 'kcal'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNutritionField('Protein', _calculatedNutrition['protein'] ?? 0.0, 'g'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionField('Carbs', _calculatedNutrition['carbs'] ?? 0.0, 'g'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNutritionField('Fat', _calculatedNutrition['fat'] ?? 0.0, 'g'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionField('Fiber', _calculatedNutrition['fiber'] ?? 0.0, 'g'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(), // Empty for alignment
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionField(String label, double value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return _buildSection(
      title: 'Additional Information',
      icon: Icons.settings,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCuisine,
                decoration: InputDecoration(
                  labelText: 'Cuisine Type',
                  prefixIcon: const Icon(Icons.flag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _cuisines.map((cuisine) => DropdownMenuItem(
                  value: cuisine,
                  child: Text(cuisine),
                )).toList(),
                onChanged: (value) => setState(() => _selectedCuisine = value!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: InputDecoration(
                  labelText: 'Difficulty Level',
                  prefixIcon: const Icon(Icons.trending_up),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _difficulties.map((difficulty) => DropdownMenuItem(
                  value: difficulty,
                  child: Text(difficulty),
                )).toList(),
                onChanged: (value) => setState(() => _selectedDifficulty = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedDietType,
          decoration: InputDecoration(
            labelText: 'Diet Type',
            prefixIcon: const Icon(Icons.restaurant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _dietTypes.map((diet) => DropdownMenuItem(
            value: diet,
            child: Text(diet),
          )).toList(),
          onChanged: (value) => setState(() => _selectedDietType = value!),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue[600], size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveRecipe,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.recipe == null ? 'Add Recipe' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  void _calculateNutrition() async {
    if (!_autoCalculateNutrition) return;

    final ingredients = _ingredientControllers
        .map((controller) => '${controller.amount.text} ${controller.unit} ${controller.name.text}')
        .where((ingredient) => ingredient.trim().isNotEmpty)
        .toList();

    if (ingredients.isNotEmpty) {
      final nutrition = await NutritionService.calculateRecipeNutrition(ingredients);
      if (mounted) {
        setState(() {
          _calculatedNutrition = nutrition;
        });
      }
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final ingredients = _ingredientControllers
          .map((controller) => {
                'amount': double.tryParse(controller.amount.text) ?? 1.0,
                'unit': controller.unit,
                'name': controller.name.text.trim(),
                'original': '${controller.amount.text} ${controller.unit} ${controller.name.text.trim()}',
              })
          .where((ingredient) => ingredient['name'].toString().isNotEmpty)
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
        'cuisine': _selectedCuisine,
        'difficulty': _selectedDifficulty,
        'dietType': _selectedDietType,
        'nutrition': _calculatedNutrition,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      widget.onSave(recipeData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recipe == null ? 'Recipe added successfully!' : 'Recipe updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class IngredientController {
  final TextEditingController amount;
  final TextEditingController name;
  String unit;

  IngredientController({
    required this.amount,
    required this.name,
    required this.unit,
  });

  void dispose() {
    amount.dispose();
    name.dispose();
  }
}
