import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecipeService {
  static final String _apiKey = dotenv.env['SPOONACULAR_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.spoonacular.com/recipes';

  static Future<List<dynamic>> fetchRecipes(String query) async {
    try {
      // Try Spoonacular first
      if (_apiKey.isNotEmpty) {
        final url = '$_baseUrl/complexSearch?query=$query&number=10&apiKey=$_apiKey';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List<dynamic>? ?? [];
          
          // Validate and fix image URLs
          return results.map((recipe) {
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
        } else if (response.statusCode == 402) {
          // API limit reached, use fallback
          return _fetchRecipesFallback(query);
        }
      }
      
      // Use fallback if no API key or Spoonacular fails
      return _fetchRecipesFallback(query);
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
      // Try Spoonacular first
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
      }
    }
    
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
} 