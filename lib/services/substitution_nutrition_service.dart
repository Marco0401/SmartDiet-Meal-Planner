import 'package:cloud_firestore/cloud_firestore.dart';
import 'nutrition_service.dart';

class SubstitutionNutritionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get nutrition data for a specific substitution
  static Future<Map<String, double>?> getSubstitutionNutrition(String substitution) async {
    try {
      print('DEBUG: Looking for nutrition data for substitution: "$substitution"');
      
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
        
        print('DEBUG: Available substitution categories: ${substitutionsData.keys.toList()}');
        
        // Search through all allergen categories
        for (final category in substitutionsData.keys) {
          final substitutions = substitutionsData[category] as List<dynamic>? ?? [];
          print('DEBUG: Searching in category "$category" with ${substitutions.length} substitutions');
          
          for (final sub in substitutions) {
            if (sub is Map<String, dynamic>) {
              final substitutionText = sub['substitution']?.toString() ?? '';
              print('DEBUG: Checking substitution: "$substitutionText"');
              
              // Extract the main ingredient name (before any parentheses or additional text)
              final mainIngredient = substitutionText.split('(')[0].trim().toLowerCase();
              final searchIngredient = substitution.toLowerCase();
              
              // Try exact match first
              if (substitutionText.toLowerCase() == substitution.toLowerCase()) {
                print('DEBUG: Exact match found: "$substitutionText"');
                final nutrition = sub['nutrition'] as Map<String, dynamic>?;
                if (nutrition != null) {
                  print('DEBUG: Found nutrition data: $nutrition');
                  // Convert all values to double, handling both int and double types
                  final convertedNutrition = <String, double>{};
                  for (final entry in nutrition.entries) {
                    convertedNutrition[entry.key] = (entry.value as num).toDouble();
                  }
                  return convertedNutrition;
                }
              }
              // Try partial match with main ingredient
              else if (mainIngredient == searchIngredient || 
                       substitution.toLowerCase().contains(mainIngredient) ||
                       mainIngredient.contains(searchIngredient)) {
                print('DEBUG: Partial match found: "$substitutionText" matches "$substitution"');
                final nutrition = sub['nutrition'] as Map<String, dynamic>?;
                if (nutrition != null) {
                  print('DEBUG: Found nutrition data: $nutrition');
                  // Convert all values to double, handling both int and double types
                  final convertedNutrition = <String, double>{};
                  for (final entry in nutrition.entries) {
                    convertedNutrition[entry.key] = (entry.value as num).toDouble();
                  }
                  return convertedNutrition;
                }
              }
            }
          }
        }
      }
      
      print('DEBUG: No nutrition data found for substitution: "$substitution"');
    } catch (e) {
      print('Error getting substitution nutrition: $e');
    }
    
    return null;
  }
  
  /// Recalculate nutrition for a recipe with substitutions
  static Future<Map<String, double>> recalculateNutritionWithSubstitutions(
    Map<String, dynamic> recipe,
  ) async {
    try {
      print('DEBUG: Starting nutrition recalculation for recipe: ${recipe['title']}');
      
      // For substituted recipes, check if nutrition has already been recalculated
      if (recipe['substituted'] == true) {
        // Check if originalNutrition exists and is different from current nutrition
        if (recipe['originalNutrition'] != null) {
          final originalCalories = (recipe['originalNutrition']['calories'] as num?)?.toDouble() ?? 0;
          final currentCalories = (recipe['nutrition']['calories'] as num?)?.toDouble() ?? 0;
          
          print('DEBUG: Original: $originalCalories cal, Current: $currentCalories cal');
          
          // If current nutrition is already significantly different from original, it's been recalculated
          if ((currentCalories - originalCalories).abs() > 100.0) {
            print('DEBUG: Nutrition already recalculated, returning current values');
            return Map<String, double>.from(recipe['nutrition']);
          }
        }
        
        // Use the existing NutritionService to recalculate the recipe
        print('DEBUG: Using NutritionService to recalculate recipe nutrition');
        
        // Convert ingredients to the format expected by NutritionService
        final ingredients = <String>[];
        final regularIngredients = recipe['ingredients'] as List<dynamic>? ?? [];
        
        for (final ingredient in regularIngredients) {
          if (ingredient is String) {
            // Check if this is a substitution
            if (ingredient.contains('(') && ingredient.contains('per') && ingredient.contains('egg')) {
              // Extract the substitution name (before parentheses)
              final substitutionName = ingredient.split('(')[0].trim().toLowerCase();
              print('DEBUG: Found substitution: $substitutionName');
              
              // Add substitution ingredient as string
              ingredients.add(substitutionName);
            } else {
              // Regular ingredient - add as is
              ingredients.add(ingredient.toLowerCase());
            }
          }
        }
        
        print('DEBUG: Parsed ingredients for recalculation: $ingredients');
        
        // Use NutritionService to calculate nutrition
        final calculatedNutrition = await NutritionService.calculateRecipeNutrition(ingredients);
        
        print('DEBUG: Final adjusted nutrition:');
        print('  - Calories: ${calculatedNutrition['calories']}');
        print('  - Protein: ${calculatedNutrition['protein']}');
        print('  - Carbs: ${calculatedNutrition['carbs']}');
        print('  - Fat: ${calculatedNutrition['fat']}');
        print('  - Fiber: ${calculatedNutrition['fiber']}');
        
        return Map<String, double>.from(calculatedNutrition);
      }
      
      // For non-substituted recipes, return current nutrition
      print('DEBUG: Non-substituted recipe, returning current nutrition');
      return Map<String, double>.from(recipe['nutrition'] ?? {});
    } catch (e) {
      print('Error recalculating nutrition with substitutions: $e');
      // Return original nutrition as fallback
      return Map<String, double>.from(recipe['nutrition'] ?? {});
    }
  }
  
  /// Parse ingredient string to extract name, amount, and unit
  static Map<String, dynamic>? _parseIngredient(String ingredient) {
    try {
      // Simple parsing for common patterns like "100g Flour", "300ml Milk", etc.
      final parts = ingredient.trim().split(' ');
      if (parts.length >= 2) {
        final amountStr = parts[0];
        final name = parts.sublist(1).join(' ').toLowerCase();
        
        // Extract numeric amount
        double amount = 1.0;
        String unit = 'piece';
        
        if (amountStr.contains('g')) {
          amount = double.tryParse(amountStr.replaceAll('g', '')) ?? 1.0;
          unit = 'g';
        } else if (amountStr.contains('ml')) {
          amount = double.tryParse(amountStr.replaceAll('ml', '')) ?? 1.0;
          unit = 'ml';
        } else if (amountStr.contains('tbsp') || amountStr.contains('tbls')) {
          amount = double.tryParse(amountStr.replaceAll(RegExp(r'[a-zA-Z]'), '')) ?? 1.0;
          unit = 'tbsp';
        } else if (amountStr.contains('tsp')) {
          amount = double.tryParse(amountStr.replaceAll(RegExp(r'[a-zA-Z]'), '')) ?? 1.0;
          unit = 'tsp';
        } else if (amountStr.contains('cup')) {
          amount = double.tryParse(amountStr.replaceAll(RegExp(r'[a-zA-Z]'), '')) ?? 1.0;
          unit = 'cup';
        } else {
          // Try to parse as number
          amount = double.tryParse(amountStr) ?? 1.0;
        }
        
        return {
          'name': name,
          'amount': amount,
          'unit': unit,
        };
      }
    } catch (e) {
      print('DEBUG: Error parsing ingredient "$ingredient": $e');
    }
    
    return null;
  }
  
  /// Initialize default substitution nutrition data
  static Future<void> initializeDefaultSubstitutionData() async {
    try {
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (!doc.exists) {
        // Create default substitution data with new consolidated structure
        final defaultSubstitutions = {
          'eggs': [
            {
              'substitution': 'Silken tofu (1/4 cup per egg)',
              'nutrition': {
                'calories': 35.0,
                'protein': 4.0,
                'carbs': 2.0,
                'fat': 2.0,
                'fiber': 0.5,
                'sugar': 0.0,
                'sodium': 5.0,
                'cholesterol': 0.0,
              },
            },
            {
              'substitution': 'Banana (1/2 mashed banana per egg)',
              'nutrition': {
                'calories': 50.0,
                'protein': 0.6,
                'carbs': 12.0,
                'fat': 0.2,
                'fiber': 1.5,
                'sugar': 6.0,
                'sodium': 1.0,
                'cholesterol': 0.0,
              },
            },
          ],
          'dairy': [
            {
              'substitution': 'Almond milk',
              'nutrition': {
                'calories': 17.0,
                'protein': 0.6,
                'carbs': 1.5,
                'fat': 1.1,
                'fiber': 0.4,
                'sugar': 0.0,
                'sodium': 63.0,
                'cholesterol': 0.0,
              },
            },
            {
              'substitution': 'Coconut milk',
              'nutrition': {
                'calories': 230.0,
                'protein': 2.3,
                'carbs': 6.0,
                'fat': 24.0,
                'fiber': 2.2,
                'sugar': 3.0,
                'sodium': 13.0,
                'cholesterol': 0.0,
              },
            },
          ],
          'wheat': [
            {
              'substitution': 'Almond flour',
              'nutrition': {
                'calories': 600.0,
                'protein': 21.0,
                'carbs': 22.0,
                'fat': 54.0,
                'fiber': 12.0,
                'sugar': 4.0,
                'sodium': 0.0,
                'cholesterol': 0.0,
              },
            },
          ],
        };
        
        await _firestore
            .collection('system_data')
            .doc('substitutions')
            .set({
          'data': defaultSubstitutions,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        print('DEBUG: Initialized default substitution nutrition data');
      }
    } catch (e) {
      print('Error initializing default substitution data: $e');
    }
  }
}
