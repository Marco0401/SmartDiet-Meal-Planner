import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredient_analysis_service.dart';

class AllergenService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Common allergens and their variations (fallback data)
  static const Map<String, List<String>> _allergens = {
    'dairy': [
      'milk', 'cheese', 'yogurt', 'cream', 'butter', 'whey', 'casein',
      'lactose', 'ghee', 'curd', 'kefir', 'sour cream', 'heavy cream',
      'half and half', 'evaporated milk', 'condensed milk'
    ],
    'eggs': [
      'egg', 'eggs', 'egg white', 'egg yolk', 'albumin', 'ovalbumin',
      'egg protein', 'egg powder', 'dried egg'
    ],
    'fish': [
      'fish', 'salmon', 'tuna', 'cod', 'halibut', 'mackerel', 'sardines',
      'anchovies', 'trout', 'bass', 'snapper', 'grouper', 'tilapia',
      'catfish', 'flounder', 'sole', 'perch', 'carp', 'eel',
      'bangus', 'milkfish', 'bangus (milkfish)', 'lapu-lapu', 'galunggong', 
      'tamban', 'tulingan', 'fish sauce', 'worcestershire', 'worcestershire sauce',
    ],
    'shellfish': [
      'shrimp', 'prawn', 'crab', 'lobster', 'crayfish', 'crawfish',
      'mussel', 'clam', 'oyster', 'scallop', 'squid', 'calamari',
      'octopus', 'scampi', 'langoustine', 'crayfish', 'crawfish'
    ],
    'tree_nuts': [
      'almond', 'walnut', 'pecan', 'cashew', 'pistachio', 'hazelnut',
      'macadamia', 'brazil nut', 'pine nut', 'chestnut', 'filbert',
      'almonds', 'walnuts', 'pecans', 'cashews', 'pistachios', 'hazelnuts'
    ],
    'peanuts': [
      'peanut', 'peanuts', 'groundnut', 'ground nuts', 'arachis',
      'peanut butter', 'peanut oil', 'peanut flour'
    ],
    'wheat': [
      'wheat', 'flour', 'bread', 'pasta', 'noodles', 'couscous',
      'bulgur', 'farro', 'spelt', 'kamut', 'durum', 'semolina',
      'wheat germ', 'wheat bran', 'wheat starch', 'gluten',
      'macaroni', 'spaghetti', 'linguine', 'fettuccine', 'penne',
      'rigatoni', 'rotini', 'orzo', 'lasagna', 'ravioli',
      'tortellini', 'gnocchi', 'breadcrumbs', 'croutons', 'crackers',
      'biscuit', 'muffin', 'pancake', 'waffle', 'pretzel'
    ],
    'soy': [
      'soy', 'soya', 'soybean', 'soy beans', 'tofu', 'tempeh',
      'miso', 'soy sauce', 'tamari', 'edamame', 'soy milk',
      'soy protein', 'soy lecithin', 'soy oil'
    ],
  };

  // Substitution suggestions (fallback data)
  static const Map<String, List<String>> _substitutions = {
    'dairy': [
      'Almond milk for cow milk',
      'Coconut milk for heavy cream',
      'Nutritional yeast for cheese',
      'Coconut oil for butter',
      'Cashew cream for sour cream'
    ],
    'eggs': [
      'Flaxseed meal (1 tbsp + 3 tbsp water) for 1 egg',
      'Chia seeds (1 tbsp + 3 tbsp water) for 1 egg',
      'Banana (1/4 cup mashed) for 1 egg',
      'Applesauce (1/4 cup) for 1 egg',
      'Silken tofu (1/4 cup) for 1 egg'
    ],
    'fish': [
      'Tofu for fish protein',
      'Tempeh for fish texture',
      'Mushrooms for umami flavor',
      'Seaweed for ocean flavor',
      'Plant-based fish alternatives'
    ],
    'shellfish': [
      'Tofu for protein',
      'Mushrooms for texture',
      'Seaweed for ocean flavor',
      'Plant-based seafood alternatives'
    ],
    'tree_nuts': [
      'Sunflower seeds for texture',
      'Pumpkin seeds for protein',
      'Sesame seeds for crunch',
      'Coconut for texture'
    ],
    'peanuts': [
      'Sunflower seed butter',
      'Almond butter (if not allergic to tree nuts)',
      'Soy nut butter',
      'Tahini (sesame seed butter)'
    ],
    'wheat': [
      'Rice flour for wheat flour',
      'Almond flour for wheat flour',
      'Coconut flour for wheat flour',
      'Quinoa flour for wheat flour',
      'Gluten-free pasta for regular pasta'
    ],
    'soy': [
      'Coconut aminos for soy sauce',
      'Almond milk for soy milk',
      'Chickpea tofu for regular tofu',
      'Lentils for soy protein'
    ],
  };

  /// Check if a recipe contains allergens based on ingredients
  static Map<String, List<String>> checkAllergens(List<dynamic> ingredients) {
    print('DEBUG: AllergenService.checkAllergens - Checking ${ingredients.length} ingredients');
    final foundAllergens = <String, List<String>>{};
    
    for (final ingredient in ingredients) {
      // Handle both object format (API recipes) and string format (manual/substituted recipes)
      String ingredientName;
      String displayName;
      
      if (ingredient is Map) {
        // API recipe format with name field - handle Map objects
        if (ingredient['name'] is Map) {
          // If name is a Map, extract the actual name string
          final nameMap = ingredient['name'] as Map;
          if (nameMap.containsKey('name') && nameMap['name'] is String) {
            ingredientName = nameMap['name'].toString().toLowerCase();
            displayName = nameMap['name'].toString();
          } else {
            // If no nested name, use the Map as string (fallback)
            ingredientName = nameMap.toString().toLowerCase();
            displayName = nameMap.toString();
          }
        } else {
          // Name is a string
          ingredientName = ingredient['name']?.toString().toLowerCase() ?? '';
          displayName = ingredient['name']?.toString() ?? '';
        }
      } else {
        // String format (manual meals or substituted recipes)
        ingredientName = ingredient.toString().toLowerCase();
        displayName = ingredient.toString();
      }
      
      final ingredientText = ingredientName.trim();
      
      // Skip empty ingredients
      if (ingredientText.isEmpty) {
        print('DEBUG: AllergenService - Skipping empty ingredient');
        continue;
      }
      
      print('DEBUG: AllergenService - Checking: "$displayName" (text: "$ingredientText")');
      
      // Check false positives BEFORE checking allergens
      if (_isFalsePositive(ingredientText)) {
        print('DEBUG: AllergenService - Skipping false positive: $displayName');
        continue;
      }
      
      // NEW: Extract base ingredient for better matching
      final baseIngredient = IngredientAnalysisService.extractBaseIngredient(ingredientText);
      if (baseIngredient != ingredientText) {
        print('DEBUG: AllergenService - Base ingredient: "$baseIngredient"');
      }
      
      // Check both original and base ingredient
      final textsToCheck = [ingredientText];
      if (baseIngredient != ingredientText) {
        textsToCheck.add(baseIngredient);
      }
      
      for (final textToCheck in textsToCheck) {
        for (final allergenEntry in _allergens.entries) {
          final allergenType = allergenEntry.key;
          final allergenKeywords = allergenEntry.value;
          
          for (final keyword in allergenKeywords) {
            // Use word boundary matching to avoid false positives
            final regex = RegExp(r'\b' + RegExp.escape(keyword.toLowerCase()) + r'\b');
            if (regex.hasMatch(textToCheck)) {
              if (!foundAllergens.containsKey(allergenType)) {
                foundAllergens[allergenType] = [];
              }
              
              if (!foundAllergens[allergenType]!.contains(displayName)) {
                foundAllergens[allergenType]!.add(displayName);
                print('DEBUG: AllergenService - ✓ Found $allergenType in "$displayName" (keyword: "$keyword" in "${textToCheck == baseIngredient ? 'base' : 'original'}")');
              }
              break; // Found this allergen in this ingredient, move to next allergen type
            }
          }
        }
      }
      
      // NEW: Check for hidden allergens using ingredient analysis
      final hiddenAllergens = IngredientAnalysisService.detectHiddenAllergens(displayName);
      for (final entry in hiddenAllergens.entries) {
        final allergenType = entry.key;
        final confidence = entry.value;
        
        if (!foundAllergens.containsKey(allergenType)) {
          foundAllergens[allergenType] = [];
        }
        
        if (!foundAllergens[allergenType]!.contains(displayName)) {
          foundAllergens[allergenType]!.add(displayName);
          print('DEBUG: AllergenService - ✓ Found hidden $allergenType in "$displayName" (confidence: ${(confidence * 100).toStringAsFixed(0)}%)');
        }
      }
    }
    
    print('DEBUG: AllergenService - Final result: $foundAllergens');
    return foundAllergens;
  }

  /// Get substitution suggestions for a specific allergen
  static Future<List<String>> getSubstitutions(String allergenType) async {
    try {
      // Normalize allergen name first
      final normalizedAllergen = normalizeAllergenName(allergenType);
      print('DEBUG: Getting substitutions for allergen: "$allergenType" (normalized: "$normalizedAllergen")');
      
      // First try to get from Firestore
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final substitutions = data?['data'] as Map<String, dynamic>? ?? {};
        
        print('DEBUG: Available substitution categories: ${substitutions.keys.toList()}');
        
        // Use normalized allergen name
        List<dynamic> allergenSubstitutions = substitutions[normalizedAllergen] as List<dynamic>? ?? [];
        print('DEBUG: Found ${allergenSubstitutions.length} substitutions for normalized key "$normalizedAllergen"');
        
        // Handle both old format (List<String>) and new format (List<Map>)
        final substitutionStrings = <String>[];
        for (final sub in allergenSubstitutions) {
          if (sub is String) {
            // Old format - just substitution string
            substitutionStrings.add(sub);
          } else if (sub is Map<String, dynamic>) {
            // New format - extract substitution text
            final substitutionText = sub['substitution']?.toString() ?? '';
            if (substitutionText.isNotEmpty) {
              substitutionStrings.add(substitutionText);
            }
          }
        }
        
        if (substitutionStrings.isNotEmpty) {
          print('DEBUG: Returning ${substitutionStrings.length} substitution strings: $substitutionStrings');
          return substitutionStrings;
        }
      } else {
        print('DEBUG: No substitutions document found in Firestore');
      }
    } catch (e) {
      print('Error getting substitutions from Firestore: $e');
    }
    
    // Fallback to hardcoded data using normalized name
    final normalizedAllergen = normalizeAllergenName(allergenType);
    final fallbackSubstitutions = _substitutions[normalizedAllergen] ?? [];
    print('DEBUG: Using fallback substitutions for "$normalizedAllergen": $fallbackSubstitutions');
    return fallbackSubstitutions;
  }

  /// Get all substitution suggestions (for admin interface)
  static Future<Map<String, List<String>>> getAllSubstitutions() async {
    try {
      // First try to get from Firestore
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final substitutions = data?['data'] as Map<String, dynamic>? ?? {};
        
        // Convert to the expected format, handling both old and new data structures
        final result = <String, List<String>>{};
        for (final entry in substitutions.entries) {
          final allergenType = entry.key;
          final allergenSubstitutions = entry.value as List<dynamic>? ?? [];
          
          final substitutionStrings = <String>[];
          for (final sub in allergenSubstitutions) {
            if (sub is String) {
              // Old format - just substitution string
              substitutionStrings.add(sub);
            } else if (sub is Map<String, dynamic>) {
              // New format - extract substitution text
              final substitutionText = sub['substitution']?.toString() ?? '';
              if (substitutionText.isNotEmpty) {
                substitutionStrings.add(substitutionText);
              }
            }
          }
          
          result[allergenType] = substitutionStrings;
        }
        
        return result;
      }
    } catch (e) {
      print('Error getting all substitutions from Firestore: $e');
    }
    
    // Fallback to hardcoded data
    return _substitutions;
  }

  /// Update system substitutions (admin only)
  static Future<void> updateSystemSubstitutions(Map<String, List<String>> newSubstitutions) async {
    try {
      await _firestore
          .collection('system_data')
          .doc('substitutions')
          .update({
            'data': newSubstitutions,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      // Data will be fetched fresh from Firestore on next call
      
      print('System substitutions updated successfully');
    } catch (e) {
      print('Error updating system substitutions: $e');
      rethrow;
    }
  }

  /// Get substitution suggestions for a specific allergen including admin-created ones
  static Future<List<String>> getSubstitutionsWithAdmin(String allergenType) async {
    try {
      // Start with system substitutions
      final systemSubstitutions = await getSubstitutions(allergenType);
      final allSubstitutions = List<String>.from(systemSubstitutions);
      
      // Fetch admin-created substitutions from Firestore
      final adminSubstitutionsSnapshot = await FirebaseFirestore.instance
          .collection('admin_substitutions')
          .where('allergenType', isEqualTo: allergenType)
          .get();
      
      // Add admin substitutions to the list
      for (final doc in adminSubstitutionsSnapshot.docs) {
        final data = doc.data();
        final substitution = data['substitution'] as String?;
        if (substitution != null && !allSubstitutions.contains(substitution)) {
          allSubstitutions.add(substitution);
        }
      }
      
      return allSubstitutions;
    } catch (e) {
      print('Error fetching admin substitutions: $e');
      // Return system substitutions as fallback
      return await getSubstitutions(allergenType);
    }
  }

  /// Get all available allergen types
  static List<String> getAllergenTypes() {
    return _allergens.keys.toList();
  }

  /// Normalize allergen name from user input to internal key
  static String normalizeAllergenName(String allergen) {
    final normalized = allergen.toLowerCase().trim();
    
    // Map user-facing names to internal keys
    if (normalized == 'milk' || normalized == 'dairy') return 'dairy';
    if (normalized == 'wheat' || normalized == 'wheat/gluten' || normalized == 'gluten') return 'wheat';
    if (normalized == 'tree nuts' || normalized == 'tree_nuts') return 'tree_nuts';
    
    return normalized;
  }

  /// Get allergen display names
  static String getDisplayName(String allergenType) {
    // Normalize first
    final normalized = normalizeAllergenName(allergenType);
    
    switch (normalized) {
      case 'dairy':
        return 'Dairy';
      case 'eggs':
        return 'Eggs';
      case 'fish':
        return 'Fish';
      case 'shellfish':
        return 'Shellfish';
      case 'tree_nuts':
        return 'Tree Nuts';
      case 'peanuts':
        return 'Peanuts';
      case 'wheat':
        return 'Wheat/Gluten';
      case 'soy':
        return 'Soy';
      default:
        return allergenType;
    }
  }

  /// Get allergen icon
  static String getAllergenIcon(String allergenType) {
    // Normalize first
    final normalized = normalizeAllergenName(allergenType);
    
    switch (normalized) {
      case 'dairy':
        return '🥛';
      case 'eggs':
        return '🥚';
      case 'fish':
        return '🐟';
      case 'shellfish':
        return '🦐';
      case 'tree_nuts':
        return '🌰';
      case 'peanuts':
        return '🥜';
      case 'wheat':
        return '🌾';
      case 'soy':
        return '🫘';
      default:
        return '⚠️';
    }
  }

  /// Check if an ingredient is a false positive for allergen detection
  static bool _isFalsePositive(String ingredientText) {
    final textLower = ingredientText.toLowerCase();
    
    // Common false positives that contain allergen keywords but aren't actually allergens
    final falsePositives = [
      'eggplant', 'egg plants', 'egg plant', 'eggplants',
      'nutmeg', 'coconut', 'butternut', 'donut', 'doughnut',
      'cream of mushroom', 'cream of chicken', 'cream of celery', // Canned soups - may or may not have dairy
      'almond milk', 'oat milk', 'coconut milk', 'soy milk', 'rice milk', // Milk alternatives
    ];
    
    for (final falsePositive in falsePositives) {
      if (textLower.contains(falsePositive.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }

  /// Check if a recipe is safe for a user's allergen profile
  static bool isRecipeSafe(
    List<dynamic> ingredients,
    List<String> userAllergens,
  ) {
    final foundAllergens = checkAllergens(ingredients);
    
    for (final userAllergen in userAllergens) {
      if (foundAllergens.containsKey(userAllergen)) {
        return false;
      }
    }
    
    return true;
  }

  /// Get allergen risk level (low, medium, high)
  static String getRiskLevel(int allergenCount) {
    if (allergenCount == 0) {
      return 'Safe';
    } else if (allergenCount <= 2) {
      return 'Low Risk';
    } else if (allergenCount <= 4) {
      return 'Medium Risk';
    } else {
      return 'High Risk';
    }
  }

  /// Get color for risk level
  static int getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Safe':
        return 0xFF4CAF50; // Green
      case 'Low Risk':
        return 0xFFFF9800; // Orange
      case 'Medium Risk':
        return 0xFFFF5722; // Deep Orange
      case 'High Risk':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
} 