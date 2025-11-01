import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/nutrition_service.dart';
import '../services/allergen_detection_service.dart';
import '../services/allergen_service.dart';

class EditMealDialog extends StatefulWidget {
  final Map<String, dynamic> meal;
  final String mealId;
  final String dateKey;

  const EditMealDialog({
    super.key,
    required this.meal,
    required this.mealId,
    required this.dateKey,
  });

  @override
  State<EditMealDialog> createState() => _EditMealDialogState();
}

class _EditMealDialogState extends State<EditMealDialog> {
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _editedIngredients = [];
  List<String> _ingredientSearchResults = [];
  List<String> _availableIngredients = [];
  Map<String, dynamic> _availableIngredientsWithNutrition = {};
  bool _isCalculating = false;
  Map<String, double> _calculatedNutrition = {};
  List<String> _instructionSteps = []; // Individual instruction steps
  
  @override
  void initState() {
    super.initState();
    final instructionsText = widget.meal['instructions']?.toString() ?? '';
    _instructionsController.text = instructionsText;
    
    // Parse instructions into steps (split by newline or numbered steps)
    _instructionSteps = _parseInstructionsIntoSteps(instructionsText);
    
    // Extract ingredients as full objects from both 'ingredients' and 'extendedIngredients' arrays
    _editedIngredients = _extractIngredientsFromMeal(widget.meal);
    
    _loadAvailableIngredients();
    
    // Initial nutrition calculation
    _recalculateNutrition();
  }
  
  /// Parse instructions text into individual steps
  List<String> _parseInstructionsIntoSteps(String instructions) {
    if (instructions.isEmpty) return [];
    
    // Try to split by numbered steps first (e.g., "1. ", "2. ", etc.)
    final numberedPattern = RegExp(r'\d+[\.)]\s+');
    if (numberedPattern.hasMatch(instructions)) {
      final steps = <String>[];
      final matches = numberedPattern.allMatches(instructions);
      
      for (int i = 0; i < matches.length; i++) {
        final match = matches.elementAt(i);
        final start = match.end;
        final end = (i < matches.length - 1) 
            ? matches.elementAt(i + 1).start 
            : instructions.length;
        
        final stepText = instructions.substring(start, end).trim();
        if (stepText.isNotEmpty) {
          steps.add(stepText);
        }
      }
      
      if (steps.isNotEmpty) return steps;
    }
    
    // Otherwise split by newlines
    final lines = instructions
        .split('\n')
        .where((step) => step.trim().isNotEmpty)
        .map((step) => step.trim())
        .toList();
    
    // If only one or two lines, try to split by sentences (for combined steps)
    if (lines.length <= 2) {
      final sentences = <String>[];
      for (final line in lines) {
        // Split by ". " followed by capital letter (new sentence indicator)
        final parts = line.split(RegExp(r'\.\s+(?=[A-Z])'));
        for (final part in parts) {
          final cleaned = part.trim();
          if (cleaned.isNotEmpty) {
            // Add period back if it was removed
            sentences.add(cleaned.endsWith('.') ? cleaned : '$cleaned.');
          }
        }
      }
      if (sentences.length > lines.length) {
        return sentences;
      }
    }
    
    return lines;
  }
  
  /// Add a new instruction step
  void _addInstructionStep() {
    setState(() {
      _instructionSteps.add('');
    });
  }
  
  /// Remove an instruction step
  void _removeInstructionStep(int index) {
    setState(() {
      _instructionSteps.removeAt(index);
    });
  }
  
  /// Edit an instruction step
  void _editInstructionStep(int index, String newText) {
    setState(() {
      _instructionSteps[index] = newText;
    });
  }
  
  List<Map<String, dynamic>> _extractIngredientsFromMeal(Map<String, dynamic> meal) {
    final List<Map<String, dynamic>> allIngredients = [];
    
    // Extract from regular ingredients array
    if (meal['ingredients'] != null && meal['ingredients'] is List) {
      for (final ing in meal['ingredients'] as List) {
        if (ing is String && ing.isNotEmpty) {
          // Try to parse amount and unit from the string
          final parsed = _parseIngredientString(ing);
          allIngredients.add(parsed);
        } else if (ing is Map<String, dynamic>) {
          // Check if 'original' field exists with full text (e.g., "2 tbsp olive oil")
          print('DEBUG: Ingredient map data: ${ing.toString()}');
          final originalText = ing['original']?.toString() ?? '';
          
          if (originalText.isNotEmpty) {
            // Always re-parse the original text to ensure correct extraction
            print('DEBUG: Re-parsing original ingredient text: "$originalText"');
            final parsed = _parseIngredientString(originalText);
            allIngredients.add(parsed);
          } else {
            // No original text, use existing data but ensure nameClean is populated
            print('DEBUG: No original field, using existing data - name: "${ing['name']}", amount: ${ing['amount']}, unit: ${ing['unit']}');
            final ingredientName = ing['name']?.toString() ?? '';
            final nameClean = ing['nameClean']?.toString() ?? _findDatabaseMatch(ingredientName);
            allIngredients.add({
              ...ing,
              'name': ingredientName, // Keep original name for display
              'nameClean': nameClean, // Database-matched name for nutrition
            });
          }
        }
      }
    }
    
    // Extract from extendedIngredients (Spoonacular format)
    if (meal['extendedIngredients'] != null && meal['extendedIngredients'] is List) {
      for (final ing in meal['extendedIngredients'] as List) {
        if (ing is Map<String, dynamic>) {
          final ingredientName = ing['name'] ?? ing['originalName'] ?? ing['original'] ?? 'Unknown';
          final nameClean = _findDatabaseMatch(ingredientName.toString());
          allIngredients.add({
            'name': ingredientName,
            'nameClean': nameClean,
            'amount': ing['amount'] ?? 1.0,
            'unit': ing['unit'] ?? '',
            'original': ing['original'] ?? ing['originalName'] ?? ing['name'] ?? 'Unknown',
          });
        } else if (ing is String && ing.isNotEmpty) {
          // Try to parse amount and unit from the string
          final parsed = _parseIngredientString(ing);
          allIngredients.add(parsed);
        }
      }
    }
    
    return allIngredients;
  }

  /// Parse ingredient string to extract amount, unit, and name
  /// Format: "2 tbsp olive oil" → amount: 2, unit: tbsp, name: olive oil
  Map<String, dynamic> _parseIngredientString(String ingredientString) {
    final original = ingredientString.trim();
    print('DEBUG: Parsing: "$original"');
    
    // Convert fractions
    String text = original
        .replaceAll('¼', '1/4').replaceAll('½', '1/2').replaceAll('¾', '3/4')
        .replaceAll('⅓', '1/3').replaceAll('⅔', '2/3')
        .replaceAll('⅛', '1/8').replaceAll('⅜', '3/8').replaceAll('⅝', '5/8').replaceAll('⅞', '7/8');
    
    // Valid units
    final units = ['g', 'kg', 'mg', 'ml', 'l', 'oz', 'lb', 
                   'cup', 'cups', 'tbsp', 'tsp', 'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
                   'piece', 'pieces', 'slice', 'slices', 'clove', 'cloves',
                   'can', 'cans', 'jar', 'jars', 'bottle', 'bottles', 'package', 'packages'];
    
    double amount = 1.0;
    String amountDisplay = '1';
    String unit = 'piece'; // Default unit
    String name = text;
    
    // Pattern: NUMBER UNIT NAME (e.g., "2 tbsp olive oil", "200 g Spinach")
    final pattern = RegExp(r'^(\d+(?:\.\d+)?(?:/\d+)?)\s*([a-zA-Z]+)?\s*(.*)$');
    final match = pattern.firstMatch(text);
    
    if (match != null) {
      // Extract amount
      final amountStr = match.group(1) ?? '1';
      if (amountStr.contains('/')) {
        final parts = amountStr.split('/');
        amount = (double.tryParse(parts[0]) ?? 1.0) / (double.tryParse(parts[1]) ?? 1.0);
        amountDisplay = amountStr;
      } else {
        amount = double.tryParse(amountStr) ?? 1.0;
        amountDisplay = amountStr;
      }
      
      // Extract unit and name
      final potentialUnit = match.group(2)?.toLowerCase() ?? '';
      final remainingText = match.group(3)?.trim() ?? '';
      
      if (units.contains(potentialUnit)) {
        // Found a valid unit
        unit = potentialUnit;
        name = remainingText.isNotEmpty ? remainingText : text;
      } else {
        // No unit found, everything after number is the name
        unit = 'piece';
        name = potentialUnit.isNotEmpty ? '$potentialUnit $remainingText' : remainingText;
      }
    }
    
    // Clean up name
    name = name.trim();
    if (name.isEmpty) {
      name = text;
    }
    
    // Find database match for nutrition
    final cleanedName = _findDatabaseMatch(name);
    
    print('DEBUG: Result → amount: $amountDisplay ($amount), unit: $unit, name: $name, clean: $cleanedName');
    
    return {
      'name': name,
      'nameClean': cleanedName,
      'amount': amount,
      'amountDisplay': amountDisplay,
      'unit': unit,
      'original': original,
    };
  }
  
  /// Parse amount string and return both numeric value and display format
  Map<String, dynamic> _parseAmount(String amountStr) {
    if (amountStr.contains('/')) {
      final parts = amountStr.split('/');
      final numerator = double.tryParse(parts[0]) ?? 1.0;
      final denominator = double.tryParse(parts[1]) ?? 1.0;
      return {
        'amount': numerator / denominator,
        'display': amountStr, // Keep as fraction for display
      };
    } else {
      final amount = double.tryParse(amountStr) ?? 1.0;
      return {
        'amount': amount,
        'display': amountStr,
      };
    }
  }
  
  /// Infer a reasonable default unit based on ingredient name
  String _inferDefaultUnit(String ingredientName) {
    final lower = ingredientName.toLowerCase();
    
    // Liquids - use ml or tbsp
    if (lower.contains('oil') || lower.contains('sauce') || lower.contains('water') || 
        lower.contains('milk') || lower.contains('juice') || lower.contains('vinegar')) {
      return 'tbsp';
    }
    
    // Spices and powders - use tsp
    if (lower.contains('powder') || lower.contains('spice') || lower.contains('salt') ||
        lower.contains('pepper') || lower.contains('cumin') || lower.contains('coriander') ||
        lower.contains('turmeric') || lower.contains('paprika') || lower.contains('cinnamon')) {
      return 'tsp';
    }
    
    // Vegetables and fruits - use piece
    if (lower.contains('onion') || lower.contains('tomato') || lower.contains('potato') ||
        lower.contains('carrot') || lower.contains('apple') || lower.contains('banana')) {
      return 'piece';
    }
    
    // Garlic - use cloves
    if (lower.contains('garlic')) {
      return 'clove';
    }
    
    // Default to piece for solid items
    return 'piece';
  }

  /// Find database match for ingredient name by trying each word
  String _findDatabaseMatch(String name) {
    final lowerName = name.toLowerCase().trim();
    
    // Skip matching if ingredients haven't loaded yet
    if (_availableIngredients.isEmpty) {
      print('DEBUG: Ingredients not loaded yet, returning original: "$lowerName"');
      return lowerName;
    }
    
    print('DEBUG: Finding database match for: "$lowerName"');
    
    // 1. Try exact match first (e.g., "chicken" matches "chicken")
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower == lowerName) {
        print('DEBUG: Found exact match: "$lowerName" -> "$ing"');
        return ing;
      }
    }
    
    // 2. Split ingredient name into words and try each word
    // "To taste Salt" -> ["to", "taste", "salt"]
    // "chopped Garlic" -> ["chopped", "garlic"]
    // "thinly sliced onion" -> ["thinly", "sliced", "onion"]
    final words = lowerName.split(RegExp(r'\s+'));
    
    // Try to find database ingredient that contains any of these words
    // Prioritize longer words (more specific)
    final sortedWords = words.where((w) => w.length > 2).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final word in sortedWords) {
      // Try exact match on this word
      for (final ing in _availableIngredients) {
        final ingLower = ing.toLowerCase();
        if (ingLower == word) {
          print('DEBUG: Found exact word match: "$word" from "$lowerName" -> "$ing"');
          return ing;
        }
      }
      
      // Try if database ingredient contains this word
      for (final ing in _availableIngredients) {
        final ingLower = ing.toLowerCase();
        if (ingLower.contains(word) || word.contains(ingLower)) {
          print('DEBUG: Found word match: "$word" from "$lowerName" -> "$ing"');
          return ing;
        }
      }
    }
    
    // 3. Try removing trailing 's' for plural matching
    // "potatoes" -> "potato", "tomatoes" -> "tomato"
    for (final word in sortedWords) {
      final singular = word.replaceAll(RegExp(r's$'), '');
      if (singular != word) {
        for (final ing in _availableIngredients) {
          final ingLower = ing.toLowerCase();
          if (ingLower == singular || ingLower.contains(singular)) {
            print('DEBUG: Found plural match: "$word" (singular: "$singular") from "$lowerName" -> "$ing"');
            return ing;
          }
        }
      }
    }
    
    // 4. Fallback: return original name if no match found
    print('DEBUG: No database match found for "$lowerName", keeping original');
    return lowerName;
  }

  Future<void> _loadAvailableIngredients() async {
    try {
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
            _availableIngredientsWithNutrition = Map<String, dynamic>.from(ingredients);
          });
          print('DEBUG: Loaded ${ingredients.length} ingredients from Firestore');
          return;
        }
      }
    } catch (e) {
      print('Error loading ingredients from Firestore: $e');
    }
    
    // Fallback to hardcoded nutrition database if Firestore is empty or fails
    print('DEBUG: Falling back to hardcoded nutrition database');
    final hardcodedDb = NutritionService.getIngredientDatabase();
    setState(() {
      _availableIngredients = hardcodedDb.keys.toList();
      _availableIngredientsWithNutrition = Map<String, dynamic>.from(hardcodedDb);
    });
    print('DEBUG: Loaded ${hardcodedDb.length} ingredients from hardcoded database');
  }

  void _searchIngredients(String query) {
    if (query.isEmpty) {
      setState(() {
        _ingredientSearchResults = [];
      });
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
    // Check if ingredient already exists
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
          title: Text('Set Amount & Unit for $ingredientName'),
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
                  DropdownMenuItem(value: 'mg', child: Text('mg (milligram)')),
                  DropdownMenuItem(value: 'ml', child: Text('ml (milliliter)')),
                  DropdownMenuItem(value: 'l', child: Text('l (liter)')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp (tablespoon)')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp (teaspoon)')),
                  DropdownMenuItem(value: 'piece', child: Text('piece')),
                  DropdownMenuItem(value: 'slice', child: Text('slice')),
                  DropdownMenuItem(value: 'clove', child: Text('clove')),
                  DropdownMenuItem(value: 'oz', child: Text('oz (ounce)')),
                  DropdownMenuItem(value: 'lb', child: Text('lb (pound)')),
                  DropdownMenuItem(value: 'can', child: Text('can')),
                  DropdownMenuItem(value: 'jar', child: Text('jar')),
                  DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                  DropdownMenuItem(value: 'package', child: Text('package')),
                  DropdownMenuItem(value: 'packet', child: Text('packet')),
                  DropdownMenuItem(value: 'bag', child: Text('bag')),
                  DropdownMenuItem(value: 'box', child: Text('box')),
                  DropdownMenuItem(value: 'head', child: Text('head')),
                  DropdownMenuItem(value: 'bunch', child: Text('bunch')),
                  DropdownMenuItem(value: 'floret', child: Text('floret')),
                  DropdownMenuItem(value: 'stalk', child: Text('stalk')),
                  DropdownMenuItem(value: 'sprig', child: Text('sprig')),
                  DropdownMenuItem(value: 'leaf', child: Text('leaf')),
                  DropdownMenuItem(value: 'stick', child: Text('stick')),
                  DropdownMenuItem(value: 'drop', child: Text('drop')),
                  DropdownMenuItem(value: 'pinch', child: Text('pinch')),
                  DropdownMenuItem(value: 'dash', child: Text('dash')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedUnit = value ?? 'piece';
                  });
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
    
    if (result == null) return;
    
    // Parse amount
    double amount = 1.0;
    String amountDisplay = result['amount'] ?? '1';
    
    if (amountDisplay.contains('/')) {
      final parts = amountDisplay.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0]) ?? 1.0;
        final denominator = double.tryParse(parts[1]) ?? 1.0;
        amount = numerator / denominator;
      }
    } else {
      amount = double.tryParse(amountDisplay) ?? 1.0;
    }

    // Create ingredient object with user-specified amount and unit
    final newIngredient = {
      'name': ingredientName,
      'nameClean': ingredientName, // Same as name since it's from database
      'amount': amount,
      'amountDisplay': amountDisplay,
      'unit': result['unit'] ?? 'piece',
      'original': '$amountDisplay ${result['unit']} $ingredientName',
    };

    setState(() {
      _editedIngredients.add(newIngredient);
      _searchController.clear();
      _ingredientSearchResults.clear();
    });

    _recalculateNutrition();
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

  void _removeIngredient(int index) {
    setState(() {
      _editedIngredients.removeAt(index);
    });
    _recalculateNutrition();
  }

  /// Replace ingredient with a database match and prompt for amount/unit
  Future<void> _replaceIngredient(int index) async {
    final currentIngredient = _editedIngredients[index];
    final currentName = currentIngredient['name']?.toString() ?? '';
    
    // Show searchable dialog to pick replacement from database
    final selectedIngredient = await showDialog<String>(
      context: context,
      builder: (context) => _ReplacementPickerDialog(
        availableIngredients: _availableIngredients,
        currentName: currentName,
      ),
    );
    
    if (selectedIngredient == null) return;
    
    // Prompt for amount and unit
    await _promptAmountUnitForReplacement(index, selectedIngredient);
  }

  /// Prompt user to enter amount and unit for replaced ingredient
  Future<void> _promptAmountUnitForReplacement(int index, String newIngredientName) async {
    final currentIngredient = _editedIngredients[index];
    final amountController = TextEditingController(
      text: currentIngredient['amountDisplay']?.toString() ?? currentIngredient['amount']?.toString() ?? '1'
    );
    final rawUnit = currentIngredient['unit']?.toString() ?? '';
    String selectedUnit = _normalizeUnit(rawUnit);
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Amount & Unit for $newIngredientName'),
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
                  DropdownMenuItem(value: 'mg', child: Text('mg (milligram)')),
                  DropdownMenuItem(value: 'ml', child: Text('ml (milliliter)')),
                  DropdownMenuItem(value: 'l', child: Text('l (liter)')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp (tablespoon)')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp (teaspoon)')),
                  DropdownMenuItem(value: 'piece', child: Text('piece')),
                  DropdownMenuItem(value: 'slice', child: Text('slice')),
                  DropdownMenuItem(value: 'clove', child: Text('clove')),
                  DropdownMenuItem(value: 'oz', child: Text('oz (ounce)')),
                  DropdownMenuItem(value: 'lb', child: Text('lb (pound)')),
                  DropdownMenuItem(value: 'can', child: Text('can')),
                  DropdownMenuItem(value: 'jar', child: Text('jar')),
                  DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                  DropdownMenuItem(value: 'package', child: Text('package')),
                  DropdownMenuItem(value: 'packet', child: Text('packet')),
                  DropdownMenuItem(value: 'bag', child: Text('bag')),
                  DropdownMenuItem(value: 'box', child: Text('box')),
                  DropdownMenuItem(value: 'head', child: Text('head')),
                  DropdownMenuItem(value: 'bunch', child: Text('bunch')),
                  DropdownMenuItem(value: 'floret', child: Text('floret')),
                  DropdownMenuItem(value: 'stalk', child: Text('stalk')),
                  DropdownMenuItem(value: 'sprig', child: Text('sprig')),
                  DropdownMenuItem(value: 'leaf', child: Text('leaf')),
                  DropdownMenuItem(value: 'stick', child: Text('stick')),
                  DropdownMenuItem(value: 'drop', child: Text('drop')),
                  DropdownMenuItem(value: 'pinch', child: Text('pinch')),
                  DropdownMenuItem(value: 'dash', child: Text('dash')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedUnit = value ?? 'piece';
                  });
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
    
    if (result == null) return;
    
    // Parse amount
    double amount = 1.0;
    String amountDisplay = result['amount'] ?? '1';
    
    if (amountDisplay.contains('/')) {
      final parts = amountDisplay.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0]) ?? 1.0;
        final denominator = double.tryParse(parts[1]) ?? 1.0;
        amount = numerator / denominator;
      }
    } else {
      amount = double.tryParse(amountDisplay) ?? 1.0;
    }
    
    // Replace the ingredient
    setState(() {
      _editedIngredients[index] = {
        'name': newIngredientName,
        'nameClean': newIngredientName, // Same as name since it's from database
        'amount': amount,
        'amountDisplay': amountDisplay,
        'unit': result['unit'] ?? 'piece',
        'original': '$amountDisplay ${result['unit']} $newIngredientName',
      };
    });
    
    _recalculateNutrition();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Replaced with $newIngredientName')),
    );
  }

  /// Normalize unit names to dropdown values
  String _normalizeUnit(String unit) {
    // Handle empty, null, or invalid units
    if (unit.isEmpty || unit == '.' || unit == ' ') {
      return 'piece';
    }
    
    final lowerUnit = unit.toLowerCase().trim();
    
    // Map common variations to dropdown values
    final unitMap = {
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tbsp': 'tbsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'tsp': 'tsp',
      'cup': 'cup',
      'cups': 'cup',
      'piece': 'piece',
      'pieces': 'piece',
      'lb': 'lb',
      'pound': 'lb',
      'pounds': 'lb',
      'kg': 'kg',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'g': 'g',
      'gram': 'g',
      'grams': 'g',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'ml': 'ml',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'l': 'l',
      'liter': 'l',
      'liters': 'l',
      'clove': 'clove',
      'cloves': 'clove',
      'head': 'head',
      'heads': 'head',
      'can': 'can',
      'cans': 'can',
      'jar': 'jar',
      'jars': 'jar',
      'bottle': 'bottle',
      'bottles': 'bottle',
      'package': 'package',
      'packages': 'package',
      'bag': 'bag',
      'bags': 'bag',
      'box': 'box',
      'boxes': 'box',
      'slice': 'slice',
      'slices': 'slice',
      'packet': 'packet',
      'packets': 'packet',
      'bunch': 'bunch',
      'bunches': 'bunch',
      'floret': 'floret',
      'florets': 'floret',
      'stalk': 'stalk',
      'stalks': 'stalk',
      'sprig': 'sprig',
      'sprigs': 'sprig',
      'leaf': 'leaf',
      'leaves': 'leaf',
      'stick': 'stick',
      'sticks': 'stick',
      'drop': 'drop',
      'drops': 'drop',
      'pinch': 'pinch',
      'pinches': 'pinch',
      'dash': 'dash',
      'dashes': 'dash',
      'mg': 'mg',
      'milligram': 'mg',
      'milligrams': 'mg',
    };
    
    return unitMap[lowerUnit] ?? 'piece'; // default to 'piece' if not found
  }

  Future<void> _editIngredientAmountUnit(int index) async {
    final ingredient = _editedIngredients[index];
    final rawUnit = ingredient['unit']?.toString() ?? '';
    final normalizedUnit = _normalizeUnit(rawUnit);
    
    print('DEBUG: Editing ingredient - unit: "$rawUnit" -> normalized: "$normalizedUnit"');
    
    final amountController = TextEditingController(text: ingredient['amountDisplay']?.toString() ?? ingredient['amount']?.toString() ?? '1');
    String selectedUnit = normalizedUnit;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Amount & Unit'),
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
                  DropdownMenuItem(value: 'mg', child: Text('mg (milligram)')),
                  DropdownMenuItem(value: 'ml', child: Text('ml (milliliter)')),
                  DropdownMenuItem(value: 'l', child: Text('l (liter)')),
                  DropdownMenuItem(value: 'cup', child: Text('cup')),
                  DropdownMenuItem(value: 'tbsp', child: Text('tbsp (tablespoon)')),
                  DropdownMenuItem(value: 'tsp', child: Text('tsp (teaspoon)')),
                  DropdownMenuItem(value: 'piece', child: Text('piece')),
                  DropdownMenuItem(value: 'slice', child: Text('slice')),
                  DropdownMenuItem(value: 'clove', child: Text('clove')),
                  DropdownMenuItem(value: 'oz', child: Text('oz (ounce)')),
                  DropdownMenuItem(value: 'lb', child: Text('lb (pound)')),
                  DropdownMenuItem(value: 'can', child: Text('can')),
                  DropdownMenuItem(value: 'jar', child: Text('jar')),
                  DropdownMenuItem(value: 'bottle', child: Text('bottle')),
                  DropdownMenuItem(value: 'package', child: Text('package')),
                  DropdownMenuItem(value: 'packet', child: Text('packet')),
                  DropdownMenuItem(value: 'bag', child: Text('bag')),
                  DropdownMenuItem(value: 'box', child: Text('box')),
                  DropdownMenuItem(value: 'head', child: Text('head')),
                  DropdownMenuItem(value: 'bunch', child: Text('bunch')),
                  DropdownMenuItem(value: 'floret', child: Text('floret')),
                  DropdownMenuItem(value: 'stalk', child: Text('stalk')),
                  DropdownMenuItem(value: 'sprig', child: Text('sprig')),
                  DropdownMenuItem(value: 'leaf', child: Text('leaf')),
                  DropdownMenuItem(value: 'stick', child: Text('stick')),
                  DropdownMenuItem(value: 'drop', child: Text('drop')),
                  DropdownMenuItem(value: 'pinch', child: Text('pinch')),
                  DropdownMenuItem(value: 'dash', child: Text('dash')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedUnit = value ?? 'piece';
                  });
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
                final amountText = amountController.text;
                double amount = 1.0;
                String amountDisplay = amountText;
                
                // Parse fraction or decimal
                if (amountText.contains('/')) {
                  final parts = amountText.split('/');
                  final numerator = double.tryParse(parts[0]) ?? 1.0;
                  final denominator = double.tryParse(parts[1]) ?? 1.0;
                  amount = numerator / denominator;
                  amountDisplay = amountText; // Keep as fraction
                } else {
                  amount = double.tryParse(amountText) ?? 1.0;
                  amountDisplay = amountText;
                }
                
                setState(() {
                  _editedIngredients[index] = {
                    ...ingredient,
                    'amount': amount,
                    'amountDisplay': amountDisplay,
                    'unit': selectedUnit,
                  };
                });
                Navigator.pop(context);
                _recalculateNutrition();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recalculateNutrition() async {
    setState(() {
      _isCalculating = true;
    });

    try {
      // Use ingredient objects with amounts and units for accurate calculation
      final nutrition = await NutritionService.calculateRecipeNutritionFromObjects(
        _editedIngredients,
      );

      setState(() {
        _calculatedNutrition = nutrition;
        _isCalculating = false;
      });
    } catch (e) {
      print('Error recalculating nutrition: $e');
      setState(() {
        _isCalculating = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    // Determine if this is a favorite meal or meal plan meal
    final isFavorite = widget.dateKey.isEmpty;
    final collection = isFavorite ? 'favorites' : 'meal_plans';
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current meal data
      final mealDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .doc(widget.mealId)
          .get();

      if (!mealDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isFavorite ? "Recipe" : "Meal"} not found')),
        );
        return;
      }

      // Check for allergens in new ingredients
      final ingredientNames = _editedIngredients
          .map((ing) => ing['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      
      final detectedAllergens = AllergenService.checkAllergens(ingredientNames);
      final userAllergens = await AllergenDetectionService.getUserAllergens();
      
      bool hasAllergenConflict = false;
      if (userAllergens.isNotEmpty && detectedAllergens.isNotEmpty) {
        hasAllergenConflict = detectedAllergens.entries.any((entry) {
          final allergenType = entry.key;
          return userAllergens.any((userAllergen) =>
              userAllergen.toLowerCase() == allergenType.toLowerCase());
        });
      }

      // Combine instruction steps into formatted text
      final instructionsText = _instructionSteps
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');
      
      // Prepare updated data
      final recipeUpdates = {
        'instructions': instructionsText.trim(),
        'ingredients': _editedIngredients,
        'nutrition': _calculatedNutrition.isNotEmpty 
            ? _calculatedNutrition 
            : widget.meal['nutrition'],
        'hasAllergens': hasAllergenConflict,
        'detectedAllergens': hasAllergenConflict 
            ? detectedAllergens.entries.map((e) => e.key).toList()
            : [],
        // Clear extendedIngredients to ensure UI uses the edited 'ingredients'
        'extendedIngredients': null,
        
        // Preserve substitution metadata to prevent nutrition recalculation
        if (widget.meal['substituted'] == true) 'substituted': true,
        if (widget.meal['originalNutrition'] != null) 
            'originalNutrition': widget.meal['originalNutrition'],
        if (widget.meal['substitutions'] != null) 
            'substitutions': widget.meal['substitutions'],
        if (widget.meal['originalAllergens'] != null) 
            'originalAllergens': widget.meal['originalAllergens'],
      };

      // Update meal in Firestore
      // For favorites, update nested 'recipe' field; for meal plans, update root level
      if (isFavorite) {
        // Favorites have structure: { recipe: {...}, notes: ..., rating: ... }
        // Need to update fields inside 'recipe' using dot notation
        final Map<String, dynamic> updatedData = {};
        recipeUpdates.forEach((key, value) {
          updatedData['recipe.$key'] = value;
        });
        updatedData['updatedAt'] = FieldValue.serverTimestamp();
        await mealDoc.reference.update(updatedData);
      } else {
        // Meal plans have flat structure, update directly
        recipeUpdates['updatedAt'] = FieldValue.serverTimestamp();
        await mealDoc.reference.update(recipeUpdates);
      }

      // Update local state
      setState(() {
        widget.meal['instructions'] = instructionsText.trim();
        widget.meal['ingredients'] = _editedIngredients;
        widget.meal['extendedIngredients'] = null; // force UI to use 'ingredients'
        widget.meal['nutrition'] = _calculatedNutrition.isNotEmpty 
            ? _calculatedNutrition 
            : widget.meal['nutrition'];
        widget.meal['hasAllergens'] = hasAllergenConflict;
        widget.meal['detectedAllergens'] = hasAllergenConflict 
            ? detectedAllergens.entries.map((e) => e.key).toList()
            : [];
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFavorite ? "Recipe" : "Meal"} updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving ${isFavorite ? "recipe" : "meal"} changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ${isFavorite ? "recipe" : "meal"}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit Meal: ${widget.meal['title']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Add Ingredient Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Ingredient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for ingredients...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _ingredientSearchResults.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: _searchIngredients,
                    ),
                    if (_ingredientSearchResults.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Ingredients List
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredients (${_editedIngredients.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Info note about replacing ingredients
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'If nutrition values aren\'t showing, use the Replace button to match with ingredients in our database for better calculation.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _editedIngredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _editedIngredients[index];
                    final ingredientName = ingredient['name']?.toString() ?? 'Unknown Ingredient'; // Display name
                    final ingredientNameClean = ingredient['nameClean']?.toString() ?? ingredientName; // For nutrition lookup
                    
                    // Case-insensitive lookup for nutrition data using cleaned name
                    Map<String, dynamic>? nutrition;
                    for (final entry in _availableIngredientsWithNutrition.entries) {
                      if (entry.key.toLowerCase() == ingredientNameClean.toLowerCase()) {
                        final nutritionData = entry.value;
                        nutrition = nutritionData is Map ? Map<String, dynamic>.from(nutritionData) : null;
                        break;
                      }
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ingredient info row
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Text('${index + 1}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ingredientName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${ingredient['amountDisplay'] ?? ingredient['amount'] ?? 1} ${ingredient['unit'] ?? ''}'.trim(),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Replace button (always show for re-substitution)
                                    IconButton(
                                      icon: const Icon(Icons.swap_horiz, size: 18),
                                      onPressed: () => _replaceIngredient(index),
                                      tooltip: 'Replace',
                                      color: Colors.orange,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _editIngredientAmountUnit(index),
                                      tooltip: 'Edit',
                                      color: Colors.blue,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => _removeIngredient(index),
                                      tooltip: 'Remove',
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Nutrition info (scaled by amount)
                            if (nutrition != null) ...[
                              const Divider(height: 20),
                              FutureBuilder<Map<String, double>>(
                                future: _calculateIndividualIngredientNutrition(ingredient, nutrition),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final scaledNutrition = snapshot.data!;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMiniNutritionItem('Cal', '${scaledNutrition['calories']?.toStringAsFixed(0) ?? '0'}'),
                                      _buildMiniNutritionItem('P', '${scaledNutrition['protein']?.toStringAsFixed(1) ?? '0'}g'),
                                      _buildMiniNutritionItem('C', '${scaledNutrition['carbs']?.toStringAsFixed(1) ?? '0'}g'),
                                      _buildMiniNutritionItem('F', '${scaledNutrition['fat']?.toStringAsFixed(1) ?? '0'}g'),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Calculated Nutrition Display
            if (_calculatedNutrition.isNotEmpty)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Calculated Nutrition',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutritionItem('Calories', _calculatedNutrition['calories']?.toStringAsFixed(0) ?? '0', 'cal'),
                          _buildNutritionItem('Protein', _calculatedNutrition['protein']?.toStringAsFixed(1) ?? '0', 'g'),
                          _buildNutritionItem('Carbs', _calculatedNutrition['carbs']?.toStringAsFixed(1) ?? '0', 'g'),
                          _buildNutritionItem('Fat', _calculatedNutrition['fat']?.toStringAsFixed(1) ?? '0', 'g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Instructions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Instructions (${_instructionSteps.length} steps)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addInstructionStep,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Step'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Instruction steps
            if (_instructionSteps.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No instructions yet. Click "Add Step" to start.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _instructionSteps.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _instructionSteps.removeAt(oldIndex);
                    _instructionSteps.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Card(
                    key: ValueKey('step_$index\_${_instructionSteps[index]}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Icon(
                            Icons.drag_handle,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          // Step number
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Step text
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _instructionSteps[index])
                                ..selection = TextSelection.collapsed(offset: _instructionSteps[index].length),
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: 'Enter step instructions...',
                                border: InputBorder.none,
                              ),
                              onChanged: (value) => _editInstructionStep(index, value),
                            ),
                          ),
                          // Delete button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.red,
                            onPressed: () => _removeInstructionStep(index),
                            tooltip: 'Remove step',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 16),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCalculating ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCalculating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          '$label ($unit)',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<Map<String, double>> _calculateIndividualIngredientNutrition(
    Map<String, dynamic> ingredient,
    Map<String, dynamic> baseNutrition,
  ) async {
    // Handle both int and double amounts
    final amount = (ingredient['amount'] is int) 
        ? (ingredient['amount'] as int).toDouble()
        : (ingredient['amount'] ?? 1.0) as double;
    final unit = ingredient['unit']?.toString() ?? '';
    
    // Convert to grams
    final grams = NutritionService.convertToGrams(amount, unit);
    
    // Scale based on amount (nutrition is per 100g)
    final factor = grams / 100.0;
    
    return {
      'calories': (baseNutrition['calories'] ?? 0) * factor,
      'protein': (baseNutrition['protein'] ?? 0) * factor,
      'carbs': (baseNutrition['carbs'] ?? 0) * factor,
      'fat': (baseNutrition['fat'] ?? 0) * factor,
      'fiber': (baseNutrition['fiber'] ?? 0) * factor,
    };
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

/// Dialog for picking a replacement ingredient from the database
class _ReplacementPickerDialog extends StatefulWidget {
  final List<String> availableIngredients;
  final String currentName;

  const _ReplacementPickerDialog({
    required this.availableIngredients,
    required this.currentName,
  });

  @override
  State<_ReplacementPickerDialog> createState() => _ReplacementPickerDialogState();
}

class _ReplacementPickerDialogState extends State<_ReplacementPickerDialog> {
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Replace Ingredient'),
          const SizedBox(height: 4),
          Text(
            'Current: ${widget.currentName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
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

