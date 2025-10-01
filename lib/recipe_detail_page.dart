import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/allergen_ml_service.dart';
import 'services/allergen_service.dart';
import 'services/allergen_detection_service.dart';
import 'services/nutrition_service.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'meal_favorites_page.dart';
import 'meal_plan_dialog.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/ingredient_substitution_dialog.dart';

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
      
      // Check if this is a local recipe or API recipe
      final recipeId = widget.recipe['id'];
      
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
      print('DEBUG: Recipe source: $source, recipeId: $recipeId');
      
      if (recipeId.toString().startsWith('local_') || 
          source == 'manual_entry' ||
          source == 'manual entry' ||
          source == 'meal_planner' ||
          source == 'local' ||
          widget.recipe['substituted'] == true) {
        // This is a local recipe, manually entered meal, substituted recipe, or meal from planner - use the data directly
        print('DEBUG: Local/manual/substituted/meal_planner recipe, using data directly');
        setState(() {
          _recipeDetails = widget.recipe;
          _isLoading = false;
        });
        return;
      }
      
      // Try Filipino Recipe Service first for Filipino recipes
      Map<String, dynamic>? details;
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
      
      print('DEBUG: Recipe details loaded successfully');
      setState(() {
        _recipeDetails = details;
        _isLoading = false;
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
      
      final text = (title + ' ' + ingredients).trim();
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
      print('ML allergens for "$title": ' + labels.toString());
      if (mounted) {
        setState(() {
          _mlAllergens = labels;
          _mlSourceText = text;
          _isRunningML = false;
          
          // Safely process scores with null checks
          if (result.scores != null) {
            final positives = result.scores.entries
                .where((e) => e.value == 1)
                .where((e) => _findMlMatches(e.key, text).isNotEmpty)
                .map((e) => '${e.key} ${(result.scores?[e.key] ?? 0).toStringAsFixed(2)}')
                .toList();
            _mlStatus = positives.isEmpty ? 'ML: no positives' : 'ML: ' + positives.join(', ');
          } else {
            _mlStatus = 'ML: no data';
          }
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('ML error: ' + e.toString());
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

  Future<void> _addToMealPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
      
      // Check for allergens first
      final allergenResult = await AllergenDetectionService.getDetailedAnalysis(recipe);
      final hasAllergens = allergenResult['hasAllergens'] == true;
      final detectedAllergens = List<String>.from(allergenResult['detectedAllergens'] ?? []);
      
      Map<String, dynamic> finalRecipe = recipe;
      
      if (hasAllergens) {
        // Get substitution suggestions
        final substitutionSuggestions = <String>[];
        for (final allergen in detectedAllergens) {
          final suggestions = AllergenService.getSubstitutions(allergen);
          substitutionSuggestions.addAll(suggestions);
        }
        
        // Show allergen warning dialog with substitution options
        final warningResult = await showDialog<String>(
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
        );
        
        if (warningResult == 'continue') {
          // User chose to continue with original recipe
          finalRecipe = recipe;
        } else if (warningResult == 'substitute') {
          // User chose to substitute, show substitution dialog
          final substitutionResult = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (context) => IngredientSubstitutionDialog(
              recipe: recipe,
              detectedAllergens: detectedAllergens,
            ),
          );
          
          if (substitutionResult != null) {
            finalRecipe = substitutionResult;
          } else {
            return; // User cancelled substitution
          }
        } else {
          return; // User cancelled
        }
      }

      // Show dialog to select date and meal type
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const MealPlanDialog(),
      );

      if (result != null) {
        try {
          final ingredients = _extractIngredients(finalRecipe);
          
          // Calculate nutrition from ingredients
          final nutrition = NutritionService.calculateRecipeNutrition(ingredients);

          await NutritionService.saveMealWithNutrition(
            title: finalRecipe['title'] ?? 'Recipe',
            date: result['date'],
            mealType: result['mealType'],
            ingredients: ingredients,
            instructions: _extractInstructions(finalRecipe),
            customNutrition: nutrition,
            image: finalRecipe['image'],
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(finalRecipe['substituted'] == true 
                ? 'Substituted recipe added to meal plan!' 
                : 'Recipe added to meal plan!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding to meal plan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _addToMealPlan: $e');
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
              .map((ing) => ing.toString())
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe['title'] ?? 'Recipe Details'),
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
          : _safelyBuildRecipeDetails(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addToMealPlan,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add to Meal Plan'),
      ),
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

                // Recipe Summary
                if (details['summary'] != null)
                  Text(
                    _stripHtmlTags(details['summary']),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                const SizedBox(height: 24),

                // Allergen Information
                _safelyBuildSection('Allergen', () => _buildAllergenSection(details)),

                const SizedBox(height: 24),

                // Nutrition Information
                _safelyBuildSection('Nutrition', () => _buildNutritionSection(_ensureNutritionData(details))),

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
            Wrap(
              spacing: 12,
              runSpacing: 8,
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

                return Chip(
                  backgroundColor: Colors.green[50],
                  label: Text(
                    '${nutrient['name']}: $amountText${nutrient['unit'] ?? ''}',
                    style: TextStyle(color: Colors.green[800]),
                  ),
                );
              }).toList(),
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
      // API recipe format
      final extendedIngredients = details['extendedIngredients'];
      if (extendedIngredients is List) {
        ingredients = extendedIngredients;
        print('DEBUG: Using extendedIngredients, count: ${ingredients.length}');
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
          return {
            'amount': 1,
            'unit': '',
            'name': ingredient.toString(),
          };
        }).toList();
        print('DEBUG: Converted ingredients: $ingredients');
      } else {
        print('DEBUG: localIngredients is not a List, it is: ${localIngredients.runtimeType}');
      }
    }
    
    if (ingredients == null || ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            ...ingredients.map((ingredient) {
              // Handle both object format (API recipes) and string format (manual meals)
              String ingredientText;
              if (ingredient is Map<String, dynamic>) {
                // API recipe format with amount, unit, name
                ingredientText = '${_formatAmount(ingredient['amount'])} ${ingredient['unit'] ?? ''} ${ingredient['name'] ?? ''}';
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
          instructions = 'Ingredients:\n' + ingredients.map((ing) => '• $ing').join('\n');
        }
      }
      
    if (instructions == null || instructions.isEmpty) {
      return const SizedBox.shrink();
      }
    }

    // Split instructions into steps
    final cleanInstructions = _stripHtmlTags(instructions);
    final steps = _splitIntoSteps(cleanInstructions);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
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
    } else {
      // Network image
      return Image.network(
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
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
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

  Widget _buildAllergenSection(Map<String, dynamic> details) {
    // Handle both API recipes (extendedIngredients) and local recipes (ingredients)
    List<dynamic>? ingredients;
    
    print('DEBUG: _buildAllergenSection - Recipe: ${details['title']}');
    print('DEBUG: extendedIngredients type: ${details['extendedIngredients']?.runtimeType}');
    print('DEBUG: ingredients type: ${details['ingredients']?.runtimeType}');
    print('DEBUG: ingredients content: ${details['ingredients']}');
    
    if (details['extendedIngredients'] != null) {
      // API recipe format
      final extendedIngredients = details['extendedIngredients'];
      if (extendedIngredients is List) {
        ingredients = extendedIngredients;
        print('DEBUG: Using extendedIngredients for allergen check, count: ${ingredients.length}');
      }
    } else if (details['ingredients'] != null) {
      // Local recipe format - convert to API-like format
      final localIngredients = details['ingredients'];
      print('DEBUG: localIngredients type: ${localIngredients.runtimeType}');
      print('DEBUG: localIngredients content: $localIngredients');
      
      if (localIngredients is List) {
        print('DEBUG: Processing ingredients list for allergen check with ${localIngredients.length} items');
        ingredients = localIngredients.map((ingredient) {
          print('DEBUG: Processing ingredient for allergen check: $ingredient (type: ${ingredient.runtimeType})');
          return {
            'amount': 1,
            'unit': '',
            'name': ingredient.toString(),
          };
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Allergen Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
            const SizedBox(height: 12),
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
              if (_mlAllergens != null && _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
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
              if (_mlAllergens != null && _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
                ..._mlAllergens!.entries.where((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty).map((e) {
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
                }).toList(),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          'Substitutions: ${AllergenService.getSubstitutions(allergenType).take(2).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.green[600],
                                fontStyle: FontStyle.italic,
                              ),
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
