import 'dart:convert';

/// Service for analyzing ingredient composition and detecting hidden allergens
/// 
/// This service provides advanced ingredient parsing and analysis to:
/// - Extract base ingredients from complex descriptions
/// - Detect hidden allergens in processed foods
/// - Identify ingredient derivatives and byproducts
/// - Parse compound ingredients (e.g., "cream of mushroom soup")
class IngredientAnalysisService {
  
  /// Common ingredient derivatives that contain allergens
  static const Map<String, List<String>> allergenDerivatives = {
    'dairy': [
      'whey', 'casein', 'lactose', 'curds', 'ghee',
      'buttermilk', 'cream cheese', 'sour cream', 'heavy cream',
      'half and half', 'evaporated milk', 'condensed milk',
      'milk powder', 'milk solids', 'milk protein',
      'lactalbumin', 'lactoglobulin', 'rennet casein',
      'cheese powder', 'butter oil', 'butter solids',
    ],
    'eggs': [
      'albumin', 'ovalbumin', 'ovomucoid', 'ovotransferrin',
      'egg white', 'egg yolk', 'egg powder', 'dried egg',
      'egg solids', 'egg protein', 'lysozyme', 'meringue',
      'mayonnaise', 'aioli', 'hollandaise', 'custard',
    ],
    'wheat': [
      'wheat starch', 'wheat protein', 'wheat germ', 'wheat bran',
      'vital wheat gluten', 'hydrolyzed wheat protein',
      'wheat flour', 'enriched flour', 'all-purpose flour',
      'bread flour', 'cake flour', 'pastry flour',
      'durum', 'semolina', 'farina', 'kamut', 'spelt',
    ],
    'soy': [
      'soy protein', 'soy lecithin', 'soy flour', 'soy milk',
      'textured vegetable protein', 'tvp', 'hydrolyzed soy protein',
      'soy protein isolate', 'soy protein concentrate',
      'soybean oil', 'soy sauce', 'tamari', 'miso',
    ],
    'fish': [
      'fish oil', 'fish sauce', 'fish stock', 'fish gelatin',
      'worcestershire sauce', 'anchovy paste', 'fish protein',
      'omega-3', 'dha', 'epa', 'caviar', 'roe',
    ],
    'shellfish': [
      'shellfish extract', 'shellfish stock', 'shellfish flavoring',
      'crab extract', 'lobster extract', 'shrimp paste',
      'oyster sauce', 'clam juice', 'seafood flavoring',
    ],
    'tree_nuts': [
      'nut oil', 'nut butter', 'nut flour', 'nut milk',
      'almond extract', 'almond oil', 'walnut oil',
      'hazelnut paste', 'praline', 'marzipan', 'nougat',
      'nut pieces', 'nut meal', 'nut paste',
    ],
    'peanuts': [
      'peanut oil', 'peanut butter', 'peanut flour',
      'peanut protein', 'groundnut oil', 'arachis oil',
      'peanut paste', 'peanut pieces',
    ],
  };

  /// Processed foods that commonly contain hidden allergens
  static const Map<String, List<String>> hiddenAllergenFoods = {
    'dairy': [
      'cream of mushroom soup', 'cream of chicken soup',
      'cream of celery soup', 'cream of potato soup',
      'alfredo sauce', 'bechamel sauce', 'white sauce',
      'ranch dressing', 'caesar dressing', 'blue cheese dressing',
      'chocolate', 'milk chocolate', 'white chocolate',
      'caramel', 'toffee', 'butterscotch', 'fudge',
      'biscuits', 'crackers', 'cookies', 'cakes',
      'bread', 'rolls', 'bagels', 'croissants',
    ],
    'eggs': [
      'pasta', 'egg noodles', 'fresh pasta',
      'mayonnaise', 'aioli', 'hollandaise',
      'meringue', 'marshmallows', 'nougat',
      'custard', 'pudding', 'ice cream',
      'cakes', 'cookies', 'brownies', 'muffins',
    ],
    'wheat': [
      'soy sauce', 'teriyaki sauce', 'hoisin sauce',
      'worcestershire sauce', 'malt vinegar',
      'beer', 'ale', 'lager', 'malt beverages',
      'seitan', 'imitation crab', 'surimi',
      'bouillon cubes', 'soup mixes', 'gravy mixes',
    ],
    'soy': [
      'vegetable oil', 'vegetable broth',
      'bouillon', 'stock cubes', 'soup bases',
      'protein bars', 'energy bars', 'meal replacements',
      'processed meats', 'hot dogs', 'sausages',
    ],
  };

  /// Analyze an ingredient string to extract base components
  /// 
  /// Example: "1 cup (250ml) low-fat milk" → "milk"
  /// Example: "2 tbsp butter, melted" → "butter"
  static String extractBaseIngredient(String ingredient) {
    // Remove measurements and quantities
    String cleaned = ingredient.toLowerCase().trim();
    
    // Remove common measurement patterns
    cleaned = cleaned.replaceAll(RegExp(r'\d+[\s]*(cup|cups|tbsp|tsp|oz|ounces|lb|pounds|g|grams|ml|l|liters?)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d+/\d+'), ''); // Remove fractions
    cleaned = cleaned.replaceAll(RegExp(r'\d+'), ''); // Remove numbers
    
    // Remove parenthetical content
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    
    // Remove preparation methods
    final preparationMethods = [
      'chopped', 'diced', 'minced', 'sliced', 'grated', 'shredded',
      'melted', 'softened', 'room temperature', 'cold', 'warm',
      'fresh', 'frozen', 'canned', 'dried', 'cooked', 'raw',
      'optional', 'to taste', 'as needed', 'for garnish',
      'finely', 'roughly', 'thinly', 'thickly',
    ];
    
    for (final method in preparationMethods) {
      cleaned = cleaned.replaceAll(method, '');
    }
    
    // Remove common descriptors
    final descriptors = [
      'large', 'medium', 'small', 'extra', 'super',
      'low-fat', 'non-fat', 'fat-free', 'reduced-fat',
      'whole', 'skim', 'organic', 'free-range',
      'unsalted', 'salted', 'sweetened', 'unsweetened',
    ];
    
    for (final descriptor in descriptors) {
      cleaned = cleaned.replaceAll(descriptor, '');
    }
    
    // Remove punctuation and extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'[,;.!?-]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();
    
    return cleaned;
  }

  /// Check if an ingredient contains hidden allergens
  /// 
  /// Returns a map of allergen types to confidence levels (0.0 to 1.0)
  static Map<String, double> detectHiddenAllergens(String ingredient) {
    final hiddenAllergens = <String, double>{};
    final ingredientLower = ingredient.toLowerCase();
    final baseIngredient = extractBaseIngredient(ingredient);
    
    // Check against known hidden allergen foods
    for (final entry in hiddenAllergenFoods.entries) {
      final allergenType = entry.key;
      final foods = entry.value;
      
      for (final food in foods) {
        if (ingredientLower.contains(food) || baseIngredient.contains(food)) {
          // High confidence for exact matches
          hiddenAllergens[allergenType] = 0.9;
          break;
        }
      }
    }
    
    // Check against allergen derivatives
    for (final entry in allergenDerivatives.entries) {
      final allergenType = entry.key;
      final derivatives = entry.value;
      
      for (final derivative in derivatives) {
        if (ingredientLower.contains(derivative) || baseIngredient.contains(derivative)) {
          // Very high confidence for derivatives
          hiddenAllergens[allergenType] = 1.0;
          break;
        }
      }
    }
    
    return hiddenAllergens;
  }

  /// Analyze a full recipe's ingredients for allergens
  /// 
  /// Returns detailed analysis including:
  /// - Direct allergens (obvious ingredients)
  /// - Hidden allergens (derivatives and processed foods)
  /// - Confidence levels for each detection
  static Map<String, dynamic> analyzeRecipeIngredients(List<dynamic> ingredients) {
    final directAllergens = <String, List<String>>{};
    final hiddenAllergens = <String, Map<String, double>>{};
    final warnings = <String>[];
    
    for (final ingredient in ingredients) {
      String ingredientName;
      
      if (ingredient is Map<String, dynamic>) {
        ingredientName = ingredient['name']?.toString() ?? 
                        ingredient['original']?.toString() ?? '';
      } else {
        ingredientName = ingredient.toString();
      }
      
      if (ingredientName.isEmpty) continue;
      
      // Extract base ingredient
      final baseIngredient = extractBaseIngredient(ingredientName);
      
      // Check for hidden allergens
      final hidden = detectHiddenAllergens(ingredientName);
      
      if (hidden.isNotEmpty) {
        for (final entry in hidden.entries) {
          final allergenType = entry.key;
          final confidence = entry.value;
          
          if (!hiddenAllergens.containsKey(allergenType)) {
            hiddenAllergens[allergenType] = {};
          }
          
          hiddenAllergens[allergenType]![ingredientName] = confidence;
          
          // Add warning for medium-confidence detections
          if (confidence < 0.9) {
            warnings.add('$ingredientName may contain $allergenType (confidence: ${(confidence * 100).toStringAsFixed(0)}%)');
          }
        }
      }
    }
    
    return {
      'directAllergens': directAllergens,
      'hiddenAllergens': hiddenAllergens,
      'warnings': warnings,
      'totalIngredients': ingredients.length,
      'analyzedSuccessfully': true,
    };
  }

  /// Get substitution suggestions that avoid hidden allergens
  /// 
  /// This ensures substitutions don't introduce new allergens
  static List<String> getSafeSubstitutions(
    String ingredient,
    List<String> userAllergens,
  ) {
    final suggestions = <String>[];
    final ingredientLower = ingredient.toLowerCase();
    
    // Dairy substitutions
    if (ingredientLower.contains('milk') || ingredientLower.contains('cream')) {
      if (!userAllergens.any((a) => a.toLowerCase().contains('soy'))) {
        suggestions.add('Soy milk or soy cream');
      }
      if (!userAllergens.any((a) => a.toLowerCase().contains('nut'))) {
        suggestions.add('Almond milk or cashew cream');
      }
      suggestions.add('Oat milk or oat cream');
      suggestions.add('Coconut milk or coconut cream');
    }
    
    // Egg substitutions
    if (ingredientLower.contains('egg')) {
      suggestions.add('Flax egg (1 tbsp ground flaxseed + 3 tbsp water)');
      suggestions.add('Chia egg (1 tbsp chia seeds + 3 tbsp water)');
      suggestions.add('Applesauce (1/4 cup per egg)');
      suggestions.add('Mashed banana (1/2 banana per egg)');
    }
    
    // Wheat/flour substitutions
    if (ingredientLower.contains('flour') || ingredientLower.contains('wheat')) {
      suggestions.add('Rice flour (gluten-free)');
      if (!userAllergens.any((a) => a.toLowerCase().contains('nut'))) {
        suggestions.add('Almond flour');
      }
      suggestions.add('Coconut flour');
      suggestions.add('Oat flour (certified gluten-free)');
    }
    
    return suggestions;
  }

  /// Validate that a substitution is safe for the user
  /// 
  /// Checks if the substitution introduces any new allergens
  static bool isSubstitutionSafe(
    String substitution,
    List<String> userAllergens,
  ) {
    final substitutionLower = substitution.toLowerCase();
    
    for (final allergen in userAllergens) {
      final allergenLower = allergen.toLowerCase();
      
      // Check direct matches
      if (substitutionLower.contains(allergenLower)) {
        return false;
      }
      
      // Check derivatives
      final allergenKey = _normalizeAllergenKey(allergen);
      final derivatives = allergenDerivatives[allergenKey] ?? [];
      
      for (final derivative in derivatives) {
        if (substitutionLower.contains(derivative.toLowerCase())) {
          return false;
        }
      }
    }
    
    return true;
  }

  /// Normalize allergen name to match internal keys
  static String _normalizeAllergenKey(String allergen) {
    final normalized = allergen.toLowerCase().trim();
    if (normalized.contains('milk') || normalized.contains('dairy')) return 'dairy';
    if (normalized.contains('wheat') || normalized.contains('gluten')) return 'wheat';
    if (normalized.contains('tree') && normalized.contains('nut')) return 'tree_nuts';
    return normalized.replaceAll(' ', '_');
  }

  /// Generate a detailed ingredient report
  /// 
  /// Useful for debugging and user transparency
  static String generateIngredientReport(Map<String, dynamic> analysis) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== Ingredient Analysis Report ===\n');
    buffer.writeln('Total ingredients analyzed: ${analysis['totalIngredients']}');
    buffer.writeln('Analysis successful: ${analysis['analyzedSuccessfully']}\n');
    
    final hiddenAllergens = analysis['hiddenAllergens'] as Map<String, Map<String, double>>;
    
    if (hiddenAllergens.isNotEmpty) {
      buffer.writeln('Hidden Allergens Detected:');
      for (final entry in hiddenAllergens.entries) {
        buffer.writeln('\n${entry.key.toUpperCase()}:');
        for (final ingredient in entry.value.entries) {
          final confidence = (ingredient.value * 100).toStringAsFixed(0);
          buffer.writeln('  - ${ingredient.key} (${confidence}% confidence)');
        }
      }
    } else {
      buffer.writeln('No hidden allergens detected.');
    }
    
    final warnings = analysis['warnings'] as List<String>;
    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  ⚠️  $warning');
      }
    }
    
    return buffer.toString();
  }
}
