import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'filipino_recipe_service.dart';

class RecipeService {
  static final String _apiKey = dotenv.env['SPOONACULAR_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.spoonacular.com/recipes';

  static Future<List<dynamic>> fetchRecipes(String query) async {
    List<dynamic> allRecipes = [];
    
    try {
      // 1. Try Spoonacular first
      if (_apiKey.isNotEmpty) {
        final url = '$_baseUrl/complexSearch?query=$query&number=10&apiKey=$_apiKey';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List<dynamic>? ?? [];
          
          // Validate and fix image URLs
          final spoonacularRecipes = results.map((recipe) {
            final recipeMap = Map<String, dynamic>.from(recipe);
            final imageUrl = recipeMap['image'] as String?;
            
            // If image URL is null or empty, or if it's a Spoonacular URL that might fail,
            // set it to null so the UI can show a placeholder
            if (imageUrl == null || imageUrl.isEmpty || 
                (imageUrl.contains('spoonacular.com') && !imageUrl.contains('https://'))) {
              recipeMap['image'] = null;
            }
            
            return recipeMap;
          }).toList();
          
          allRecipes.addAll(spoonacularRecipes);
        } else if (response.statusCode == 402) {
          // API limit reached, continue to other sources
        }
      }
      
      // 2. Try Filipino Recipe Service
      try {
        final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes(query);
        allRecipes.addAll(filipinoRecipes);
      } catch (e) {
        print('Filipino Recipe Service error: $e');
      }
      
      // 3. If no recipes found, use TheMealDB fallback
      if (allRecipes.isEmpty) {
        allRecipes = await _fetchRecipesFallback(query);
      }
      
      return allRecipes;
    } catch (e) {
      // Use fallback on any error
      return _fetchRecipesFallback(query);
    }
  }

  static Future<List<dynamic>> _fetchRecipesFallback(String query) async {
    // Using a free recipe API as fallback
    final url = 'https://www.themealdb.com/api/json/v1/1/search.php?s=$query';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meals = data['meals'] as List<dynamic>? ?? [];
      
      // Convert to similar format as Spoonacular
      return meals.map((meal) => {
        'id': meal['idMeal'],
        'title': meal['strMeal'],
        'image': meal['strMealThumb'],
        'sourceUrl': meal['strSource'],
      }).toList();
    } else {
      throw Exception('Failed to load recipes from fallback API');
    }
  }

  static Future<Map<String, dynamic>> fetchRecipeDetails(dynamic id) async {
    try {
      // Try Filipino Recipe Service first for Filipino recipes
      if (id.toString().startsWith('curated_') || 
          id.toString().startsWith('themealdb_') ||
          id.toString().startsWith('local_filipino_')) {
        final filipinoDetails = await FilipinoRecipeService.getRecipeDetails(id.toString());
        if (filipinoDetails != null) {
          return filipinoDetails;
        }
      }
      
      // Try Spoonacular for other recipes
      if (_apiKey.isNotEmpty) {
        final url = '$_baseUrl/$id/information?apiKey=$_apiKey';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Add nutrition information if available
          if (data['nutrition'] != null) {
            data['nutrition'] = _extractNutritionInfo(data['nutrition']);
          }
          
          return data;
        } else if (response.statusCode == 402) {
          // API limit reached, use fallback
          return _fetchRecipeDetailsFallback(id);
        }
      }
      
      // Use fallback if no API key or Spoonacular fails
      return _fetchRecipeDetailsFallback(id);
    } catch (e) {
      // Use fallback on any error
      return _fetchRecipeDetailsFallback(id);
    }
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

  static Future<Map<String, dynamic>> _fetchRecipeDetailsFallback(dynamic id) async {
    // Using TheMealDB as fallback
    final url = 'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$id';
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meal = data['meals']?[0];
      
      if (meal != null) {
        // Convert to similar format as Spoonacular
        return {
          'id': meal['idMeal'],
          'title': meal['strMeal'],
          'image': meal['strMealThumb'],
          'instructions': meal['strInstructions'],
          'extendedIngredients': _parseIngredients(meal),
          'summary': 'Recipe from TheMealDB',
          'nutrition': _generateEstimatedNutrition(meal),
          'cuisine': meal['strArea'] ?? 'International',
          'category': meal['strCategory'] ?? 'Main Course',
        };
      }
    }
    
    throw Exception('Failed to load recipe details from fallback API');
  }

  static List<Map<String, dynamic>> _parseIngredients(Map<String, dynamic> meal) {
    final ingredients = <Map<String, dynamic>>[];
    
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'];
      final measure = meal['strMeasure$i'];
      
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        ingredients.add({
          'name': ingredient.trim(),
          'amount': measure?.trim() ?? '1',
          'unit': '',
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
} 