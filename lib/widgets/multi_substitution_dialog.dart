import 'package:flutter/material.dart';
import '../services/allergen_service.dart';
import '../services/allergen_detection_service.dart';
import '../services/ingredient_analysis_service.dart';
import '../services/substitution_nutrition_service.dart';

class MultiSubstitutionDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final List<String> detectedAllergens;

  const MultiSubstitutionDialog({
    super.key,
    required this.recipe,
    required this.detectedAllergens,
  });

  @override
  State<MultiSubstitutionDialog> createState() => _MultiSubstitutionDialogState();
}

class _MultiSubstitutionDialogState extends State<MultiSubstitutionDialog> {
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isApplying = false;
  
  // Step 1: Allergen selection
  Map<String, bool> _selectedAllergens = {};
  
  // Step 2: Ingredient and substitution selection
  Map<String, String> _selectedSubstitutions = {};
  Map<String, List<String>> _substitutionOptions = {};
  Map<String, List<String>> _allergenIngredients = {};

  @override
  void initState() {
    super.initState();
    _initializeAllergenData();
  }

  /// Normalize allergen name to match AllergenService keys
  String _normalizeAllergenName(String allergen) {
    return AllergenService.normalizeAllergenName(allergen);
  }

  /// Get hardcoded substitution fallback data
  List<String> _getHardcodedSubstitutions(String allergenType) {
    const hardcodedSubstitutions = {
      'dairy': [
        'Almond milk for cow milk',
        'Coconut milk for heavy cream',
        'Nutritional yeast for cheese',
        'Coconut oil for butter',
        'Cashew cream for sour cream'
      ],
      'eggs': [
        'Flax eggs (1 tbsp ground flaxseed + 3 tbsp water)',
        'Chia eggs (1 tbsp chia seeds + 3 tbsp water)',
        'Applesauce (1/4 cup per egg)',
        'Banana (1/2 mashed banana per egg)',
        'Commercial egg replacer',
        'Silken tofu (1/4 cup per egg)'
      ],
      'fish': [
        'Tofu for fish proteinsss',
        'Mushrooms for fish texture',
        'Jackfruit for fish flakes',
        'Seaweed for fish flavor',
        'Plant-based fish alternatives',
        'Tempeh for fish protein'
      ],
      'shellfish': [
        'Mushrooms for shellfish texture',
        'Hearts of palm for scallops',
        'Artichoke hearts for crab',
        'Jackfruit for lobster',
        'Plant-based shellfish alternatives',
        'Tofu for shrimp texture'
      ],
      'tree_nuts': [
        'Sunflower seeds for nuts',
        'Pumpkin seeds for nuts',
        'Oats for nut texture',
        'Coconut for nut flavor',
        'Seeds for nut protein',
        'Plant-based nut alternatives'
      ],
      'peanuts': [
        'Sunflower seed butter',
        'Almond butter (if no tree nut allergy)',
        'Soy butter',
        'Tahini (sesame seed butter)',
        'Coconut butter',
        'Pumpkin seed butter'
      ],
      'wheat': [
        'Rice flour for wheat flour',
        'Almond flour for wheat flour',
        'Coconut flour for wheat flour',
        'Oat flour for wheat flour',
        'Quinoa flour for wheat flour',
        'Gluten-free flour blends'
      ],
      'soy': [
        'Coconut aminos for soy sauce',
        'Tamari (wheat-free soy sauce)',
        'Liquid aminos',
        'Miso alternatives',
        'Tempeh alternatives',
        'Tofu alternatives'
      ],
    };
    
    return hardcodedSubstitutions[allergenType.toLowerCase()] ?? [];
  }

  void _initializeAllergenData() async {
    // Get ingredients from the recipe
    List<dynamic> ingredients = [];
    if (widget.recipe['extendedIngredients'] != null) {
      ingredients = widget.recipe['extendedIngredients'] as List<dynamic>;
    } else if (widget.recipe['ingredients'] != null) {
      ingredients = widget.recipe['ingredients'] as List<dynamic>;
    }
    
    print('DEBUG: Multi-substitution - Raw ingredients: $ingredients');
    
    // Find ingredients that contain each detected allergen
    _allergenIngredients = {};
    _substitutionOptions = {};
    
    for (final allergen in widget.detectedAllergens) {
      _selectedAllergens[allergen] = true; // Default to selected
      _allergenIngredients[allergen] = [];
      _substitutionOptions[allergen] = [];
      
      // Find ingredients containing this allergen
      // Normalize allergen name to match AllergenService keys
      String normalizedAllergen = _normalizeAllergenName(allergen);
      print('DEBUG: Multi-sub - Checking for allergen "$allergen" (normalized: "$normalizedAllergen")');
      print('DEBUG: Multi-sub - Total ingredients to check: ${ingredients.length}');
      
      for (final ingredient in ingredients) {
        String ingredientName;
        if (ingredient is Map<String, dynamic>) {
          ingredientName = ingredient['name']?.toString() ?? '';
        } else {
          ingredientName = ingredient.toString();
        }
        
        // Skip empty ingredients
        if (ingredientName.trim().isEmpty) {
          continue;
        }
        
        print('DEBUG: Multi-sub - Checking ingredient: "$ingredientName"');
        
        // Convert ingredient to the format expected by AllergenService
        final ingredientForCheck = {
          'name': ingredientName,
          'amount': 1.0,
          'unit': '',
        };
        
        final foundAllergens = await AllergenService.checkAllergens([ingredientForCheck]);
        print('DEBUG: Multi-sub - Ingredient "$ingredientName" contains allergens: ${foundAllergens.keys.toList()}');
        
        // Check if this ingredient contains the allergen we're looking for
        if (foundAllergens.containsKey(normalizedAllergen)) {
          _allergenIngredients[allergen]!.add(ingredientName);
          print('DEBUG: Multi-sub - ✓ Found allergen "$allergen" in ingredient "$ingredientName"');
        }
      }
      
      print('DEBUG: Multi-sub - Found ${_allergenIngredients[allergen]!.length} ingredients with $allergen');
      
      // Get substitution options for this allergen
      try {
        // NEW: Get safe substitutions that avoid user's other allergens
        final userAllergens = await AllergenDetectionService.getUserAllergens();
        final safeSubs = IngredientAnalysisService.getSafeSubstitutions(
          allergen,
          userAllergens,
        );
        
        final substitutions = await AllergenService.getSubstitutions(normalizedAllergen);
        print('DEBUG: Got ${substitutions.length} substitutions for $allergen (normalized: $normalizedAllergen): $substitutions');
        
        // Combine safe and regular substitutions
        final allSubs = [...safeSubs, ...substitutions];
        
        // Validate all substitutions
        final validatedSubs = allSubs.where((sub) {
          return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
        }).toSet().toList(); // Remove duplicates
        
        // If no substitutions found, use hardcoded fallback
        if (validatedSubs.isEmpty) {
          print('DEBUG: No safe substitutions found, using hardcoded fallback for $allergen');
          final fallbackSubstitutions = _getHardcodedSubstitutions(normalizedAllergen);
          _substitutionOptions[allergen] = fallbackSubstitutions;
        } else {
          print('DEBUG: Got ${validatedSubs.length} safe substitutions');
          _substitutionOptions[allergen] = validatedSubs;
        }
      } catch (e) {
        print('DEBUG: Error getting substitutions for $allergen: $e');
        final fallbackSubstitutions = _getHardcodedSubstitutions(normalizedAllergen);
        _substitutionOptions[allergen] = fallbackSubstitutions;
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate that at least one allergen is selected
      final selectedCount = _selectedAllergens.values.where((selected) => selected).length;
      if (selectedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one allergen to substitute')),
        );
        return;
      }
    }
    
    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
  }

  void _applyAllSubstitutions() async {
    setState(() {
      _isApplying = true;
    });
    
    try {
      // Create a modified recipe with all substitutions
      final modifiedRecipe = Map<String, dynamic>.from(widget.recipe);
      
      // Update ingredients
      List<dynamic> ingredients = [];
      if (modifiedRecipe['extendedIngredients'] != null) {
        ingredients = List<dynamic>.from(modifiedRecipe['extendedIngredients'] as List<dynamic>);
      } else if (modifiedRecipe['ingredients'] != null) {
        ingredients = List<dynamic>.from(modifiedRecipe['ingredients'] as List<dynamic>);
      }
      
      // Apply all selected substitutions
      final appliedSubstitutions = <String, String>{};
      
      for (final allergen in _selectedAllergens.keys) {
        if (_selectedAllergens[allergen] == true && _selectedSubstitutions.containsKey(allergen)) {
          final substitution = _selectedSubstitutions[allergen]!;
          print('DEBUG: Applying substitution for $allergen: $substitution');
          
          // Replace ingredients containing this allergen
          for (int i = 0; i < ingredients.length; i++) {
            String ingredientName;
            if (ingredients[i] is Map<String, dynamic>) {
              ingredientName = ingredients[i]['name']?.toString() ?? '';
              if (_allergenIngredients[allergen]!.contains(ingredientName)) {
                print('DEBUG: Replacing ingredient "$ingredientName" with "$substitution"');
                ingredients[i] = {
                  ...ingredients[i],
                  'name': substitution,
                  'original': ingredientName,
                  'substituted': true,
                  'allergen': allergen,
                };
                appliedSubstitutions[ingredientName] = substitution;
              }
            } else {
              ingredientName = ingredients[i].toString();
              if (_allergenIngredients[allergen]!.contains(ingredientName)) {
                print('DEBUG: Replacing ingredient "$ingredientName" with "$substitution"');
                ingredients[i] = substitution;
                appliedSubstitutions[ingredientName] = substitution;
              }
            }
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
      
      // Recalculate nutrition with all substituted ingredients
      final updatedNutrition = await SubstitutionNutritionService.recalculateNutritionWithSubstitutions(modifiedRecipe);
      modifiedRecipe['nutrition'] = updatedNutrition;
      
      // Mark as substituted
      modifiedRecipe['substituted'] = true;
      modifiedRecipe['originalAllergens'] = widget.detectedAllergens;
      modifiedRecipe['substitutions'] = appliedSubstitutions;
      
      print('DEBUG: Applied multiple substitutions: $appliedSubstitutions');
      print('DEBUG: Updated nutrition: $updatedNutrition');
      
      if (mounted) {
        Navigator.of(context).pop(modifiedRecipe);
      }
    } catch (e) {
      print('DEBUG: Error applying multiple substitutions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying substitutions: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: Colors.green[600],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Substitute Multiple Ingredients',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Progress indicator
                  Row(
                    children: [
                      _buildStepIndicator(0, 'Select Allergens'),
                      Expanded(child: Divider(color: Colors.grey[300])),
                      _buildStepIndicator(1, 'Choose Substitutions'),
                      Expanded(child: Divider(color: Colors.grey[300])),
                      _buildStepIndicator(2, 'Review & Apply'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Step content
                  Expanded(
                    child: _buildStepContent(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _currentStep < 2 ? _nextStep : _applyAllSubstitutions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isApplying
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  _currentStep < 2 ? 'Next' : 'Apply All Substitutions',
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? Colors.green[600] : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.green[600] : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildAllergenSelectionStep();
      case 1:
        return _buildSubstitutionSelectionStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAllergenSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select allergens to substitute:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: widget.detectedAllergens.length,
            itemBuilder: (context, index) {
              final allergen = widget.detectedAllergens[index];
              final ingredientCount = _allergenIngredients[allergen]?.length ?? 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Row(
                    children: [
                      Text(AllergenService.getAllergenIcon(allergen)),
                      const SizedBox(width: 8),
                      Text(AllergenService.getDisplayName(allergen)),
                    ],
                  ),
                  subtitle: Text('$ingredientCount ingredient(s) found'),
                  value: _selectedAllergens[allergen] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _selectedAllergens[allergen] = value ?? false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubstitutionSelectionStep() {
    final selectedAllergens = _selectedAllergens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose substitutions for each allergen:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: selectedAllergens.length,
            itemBuilder: (context, index) {
              final allergen = selectedAllergens[index];
              final substitutions = _substitutionOptions[allergen] ?? [];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(AllergenService.getAllergenIcon(allergen)),
                          const SizedBox(width: 8),
                          Text(
                            AllergenService.getDisplayName(allergen),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingredients: ${_allergenIngredients[allergen]?.join(', ') ?? 'None'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      if (substitutions.isNotEmpty) ...[
                        const Text('Choose substitution:'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubstitutions[allergen],
                              hint: const Text('Select substitution'),
                              isExpanded: true,
                              items: substitutions.map((substitution) {
                                return DropdownMenuItem<String>(
                                  value: substitution,
                                  child: Text(substitution),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubstitutions[allergen] = value ?? '';
                                });
                              },
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'No substitutions available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final selectedAllergens = _selectedAllergens.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review your substitutions:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: selectedAllergens.length,
            itemBuilder: (context, index) {
              final allergen = selectedAllergens[index];
              final substitution = _selectedSubstitutions[allergen];
              final ingredients = _allergenIngredients[allergen] ?? [];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(AllergenService.getAllergenIcon(allergen)),
                  title: Text(AllergenService.getDisplayName(allergen)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ingredients: ${ingredients.join(', ')}'),
                      if (substitution != null && substitution.isNotEmpty)
                        Text('Substitution: $substitution'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
