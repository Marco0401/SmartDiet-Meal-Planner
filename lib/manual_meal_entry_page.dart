import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/nutrition_service.dart';
import 'meal_favorites_page.dart';

class ManualMealEntryPage extends StatefulWidget {
  final String? selectedDate;
  final String? mealType;
  final Map<String, dynamic>? prefilledData;

  const ManualMealEntryPage({
    super.key,
    this.selectedDate,
    this.mealType,
    this.prefilledData,
  });

  @override
  State<ManualMealEntryPage> createState() => _ManualMealEntryPageState();
}

class _ManualMealEntryPageState extends State<ManualMealEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _servingSizeController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedMealType = 'Breakfast';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.selectedDate != null) {
      _selectedDate = DateTime.parse(widget.selectedDate!);
    }
    if (widget.mealType != null) {
      _selectedMealType = widget.mealType!;
    }
    _servingSizeController.text = '1';
    
    // Pre-fill data if provided (from barcode scanning)
    if (widget.prefilledData != null) {
      _prefillFormData(widget.prefilledData!);
    }
  }

  void _prefillFormData(Map<String, dynamic> data) {
    _foodNameController.text = data['foodName']?.toString() ?? '';
    _caloriesController.text = data['calories']?.toString() ?? '';
    _proteinController.text = data['protein']?.toString() ?? '';
    _carbsController.text = data['carbs']?.toString() ?? '';
    _fatController.text = data['fat']?.toString() ?? '';
    _fiberController.text = data['fiber']?.toString() ?? '';
    _sugarController.text = data['sugar']?.toString() ?? '';
    _sodiumController.text = data['sodium']?.toString() ?? '';
    _servingSizeController.text = data['servingSize']?.toString() ?? '1';
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _servingSizeController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _calculateNutritionFromIngredients() {
    if (_ingredientsController.text.trim().isEmpty) return;
    
    final ingredientsList = _ingredientsController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final nutrition = NutritionService.calculateRecipeNutrition(ingredientsList);
    
    setState(() {
      _caloriesController.text = nutrition['calories']!.toStringAsFixed(1);
      _proteinController.text = nutrition['protein']!.toStringAsFixed(1);
      _carbsController.text = nutrition['carbs']!.toStringAsFixed(1);
      _fatController.text = nutrition['fat']!.toStringAsFixed(1);
      _fiberController.text = nutrition['fiber']!.toStringAsFixed(1);
    });
  }

  Future<void> _saveMeal() async {
    if (_foodNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a food name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final servingSize = double.tryParse(_servingSizeController.text) ?? 1.0;
      final ingredientsList = _ingredientsController.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // Use NutritionService to save meal with proper nutrition calculation
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final nutritionData = {
        'calories': (double.tryParse(_caloriesController.text) ?? 0) * servingSize,
        'protein': (double.tryParse(_proteinController.text) ?? 0) * servingSize,
        'carbs': (double.tryParse(_carbsController.text) ?? 0) * servingSize,
        'fat': (double.tryParse(_fatController.text) ?? 0) * servingSize,
        'fiber': (double.tryParse(_fiberController.text) ?? 0) * servingSize,
      };
      
      print('DEBUG: Saving meal with date: $dateString');
      print('DEBUG: Nutrition data: $nutritionData');
      
      await NutritionService.saveMealWithNutrition(
        title: _foodNameController.text.trim(),
        date: dateString,
        mealType: _selectedMealType.toLowerCase(),
        ingredients: ingredientsList,
        instructions: _instructionsController.text.trim(),
        customNutrition: nutritionData,
      );

      // Also save to favorites (Manage Recipes) as a custom recipe
      final customRecipe = {
        'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
        'title': _foodNameController.text.trim(),
        'image': null,
        'source': 'manual_entry',
        'cuisine': 'Custom',
        'ingredients': ingredientsList,
        'instructions': _instructionsController.text.trim(),
        'nutrition': {
          'calories': (double.tryParse(_caloriesController.text) ?? 0) * servingSize,
          'protein': (double.tryParse(_proteinController.text) ?? 0) * servingSize,
          'carbs': (double.tryParse(_carbsController.text) ?? 0) * servingSize,
          'fat': (double.tryParse(_fatController.text) ?? 0) * servingSize,
          'fiber': (double.tryParse(_fiberController.text) ?? 0) * servingSize,
          'sugar': (double.tryParse(_sugarController.text) ?? 0) * servingSize,
          'sodium': (double.tryParse(_sodiumController.text) ?? 0) * servingSize,
        },
        'servings': servingSize,
        'readyInMinutes': 0, // Manual entry, no prep time
        'mealType': _selectedMealType.toLowerCase(),
      };

      // Save to favorites collection
      await FavoriteService.addToFavorites(
        context,
        customRecipe,
        notes: 'Custom recipe created on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal entry saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Manual Entry'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          if (!_isLoading)
            TextButton(
              onPressed: _saveMeal,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food Name
              Card(
                elevation: 8,
                shadowColor: Colors.green.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.green[50]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green[200]!,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Information',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _foodNameController,
                          decoration: const InputDecoration(
                            labelText: 'Food Name *',
                            hintText: 'e.g., Grilled Chicken Breast',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.restaurant),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a food name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _servingSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Serving Size',
                            hintText: '1',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                            suffixText: 'servings',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final parsed = double.tryParse(value);
                              if (parsed == null || parsed <= 0) {
                                return 'Please enter a valid serving size';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date and Meal Type
              Card(
  elevation: 8,
  shadowColor: Colors.green.withOpacity(0.3),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white,
          Colors.green[50]!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.green[200]!,
        width: 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ), // ✅ fixed here
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: _mealTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMealType = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
),
const SizedBox(height: 16),

              // Nutrition Information
              Card(
                elevation: 8,
                shadowColor: Colors.green.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition Information (per serving)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Ingredients section for auto-calculation
                      TextFormField(
                        controller: _ingredientsController,
                        decoration: InputDecoration(
                          labelText: 'Ingredients (one per line)',
                          hintText: 'e.g., 200g chicken breast\n100g rice\n50g broccoli',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calculate),
                            onPressed: _calculateNutritionFromIngredients,
                            tooltip: 'Calculate nutrition from ingredients',
                          ),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Instructions (optional)',
                          hintText: 'e.g., 1. Heat oil in a pan\n2. Add chicken and cook for 5 minutes\n3. Add vegetables and stir-fry',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _caloriesController,
                              decoration: const InputDecoration(
                                labelText: 'Calories *',
                                border: OutlineInputBorder(),
                                suffixText: 'cal',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null || parsed < 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
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
                                labelText: 'Carbohydrates',
                                border: OutlineInputBorder(),
                                suffixText: 'g',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
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
                          const SizedBox(width: 16),
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
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Meal Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
