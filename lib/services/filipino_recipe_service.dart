import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class FilipinoRecipeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Filipino recipe APIs and sources
  static const String _themealdbUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Fetch Filipino recipes from multiple sources
  static Future<List<dynamic>> fetchFilipinoRecipes(String query) async {
    print('DEBUG: fetchFilipinoRecipes called with query: "$query"');
    List<dynamic> allRecipes = [];
    
    try {
      // 1. Try TheMealDB for Filipino dishes
      print('DEBUG: Fetching from TheMealDB...');
      final mealDbRecipes = await _fetchFromTheMealDB(query);
      print('DEBUG: TheMealDB returned ${mealDbRecipes.length} recipes');
      allRecipes.addAll(mealDbRecipes);
      
      // 2. Add curated Filipino recipes from Firestore
      print('DEBUG: Fetching curated Filipino recipes...');
      final localFilipinoRecipes = await _getCuratedFilipinoRecipes(query);
      print('DEBUG: Curated recipes returned ${localFilipinoRecipes.length} recipes');
      allRecipes.addAll(localFilipinoRecipes);
      
      print('DEBUG: Total Filipino recipes: ${allRecipes.length}');
      return allRecipes;
    } catch (e) {
      print('Error fetching Filipino recipes: $e');
      // Return local recipes as fallback
      return await _getCuratedFilipinoRecipes(query);
    }
  }

  /// Fetch recipes from TheMealDB (has some Filipino dishes)
  static Future<List<dynamic>> _fetchFromTheMealDB(String query) async {
    try {
      final url = '$_themealdbUrl/search.php?s=$query';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List<dynamic>? ?? [];
        
        // Filter for Filipino dishes and convert format
        return meals.where((meal) {
          final mealName = (meal['strMeal'] as String? ?? '').toLowerCase();
          return _isFilipinoDish(mealName);
        }).map((meal) => {
          'id': 'themealdb_${meal['idMeal']}',
          'title': meal['strMeal'],
          'description': meal['strInstructions']?.substring(0, 100) ?? '',
          'image': meal['strMealThumb'],
          'source': 'TheMealDB',
          'cuisine': 'Filipino',
          'ingredients': _extractMealDbIngredients(meal),
          'instructions': meal['strInstructions'] ?? '',
          'nutrition': _estimateNutritionFromIngredients(_extractMealDbIngredients(meal), meal['strMeal'] ?? ''),
        }).toList();
      }
    } catch (e) {
      print('TheMealDB error: $e');
    }
    return [];
  }

  /// Estimate nutrition information from ingredients and recipe title
  static Map<String, dynamic> _estimateNutritionFromIngredients(List<String> ingredients, String title) {
    double calories = 300; // Base calories
    double protein = 15;   // Base protein
    double carbs = 35;     // Base carbs
    double fat = 12;       // Base fat
    
    final titleLower = title.toLowerCase();
    final ingredientsText = ingredients.join(' ').toLowerCase();
    
    // Adjust based on recipe type
    if (titleLower.contains('adobo') || titleLower.contains('pork') || titleLower.contains('beef')) {
      calories += 150;
      protein += 20;
      fat += 15;
    } else if (titleLower.contains('chicken')) {
      calories += 100;
      protein += 25;
      fat += 8;
    } else if (titleLower.contains('fish') || titleLower.contains('bangus')) {
      calories += 80;
      protein += 20;
      fat += 6;
    } else if (titleLower.contains('vegetable') || titleLower.contains('gulay')) {
      calories -= 50;
      protein -= 5;
      carbs += 10;
      fat -= 3;
    } else if (titleLower.contains('rice') || titleLower.contains('silog')) {
      calories += 120;
      carbs += 30;
      protein += 5;
    } else if (titleLower.contains('soup') || titleLower.contains('sinigang')) {
      calories -= 30;
      carbs += 15;
      fat -= 5;
    }
    
    // Adjust based on ingredients
    if (ingredientsText.contains('coconut milk') || ingredientsText.contains('gata')) {
      calories += 100;
      fat += 15;
    }
    if (ingredientsText.contains('oil') || ingredientsText.contains('butter')) {
      calories += 50;
      fat += 8;
    }
    if (ingredientsText.contains('sugar') || ingredientsText.contains('honey')) {
      calories += 60;
      carbs += 15;
    }
    if (ingredientsText.contains('egg')) {
      calories += 70;
      protein += 6;
      fat += 5;
    }
    
    // Ensure minimum values
    calories = calories.clamp(200, 800);
    protein = protein.clamp(8, 50);
    carbs = carbs.clamp(20, 80);
    fat = fat.clamp(5, 40);
    
    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fat': fat.round(),
    };
  }

  /// Get curated Filipino recipes from Firestore
  static Future<List<dynamic>> _getCuratedFilipinoRecipes(String query) async {
    try {
      print('DEBUG: Fetching curated Filipino recipes from Firestore...');
      // First try to get from Firestore
      final doc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      print('DEBUG: Firestore doc exists: ${doc.exists}');
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = data?['data'] as List<dynamic>? ?? [];
        print('DEBUG: Found ${recipes.length} recipes in Firestore');
        
        // Filter by query if provided
        if (query.isNotEmpty) {
          final lowercaseQuery = query.toLowerCase();
          final filteredRecipes = recipes.where((recipe) {
            final title = (recipe['title'] as String? ?? '').toLowerCase();
            final description = (recipe['description'] as String? ?? '').toLowerCase();
            return title.contains(lowercaseQuery) || description.contains(lowercaseQuery);
          }).toList();
          print('DEBUG: After filtering for "$query": ${filteredRecipes.length} recipes');
          return filteredRecipes;
        }
        
        print('DEBUG: Returning all ${recipes.length} recipes from Firestore');
        return recipes;
      } else {
        print('DEBUG: No Firestore document found, falling back to hardcoded data');
      }
    } catch (e) {
      print('Error getting curated recipes from Firestore: $e');
    }
    
    // Fallback to hardcoded data
    print('DEBUG: Using hardcoded Filipino recipes');
    return _getHardcodedFilipinoRecipes(query);
  }

  /// Get hardcoded Filipino recipes (fallback)
  static List<dynamic> _getHardcodedFilipinoRecipes(String query) {
    final allFilipinoRecipes = [
      // Filipino Breakfast Recipes
      {
        'id': 'local_filipino_breakfast_1',
        'title': 'Tapsilog',
        'description': 'Traditional Filipino breakfast with cured beef, garlic rice, and fried egg',
        'image': 'assets/images/filipino/breakfast/tapsilog.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Tapa (cured beef)', 'Garlic rice', 'Eggs', 'Soy sauce', 'Vinegar'],
        'instructions': '1. Marinate beef strips in soy sauce, vinegar, garlic, and black pepper for at least 30 minutes.\n2. Heat oil in a pan and cook the marinated beef until tender and slightly caramelized.\n3. For garlic rice: Sauté minced garlic in oil until golden, add cooked rice and mix well.\n4. Fry eggs sunny-side up.\n5. Serve beef over garlic rice with fried egg on top.\n6. Garnish with chopped scallions and serve with vinegar dipping sauce.',
        'nutrition': {'calories': 450, 'protein': 25, 'carbs': 45, 'fat': 18, 'fiber': 9}
      },
      {
        'id': 'local_filipino_breakfast_2',
        'title': 'Champorado',
        'description': 'Sweet chocolate rice porridge with milk',
        'image': 'assets/images/filipino/breakfast/champorado.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Glutinous rice', 'Cocoa powder', 'Milk', 'Sugar', 'Salt'],
        'instructions': '1. Rinse glutinous rice until water runs clear.\n2. In a pot, combine rice with water and bring to a boil.\n3. Reduce heat and simmer, stirring occasionally, until rice is tender (about 20 minutes).\n4. Add cocoa powder and mix well until fully incorporated.\n5. Gradually add milk while stirring continuously.\n6. Add sugar to taste and continue cooking until thick and creamy.\n7. Serve hot in bowls, topped with evaporated milk and sugar if desired.',
        'nutrition': {'calories': 380, 'protein': 12, 'carbs': 68, 'fat': 8, 'fiber': 8}
      },
      {
        'id': 'local_filipino_breakfast_3',
        'title': 'Tocino with Garlic Rice',
        'description': 'Sweet cured pork with garlic fried rice',
        'image': 'assets/images/filipino/breakfast/tocino.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Tocino (sweet cured pork)', 'Garlic rice', 'Soy sauce', 'Garlic'],
        'instructions': '1. Heat oil in a pan over medium heat.\n2. Add tocino slices and cook for 3-4 minutes on each side.\n3. Add a splash of water and cover to steam for 2-3 minutes until fully cooked.\n4. Remove cover and continue cooking until caramelized and slightly crispy.\n5. For garlic rice: Sauté minced garlic in oil until golden brown.\n6. Add day-old rice and stir-fry for 2-3 minutes until heated through.\n7. Season with salt and pepper to taste.\n8. Serve tocino over garlic rice with atchara (pickled papaya) on the side.',
        'nutrition': {'calories': 520, 'protein': 22, 'carbs': 58, 'fat': 24, 'fiber': 10}
      },
      {
        'id': 'local_filipino_breakfast_4',
        'title': 'Longsilog',
        'description': 'Filipino sausage with garlic rice and fried egg',
        'image': 'assets/images/filipino/breakfast/longsilog.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'breakfast',
        'ingredients': ['Longganisa (Filipino sausage)', 'Garlic rice', 'Eggs', 'Vinegar'],
        'instructions': '1. Prick longganisa sausages with a fork to prevent bursting.\n2. Heat oil in a pan over medium heat.\n3. Add longganisa and cook for 5-6 minutes, turning occasionally.\n4. Add a little water and cover to steam for 3-4 minutes until fully cooked.\n5. Remove cover and continue cooking until caramelized and slightly crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up in the same pan.\n8. Serve longganisa over garlic rice with fried egg and vinegar dipping sauce.',
        'nutrition': {'calories': 480, 'protein': 28, 'carbs': 42, 'fat': 22, 'fiber': 10}
      },
      {
        'id': 'local_filipino_breakfast_5',
        'title': 'Bangusilog',
        'description': 'Fried milkfish with garlic rice and fried egg',
        'image': 'assets/images/filipino/breakfast/bangusilog.jpg',
        'source': 'Local',
        'mealType': 'breakfast',
        'cuisine': 'Filipino',
        'ingredients': ['Bangus (milkfish)', 'Garlic rice', 'Eggs', 'Salt', 'Pepper'],
        'instructions': '1. Clean and scale the bangus (milkfish), remove gills and innards.\n2. Make diagonal cuts on both sides of the fish.\n3. Season with salt, pepper, and calamansi juice. Let marinate for 15 minutes.\n4. Heat oil in a pan over medium-high heat.\n5. Fry the bangus for 5-6 minutes on each side until golden and crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up.\n8. Serve bangus over garlic rice with fried egg, tomatoes, and vinegar dipping sauce.',
        'nutrition': {'calories': 420, 'protein': 32, 'carbs': 38, 'fat': 18, 'fiber': 8}
      },
      {
        'id': 'local_filipino_breakfast_6',
        'title': 'Arroz Caldo',
        'description': 'Filipino chicken rice porridge with ginger',
        'image': 'assets/images/filipino/breakfast/arroz_caldo.jpg',
        'mealType': 'breakfast',
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken', 'Rice', 'Ginger', 'Garlic', 'Fish sauce', 'Green onions'],
        'instructions': '1. Heat oil in a large pot over medium heat.\n2. Sauté minced garlic and ginger until fragrant.\n3. Add chicken pieces and cook until lightly browned.\n4. Add rice and stir for 2-3 minutes until rice is slightly toasted.\n5. Pour in chicken broth and bring to a boil.\n6. Reduce heat and simmer for 20-25 minutes, stirring occasionally.\n7. Add fish sauce, salt, and pepper to taste.\n8. Continue cooking until rice is tender and mixture is creamy.\n9. Garnish with chopped scallions, fried garlic, and hard-boiled eggs.\n10. Serve hot with calamansi and fish sauce on the side.',
        'nutrition': {'calories': 380, 'protein': 22, 'carbs': 52, 'fat': 12, 'fiber': 8}
      },
      
      // Filipino Lunch Recipes
      {
        'id': 'local_filipino_lunch_1',
        'title': 'Chicken Adobo',
        'description': 'Classic Filipino braised chicken in soy sauce and vinegar',
        'image': 'assets/images/filipino/lunch/chicken_adobo.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Chicken', 'Soy sauce', 'Vinegar', 'Garlic', 'Bay leaves', 'Black pepper'],
        'instructions': '1. Marinate chicken in soy sauce, vinegar, garlic, and black pepper for 30 minutes.\n2. Heat oil in a pot and brown the chicken pieces.\n3. Add the marinade and bay leaves.\n4. Bring to a boil, then simmer covered for 30-40 minutes until chicken is tender.\n5. Remove cover and simmer until sauce thickens.',
        'nutrition': {'calories': 420, 'protein': 35, 'carbs': 12, 'fat': 25, 'fiber': 8}
      },
      {
        'id': 'local_filipino_lunch_2',
        'title': 'Sinigang na Baboy',
        'description': 'Filipino pork soup with tamarind and vegetables',
        'image': 'assets/images/filipino/lunch/sinigang.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Pork', 'Tamarind', 'Tomatoes', 'Onions', 'Kangkong', 'Radish', 'Eggplant'],
        'instructions': '1. Boil pork until tender.\n2. Add tamarind paste, tomatoes, and onions.\n3. Add vegetables and simmer until cooked.\n4. Season with salt and pepper to taste.',
        'nutrition': {'calories': 380, 'protein': 28, 'carbs': 22, 'fat': 20, 'fiber': 8}
      },
      {
        'id': 'local_filipino_lunch_3',
        'title': 'Kare-kare',
        'description': 'Filipino oxtail stew in peanut sauce',
        'image': 'assets/images/filipino/lunch/kare_kare.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Oxtail', 'Peanut butter', 'Rice flour', 'Vegetables', 'Shrimp paste'],
        'instructions': '1. Boil oxtail until tender.\n2. Make peanut sauce with peanut butter and rice flour.\n3. Add vegetables and simmer.\n4. Serve with shrimp paste.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 25, 'fat': 28, 'fiber': 10}
      },
      {
        'id': 'local_filipino_lunch_4',
        'title': 'Bicol Express',
        'description': 'Spicy Filipino dish with pork and coconut milk',
        'image': 'assets/images/filipino/lunch/bicol_express.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Pork', 'Coconut milk', 'Chili peppers', 'Onions', 'Garlic', 'Ginger'],
        'instructions': '1. Sauté pork until browned.\n2. Add aromatics and chili peppers.\n3. Pour coconut milk and simmer until thick.\n4. Season to taste.',
        'nutrition': {'calories': 520, 'protein': 30, 'carbs': 18, 'fat': 35, 'fiber': 10}
      },
      {
        'id': 'local_filipino_lunch_5',
        'title': 'Pinakbet',
        'description': 'Mixed vegetable stew with shrimp paste',
        'image': 'assets/images/filipino/lunch/pinakbet.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Mixed vegetables', 'Pork', 'Shrimp paste', 'Tomatoes', 'Onions'],
        'instructions': '1. Sauté pork until browned.\n2. Add tomatoes and onions.\n3. Add vegetables and shrimp paste.\n4. Simmer until vegetables are tender.',
        'nutrition': {'calories': 350, 'protein': 20, 'carbs': 28, 'fat': 18, 'fiber': 7}
      },
      {
        'id': 'local_filipino_lunch_6',
        'title': 'Laing',
        'description': 'Taro leaves cooked in coconut milk with pork',
        'image': 'assets/images/filipino/lunch/laing.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'lunch',
        'ingredients': ['Taro leaves', 'Coconut milk', 'Pork', 'Chili peppers', 'Ginger', 'Garlic'],
        'instructions': '1. Sauté pork until browned.\n2. Add garlic, ginger, and chili peppers.\n3. Add taro leaves and coconut milk.\n4. Simmer until leaves are tender.\n5. Season with salt and pepper.',
        'nutrition': {'calories': 420, 'protein': 25, 'carbs': 20, 'fat': 28, 'fiber': 8}
      },
      
      // Filipino Dinner Recipes
      {
        'id': 'local_filipino_dinner_1',
        'title': 'Lechon Kawali',
        'description': 'Crispy deep-fried pork belly',
        'image': 'assets/images/filipino/dinner/lechon_kawali.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Pork belly', 'Salt', 'Bay leaves', 'Peppercorns', 'Oil'],
        'instructions': '1. Boil pork belly with salt, bay leaves, and peppercorns until tender.\n2. Let cool and cut into serving pieces.\n3. Deep fry until golden and crispy.\n4. Serve with liver sauce or vinegar dip.',
        'nutrition': {'calories': 580, 'protein': 35, 'carbs': 5, 'fat': 45, 'fiber': 12}
      },
      {
        'id': 'local_filipino_dinner_2',
        'title': 'Beef Caldereta',
        'description': 'Filipino beef stew with tomato sauce and vegetables',
        'image': 'assets/images/filipino/dinner/beef_caldereta.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Beef', 'Tomato sauce', 'Potatoes', 'Carrots', 'Bell peppers', 'Liver spread'],
        'instructions': '1. Brown beef pieces in oil.\n2. Add tomato sauce and simmer until tender.\n3. Add vegetables and liver spread.\n4. Cook until vegetables are tender.',
        'nutrition': {'calories': 520, 'protein': 38, 'carbs': 25, 'fat': 30, 'fiber': 10}
      },
      {
        'id': 'local_filipino_dinner_3',
        'title': 'Pork Menudo',
        'description': 'Filipino pork stew with liver and vegetables',
        'image': 'assets/images/filipino/dinner/pork_menudo.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'dinner',
        'ingredients': ['Pork', 'Pork liver', 'Tomato sauce', 'Potatoes', 'Carrots', 'Raisins'],
        'instructions': '1. Sauté pork until browned.\n2. Add tomato sauce and simmer.\n3. Add liver and vegetables.\n4. Cook until tender and flavorful.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 28, 'fat': 26, 'fiber': 10}
      },
      
      // Filipino Snack/Dessert Recipes
      {
        'id': 'local_filipino_snack_1',
        'title': 'Turon',
        'description': 'Filipino spring roll with banana and jackfruit',
        'image': 'assets/images/filipino/snacks/turon.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'snack',
        'ingredients': ['Banana', 'Jackfruit strips', 'Brown sugar', 'Spring roll wrapper'],
        'instructions': '1. Place banana and jackfruit on wrapper.\n2. Sprinkle with brown sugar.\n3. Roll tightly and deep fry until golden.',
        'nutrition': {'calories': 280, 'protein': 4, 'carbs': 45, 'fat': 12, 'fiber': 6}
      },
      {
        'id': 'local_filipino_snack_2',
        'title': 'Halo-halo',
        'description': 'Filipino mixed dessert with shaved ice',
        'image': 'assets/images/filipino/snacks/halo_halo.jpg',
        'source': 'Local',
        'cuisine': 'Filipino',
        'mealType': 'snack',
        'ingredients': ['Shaved ice', 'Mixed beans', 'Ube', 'Leche flan', 'Ice cream', 'Evaporated milk'],
        'instructions': '1. Layer ingredients in a tall glass.\n2. Top with shaved ice.\n3. Add evaporated milk and ice cream.\n4. Mix before eating.',
        'nutrition': {'calories': 320, 'protein': 8, 'carbs': 58, 'fat': 10, 'fiber': 6}
      }
    ];

    // Filter recipes based on query (meal type or general search)
    if (query.isEmpty) return allFilipinoRecipes;
    
    final queryLower = query.toLowerCase();
    return allFilipinoRecipes.where((recipe) {
      final title = recipe['title']?.toString().toLowerCase() ?? '';
      final mealType = recipe['mealType']?.toString().toLowerCase() ?? '';
      final description = recipe['description']?.toString().toLowerCase() ?? '';
      
      return title.contains(queryLower) || 
             mealType.contains(queryLower) || 
             description.contains(queryLower) ||
             queryLower == 'all';
    }).toList();
  }

  /// Check if a dish name is Filipino
  static bool _isFilipinoDish(String dishName) {
    final filipinoKeywords = [
      'adobo', 'sinigang', 'kare-kare', 'lechon', 'pancit', 'sisig', 'bulalo',
      'nilaga', 'tinola', 'menudo', 'kaldereta', 'mechado', 'bicol express',
      'laing', 'pinakbet', 'ginataang', 'paksiw', 'batchoy', 'lomi',
      'halo-halo', 'bibingka', 'puto', 'kutsinta', 'sapin-sapin', 'buko pandan',
      'leche flan', 'ube', 'turon', 'lumpia', 'chicharon', 'polvoron',
      'tapsilog', 'tocino', 'longsilog', 'bangusilog', 'champorado', 'arroz caldo'
    ];
    
    return filipinoKeywords.any((keyword) => dishName.contains(keyword));
  }

  /// Extract ingredients from TheMealDB format
  static List<String> _extractMealDbIngredients(Map<String, dynamic> meal) {
    List<String> ingredients = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'] as String?;
      final measure = meal['strMeasure$i'] as String?;
      if (ingredient != null && ingredient.isNotEmpty) {
        ingredients.add('${measure ?? ''} $ingredient'.trim());
      }
    }
    return ingredients;
  }

  /// Get recipe details by ID
  static Future<Map<String, dynamic>?> getRecipeDetails(String id) async {
    try {
      if (id.startsWith('themealdb_')) {
        return await _getTheMealDbRecipeDetails(id);
      } else if (id.startsWith('curated_') || id.startsWith('local_filipino_')) {
        return _getCuratedRecipeDetails(id);
      }
    } catch (e) {
      print('Error getting recipe details for $id: $e');
    }
    return null;
  }

  /// Get TheMealDB recipe details
  static Future<Map<String, dynamic>?> _getTheMealDbRecipeDetails(String id) async {
    try {
      final mealId = id.replaceFirst('themealdb_', '');
      final url = '$_themealdbUrl/lookup.php?i=$mealId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List<dynamic>? ?? [];
        if (meals.isNotEmpty) {
          final meal = meals.first;
          return {
            'id': id,
            'title': meal['strMeal'],
            'description': meal['strInstructions']?.substring(0, 200) ?? '',
            'image': meal['strMealThumb'],
            'source': 'TheMealDB',
            'cuisine': 'Filipino',
            'ingredients': _extractMealDbIngredients(meal),
            'instructions': meal['strInstructions'] ?? '',
            'sourceUrl': meal['strSource'],
            'nutrition': _generateEstimatedNutrition(meal),
            'category': meal['strCategory'] ?? 'Main Course',
          };
        }
      }
    } catch (e) {
      print('Error getting TheMealDB recipe details: $e');
    }
    return null;
  }


  /// Get curated recipe details
  static Future<Map<String, dynamic>?> _getCuratedRecipeDetails(String id) async {
    final recipes = await _getCuratedFilipinoRecipes('');
    try {
      return recipes.firstWhere(
        (recipe) => recipe['id'].toString() == id.toString(),
      );
    } catch (e) {
      print('DEBUG: Error finding recipe with id $id: $e');
      return null;
    }
  }

  /// Generate estimated nutrition information for TheMealDB recipes
  static Map<String, dynamic> _generateEstimatedNutrition(Map<String, dynamic> meal) {
    // Generate estimated nutrition based on ingredients and meal type
    final ingredients = <String>[];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'];
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        ingredients.add(ingredient.trim().toLowerCase());
      }
    }
    
    // Base nutrition estimates for Filipino dishes
    double calories = 350.0;
    double protein = 18.0;
    double carbs = 35.0;
    double fat = 15.0;
    double fiber = 4.0;
    double sugar = 8.0;
    double sodium = 500.0;
    double cholesterol = 60.0;
    
    // Adjust based on ingredients
    for (final ingredient in ingredients) {
      if (ingredient.contains('meat') || ingredient.contains('chicken') || ingredient.contains('beef') || 
          ingredient.contains('pork') || ingredient.contains('fish') || ingredient.contains('lamb') ||
          ingredient.contains('bangus') || ingredient.contains('tuna') || ingredient.contains('shrimp')) {
        protein += 10.0;
        calories += 60.0;
        fat += 4.0;
        cholesterol += 25.0;
      }
      if (ingredient.contains('rice') || ingredient.contains('pasta') || ingredient.contains('bread') || 
          ingredient.contains('potato') || ingredient.contains('noodle') || ingredient.contains('pancit')) {
        carbs += 18.0;
        calories += 70.0;
        fiber += 1.5;
      }
      if (ingredient.contains('cheese') || ingredient.contains('milk') || ingredient.contains('cream') || 
          ingredient.contains('butter') || ingredient.contains('yogurt') || ingredient.contains('coconut milk')) {
        protein += 5.0;
        calories += 50.0;
        fat += 5.0;
        cholesterol += 18.0;
        sodium += 120.0;
      }
      if (ingredient.contains('vegetable') || ingredient.contains('tomato') || ingredient.contains('onion') || 
          ingredient.contains('carrot') || ingredient.contains('pepper') || ingredient.contains('lettuce') ||
          ingredient.contains('cabbage') || ingredient.contains('eggplant') || ingredient.contains('okra')) {
        fiber += 2.5;
        calories += 12.0;
        carbs += 4.0;
      }
      if (ingredient.contains('oil') || ingredient.contains('olive') || ingredient.contains('coconut') ||
          ingredient.contains('palm oil')) {
        fat += 10.0;
        calories += 80.0;
      }
      if (ingredient.contains('sugar') || ingredient.contains('honey') || ingredient.contains('syrup') ||
          ingredient.contains('brown sugar')) {
        sugar += 12.0;
        calories += 45.0;
        carbs += 12.0;
      }
      if (ingredient.contains('salt') || ingredient.contains('soy') || ingredient.contains('sauce') ||
          ingredient.contains('fish sauce') || ingredient.contains('shrimp paste')) {
        sodium += 250.0;
      }
      if (ingredient.contains('vinegar') || ingredient.contains('calamansi') || ingredient.contains('lemon')) {
        sodium += 50.0;
        calories += 5.0;
      }
    }
    
    // Adjust based on meal category
    final category = meal['strCategory']?.toString().toLowerCase() ?? '';
    if (category.contains('dessert') || category.contains('sweet') || category.contains('cake')) {
      calories += 120.0;
      sugar += 18.0;
      carbs += 25.0;
    } else if (category.contains('soup') || category.contains('stew') || category.contains('sinigang')) {
      calories -= 30.0;
      sodium += 400.0;
    } else if (category.contains('salad') || category.contains('vegetable')) {
      calories -= 80.0;
      fiber += 6.0;
    }
    
    return {
      'calories': calories.roundToDouble(),
      'protein': protein.roundToDouble(),
      'carbs': carbs.roundToDouble(),
      'fat': fat.roundToDouble(),
      'fiber': fiber.roundToDouble(),
      'sugar': sugar.roundToDouble(),
      'sodium': sodium.roundToDouble(),
      'cholesterol': cholesterol.roundToDouble(),
      'saturatedFat': (fat * 0.35).roundToDouble(),
      'transFat': 0.0,
      'monounsaturatedFat': (fat * 0.35).roundToDouble(),
      'polyunsaturatedFat': (fat * 0.30).roundToDouble(),
      'vitaminA': 600.0,
      'vitaminC': 35.0,
      'calcium': 250.0,
      'iron': 4.0,
      'potassium': 450.0,
      'magnesium': 60.0,
      'phosphorus': 180.0,
      'zinc': 2.5,
      'folate': 60.0,
      'vitaminD': 3.0,
      'vitaminE': 3.0,
      'vitaminK': 25.0,
      'thiamin': 0.6,
      'riboflavin': 0.4,
      'niacin': 5.0,
      'vitaminB6': 0.6,
      'vitaminB12': 1.2,
    };
  }

  /// Search for Filipino recipes by category
  static Future<List<dynamic>> searchByCategory(String category) async {
    final categoryMap = {
      'breakfast': ['tapsilog', 'tocino', 'longsilog', 'bangusilog', 'champorado', 'arroz caldo'],
      'lunch': ['adobo', 'sinigang', 'kare-kare', 'bicol express', 'laing', 'pinakbet'],
      'dinner': ['lechon', 'pancit', 'sisig', 'kaldereta', 'mechado', 'menudo'],
      'soup': ['bulalo', 'nilaga', 'tinola', 'batchoy', 'lomi'],
      'dessert': ['halo-halo', 'bibingka', 'puto', 'kutsinta', 'leche flan', 'ube'],
      'snack': ['lumpia', 'turon', 'chicharon', 'polvoron'],
    };

    final keywords = categoryMap[category.toLowerCase()] ?? [];
    List<dynamic> results = [];

    for (final keyword in keywords) {
      final recipes = await fetchFilipinoRecipes(keyword);
      results.addAll(recipes);
    }

    return results;
  }

  /// Get popular Filipino dishes
  static Future<List<dynamic>> getPopularFilipinoDishes() async {
    final popularDishes = [
      'adobo', 'sinigang', 'kare-kare', 'lechon kawali', 'pancit canton',
      'sisig', 'bulalo', 'halo-halo', 'lumpia', 'tapsilog'
    ];

    List<dynamic> results = [];
    for (final dish in popularDishes) {
      final recipes = await fetchFilipinoRecipes(dish);
      if (recipes.isNotEmpty) {
        results.add(recipes.first);
      }
    }

    return results;
  }

  /// Get a specific Filipino recipe by ID
  static Future<dynamic> getFilipinoRecipeById(String id) async {
    final recipes = await _getCuratedFilipinoRecipes('');
    try {
      return recipes.firstWhere(
        (recipe) => recipe['id'] == id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update curated Filipino recipes (admin only)
  static Future<void> updateCuratedFilipinoRecipes(List<Map<String, dynamic>> newRecipes) async {
    try {
      await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .update({
            'data': newRecipes,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      // Clear any cached data to ensure fresh data is fetched
      // The next call to _getCuratedFilipinoRecipes will fetch fresh data from Firestore
      
      print('Curated Filipino recipes updated successfully');
    } catch (e) {
      print('Error updating curated Filipino recipes: $e');
      rethrow;
    }
  }

  /// Update a single curated Filipino recipe (admin only)
  static Future<void> updateSingleCuratedFilipinoRecipe(Map<String, dynamic> updatedRecipe) async {
    try {
      final doc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        
        // Find and update the specific recipe
        final recipeIndex = recipes.indexWhere((recipe) => recipe['id'] == updatedRecipe['id']);
        if (recipeIndex != -1) {
          final oldRecipe = recipes[recipeIndex];
          recipes[recipeIndex] = {
            ...recipes[recipeIndex],
            ...updatedRecipe,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          
          await _firestore
              .collection('system_data')
              .doc('filipino_recipes')
              .update({
                'data': recipes,
                'updatedAt': DateTime.now().toIso8601String(),
              });
          
          print('Single curated Filipino recipe updated successfully');
          
          // Propagate changes to existing meal plans and individual meals
          await _propagateRecipeChanges(oldRecipe, recipes[recipeIndex]);
        } else {
          print('Recipe with ID ${updatedRecipe['id']} not found');
          throw Exception('Recipe not found');
        }
      } else {
        throw Exception('Filipino recipes document not found');
      }
    } catch (e) {
      print('Error updating single curated Filipino recipe: $e');
      rethrow;
    }
  }

  /// Propagate recipe changes to existing meal plans and individual meals
  static Future<void> _propagateRecipeChanges(Map<String, dynamic> oldRecipe, Map<String, dynamic> newRecipe) async {
    try {
      print('Propagating recipe changes for: ${newRecipe['title']}');
      
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      int updatedMealPlans = 0;
      int updatedIndividualMeals = 0;
      List<String> affectedUsers = [];
      
      // Track what changed for notifications
      final changes = _trackRecipeChanges(oldRecipe, newRecipe);
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        bool userAffected = false;
        
        // Update meal plans
        final mealPlansSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('meal_plans')
            .get();
        
        for (final mealPlanDoc in mealPlansSnapshot.docs) {
          final mealPlanData = mealPlanDoc.data();
          final meals = List<Map<String, dynamic>>.from(mealPlanData['meals'] ?? []);
          bool needsUpdate = false;
          
          for (int i = 0; i < meals.length; i++) {
            final meal = meals[i];
            if (meal['recipeId'] == oldRecipe['id'] || 
                meal['title'] == oldRecipe['title'] ||
                (meal['source'] == 'curated' && meal['id'] == oldRecipe['id'])) {
              
              // Update the meal with new recipe data
              meals[i] = {
                ...meal,
                'title': newRecipe['title'],
                'description': newRecipe['description'],
                'instructions': newRecipe['instructions'],
                'ingredients': newRecipe['ingredients'],
                'image': newRecipe['image'],
                'nutrition': newRecipe['nutrition'],
                'cookingTime': newRecipe['cookingTime'],
                'servings': newRecipe['servings'],
                'recipeUpdatedAt': DateTime.now().toIso8601String(),
                'recipeUpdateHistory': [
                  ...(meal['recipeUpdateHistory'] as List<dynamic>? ?? []),
                  {
                    'updatedAt': DateTime.now().toIso8601String(),
                    'changes': changes,
                    'updatedBy': 'admin',
                  }
                ],
              };
              needsUpdate = true;
              userAffected = true;
            }
          }
          
          if (needsUpdate) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('meal_plans')
                .doc(mealPlanDoc.id)
                .update({'meals': meals});
            updatedMealPlans++;
          }
        }
        
        // Update individual meals
        final mealsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('meals')
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final mealData = mealDoc.data();
          if (mealData['recipeId'] == oldRecipe['id'] || 
              mealData['title'] == oldRecipe['title'] ||
              (mealData['source'] == 'curated' && mealData['id'] == oldRecipe['id'])) {
            
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('meals')
                .doc(mealDoc.id)
                .update({
              'title': newRecipe['title'],
              'description': newRecipe['description'],
              'instructions': newRecipe['instructions'],
              'ingredients': newRecipe['ingredients'],
              'image': newRecipe['image'],
              'nutrition': newRecipe['nutrition'],
              'cookingTime': newRecipe['cookingTime'],
              'servings': newRecipe['servings'],
              'recipeUpdatedAt': DateTime.now().toIso8601String(),
              'recipeUpdateHistory': [
                ...(mealData['recipeUpdateHistory'] as List<dynamic>? ?? []),
                {
                  'updatedAt': DateTime.now().toIso8601String(),
                  'changes': changes,
                  'updatedBy': 'admin',
                }
              ],
            });
            updatedIndividualMeals++;
            userAffected = true;
          }
        }
        
        if (userAffected) {
          affectedUsers.add(userId);
        }
      }
      
      // Send notifications to affected users
      if (affectedUsers.isNotEmpty) {
        await _sendRecipeUpdateNotifications(affectedUsers, newRecipe, changes);
      }
      
      print('Recipe propagation completed: $updatedMealPlans meal plans and $updatedIndividualMeals individual meals updated for ${affectedUsers.length} users');
    } catch (e) {
      print('Error propagating recipe changes: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Track what changed in the recipe
  static List<String> _trackRecipeChanges(Map<String, dynamic> oldRecipe, Map<String, dynamic> newRecipe) {
    List<String> changes = [];
    
    if (oldRecipe['title'] != newRecipe['title']) {
      changes.add('Title: "${oldRecipe['title']}" → "${newRecipe['title']}"');
    }
    if (oldRecipe['description'] != newRecipe['description']) {
      changes.add('Description updated');
    }
    if (oldRecipe['instructions'] != newRecipe['instructions']) {
      changes.add('Instructions updated');
    }
    if (oldRecipe['ingredients']?.toString() != newRecipe['ingredients']?.toString()) {
      changes.add('Ingredients updated');
    }
    if (oldRecipe['cookingTime'] != newRecipe['cookingTime']) {
      changes.add('Cooking time: ${oldRecipe['cookingTime']} → ${newRecipe['cookingTime']} minutes');
    }
    if (oldRecipe['servings'] != newRecipe['servings']) {
      changes.add('Servings: ${oldRecipe['servings']} → ${newRecipe['servings']}');
    }
    if (oldRecipe['image'] != newRecipe['image']) {
      changes.add('Image updated');
    }
    
    return changes;
  }

  /// Send notifications to users about recipe updates
  static Future<void> _sendRecipeUpdateNotifications(List<String> userIds, Map<String, dynamic> recipe, List<String> changes) async {
    try {
      final notificationData = {
        'type': 'recipe_updated',
        'title': 'Recipe Updated: ${recipe['title']}',
        'message': 'A recipe in your meal plan has been updated by our admin team.',
        'details': {
          'recipeId': recipe['id'],
          'recipeTitle': recipe['title'],
          'changes': changes,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'priority': 'medium',
      };

      // Send to each affected user
      for (final userId in userIds) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add(notificationData);
      }
      
      print('Recipe update notifications sent to ${userIds.length} users');
    } catch (e) {
      print('Error sending recipe update notifications: $e');
    }
  }

  /// Add a new curated Filipino recipe (admin only)
  static Future<void> addCuratedFilipinoRecipe(Map<String, dynamic> recipe) async {
    try {
      final doc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        
        // Add the new recipe
        recipes.add({
          ...recipe,
          'id': recipe['id'] ?? 'curated_${DateTime.now().millisecondsSinceEpoch}',
          'isEditable': true,
          'createdAt': DateTime.now().toIso8601String(),
        });
        
        await _firestore
            .collection('system_data')
            .doc('filipino_recipes')
            .update({
              'data': recipes,
              'updatedAt': DateTime.now().toIso8601String(),
            });
        
        print('Curated Filipino recipe added successfully');
      }
    } catch (e) {
      print('Error adding curated Filipino recipe: $e');
      rethrow;
    }
  }

  /// Delete a curated Filipino recipe (admin only)
  static Future<void> deleteCuratedFilipinoRecipe(String recipeId) async {
    try {
      final doc = await _firestore
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        
        // Remove the recipe
        recipes.removeWhere((recipe) => recipe['id'] == recipeId);
        
        await _firestore
            .collection('system_data')
            .doc('filipino_recipes')
            .update({
              'data': recipes,
              'updatedAt': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      print('Error deleting curated Filipino recipe: $e');
      rethrow;
    }
  }
}
