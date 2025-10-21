import 'package:cloud_firestore/cloud_firestore.dart';

class MigrateSubstitutionNutrition {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrates all existing string substitutions to the new consolidated format with nutrition data
  static Future<void> migrateAllSubstitutions() async {
    try {
      print('🔄 Starting migration of substitution nutrition data...');
      
      // Get current substitutions document
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (!doc.exists) {
        print('❌ No substitutions document found');
        return;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
      
      print('📊 Current data structure:');
      for (final category in substitutionsData.keys) {
        final substitutions = substitutionsData[category];
        if (substitutions is List) {
          print('  $category: ${substitutions.length} items');
        }
      }
      
      // Create new consolidated data structure
      final newSubstitutionsData = <String, List<Map<String, dynamic>>>{};
      
      // Process each allergen category
      final allergenCategories = ['dairy', 'eggs', 'fish', 'peanuts', 'shellfish', 'soy', 'tree_nuts', 'wheat'];
      
      for (final category in allergenCategories) {
        final substitutions = substitutionsData[category];
        if (substitutions == null) continue;
        
        final newSubstitutions = <Map<String, dynamic>>[];
        
        if (substitutions is List) {
          for (final substitution in substitutions) {
            if (substitution is String) {
              // Old format - convert to new format with nutrition
              final nutritionData = _getNutritionForSubstitution(category, substitution);
              newSubstitutions.add({
                'substitution': substitution,
                'nutrition': nutritionData,
              });
            } else if (substitution is Map<String, dynamic>) {
              // Already new format - keep as is
              newSubstitutions.add(substitution);
            }
          }
        }
        
        newSubstitutionsData[category] = newSubstitutions;
        print('✅ Migrated $category: ${newSubstitutions.length} substitutions');
      }
      
      // Update Firestore with new structure
      await _firestore
          .collection('system_data')
          .doc('substitutions')
          .update({
        'data': newSubstitutionsData,
        'migratedAt': DateTime.now().toIso8601String(),
        'version': '2.0',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('🎉 Migration completed successfully!');
      print('📈 Total substitutions migrated: ${newSubstitutionsData.values.fold(0, (sum, list) => sum + list.length)}');
      
    } catch (e) {
      print('❌ Error during migration: $e');
      rethrow;
    }
  }

  /// Gets nutrition data for a specific substitution based on category and substitution text
  static Map<String, double> _getNutritionForSubstitution(String category, String substitution) {
    // Comprehensive nutrition database for all substitutions
    final nutritionDatabase = {
      'dairy': {
        'Almond milk for cow milk': {
          'calories': 17.0,
          'protein': 0.6,
          'carbs': 1.5,
          'fat': 1.1,
          'fiber': 0.4,
          'sugar': 0.0,
          'sodium': 63.0,
          'cholesterol': 0.0,
        },
        'Coconut milk for heavy cream': {
          'calories': 230.0,
          'protein': 2.3,
          'carbs': 6.0,
          'fat': 24.0,
          'fiber': 2.2,
          'sugar': 3.0,
          'sodium': 13.0,
          'cholesterol': 0.0,
        },
        'Oat milk for regular milk': {
          'calories': 43.0,
          'protein': 1.0,
          'carbs': 7.0,
          'fat': 1.5,
          'fiber': 0.8,
          'sugar': 2.0,
          'sodium': 15.0,
          'cholesterol': 0.0,
        },
        'Cashew cream for sour cream': {
          'calories': 157.0,
          'protein': 5.2,
          'carbs': 8.9,
          'fat': 12.4,
          'fiber': 0.9,
          'sugar': 1.7,
          'sodium': 3.0,
          'cholesterol': 0.0,
        },
        'Nutritional yeast for cheese': {
          'calories': 325.0,
          'protein': 50.0,
          'carbs': 38.0,
          'fat': 5.0,
          'fiber': 25.0,
          'sugar': 0.0,
          'sodium': 25.0,
          'cholesterol': 0.0,
        },
        'Coconut oil for butter': {
          'calories': 862.0,
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 100.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 0.0,
          'cholesterol': 0.0,
        },
        'Vegan butter for regular butter': {
          'calories': 714.0,
          'protein': 0.0,
          'carbs': 0.0,
          'fat': 80.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 600.0,
          'cholesterol': 0.0,
        },
      },
      'eggs': {
        'Flax eggs (1 tbsp ground flaxseed + 3 tbsp water)': {
          'calories': 37.0,
          'protein': 1.3,
          'carbs': 2.0,
          'fat': 3.0,
          'fiber': 1.9,
          'sugar': 0.1,
          'sodium': 2.0,
          'cholesterol': 0.0,
        },
        'Chia eggs (1 tbsp chia seeds + 3 tbsp water)': {
          'calories': 60.0,
          'protein': 2.0,
          'carbs': 5.0,
          'fat': 4.0,
          'fiber': 4.0,
          'sugar': 0.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Applesauce (1/4 cup per egg)': {
          'calories': 25.0,
          'protein': 0.1,
          'carbs': 6.6,
          'fat': 0.1,
          'fiber': 1.2,
          'sugar': 5.5,
          'sodium': 0.0,
          'cholesterol': 0.0,
        },
        'Banana (1/2 mashed banana per egg)': {
          'calories': 50.0,
          'protein': 0.6,
          'carbs': 12.0,
          'fat': 0.2,
          'fiber': 1.5,
          'sugar': 6.0,
          'sodium': 1.0,
          'cholesterol': 0.0,
        },
        'Commercial egg replacer': {
          'calories': 20.0,
          'protein': 1.0,
          'carbs': 4.0,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 200.0,
          'cholesterol': 0.0,
        },
        'Silken tofu (1/4 cup per egg)': {
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
      'fish': {
        'Tofu for fish proteinsss': {
          'calories': 76.0,
          'protein': 8.0,
          'carbs': 1.9,
          'fat': 4.8,
          'fiber': 0.3,
          'sugar': 0.6,
          'sodium': 7.0,
          'cholesterol': 0.0,
        },
        'Mushrooms for fish texture': {
          'calories': 22.0,
          'protein': 3.1,
          'carbs': 3.3,
          'fat': 0.3,
          'fiber': 1.0,
          'sugar': 2.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Jackfruit for fish flakes': {
          'calories': 95.0,
          'protein': 1.7,
          'carbs': 23.0,
          'fat': 0.6,
          'fiber': 1.5,
          'sugar': 19.0,
          'sodium': 2.0,
          'cholesterol': 0.0,
        },
        'Seaweed for fish flavor': {
          'calories': 35.0,
          'protein': 5.8,
          'carbs': 5.1,
          'fat': 0.6,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 2300.0,
          'cholesterol': 0.0,
        },
        'Plant-based fish alternatives': {
          'calories': 120.0,
          'protein': 12.0,
          'carbs': 8.0,
          'fat': 4.0,
          'fiber': 2.0,
          'sugar': 1.0,
          'sodium': 300.0,
          'cholesterol': 0.0,
        },
        'Tempeh for fish protein': {
          'calories': 192.0,
          'protein': 20.0,
          'carbs': 7.6,
          'fat': 11.0,
          'fiber': 9.0,
          'sugar': 0.0,
          'sodium': 9.0,
          'cholesterol': 0.0,
        },
      },
      'peanuts': {
        'Sunflower seed butter': {
          'calories': 200.0,
          'protein': 6.0,
          'carbs': 6.0,
          'fat': 18.0,
          'fiber': 3.0,
          'sugar': 2.0,
          'sodium': 100.0,
          'cholesterol': 0.0,
        },
        'Almond butter (if no tree nut allergy)': {
          'calories': 190.0,
          'protein': 7.0,
          'carbs': 6.0,
          'fat': 18.0,
          'fiber': 3.0,
          'sugar': 1.0,
          'sodium': 0.0,
          'cholesterol': 0.0,
        },
        'Soy butter': {
          'calories': 180.0,
          'protein': 8.0,
          'carbs': 8.0,
          'fat': 14.0,
          'fiber': 2.0,
          'sugar': 2.0,
          'sodium': 150.0,
          'cholesterol': 0.0,
        },
        'Tahini (sesame seed butter)': {
          'calories': 178.0,
          'protein': 5.0,
          'carbs': 6.0,
          'fat': 16.0,
          'fiber': 2.0,
          'sugar': 0.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Coconut butter': {
          'calories': 200.0,
          'protein': 2.0,
          'carbs': 6.0,
          'fat': 20.0,
          'fiber': 4.0,
          'sugar': 2.0,
          'sodium': 10.0,
          'cholesterol': 0.0,
        },
        'Pumpkin seed butter': {
          'calories': 190.0,
          'protein': 8.0,
          'carbs': 4.0,
          'fat': 18.0,
          'fiber': 2.0,
          'sugar': 1.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
      },
      'shellfish': {
        'Mushrooms for shellfish texture': {
          'calories': 22.0,
          'protein': 3.1,
          'carbs': 3.3,
          'fat': 0.3,
          'fiber': 1.0,
          'sugar': 2.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Hearts of palm for scallops': {
          'calories': 23.0,
          'protein': 2.0,
          'carbs': 4.0,
          'fat': 0.5,
          'fiber': 2.0,
          'sugar': 0.0,
          'sodium': 14.0,
          'cholesterol': 0.0,
        },
        'Artichoke hearts for crab': {
          'calories': 25.0,
          'protein': 3.0,
          'carbs': 5.0,
          'fat': 0.2,
          'fiber': 5.0,
          'sugar': 1.0,
          'sodium': 296.0,
          'cholesterol': 0.0,
        },
        'Jackfruit for lobster': {
          'calories': 95.0,
          'protein': 1.7,
          'carbs': 23.0,
          'fat': 0.6,
          'fiber': 1.5,
          'sugar': 19.0,
          'sodium': 2.0,
          'cholesterol': 0.0,
        },
        'Plant-based shellfish alternatives': {
          'calories': 100.0,
          'protein': 10.0,
          'carbs': 6.0,
          'fat': 3.0,
          'fiber': 1.0,
          'sugar': 1.0,
          'sodium': 250.0,
          'cholesterol': 0.0,
        },
        'Tofu for shrimp texture': {
          'calories': 76.0,
          'protein': 8.0,
          'carbs': 1.9,
          'fat': 4.8,
          'fiber': 0.3,
          'sugar': 0.6,
          'sodium': 7.0,
          'cholesterol': 0.0,
        },
      },
      'soy': {
        'Coconut aminos for soy sauce': {
          'calories': 15.0,
          'protein': 0.0,
          'carbs': 3.0,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 2.0,
          'sodium': 270.0,
          'cholesterol': 0.0,
        },
        'Tamari (wheat-free soy sauce)': {
          'calories': 8.0,
          'protein': 1.0,
          'carbs': 1.0,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 920.0,
          'cholesterol': 0.0,
        },
        'Liquid aminos': {
          'calories': 10.0,
          'protein': 2.0,
          'carbs': 2.0,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 0.0,
          'sodium': 160.0,
          'cholesterol': 0.0,
        },
        'Miso alternatives': {
          'calories': 30.0,
          'protein': 2.0,
          'carbs': 4.0,
          'fat': 1.0,
          'fiber': 1.0,
          'sugar': 1.0,
          'sodium': 600.0,
          'cholesterol': 0.0,
        },
        'Tempeh alternatives': {
          'calories': 192.0,
          'protein': 20.0,
          'carbs': 7.6,
          'fat': 11.0,
          'fiber': 9.0,
          'sugar': 0.0,
          'sodium': 9.0,
          'cholesterol': 0.0,
        },
        'Tofu alternatives': {
          'calories': 76.0,
          'protein': 8.0,
          'carbs': 1.9,
          'fat': 4.8,
          'fiber': 0.3,
          'sugar': 0.6,
          'sodium': 7.0,
          'cholesterol': 0.0,
        },
      },
      'tree_nuts': {
        'Sunflower seeds for nuts': {
          'calories': 164.0,
          'protein': 5.8,
          'carbs': 6.0,
          'fat': 14.0,
          'fiber': 3.0,
          'sugar': 0.0,
          'sodium': 1.0,
          'cholesterol': 0.0,
        },
        'Pumpkin seeds for nuts': {
          'calories': 125.0,
          'protein': 5.0,
          'carbs': 4.0,
          'fat': 10.0,
          'fiber': 2.0,
          'sugar': 0.0,
          'sodium': 2.0,
          'cholesterol': 0.0,
        },
        'Oats for nut texture': {
          'calories': 68.0,
          'protein': 2.4,
          'carbs': 12.0,
          'fat': 1.4,
          'fiber': 1.7,
          'sugar': 0.0,
          'sodium': 1.0,
          'cholesterol': 0.0,
        },
        'Coconut for nut flavor': {
          'calories': 354.0,
          'protein': 3.3,
          'carbs': 15.0,
          'fat': 33.0,
          'fiber': 9.0,
          'sugar': 6.0,
          'sodium': 20.0,
          'cholesterol': 0.0,
        },
        'Seeds for nut protein': {
          'calories': 150.0,
          'protein': 6.0,
          'carbs': 5.0,
          'fat': 12.0,
          'fiber': 2.0,
          'sugar': 1.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Plant-based nut alternatives': {
          'calories': 180.0,
          'protein': 8.0,
          'carbs': 8.0,
          'fat': 14.0,
          'fiber': 3.0,
          'sugar': 2.0,
          'sodium': 10.0,
          'cholesterol': 0.0,
        },
      },
      'wheat': {
        'Rice flour for wheat flour': {
          'calories': 366.0,
          'protein': 6.0,
          'carbs': 80.0,
          'fat': 1.4,
          'fiber': 2.4,
          'sugar': 0.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Almond flour for wheat flour': {
          'calories': 600.0,
          'protein': 21.0,
          'carbs': 22.0,
          'fat': 54.0,
          'fiber': 12.0,
          'sugar': 4.0,
          'sodium': 0.0,
          'cholesterol': 0.0,
        },
        'Coconut flour for wheat flour': {
          'calories': 400.0,
          'protein': 20.0,
          'carbs': 60.0,
          'fat': 20.0,
          'fiber': 40.0,
          'sugar': 20.0,
          'sodium': 0.0,
          'cholesterol': 0.0,
        },
        'Oat flour for wheat flour': {
          'calories': 389.0,
          'protein': 17.0,
          'carbs': 66.0,
          'fat': 7.0,
          'fiber': 11.0,
          'sugar': 1.0,
          'sodium': 2.0,
          'cholesterol': 0.0,
        },
        'Quinoa flour for wheat flour': {
          'calories': 368.0,
          'protein': 14.0,
          'carbs': 64.0,
          'fat': 6.0,
          'fiber': 7.0,
          'sugar': 0.0,
          'sodium': 5.0,
          'cholesterol': 0.0,
        },
        'Gluten-free flour blends': {
          'calories': 350.0,
          'protein': 8.0,
          'carbs': 75.0,
          'fat': 2.0,
          'fiber': 5.0,
          'sugar': 2.0,
          'sodium': 10.0,
          'cholesterol': 0.0,
        },
      },
    };
    
    // Get nutrition data for the specific substitution
    final categoryData = nutritionDatabase[category];
    if (categoryData != null) {
      final nutrition = categoryData[substitution];
      if (nutrition != null) {
        return Map<String, double>.from(nutrition);
      }
    }
    
    // Fallback nutrition data if not found
    return {
      'calories': 50.0,
      'protein': 2.0,
      'carbs': 5.0,
      'fat': 2.0,
      'fiber': 1.0,
      'sugar': 1.0,
      'sodium': 10.0,
      'cholesterol': 0.0,
    };
  }

  /// Validates the migration by checking if all substitutions have nutrition data
  static Future<bool> validateMigration() async {
    try {
      print('🔍 Validating migration...');
      
      final doc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (!doc.exists) {
        print('❌ No substitutions document found');
        return false;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
      
      int totalSubstitutions = 0;
      int substitutionsWithNutrition = 0;
      
      for (final category in substitutionsData.keys) {
        final substitutions = substitutionsData[category];
        if (substitutions is List) {
          for (final substitution in substitutions) {
            totalSubstitutions++;
            if (substitution is Map<String, dynamic> && 
                substitution.containsKey('nutrition') &&
                substitution['nutrition'] is Map) {
              substitutionsWithNutrition++;
            }
          }
        }
      }
      
      print('📊 Validation Results:');
      print('  Total substitutions: $totalSubstitutions');
      print('  With nutrition data: $substitutionsWithNutrition');
      print('  Migration success rate: ${(substitutionsWithNutrition / totalSubstitutions * 100).toStringAsFixed(1)}%');
      
      return substitutionsWithNutrition == totalSubstitutions;
      
    } catch (e) {
      print('❌ Error during validation: $e');
      return false;
    }
  }
}
