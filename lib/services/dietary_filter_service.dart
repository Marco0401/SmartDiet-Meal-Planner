import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietaryFilterService {
  /// Get user's dietary preference (single selection)
  static Future<String?> getUserDietaryPreference() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final prefs = List<String>.from(data?['dietaryPreferences'] ?? []);
        // Return first preference (single-select)
        return prefs.isNotEmpty && prefs.first != 'None' ? prefs.first : null;
      }
      return null;
    } catch (e) {
      print('Error getting user dietary preference: $e');
      return null;
    }
  }

  /// Filter recipes based on dietary preference
  static List<Map<String, dynamic>> filterRecipesByDiet(
    List<Map<String, dynamic>> recipes,
    String? dietaryPreference,
  ) {
    if (dietaryPreference == null || 
        dietaryPreference == 'None' || 
        dietaryPreference == 'No Preference') {
      return recipes;
    }

    print('DEBUG: Filtering ${recipes.length} recipes for diet: $dietaryPreference');

    return recipes.where((recipe) {
      final title = (recipe['title'] ?? '').toString().toLowerCase();
      final description = (recipe['description'] ?? '').toString().toLowerCase();
      final summary = (recipe['summary'] ?? '').toString().toLowerCase();
      final ingredients = _extractIngredientsList(recipe);
      final category = (recipe['category'] ?? '').toString().toLowerCase();
      
      final searchText = '$title $description $summary ${ingredients.join(' ')} $category';

      switch (dietaryPreference.toLowerCase()) {
        case 'vegetarian':
          return _isVegetarian(searchText, ingredients);
        case 'vegan':
          return _isVegan(searchText, ingredients);
        case 'pescatarian':
          return _isPescatarian(searchText, ingredients);
        case 'keto':
        case 'ketogenic':
          return _isKeto(searchText, ingredients);
        case 'low carb':
          return _isLowCarb(recipe);
        case 'low sodium':
          return _isLowSodium(recipe);
        case 'halal':
          return _isHalal(searchText, ingredients);
        default:
          return true; // Unknown preference, don't filter
      }
    }).toList();
  }

  /// Extract ingredients list from recipe
  static List<String> _extractIngredientsList(Map<String, dynamic> recipe) {
    final ingredients = <String>[];

    // Check extendedIngredients (Spoonacular format)
    if (recipe['extendedIngredients'] is List) {
      for (var ing in recipe['extendedIngredients'] as List) {
        if (ing is Map) {
          final name = ing['name']?.toString() ?? ing['original']?.toString() ?? '';
          if (name.isNotEmpty) ingredients.add(name.toLowerCase());
        } else if (ing is String) {
          ingredients.add(ing.toLowerCase());
        }
      }
    }

    // Check ingredients field
    if (recipe['ingredients'] is List) {
      for (var ing in recipe['ingredients'] as List) {
        if (ing is Map) {
          final name = ing['name']?.toString() ?? '';
          if (name.isNotEmpty) ingredients.add(name.toLowerCase());
        } else if (ing is String) {
          ingredients.add(ing.toLowerCase());
        }
      }
    }

    return ingredients;
  }

  /// Check if recipe is vegetarian
  static bool _isVegetarian(String searchText, List<String> ingredients) {
    // Exclude meat, poultry, fish, and seafood
    final nonVegetarian = [
      'meat', 'beef', 'pork', 'chicken', 'turkey', 'duck', 'lamb', 'veal',
      'fish', 'salmon', 'tuna', 'cod', 'tilapia', 'shrimp', 'prawn', 'crab',
      'lobster', 'clam', 'mussel', 'oyster', 'anchovy', 'bacon', 'ham',
      'sausage', 'pepperoni', 'salami', 'chorizo', 'ground beef', 'ground pork',
      'steak', 'ribs', 'wings', 'thigh', 'breast', 'drumstick', 'seafood',
    ];

    for (final item in nonVegetarian) {
      if (searchText.contains(item)) {
        print('DEBUG: Recipe excluded from vegetarian - contains: $item');
        return false;
      }
    }
    return true;
  }

  /// Check if recipe is vegan
  static bool _isVegan(String searchText, List<String> ingredients) {
    // First check if vegetarian
    if (!_isVegetarian(searchText, ingredients)) {
      return false;
    }

    // Additionally exclude dairy, eggs, and honey
    final nonVegan = [
      'milk', 'cheese', 'butter', 'cream', 'yogurt', 'egg', 'eggs',
      'honey', 'whey', 'casein', 'lactose', 'ghee', 'mayo', 'mayonnaise',
      'dairy', 'gelatin', 'lard', 'tallow',
    ];

    for (final item in nonVegan) {
      if (searchText.contains(item)) {
        print('DEBUG: Recipe excluded from vegan - contains: $item');
        return false;
      }
    }
    return true;
  }

  /// Check if recipe is pescatarian
  static bool _isPescatarian(String searchText, List<String> ingredients) {
    // Exclude meat and poultry, but allow fish and seafood
    final nonPescatarian = [
      'meat', 'beef', 'pork', 'chicken', 'turkey', 'duck', 'lamb', 'veal',
      'bacon', 'ham', 'sausage', 'pepperoni', 'salami', 'chorizo',
      'ground beef', 'ground pork', 'steak', 'ribs', 'wings', 'thigh',
      'breast', 'drumstick',
    ];

    for (final item in nonPescatarian) {
      if (searchText.contains(item)) {
        print('DEBUG: Recipe excluded from pescatarian - contains: $item');
        return false;
      }
    }
    return true;
  }

  /// Check if recipe is keto-friendly
  static bool _isKeto(String searchText, List<String> ingredients) {
    // Exclude high-carb foods
    final highCarb = [
      'bread', 'pasta', 'rice', 'potato', 'noodle', 'flour', 'sugar',
      'wheat', 'corn', 'oat', 'barley', 'quinoa', 'couscous', 'cereal',
      'bagel', 'muffin', 'cake', 'cookie', 'pie', 'pastry', 'pizza',
      'tortilla', 'wrap', 'sandwich', 'burger bun', 'bun',
    ];

    for (final item in highCarb) {
      if (searchText.contains(item)) {
        print('DEBUG: Recipe excluded from keto - contains: $item');
        return false;
      }
    }

    // Check nutrition if available
    final nutrition = ingredients;
    return true;
  }

  /// Check if recipe is low carb
  static bool _isLowCarb(Map<String, dynamic> recipe) {
    // Check nutrition data if available
    if (recipe['nutrition'] != null) {
      final nutrition = recipe['nutrition'] as Map<String, dynamic>;
      final carbs = (nutrition['carbs'] ?? nutrition['carbohydrates'] ?? 999) as num;
      
      // Low carb typically means less than 30g carbs per serving
      if (carbs < 30) {
        return true;
      }
    }

    // Fallback to keto check (keto is low carb)
    final searchText = '${recipe['title']} ${recipe['description'] ?? ''} ${recipe['summary'] ?? ''}'.toLowerCase();
    final ingredients = _extractIngredientsList(recipe);
    return _isKeto(searchText, ingredients);
  }

  /// Check if recipe is low sodium
  static bool _isLowSodium(Map<String, dynamic> recipe) {
    // Check nutrition data if available
    if (recipe['nutrition'] != null) {
      final nutrition = recipe['nutrition'] as Map<String, dynamic>;
      final sodium = (nutrition['sodium'] ?? 999999) as num;
      
      // Low sodium typically means less than 140mg per serving
      if (sodium < 500) { // Being more lenient for meal-sized portions
        return true;
      }
    }

    // Fallback to ingredient check
    final searchText = '${recipe['title']} ${recipe['description'] ?? ''} ${recipe['summary'] ?? ''}'.toLowerCase();
    final highSodium = [
      'soy sauce', 'salt', 'salted', 'cured', 'pickled', 'smoked',
      'canned', 'processed', 'bacon', 'ham', 'sausage', 'cheese',
    ];

    for (final item in highSodium) {
      if (searchText.contains(item)) {
        return false;
      }
    }
    return true;
  }

  /// Check if recipe is halal
  static bool _isHalal(String searchText, List<String> ingredients) {
    // Exclude pork and alcohol
    final nonHalal = [
      'pork', 'bacon', 'ham', 'sausage', 'pepperoni', 'salami',
      'alcohol', 'wine', 'beer', 'rum', 'vodka', 'whiskey', 'liquor',
      'gelatin', 'lard',
    ];

    for (final item in nonHalal) {
      if (searchText.contains(item)) {
        print('DEBUG: Recipe excluded from halal - contains: $item');
        return false;
      }
    }
    return true;
  }

  /// Get dietary preference display name
  static String getDietaryPreferenceDisplayName(String? preference) {
    if (preference == null || preference == 'None' || preference == 'No Preference') {
      return 'All Recipes';
    }
    return preference;
  }

  /// Get dietary preference description
  static String getDietaryPreferenceDescription(String? preference) {
    switch (preference?.toLowerCase()) {
      case 'vegetarian':
        return 'No meat, poultry, or seafood';
      case 'vegan':
        return 'No animal products';
      case 'pescatarian':
        return 'No meat or poultry, fish allowed';
      case 'keto':
      case 'ketogenic':
        return 'Very low carb, high fat';
      case 'low carb':
        return 'Reduced carbohydrate intake';
      case 'low sodium':
        return 'Reduced salt content';
      case 'halal':
        return 'No pork or alcohol';
      default:
        return 'No dietary restrictions';
    }
  }
}
