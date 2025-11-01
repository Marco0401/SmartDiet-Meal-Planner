import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'services/nutrition_service.dart';
import 'services/nutrition_progress_notifier.dart';
import 'services/allergen_detection_service.dart';
import 'services/allergen_service.dart';
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
  final _cookingTimeController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedMealType = 'Breakfast';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Smart Entry Mode Toggle
  bool _smartEntryMode = true; // Default ON
  
  // Smart Entry Mode data
  List<Map<String, dynamic>> _editedIngredients = [];
  List<String> _instructionSteps = [];
  List<String> _ingredientSearchResults = [];
  List<String> _availableIngredients = [];
  Map<String, dynamic> _calculatedNutrition = {};
  
  // Edit mode tracking
  bool _isEditMode = false;
  String? _editingMealId; // For meal planner
  String? _editingFavoriteId; // For favorites

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
    _cookingTimeController.text = '30'; // Default 30 minutes
    
    // Load available ingredients for smart mode
    _loadAvailableIngredients();
    
    // Pre-fill data if provided (from barcode scanning)
    if (widget.prefilledData != null) {
      _prefillFormData(widget.prefilledData!);
    }
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
    _cookingTimeController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _prefillFormData(Map<String, dynamic> data) {
    // Detect edit mode
    _isEditMode = data['id'] != null || data['docId'] != null;
    _editingMealId = data['id']?.toString();
    _editingFavoriteId = data['docId']?.toString();
    
    print('DEBUG: Prefill - Edit mode: $_isEditMode, MealId: $_editingMealId, FavoriteId: $_editingFavoriteId');
    
    // Handle both barcode format and manual entry format
    _foodNameController.text = data['title']?.toString() ?? data['foodName']?.toString() ?? '';
    
    // Get nutrition data
    final nutrition = data['nutrition'] as Map<String, dynamic>?;
    if (nutrition != null) {
      _caloriesController.text = nutrition['calories']?.toString() ?? '';
      _proteinController.text = nutrition['protein']?.toString() ?? '';
      _carbsController.text = nutrition['carbs']?.toString() ?? '';
      _fatController.text = nutrition['fat']?.toString() ?? '';
      _fiberController.text = nutrition['fiber']?.toString() ?? '';
      _sugarController.text = nutrition['sugar']?.toString() ?? '';
      _sodiumController.text = nutrition['sodium']?.toString() ?? '';
    } else {
      // Fallback to direct fields for barcode format
      _caloriesController.text = data['calories']?.toString() ?? '';
      _proteinController.text = data['protein']?.toString() ?? '';
      _carbsController.text = data['carbs']?.toString() ?? '';
      _fatController.text = data['fat']?.toString() ?? '';
      _fiberController.text = data['fiber']?.toString() ?? '';
      _sugarController.text = data['sugar']?.toString() ?? '';
      _sodiumController.text = data['sodium']?.toString() ?? '';
    }
    
    _servingSizeController.text = data['servings']?.toString() ?? data['servingSize']?.toString() ?? '1';
    _cookingTimeController.text = data['cookingTime']?.toString() ?? data['readyInMinutes']?.toString() ?? '30';
    
    // Handle ingredients and instructions for manual entry format
    final ingredients = data['ingredients'];
    if (ingredients is List) {
      // Smart mode: Populate _editedIngredients for structured list
      _smartEntryMode = true;
      _editedIngredients = ingredients.map((ing) {
        if (ing is String) {
          // Parse string format: "2 cup rice" -> {amount: 2, unit: cup, name: rice}
          final parsed = _parseIngredientString(ing);
          return {
            'name': parsed['name'] ?? ing,
            'amount': parsed['amount'] ?? 1.0,
            'unit': parsed['unit'] ?? 'piece',
            'amountDisplay': parsed['amountDisplay'] ?? '1',
            'original': ing,
            'nutrition': <String, double>{}, // Will calculate next
          };
        }
        return ing as Map<String, dynamic>;
      }).toList();
      
      // Calculate nutrition for each prefilled ingredient
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        for (int i = 0; i < _editedIngredients.length; i++) {
          final ing = _editedIngredients[i];
          final nutrition = await _calculateIndividualNutrition(
            ing['name']?.toString() ?? '',
            ing['amount'] as double,
            ing['unit']?.toString() ?? 'piece',
          );
          if (mounted) {
            setState(() {
              _editedIngredients[i]['nutrition'] = nutrition;
            });
          }
        }
        // After all ingredients have nutrition, recalculate total
        if (mounted) {
          _recalculateNutrition();
        }
      });
    } else if (ingredients is String && ingredients.isNotEmpty) {
      // Manual mode: Plain text
      _smartEntryMode = false;
      _ingredientsController.text = ingredients;
    }
    
    final instructions = data['instructions'];
    if (instructions is List) {
      _instructionSteps = List<String>.from(instructions);
    } else if (instructions is String && instructions.isNotEmpty) {
      // Parse numbered instructions
      _instructionSteps = instructions.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), ''))
          .toList();
      if (_instructionSteps.isEmpty) {
        _instructionSteps = [instructions];
      }
    }
    
    // Handle image
    if (data['image'] != null) {
      final imagePath = data['image'].toString();
      if (imagePath.startsWith('/') || imagePath.contains('/data/')) {
        _selectedImage = File(imagePath);
      }
    }
  }

  void _calculateNutritionFromIngredients() async {
    if (_ingredientsController.text.trim().isEmpty) return;
    
    final ingredientsList = _ingredientsController.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final nutrition = await NutritionService.calculateRecipeNutrition(ingredientsList);
    
    if (mounted) {
      setState(() {
        _caloriesController.text = nutrition['calories']!.toStringAsFixed(1);
        _proteinController.text = nutrition['protein']!.toStringAsFixed(1);
        _carbsController.text = nutrition['carbs']!.toStringAsFixed(1);
        _fatController.text = nutrition['fat']!.toStringAsFixed(1);
        _fiberController.text = nutrition['fiber']!.toStringAsFixed(1);
      });
    }
  }
  
  // ============ SMART ENTRY MODE METHODS ============
  
  Future<void> _loadAvailableIngredients() async {
    try {
      // Fetch from Firestore system_data/ingredient_nutrition
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final ingredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
        if (ingredients.isNotEmpty) {
          setState(() {
            _availableIngredients = ingredients.keys.toList();
          });
          print('DEBUG: Loaded ${ingredients.length} ingredients from Firestore');
          return;
        }
      }
    } catch (e) {
      print('Error loading ingredients from Firestore: $e');
    }
    
    // Fallback to hardcoded list if Firestore fails
    print('DEBUG: Falling back to hardcoded ingredient list');
    setState(() {
      _availableIngredients = [
        'chicken breast', 'beef', 'pork', 'fish', 'eggs', 'milk', 'cheese',
        'rice', 'pasta', 'bread', 'potato', 'sweet potato',
        'broccoli', 'spinach', 'carrot', 'tomato', 'onion', 'garlic',
        'olive oil', 'butter', 'salt', 'pepper', 'soy sauce',
      ];
    });
  }
  
  Map<String, dynamic> _parseIngredientString(String text) {
    // Parse "2 tbsp olive oil" into {amount: 2, unit: tbsp, name: olive oil}
    final RegExp pattern = RegExp(r'^(\d+(?:[\/\.]\d+)?)\s*([a-zA-Z]+)?\s+(.+)$');
    final match = pattern.firstMatch(text.trim());
    
    if (match != null) {
      final amountStr = match.group(1)!;
      double amount = double.tryParse(amountStr) ?? 1.0;
      
      // Handle fractions like "1/2"
      if (amountStr.contains('/')) {
        final parts = amountStr.split('/');
        amount = double.parse(parts[0]) / double.parse(parts[1]);
      }
      
      return {
        'amount': amount,
        'unit': match.group(2)?.toLowerCase() ?? 'piece',
        'name': match.group(3)!.trim(),
        'original': text,
      };
    }
    
    // Fallback: treat whole string as ingredient name
    return {
      'amount': 1.0,
      'unit': 'piece',
      'name': text.trim(),
      'original': text,
    };
  }
  
  void _searchIngredients(String query) {
    if (query.isEmpty) {
      setState(() => _ingredientSearchResults = []);
      return;
    }
    
    final queryLower = query.toLowerCase();
    final matches = _availableIngredients.where((ingredient) {
      return ingredient.toLowerCase().contains(queryLower);
    }).toList();
    
    setState(() {
      _ingredientSearchResults = matches.take(10).toList();
    });
  }
  
  Future<void> _addIngredient(String ingredientName) async {
    // Check if already exists
    if (_editedIngredients.any((ing) => ing['name'] == ingredientName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$ingredientName is already in the list')),
      );
      return;
    }
    
    // Check for allergens first
    final userAllergens = await AllergenDetectionService.getUserAllergens();
    final detectedAllergens = AllergenService.checkAllergens([ingredientName]);
    
    if (userAllergens.isNotEmpty && detectedAllergens.isNotEmpty) {
      final hasConflict = detectedAllergens.entries.any((entry) {
        final allergenType = entry.key;
        final allergens = entry.value;
        
        // Check if this allergen type matches any user allergen
        return userAllergens.any((userAllergen) =>
            userAllergen.toLowerCase() == allergenType.toLowerCase()) &&
            allergens.isNotEmpty;
      });

      if (hasConflict) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Allergen Warning'),
            content: Text(
              'This ingredient may contain allergens you\'re sensitive to.\n\n'
              'Detected allergens: ${detectedAllergens.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('\n')}\n\n'
              'Do you want to continue or find a substitution?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Find Substitution'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );

        if (shouldContinue == false) {
          await _showSubstitutionDialog(ingredientName, detectedAllergens);
          return;
        }
      }
    }
    
    // Prompt for amount and unit
    final amountController = TextEditingController(text: '1');
    String selectedUnit = 'piece';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Amount for $ingredientName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (e.g., 1, 2, 1/2)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'g', child: Text('g (gram)')),
                  DropdownMenuItem(value: 'kg', child: Text('kg (kilogram)')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp (tablespoon)')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp (teaspoon)')),
                  DropdownMenuItem(value: 'piece', child: Text('piece')),
                  DropdownMenuItem(value: 'slice', child: Text('slice')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedUnit = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'amount': amountController.text,
                  'unit': selectedUnit,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      double amount = 1.0;
      String amountDisplay = result['amount'].toString();
      
      if (amountDisplay.contains('/')) {
        final parts = amountDisplay.split('/');
        amount = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        amount = double.tryParse(amountDisplay) ?? 1.0;
      }
      
      // Calculate individual nutrition for this ingredient
      final individualNutrition = await _calculateIndividualNutrition(
        ingredientName,
        amount,
        result['unit'],
      );
      
      setState(() {
        _editedIngredients.add({
          'name': ingredientName,
          'amount': amount,
          'amountDisplay': amountDisplay,
          'unit': result['unit'],
          'original': '$amountDisplay ${result['unit']} $ingredientName',
          'nutrition': individualNutrition, // Store individual nutrition
        });
        _searchController.clear();
        _ingredientSearchResults = [];
      });
      
      _recalculateNutrition();
    }
  }
  
  Future<void> _showSubstitutionDialog(String ingredient, Map<String, List<String>> detectedAllergens) async {
    final substitutions = <String>[];
    
    for (final allergenEntry in detectedAllergens.entries) {
      final allergenType = allergenEntry.key;
      final subs = await AllergenService.getSubstitutions(allergenType);
      substitutions.addAll(subs);
    }

    if (substitutions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No substitutions available for $ingredient')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Substitute Ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: substitutions.take(5).map((sub) {
            return ListTile(
              title: Text(sub),
              onTap: () {
                Navigator.pop(context);
                _addIngredient(sub);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Future<Map<String, double>> _calculateIndividualNutrition(
    String ingredientName,
    double amount,
    String unit,
  ) async {
    try {
      // Fetch raw nutrition from Firestore (per 100g)
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();
      
      if (!doc.exists) {
        print('DEBUG: ingredient_nutrition document not found');
        return _getDefaultNutrition();
      }
      
      final data = doc.data();
      final ingredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
      
      // Find ingredient (case-insensitive)
      final ingredientLower = ingredientName.toLowerCase().trim();
      Map<String, dynamic>? ingredientData;
      
      // Try exact match first
      for (final entry in ingredients.entries) {
        if (entry.key.toLowerCase() == ingredientLower) {
          ingredientData = Map<String, dynamic>.from(entry.value);
          print('DEBUG: Found exact match: ${entry.key}');
          break;
        }
      }
      
      // Try partial match if exact not found
      if (ingredientData == null) {
        for (final entry in ingredients.entries) {
          if (entry.key.toLowerCase().contains(ingredientLower) || 
              ingredientLower.contains(entry.key.toLowerCase())) {
            ingredientData = Map<String, dynamic>.from(entry.value);
            print('DEBUG: Found partial match: ${entry.key}');
            break;
          }
        }
      }
      
      if (ingredientData == null) {
        print('DEBUG: No match found for: $ingredientName');
        return _getDefaultNutrition();
      }
      
      // Get base nutrition per 100g
      final baseCalories = (ingredientData['calories'] ?? 0).toDouble();
      final baseProtein = (ingredientData['protein'] ?? 0).toDouble();
      final baseCarbs = (ingredientData['carbs'] ?? 0).toDouble();
      final baseFat = (ingredientData['fat'] ?? 0).toDouble();
      final baseFiber = (ingredientData['fiber'] ?? 0).toDouble();
      
      // Convert amount to grams
      final amountInGrams = NutritionService.convertToGrams(amount, unit);
      
      // Calculate actual nutrition based on amount
      // Database values are per 100g
      final servingFactor = amountInGrams / 100.0;
      
      final nutrition = <String, double>{
        'calories': baseCalories * servingFactor,
        'protein': baseProtein * servingFactor,
        'carbs': baseCarbs * servingFactor,
        'fat': baseFat * servingFactor,
        'fiber': baseFiber * servingFactor,
      };
      
      print('DEBUG: Calculated nutrition for $amount$unit $ingredientName: $nutrition');
      return nutrition;
      
    } catch (e) {
      print('Error calculating individual nutrition: $e');
      return _getDefaultNutrition();
    }
  }
  
  Map<String, double> _getDefaultNutrition() {
    return <String, double>{
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
    };
  }
  
  void _removeIngredient(int index) {
    setState(() {
      _editedIngredients.removeAt(index);
    });
    _recalculateNutrition();
  }
  
  Future<void> _replaceIngredient(int index) async {
    // Show searchable dialog to pick replacement from database
    final selectedIngredient = await showDialog<String>(
      context: context,
      builder: (context) => _SearchIngredientDialog(
        availableIngredients: _availableIngredients,
      ),
    );
    
    if (selectedIngredient == null) return;
    
    // Prompt for amount and unit with current values prefilled
    final currentIngredient = _editedIngredients[index];
    final amountController = TextEditingController(
      text: currentIngredient['amountDisplay']?.toString() ?? currentIngredient['amount']?.toString() ?? '1'
    );
    String selectedUnit = currentIngredient['unit']?.toString() ?? 'piece';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Amount for $selectedIngredient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (e.g., 1, 2, 1/2)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'g', child: Text('g (gram)')),
                  DropdownMenuItem(value: 'kg', child: Text('kg (kilogram)')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp (tablespoon)')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp (teaspoon)')),
                  DropdownMenuItem(value: 'piece', child: Text('piece')),
                  DropdownMenuItem(value: 'slice', child: Text('slice')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedUnit = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'amount': amountController.text,
                  'unit': selectedUnit,
                });
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      double amount = 1.0;
      String amountDisplay = result['amount'].toString();
      
      if (amountDisplay.contains('/')) {
        final parts = amountDisplay.split('/');
        amount = double.parse(parts[0]) / double.parse(parts[1]);
      } else {
        amount = double.tryParse(amountDisplay) ?? 1.0;
      }
      
      // Calculate nutrition for new ingredient
      final individualNutrition = await _calculateIndividualNutrition(
        selectedIngredient,
        amount,
        result['unit'],
      );
      
      setState(() {
        _editedIngredients[index] = {
          'name': selectedIngredient,
          'amount': amount,
          'amountDisplay': amountDisplay,
          'unit': result['unit'],
          'original': '$amountDisplay ${result['unit']} $selectedIngredient',
          'nutrition': individualNutrition,
        };
      });
      
      _recalculateNutrition();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Replaced with $selectedIngredient')),
      );
    }
  }
  
  void _addInstructionStep() {
    setState(() {
      _instructionSteps.add('');
    });
  }
  
  void _removeInstructionStep(int index) {
    setState(() {
      _instructionSteps.removeAt(index);
    });
  }
  
  Future<void> _recalculateNutrition() async {
    if (_editedIngredients.isEmpty) {
      setState(() {
        _calculatedNutrition = {
          'calories': 0.0,
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 0.0,
          'fiber': 0.0,
        };
      });
      return;
    }
    
    // Sum up individual ingredient nutrition (already calculated correctly)
    double totalCalories = 0.0;
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;
    
    for (final ingredient in _editedIngredients) {
      final nutrition = ingredient['nutrition'] as Map<String, double>?;
      if (nutrition != null) {
        totalCalories += nutrition['calories'] ?? 0.0;
        totalProtein += nutrition['protein'] ?? 0.0;
        totalCarbs += nutrition['carbs'] ?? 0.0;
        totalFat += nutrition['fat'] ?? 0.0;
        totalFiber += nutrition['fiber'] ?? 0.0;
      }
    }
    
    if (mounted) {
      setState(() {
        _calculatedNutrition = {
          'calories': totalCalories,
          'protein': totalProtein,
          'carbs': totalCarbs,
          'fat': totalFat,
          'fiber': totalFiber,
        };
      });
    }
  }
  
  // ============ UI BUILDER METHODS ============
  
  Widget _buildSmartModeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients & Nutrition',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 12),
        
        // Info notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All ingredient nutrition values are based on per 100g. The system automatically calculates based on the amount you enter.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Ingredient search
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search Ingredients',
            hintText: 'e.g., chicken breast, rice, broccoli',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _ingredientSearchResults = []);
                    },
                  )
                : null,
          ),
          onChanged: _searchIngredients,
        ),
        
        // Search results
        if (_ingredientSearchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _ingredientSearchResults.length,
              itemBuilder: (context, index) {
                final ingredient = _ingredientSearchResults[index];
                return ListTile(
                  dense: true,
                  title: Text(ingredient),
                  leading: const Icon(Icons.add_circle_outline, size: 18),
                  onTap: () => _addIngredient(ingredient),
                );
              },
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Added ingredients list
        if (_editedIngredients.isNotEmpty) ...[
          Text(
            'Ingredients (${_editedIngredients.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_editedIngredients.length, (index) {
            final ing = _editedIngredients[index];
            final nutrition = ing['nutrition'] as Map<String, double>?;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ing['name'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${ing['amountDisplay'] ?? ing['amount']} ${ing['unit']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                          tooltip: 'Replace',
                          onPressed: () => _replaceIngredient(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _removeIngredient(index),
                        ),
                      ],
                    ),
                    if (nutrition != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutrientBadge(
                            '${nutrition['calories']?.toStringAsFixed(0) ?? '0'}',
                            'Cal',
                            Colors.orange,
                          ),
                          _buildNutrientBadge(
                            '${nutrition['protein']?.toStringAsFixed(1) ?? '0'}g',
                            'P',
                            Colors.blue,
                          ),
                          _buildNutrientBadge(
                            '${nutrition['carbs']?.toStringAsFixed(1) ?? '0'}g',
                            'C',
                            Colors.green,
                          ),
                          _buildNutrientBadge(
                            '${nutrition['fat']?.toStringAsFixed(1) ?? '0'}g',
                            'F',
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        
        // Instructions
        Text(
          'Instructions:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_instructionSteps.length, (index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
              ),
              title: TextField(
                decoration: const InputDecoration(
                  hintText: 'Enter instruction step',
                  border: InputBorder.none,
                ),
                onChanged: (value) => _instructionSteps[index] = value,
                controller: TextEditingController(text: _instructionSteps[index])
                  ..selection = TextSelection.collapsed(offset: _instructionSteps[index].length),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeInstructionStep(index),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addInstructionStep,
          icon: const Icon(Icons.add),
          label: const Text('Add Instruction Step'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // Calculated nutrition display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Calculated Nutrition',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildNutrientRow('Calories', _calculatedNutrition['calories'] ?? 0, 'kcal'),
              _buildNutrientRow('Protein', _calculatedNutrition['protein'] ?? 0, 'g'),
              _buildNutrientRow('Carbs', _calculatedNutrition['carbs'] ?? 0, 'g'),
              _buildNutrientRow('Fat', _calculatedNutrition['fat'] ?? 0, 'g'),
              _buildNutrientRow('Fiber', _calculatedNutrition['fiber'] ?? 0, 'g'),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildNutrientRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNutrientBadge(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildManualModeUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients & Instructions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        const SizedBox(height: 16),
        
        // Ingredients text field
        TextFormField(
          controller: _ingredientsController,
          decoration: const InputDecoration(
            labelText: 'Ingredients (one per line)',
            hintText: 'e.g., 200g chicken breast\n100g rice\n50g broccoli',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        
        // Instructions text field
        TextFormField(
          controller: _instructionsController,
          decoration: const InputDecoration(
            labelText: 'Instructions (optional)',
            hintText: 'e.g., 1. Heat oil\n2. Cook chicken\n3. Serve',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        
        // Manual nutrition inputs
        Text(
          'Manual Nutrition Entry:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories *',
                  border: OutlineInputBorder(),
                  suffixText: 'kcal',
                ),
                keyboardType: TextInputType.number,
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
                  labelText: 'Carbs',
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
    );
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
      
      // Prepare ingredients and instructions based on mode
      List<String> ingredientsList;
      String instructionsText;
      Map<String, double> nutritionData;
      
      if (_smartEntryMode) {
        // Smart Mode: Use structured ingredients and instructions
        ingredientsList = _editedIngredients
            .map((ing) => ing['original'].toString())
            .toList();
        
        // Join instruction steps with numbering
        instructionsText = _instructionSteps
            .asMap()
            .entries
            .where((entry) => entry.value.trim().isNotEmpty)
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');
        
        // Use calculated nutrition from ingredients
        nutritionData = {
          'calories': (_calculatedNutrition['calories'] ?? 0.0) * servingSize,
          'protein': (_calculatedNutrition['protein'] ?? 0.0) * servingSize,
          'carbs': (_calculatedNutrition['carbs'] ?? 0.0) * servingSize,
          'fat': (_calculatedNutrition['fat'] ?? 0.0) * servingSize,
          'fiber': (_calculatedNutrition['fiber'] ?? 0.0) * servingSize,
        };
      } else {
        // Manual Mode: Use text fields (PRESERVES USER INPUT)
        ingredientsList = _ingredientsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        instructionsText = _instructionsController.text.trim();
        
        // Use manually entered nutrition values (NO CALCULATION INTERFERENCE)
        nutritionData = {
          'calories': (double.tryParse(_caloriesController.text) ?? 0) * servingSize,
          'protein': (double.tryParse(_proteinController.text) ?? 0) * servingSize,
          'carbs': (double.tryParse(_carbsController.text) ?? 0) * servingSize,
          'fat': (double.tryParse(_fatController.text) ?? 0) * servingSize,
          'fiber': (double.tryParse(_fiberController.text) ?? 0) * servingSize,
        };
      }

      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      print('DEBUG: Edit mode: $_isEditMode');
      print('DEBUG: Meal ID: $_editingMealId, Favorite ID: $_editingFavoriteId');
      print('DEBUG: Mode: ${_smartEntryMode ? "Smart" : "Manual"}');
      print('DEBUG: Nutrition data: $nutritionData');
      
      if (_isEditMode) {
        // UPDATE EXISTING RECIPE
        if (_editingMealId != null) {
          // Update meal planner entry
          print('DEBUG: Updating meal planner entry: $_editingMealId');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meal_plans')
              .doc(_editingMealId)
              .update({
            'title': _foodNameController.text.trim(),
            'ingredients': ingredientsList,
            'instructions': instructionsText,
            'nutrition': nutritionData, // Direct nutrition, no scaling
            'image': _selectedImage?.path,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        
        if (_editingFavoriteId != null) {
          // Update favorites entry
          print('DEBUG: Updating favorites entry: $_editingFavoriteId');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .doc(_editingFavoriteId)
              .update({
            'recipe.title': _foodNameController.text.trim(),
            'recipe.ingredients': ingredientsList,
            'recipe.instructions': instructionsText,
            'recipe.nutrition': nutritionData, // Direct nutrition, no scaling
            'recipe.image': _selectedImage?.path,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // CREATE NEW RECIPE
        print('DEBUG: Creating new meal');
        await NutritionService.saveMealWithNutrition(
          title: _foodNameController.text.trim(),
          date: dateString,
          mealType: _selectedMealType.toLowerCase(),
          ingredients: ingredientsList,
          instructions: instructionsText,
          customNutrition: nutritionData,
          image: _selectedImage?.path,
        );

        // Also save to favorites
        final customRecipe = <String, dynamic>{
          'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
          'title': _foodNameController.text.trim(),
          'image': _selectedImage?.path,
          'source': 'manual_entry',
          'cuisine': 'Custom',
          'ingredients': List<String>.from(ingredientsList),
          'instructions': instructionsText,
          'nutrition': Map<String, double>.from(nutritionData),
          'servings': servingSize,
          'readyInMinutes': int.tryParse(_cookingTimeController.text.trim()) ?? 30,
          'cookingTime': int.tryParse(_cookingTimeController.text.trim()) ?? 30,
          'mealType': _selectedMealType.toLowerCase(),
        };

        await FavoriteService.addToFavorites(
          context,
          customRecipe,
          notes: 'Custom recipe created on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
        );
      }

      if (mounted) {
        // Show motivational progress notification
        await NutritionProgressNotifier.showProgressNotification(
          context,
          nutritionData,
          mealDate: _selectedDate,
        );
        
        // Small delay to let user see the notification
        await Future.delayed(const Duration(milliseconds: 500));
        
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

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Manual Entry'),
            Text(
              _smartEntryMode ? 'Smart Mode' : 'Manual Mode',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
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
              // Smart Entry Mode Toggle
              Card(
                elevation: 8,
                shadowColor: Colors.blue.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        _smartEntryMode ? Colors.blue[50]! : Colors.orange[50]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _smartEntryMode ? Colors.blue[200]! : Colors.orange[200]!,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(
                          _smartEntryMode ? Icons.auto_awesome : Icons.edit,
                          color: _smartEntryMode ? Colors.blue[700] : Colors.orange[700],
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _smartEntryMode ? 'Smart Entry Mode' : 'Manual Entry Mode',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _smartEntryMode ? Colors.blue[800] : Colors.orange[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _smartEntryMode
                                    ? 'Add ingredients → Auto-calculate nutrition'
                                    : 'Enter nutrition values manually',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _smartEntryMode,
                          onChanged: (value) {
                            setState(() => _smartEntryMode = value);
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
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
                          controller: _cookingTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Ready in Minutes',
                            hintText: '30',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer),
                            suffixText: 'min',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final parsed = int.tryParse(value);
                              if (parsed == null || parsed <= 0) {
                                return 'Please enter a valid cooking time';
                              }
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

              // Image Upload Section
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
                          'Meal Photo (Optional)',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedImage == null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _takePicture,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Take Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickImageFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Choose from Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[300]!, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _takePicture,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Retake Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickImageFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Change Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _removeImage,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Remove Photo',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
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

              // Nutrition Information - Conditional based on mode
              Card(
                elevation: 8,
                shadowColor: (_smartEntryMode ? Colors.blue : Colors.orange).withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        _smartEntryMode ? Colors.blue[50]! : Colors.orange[50]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _smartEntryMode ? Colors.blue[200]! : Colors.orange[200]!,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _smartEntryMode ? _buildSmartModeUI() : _buildManualModeUI(),
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

/// Dialog for searching and selecting ingredients from the database
class _SearchIngredientDialog extends StatefulWidget {
  final List<String> availableIngredients;

  const _SearchIngredientDialog({
    required this.availableIngredients,
  });

  @override
  State<_SearchIngredientDialog> createState() => _SearchIngredientDialogState();
}

class _SearchIngredientDialogState extends State<_SearchIngredientDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredIngredients = [];

  @override
  void initState() {
    super.initState();
    _filteredIngredients = widget.availableIngredients;
  }

  void _filterIngredients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredIngredients = widget.availableIngredients;
      } else {
        final queryLower = query.toLowerCase();
        _filteredIngredients = widget.availableIngredients
            .where((ing) => ing.toLowerCase().contains(queryLower))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Replacement Ingredient'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search ingredients in database',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterIngredients,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _filteredIngredients.isEmpty
                  ? const Center(
                      child: Text('No ingredients found'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredIngredients.length > 50 
                          ? 50 
                          : _filteredIngredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _filteredIngredients[index];
                        return ListTile(
                          title: Text(ingredient),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () {
                            Navigator.pop(context, ingredient);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
