import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'services/allergen_ml_service.dart';
import 'services/allergen_service.dart';
import 'services/allergen_detection_service.dart';
import 'services/nutrition_service.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'services/substitution_nutrition_service.dart';
import 'meal_favorites_page.dart';
import 'meal_plan_dialog.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/substitution_dialog_helper.dart';
import 'widgets/edit_meal_dialog.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  Map<String, dynamic>? _recipeDetails;
  bool _isLoading = true;
  String? _error;
  Map<String, int>? _mlAllergens;
  String? _mlStatus; // debug/status of ML call
  String _mlSourceText = '';
  bool _isFavorited = false;
  bool _isCheckingFavorite = true;
  bool _isRunningML = false;

  // Lightweight keyword hints to explain ML detections
  static const Map<String, List<String>> _mlKeywordMap = {
    'peanuts': ['peanut','peanuts','peanut butter'],
    'tree_nuts': ['almond','walnut','cashew','pecan','hazelnut','pistachio'],
    'milk': ['milk','cheese','yogurt','cream','butter','ghee','dairy'],
    'eggs': ['egg','eggs','mayonnaise','mayo'],
    'fish': ['fish','salmon','tuna','cod','tilapia','mackerel','anchovy'],
    'shellfish': ['shrimp','prawn','crab','lobster','clam','mussel','oyster','scallop'],
    'wheat_gluten': ['flour','wheat','bread','pasta','noodles','semolina'],
    'soy': ['soy','soya','tofu','edamame','soy sauce','miso','tempeh'],
    'sesame': ['sesame','tahini','sesame seed','sesame oil'],
  };

  List<String> _findMlMatches(String allergen, String text) {
    final terms = _mlKeywordMap[allergen] ?? const [];
    final lower = text.toLowerCase();
    final hits = <String>[];
    for (final t in terms) {
      if (lower.contains(t)) hits.add(t);
    }
    return hits;
  }

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
    _checkIfFavorited();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      print('DEBUG: Loading recipe details for: ${widget.recipe}');
      print('DEBUG: Recipe keys: ${widget.recipe.keys.toList()}');
      print('DEBUG: Ingredients type: ${widget.recipe['ingredients']?.runtimeType}');
      print('DEBUG: ExtendedIngredients type: ${widget.recipe['extendedIngredients']?.runtimeType}');
      // If this recipe came from Favorites (docId present), fetch the latest nested recipe object
      final favoriteDocId = widget.recipe['docId']?.toString();
      if (favoriteDocId != null && favoriteDocId.isNotEmpty) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final favSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('favorites')
                .doc(favoriteDocId)
                .get();
            if (favSnap.exists) {
              final favData = favSnap.data() as Map<String, dynamic>;
              final latestRecipe = Map<String, dynamic>.from(favData['recipe'] ?? {});
              latestRecipe['docId'] = favoriteDocId; // preserve for future edits
              // Remove any lingering date field from favorites recipe in memory
              latestRecipe.remove('date');
              print('DEBUG: Loaded latest favorite recipe from Firestore');
              setState(() {
                _recipeDetails = latestRecipe;
                _isLoading = false;
              });
              // After setting latest data from favorites, continue rendering directly
              return;
            }
          }
        } catch (e) {
          print('DEBUG: Error fetching latest favorite recipe: $e');
        }
      }
      
      // Check if this is a local recipe or API recipe
      // Use recipeId if available (for meals from meal planner), otherwise fall back to id
      final recipeId = widget.recipe['recipeId'] ?? widget.recipe['id'];
      
      if (recipeId == null) {
        // No ID, use the recipe data directly (this is likely a manually entered meal)
        print('DEBUG: No recipe ID, using data directly');
        setState(() {
          _recipeDetails = widget.recipe;
          _isLoading = false;
        });
        return;
      }
      
      // Check if this is a local/manual recipe that should use data directly
      final source = widget.recipe['source']?.toString().toLowerCase() ?? '';
      final substituted = widget.recipe['substituted'];
      print('DEBUG: Recipe source: $source, recipeId: $recipeId, substituted: $substituted');
      print('DEBUG: Meal data keys: ${widget.recipe.keys.toList()}');
      print('DEBUG: Meal data summary: ${widget.recipe['summary']}');
      print('DEBUG: Meal data description: ${widget.recipe['description']}');
      
      // Use meal data directly if it has any of these conditions
      final hasIngredients = widget.recipe['ingredients'] != null || widget.recipe['extendedIngredients'] != null;
      final isFromMealPlanner = widget.recipe['date'] != null; // Meals in planner have date field
      
      if (recipeId.toString().startsWith('local_') || 
          recipeId.toString().startsWith('admin_filipino_') ||
          recipeId.toString().startsWith('firestore_filipino_') ||
          source == 'manual_entry' ||
          source == 'manual entry' ||
          source == 'meal_planner' ||
          source == 'local' ||
          source == 'expert_plan' ||
          source == 'scanner' ||
          source == 'openfoodfacts' ||
          source == 'OpenFoodFacts' ||
          source == 'usda' ||
          source == 'USDA' ||
          source == 'admin created' ||
          source == 'admin' ||
          substituted == true ||
          isFromMealPlanner) { // Also use data directly for planned meals
        // This is a local recipe, manually entered meal, substituted recipe, expert plan meal, meal from planner, or scanned product - use the data directly
        print('DEBUG: Local/manual/substituted/expert_plan/meal_planner/scanned recipe, using data directly');
        print('DEBUG: Using meal data directly - summary: ${widget.recipe['summary']}, description: ${widget.recipe['description']}');
        
        // If this is a substituted recipe, recalculate nutrition only if not already recalculated
        if (substituted == true) {
          // Check if nutrition has already been recalculated by comparing with original
          final currentCalories = (widget.recipe['nutrition']?['calories'] as num?)?.toDouble() ?? 0;
          final originalCalories = (widget.recipe['originalNutrition']?['calories'] as num?)?.toDouble() ?? 0;
          
          print('DEBUG: Substituted recipe check - current: $currentCalories, original: $originalCalories');
          print('DEBUG: originalNutrition is null: ${widget.recipe['originalNutrition'] == null}');
          print('DEBUG: currentCalories == 0.0: ${currentCalories == 0.0}');
          print('DEBUG: Will recalculate: ${widget.recipe['originalNutrition'] == null || currentCalories == 0.0}');
          
          // Always recalculate if originalNutrition is null (indicating no original data stored) OR current nutrition is 0 (indicating no nutrition data)
          if (widget.recipe['originalNutrition'] == null || currentCalories == 0.0) {
            print('DEBUG: Recipe is substituted, recalculating nutrition...');
            print('DEBUG: About to call SubstitutionNutritionService.recalculateNutritionWithSubstitutions');
            try {
              // Store original nutrition if not already stored
              if (widget.recipe['originalNutrition'] == null) {
                // For substituted recipes, we need to calculate the original nutrition
                // by temporarily reverting substitutions and calculating with original ingredients
                print('DEBUG: Calculating original nutrition by reverting substitutions...');
                
                // Store current nutrition as original (this is the nutrition with substitutions)
                // The SubstitutionNutritionService will recalculate based on the substituted ingredients
                widget.recipe['originalNutrition'] = Map<String, dynamic>.from(widget.recipe['nutrition'] ?? {});
                print('DEBUG: Set originalNutrition to current nutrition for recalculation');
              }
              
              print('DEBUG: Calling SubstitutionNutritionService.recalculateNutritionWithSubstitutions...');
              final adjustedNutrition = await SubstitutionNutritionService.recalculateNutritionWithSubstitutions(widget.recipe);
              print('DEBUG: Got result from SubstitutionNutritionService: $adjustedNutrition');
              widget.recipe['nutrition'] = adjustedNutrition;
              print('DEBUG: Nutrition recalculated for substituted recipe');
              
              // Update the meal in Firestore to persist the changes
              await _updateMealInFirestore(widget.recipe);
              print('DEBUG: Updated meal in Firestore with recalculated nutrition');
            } catch (e) {
              print('DEBUG: Error recalculating nutrition for substituted recipe: $e');
            }
          } else {
            print('DEBUG: Nutrition already recalculated for substituted recipe (current: $currentCalories, original: $originalCalories)');
          }
        }
        
        setState(() {
          _recipeDetails = widget.recipe;
          _isLoading = false;
        });
        
        // Force additional refresh to ensure clean display
        setState(() {
          print('DEBUG: Refreshing recipe details page UI for clean display');
        });
        return;
      }
      
      // Try Filipino Recipe Service first for Filipino recipes
      Map<String, dynamic>? details;
      
      // Store original summary/description from meal data as fallback
      final originalSummary = widget.recipe['summary'];
      final originalDescription = widget.recipe['description'];
      print('DEBUG: Original summary: $originalSummary, description: $originalDescription');
      
      if (widget.recipe['cuisine'] == 'Filipino' || 
          recipeId.toString().startsWith('curated_') ||
          recipeId.toString().startsWith('themealdb_') ||
          recipeId.toString().startsWith('local_filipino_')) {
        print('DEBUG: Trying Filipino Recipe Service');
        details = await FilipinoRecipeService.getRecipeDetails(recipeId.toString());
      }
      
      // Fallback to regular Recipe Service
      if (details == null) {
        print('DEBUG: Trying regular Recipe Service');
        details = await RecipeService.fetchRecipeDetails(recipeId);
      }
      
      // Apply fallback for summary/description if API data doesn't have it
      if ((details['summary'] == null || details['summary'].toString().isEmpty) && 
          originalSummary != null && originalSummary.toString().isNotEmpty) {
        print('DEBUG: Using original summary as fallback');
        details['summary'] = originalSummary;
      }
      if ((details['description'] == null || details['description'].toString().isEmpty) && 
          originalDescription != null && originalDescription.toString().isNotEmpty) {
        print('DEBUG: Using original description as fallback');
        details['description'] = originalDescription;
      }
      
      print('DEBUG: Recipe details loaded successfully');
      setState(() {
        _recipeDetails = details;
        _isLoading = false;
      });
      
      // Force additional refresh to ensure clean display
      setState(() {
        print('DEBUG: Refreshing recipe details page UI for API-fetched recipe');
      });
    } catch (e) {
      print('DEBUG: Error in _loadRecipeDetails: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAllergenML() async {
    if (_isRunningML || _mlStatus != 'ML: not started') return; // Prevent multiple calls
    
    try {
      setState(() {
        _mlStatus = 'ML: detecting...';
        _isRunningML = true;
      });
      final r = _recipeDetails ?? widget.recipe;
      final title = (r['title'] ?? '').toString();
      
      String ingredients = '';
      try {
        if (r['extendedIngredients'] != null) {
          ingredients = (r['extendedIngredients'] as List?)?.map((e) {
            // Handle both object format (API recipes) and string format (substituted recipes)
            if (e is Map<String, dynamic>) {
              return (e['name'] ?? '').toString();
            } else {
              return e.toString();
            }
          }).join(' ') ?? '';
        } else if (r['ingredients'] != null) {
          ingredients = (r['ingredients'] as List?)?.map((e) => e.toString()).join(' ') ?? '';
        }
      } catch (e) {
        print('DEBUG: Error processing ingredients for ML: $e');
        ingredients = '';
      }
      
      final text = ('$title $ingredients').trim();
      if (text.isEmpty) {
        setState(() {
          _mlStatus = 'ML: no text';
          _isRunningML = false;
        });
        return;
      }
      
      // Add timeout to prevent hanging
      final result = await AllergenMLService.predictWithScores(text).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('ML API timeout');
        },
      );
      final labels = result.labels;
      // Debug: print ML labels
      // ignore: avoid_print
      print('ML allergens for "$title": $labels');
      if (mounted) {
        setState(() {
          _mlAllergens = labels;
          _mlSourceText = text;
          _isRunningML = false;
          
          // Process scores
          final positives = result.scores.entries
              .where((e) => e.value == 1)
              .where((e) => _findMlMatches(e.key, text).isNotEmpty)
              .map((e) => '${e.key} ${e.value.toStringAsFixed(2)}')
              .toList();
          _mlStatus = positives.isEmpty ? 'ML: no positives' : 'ML: ${positives.join(', ')}';
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('ML error: $e');
      if (mounted) {
        setState(() {
          _mlStatus = 'ML error';
          _isRunningML = false;
          _mlAllergens = {}; // Set empty map to prevent further calls
        });
      }
    }
  }

  Future<void> _checkIfFavorited() async {
    if (widget.recipe['id'] != null) {
      final isFavorited = await FavoriteService.isFavorited(widget.recipe['id'].toString());
      setState(() {
        _isFavorited = isFavorited;
        _isCheckingFavorite = false;
      });
    } else {
      setState(() {
        _isCheckingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorited) {
      await FavoriteService.removeFromFavorites(widget.recipe['id'].toString());
      setState(() {
        _isFavorited = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from favorites'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await FavoriteService.addToFavorites(context, widget.recipe);
      setState(() {
        _isFavorited = true;
      });
    }
  }

  Future<void> _editMeal() async {
    // Use the freshest data available
    final baseRecipe = _recipeDetails ?? widget.recipe;
    // Extract the meal ID and date from the recipe (for meal planner)
    final mealId = baseRecipe['id']?.toString() ?? '';
    final dateKey = baseRecipe['date']?.toString() ?? '';
    
    // Check if it's a favorite meal (has docId)
    final favoriteId = baseRecipe['docId']?.toString() ?? '';
    final isFavorite = favoriteId.isNotEmpty && dateKey.isEmpty;
    
    // Validate that we have required IDs
    if (mealId.isEmpty && favoriteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit this meal. Missing required information.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show the Edit Meal Dialog
    final result = await showDialog(
      context: context,
      builder: (context) => EditMealDialog(
        meal: baseRecipe,
        mealId: isFavorite ? favoriteId : mealId,
        dateKey: dateKey, // Empty for favorites
      ),
    );

    // If meal was successfully edited, refresh the page to show updated nutrition
    if (result == true) {
      // Reload the recipe details to show updated nutrition
      await _loadRecipeDetails();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isFavorite ? "Recipe" : "Meal"} updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addToMealPlan() async {
    print('DEBUG: ===== _addToMealPlan CALLED =====');
    print('DEBUG: Button pressed, starting meal plan addition process');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('DEBUG: No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add meals to your plan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final recipe = _recipeDetails ?? widget.recipe;
      print('DEBUG: Using recipe: ${recipe['title']}');
      
      // Check for allergens first
      final allergenResult = await AllergenDetectionService.getDetailedAnalysis(recipe);
      final hasAllergens = allergenResult['hasAllergens'] == true;
      final detectedAllergens = List<String>.from(allergenResult['detectedAllergens'] ?? []);
      
      Map<String, dynamic> finalRecipe = recipe;
      
      if (hasAllergens) {
        // Get substitution suggestions
        final substitutionSuggestions = <String>[];
        for (final allergen in detectedAllergens) {
          // Convert display name to allergen type
          String allergenType = allergen.toLowerCase().replaceAll(' ', '_');
          if (allergen == 'Eggs') allergenType = 'eggs';
          if (allergen == 'Dairy') allergenType = 'dairy';
          if (allergen == 'Fish') allergenType = 'fish';
          if (allergen == 'Shellfish') allergenType = 'shellfish';
          if (allergen == 'Tree Nuts') allergenType = 'tree_nuts';
          if (allergen == 'Peanuts') allergenType = 'peanuts';
          if (allergen == 'Wheat/Gluten') allergenType = 'wheat';
          if (allergen == 'Soy') allergenType = 'soy';
          
          final suggestions = await AllergenService.getSubstitutions(allergenType);
          substitutionSuggestions.addAll(suggestions);
        }
        
        // Show allergen warning dialog with substitution options
        String? warningResult;
        await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AllergenWarningDialog(
            recipe: recipe,
            detectedAllergens: detectedAllergens,
            substitutionSuggestions: substitutionSuggestions,
            riskLevel: 'High', // Default risk level
            onContinue: () {
              Navigator.of(context).pop('continue'); // Return continue signal
            },
            onSubstitute: () {
              Navigator.of(context).pop('substitute'); // Return substitute signal
            },
          ),
        ).then((result) {
          warningResult = result;
        });
        
        if (warningResult == 'continue') {
          // User chose to continue with original recipe
          print('DEBUG: User chose to continue with original recipe');
          finalRecipe = Map<String, dynamic>.from(recipe);
          // Add allergen information to the recipe
          finalRecipe['hasAllergens'] = hasAllergens;
          finalRecipe['detectedAllergens'] = detectedAllergens;
          print('DEBUG: Added allergen info to finalRecipe - hasAllergens: $hasAllergens, detectedAllergens: $detectedAllergens');
        } else if (warningResult == 'substitute') {
          // User chose to substitute, show substitution dialog
          print('DEBUG: User chose to substitute, showing substitution dialog');
          final substitutionResult = await SubstitutionDialogHelper.showSubstitutionDialog(
            context,
            recipe,
            detectedAllergens,
          );
          
          if (substitutionResult != null) {
            print('DEBUG: Substitution completed, using substituted recipe');
            finalRecipe = substitutionResult;
          } else {
            print('DEBUG: User cancelled substitution');
            return; // User cancelled substitution
          }
        } else {
          print('DEBUG: User cancelled allergen warning dialog');
          return; // User cancelled
        }
      }

      // Show dialog to select date and meal type
      print('DEBUG: Showing MealPlanDialog');
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const MealPlanDialog(),
      );
      print('DEBUG: MealPlanDialog closed, result: $result');
      
      if (result == null) {
        print('DEBUG: User cancelled MealPlanDialog');
        return;
      }

        print('DEBUG: MealPlanDialog result: $result');
        try {
          print('DEBUG: Final recipe keys: ${finalRecipe.keys.toList()}');
          
          // Check if this is a substituted recipe or original recipe
          final isSubstituted = finalRecipe['substituted'] == true;
          print('DEBUG: Is substituted recipe: $isSubstituted');
          
          if (isSubstituted) {
            // For substituted recipes, use the existing nutrition and save with substitution data
            print('DEBUG: Saving substituted recipe with existing nutrition');
            await _saveSubstitutedMeal(finalRecipe, result);
          } else {
            // For original recipes, use the existing nutrition values (don't recalculate)
            print('DEBUG: Using original recipe nutrition without recalculation');
            final ingredients = _extractIngredients(finalRecipe);
            print('DEBUG: Extracted ingredients: ${ingredients.length} items');
            print('DEBUG: Ingredients list: $ingredients');
            
            // Use the original recipe's nutrition values
            final nutrition = finalRecipe['nutrition'] as Map<String, dynamic>? ?? {};
            print('DEBUG: Using original nutrition: $nutrition');

            print('DEBUG: Saving original recipe to Firestore with original nutrition');
            await _saveOriginalMeal(finalRecipe, result, ingredients, nutrition);
          }

        print('DEBUG: Meal saved successfully, showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(finalRecipe['substituted'] == true 
              ? 'Substituted recipe added to meal plan!' 
              : 'Recipe added to meal plan!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to meal planner to refresh the view
        print('DEBUG: Navigating back to meal planner to refresh');
        Navigator.pop(context, true); // Return true to indicate refresh needed
      } catch (e) {
        print('DEBUG: Error in meal saving: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error in _addToMealPlan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to meal plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _extractIngredients(Map<String, dynamic> recipe) {
    try {
      print('DEBUG: _extractIngredients called with recipe keys: ${recipe.keys.toList()}');
      print('DEBUG: extendedIngredients type: ${recipe['extendedIngredients']?.runtimeType}');
      print('DEBUG: ingredients type: ${recipe['ingredients']?.runtimeType}');
      
      // Try different ingredient formats
      if (recipe['extendedIngredients'] != null) {
        print('DEBUG: Processing extendedIngredients in _extractIngredients');
        final result = (recipe['extendedIngredients'] as List)
            .map((ing) {
              try {
                // Handle both object format (API recipes) and string format (substituted recipes)
                if (ing is Map<String, dynamic>) {
                  return ing['original']?.toString() ?? ing['name']?.toString() ?? '';
                } else {
                  return ing.toString();
                }
              } catch (e) {
                print('DEBUG: Error processing ingredient: $ing, error: $e');
                return ing.toString();
              }
            })
            .where((ing) => ing.isNotEmpty)
            .toList();
        print('DEBUG: ExtendedIngredients result: $result');
        return result;
      } else if (recipe['ingredients'] != null) {
        print('DEBUG: Processing regular ingredients in _extractIngredients');
        final ingredients = recipe['ingredients'];
        print('DEBUG: Raw ingredients: $ingredients');
        
        if (ingredients is List) {
          final result = ingredients
              .map((ing) {
                // Handle both string format and object format
                if (ing is Map<String, dynamic>) {
                  // Object format from Enhanced Recipe Dialog
                  final amount = ing['amount']?.toString() ?? '1';
                  final unit = ing['unit']?.toString() ?? '';
                  final name = ing['name']?.toString() ?? '';
                  
                  // Use original field if available, otherwise construct it
                  return ing['original']?.toString() ?? 
                         '$amount $unit $name'.trim();
                } else {
                  // String format
                  return ing.toString();
                }
              })
              .where((ing) => ing.isNotEmpty)
              .toList();
          print('DEBUG: Ingredients result: $result');
          return result;
        } else {
          print('DEBUG: Ingredients is not a list, type: ${ingredients.runtimeType}');
          final result = [ingredients.toString()];
          print('DEBUG: Non-list ingredients result: $result');
          return result;
        }
      }
    } catch (e) {
      print('DEBUG: Error in _extractIngredients: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
    }
    print('DEBUG: No ingredients found, returning empty list');
    return [];
  }

  String _extractInstructions(Map<String, dynamic> recipe) {
    try {
      if (recipe['instructions'] != null) {
        if (recipe['instructions'] is List) {
          return (recipe['instructions'] as List)
              .map((inst) => inst.toString())
              .join('\n');
        }
        return recipe['instructions'].toString();
      } else if (recipe['analyzedInstructions'] != null) {
        final instructions = recipe['analyzedInstructions'];
        if (instructions is List && instructions.isNotEmpty) {
          final firstInstruction = instructions[0];
          if (firstInstruction is Map && firstInstruction['steps'] != null) {
            final steps = firstInstruction['steps'] as List? ?? [];
            return steps
                .map((step) => step['step']?.toString() ?? '')
                .where((step) => step.isNotEmpty)
                .join('\n');
          }
        }
      }
      return '';
    } catch (e) {
      print('DEBUG: Error in _extractInstructions: $e');
      return '';
    }
  }

  /// Save original meal with all its data to Firestore (no nutrition recalculation)
  Future<void> _saveOriginalMeal(Map<String, dynamic> recipe, Map<String, dynamic> mealPlanData, List<String> ingredients, Map<String, dynamic> nutrition) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('DEBUG: Saving original meal with complete data');
      print('DEBUG: Recipe keys: ${recipe.keys.toList()}');
      print('DEBUG: Recipe summary: ${recipe['summary']}');
      print('DEBUG: Recipe description: ${recipe['description']}');
      print('DEBUG: Recipe nutrition: $nutrition');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .add({
        'title': recipe['title'] ?? 'Recipe',
        'date': mealPlanData['date'],
        'mealType': mealPlanData['mealType'],
        'meal_type': mealPlanData['mealType'],
        'ingredients': ingredients,
        'extendedIngredients': recipe['extendedIngredients'],
        'instructions': recipe['instructions'] ?? '',
        'nutrition': nutrition,
        'image': recipe['image'],
        'summary': recipe['summary'],
        'description': recipe['description'],
        'cuisine': recipe['cuisine'],
        'substituted': false,
        'hasAllergens': recipe['hasAllergens'] ?? false,
        'detectedAllergens': recipe['detectedAllergens'] ?? [],
        'recipeId': recipe['recipeId'] ?? recipe['id'],
        'source': recipe['source'] ?? 'meal_planner',
        'created_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: Original meal saved successfully');
    } catch (e) {
      print('DEBUG: Error saving original meal: $e');
      rethrow;
    }
  }

  /// Save substituted meal with all its data to Firestore
  Future<void> _saveSubstitutedMeal(Map<String, dynamic> recipe, Map<String, dynamic> mealPlanData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('DEBUG: Saving substituted meal with complete data');
      print('DEBUG: Recipe keys: ${recipe.keys.toList()}');
      print('DEBUG: Recipe summary: ${recipe['summary']}');
      print('DEBUG: Recipe description: ${recipe['description']}');
      print('DEBUG: Recipe nutrition: ${recipe['nutrition']}');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .add({
        'title': recipe['title'] ?? 'Recipe',
        'date': mealPlanData['date'],
        'mealType': mealPlanData['mealType'],
        'meal_type': mealPlanData['mealType'],
        'ingredients': recipe['ingredients'] ?? [],
        'extendedIngredients': recipe['extendedIngredients'],
        'instructions': recipe['instructions'] ?? '',
        'nutrition': recipe['nutrition'] ?? {},
        'originalNutrition': recipe['originalNutrition'],
        'image': recipe['image'],
        'summary': recipe['summary'],
        'description': recipe['description'],
        'cuisine': recipe['cuisine'],
        'substituted': true,
        'substitutions': recipe['substitutions'],
        'hasAllergens': recipe['hasAllergens'] ?? false,
        'detectedAllergens': recipe['detectedAllergens'] ?? [],
        'originalAllergens': recipe['originalAllergens'] ?? [],
        'recipeId': recipe['recipeId'] ?? recipe['id'],
        'source': recipe['source'] ?? 'meal_planner',
        'created_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: Substituted meal saved successfully');
    } catch (e) {
      print('DEBUG: Error saving substituted meal: $e');
      rethrow;
    }
  }

  /// Update the meal in Firestore with the latest nutrition data
  Future<void> _updateMealInFirestore(Map<String, dynamic> recipe) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final mealId = recipe['id'];
      if (mealId == null) return;
      
      // Update the meal document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .doc(mealId)
          .update({
        'nutrition': recipe['nutrition'],
        'originalNutrition': recipe['originalNutrition'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: Successfully updated meal $mealId in Firestore');
    } catch (e) {
      print('DEBUG: Error updating meal in Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValidated = widget.recipe['nutritionValidated'] == true;
    final validatedBy = widget.recipe['validatedBy'];
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.recipe['title'] ?? 'Recipe Details',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isValidated) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Validated by ${validatedBy ?? "Nutritionist"}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (!_isCheckingFavorite && widget.recipe['id'] != null)
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : Colors.white,
              ),
              tooltip: _isFavorited ? 'Remove from favorites' : 'Add to favorites',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadRecipeDetails();
              },
              child: _safelyBuildRecipeDetails(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('DEBUG: ===== FLOATING ACTION BUTTON PRESSED =====');
          _addToMealPlan();
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add to Meal Plan'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _safelyBuildSection(String sectionName, Widget Function() builder) {
    try {
      print('DEBUG: Building $sectionName section');
      return builder();
    } catch (e, stackTrace) {
      print('DEBUG: Error in $sectionName section: $e');
      print('DEBUG: Stack trace: $stackTrace');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('Error in $sectionName section: $e', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            Text('Stack: ${stackTrace.toString().split('\n').first}', 
                 style: const TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ),
      );
    }
  }

  Widget _safelyBuildRecipeDetails() {
    try {
      print('DEBUG: Entering _safelyBuildRecipeDetails');
      return _buildRecipeDetails();
    } catch (e, stackTrace) {
      print('DEBUG: Error in _safelyBuildRecipeDetails: $e');
      print('DEBUG: Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading recipe details: $e'),
            const SizedBox(height: 8),
            Text('Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}', 
                 style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRecipeDetails() {
    print('DEBUG: Starting _buildRecipeDetails');
    if (_recipeDetails == null) {
      print('DEBUG: _recipeDetails is null');
      return const Center(child: Text('No details available'));
    }

    final details = _recipeDetails!;
    print('DEBUG: Recipe details available, keys: ${details.keys.toList()}');

    // Kick off ML allergen detection once details are present
    if (_mlAllergens == null && !_isLoading && !_isRunningML && _mlStatus == 'ML: not started') {
      print('DEBUG: Running ML allergen detection');
      _runAllergenML();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe Image
          if (details['image'] != null &&
              details['image'].toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 250,
              child: _buildRecipeImage(details['image']),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe Title
                Text(
                  details['title'] ?? 'No Title',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),

                // Recipe Summary/Description
                if (details['summary'] != null || details['description'] != null)
                  Builder(
                    builder: (context) {
                      final summaryText = _stripHtmlTags(details['summary'] ?? details['description'] ?? '');
                      print('DEBUG: Displaying summary/description: $summaryText');
                      return Text(
                        summaryText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    },
                  )
                else
                  Builder(
                    builder: (context) {
                      print('DEBUG: No summary or description found - summary: ${details['summary']}, description: ${details['description']}');
                      return const SizedBox.shrink();
                    },
                  ),

                const SizedBox(height: 24),

                // Allergen Information
                _safelyBuildSection('Allergen', () => _buildAllergenSection(details)),

                const SizedBox(height: 24),

                // Nutrition Information
                _safelyBuildSection('Nutrition', () => _buildNutritionSection(_ensureNutritionData(details))),

                const SizedBox(height: 16),

                // Edit Meal Button (for both planned meals and favorite meals)
                if ((widget.recipe['id'] != null && widget.recipe['date'] != null) || 
                    widget.recipe['docId'] != null)
                  _safelyBuildSection('Edit Meal', () => _buildEditMealButton()),

                const SizedBox(height: 24),

                // Ingredients Section
                _safelyBuildSection('Ingredients', () => _buildIngredientsSection(details)),

                const SizedBox(height: 24),

                // Instructions Section
                _safelyBuildSection('Instructions', () => _buildInstructionsSection(details)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ensure nutrition data exists for all recipes, estimate if missing
  Map<String, dynamic> _ensureNutritionData(Map<String, dynamic> details) {
    print('DEBUG: _ensureNutritionData called for recipe: ${details['title']}');
    print('DEBUG: Available keys: ${details.keys.toList()}');
    print('DEBUG: Nutrition field: ${details['nutrition']}');
    
    // If nutrition data already exists and is not empty, return it
    if (details['nutrition'] != null && details['nutrition'] is Map<String, dynamic>) {
      final nutrition = details['nutrition'] as Map<String, dynamic>;
      if (nutrition.isNotEmpty) {
        print('DEBUG: Found existing nutrition data');
        return nutrition;
      } else {
        print('DEBUG: Nutrition field exists but is empty');
      }
    }
    
    // If no nutrition data, estimate based on title and ingredients
    print('DEBUG: No nutrition data found, estimating...');
    final title = details['title']?.toString() ?? '';
    final ingredients = _extractIngredientsText(details);
    
    final estimated = _estimateNutritionFromRecipe(title, ingredients);
    print('DEBUG: Estimated nutrition: $estimated');
    return estimated;
  }

  /// Extract ingredients text from recipe details
  String _extractIngredientsText(Map<String, dynamic> details) {
    try {
      print('DEBUG: _extractIngredientsText called with details keys: ${details.keys.toList()}');
      print('DEBUG: extendedIngredients type: ${details['extendedIngredients']?.runtimeType}');
      print('DEBUG: ingredients type: ${details['ingredients']?.runtimeType}');
      
      if (details['extendedIngredients'] != null) {
        print('DEBUG: Processing extendedIngredients');
        final ingredients = details['extendedIngredients'] as List<dynamic>;
        final result = ingredients.map((ing) {
          try {
            // Handle both object format (API recipes) and string format (substituted recipes)
            if (ing is Map<String, dynamic>) {
              return ing['name']?.toString() ?? '';
            } else {
              return ing.toString();
            }
          } catch (e) {
            print('DEBUG: Error processing ingredient in extendedIngredients: $ing, error: $e');
            return '';
          }
        }).join(' ');
        print('DEBUG: ExtendedIngredients result: $result');
        return result;
      } else if (details['ingredients'] != null) {
        print('DEBUG: Processing regular ingredients');
        final ingredients = details['ingredients'];
        print('DEBUG: Raw ingredients: $ingredients');
        
        // Handle different ingredient formats safely
        if (ingredients is List) {
          if (ingredients.isEmpty) {
            print('DEBUG: Ingredients list is empty, returning empty string');
            return '';
          }
          final result = ingredients.map((ing) => ing.toString()).join(' ');
          print('DEBUG: Ingredients result: $result');
          return result;
        } else {
          print('DEBUG: Ingredients is not a list, type: ${ingredients.runtimeType}');
          final result = ingredients.toString();
          print('DEBUG: Non-list ingredients result: $result');
          return result;
        }
      }
      print('DEBUG: No ingredients found, returning empty string');
      return '';
    } catch (e) {
      print('DEBUG: Error in _extractIngredientsText: $e');
      print('DEBUG: Stack trace: ${StackTrace.current}');
      return '';
    }
  }

  /// Estimate nutrition information from recipe title and ingredients
  Map<String, dynamic> _estimateNutritionFromRecipe(String title, String ingredients) {
    double calories = 350; // Base calories
    double protein = 18;   // Base protein
    double carbs = 40;     // Base carbs
    double fat = 14;       // Base fat
    
    final titleLower = title.toLowerCase();
    final ingredientsLower = ingredients.toLowerCase();
    
    // Adjust based on recipe type
    if (titleLower.contains('salad') || titleLower.contains('vegetable')) {
      calories = 180; protein = 8; carbs = 25; fat = 6;
    } else if (titleLower.contains('chicken')) {
      calories = 380; protein = 35; carbs = 20; fat = 16;
    } else if (titleLower.contains('beef') || titleLower.contains('bbq')) {
      calories = 450; protein = 40; carbs = 15; fat = 25;
    } else if (titleLower.contains('fish') || titleLower.contains('salmon')) {
      calories = 320; protein = 30; carbs = 18; fat = 14;
    } else if (titleLower.contains('pasta') || titleLower.contains('noodle')) {
      calories = 420; protein = 15; carbs = 65; fat = 12;
    } else if (titleLower.contains('soup')) {
      calories = 220; protein = 12; carbs = 28; fat = 8;
    } else if (titleLower.contains('rice') || titleLower.contains('champorado')) {
      calories = 380; protein = 12; carbs = 68; fat = 8;
    }
    
    // Adjust based on ingredients
    if (ingredientsLower.contains('cheese') || ingredientsLower.contains('milk')) {
      calories += 50; protein += 6; fat += 5;
    }
    if (ingredientsLower.contains('oil') || ingredientsLower.contains('butter')) {
      calories += 60; fat += 8;
    }
    if (ingredientsLower.contains('sugar') || ingredientsLower.contains('honey')) {
      calories += 50; carbs += 12;
    }
    
    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fat': fat.round(),
      'fiber': (calories * 0.02).round(),
      'sugar': (carbs * 0.3).round(),
      'sodium': (calories * 2).round(),
    };
  }

  Widget _buildNutritionSection(Map<String, dynamic> nutrition) {
    // Handle both API recipes (nutrients array) and local recipes (direct nutrition values)
    List<dynamic>? nutrients;
    
    if (nutrition['nutrients'] != null) {
      // API recipe format
      nutrients = nutrition['nutrients'] as List<dynamic>?;
    } else {
      // Local recipe format - convert to API-like format
      nutrients = [
        {'name': 'Calories', 'amount': nutrition['calories'], 'unit': 'cal'},
        {'name': 'Protein', 'amount': nutrition['protein'], 'unit': 'g'},
        {'name': 'Carbohydrates', 'amount': nutrition['carbs'], 'unit': 'g'},
        {'name': 'Fat', 'amount': nutrition['fat'], 'unit': 'g'},
        {'name': 'Fiber', 'amount': nutrition['fiber'], 'unit': 'g'},
      ].where((nutrient) => nutrient['amount'] != null && nutrient['amount'] > 0).toList();
    }
    
    print('DEBUG: _buildNutritionSection - nutrients: $nutrients');
    
    if (nutrients == null || nutrients.isEmpty) {
      print('DEBUG: No nutrients found, showing placeholder nutrition section');
      // Show a basic nutrition section with estimated values
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nutrition Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Nutrition data not available for this recipe.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_food_beverage, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Nutrition Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Nutrition Cards Grid
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: nutrients.take(6).map((nutrient) {
                final amount = nutrient['amount'];
                String amountText = '';

                if (amount != null) {
                  if (amount is num) {
                    amountText = amount.toStringAsFixed(1);
                  } else {
                    amountText = amount.toString();
                  }
                }

                return _buildNutritionCard(nutrient, amountText);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(Map<String, dynamic> nutrient, String amountText) {
    final name = nutrient['name']?.toString().toLowerCase() ?? '';
    final unit = nutrient['unit']?.toString() ?? '';
    
    // Get icon and color based on nutrient type
    IconData icon;
    Color color;
    
    if (name.contains('calorie')) {
      icon = Icons.local_fire_department;
      color = Colors.red;
    } else if (name.contains('protein')) {
      icon = Icons.fitness_center;
      color = Colors.blue;
    } else if (name.contains('carbohydrate') || name.contains('carb')) {
      icon = Icons.grain;
      color = Colors.orange;
    } else if (name.contains('fat')) {
      icon = Icons.opacity;
      color = Colors.yellow[700]!;
    } else if (name.contains('fiber')) {
      icon = Icons.eco;
      color = Colors.green;
    } else {
      icon = Icons.info;
      color = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                amountText.isNotEmpty ? amountText : '0.0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              nutrient['name'] ?? '',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMealButton() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Edit This Meal',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customize the ingredients and instructions for this meal to match your preferences. Nutrition values will update in real-time.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _editMeal,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Meal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(Map<String, dynamic> details) {
    // Handle both API recipes (extendedIngredients) and local recipes (ingredients)
    List<dynamic>? ingredients;
    
    print('DEBUG: _buildIngredientsSection - Recipe: ${details['title']}');
    print('DEBUG: extendedIngredients type: ${details['extendedIngredients']?.runtimeType}');
    print('DEBUG: ingredients type: ${details['ingredients']?.runtimeType}');
    print('DEBUG: ingredients content: ${details['ingredients']}');
    
    if (details['extendedIngredients'] != null) {
      // API recipe format - convert to simple format like local recipes
      final extendedIngredients = details['extendedIngredients'];
      if (extendedIngredients is List) {
        print('DEBUG: Processing extendedIngredients with ${extendedIngredients.length} items');
        ingredients = extendedIngredients.map((ingredient) {
          print('DEBUG: Processing API ingredient: $ingredient (type: ${ingredient.runtimeType})');
          
          if (ingredient is Map) {
            // Convert API format to simple format like local recipes
            String name = '';
            String original = '';
            
            // Handle name field - it might be a string or a Map
            if (ingredient['name'] is Map) {
              // If name is a Map, it might contain the entire ingredient object
              final nameMap = ingredient['name'] as Map;
              print('DEBUG: name is a Map with keys: ${nameMap.keys.toList()}');
              
              // Check if this Map has a 'name' field (nested ingredient)
              if (nameMap.containsKey('name') && nameMap['name'] is String) {
                name = nameMap['name'].toString();
                print('DEBUG: Extracted nested name: $name');
              } else if (nameMap.containsKey('name') && nameMap['name'] is Map) {
                // If name field is also a Map, extract the string from it
                final nestedNameMap = nameMap['name'] as Map;
                name = nestedNameMap['name']?.toString() ?? '';
                print('DEBUG: Extracted deeply nested name: $name');
              } else {
                // If no nested name, use the Map as string (fallback)
                name = nameMap.toString();
                print('DEBUG: Using Map as string: $name');
              }
            } else {
              // Name is a string - ensure we only get the string value
              name = ingredient['name']?.toString() ?? '';
              print('DEBUG: Using name as string: $name');
            }
            
            // CRITICAL FIX: If name is still a Map (toString() of Map), extract the actual name
            if (name.startsWith('{') && name.contains('name:')) {
              print('DEBUG: name is still a Map string, extracting actual name');
              // Extract the name from the Map string using regex
              final nameMatch = RegExp(r'name:\s*([^,}]+)').firstMatch(name);
              if (nameMatch != null) {
                name = nameMatch.group(1)?.trim() ?? name;
                print('DEBUG: Extracted name from Map string: $name');
              }
            }
            
            // ULTIMATE FIX: If name is still a Map object (not string), extract directly
            if (ingredient['name'] is Map) {
              final nameMap = ingredient['name'] as Map;
              // Try to get the actual name from the Map
              if (nameMap.containsKey('name') && nameMap['name'] is String) {
                name = nameMap['name'].toString();
                print('DEBUG: ULTIMATE FIX - Extracted name from Map: $name');
              } else {
                // If no 'name' field, try to get the first string value
                for (var key in nameMap.keys) {
                  if (nameMap[key] is String && nameMap[key].toString().isNotEmpty) {
                    name = nameMap[key].toString();
                    print('DEBUG: ULTIMATE FIX - Using first string value: $name');
                    break;
                  }
                }
              }
            }
            
            // FINAL SAFETY CHECK: Ensure name is always a string, not an object
            if (name is Map) {
              print('DEBUG: ERROR - name is still a Map object, converting to string');
              name = name.toString();
            }
            
            // Handle original field - it might be a string or a Map
            if (ingredient['original'] is Map) {
              // If original is a Map, extract the actual original
              final originalMap = ingredient['original'] as Map;
              original = originalMap['original']?.toString() ?? '';
              print('DEBUG: Extracted original from Map: $original');
            } else {
              original = ingredient['original']?.toString() ?? '';
              print('DEBUG: Using original as string: $original');
            }
            
            print('DEBUG: Final name value: $name (type: ${name.runtimeType})');
            print('DEBUG: Final original value: $original (type: ${original.runtimeType})');
            
            return {
              'amount': _safeDouble(ingredient['amount']) ?? 1.0,
              'unit': ingredient['unit']?.toString() ?? '',
              'name': name,
              'original': original,
              'substituted': ingredient['substituted'] ?? false,
            };
          } else {
            // Fallback for non-object ingredients
            return {
              'amount': 1.0,
              'unit': '',
              'name': ingredient.toString(),
              'original': ingredient.toString(),
              'substituted': false,
            };
          }
        }).toList();
        print('DEBUG: Converted API ingredients: $ingredients');
      }
    } else if (details['ingredients'] != null) {
      // Local recipe format - convert to API-like format
      final localIngredients = details['ingredients'];
      print('DEBUG: localIngredients type: ${localIngredients.runtimeType}');
      print('DEBUG: localIngredients content: $localIngredients');
      
      if (localIngredients is List) {
        print('DEBUG: Processing ingredients list with ${localIngredients.length} items');
        ingredients = localIngredients.map((ingredient) {
          print('DEBUG: Processing ingredient: $ingredient (type: ${ingredient.runtimeType})');
          
          // Handle both string format and object format
          if (ingredient is Map<String, dynamic>) {
            // Object format from Enhanced Recipe Dialog
            return {
              'amount': _safeDouble(ingredient['amount']) ?? 1.0,
              'amountDisplay': ingredient['amountDisplay']?.toString() ?? '', // preserve fractions
              'unit': ingredient['unit']?.toString() ?? '',
              'name': ingredient['name']?.toString() ?? '',
            };
          } else {
            // String format
            return {
              'amount': 1.0,
              'unit': '',
              'name': ingredient.toString(),
            };
          }
        }).toList();
        print('DEBUG: Converted ingredients: $ingredients');
      } else {
        print('DEBUG: localIngredients is not a List, it is: ${localIngredients.runtimeType}');
      }
    }
    
    if (ingredients == null || ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ingredients',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            ...ingredients.map((ingredient) {
              // Handle both object format (API recipes) and string format (manual meals)
              String ingredientText;
              if (ingredient is Map<String, dynamic>) {
                // API recipe format - check if this is a substituted ingredient first
                if (ingredient['substituted'] == true && ingredient['name'] != null && ingredient['name'].toString().isNotEmpty) {
                  // For substituted ingredients, use the 'name' field which contains substitution details
                  ingredientText = ingredient['name'].toString();
                } else if (ingredient['original'] != null && ingredient['original'].toString().isNotEmpty) {
                  // Use the 'original' field which contains clean text like "1 tablespoon chopped chives"
                  ingredientText = ingredient['original'].toString();
                } else if (ingredient['name'] != null && ingredient['name'].toString().isNotEmpty) {
                  // Fallback to 'name' field and format with amount/unit
                  // Use amountDisplay to preserve fractions, fallback to formatted amount
                  final amountDisplay = ingredient['amountDisplay']?.toString() ?? '';
                  final amount = amountDisplay.isNotEmpty ? amountDisplay : _formatAmount(ingredient['amount']);
                  final unit = ingredient['unit']?.toString() ?? '';
                  final name = ingredient['name'].toString();
                  
                  // Clean up the formatting
                  if (amount.isNotEmpty && unit.isNotEmpty) {
                    ingredientText = '$amount $unit $name';
                  } else if (amount.isNotEmpty) {
                    ingredientText = '$amount $name';
                  } else {
                    ingredientText = name;
                  }
                } else {
                  // Last resort - convert the whole object to string
                  ingredientText = ingredient.toString();
                }
              } else {
                // Manual meal format - just a string
                ingredientText = ingredient.toString();
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ingredientText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
              }),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection(Map<String, dynamic> details) {
    // Handle both API recipes (instructions) and local recipes (instructions)
    String? instructions;
    
    if (details['instructions'] != null) {
      instructions = details['instructions'] as String?;
    }
    
    if (instructions == null || instructions.isEmpty) {
      // For manually entered meals, show ingredients as instructions if no instructions
      if (details['ingredients'] != null && details['ingredients'] is List) {
        final ingredients = details['ingredients'] as List;
        if (ingredients.isNotEmpty) {
          instructions = 'Ingredients:\n${ingredients.map((ing) => '• $ing').join('\n')}';
        }
      }
      
    if (instructions == null || instructions.isEmpty) {
      return const SizedBox.shrink();
      }
    }

    // Split instructions into steps
    final cleanInstructions = _stripHtmlTags(instructions);
    final steps = _splitIntoSteps(cleanInstructions);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
              }),
            ],
          ),
        ),
        ],
      ),
    );
  }

  List<String> _splitIntoSteps(String instructions) {
    try {
    // Split by common step indicators
    final stepPatterns = [
      RegExp(r'\d+\.\s*', caseSensitive: false), // "1. ", "2. ", etc.
      RegExp(
        r'step\s*\d+[:\s]*',
        caseSensitive: false,
      ), // "Step 1:", "step 1:", etc.
      RegExp(r'^\s*[•·]\s*', caseSensitive: false), // Bullet points
    ];

    String processedInstructions = instructions;

    // Try to split by numbered steps first
    for (final pattern in stepPatterns) {
      if (pattern.hasMatch(processedInstructions)) {
        final parts = processedInstructions.split(pattern);
        if (parts.length > 1) {
          return parts.where((part) => part.trim().isNotEmpty).toList();
        }
      }
    }

    // If no clear step indicators, split by sentences
    final sentences = processedInstructions.split(RegExp(r'[.!?]\s+'));
    return sentences.where((sentence) => sentence.trim().isNotEmpty).toList();
    } catch (e) {
      print('DEBUG: Error in _splitIntoSteps: $e');
      return [instructions]; // Return the original instructions as a single step
    }
  }

  Widget _buildRecipeImage(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      // Local asset image
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[50]!, Colors.green[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.green,
              ),
            ),
          );
        },
      );
    } else if (imagePath.startsWith('/') || imagePath.startsWith('file://') || imagePath.contains('/storage/') || imagePath.contains('/data/')) {
      // Local file image
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[50]!, Colors.green[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.green,
              ),
            ),
          );
        },
      );
    } else {
      // Network image with proper sizing to avoid memory issues
      return Image.network(
        imagePath,
        height: 250,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 500, // Limit cache size to reduce memory usage
        cacheHeight: 500,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[50]!, Colors.green[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.green,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: 250,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        },
      );
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '';

    if (amount is num) {
      return amount.toStringAsFixed(1);
    } else if (amount is String) {
      // Try to parse as number first
      final parsed = double.tryParse(amount);
      if (parsed != null) {
        return parsed.toStringAsFixed(1);
      }
      return amount;
    } else {
      return amount.toString();
    }
  }

  double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildAllergenSection(Map<String, dynamic> details) {
  // Handle both API recipes (extendedIngredients) and local recipes (ingredients)
  List<dynamic>? ingredients;

  print('DEBUG: _buildAllergenSection - Recipe: ${details['title']}');
  print('DEBUG: extendedIngredients type: ${details['extendedIngredients']?.runtimeType}');
  print('DEBUG: ingredients type: ${details['ingredients']?.runtimeType}');
  print('DEBUG: ingredients content: ${details['ingredients']}');

  if (details['extendedIngredients'] != null) {
    // API recipe format - prioritize extendedIngredients
    final extendedIngredients = details['extendedIngredients'];
    if (extendedIngredients is List && extendedIngredients.isNotEmpty) {
      ingredients = extendedIngredients;
      print('DEBUG: Using extendedIngredients for allergen check, count: ${ingredients.length}');
    }
  }

  // Only use ingredients if extendedIngredients is not available or empty
  if ((ingredients == null || ingredients.isEmpty) && details['ingredients'] != null) {
    // Local recipe format - convert to API-like format
    final localIngredients = details['ingredients'];
    print('DEBUG: localIngredients type: ${localIngredients.runtimeType}');
    print('DEBUG: localIngredients content: $localIngredients');

    if (localIngredients is List && localIngredients.isNotEmpty) {
      print('DEBUG: Processing ingredients list for allergen check with ${localIngredients.length} items');
      ingredients = localIngredients.map((ingredient) {
        print('DEBUG: Processing ingredient for allergen check: $ingredient (type: ${ingredient.runtimeType})');

        // Handle both string format and object format
        if (ingredient is Map<String, dynamic>) {
          // Object format from Enhanced Recipe Dialog
          return {
            'amount': _safeDouble(ingredient['amount']) ?? 1.0,
            'unit': ingredient['unit']?.toString() ?? '',
            'name': ingredient['name']?.toString() ?? '',
          };
        } else {
          // String format
          return {
            'amount': 1.0,
            'unit': '',
            'name': ingredient.toString(),
          };
        }
      }).toList();
      print('DEBUG: Converted ingredients for allergen check: $ingredients');
    } else {
      print('DEBUG: localIngredients is not a List for allergen check, it is: ${localIngredients.runtimeType}');
    }
  }

  if (ingredients == null || ingredients.isEmpty) {
    return const SizedBox.shrink();
  }

  print('DEBUG: Calling AllergenService.checkAllergens with ingredients: $ingredients');
  final allergens = AllergenService.checkAllergens(ingredients);
  print('DEBUG: AllergenService.checkAllergens result: $allergens');

  final allergenCount = allergens.values.fold(
    0,
    (sum, list) => sum + list.length,
  );
  print('DEBUG: Allergen count: $allergenCount');

  final riskLevel = AllergenService.getRiskLevel(allergenCount);
  print('DEBUG: Risk level: $riskLevel');

  final riskColor = Color(AllergenService.getRiskColor(riskLevel));
  print('DEBUG: Risk color: $riskColor');

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green[50]!, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Allergen Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  riskLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allergens.isEmpty && (_mlAllergens == null || _mlAllergens!.values.every((v) => v == 0)))
                const Text(
                  'No common allergens detected in this recipe.',
                  style: TextStyle(
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                Text(
                  'This recipe contains the following allergens:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (_mlStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.memory, size: 14, color: Color(0xFF888888)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _mlStatus!,
                            style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_mlAllergens != null &&
                    _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _mlAllergens!.entries
                          .where((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty)
                          .map((e) => Chip(
                                backgroundColor: Colors.red[50],
                                label: Text('${e.key} (ML)', style: const TextStyle(color: Colors.red)),
                              ))
                          .toList(),
                    ),
                  ),
                if (_mlAllergens != null &&
                    _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
                  ..._mlAllergens!.entries
                      .where((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty)
                      .map((e) {
                    final matches = _findMlMatches(e.key, _mlSourceText);
                    return Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Text(
                        'Reason (ML): found ${matches.join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    );
                  }),
                ...allergens.entries.map((entry) {
                  final allergenType = entry.key;
                  final ingredients = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              AllergenService.getAllergenIcon(allergenType),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AllergenService.getDisplayName(allergenType),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(
                            'Found in: ${ingredients.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: FutureBuilder<List<String>>(
                            future: AllergenService.getSubstitutions(allergenType),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final substitutions = snapshot.data!;
                                return Text(
                                  'Substitutions: ${substitutions.take(2).join(', ')}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.green[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                );
                              }
                              return Text(
                                'Substitutions: Loading...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
  String _stripHtmlTags(String htmlText) {
    try {
    // Simple HTML tag removal - you might want to use a proper HTML parser
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    } catch (e) {
      print('DEBUG: Error in _stripHtmlTags: $e');
      return htmlText; // Return original text if there's an error
    }
  }
}
