import 'package:flutter/material.dart';
import '../services/allergen_service.dart';
import '../services/allergen_detection_service.dart';
import '../services/ingredient_analysis_service.dart';
import '../services/substitution_nutrition_service.dart';
import 'multi_substitution_dialog.dart';

class IngredientSubstitutionDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final List<String> detectedAllergens;

  const IngredientSubstitutionDialog({
    super.key,
    required this.recipe,
    required this.detectedAllergens,
  });

  @override
  State<IngredientSubstitutionDialog> createState() => _IngredientSubstitutionDialogState();
}

class _IngredientSubstitutionDialogState extends State<IngredientSubstitutionDialog> {
  String? _selectedIngredient;
  String? _selectedSubstitution;
  bool _isApplying = false;
  bool _isLoading = true;
  List<String> _substitutableIngredients = [];
  Map<String, List<String>> _substitutionOptions = {};

  @override
  void initState() {
    super.initState();
    _findSubstitutableIngredients();
  }

  void _findSubstitutableIngredients() async {
    print('DEBUG: IngredientSubstitutionDialog - Received detectedAllergens: ${widget.detectedAllergens}');
    
    // Get ingredients from the recipe
    List<dynamic> ingredients = [];
    if (widget.recipe['extendedIngredients'] != null) {
      ingredients = widget.recipe['extendedIngredients'] as List<dynamic>;
    } else if (widget.recipe['ingredients'] != null) {
      ingredients = widget.recipe['ingredients'] as List<dynamic>;
    }
    
    print('DEBUG: IngredientSubstitutionDialog - Raw ingredients: ${ingredients.length} items');
    
    // Find ingredients that contain allergens
    _substitutableIngredients = [];
    _substitutionOptions = {};
    
    for (final ingredient in ingredients) {
      String ingredientName;
      if (ingredient is Map<String, dynamic>) {
        ingredientName = ingredient['name']?.toString() ?? '';
      } else {
        ingredientName = ingredient.toString();
      }
      
      print('DEBUG: Checking ingredient: $ingredientName');
      
      // Check if this ingredient contains any of the detected allergens
      final foundAllergens = AllergenService.checkAllergens([ingredient]);
      print('DEBUG: Found allergens in $ingredientName: ${foundAllergens.keys.toList()}');
      
      for (final allergen in widget.detectedAllergens) {
        // Normalize allergen name to match AllergenService keys
        String allergenType = AllergenService.normalizeAllergenName(allergen);
        print('DEBUG: Checking allergen "$allergen" (normalized: "$allergenType")');
        
        if (foundAllergens.containsKey(allergenType)) {
          if (!_substitutableIngredients.contains(ingredientName)) {
            _substitutableIngredients.add(ingredientName);
            print('DEBUG: Getting substitutions for $allergenType');
            
            // NEW: Get safe substitutions that avoid user's other allergens
            final userAllergens = await AllergenDetectionService.getUserAllergens();
            final safeSubs = IngredientAnalysisService.getSafeSubstitutions(
              ingredientName,
              userAllergens,
            );
            
            // Also get admin substitutions
            final adminSubs = await AllergenService.getSubstitutionsWithAdmin(allergenType);
            
            // Combine and validate all substitutions
            final allSubs = [...safeSubs, ...adminSubs];
            final validatedSubs = allSubs.where((sub) {
              return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
            }).toSet().toList(); // Remove duplicates
            
            print('DEBUG: Got ${validatedSubs.length} safe substitutions: $validatedSubs');
            _substitutionOptions[ingredientName] = validatedSubs;
          }
        }
      }
    }
    
    // If no specific ingredients found, add the allergens themselves as substitutable
    if (_substitutableIngredients.isEmpty) {
      print('DEBUG: No specific ingredients found, adding allergens as substitutable');
      for (final allergen in widget.detectedAllergens) {
        // Normalize allergen name to match AllergenService keys
        String allergenType = AllergenService.normalizeAllergenName(allergen);
        print('DEBUG: Adding allergen "$allergen" (normalized: "$allergenType") as substitutable');
        
        final allergenName = AllergenService.getDisplayName(allergenType);
        _substitutableIngredients.add(allergenName);
        print('DEBUG: Getting substitutions for $allergenType');
        
        // NEW: Get safe substitutions
        final userAllergens = await AllergenDetectionService.getUserAllergens();
        final safeSubs = IngredientAnalysisService.getSafeSubstitutions(
          allergenName,
          userAllergens,
        );
        
        final adminSubs = await AllergenService.getSubstitutionsWithAdmin(allergenType);
        final allSubs = [...safeSubs, ...adminSubs];
        final validatedSubs = allSubs.where((sub) {
          return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
        }).toSet().toList();
        
        print('DEBUG: Got ${validatedSubs.length} safe substitutions: $validatedSubs');
        _substitutionOptions[allergenName] = validatedSubs;
      }
    }
    
    
    // Update UI
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applySubstitution() async {
    if (_selectedIngredient == null || _selectedSubstitution == null) return;
    
    setState(() {
      _isApplying = true;
    });
    
    try {
      // Create a modified recipe with the substitution
      final modifiedRecipe = Map<String, dynamic>.from(widget.recipe);
      
      // Update ingredients
      List<dynamic> ingredients = [];
      if (modifiedRecipe['extendedIngredients'] != null) {
        ingredients = List<dynamic>.from(modifiedRecipe['extendedIngredients'] as List<dynamic>);
      } else if (modifiedRecipe['ingredients'] != null) {
        ingredients = List<dynamic>.from(modifiedRecipe['ingredients'] as List<dynamic>);
      }
      
      // Replace the selected ingredient with the substitution
      for (int i = 0; i < ingredients.length; i++) {
        String ingredientName;
        if (ingredients[i] is Map<String, dynamic>) {
          ingredientName = ingredients[i]['name']?.toString() ?? '';
          if (ingredientName == _selectedIngredient) {
            ingredients[i] = {
              ...ingredients[i],
              'name': _selectedSubstitution,
              'original': _selectedIngredient,
              'substituted': true,
            };
          }
        } else {
          ingredientName = ingredients[i].toString();
          if (ingredientName == _selectedIngredient) {
            ingredients[i] = _selectedSubstitution;
          }
        }
      }
      
      // Update the recipe
      if (modifiedRecipe['extendedIngredients'] != null) {
        modifiedRecipe['extendedIngredients'] = ingredients;
      } else {
        modifiedRecipe['ingredients'] = ingredients;
      }
      
      // Store original nutrition before recalculation (only if not already stored)
      if (modifiedRecipe['originalNutrition'] == null) {
        modifiedRecipe['originalNutrition'] = Map<String, dynamic>.from(modifiedRecipe['nutrition'] ?? {});
      }
      
      // Recalculate nutrition with substituted ingredients
      final updatedNutrition = await _recalculateNutrition(modifiedRecipe);
      modifiedRecipe['nutrition'] = updatedNutrition;
      
      // Mark as substituted
      modifiedRecipe['substituted'] = true;
      modifiedRecipe['originalAllergens'] = widget.detectedAllergens;
      modifiedRecipe['substitutions'] = {
        _selectedIngredient!: _selectedSubstitution!,
      };
      
      print('DEBUG: Applied substitution: $_selectedIngredient -> $_selectedSubstitution');
      print('DEBUG: Updated nutrition: $updatedNutrition');
      
      if (mounted) {
        Navigator.of(context).pop(modifiedRecipe);
      }
    } catch (e) {
      print('DEBUG: Error applying substitution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying substitution: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _recalculateNutrition(Map<String, dynamic> recipe) async {
    try {
      // Use the new smart nutrition calculation service
      final adjustedNutrition = await SubstitutionNutritionService.recalculateNutritionWithSubstitutions(recipe);
      
      print('DEBUG: Smart nutrition recalculation completed:');
      print('  - Calories: ${adjustedNutrition['calories']} cal');
      print('  - Protein: ${adjustedNutrition['protein']} g');
      print('  - Carbs: ${adjustedNutrition['carbs']} g');
      print('  - Fat: ${adjustedNutrition['fat']} g');
      print('  - Fiber: ${adjustedNutrition['fiber']} g');
      
      return adjustedNutrition;
    } catch (e) {
      print('DEBUG: Error recalculating nutrition: $e');
      // Return original nutrition if calculation fails
      return recipe['nutrition'] as Map<String, dynamic>? ?? {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingredient Substitution',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Replace ingredients containing allergens',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Detected Allergens
              if (widget.detectedAllergens.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detected Allergens:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: widget.detectedAllergens.map((allergen) {
                          return Chip(
                            label: Text(AllergenService.getDisplayName(allergen)),
                            avatar: Text(AllergenService.getAllergenIcon(allergen)),
                            backgroundColor: Colors.orange.withOpacity(0.2),
                            labelStyle: const TextStyle(color: Colors.orange),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Loading indicator
              if (_isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading substitution options...'),
                      ],
                    ),
                  ),
                ),
              ] else if (_substitutableIngredients.isNotEmpty) ...[
                const Text(
                  'Select Ingredient to Substitute:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedIngredient,
                      hint: const Text('Choose an ingredient'),
                      isExpanded: true,
                      items: _substitutableIngredients.map((ingredient) {
                        return DropdownMenuItem<String>(
                          value: ingredient,
                          child: Text(ingredient),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedIngredient = value;
                          _selectedSubstitution = null; // Reset substitution selection
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Select Substitution
                if (_selectedIngredient != null) ...[
                  const Text(
                    'Choose Substitution:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubstitution,
                        hint: const Text('Choose a substitution'),
                        isExpanded: true,
                        items: (_substitutionOptions[_selectedIngredient] ?? []).map((substitution) {
                          return DropdownMenuItem<String>(
                            value: substitution,
                            child: Text(substitution),
                          );
                        }).toList(),
                        onChanged: (_substitutionOptions[_selectedIngredient] ?? []).isEmpty 
                            ? null 
                            : (value) {
                                setState(() {
                                  _selectedSubstitution = value;
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Preview
                  if (_selectedSubstitution != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Substitution Preview:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedIngredient!,
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.blue),
                              Expanded(
                                child: Text(
                                  _selectedSubstitution!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No substitutable ingredients found in this recipe.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedIngredient != null && 
                                 _selectedSubstitution != null && 
                                 !_isApplying) 
                          ? _applySubstitution 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isApplying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Apply Substitution'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
