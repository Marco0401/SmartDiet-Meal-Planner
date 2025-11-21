import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredient_analysis_service.dart';

class AllergenDetectionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Common allergen keywords and their categories (all lowercase for case-insensitive matching)
  static const Map<String, List<String>> allergenKeywords = {
    'peanuts': ['peanut', 'peanuts', 'groundnut', 'groundnuts', 'arachis', 'peanut oil', 'peanut butter'],
    'tree_nuts': ['almond', 'almonds', 'walnut', 'walnuts', 'cashew', 'cashews', 'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'pecan', 'pecans', 'brazil nut', 'brazil nuts', 'macadamia', 'macadamias', 'pine nut', 'pine nuts'],
    'milk': ['milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'lactose', 'whey', 'casein', 'ghee', 'buttermilk', 'mozzarella', 'cheddar', 'parmesan', 'ricotta', 'cottage cheese', 'sour cream', 'heavy cream'],
    'eggs': ['egg', 'eggs', 'egg white', 'egg yolk', 'albumen', 'lecithin', 'mayonnaise', 'mayo', 'egg beaters', 'scrambled', 'fried egg', 'boiled egg'],
    'fish': ['fish', 'salmon', 'tuna', 'cod', 'halibut', 'sardine', 'anchovy', 'fish sauce', 'worcestershire', 'worcestershire sauce', 'bangus', 'milkfish', 'bangus (milkfish)', 'tilapia', 'lapu-lapu', 'galunggong', 'tamban', 'tulingan', 'mackerel', 'trout', 'bass'],
    'shellfish': ['shrimp', 'prawn', 'crab', 'lobster', 'scallop', 'mussel', 'oyster', 'clam', 'shellfish', 'crustacean', 'crawfish', 'crayfish'],
    'wheat': ['wheat', 'flour', 'bread', 'pasta', 'noodles', 'gluten', 'semolina', 'bulgur', 'couscous', 'seitan', 'all-purpose flour', 'wheat flour', 'whole wheat', 'breadcrumbs', 'croutons', 'pizza dough', 'pie crust', 'macaroni', 'spaghetti', 'linguine', 'fettuccine', 'penne', 'rigatoni', 'rotini', 'orzo', 'lasagna', 'ravioli', 'tortellini', 'gnocchi', 'biscuit', 'muffin', 'pancake', 'waffle', 'pretzel', 'crackers'],
    'soy': ['soy', 'soya', 'soybean', 'soybeans', 'tofu', 'tempeh', 'miso', 'soy sauce', 'tamari', 'edamame', 'soy milk', 'soy protein'],
    'sesame': ['sesame', 'sesame oil', 'sesame seeds', 'tahini', 'halva', 'sesame seed oil'],
  };

  // Map user allergen names to internal keys (case-insensitive)
  static String _normalizeAllergenKey(String allergen) {
    final normalized = allergen.toLowerCase().trim();
    // Map common variations to standard keys
    if (normalized.contains('wheat') || normalized.contains('gluten')) return 'wheat';
    if (normalized.contains('tree') && normalized.contains('nut')) return 'tree_nuts';
    return normalized.replaceAll(' ', '_');
  }

  // Ingredient substitution suggestions
  static const Map<String, List<String>> substitutions = {
    'peanuts': ['sunflower seeds', 'pumpkin seeds', 'almonds (if not allergic)', 'cashews (if not allergic)', 'sunflower butter'],
    'tree_nuts': ['seeds (sunflower, pumpkin)', 'oats', 'coconut flakes', 'dried fruit'],
    'milk': ['almond milk', 'oat milk', 'coconut milk', 'rice milk', 'soy milk (if not allergic)', 'dairy-free alternatives'],
    'eggs': ['flax eggs (1 tbsp ground flaxseed + 3 tbsp water)', 'chia eggs', 'applesauce', 'banana', 'commercial egg replacer'],
    'fish': ['chicken', 'tofu', 'beans', 'lentils', 'mushrooms', 'seaweed (if not allergic to iodine)'],
    'shellfish': ['chicken', 'fish (if not allergic)', 'tofu', 'mushrooms', 'jackfruit'],
    'wheat': ['rice flour', 'almond flour', 'coconut flour', 'oat flour', 'gluten-free flour blend', 'quinoa', 'rice'],
    'soy': ['coconut aminos', 'tamari (wheat-free soy sauce)', 'miso alternatives', 'tofu alternatives (chickpea tofu)'],
    'sesame': ['olive oil', 'coconut oil', 'sunflower oil', 'pumpkin seeds', 'hemp seeds'],
  };

  // Get user's allergens from account settings
  static Future<List<String>> getUserAllergens() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final allergies = List<String>.from(data?['allergies'] ?? []);
        // Remove 'None' if present
        allergies.removeWhere((allergy) => allergy.toLowerCase() == 'none');
        return allergies;
      }
      return [];
    } catch (e) {
      print('Error getting user allergens: $e');
      return [];
    }
  }

  // Detect allergens in a recipe
  static Future<Map<String, dynamic>> detectAllergensInRecipe(Map<String, dynamic> recipe) async {
    try {
      final userAllergens = await getUserAllergens();
      if (userAllergens.isEmpty) {
        return {
          'hasAllergens': false,
          'detectedAllergens': [],
          'safeToEat': true,
        };
      }

      final detectedAllergens = <String>[];
      
      // Handle both string and object ingredient formats
      List<String> ingredients = [];
      
      // Try extendedIngredients first (API recipes), then ingredients (manual recipes)
      if (recipe['extendedIngredients'] != null) {
        final rawIngredients = recipe['extendedIngredients'] as List<dynamic>;
        ingredients = rawIngredients.map((ingredient) {
          if (ingredient is Map<String, dynamic>) {
            return ingredient['name']?.toString() ?? ingredient['original']?.toString() ?? '';
          } else {
            return ingredient.toString();
          }
        }).where((ingredient) => ingredient.isNotEmpty).toList();
        print('DEBUG: AllergenDetectionService - Using extendedIngredients: ${ingredients.length} items');
      } else if (recipe['ingredients'] != null) {
        final rawIngredients = recipe['ingredients'] as List<dynamic>;
        ingredients = rawIngredients.map((ingredient) {
          if (ingredient is Map<String, dynamic>) {
            // Object format from Enhanced Recipe Dialog
            return ingredient['name']?.toString() ?? '';
          } else {
            // String format
            return ingredient.toString();
          }
        }).where((ingredient) => ingredient.isNotEmpty).toList();
        print('DEBUG: AllergenDetectionService - Using ingredients: ${ingredients.length} items');
      } else {
        print('DEBUG: AllergenDetectionService - No ingredients found in recipe!');
      }
      
      final title = recipe['title']?.toString().toLowerCase() ?? '';
      final description = recipe['description']?.toString().toLowerCase() ?? '';
      final instructions = recipe['instructions']?.toString().toLowerCase() ?? '';

      // Combine all text to search
      final searchText = '$title $description $instructions ${ingredients.join(' ')}'.toLowerCase();

      // Check each user allergen
      print('DEBUG: AllergenDetectionService - User allergens: $userAllergens');
      for (final userAllergen in userAllergens) {
        final allergenKey = _normalizeAllergenKey(userAllergen);
        final keywords = allergenKeywords[allergenKey] ?? [];
        print('DEBUG: AllergenDetectionService - Checking user allergen "$userAllergen" (normalized: "$allergenKey") with ${keywords.length} keywords');
        
        bool allergenFound = false;
        for (final keyword in keywords) {
          // Use word boundary matching to avoid false positives
          final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
          if (regex.hasMatch(searchText) && !_isFalsePositive(searchText, keyword)) {
            detectedAllergens.add(userAllergen);
            allergenFound = true;
            print('DEBUG: AllergenDetectionService - ✓ Found "$userAllergen" via keyword "$keyword" in searchText');
            break; // Found this allergen, move to next
          }
        }
        
        // If not found yet, check individual ingredients more carefully
        if (!allergenFound) {
          for (final ingredient in ingredients) {
            final ingredientLower = ingredient.toLowerCase();
            for (final keyword in keywords) {
              if (ingredientLower.contains(keyword) && !_isFalsePositive(ingredientLower, keyword)) {
                detectedAllergens.add(userAllergen);
                allergenFound = true;
                print('DEBUG: AllergenDetectionService - ✓ Found "$userAllergen" via keyword "$keyword" in ingredient "$ingredient"');
                break;
              }
            }
            if (allergenFound) break;
          }
        }
        
        if (!allergenFound) {
          print('DEBUG: AllergenDetectionService - ✗ Did NOT find "$userAllergen" in recipe');
        }
      }
      
      print('DEBUG: AllergenDetectionService - Final detectedAllergens: $detectedAllergens');

      // NEW: Analyze for hidden allergens
      final ingredientsList = recipe['extendedIngredients'] ?? recipe['ingredients'] ?? [];
      final analysis = IngredientAnalysisService.analyzeRecipeIngredients(ingredientsList);
      final hiddenAllergens = analysis['hiddenAllergens'] as Map<String, Map<String, double>>;
      
      print('DEBUG: AllergenDetectionService - Hidden allergens found: ${hiddenAllergens.keys.toList()}');
      
      // Check if user is allergic to any hidden allergens
      for (final allergenType in hiddenAllergens.keys) {
        for (final userAllergen in userAllergens) {
          final normalizedUser = _normalizeAllergenKey(userAllergen);
          if (normalizedUser == allergenType) {
            if (!detectedAllergens.contains(userAllergen)) {
              detectedAllergens.add(userAllergen);
              print('DEBUG: AllergenDetectionService - Added hidden allergen: $userAllergen');
            }
          }
        }
      }

      return {
        'hasAllergens': detectedAllergens.isNotEmpty,
        'detectedAllergens': detectedAllergens,
        'safeToEat': detectedAllergens.isEmpty,
        'hiddenAllergens': hiddenAllergens,
        'warnings': analysis['warnings'],
        'recipe': recipe,
      };
    } catch (e) {
      print('Error detecting allergens: $e');
      return {
        'hasAllergens': false,
        'detectedAllergens': [],
        'safeToEat': true,
        'error': e.toString(),
      };
    }
  }

  // Get substitution suggestions for detected allergens
  static List<String> getSubstitutionSuggestions(List<String> allergens) {
    final suggestions = <String>[];
    
    for (final allergen in allergens) {
      final allergenKey = _normalizeAllergenKey(allergen);
      final subs = substitutions[allergenKey] ?? [];
      suggestions.addAll(subs);
    }
    
    return suggestions.toSet().toList(); // Remove duplicates
  }

  // Check if a recipe is safe for the user
  static Future<bool> isRecipeSafe(Map<String, dynamic> recipe) async {
    final result = await detectAllergensInRecipe(recipe);
    return result['safeToEat'] ?? true;
  }

  // Check if a keyword match is a false positive
  static bool _isFalsePositive(String searchText, String keyword) {
    final searchLower = searchText.toLowerCase();
    final keywordLower = keyword.toLowerCase();
    
    // Common false positives that contain allergen keywords but aren't actually allergens
    final falsePositives = {
      'egg': ['eggplant', 'egg plant', 'nutmeg'],
      'nut': ['nutmeg', 'coconut', 'butternut', 'donut', 'doughnut'],
      'milk': ['coconut milk', 'almond milk', 'oat milk', 'soy milk', 'rice milk'], // These are safe alternatives
      'cream': ['cream of mushroom', 'cream of chicken', 'cream of celery', 'cream of potato'], // Canned soups
      'butter': ['peanut butter', 'almond butter', 'sunflower butter', 'cashew butter'], // Nut butters (handled separately)
    };
    
    // Check if this keyword has known false positives
    if (falsePositives.containsKey(keywordLower)) {
      for (final falsePositive in falsePositives[keywordLower]!) {
        if (searchLower.contains(falsePositive.toLowerCase())) {
          // Special case for milk alternatives - they're safe
          if (keywordLower == 'milk' && !searchLower.contains('dairy')) {
            return true; // Milk alternatives are safe
          }
          // Special case for cream soups - might contain dairy but often don't
          if (keywordLower == 'cream' && searchLower.contains('cream of')) {
            return true; // Cream soups are ambiguous, skip them
          }
          return true;
        }
      }
    }
    
    return false;
  }

  // Get detailed allergen analysis
  static Future<Map<String, dynamic>> getDetailedAnalysis(Map<String, dynamic> recipe) async {
    final result = await detectAllergensInRecipe(recipe);
    final suggestions = getSubstitutionSuggestions(result['detectedAllergens'] ?? []);
    
    return {
      ...result,
      'substitutionSuggestions': suggestions,
      'riskLevel': _getRiskLevel(result['detectedAllergens'] ?? []),
    };
  }

  // Determine risk level based on allergens
  static String _getRiskLevel(List<String> allergens) {
    if (allergens.isEmpty) return 'safe';
    if (allergens.length == 1) return 'low';
    if (allergens.length <= 3) return 'medium';
    return 'high';
  }

  // Get allergen warning message
  static String getWarningMessage(List<String> allergens) {
    if (allergens.isEmpty) return '';
    
    if (allergens.length == 1) {
      return '⚠️ This recipe contains ${allergens.first}, which you\'re allergic to.';
    } else {
      return '⚠️ This recipe contains multiple allergens: ${allergens.join(', ')}.';
    }
  }

  // Get substitution message
  static String getSubstitutionMessage(List<String> suggestions) {
    if (suggestions.isEmpty) return '';
    
    return '💡 Consider these substitutions: ${suggestions.take(3).join(', ')}${suggestions.length > 3 ? '...' : ''}';
  }
}
