import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'filipino_recipe_service.dart';

class RecipeService {
  static final String _apiKey = dotenv.env['SPOONACULAR_API_KEY'] ?? '';
  
  static bool get isApiKeyConfigured => _apiKey.isNotEmpty && _apiKey != 'your_api_key_here';
  static const String _baseUrl = 'https://api.spoonacular.com/recipes';

  static Future<List<dynamic>> fetchRecipes(String query) async {
    List<dynamic> allRecipes = [];
    
    print('DEBUG: fetchRecipes called with query: "$query"');
    print('DEBUG: API key configured: $isApiKeyConfigured');
    print('DEBUG: API key: ${_apiKey.substring(0, 8)}...');
    
    try {
      // 1. Try Spoonacular first (only if API key is available)
      if (isApiKeyConfigured) {
        try {
          final url = '$_baseUrl/complexSearch?query=$query&number=10&apiKey=$_apiKey';
          print('DEBUG: Spoonacular URL: $url');
          final response = await http.get(Uri.parse(url));
          print('DEBUG: Spoonacular response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = data['results'] as List<dynamic>? ?? [];
            
            // Validate and fix image URLs, ensure nutrition data
            final spoonacularRecipes = results.map((recipe) {
              final recipeMap = Map<String, dynamic>.from(recipe);
              final imageUrl = recipeMap['image'] as String?;
              
              // If image URL is null or empty, or if it's a Spoonacular URL that might fail,
              // set it to null so the UI can show a placeholder
              if (imageUrl == null || imageUrl.isEmpty || 
                  (imageUrl.contains('spoonacular.com') && !imageUrl.contains('https://'))) {
                recipeMap['image'] = null;
              }
              
              // Ensure nutrition data exists
              if (recipeMap['nutrition'] == null) {
                recipeMap['nutrition'] = _estimateNutritionFromTitle(recipeMap['title'] ?? '');
              }
              
              return recipeMap;
            }).toList();
            
            allRecipes.addAll(spoonacularRecipes);
            print('DEBUG: Spoonacular API: Successfully fetched ${spoonacularRecipes.length} recipes');
          } else if (response.statusCode == 402) {
            // API limit reached, continue to other sources
            print('Spoonacular API limit reached, trying other sources...');
          } else {
            print('Spoonacular API error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Spoonacular API error: $e');
        }
      } else {
        print('Spoonacular API key not configured, using fallback APIs');
      }
      
      // 2. Try TheMealDB only if we don't have enough recipes yet (always available, no API key required)
      if (allRecipes.length < 10) {
        try {
          final themealdbRecipes = await _fetchRecipesFallback(query);
          allRecipes.addAll(themealdbRecipes);
          print('DEBUG: TheMealDB: Successfully fetched ${themealdbRecipes.length} recipes');
        } catch (e) {
          print('TheMealDB error: $e');
        }
      }
      
      // 3. Try Filipino Recipe Service only if we still need more recipes
      if (allRecipes.length < 10) {
        try {
          final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes(query);
          allRecipes.addAll(filipinoRecipes);
          print('Filipino Recipe Service: Successfully fetched ${filipinoRecipes.length} recipes');
        } catch (e) {
          print('Filipino Recipe Service error: $e');
        }
      }
      
      // 4. Try Admin Recipes only if we still need more
      if (allRecipes.length < 15) {
        try {
          final adminRecipes = await _fetchAdminRecipes(query);
          allRecipes.addAll(adminRecipes);
          print('Admin Recipes: Successfully fetched ${adminRecipes.length} recipes');
        } catch (e) {
          print('Admin Recipes error: $e');
        }
      }
      
      // Limit total results to 20 for better performance
      final limitedRecipes = allRecipes.take(20).toList();
      print('Total recipes fetched: ${allRecipes.length} (limited to ${limitedRecipes.length})');
      return limitedRecipes;
    } catch (e) {
      print('Error in fetchRecipes: $e');
      // Use fallback on any error
      try {
        return await _fetchRecipesFallback(query);
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  static Future<List<dynamic>> _fetchRecipesFallback(String query) async {
    // Using a free recipe API as fallback
    final url = 'https://www.themealdb.com/api/json/v1/1/search.php?s=$query';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meals = data['meals'] as List<dynamic>? ?? [];
      
      // Extract ingredients from TheMealDB meal object
      List<String> _extractIngredients(Map<String, dynamic> meal) {
        final ingredients = <String>[];
        for (int i = 1; i <= 20; i++) {
          final ingredient = meal['strIngredient$i'];
          final measure = meal['strMeasure$i'];
          if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
            if (measure != null && measure.toString().trim().isNotEmpty) {
              ingredients.add('$measure $ingredient');
            } else {
              ingredients.add(ingredient.toString());
            }
          }
        }
        return ingredients;
      }
      
      // Filter recipes to only include those with the search term in the name
      // and limit to top 10 results
      final queryLower = query.toLowerCase();
      final filteredMeals = meals
          .where((meal) {
            final mealName = meal['strMeal']?.toString().toLowerCase() ?? '';
            return mealName.contains(queryLower);
          })
          .take(10)
          .toList();
      
      print('DEBUG: TheMealDB filtered from ${meals.length} to ${filteredMeals.length} results');
      
      // Convert to similar format as Spoonacular
      return filteredMeals.map((meal) {
        final mealMap = meal as Map<String, dynamic>;
        final ingredients = _extractIngredients(mealMap);
        return {
          'id': 'themealdb_${mealMap['idMeal']}', // Prefix to identify TheMealDB recipes
          'title': mealMap['strMeal'],
          'image': mealMap['strMealThumb'],
          'sourceUrl': mealMap['strSource'],
          'ingredients': ingredients, // Add ingredients for filtering
        };
      }).toList();
    } else {
      throw Exception('Failed to load recipes from fallback API');
    }
  }

  static Future<Map<String, dynamic>> fetchRecipeDetails(dynamic id) async {
    try {
      Map<String, dynamic>? recipeDetails;
      
      // Try admin recipes first - check both admin_ prefix and direct ID lookup
      if (id.toString().startsWith('admin_')) {
        final adminDetails = await _fetchAdminRecipeDetails(id.toString());
        if (adminDetails != null) {
          recipeDetails = adminDetails;
        }
      } else {
        // Try direct admin recipe lookup for non-prefixed IDs
        final adminDetails = await _fetchAdminRecipeDetails(id.toString());
        if (adminDetails != null) {
          recipeDetails = adminDetails;
        }
      }
      
      // Try Filipino Recipe Service for Filipino recipes
      if (recipeDetails == null) {
        // Check if it's a Filipino recipe by trying FilipinoRecipeService
        // This handles both prefixed IDs and Firestore IDs
        final filipinoDetails = await FilipinoRecipeService.getRecipeDetails(id.toString());
        if (filipinoDetails != null) {
          recipeDetails = filipinoDetails;
        }
      }
      
      // Handle TheMealDB recipes
      if (recipeDetails == null && id.toString().startsWith('themealdb_')) {
        recipeDetails = await _fetchRecipeDetailsFallback(id);
      }
      
      // Try Spoonacular for other recipes
      if (recipeDetails == null && _apiKey.isNotEmpty) {
        final url = '$_baseUrl/$id/information?includeNutrition=true&apiKey=$_apiKey';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Add nutrition information if available
          if (data['nutrition'] != null) {
            data['nutrition'] = _extractNutritionInfo(data['nutrition']);
          } else {
            // Estimate nutrition from title if API doesn't provide it
            data['nutrition'] = _estimateNutritionFromTitle(data['title'] ?? '');
          }
          
          recipeDetails = data;
        } else if (response.statusCode == 402) {
          // API limit reached, use fallback
          recipeDetails = await _fetchRecipeDetailsFallback(id);
        }
      }
      
      // Use fallback if no API key or Spoonacular fails
      recipeDetails ??= await _fetchRecipeDetailsFallback(id);
      
      // Check for nutrition overrides (for API recipes)
      final overriddenRecipe = await _applyNutritionOverride(recipeDetails, id);
      return overriddenRecipe;
      
    } catch (e) {
      // Use fallback on any error
      final fallback = await _fetchRecipeDetailsFallback(id);
      return await _applyNutritionOverride(fallback, id);
    }
  }

  /// Check if there's a nutritionist-validated nutrition override for this recipe
  static Future<Map<String, dynamic>> _applyNutritionOverride(Map<String, dynamic> recipe, dynamic recipeId) async {
    try {
      // Check if an override exists for this recipe
      final overrideDoc = await FirebaseFirestore.instance
          .collection('api_recipe_overrides')
          .doc(recipeId.toString())
          .get();
      
      if (overrideDoc.exists) {
        final overrideData = overrideDoc.data();
        if (overrideData != null && overrideData['nutrition'] != null) {
          print('DEBUG: Applying nutrition override for recipe $recipeId');
          // Apply the validated nutrition override
          recipe['nutrition'] = overrideData['nutrition'];
          recipe['nutritionValidated'] = true;
          recipe['validatedBy'] = overrideData['validatedBy'];
          recipe['validatedAt'] = overrideData['validatedAt'];
        }
      }
    } catch (e) {
      print('DEBUG: Error checking nutrition override: $e');
      // If there's an error, just return the original recipe
    }
    
    return recipe;
  }

  static Map<String, dynamic> _extractNutritionInfo(Map<String, dynamic> nutrition) {
    final nutrients = nutrition['nutrients'] as List<dynamic>? ?? [];
    final nutritionMap = <String, dynamic>{};
    
    for (final nutrient in nutrients) {
      final name = nutrient['name']?.toString().toLowerCase();
      final amount = nutrient['amount'] ?? 0;
      
      switch (name) {
        case 'calories':
          nutritionMap['calories'] = amount;
          break;
        case 'protein':
          nutritionMap['protein'] = amount;
          break;
        case 'carbohydrates':
        case 'carbs':
          nutritionMap['carbs'] = amount;
          break;
        case 'fat':
          nutritionMap['fat'] = amount;
          break;
        case 'fiber':
          nutritionMap['fiber'] = amount;
          break;
        case 'sugar':
          nutritionMap['sugar'] = amount;
          break;
        case 'sodium':
          nutritionMap['sodium'] = amount;
          break;
        case 'cholesterol':
          nutritionMap['cholesterol'] = amount;
          break;
        case 'saturated fat':
          nutritionMap['saturatedFat'] = amount;
          break;
        case 'trans fat':
          nutritionMap['transFat'] = amount;
          break;
        case 'monounsaturated fat':
          nutritionMap['monounsaturatedFat'] = amount;
          break;
        case 'polyunsaturated fat':
          nutritionMap['polyunsaturatedFat'] = amount;
          break;
        case 'vitamin a':
          nutritionMap['vitaminA'] = amount;
          break;
        case 'vitamin c':
          nutritionMap['vitaminC'] = amount;
          break;
        case 'calcium':
          nutritionMap['calcium'] = amount;
          break;
        case 'iron':
          nutritionMap['iron'] = amount;
          break;
        case 'potassium':
          nutritionMap['potassium'] = amount;
          break;
        case 'magnesium':
          nutritionMap['magnesium'] = amount;
          break;
        case 'phosphorus':
          nutritionMap['phosphorus'] = amount;
          break;
        case 'zinc':
          nutritionMap['zinc'] = amount;
          break;
        case 'folate':
          nutritionMap['folate'] = amount;
          break;
        case 'vitamin d':
          nutritionMap['vitaminD'] = amount;
          break;
        case 'vitamin e':
          nutritionMap['vitaminE'] = amount;
          break;
        case 'vitamin k':
          nutritionMap['vitaminK'] = amount;
          break;
        case 'thiamin':
          nutritionMap['thiamin'] = amount;
          break;
        case 'riboflavin':
          nutritionMap['riboflavin'] = amount;
          break;
        case 'niacin':
          nutritionMap['niacin'] = amount;
          break;
        case 'vitamin b6':
          nutritionMap['vitaminB6'] = amount;
          break;
        case 'vitamin b12':
          nutritionMap['vitaminB12'] = amount;
          break;
      }
    }
    
    // Ensure basic nutrition values are present with defaults
    nutritionMap['calories'] ??= 0.0;
    nutritionMap['protein'] ??= 0.0;
    nutritionMap['carbs'] ??= 0.0;
    nutritionMap['fat'] ??= 0.0;
    nutritionMap['fiber'] ??= 0.0;
    nutritionMap['sugar'] ??= 0.0;
    nutritionMap['sodium'] ??= 0.0;
    nutritionMap['cholesterol'] ??= 0.0;
    nutritionMap['saturatedFat'] ??= 0.0;
    nutritionMap['transFat'] ??= 0.0;
    nutritionMap['monounsaturatedFat'] ??= 0.0;
    nutritionMap['polyunsaturatedFat'] ??= 0.0;
    
    return nutritionMap;
  }

  /// Estimate nutrition information from recipe title
  static Map<String, dynamic> _estimateNutritionFromTitle(String title) {
    double calories = 350; // Base calories
    double protein = 18;   // Base protein
    double carbs = 40;     // Base carbs
    double fat = 14;       // Base fat
    
    final titleLower = title.toLowerCase();
    
    // Adjust based on recipe type
    if (titleLower.contains('salad') || titleLower.contains('vegetable')) {
      calories = 180;
      protein = 8;
      carbs = 25;
      fat = 6;
    } else if (titleLower.contains('pasta') || titleLower.contains('noodle')) {
      calories = 420;
      protein = 15;
      carbs = 65;
      fat = 12;
    } else if (titleLower.contains('chicken')) {
      calories = 380;
      protein = 35;
      carbs = 20;
      fat = 16;
    } else if (titleLower.contains('beef') || titleLower.contains('steak')) {
      calories = 450;
      protein = 40;
      carbs = 15;
      fat = 25;
    } else if (titleLower.contains('fish') || titleLower.contains('salmon')) {
      calories = 320;
      protein = 30;
      carbs = 18;
      fat = 14;
    } else if (titleLower.contains('soup')) {
      calories = 220;
      protein = 12;
      carbs = 28;
      fat = 8;
    } else if (titleLower.contains('pizza')) {
      calories = 520;
      protein = 22;
      carbs = 55;
      fat = 24;
    } else if (titleLower.contains('burger')) {
      calories = 580;
      protein = 28;
      carbs = 45;
      fat = 32;
    }
    
    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fat': fat.round(),
      'fiber': (calories * 0.02).round(),
      'sugar': (carbs * 0.3).round(),
      'sodium': (calories * 2).round(),
    };
  }

  static Future<Map<String, dynamic>> _fetchRecipeDetailsFallback(dynamic id) async {
    // Using TheMealDB as fallback
    // Extract the actual ID if it's prefixed
    String actualId = id.toString();
    if (actualId.startsWith('themealdb_')) {
      actualId = actualId.substring('themealdb_'.length);
    }
    
    print('DEBUG: Fetching recipe details for ID: $actualId');
    final url = 'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$actualId';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('DEBUG: TheMealDB response data type: ${data.runtimeType}');
      print('DEBUG: TheMealDB meals field: ${data['meals']}');
      
      final meals = data['meals'];
      if (meals != null && meals is List && meals.isNotEmpty) {
        final meal = meals[0];
        print('DEBUG: Found meal: ${meal['strMeal']}');
        
        // Convert to similar format as Spoonacular
        return {
          'id': id.toString(), // Keep the original prefixed ID
          'title': meal['strMeal'],
          'image': meal['strMealThumb'],
          'instructions': meal['strInstructions'],
          'extendedIngredients': _parseIngredients(meal),
          'summary': 'Recipe from TheMealDB',
          'nutrition': _generateEstimatedNutrition(meal),
          'cuisine': meal['strArea'] ?? 'International',
          'category': meal['strCategory'] ?? 'Main Course',
        };
      } else {
        print('DEBUG: No meals found in TheMealDB response');
      }
    } else {
      print('DEBUG: TheMealDB API error: ${response.statusCode}');
    }
    
    throw Exception('Failed to load recipe details from fallback API');
  }

  static List<Map<String, dynamic>> _parseIngredients(Map<String, dynamic> meal) {
    final ingredients = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'];
      final measure = meal['strMeasure$i'];
      
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        // Parse amount safely
        double amount = 1.0;
        if (measure != null && measure.trim().isNotEmpty) {
          // Try to extract number from measure string
          final measureStr = measure.trim();
          final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(measureStr);
          if (numberMatch != null) {
            amount = double.tryParse(numberMatch.group(1)!) ?? 1.0;
          }
        }
        
        ingredients.add({
          'id': i.toString(), // Convert to string to avoid type issues
          'name': ingredient.trim(),
          'nameClean': ingredient.trim().toLowerCase(),
          'original': '${measure?.trim() ?? '1'} ${ingredient.trim()}',
          'originalName': ingredient.trim(),
          'amount': amount,
          'unit': '',
          'measures': {
            'us': {'amount': amount, 'unitShort': '', 'unitLong': ''},
            'metric': {'amount': amount, 'unitShort': '', 'unitLong': ''},
          },
          'meta': [],
          'consistency': 'SOLID',
          'aisle': 'Produce',
          'image': '',
        });
      }
    }
    
    return ingredients;
  }

  static Map<String, dynamic> _generateEstimatedNutrition(Map<String, dynamic> meal) {
    // Generate estimated nutrition based on ingredients and meal type
    final ingredients = <String>[];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'];
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        ingredients.add(ingredient.trim().toLowerCase());
      }
    }
    
    // Base nutrition estimates
    double calories = 300.0;
    double protein = 15.0;
    double carbs = 30.0;
    double fat = 12.0;
    double fiber = 3.0;
    double sugar = 5.0;
    double sodium = 400.0;
    double cholesterol = 50.0;
    
    // Adjust based on ingredients
    for (final ingredient in ingredients) {
      if (ingredient.contains('meat') || ingredient.contains('chicken') || ingredient.contains('beef') || 
          ingredient.contains('pork') || ingredient.contains('fish') || ingredient.contains('lamb')) {
        protein += 8.0;
        calories += 50.0;
        fat += 3.0;
        cholesterol += 20.0;
      }
      if (ingredient.contains('rice') || ingredient.contains('pasta') || ingredient.contains('bread') || 
          ingredient.contains('potato') || ingredient.contains('noodle')) {
        carbs += 15.0;
        calories += 60.0;
        fiber += 1.0;
      }
      if (ingredient.contains('cheese') || ingredient.contains('milk') || ingredient.contains('cream') || 
          ingredient.contains('butter') || ingredient.contains('yogurt')) {
        protein += 4.0;
        calories += 40.0;
        fat += 4.0;
        cholesterol += 15.0;
        sodium += 100.0;
      }
      if (ingredient.contains('vegetable') || ingredient.contains('tomato') || ingredient.contains('onion') || 
          ingredient.contains('carrot') || ingredient.contains('pepper') || ingredient.contains('lettuce')) {
        fiber += 2.0;
        calories += 10.0;
        carbs += 3.0;
      }
      if (ingredient.contains('oil') || ingredient.contains('olive') || ingredient.contains('coconut')) {
        fat += 8.0;
        calories += 70.0;
      }
      if (ingredient.contains('sugar') || ingredient.contains('honey') || ingredient.contains('syrup')) {
        sugar += 10.0;
        calories += 40.0;
        carbs += 10.0;
      }
      if (ingredient.contains('salt') || ingredient.contains('soy') || ingredient.contains('sauce')) {
        sodium += 200.0;
      }
    }
    
    // Adjust based on meal category
    final category = meal['strCategory']?.toString().toLowerCase() ?? '';
    if (category.contains('dessert') || category.contains('sweet')) {
      calories += 100.0;
      sugar += 15.0;
      carbs += 20.0;
    } else if (category.contains('soup') || category.contains('stew')) {
      calories -= 50.0;
      sodium += 300.0;
    } else if (category.contains('salad')) {
      calories -= 100.0;
      fiber += 5.0;
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
      'saturatedFat': (fat * 0.3).roundToDouble(),
      'transFat': 0.0,
      'monounsaturatedFat': (fat * 0.4).roundToDouble(),
      'polyunsaturatedFat': (fat * 0.3).roundToDouble(),
      'vitaminA': 500.0,
      'vitaminC': 30.0,
      'calcium': 200.0,
      'iron': 3.0,
      'potassium': 400.0,
      'magnesium': 50.0,
      'phosphorus': 150.0,
      'zinc': 2.0,
      'folate': 50.0,
      'vitaminD': 2.0,
      'vitaminE': 2.0,
      'vitaminK': 20.0,
      'thiamin': 0.5,
      'riboflavin': 0.3,
      'niacin': 4.0,
      'vitaminB6': 0.5,
      'vitaminB12': 1.0,
    };
  }

  /// Fetch admin-created recipes from Firebase
  static Future<List<dynamic>> _fetchAdminRecipes(String query) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      final allRecipes = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'source': 'Admin Created',
      }).toList();
      
      // Filter recipes based on search query
      final filteredRecipes = allRecipes.where((recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase();
        final description = (recipe['description'] ?? '').toString().toLowerCase();
        final ingredients = (recipe['ingredients'] as List<dynamic>? ?? [])
            .map((ing) => ing.toString().toLowerCase())
            .join(' ');
        final cuisine = (recipe['cuisine'] ?? '').toString().toLowerCase();
        
        final searchTerms = query.toLowerCase().split(' ');
        
        return searchTerms.any((term) =>
            title.contains(term) ||
            description.contains(term) ||
            ingredients.contains(term) ||
            cuisine.contains(term));
      }).toList();
      
      return filteredRecipes;
    } catch (e) {
      print('Error fetching admin recipes: $e');
      return [];
    }
  }

  /// Fetch specific admin recipe details from Firebase
  static Future<Map<String, dynamic>?> _fetchAdminRecipeDetails(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .doc(id)
          .get();
      
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
          'source': 'Admin Created',
        };
      }
      return null;
    } catch (e) {
      print('Error fetching admin recipe details: $e');
      return null;
    }
  }

  /// Update a single admin recipe and propagate changes to meal plans
  static Future<void> updateSingleAdminRecipe(String recipeId, Map<String, dynamic> updatedRecipe) async {
    try {
      print('DEBUG: Updating admin recipe with ID: $recipeId');
      print('DEBUG: Original recipe data: $updatedRecipe');
      
      // Clean the recipe data to ensure no null string values
      final cleanedRecipe = <String, dynamic>{};
      updatedRecipe.forEach((key, value) {
        if (value is String) {
          cleanedRecipe[key] = value.isEmpty ? '' : value;
        } else if (value == null) {
          // Handle null values based on field type
          switch (key) {
            case 'title':
            case 'description':
            case 'instructions':
            case 'image':
            case 'cuisine':
            case 'difficulty':
            case 'dietType':
            case 'mealType':
              cleanedRecipe[key] = '';
              break;
            case 'cookingTime':
            case 'servings':
              cleanedRecipe[key] = 0;
              break;
            case 'ingredients':
              cleanedRecipe[key] = [];
              break;
            case 'nutrition':
              cleanedRecipe[key] = {};
              break;
            default:
              cleanedRecipe[key] = value;
          }
        } else {
          cleanedRecipe[key] = value;
        }
      });
      
      print('DEBUG: Cleaned recipe data: $cleanedRecipe');
      
      // Update the recipe in Firestore
      await FirebaseFirestore.instance
          .collection('admin_recipes')
          .doc(recipeId)
          .update({
        ...cleanedRecipe,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('Admin recipe updated successfully');
      
      // Propagate changes to existing meal plans and individual meals
      await _propagateAdminRecipeChanges(recipeId, updatedRecipe);
    } catch (e) {
      print('Error updating admin recipe: $e');
      rethrow;
    }
  }

  /// Propagate admin recipe changes to existing meal plans and individual meals
  static Future<void> _propagateAdminRecipeChanges(String recipeId, Map<String, dynamic> newRecipe) async {
    try {
      print('Propagating admin recipe changes for: ${newRecipe['title']}');
      
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int updatedMealPlans = 0;
      int updatedIndividualMeals = 0;
      List<String> affectedUsers = [];
      
      // Track what changed for notifications
      final changes = _trackAdminRecipeChanges(recipeId, newRecipe);
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        bool userAffected = false;
        
        // Update meal plans
        final mealPlansSnapshot = await FirebaseFirestore.instance
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
            if (meal['recipeId'] == recipeId || 
                meal['title'] == newRecipe['title'] ||
                (meal['source'] == 'Admin Created' && meal['id'] == recipeId)) {
              
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
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('meal_plans')
                .doc(mealPlanDoc.id)
                .update({'meals': meals});
            updatedMealPlans++;
          }
        }
        
        // Update individual meals
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('meal_plans')
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final mealData = mealDoc.data();
          if (mealData['recipeId'] == recipeId || 
              mealData['title'] == newRecipe['title'] ||
              (mealData['source'] == 'Admin Created' && mealData['id'] == recipeId)) {
            
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('meal_plans')
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
        await _sendAdminRecipeUpdateNotifications(affectedUsers, newRecipe, changes);
      }
      
      print('Admin recipe propagation completed: $updatedMealPlans meal plans and $updatedIndividualMeals individual meals updated for ${affectedUsers.length} users');
    } catch (e) {
      print('Error propagating admin recipe changes: $e');
      // Don't rethrow - this is a background operation
    }
  }

  /// Track what changed in the admin recipe
  static List<String> _trackAdminRecipeChanges(String recipeId, Map<String, dynamic> newRecipe) {
    List<String> changes = [];
    
    // Note: For admin recipes, we don't have the old recipe data easily accessible
    // In a real implementation, you might want to store the old data before updating
    changes.add('Recipe updated by admin');
    
    if (newRecipe['title'] != null) {
      changes.add('Title: "${newRecipe['title']}"');
    }
    if (newRecipe['description'] != null) {
      changes.add('Description updated');
    }
    if (newRecipe['instructions'] != null) {
      changes.add('Instructions updated');
    }
    if (newRecipe['ingredients'] != null) {
      changes.add('Ingredients updated');
    }
    if (newRecipe['cookingTime'] != null) {
      changes.add('Cooking time: ${newRecipe['cookingTime']} minutes');
    }
    if (newRecipe['servings'] != null) {
      changes.add('Servings: ${newRecipe['servings']}');
    }
    if (newRecipe['image'] != null) {
      changes.add('Image updated');
    }
    
    return changes;
  }

  /// Send notifications to users about admin recipe updates
  static Future<void> _sendAdminRecipeUpdateNotifications(List<String> userIds, Map<String, dynamic> recipe, List<String> changes) async {
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add(notificationData);
      }
      
      print('Admin recipe update notifications sent to ${userIds.length} users');
    } catch (e) {
      print('Error sending admin recipe update notifications: $e');
    }
  }
} 