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
                     // Try more flexible matching for substitutions with parentheses
                     else {
                       // Extract key words from both strings for comparison
                       final substitutionWords = substitutionText.toLowerCase().split(RegExp(r'[^a-z]')).where((w) => w.isNotEmpty).toSet();
                       final searchWords = substitution.toLowerCase().split(RegExp(r'[^a-z]')).where((w) => w.isNotEmpty).toSet();
                       
                       // Check if there's significant overlap in key words
                       final commonWords = substitutionWords.intersection(searchWords);
                       
                       // For better matching, prioritize exact ingredient name matches
                       final hasExactIngredientMatch = commonWords.any((word) => 
                         word == 'banana' || word == 'applesauce' || word == 'tofu' || 
                         word == 'flax' || word == 'chia' || word == 'commercial');
                       
                       if (hasExactIngredientMatch || (commonWords.length >= 2 && commonWords.any((word) => word.length > 3))) {
                         print('DEBUG: Flexible match found: "$substitutionText" matches "$substitution" (common words: $commonWords)');
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
      
      // First check if this is actually a substituted recipe
      if (recipe['substituted'] != true) {
        print('DEBUG: Non-substituted recipe, returning current nutrition');
        // Safely convert nutrition values to double
        final currentNutrition = <String, double>{};
        if (recipe['nutrition'] != null) {
          for (final entry in (recipe['nutrition'] as Map).entries) {
            currentNutrition[entry.key] = (entry.value as num).toDouble();
          }
        }
        return currentNutrition;
      }
      
      // For substituted recipes, check if nutrition has already been recalculated
      if (recipe['substituted'] == true) {
        // Check if originalNutrition exists and is different from current nutrition
        if (recipe['originalNutrition'] != null) {
          final originalCalories = (recipe['originalNutrition']['calories'] as num?)?.toDouble() ?? 0;
          final currentCalories = (recipe['nutrition']['calories'] as num?)?.toDouble() ?? 0;
          
          print('DEBUG: Original: $originalCalories cal, Current: $currentCalories cal');
          
          // If current nutrition is 0.0, it hasn't been calculated yet - we need to recalculate
          // If current nutrition is already significantly different from original, it's been recalculated
          if (currentCalories > 0.0 && (currentCalories - originalCalories).abs() > 100.0) {
            print('DEBUG: Nutrition already recalculated, returning current values');
            // Safely convert nutrition values to double
            final currentNutrition = <String, double>{};
            for (final entry in (recipe['nutrition'] as Map).entries) {
              currentNutrition[entry.key] = (entry.value as num).toDouble();
            }
            return currentNutrition;
          }
        }
        
        // Recalculate nutrition for the entire recipe with substituted ingredients
        print('DEBUG: Recalculating nutrition for entire recipe with substitutions');
        
        // Get ingredients from either 'extendedIngredients' or 'ingredients' field
        List<dynamic> ingredients = [];
        if (recipe['extendedIngredients'] != null) {
          ingredients = recipe['extendedIngredients'] as List<dynamic>;
          print('DEBUG: Using extendedIngredients field with ${ingredients.length} items');
        } else if (recipe['ingredients'] != null) {
          ingredients = recipe['ingredients'] as List<dynamic>;
          print('DEBUG: Using ingredients field with ${ingredients.length} items');
        }
        
        // Convert ingredients to the format expected by NutritionService
        final nutritionIngredients = <String>[];
        
        for (final ingredient in ingredients) {
          String ingredientName;
          bool isSubstitution = false;
          
          print('DEBUG: Raw ingredient data: $ingredient');
          
          if (ingredient is String) {
            ingredientName = ingredient;
            // Check if this is a substitution (contains parentheses and "per")
            isSubstitution = ingredient.contains('(') && ingredient.contains('per');
            print('DEBUG: String ingredient "$ingredientName" - substitution: $isSubstitution');
          } else if (ingredient is Map<String, dynamic>) {
            // Handle extendedIngredients format
            ingredientName = ingredient['name']?.toString() ?? '';
            final substitutedFlag = ingredient['substituted'];
            print('DEBUG: Map ingredient "$ingredientName" - substituted flag: $substitutedFlag (type: ${substitutedFlag.runtimeType})');
            
            // Check if it's marked as substituted OR if the name contains substitution patterns
            isSubstitution = substitutedFlag == true || 
                            (ingredientName.contains('(') && ingredientName.contains('per')) ||
                            ingredientName.contains('for ') ||
                            ingredientName.contains('substitute') ||
                            ingredientName.contains('Banana') ||
                            ingredientName.contains('Applesauce') ||
                            ingredientName.contains('Tofu');
            
            print('DEBUG: Map ingredient "$ingredientName" - final substitution: $isSubstitution');
          } else {
            print('DEBUG: Skipping invalid ingredient type: ${ingredient.runtimeType}');
            continue; // Skip invalid ingredients
          }
          
          if (isSubstitution) {
            print('DEBUG: Processing substitution: "$ingredientName"');
            
            // For substituted ingredients, use the substitution name for nutrition calculation
            nutritionIngredients.add(ingredientName.toLowerCase());
          } else {
            // For regular ingredients, use the clean name
            String cleanName = ingredientName;
            if (ingredient is Map<String, dynamic>) {
              cleanName = ingredient['nameClean']?.toString() ?? ingredientName;
            }
            nutritionIngredients.add(cleanName.toLowerCase());
          }
        }
        
        print('DEBUG: Final ingredients for nutrition calculation: $nutritionIngredients');
        
        // Calculate nutrition for the entire recipe
        final adjustedNutrition = await NutritionService.calculateRecipeNutrition(nutritionIngredients);
        print('DEBUG: Calculated nutrition for substituted recipe: $adjustedNutrition');
        
        // Ensure no negative values
        adjustedNutrition['calories'] = adjustedNutrition['calories']!.clamp(0.0, double.infinity);
        adjustedNutrition['protein'] = adjustedNutrition['protein']!.clamp(0.0, double.infinity);
        adjustedNutrition['carbs'] = adjustedNutrition['carbs']!.clamp(0.0, double.infinity);
        adjustedNutrition['fat'] = adjustedNutrition['fat']!.clamp(0.0, double.infinity);
        adjustedNutrition['fiber'] = adjustedNutrition['fiber']!.clamp(0.0, double.infinity);
        
        print('DEBUG: Final adjusted nutrition:');
        print('  - Calories: ${adjustedNutrition['calories']}');
        print('  - Protein: ${adjustedNutrition['protein']}');
        print('  - Carbs: ${adjustedNutrition['carbs']}');
        print('  - Fat: ${adjustedNutrition['fat']}');
        print('  - Fiber: ${adjustedNutrition['fiber']}');
        
        return adjustedNutrition;
      }
      
      // For non-substituted recipes, return current nutrition
      print('DEBUG: Non-substituted recipe, returning current nutrition');
      // Safely convert nutrition values to double
      final currentNutrition = <String, double>{};
      if (recipe['nutrition'] != null) {
        for (final entry in (recipe['nutrition'] as Map).entries) {
          currentNutrition[entry.key] = (entry.value as num).toDouble();
        }
      }
      return currentNutrition;
    } catch (e) {
      print('Error recalculating nutrition with substitutions: $e');
      // Return original nutrition as fallback
      final fallbackNutrition = <String, double>{};
      if (recipe['nutrition'] != null) {
        for (final entry in (recipe['nutrition'] as Map).entries) {
          fallbackNutrition[entry.key] = (entry.value as num).toDouble();
        }
      }
      return fallbackNutrition;
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
