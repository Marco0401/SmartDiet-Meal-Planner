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
  
  @override
  void initState() {
    super.initState();
    _instructionsController.text = widget.meal['instructions']?.toString() ?? '';
    
    // Extract ingredients as full objects from both 'ingredients' and 'extendedIngredients' arrays
    _editedIngredients = _extractIngredientsFromMeal(widget.meal);
    
    _loadAvailableIngredients();
    
    // Initial nutrition calculation
    _recalculateNutrition();
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
          allIngredients.add(ing);
        }
      }
    }
    
    // Extract from extendedIngredients (Spoonacular format)
    if (meal['extendedIngredients'] != null && meal['extendedIngredients'] is List) {
      for (final ing in meal['extendedIngredients'] as List) {
        if (ing is Map<String, dynamic>) {
          allIngredients.add({
            'name': ing['name'] ?? ing['originalName'] ?? ing['original'] ?? 'Unknown',
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

  /// Parse ingredient string to extract name, amount, and unit
  Map<String, dynamic> _parseIngredientString(String ingredientString) {
    final original = ingredientString.trim();
    
    print('DEBUG: Parsing ingredient string: "$original"');
    
    // Pattern 1: "450 grams Boneless skin Chicken" (amount + single-word unit + name)
    final pattern1 = RegExp(r'^(\d+(?:\.\d+)?|\d+\/\d+)\s+([a-zA-Z]+)\s+(.+)$');
    final match1 = pattern1.firstMatch(original);
    
    if (match1 != null) {
      var amountStr = match1.group(1) ?? '';
      final unit = (match1.group(2) ?? '').trim();
      final name = (match1.group(3) ?? original).trim();
      
      print('DEBUG: Pattern1 matched - amount: $amountStr, unit: $unit, name: $name');
      
      String fractionDisplay = amountStr;
      double amount = 1.0;
      
      if (amountStr.contains('/')) {
        final parts = amountStr.split('/');
        final numerator = double.tryParse(parts[0]) ?? 1.0;
        final denominator = double.tryParse(parts[1]) ?? 1.0;
        amount = numerator / denominator;
        fractionDisplay = amountStr;
      } else {
        amount = double.tryParse(amountStr) ?? 1.0;
        fractionDisplay = amountStr;
      }
      
      final cleanedName = _cleanIngredientName(name);
      
      return {
        'name': cleanedName,
        'amount': amount,
        'amountDisplay': fractionDisplay,
        'unit': unit.toLowerCase(),
        'original': original,
      };
    }
    
    // Pattern 2: Multi-word units "2 tablespoons Soy sauce" (amount + multi-word unit + name)
    final pattern2 = RegExp(r'^(\d+(?:\.\d+)?|\d+\/\d+)\s+([a-zA-Z]+\s+[a-zA-Z]+)\s+(.+)$');
    final match2 = pattern2.firstMatch(original);
    
    if (match2 != null) {
      var amountStr = match2.group(1) ?? '';
      final unit = (match2.group(2) ?? '').trim();
      final name = (match2.group(3) ?? original).trim();
      
      print('DEBUG: Pattern2 matched - amount: $amountStr, unit: $unit, name: $name');
      
      String fractionDisplay = amountStr;
      double amount = 1.0;
      
      if (amountStr.contains('/')) {
        final parts = amountStr.split('/');
        final numerator = double.tryParse(parts[0]) ?? 1.0;
        final denominator = double.tryParse(parts[1]) ?? 1.0;
        amount = numerator / denominator;
        fractionDisplay = amountStr;
      } else {
        amount = double.tryParse(amountStr) ?? 1.0;
        fractionDisplay = amountStr;
      }
      
      final cleanedName = _cleanIngredientName(name);
      
      return {
        'name': cleanedName,
        'amount': amount,
        'amountDisplay': fractionDisplay,
        'unit': unit.toLowerCase(),
        'original': original,
      };
    }
    
    print('DEBUG: No pattern matched, treating as name only');
    
    // Fallback: Just a name without amount/unit (e.g., "Pork", "Tomato sauce")
    final cleanedName = _cleanIngredientName(original);
    
    return {
      'name': cleanedName,
      'amount': 1.0,
      'amountDisplay': '1',
      'unit': '',
      'original': original,
    };
  }

  /// Clean ingredient name by removing descriptors and finding similar names
  String _cleanIngredientName(String name) {
    final lowerName = name.toLowerCase().trim();
    
    // Skip matching if ingredients haven't loaded yet
    if (_availableIngredients.isEmpty) {
      print('DEBUG: Ingredients not loaded yet, returning original: "$lowerName"');
      return lowerName;
    }
    
    // Remove common descriptors to get to the core ingredient
    var cleaned = lowerName
        .replaceAll(RegExp(r'\b(boneless|skinless|bone-in|fresh|dried|frozen|canned|chopped|diced|sliced|grated|minced|ground|whole|half|quarter|large|medium|small|big|tiny|peeled|crushed|finely|coarsely|roughly|thinly|thickly|julienned|cubed|strips|granulated|powdered|raw|cooked|boiled|fried|grilled|skin|boneless)\b'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' '); // Remove extra spaces
    
    // Helper to normalize plurals (remove trailing 's' for comparison)
    String normalizePlural(String word) => word.replaceAll(RegExp(r's$'), '');
    
    // Get just the last significant word (e.g., "granulated sugar" -> "sugar", "boneless skin chicken" -> "chicken")
    String getLastWord(String text) {
      final words = text.split(' ').where((w) => w.length > 2).toList();
      return words.isNotEmpty ? words.last : text;
    }
    
    // 1. Try exact case-insensitive match first (most precise)
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower == lowerName) {
        print('DEBUG: Found exact match: "$lowerName" -> "$ing"');
        return ing;
      }
    }
    
    // 2. Try cleaned version against exact match (case-insensitive)
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower == cleaned) {
        print('DEBUG: Found exact match after cleaning: "$cleaned" -> "$ing"');
        return ing;
      }
    }
    
    // 3. Try getting the last word and matching that
    final lastWord = getLastWord(cleaned);
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower == lastWord || ingLower.contains(lastWord)) {
        print('DEBUG: Found match by last word: "$lastWord" from "$cleaned" -> "$ing"');
        return ing;
      }
    }
    
    // 4. Try plural/singular matching with last word (e.g., "carrots" -> "carrot", "potatoes" -> "potato")
    final lastWordSingular = normalizePlural(lastWord);
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      final ingSingular = normalizePlural(ingLower);
      
      // If singular forms match, it's a match (case-insensitive)
      if (ingSingular == lastWordSingular) {
        print('DEBUG: Found plural/singular match by last word: "$lastWordSingular" from "$cleaned" -> "$ing"');
        return ing;
      }
    }
    
    // 5. Try to find where cleaned version is a substring (e.g., "lemon" in "lemon juice")
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower.contains(cleaned) || cleaned.contains(ingLower)) {
        // Prefer matches where the ingredient starts with the cleaned name
        // (e.g., "lemon" -> "lemon juice" is better than "lemon" -> "lemongrass")
        if (ingLower.startsWith(cleaned)) {
          print('DEBUG: Found substring match (ingredient starts with): "$cleaned" in "$ing"');
          return ing;
        }
      }
    }
    
    // 6. Try partial word matching (e.g., "soy sauce" contains "soy" and "sauce")
    final cleanedWords = cleaned.split(' ').where((w) => w.length > 2).toList();
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      final ingWords = ingLower.split(' ').where((w) => w.length > 2).toList();
      
      // Check if most words match (including plural/singular)
      final matchingWords = cleanedWords.where((cw) {
        final cwSingular = normalizePlural(cw);
        return ingWords.any((iw) {
          final iwSingular = normalizePlural(iw);
          return iw.contains(cw) || cw.contains(iw) || iwSingular == cwSingular;
        });
      }).length;
      
      if (matchingWords > 0 && matchingWords == cleanedWords.length) {
        print('DEBUG: Found word-based match: "$cleaned" -> "$ing" (matched $matchingWords words)');
        return ing;
      }
    }
    
    // 7. Try to find a match where ingredient contains the key word (case-insensitive)
    for (final ing in _availableIngredients) {
      final ingLower = ing.toLowerCase();
      if (ingLower.contains(cleaned) || cleaned.contains(ingLower)) {
        print('DEBUG: Found general substring match: "$cleaned" -> "$ing"');
        return ing;
      }
    }
    
    // Return cleaned original if no match found
    print('DEBUG: No match found for: "$cleaned"');
    return cleaned;
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
        setState(() {
          _availableIngredients = ingredients.keys.toList();
          _availableIngredientsWithNutrition = Map<String, dynamic>.from(ingredients);
        });
      }
    } catch (e) {
      print('Error loading ingredients: $e');
    }
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

    // Create ingredient object
    final newIngredient = {
      'name': ingredientName,
      'amount': 1.0,
      'unit': '',
      'original': ingredientName,
    };

    // Check for allergens
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

  /// Normalize unit names to dropdown values
  String _normalizeUnit(String unit) {
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
      'l': 'L',
      'liter': 'L',
      'liters': 'L',
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
    };
    
    return unitMap[lowerUnit] ?? 'piece'; // default to 'piece' if not found
  }

  Future<void> _editIngredientAmountUnit(int index) async {
    final ingredient = _editedIngredients[index];
    final rawUnit = ingredient['unit']?.toString() ?? '';
    final normalizedUnit = _normalizeUnit(rawUnit);
    
    print('DEBUG: Editing ingredient - unit: "$rawUnit" -> normalized: "$normalizedUnit"');
    
    final amountController = TextEditingController(text: ingredient['amountDisplay']?.toString() ?? ingredient['amount']?.toString() ?? '1');
    final unitController = TextEditingController(text: normalizedUnit);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${ingredient['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: unitController.text.isNotEmpty ? unitController.text : 'piece',
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
                }
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
                  'unit': unitController.text.isNotEmpty ? unitController.text : 'piece',
                };
              });
              Navigator.pop(context);
              _recalculateNutrition();
            },
            child: const Text('Save'),
          ),
        ],
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current meal data
      final mealDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc(widget.mealId)
          .get();

      if (!mealDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal not found')),
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

      // Prepare updated data
      final updatedData = {
        'instructions': _instructionsController.text.trim(),
        'ingredients': _editedIngredients,
        'nutrition': _calculatedNutrition.isNotEmpty 
            ? _calculatedNutrition 
            : widget.meal['nutrition'],
        'hasAllergens': hasAllergenConflict,
        'detectedAllergens': hasAllergenConflict 
            ? detectedAllergens.entries.map((e) => e.key).toList()
            : [],
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Preserve substitution metadata to prevent nutrition recalculation
        if (widget.meal['substituted'] == true) 'substituted': true,
        if (widget.meal['originalNutrition'] != null) 
            'originalNutrition': widget.meal['originalNutrition'],
        if (widget.meal['substitutions'] != null) 
            'substitutions': widget.meal['substitutions'],
        if (widget.meal['extendedIngredients'] != null) 
            'extendedIngredients': widget.meal['extendedIngredients'],
        if (widget.meal['originalAllergens'] != null) 
            'originalAllergens': widget.meal['originalAllergens'],
      };

      // Update meal in Firestore
      await mealDoc.reference.update(updatedData);

      // Update local state
      setState(() {
        widget.meal['instructions'] = _instructionsController.text.trim();
        widget.meal['ingredients'] = _editedIngredients;
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
          const SnackBar(
            content: Text('Meal updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving meal changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meal: $e'),
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _editedIngredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _editedIngredients[index];
                    final ingredientName = ingredient['name']?.toString() ?? 'Unknown Ingredient';
                    
                    // Case-insensitive lookup for nutrition data
                    Map<String, dynamic>? nutrition;
                    for (final entry in _availableIngredientsWithNutrition.entries) {
                      if (entry.key.toLowerCase() == ingredientName.toLowerCase()) {
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
                                          Text(
                                            '${ingredient['amountDisplay'] ?? ingredient['amount'] ?? 1} ${ingredient['unit'] ?? ''}'.trim(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
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
            
            // Instructions
            Text(
              'Instructions',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _instructionsController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Enter cooking instructions...',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
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

