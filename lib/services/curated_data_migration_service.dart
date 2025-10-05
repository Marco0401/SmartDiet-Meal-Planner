import 'package:cloud_firestore/cloud_firestore.dart';

class CuratedDataMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate system substitutions to Firestore
  static Future<void> migrateSystemSubstitutions() async {
    try {
      // Check if already migrated
      final existingDoc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (existingDoc.exists) {
        print('System substitutions already migrated');
        return;
      }

      // System substitutions data
      final systemSubstitutions = {
        'dairy': [
          'Almond milk for cow milk',
          'Coconut milk for heavy cream',
          'Oat milk for regular milk',
          'Cashew cream for sour cream',
          'Nutritional yeast for cheese',
          'Coconut oil for butter',
          'Vegan butter for regular butter',
        ],
        'eggs': [
          'Flax eggs (1 tbsp ground flaxseed + 3 tbsp water)',
          'Chia eggs (1 tbsp chia seeds + 3 tbsp water)',
          'Applesauce (1/4 cup per egg)',
          'Banana (1/2 mashed banana per egg)',
          'Commercial egg replacer',
          'Silken tofu (1/4 cup per egg)',
        ],
        'fish': [
          'Tofu for fish protein',
          'Mushrooms for fish texture',
          'Jackfruit for fish flakes',
          'Seaweed for fish flavor',
          'Plant-based fish alternatives',
          'Tempeh for fish protein',
        ],
        'shellfish': [
          'Mushrooms for shellfish texture',
          'Hearts of palm for scallops',
          'Artichoke hearts for crab',
          'Jackfruit for lobster',
          'Plant-based shellfish alternatives',
          'Tofu for shrimp texture',
        ],
        'tree_nuts': [
          'Sunflower seeds for nuts',
          'Pumpkin seeds for nuts',
          'Oats for nut texture',
          'Coconut for nut flavor',
          'Seeds for nut protein',
          'Plant-based nut alternatives',
        ],
        'peanuts': [
          'Sunflower seed butter',
          'Almond butter (if no tree nut allergy)',
          'Soy butter',
          'Tahini (sesame seed butter)',
          'Coconut butter',
          'Pumpkin seed butter',
        ],
        'wheat': [
          'Rice flour for wheat flour',
          'Almond flour for wheat flour',
          'Coconut flour for wheat flour',
          'Oat flour for wheat flour',
          'Quinoa flour for wheat flour',
          'Gluten-free flour blends',
        ],
        'soy': [
          'Coconut aminos for soy sauce',
          'Tamari (wheat-free soy sauce)',
          'Liquid aminos',
          'Miso alternatives',
          'Tempeh alternatives',
          'Tofu alternatives',
        ],
      };

      // Save to Firestore
      await _firestore
          .collection('system_data')
          .doc('substitutions')
          .set({
            'data': systemSubstitutions,
            'migratedAt': DateTime.now().toIso8601String(),
            'version': '1.0',
            'type': 'system_substitutions',
          });

      print('System substitutions migrated successfully');
    } catch (e) {
      print('Error migrating system substitutions: $e');
    }
  }

  /// Migrate curated Filipino recipes to Firestore
  static Future<void> migrateCuratedFilipinoRecipes() async {
    try {
      // Check if already migrated
      final existingDoc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      // Get all curated Filipino recipes from the service
      final curatedRecipes = _getAllCuratedFilipinoRecipes();
      
      if (existingDoc.exists) {
        final existingData = existingDoc.data();
        final existingRecipes = existingData?['data'] as List<dynamic>? ?? [];
        print('Found ${existingRecipes.length} existing recipes in Firestore');
        print('New recipes to migrate: ${curatedRecipes.length}');
        
        // If we have fewer recipes than expected, update with the complete set
        if (existingRecipes.length < curatedRecipes.length) {
          print('Updating with complete recipe set...');
          await _firestore
              .collection('system_data')
              .doc('filipino_recipes')
              .update({
                'data': curatedRecipes,
                'updatedAt': DateTime.now().toIso8601String(),
                'migratedAt': DateTime.now().toIso8601String(),
                'version': '1.1',
                'type': 'curated_filipino_recipes',
              });
          print('Curated Filipino recipes updated successfully');
        } else {
          print('Curated Filipino recipes already up to date');
        }
        return;
      }

      // Save to Firestore
      await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .set({
            'data': curatedRecipes,
            'migratedAt': DateTime.now().toIso8601String(),
            'version': '1.0',
            'type': 'curated_filipino_recipes',
          });

      print('Curated Filipino recipes migrated successfully');
    } catch (e) {
      print('Error migrating curated Filipino recipes: $e');
    }
  }

  /// Get all curated Filipino recipes from the hardcoded data
  static List<Map<String, dynamic>> _getAllCuratedFilipinoRecipes() {
    return [
      // Filipino Breakfast Recipes
      {
        'id': 'local_filipino_breakfast_1',
        'title': 'Tapsilog',
        'description': 'Traditional Filipino breakfast with cured beef, garlic rice, and fried egg',
        'image': 'assets/images/filipino/breakfast/tapsilog.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Tapa (cured beef)', 'Garlic rice', 'Eggs', 'Soy sauce', 'Vinegar'],
        'instructions': '1. Marinate beef strips in soy sauce, vinegar, garlic, and black pepper for at least 30 minutes.\n2. Heat oil in a pan and cook the marinated beef until tender and slightly caramelized.\n3. For garlic rice: Sauté minced garlic in oil until golden, add cooked rice and mix well.\n4. Fry eggs sunny-side up.\n5. Serve beef over garlic rice with fried egg on top.\n6. Garnish with chopped scallions and serve with vinegar dipping sauce.',
        'nutrition': {'calories': 450, 'protein': 25, 'carbs': 45, 'fat': 18, 'fiber': 9},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_breakfast_2',
        'title': 'Champorado',
        'description': 'Sweet chocolate rice porridge with milk',
        'image': 'assets/images/filipino/breakfast/champorado.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Glutinous rice', 'Cocoa powder', 'Milk', 'Sugar', 'Salt'],
        'instructions': '1. Rinse glutinous rice until water runs clear.\n2. In a pot, combine rice with water and bring to a boil.\n3. Reduce heat and simmer, stirring occasionally, until rice is tender (about 20 minutes).\n4. Add cocoa powder and mix well until fully incorporated.\n5. Gradually add milk while stirring continuously.\n6. Add sugar to taste and continue cooking until thick and creamy.\n7. Serve hot in bowls, topped with evaporated milk and sugar if desired.',
        'nutrition': {'calories': 380, 'protein': 12, 'carbs': 68, 'fat': 8, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_breakfast_3',
        'title': 'Tocino with Garlic Rice',
        'description': 'Sweet cured pork with garlic fried rice',
        'image': 'assets/images/filipino/breakfast/tocino.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Tocino (sweet cured pork)', 'Garlic rice', 'Soy sauce', 'Garlic'],
        'instructions': '1. Heat oil in a pan over medium heat.\n2. Add tocino slices and cook for 3-4 minutes on each side.\n3. Add a splash of water and cover to steam for 2-3 minutes until fully cooked.\n4. Remove cover and continue cooking until caramelized and slightly crispy.\n5. For garlic rice: Sauté minced garlic in oil until golden brown.\n6. Add day-old rice and stir-fry for 2-3 minutes until heated through.\n7. Season with salt and pepper to taste.\n8. Serve tocino over garlic rice with atchara (pickled papaya) on the side.',
        'nutrition': {'calories': 520, 'protein': 22, 'carbs': 58, 'fat': 24, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_breakfast_4',
        'title': 'Longsilog',
        'description': 'Filipino sausage with garlic rice and fried egg',
        'image': 'assets/images/filipino/breakfast/longsilog.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Longganisa (Filipino sausage)', 'Garlic rice', 'Eggs', 'Vinegar'],
        'instructions': '1. Prick longganisa sausages with a fork to prevent bursting.\n2. Heat oil in a pan over medium heat.\n3. Add longganisa and cook for 5-6 minutes, turning occasionally.\n4. Add a little water and cover to steam for 3-4 minutes until fully cooked.\n5. Remove cover and continue cooking until caramelized and slightly crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up in the same pan.\n8. Serve longganisa over garlic rice with fried egg and vinegar dipping sauce.',
        'nutrition': {'calories': 480, 'protein': 28, 'carbs': 42, 'fat': 22, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_breakfast_5',
        'title': 'Bangusilog',
        'description': 'Fried milkfish with garlic rice and fried egg',
        'image': 'assets/images/filipino/breakfast/bangusilog.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Bangus (milkfish)', 'Garlic rice', 'Eggs', 'Salt', 'Pepper'],
        'instructions': '1. Clean and scale the bangus (milkfish), remove gills and innards.\n2. Make diagonal cuts on both sides of the fish.\n3. Season with salt, pepper, and calamansi juice. Let marinate for 15 minutes.\n4. Heat oil in a pan over medium-high heat.\n5. Fry the bangus for 5-6 minutes on each side until golden and crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up.\n8. Serve bangus over garlic rice with fried egg, tomatoes, and vinegar dipping sauce.',
        'nutrition': {'calories': 420, 'protein': 32, 'carbs': 38, 'fat': 18, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_breakfast_6',
        'title': 'Arroz Caldo',
        'description': 'Filipino chicken rice porridge with ginger',
        'image': 'assets/images/filipino/breakfast/arroz_caldo.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Chicken', 'Rice', 'Ginger', 'Garlic', 'Fish sauce', 'Green onions'],
        'instructions': '1. Heat oil in a large pot over medium heat.\n2. Sauté minced garlic and ginger until fragrant.\n3. Add chicken pieces and cook until lightly browned.\n4. Add rice and stir for 2-3 minutes until rice is slightly toasted.\n5. Pour in chicken broth and bring to a boil.\n6. Reduce heat and simmer for 20-25 minutes, stirring occasionally.\n7. Add fish sauce, salt, and pepper to taste.\n8. Continue cooking until rice is tender and mixture is creamy.\n9. Garnish with chopped scallions, fried garlic, and hard-boiled eggs.\n10. Serve hot with calamansi and fish sauce on the side.',
        'nutrition': {'calories': 380, 'protein': 22, 'carbs': 52, 'fat': 12, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      
      // Filipino Lunch Recipes
      {
        'id': 'local_filipino_lunch_1',
        'title': 'Chicken Adobo',
        'description': 'Classic Filipino braised chicken in soy sauce and vinegar',
        'image': 'assets/images/filipino/lunch/chicken_adobo.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Chicken', 'Soy sauce', 'Vinegar', 'Garlic', 'Bay leaves', 'Black pepper'],
        'instructions': '1. Marinate chicken in soy sauce, vinegar, garlic, and black pepper for 30 minutes.\n2. Heat oil in a pot and brown the chicken pieces.\n3. Add the marinade and bay leaves.\n4. Bring to a boil, then simmer covered for 30-40 minutes until chicken is tender.\n5. Remove cover and simmer until sauce thickens.',
        'nutrition': {'calories': 420, 'protein': 35, 'carbs': 12, 'fat': 25, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_lunch_2',
        'title': 'Sinigang na Baboy',
        'description': 'Filipino pork soup with tamarind and vegetables',
        'image': 'assets/images/filipino/lunch/sinigang.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Pork', 'Tamarind', 'Tomatoes', 'Onions', 'Kangkong', 'Radish', 'Eggplant'],
        'instructions': '1. Boil pork until tender.\n2. Add tamarind paste, tomatoes, and onions.\n3. Add vegetables and simmer until cooked.\n4. Season with salt and pepper to taste.',
        'nutrition': {'calories': 380, 'protein': 28, 'carbs': 22, 'fat': 20, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_lunch_3',
        'title': 'Kare-kare',
        'description': 'Filipino oxtail stew in peanut sauce',
        'image': 'assets/images/filipino/lunch/kare_kare.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Oxtail', 'Peanut butter', 'Rice flour', 'Vegetables', 'Shrimp paste'],
        'instructions': '1. Boil oxtail until tender.\n2. Make peanut sauce with peanut butter and rice flour.\n3. Add vegetables and simmer.\n4. Serve with shrimp paste.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 25, 'fat': 28, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_lunch_4',
        'title': 'Bicol Express',
        'description': 'Spicy Filipino dish with pork and coconut milk',
        'image': 'assets/images/filipino/lunch/bicol_express.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Pork', 'Coconut milk', 'Chili peppers', 'Onions', 'Garlic', 'Ginger'],
        'instructions': '1. Sauté pork until browned.\n2. Add aromatics and chili peppers.\n3. Pour coconut milk and simmer until thick.\n4. Season to taste.',
        'nutrition': {'calories': 520, 'protein': 30, 'carbs': 18, 'fat': 35, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_lunch_5',
        'title': 'Pinakbet',
        'description': 'Mixed vegetable stew with shrimp paste',
        'image': 'assets/images/filipino/lunch/pinakbet.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Mixed vegetables', 'Pork', 'Shrimp paste', 'Tomatoes', 'Onions'],
        'instructions': '1. Sauté pork until browned.\n2. Add tomatoes and onions.\n3. Add vegetables and shrimp paste.\n4. Simmer until vegetables are tender.',
        'nutrition': {'calories': 350, 'protein': 20, 'carbs': 28, 'fat': 18, 'fiber': 7},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_lunch_6',
        'title': 'Laing',
        'description': 'Taro leaves cooked in coconut milk with pork',
        'image': 'assets/images/filipino/lunch/laing.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Taro leaves', 'Coconut milk', 'Pork', 'Chili peppers', 'Ginger', 'Garlic'],
        'instructions': '1. Sauté pork until browned.\n2. Add garlic, ginger, and chili peppers.\n3. Add taro leaves and coconut milk.\n4. Simmer until leaves are tender.\n5. Season with salt and pepper.',
        'nutrition': {'calories': 420, 'protein': 25, 'carbs': 20, 'fat': 28, 'fiber': 8},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      
      // Filipino Dinner Recipes
      {
        'id': 'local_filipino_dinner_1',
        'title': 'Lechon Kawali',
        'description': 'Crispy deep-fried pork belly',
        'image': 'assets/images/filipino/dinner/lechon_kawali.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Pork belly', 'Salt', 'Bay leaves', 'Peppercorns', 'Oil'],
        'instructions': '1. Boil pork belly with salt, bay leaves, and peppercorns until tender.\n2. Let cool and cut into serving pieces.\n3. Deep fry until golden and crispy.\n4. Serve with liver sauce or vinegar dip.',
        'nutrition': {'calories': 580, 'protein': 35, 'carbs': 5, 'fat': 45, 'fiber': 12},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_dinner_2',
        'title': 'Beef Caldereta',
        'description': 'Filipino beef stew with tomato sauce and vegetables',
        'image': 'assets/images/filipino/dinner/beef_caldereta.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Beef', 'Tomato sauce', 'Potatoes', 'Carrots', 'Bell peppers', 'Liver spread'],
        'instructions': '1. Brown beef pieces in oil.\n2. Add tomato sauce and simmer until tender.\n3. Add vegetables and liver spread.\n4. Cook until vegetables are tender.',
        'nutrition': {'calories': 520, 'protein': 38, 'carbs': 25, 'fat': 30, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_dinner_3',
        'title': 'Pork Menudo',
        'description': 'Filipino pork stew with liver and vegetables',
        'image': 'assets/images/filipino/dinner/pork_menudo.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Pork', 'Pork liver', 'Tomato sauce', 'Potatoes', 'Carrots', 'Raisins'],
        'instructions': '1. Sauté pork until browned.\n2. Add tomato sauce and simmer.\n3. Add liver and vegetables.\n4. Cook until tender and flavorful.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 28, 'fat': 26, 'fiber': 10},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      
      // Filipino Snack/Dessert Recipes
      {
        'id': 'local_filipino_snack_1',
        'title': 'Turon',
        'description': 'Filipino spring roll with banana and jackfruit',
        'image': 'assets/images/filipino/snacks/turon.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'snack',
        'ingredients': ['Banana', 'Jackfruit strips', 'Brown sugar', 'Spring roll wrapper'],
        'instructions': '1. Place banana and jackfruit on wrapper.\n2. Sprinkle with brown sugar.\n3. Roll tightly and deep fry until golden.',
        'nutrition': {'calories': 280, 'protein': 4, 'carbs': 45, 'fat': 12, 'fiber': 6},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'local_filipino_snack_2',
        'title': 'Halo-halo',
        'description': 'Filipino mixed dessert with shaved ice',
        'image': 'assets/images/filipino/snacks/halo_halo.jpg',
        'source': 'curated',
        'cuisine': 'Filipino',
        'mealType': 'snack',
        'ingredients': ['Shaved ice', 'Mixed beans', 'Ube', 'Leche flan', 'Ice cream', 'Evaporated milk'],
        'instructions': '1. Layer ingredients in a tall glass.\n2. Top with shaved ice.\n3. Add evaporated milk and ice cream.\n4. Mix before eating.',
        'nutrition': {'calories': 320, 'protein': 8, 'carbs': 58, 'fat': 10, 'fiber': 6},
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];
  }

  /// Run all migrations
  static Future<void> runAllMigrations() async {
    print('Starting curated data migration...');
    await migrateSystemSubstitutions();
    await migrateCuratedFilipinoRecipes();
    print('All migrations completed!');
  }

  /// Check if migrations are needed
  static Future<bool> needsMigration() async {
    try {
      final substitutionsDoc = await _firestore
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      final recipesDoc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      // Check if substitutions exist
      if (!substitutionsDoc.exists) {
        print('DEBUG: Substitutions migration needed');
        return true;
      }
      
      // Check if recipes exist and have the complete set
      if (!recipesDoc.exists) {
        print('DEBUG: Recipes migration needed');
        return true;
      }
      
      final recipesData = recipesDoc.data();
      final recipes = recipesData?['data'] as List<dynamic>? ?? [];
      final expectedRecipes = _getAllCuratedFilipinoRecipes();
      
      print('DEBUG: Found ${recipes.length} recipes, expected ${expectedRecipes.length}');
      
      if (recipes.length < expectedRecipes.length) {
        print('DEBUG: Incomplete recipes set, migration needed');
        return true;
      }
      
      print('DEBUG: All migrations up to date');
      return false;
    } catch (e) {
      print('Error checking migration status: $e');
      return true; // Assume migration needed if error
    }
  }
}
