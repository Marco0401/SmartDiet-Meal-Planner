import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllergenDetectionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Common allergen keywords and their categories
  static const Map<String, List<String>> allergenKeywords = {
    'peanuts': ['peanut', 'peanuts', 'groundnut', 'groundnuts', 'arachis', 'peanut oil', 'peanut butter'],
    'tree_nuts': ['almond', 'almonds', 'walnut', 'walnuts', 'cashew', 'cashews', 'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'pecan', 'pecans', 'brazil nut', 'brazil nuts', 'macadamia', 'macadamias'],
    'milk': ['milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'lactose', 'whey', 'casein', 'ghee', 'buttermilk'],
    'eggs': ['egg', 'eggs', 'egg white', 'egg yolk', 'albumen', 'lecithin', 'mayonnaise', 'mayo'],
    'fish': ['fish', 'salmon', 'tuna', 'cod', 'halibut', 'sardine', 'anchovy', 'fish sauce', 'worcestershire'],
    'shellfish': ['shrimp', 'prawn', 'crab', 'lobster', 'scallop', 'mussel', 'oyster', 'clam', 'shellfish', 'crustacean'],
    'wheat_gluten': ['wheat', 'flour', 'bread', 'pasta', 'noodles', 'gluten', 'semolina', 'bulgur', 'couscous', 'seitan'],
    'soy': ['soy', 'soya', 'soybean', 'soybeans', 'tofu', 'tempeh', 'miso', 'soy sauce', 'tamari', 'edamame'],
    'sesame': ['sesame', 'sesame oil', 'sesame seeds', 'tahini', 'halva'],
  };

  // Ingredient substitution suggestions
  static const Map<String, List<String>> substitutions = {
    'peanuts': ['sunflower seeds', 'pumpkin seeds', 'almonds (if not allergic)', 'cashews (if not allergic)', 'sunflower butter'],
    'tree_nuts': ['seeds (sunflower, pumpkin)', 'oats', 'coconut flakes', 'dried fruit'],
    'milk': ['almond milk', 'oat milk', 'coconut milk', 'rice milk', 'soy milk (if not allergic)', 'dairy-free alternatives'],
    'eggs': ['flax eggs (1 tbsp ground flaxseed + 3 tbsp water)', 'chia eggs', 'applesauce', 'banana', 'commercial egg replacer'],
    'fish': ['chicken', 'tofu', 'beans', 'lentils', 'mushrooms', 'seaweed (if not allergic to iodine)'],
    'shellfish': ['chicken', 'fish (if not allergic)', 'tofu', 'mushrooms', 'jackfruit'],
    'wheat_gluten': ['rice flour', 'almond flour', 'coconut flour', 'oat flour', 'gluten-free flour blend', 'quinoa', 'rice'],
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
      final ingredients = List<String>.from(recipe['ingredients'] ?? []);
      final title = recipe['title']?.toString().toLowerCase() ?? '';
      final description = recipe['description']?.toString().toLowerCase() ?? '';
      final instructions = recipe['instructions']?.toString().toLowerCase() ?? '';

      // Combine all text to search
      final searchText = '$title $description $instructions ${ingredients.join(' ')}'.toLowerCase();

      // Check each user allergen
      for (final userAllergen in userAllergens) {
        final allergenKey = userAllergen.toLowerCase().replaceAll(' ', '_');
        final keywords = allergenKeywords[allergenKey] ?? [];
        
        for (final keyword in keywords) {
          // Use word boundary matching to avoid false positives
          final regex = RegExp(r'\b' + RegExp.escape(keyword.toLowerCase()) + r'\b');
          if (regex.hasMatch(searchText) && !_isFalsePositive(searchText, keyword)) {
            detectedAllergens.add(userAllergen);
            break; // Found this allergen, move to next
          }
        }
      }

      return {
        'hasAllergens': detectedAllergens.isNotEmpty,
        'detectedAllergens': detectedAllergens,
        'safeToEat': detectedAllergens.isEmpty,
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
      final allergenKey = allergen.toLowerCase().replaceAll(' ', '_');
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
    // Common false positives that contain allergen keywords but aren't actually allergens
    final falsePositives = [
      'eggplant', 'egg plants', 'egg plant', 'eggplants',
      'egg noodles', 'egg pasta', // These might actually contain eggs, but let's be conservative
    ];
    
    for (final falsePositive in falsePositives) {
      if (searchText.contains(falsePositive)) {
        return true;
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
