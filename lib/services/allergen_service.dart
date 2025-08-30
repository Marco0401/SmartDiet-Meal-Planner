class AllergenService {
  // Common allergens and their variations
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
      'catfish', 'flounder', 'sole', 'perch', 'carp', 'eel'
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
      'wheat germ', 'wheat bran', 'wheat starch', 'gluten'
    ],
    'soy': [
      'soy', 'soya', 'soybean', 'soy beans', 'tofu', 'tempeh',
      'miso', 'soy sauce', 'tamari', 'edamame', 'soy milk',
      'soy protein', 'soy lecithin', 'soy oil'
    ],
  };

  // Substitution suggestions
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
    final foundAllergens = <String, List<String>>{};
    
    for (final ingredient in ingredients) {
      final ingredientName = ingredient['name']?.toString().toLowerCase() ?? '';
      final ingredientText = ingredientName;
      
      for (final allergenEntry in _allergens.entries) {
        final allergenType = allergenEntry.key;
        final allergenKeywords = allergenEntry.value;
        
        for (final keyword in allergenKeywords) {
          if (ingredientText.contains(keyword.toLowerCase())) {
            if (!foundAllergens.containsKey(allergenType)) {
              foundAllergens[allergenType] = [];
            }
            if (!foundAllergens[allergenType]!.contains(ingredientName)) {
              foundAllergens[allergenType]!.add(ingredientName);
            }
            break;
          }
        }
      }
    }
    
    return foundAllergens;
  }

  /// Get substitution suggestions for a specific allergen
  static List<String> getSubstitutions(String allergenType) {
    return _substitutions[allergenType] ?? [];
  }

  /// Get all available allergen types
  static List<String> getAllergenTypes() {
    return _allergens.keys.toList();
  }

  /// Get allergen display names
  static String getDisplayName(String allergenType) {
    switch (allergenType) {
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
    switch (allergenType) {
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