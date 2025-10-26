import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NutritionService {
  // Nutrition database for common ingredients
  static const Map<String, Map<String, double>> _nutritionDatabase = {
    // Proteins
    'chicken breast': {'calories': 165, 'protein': 31, 'carbs': 0, 'fat': 3.6, 'fiber': 0},
    'chicken thigh': {'calories': 209, 'protein': 26, 'carbs': 0, 'fat': 10.9, 'fiber': 0},
    'beef': {'calories': 250, 'protein': 26, 'carbs': 0, 'fat': 15, 'fiber': 0},
    'pork': {'calories': 242, 'protein': 27, 'carbs': 0, 'fat': 14, 'fiber': 0},
    'fish': {'calories': 206, 'protein': 22, 'carbs': 0, 'fat': 12, 'fiber': 0},
    'salmon': {'calories': 208, 'protein': 25, 'carbs': 0, 'fat': 12, 'fiber': 0},
    'tuna': {'calories': 144, 'protein': 30, 'carbs': 0, 'fat': 1, 'fiber': 0},
    'shrimp': {'calories': 99, 'protein': 21, 'carbs': 0.9, 'fat': 0.3, 'fiber': 0},
    'egg': {'calories': 68, 'protein': 6, 'carbs': 0.6, 'fat': 4.5, 'fiber': 0},
    'eggs': {'calories': 68, 'protein': 6, 'carbs': 0.6, 'fat': 4.5, 'fiber': 0},
    'tofu': {'calories': 76, 'protein': 8, 'carbs': 1.9, 'fat': 4.8, 'fiber': 0.3},
    'tempeh': {'calories': 192, 'protein': 20, 'carbs': 7.6, 'fat': 10.8, 'fiber': 9},
    
    // Grains
    'rice': {'calories': 130, 'protein': 2.7, 'carbs': 28, 'fat': 0.3, 'fiber': 0.4},
    'brown rice': {'calories': 111, 'protein': 2.6, 'carbs': 23, 'fat': 0.9, 'fiber': 1.8},
    'quinoa': {'calories': 120, 'protein': 4.4, 'carbs': 22, 'fat': 1.9, 'fiber': 2.8},
    'oats': {'calories': 68, 'protein': 2.4, 'carbs': 12, 'fat': 1.4, 'fiber': 1.7},
    'bread': {'calories': 265, 'protein': 9, 'carbs': 49, 'fat': 3.2, 'fiber': 2.7},
    'pasta': {'calories': 131, 'protein': 5, 'carbs': 25, 'fat': 1.1, 'fiber': 1.8},
    
    // Vegetables
    'broccoli': {'calories': 34, 'protein': 2.8, 'carbs': 7, 'fat': 0.4, 'fiber': 2.6},
    'spinach': {'calories': 23, 'protein': 2.9, 'carbs': 3.6, 'fat': 0.4, 'fiber': 2.2},
    'carrot': {'calories': 41, 'protein': 0.9, 'carbs': 10, 'fat': 0.2, 'fiber': 2.8},
    'tomato': {'calories': 18, 'protein': 0.9, 'carbs': 3.9, 'fat': 0.2, 'fiber': 1.2},
    'onion': {'calories': 40, 'protein': 1.1, 'carbs': 9.3, 'fat': 0.1, 'fiber': 1.7},
    'garlic': {'calories': 149, 'protein': 6.4, 'carbs': 33, 'fat': 0.5, 'fiber': 2.1},
    'potato': {'calories': 77, 'protein': 2, 'carbs': 17, 'fat': 0.1, 'fiber': 2.2},
    'sweet potato': {'calories': 86, 'protein': 1.6, 'carbs': 20, 'fat': 0.1, 'fiber': 3},
    'bell pepper': {'calories': 31, 'protein': 1, 'carbs': 7, 'fat': 0.3, 'fiber': 2.5},
    'cucumber': {'calories': 16, 'protein': 0.7, 'carbs': 4, 'fat': 0.1, 'fiber': 0.5},
    'lettuce': {'calories': 15, 'protein': 1.4, 'carbs': 2.9, 'fat': 0.2, 'fiber': 1.3},
    'cabbage': {'calories': 25, 'protein': 1.3, 'carbs': 6, 'fat': 0.1, 'fiber': 2.5},
    'eggplant': {'calories': 25, 'protein': 1, 'carbs': 6, 'fat': 0.2, 'fiber': 3},
    'zucchini': {'calories': 17, 'protein': 1.2, 'carbs': 3.1, 'fat': 0.3, 'fiber': 1},
    
    // Fruits
    'banana': {'calories': 89, 'protein': 1.1, 'carbs': 23, 'fat': 0.3, 'fiber': 2.6},
    'apple': {'calories': 52, 'protein': 0.3, 'carbs': 14, 'fat': 0.2, 'fiber': 2.4},
    'orange': {'calories': 47, 'protein': 0.9, 'carbs': 12, 'fat': 0.1, 'fiber': 2.4},
    'strawberry': {'calories': 32, 'protein': 0.7, 'carbs': 8, 'fat': 0.3, 'fiber': 2},
    'blueberry': {'calories': 57, 'protein': 0.7, 'carbs': 14, 'fat': 0.3, 'fiber': 2.4},
    'avocado': {'calories': 160, 'protein': 2, 'carbs': 9, 'fat': 15, 'fiber': 7},
    
    // Dairy
    'milk': {'calories': 42, 'protein': 3.4, 'carbs': 5, 'fat': 1, 'fiber': 0},
    'cheese': {'calories': 113, 'protein': 7, 'carbs': 1, 'fat': 9, 'fiber': 0},
    'yogurt': {'calories': 59, 'protein': 10, 'carbs': 3.6, 'fat': 0.4, 'fiber': 0},
    'butter': {'calories': 717, 'protein': 0.9, 'carbs': 0.1, 'fat': 81, 'fiber': 0},
    
    // Nuts and Seeds
    'almonds': {'calories': 579, 'protein': 21, 'carbs': 22, 'fat': 50, 'fiber': 12},
    'walnuts': {'calories': 654, 'protein': 15, 'carbs': 14, 'fat': 65, 'fiber': 6.7},
    'peanuts': {'calories': 567, 'protein': 26, 'carbs': 16, 'fat': 49, 'fiber': 8.5},
    'chia seeds': {'calories': 486, 'protein': 17, 'carbs': 42, 'fat': 31, 'fiber': 34},
    'flax seeds': {'calories': 534, 'protein': 18, 'carbs': 29, 'fat': 42, 'fiber': 28},
    
    // Oils and Fats
    'olive oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'coconut oil': {'calories': 862, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'vegetable oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    
    // Legumes
    'black beans': {'calories': 132, 'protein': 8.9, 'carbs': 24, 'fat': 0.5, 'fiber': 8.7},
    'chickpeas': {'calories': 164, 'protein': 8.9, 'carbs': 27, 'fat': 2.6, 'fiber': 7.6},
    'lentils': {'calories': 116, 'protein': 9, 'carbs': 20, 'fat': 0.4, 'fiber': 7.9},
    'kidney beans': {'calories': 127, 'protein': 8.7, 'carbs': 23, 'fat': 0.5, 'fiber': 6.4},
    
    // Spices and Herbs
    'salt': {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    'pepper': {'calories': 251, 'protein': 10, 'carbs': 64, 'fat': 3.3, 'fiber': 25},
    'garlic powder': {'calories': 331, 'protein': 16, 'carbs': 73, 'fat': 0.7, 'fiber': 9},
    'onion powder': {'calories': 341, 'protein': 10, 'carbs': 79, 'fat': 1, 'fiber': 15},
    'paprika': {'calories': 282, 'protein': 14, 'carbs': 54, 'fat': 12, 'fiber': 35},
    'cumin': {'calories': 375, 'protein': 18, 'carbs': 44, 'fat': 22, 'fiber': 11},
    'oregano': {'calories': 265, 'protein': 9, 'carbs': 69, 'fat': 4, 'fiber': 43},
    'basil': {'calories': 22, 'protein': 3.2, 'carbs': 2.6, 'fat': 0.6, 'fiber': 1.6},
    'parsley': {'calories': 36, 'protein': 3, 'carbs': 6, 'fat': 0.8, 'fiber': 3.3},
    'cilantro': {'calories': 23, 'protein': 2.1, 'carbs': 3.7, 'fat': 0.5, 'fiber': 2.8},
    
    // Condiments and Sauces
    'soy sauce': {'calories': 8, 'protein': 1.3, 'carbs': 0.8, 'fat': 0, 'fiber': 0.1},
    'vinegar': {'calories': 19, 'protein': 0, 'carbs': 0.9, 'fat': 0, 'fiber': 0},
    'ketchup': {'calories': 112, 'protein': 1.7, 'carbs': 27, 'fat': 0.1, 'fiber': 0.4},
    'mustard': {'calories': 66, 'protein': 4, 'carbs': 4, 'fat': 4, 'fiber': 3.3},
    'mayonnaise': {'calories': 680, 'protein': 1, 'carbs': 0.6, 'fat': 75, 'fiber': 0},
    'hot sauce': {'calories': 6, 'protein': 0.3, 'carbs': 1.3, 'fat': 0.1, 'fiber': 0.2},
    
    // Filipino specific ingredients
    'fish sauce': {'calories': 6, 'protein': 1.3, 'carbs': 0.6, 'fat': 0, 'fiber': 0},
    'coconut milk': {'calories': 230, 'protein': 2.3, 'carbs': 6, 'fat': 24, 'fiber': 2.2},
    'coconut cream': {'calories': 330, 'protein': 3.3, 'carbs': 6, 'fat': 35, 'fiber': 0},
    'palm oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'cane vinegar': {'calories': 19, 'protein': 0, 'carbs': 0.9, 'fat': 0, 'fiber': 0},
    'calamansi': {'calories': 22, 'protein': 0.4, 'carbs': 7, 'fat': 0.1, 'fiber': 0.1},
    'patis': {'calories': 6, 'protein': 1.3, 'carbs': 0.6, 'fat': 0, 'fiber': 0},
    'bagoong': {'calories': 47, 'protein': 7.1, 'carbs': 2.2, 'fat': 0.8, 'fiber': 0},
    'achuete': {'calories': 329, 'protein': 0, 'carbs': 61, 'fat': 0, 'fiber': 0},
    'tamarind': {'calories': 239, 'protein': 2.8, 'carbs': 63, 'fat': 0.6, 'fiber': 5.1},
    'bay leaves': {'calories': 313, 'protein': 8, 'carbs': 75, 'fat': 8, 'fiber': 26},
    'lemongrass': {'calories': 99, 'protein': 1.8, 'carbs': 25, 'fat': 0.5, 'fiber': 0},
    'ginger': {'calories': 80, 'protein': 1.8, 'carbs': 18, 'fat': 0.8, 'fiber': 2},
    'turmeric': {'calories': 354, 'protein': 8, 'carbs': 65, 'fat': 10, 'fiber': 21},
    'galangal': {'calories': 71, 'protein': 1, 'carbs': 15, 'fat': 1, 'fiber': 2},
    'kalamansi juice': {'calories': 22, 'protein': 0.4, 'carbs': 7, 'fat': 0.1, 'fiber': 0.1},
    'coconut water': {'calories': 19, 'protein': 0.7, 'carbs': 4, 'fat': 0.2, 'fiber': 0},
    'ube': {'calories': 82, 'protein': 1.4, 'carbs': 20, 'fat': 0.1, 'fiber': 2.3},
    'malunggay': {'calories': 64, 'protein': 9.4, 'carbs': 8.3, 'fat': 1.4, 'fiber': 2},
    'kangkong': {'calories': 19, 'protein': 2.6, 'carbs': 3.1, 'fat': 0.2, 'fiber': 1.1},
    'sitaw': {'calories': 31, 'protein': 1.8, 'carbs': 7, 'fat': 0.1, 'fiber': 2.5},
    'okra': {'calories': 33, 'protein': 1.9, 'carbs': 7, 'fat': 0.2, 'fiber': 3.2},
    'ampalaya': {'calories': 17, 'protein': 1, 'carbs': 3.7, 'fat': 0.2, 'fiber': 2.8},
    'talong': {'calories': 25, 'protein': 1, 'carbs': 6, 'fat': 0.2, 'fiber': 3},
    'gabi': {'calories': 112, 'protein': 1.5, 'carbs': 27, 'fat': 0.1, 'fiber': 4.1},
    'kamote': {'calories': 86, 'protein': 1.6, 'carbs': 20, 'fat': 0.1, 'fiber': 3},
    'saging': {'calories': 89, 'protein': 1.1, 'carbs': 23, 'fat': 0.3, 'fiber': 2.6},
    'mango': {'calories': 60, 'protein': 0.8, 'carbs': 15, 'fat': 0.4, 'fiber': 1.6},
    'papaya': {'calories': 43, 'protein': 0.5, 'carbs': 11, 'fat': 0.3, 'fiber': 1.7},
    'pineapple': {'calories': 50, 'protein': 0.5, 'carbs': 13, 'fat': 0.1, 'fiber': 1.4},
    'jackfruit': {'calories': 95, 'protein': 1.7, 'carbs': 23, 'fat': 0.6, 'fiber': 1.5},
    'durian': {'calories': 147, 'protein': 1.5, 'carbs': 27, 'fat': 5.3, 'fiber': 3.8},
    'rambutan': {'calories': 68, 'protein': 0.9, 'carbs': 16, 'fat': 0.2, 'fiber': 0.9},
    'lanzones': {'calories': 57, 'protein': 0.8, 'carbs': 14, 'fat': 0.1, 'fiber': 0.8},
    'chico': {'calories': 83, 'protein': 0.7, 'carbs': 20, 'fat': 0.4, 'fiber': 5.3},
    'santol': {'calories': 39, 'protein': 0.8, 'carbs': 9, 'fat': 0.1, 'fiber': 0.8},
    'atis': {'calories': 75, 'protein': 1.7, 'carbs': 19, 'fat': 0.6, 'fiber': 2.4},
    'guyabano': {'calories': 66, 'protein': 1, 'carbs': 17, 'fat': 0.3, 'fiber': 3.3},
    'duhat': {'calories': 60, 'protein': 0.7, 'carbs': 15, 'fat': 0.2, 'fiber': 0.9},
    'macopa': {'calories': 25, 'protein': 0.6, 'carbs': 6, 'fat': 0.1, 'fiber': 0.8},
    'balimbing': {'calories': 31, 'protein': 1, 'carbs': 7, 'fat': 0.1, 'fiber': 0.8},
    'kasoy': {'calories': 553, 'protein': 18, 'carbs': 30, 'fat': 44, 'fiber': 3.3},
    'pili': {'calories': 719, 'protein': 11, 'carbs': 4, 'fat': 79, 'fiber': 3.7},
    'buko': {'calories': 19, 'protein': 0.7, 'carbs': 4, 'fat': 0.2, 'fiber': 0},
    'niyog': {'calories': 354, 'protein': 3.3, 'carbs': 15, 'fat': 33, 'fiber': 9},
    'gata': {'calories': 230, 'protein': 2.3, 'carbs': 6, 'fat': 24, 'fiber': 2.2},
    'kakang gata': {'calories': 330, 'protein': 3.3, 'carbs': 6, 'fat': 35, 'fiber': 0},
    'tuba': {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    'lambanog': {'calories': 231, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    'tuba vinegar': {'calories': 19, 'protein': 0, 'carbs': 0.9, 'fat': 0, 'fiber': 0},
    'suka': {'calories': 19, 'protein': 0, 'carbs': 0.9, 'fat': 0, 'fiber': 0},
    'asin': {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    'paminta': {'calories': 251, 'protein': 10, 'carbs': 64, 'fat': 3.3, 'fiber': 25},
    'bawang': {'calories': 149, 'protein': 6.4, 'carbs': 33, 'fat': 0.5, 'fiber': 2.1},
    'sibuyas': {'calories': 40, 'protein': 1.1, 'carbs': 9.3, 'fat': 0.1, 'fiber': 1.7},
    'luya': {'calories': 80, 'protein': 1.8, 'carbs': 18, 'fat': 0.8, 'fiber': 2},
    'tanglad': {'calories': 99, 'protein': 1.8, 'carbs': 25, 'fat': 0.5, 'fiber': 0},
    'dahon ng laurel': {'calories': 313, 'protein': 8, 'carbs': 75, 'fat': 8, 'fiber': 26},
    'sili': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
    'siling labuyo': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
    'siling haba': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
    'siling mahaba': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
    'siling bilog': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
    'siling siling': {'calories': 40, 'protein': 1.9, 'carbs': 9, 'fat': 0.4, 'fiber': 1.5},
  };

  /// Calculate nutrition for a list of ingredients
  /// Calculate nutrition from a list of ingredient names (legacy method)
  static Future<Map<String, double>> calculateRecipeNutrition(List<String> ingredients) async {
    // Convert to ingredient objects format
    final ingredientObjects = ingredients.map((name) => {
      'name': name,
      'amount': 1.0,
      'unit': 'piece',
    }).toList();
    
    return calculateRecipeNutritionFromObjects(ingredientObjects);
  }

  /// Calculate nutrition from a list of ingredient objects with amounts and units
  static Future<Map<String, double>> calculateRecipeNutritionFromObjects(List<Map<String, dynamic>> ingredients) async {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;

    for (final ingredient in ingredients) {
      final name = ingredient['name']?.toString() ?? '';
      // Handle both int and double amounts
      final amount = (ingredient['amount'] is int) 
          ? (ingredient['amount'] as int).toDouble()
          : (ingredient['amount'] ?? 1.0) as double;
      final unit = ingredient['unit']?.toString() ?? '';
      
      if (name.isEmpty) continue;
      
      try {
        // Get base nutrition per 100g
        final baseNutrition = await _getIngredientNutrition(name);
        
        // Convert amount to grams
        final amountInGrams = _convertToGrams(amount, unit);
        
        // Calculate actual nutrition based on amount
        // Nutrition database values are typically per 100g
        final servingFactor = amountInGrams / 100.0;
        
        totalCalories += (baseNutrition['calories'] ?? 0) * servingFactor;
        totalProtein += (baseNutrition['protein'] ?? 0) * servingFactor;
        totalCarbs += (baseNutrition['carbs'] ?? 0) * servingFactor;
        totalFat += (baseNutrition['fat'] ?? 0) * servingFactor;
        totalFiber += (baseNutrition['fiber'] ?? 0) * servingFactor;
      } catch (e) {
        print('DEBUG: Error processing ingredient "$name": $e');
      }
    }

    // Apply realistic recipe scaling (not arbitrary!)
    // Most recipes serve 4-6 people, so scale down to single serving
    final servings = 4.0; // Average recipe serves 4
    final scaleFactor = 1.0 / servings;
    
    return {
      'calories': (totalCalories * scaleFactor).clamp(200.0, 1000.0),
      'protein': (totalProtein * scaleFactor).clamp(10.0, 80.0),
      'carbs': (totalCarbs * scaleFactor).clamp(20.0, 120.0),
      'fat': (totalFat * scaleFactor).clamp(5.0, 60.0),
      'fiber': (totalFiber * scaleFactor).clamp(2.0, 30.0),
    };
  }

  /// Convert various units to grams
  static double convertToGrams(double amount, String unit) {
    return _convertToGrams(amount, unit);
  }
  
  static double _convertToGrams(double amount, String unit) {
    final unitLower = unit.toLowerCase().trim();
    
    // Weight conversions
    switch (unitLower) {
      case 'g':
      case 'gram':
      case 'grams':
        return amount;
      
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return amount * 1000;
      
      case 'oz':
      case 'ounce':
      case 'ounces':
        return amount * 28.35;
      
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return amount * 453.592;
      
      // Volume to weight approximations (not perfect but close)
      case 'cup':
      case 'cups':
        return amount * 240; // ~240g per cup (water approximation)
      
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        return amount * 15; // ~15g per tablespoon
      
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return amount * 5; // ~5g per teaspoon
      
      case 'ml':
      case 'milliliter':
      case 'milliliters':
        return amount; // 1ml ≈ 1g for water
      
      case 'l':
      case 'liter':
      case 'liters':
        return amount * 1000; // 1L = 1000g
      
      case 'piece':
      case 'pieces':
      case 'pc':
      case 'pcs':
      case '':
        // If no unit specified, assume 100g per piece (average ingredient size)
        return amount * 100;
      
      // Common food approximations
      case 'slice':
        return amount * 20; // Average slice ~20g
      
      case 'can':
      case 'cans':
        return amount * 400; // Average can ~400g
      
      case 'jar':
      case 'jars':
        return amount * 200; // Average jar ~200g
      
      case 'bottle':
      case 'bottles':
        return amount * 500; // Average bottle ~500g
      
      case 'package':
      case 'packages':
      case 'pack':
      case 'packs':
        return amount * 150; // Average package ~150g
      
      case 'bag':
      case 'bags':
        return amount * 250; // Average bag ~250g
      
      case 'box':
      case 'boxes':
        return amount * 300; // Average box ~300g
      
      case 'head':
      case 'heads':
        return amount * 500; // Average head (lettuce, cabbage) ~500g
      
      case 'clove':
      case 'cloves':
        return amount * 3; // Average garlic clove ~3g
      
      default:
        // Unknown unit, assume 100g per unit
        return amount * 100;
    }
  }

  /// Convert dynamic map to Map<String, double> safely handling int/double types
  static Map<String, double> _convertToDoubleMap(dynamic data) {
    if (data == null) return {};
    
    final Map<String, double> result = {};
    final Map<String, dynamic> source = Map<String, dynamic>.from(data);
    
    for (final entry in source.entries) {
      final value = entry.value;
      if (value is num) {
        result[entry.key] = value.toDouble();
      } else if (value is String) {
        // Try to parse string numbers
        final parsed = double.tryParse(value);
        if (parsed != null) {
          result[entry.key] = parsed;
        }
      }
    }
    
    return result;
  }

  /// Get nutrition data for a specific ingredient
  static Future<Map<String, double>> _getIngredientNutrition(String ingredient) async {
    final lowerIngredient = ingredient.toLowerCase().trim();
    
    // Extract ingredient name by removing amounts and units
    final cleanIngredient = _extractIngredientName(lowerIngredient);
    print('DEBUG: Processing ingredient: "$ingredient" -> clean: "$cleanIngredient"');
    
    try {
      // Fetch from Firestore first
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final ingredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
        
        // Try exact match first with clean ingredient
        if (ingredients.containsKey(cleanIngredient)) {
          print('DEBUG: Found exact match in Firestore: $cleanIngredient');
          return _convertToDoubleMap(ingredients[cleanIngredient]);
        }
        
        // Try partial matches
        for (final entry in ingredients.entries) {
          if (cleanIngredient.contains(entry.key) || entry.key.contains(cleanIngredient)) {
            print('DEBUG: Found partial match in Firestore: ${entry.key}');
            return _convertToDoubleMap(entry.value);
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error fetching ingredient nutrition from Firestore: $e');
      // Fall back to hardcoded database if Firestore fails
    }
    
    // Fallback to hardcoded database
    if (_nutritionDatabase.containsKey(cleanIngredient)) {
      print('DEBUG: Found exact match in hardcoded DB: $cleanIngredient');
      return _nutritionDatabase[cleanIngredient]!;
    }
    
    // Try partial matches in hardcoded database
    for (final entry in _nutritionDatabase.entries) {
      if (cleanIngredient.contains(entry.key) || entry.key.contains(cleanIngredient)) {
        print('DEBUG: Found partial match in hardcoded DB: ${entry.key}');
        return entry.value;
      }
    }
    
    print('DEBUG: No match found for ingredient: $cleanIngredient, using default values');
    // Default nutrition for unknown ingredients
    return {
      'calories': 50,
      'protein': 2,
      'carbs': 8,
      'fat': 1,
      'fiber': 1,
    };
  }

  /// Extract ingredient name by removing amounts and units
  static String _extractIngredientName(String ingredient) {
    // Remove common measurement units and amounts
    String clean = ingredient
        .replaceAll(RegExp(r'^\d+\.?\d*\s*(g|kg|ml|l\b|oz|lb|cup|cups|tbsp|tsp|tablespoon|teaspoon|pound|ounce|gram|kilogram|liter|milliliter)\s*'), '')
        .replaceAll(RegExp(r'^\d+\.?\d*\s*'), '') // Remove leading numbers
        .replaceAll(RegExp(r'\s+\d+\.?\d*\s*(g|kg|ml|l\b|oz|lb|cup|cups|tbsp|tsp|tablespoon|teaspoon|pound|ounce|gram|kilogram|liter|milliliter)\s*'), ' ') // Remove numbers with units in middle
        .replaceAll(RegExp(r'\s+\d+\.?\d*\s*'), ' ') // Remove numbers in middle
        .trim();
    
    // Remove common descriptors and preparation methods
    clean = clean
        .replaceAll(RegExp(r'\b(fresh|dried|frozen|canned|chopped|diced|sliced|grated|minced|ground|whole|half|quarter|large|medium|small|big|tiny|peeled|crushed|finely|coarsely|roughly|thinly|thickly|julienned|cubed|strips|bunch|handful|pinch|dash|sprinkle)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();
    
    // Ensure we don't return empty string
    if (clean.isEmpty) {
      return ingredient.toLowerCase().trim();
    }
    
    return clean;
  }

  /// Save meal with calculated nutrition to Firestore
  static Future<void> saveMealWithNutrition({
    required String title,
    required String date,
    required String mealType,
    required List<String> ingredients,
    String? instructions,
    Map<String, double>? customNutrition,
    String? image,
    String? summary,
    String? description,
    String? cuisine,
    String? recipeId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Always recalculate nutrition to ensure consistency with new scaling system
    final nutrition = await calculateRecipeNutrition(ingredients);
    print('DEBUG: Saving meal "$title" with scaled nutrition: $nutrition');

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meals')
        .add({
      'title': title,
      'date': date,
      'mealType': mealType,
      'meal_type': mealType,
      'ingredients': ingredients,
      'instructions': instructions ?? '',
      'nutrition': nutrition,
      'image': image,
      'summary': summary,
      'description': description,
      'cuisine': cuisine,
      'recipeId': recipeId,
      'created_at': FieldValue.serverTimestamp(),
      'source': 'manual_entry',
    });
  }

  /// Get daily nutrition for a specific date
  static Future<Map<String, double>> getDailyNutrition(String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final mealsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('date', isEqualTo: date)
          .get();

      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      double totalFiber = 0;

      for (final doc in mealsQuery.docs) {
        final data = doc.data();
        final nutrition = data['nutrition'] as Map<String, dynamic>? ?? {};
        
        totalCalories += (nutrition['calories'] ?? 0).toDouble();
        totalProtein += (nutrition['protein'] ?? 0).toDouble();
        totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
        totalFat += (nutrition['fat'] ?? 0).toDouble();
        totalFiber += (nutrition['fiber'] ?? 0).toDouble();
      }

      return {
        'calories': totalCalories,
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fat': totalFat,
        'fiber': totalFiber,
      };
    } catch (e) {
      print('Error getting daily nutrition: $e');
      return {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'fiber': 0,
      };
    }
  }

  /// Get nutrition goals for a user
  static Future<Map<String, double>> getNutritionGoals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'calories': (data['daily_calories'] ?? 2000).toDouble(),
          'protein': (data['daily_protein'] ?? 150).toDouble(),
          'carbs': (data['daily_carbs'] ?? 250).toDouble(),
          'fat': (data['daily_fat'] ?? 67).toDouble(),
          'fiber': (data['daily_fiber'] ?? 25).toDouble(),
        };
      }
    } catch (e) {
      print('Error getting nutrition goals: $e');
    }

    // Default goals
    return {
      'calories': 2000,
      'protein': 150,
      'carbs': 250,
      'fat': 67,
      'fiber': 25,
    };
  }

  /// Calculate daily nutrition from meals
  static Map<String, double> calculateDailyNutrition(List<Map<String, dynamic>> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;

    for (final meal in meals) {
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      if (nutrition != null) {
        totalCalories += (nutrition['calories'] ?? 0).toDouble();
        totalProtein += (nutrition['protein'] ?? 0).toDouble();
        totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
        totalFat += (nutrition['fat'] ?? 0).toDouble();
        totalFiber += (nutrition['fiber'] ?? 0).toDouble();
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
    };
  }

  /// Calculate weekly nutrition averages
  static Map<String, double> calculateWeeklyAverages(Map<String, List<Map<String, dynamic>>> weeklyMeals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    int dayCount = 0;

    for (final dayMeals in weeklyMeals.values) {
      if (dayMeals.isNotEmpty) {
        final dayNutrition = calculateDailyNutrition(dayMeals);
        totalCalories += dayNutrition['calories'] ?? 0;
        totalProtein += dayNutrition['protein'] ?? 0;
        totalCarbs += dayNutrition['carbs'] ?? 0;
        totalFat += dayNutrition['fat'] ?? 0;
        totalFiber += dayNutrition['fiber'] ?? 0;
        dayCount++;
      }
    }

    if (dayCount == 0) {
      return {
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'fiber': 0,
      };
    }

    return {
      'calories': totalCalories / dayCount,
      'protein': totalProtein / dayCount,
      'carbs': totalCarbs / dayCount,
      'fat': totalFat / dayCount,
      'fiber': totalFiber / dayCount,
    };
  }

  /// Get empty nutrition map
  static Map<String, double> getEmptyNutrition() {
    return {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
    };
  }

  /// Convert any value to double safely
  static double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Recalculate nutrition for existing meals with old high values
  static Future<void> recalculateExistingMealNutrition(String mealId, List<String> ingredients) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Calculate new nutrition with scaling
      final newNutrition = await calculateRecipeNutrition(ingredients);
      print('DEBUG: Recalculating nutrition for meal $mealId: $newNutrition');

      // Update the meal in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .doc(mealId)
          .update({
        'nutrition': newNutrition,
      });
    } catch (e) {
      print('DEBUG: Error recalculating nutrition for meal $mealId: $e');
    }
  }
}
