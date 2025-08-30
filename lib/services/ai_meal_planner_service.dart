import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_service.dart';

class AIMealPlannerService {
  static const Map<String, Map<String, dynamic>> _goalStrategies = {
    'Lose weight': {
      'calorieMultiplier': 0.8,
      'proteinRatio': 0.3,
      'carbRatio': 0.4,
      'fatRatio': 0.3,
      'mealFrequency': 3,
      'focus': ['high_protein', 'low_calorie', 'fiber_rich'],
    },
    'Gain weight': {
      'calorieMultiplier': 1.2,
      'proteinRatio': 0.25,
      'carbRatio': 0.5,
      'fatRatio': 0.25,
      'mealFrequency': 4,
      'focus': ['high_calorie', 'protein_rich', 'healthy_fats'],
    },
    'Maintain current weight': {
      'calorieMultiplier': 1.0,
      'proteinRatio': 0.25,
      'carbRatio': 0.45,
      'fatRatio': 0.3,
      'mealFrequency': 3,
      'focus': ['balanced', 'nutrient_dense'],
    },
    'Build muscle': {
      'calorieMultiplier': 1.1,
      'proteinRatio': 0.35,
      'carbRatio': 0.45,
      'fatRatio': 0.2,
      'mealFrequency': 4,
      'focus': ['high_protein', 'complex_carbs', 'post_workout'],
    },
    'Eat healthier / clean eating': {
      'calorieMultiplier': 1.0,
      'proteinRatio': 0.25,
      'carbRatio': 0.45,
      'fatRatio': 0.3,
      'mealFrequency': 3,
      'focus': ['organic', 'whole_foods', 'nutrient_dense'],
    },
  };

  static const Map<String, Map<String, dynamic>> _activityLevels = {
    'Sedentary (little or no exercise)': {'calorieMultiplier': 0.9},
    'Lightly active (light exercise/sports 1–3 days/week)': {'calorieMultiplier': 1.0},
    'Moderately active (moderate exercise/sports 3–5 days/week)': {'calorieMultiplier': 1.1},
    'Very active (hard exercise 6–7 days/week)': {'calorieMultiplier': 1.2},
  };

  static const Map<String, List<String>> _dietaryRestrictions = {
    'Vegetarian': ['meat', 'fish', 'poultry'],
    'Vegan': ['meat', 'fish', 'poultry', 'dairy', 'eggs', 'honey'],
    'Pescatarian': ['meat', 'poultry'],
    'Keto': ['high_carbs', 'sugars'],
    'Low Carb': ['high_carbs', 'sugars'],
    'Low Sodium': ['high_sodium'],
    'Halal': ['pork', 'alcohol'],
  };

  static const Map<String, List<String>> _healthConditionAdjustments = {
    'Diabetes': ['low_gi', 'controlled_carbs', 'fiber_rich'],
    'Hypertension': ['low_sodium', 'potassium_rich', 'heart_healthy'],
    'High Cholesterol': ['low_saturated_fat', 'omega_3', 'fiber_rich'],
    'Obesity': ['low_calorie', 'high_protein', 'fiber_rich'],
    'Kidney Disease': ['low_protein', 'low_potassium', 'low_phosphorus'],
    'PCOS': ['low_gi', 'anti_inflammatory', 'balanced_hormones'],
    'Lactose Intolerance': ['dairy_free', 'calcium_rich_alternatives'],
    'Gluten Sensitivity': ['gluten_free', 'whole_grains'],
  };

  /// Generate a personalized meal plan based on user profile
  static Future<Map<String, dynamic>> generatePersonalizedMealPlan({
    int? days = 7,
    String? specificGoal,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      
      // Analyze user profile and generate recommendations
      final analysis = _analyzeUserProfile(userData);
      final mealPlan = await _createMealPlan(analysis, days ?? 7, specificGoal);
      
      return {
        'userAnalysis': analysis,
        'mealPlan': mealPlan,
        'recommendations': _generateRecommendations(analysis),
        'nutritionalGoals': _calculateNutritionalGoals(analysis),
      };
    } catch (e) {
      throw Exception('Failed to generate meal plan: $e');
    }
  }

  /// Analyze user profile and extract key insights
  static Map<String, dynamic> _analyzeUserProfile(Map<String, dynamic> userData) {
    final age = _calculateAge(userData['birthday']);
    final weight = userData['weight']?.toDouble() ?? 70.0;
    final height = userData['height']?.toDouble() ?? 170.0;
    final gender = userData['gender'] ?? 'Other';
    final goal = userData['goal'] ?? 'Eat healthier / clean eating';
    final activityLevel = userData['activityLevel'] ?? 'Moderately active (moderate exercise/sports 3–5 days/week)';
    final healthConditions = List<String>.from(userData['healthConditions'] ?? []);
    final allergies = List<String>.from(userData['allergies'] ?? []);
    final dietaryPreferences = List<String>.from(userData['dietaryPreferences'] ?? []);

    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'Male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Apply activity level multiplier
    final activityMultiplier = _activityLevels[activityLevel]?['calorieMultiplier'] ?? 1.0;
    final goalStrategy = _goalStrategies[goal] ?? _goalStrategies['Eat healthier / clean eating']!;
    final goalMultiplier = goalStrategy['calorieMultiplier'] ?? 1.0;
    
    final dailyCalories = bmr * activityMultiplier * goalMultiplier;

    return {
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'goal': goal,
      'activityLevel': activityLevel,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'dietaryPreferences': dietaryPreferences,
      'bmr': bmr,
      'dailyCalories': dailyCalories,
      'goalStrategy': goalStrategy,
      'bmi': weight / ((height / 100) * (height / 100)),
      'weightCategory': _getWeightCategory(weight, height, gender, age),
    };
  }

  /// Create a meal plan based on analysis
  static Future<Map<String, dynamic>> _createMealPlan(
    Map<String, dynamic> analysis,
    int days,
    String? specificGoal,
  ) async {
    final goal = specificGoal ?? analysis['goal'];
    final goalStrategy = _goalStrategies[goal] ?? _goalStrategies['Eat healthier / clean eating']!;
    final dailyCalories = analysis['dailyCalories'];
    final mealFrequency = goalStrategy['mealFrequency'] ?? 3;
    
    final mealPlan = <String, dynamic>{};
    
    for (int day = 1; day <= days; day++) {
      final dayPlan = <String, dynamic>{};
      final dailyMeals = <String, dynamic>{};
      
      // Calculate calories per meal
      final caloriesPerMeal = dailyCalories / mealFrequency;
      
      // Generate meals for the day
      if (mealFrequency >= 3) {
        dailyMeals['breakfast'] = await _generateMeal(
          'breakfast',
          caloriesPerMeal * 0.3,
          analysis,
          goalStrategy,
        );
        dailyMeals['lunch'] = await _generateMeal(
          'lunch',
          caloriesPerMeal * 0.35,
          analysis,
          goalStrategy,
        );
        dailyMeals['dinner'] = await _generateMeal(
          'dinner',
          caloriesPerMeal * 0.35,
          analysis,
          goalStrategy,
        );
      }
      
      if (mealFrequency >= 4) {
        dailyMeals['snack'] = await _generateMeal(
          'snack',
          caloriesPerMeal * 0.2,
          analysis,
          goalStrategy,
        );
      }
      
      dayPlan['meals'] = dailyMeals;
      dayPlan['totalCalories'] = dailyCalories;
      dayPlan['nutritionalSummary'] = _calculateMealNutrition(dailyMeals);
      
      mealPlan['day_$day'] = dayPlan;
    }
    
    return mealPlan;
  }

  /// Generate a specific meal based on requirements
  static Future<Map<String, dynamic>> _generateMeal(
    String mealType,
    double targetCalories,
    Map<String, dynamic> analysis,
    Map<String, dynamic> goalStrategy,
  ) async {
    try {
      // Build search query based on meal type and user preferences
      final searchQuery = _buildMealSearchQuery(mealType, analysis, goalStrategy);
      
      // Try multiple recipe sources with fallbacks
      Map<String, dynamic>? selectedRecipe;
      
      // 1. Try Spoonacular API first
      try {
        final recipes = await RecipeService.fetchRecipes(searchQuery);
        if (recipes.isNotEmpty) {
          final filteredRecipes = _filterRecipesByPreferences(recipes, analysis);
          if (filteredRecipes.isNotEmpty) {
            selectedRecipe = _selectBestRecipe(filteredRecipes, targetCalories, analysis);
          }
        }
      } catch (e) {
        print('Spoonacular API failed: $e - likely rate limited');
      }
      
      // 2. If no recipe found, try local fallback recipes
      if (selectedRecipe == null) {
        selectedRecipe = _getLocalFallbackRecipe(mealType, analysis);
      }
      
      // 3. If still no recipe, generate generic meal
      if (selectedRecipe == null) {
        return _generateFallbackMeal(mealType, targetCalories, analysis);
      }
      
      // Calculate portion size to meet calorie target
      final portionSize = _calculatePortionSize(selectedRecipe, targetCalories);
      
      return {
        'recipe': selectedRecipe,
        'portionSize': portionSize,
        'estimatedCalories': targetCalories,
        'mealType': mealType,
        'nutritionalInfo': _extractNutritionalInfo(selectedRecipe, portionSize),
      };
    } catch (e) {
      print('Error generating meal for $mealType: $e');
      return _generateFallbackMeal(mealType, targetCalories, analysis);
    }
  }

  /// Build search query for meal generation
  static String _buildMealSearchQuery(
    String mealType,
    Map<String, dynamic> analysis,
    Map<String, dynamic> goalStrategy,
  ) {
    final List<String> queryParts = [];
    
    // Add meal type specific terms
    switch (mealType) {
      case 'breakfast':
        queryParts.addAll(['breakfast', 'morning', 'eggs', 'oatmeal', 'yogurt']);
        break;
      case 'lunch':
        queryParts.addAll(['lunch', 'midday', 'salad', 'sandwich', 'soup']);
        break;
      case 'dinner':
        queryParts.addAll(['dinner', 'evening', 'main course', 'protein']);
        break;
      case 'snack':
        queryParts.addAll(['snack', 'healthy', 'nuts', 'fruit']);
        break;
    }
    
    // Add goal-specific terms
    final focusAreas = goalStrategy['focus'] as List<String>? ?? [];
    for (final focus in focusAreas) {
      switch (focus) {
        case 'high_protein':
          queryParts.addAll(['protein', 'chicken', 'fish', 'tofu']);
          break;
        case 'low_calorie':
          queryParts.addAll(['low calorie', 'light', 'vegetables']);
          break;
        case 'fiber_rich':
          queryParts.addAll(['fiber', 'whole grains', 'vegetables']);
          break;
        case 'high_calorie':
          queryParts.addAll(['nutritious', 'healthy fats', 'avocado']);
          break;
        case 'complex_carbs':
          queryParts.addAll(['quinoa', 'brown rice', 'sweet potato']);
          break;
      }
    }
    
    // Add dietary preference terms
    for (final preference in analysis['dietaryPreferences']) {
      if (preference != 'None') {
        queryParts.add(preference.toLowerCase());
      }
    }
    
    // Remove duplicates and join
    return queryParts.toSet().take(5).join(' ');
  }

  /// Filter recipes based on user preferences and restrictions
  static List<Map<String, dynamic>> _filterRecipesByPreferences(
    List<dynamic> recipes,
    Map<String, dynamic> analysis,
  ) {
    return recipes.where((recipe) {
      // Check for allergies
      for (final allergy in analysis['allergies']) {
        if (allergy != 'None' && _containsAllergen(recipe, allergy)) {
          return false;
        }
      }
      
      // Check dietary restrictions
      for (final restriction in analysis['dietaryPreferences']) {
        if (restriction != 'None' && !_meetsDietaryRestriction(recipe, restriction)) {
          return false;
        }
      }
      
      return true;
    }).cast<Map<String, dynamic>>().toList();
  }

  /// Select the best recipe from filtered options
  static Map<String, dynamic> _selectBestRecipe(
    List<Map<String, dynamic>> recipes,
    double targetCalories,
    Map<String, dynamic> analysis,
  ) {
    // Simple scoring system - can be enhanced with ML later
    Map<String, dynamic> bestRecipe = recipes.first;
    double bestScore = 0;
    
    for (final recipe in recipes) {
      double score = 0;
      
      // Score based on calorie proximity
      final recipeCalories = recipe['calories']?.toDouble() ?? 0;
      if (recipeCalories > 0) {
        final calorieDiff = (recipeCalories - targetCalories).abs();
        score += 100 - (calorieDiff / targetCalories * 100);
      }
      
      // Score based on protein content (if goal is muscle building or weight loss)
      if (analysis['goal'] == 'Build muscle' || analysis['goal'] == 'Lose weight') {
        final protein = recipe['protein']?.toDouble() ?? 0;
        score += protein * 2;
      }
      
      // Score based on fiber content (if goal is weight loss or health)
      if (analysis['goal'] == 'Lose weight' || analysis['goal'] == 'Eat healthier / clean eating') {
        final fiber = recipe['fiber']?.toDouble() ?? 0;
        score += fiber * 3;
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestRecipe = recipe;
      }
    }
    
    return bestRecipe;
  }

  /// Calculate portion size to meet calorie target
  static double _calculatePortionSize(
    Map<String, dynamic> recipe,
    double targetCalories,
  ) {
    final recipeCalories = recipe['calories']?.toDouble() ?? 0;
    if (recipeCalories <= 0) return 1.0;
    
    return targetCalories / recipeCalories;
  }

  /// Extract nutritional information from recipe
  static Map<String, dynamic> _extractNutritionalInfo(
    Map<String, dynamic> recipe,
    double portionSize,
  ) {
    return {
      'calories': (recipe['calories']?.toDouble() ?? 0) * portionSize,
      'protein': (recipe['protein']?.toDouble() ?? 0) * portionSize,
      'carbs': (recipe['carbs']?.toDouble() ?? 0) * portionSize,
      'fat': (recipe['fat']?.toDouble() ?? 0) * portionSize,
      'fiber': (recipe['fiber']?.toDouble() ?? 0) * portionSize,
    };
  }

  /// Calculate nutritional goals based on user profile
  static Map<String, dynamic> _calculateNutritionalGoals(Map<String, dynamic> analysis) {
    final dailyCalories = analysis['dailyCalories'];
    final goalStrategy = analysis['goalStrategy'];
    
    return {
      'dailyCalories': dailyCalories,
      'protein': (dailyCalories * (goalStrategy['proteinRatio'] ?? 0.25)) / 4, // 4 cal per gram
      'carbs': (dailyCalories * (goalStrategy['carbRatio'] ?? 0.45)) / 4, // 4 cal per gram
      'fat': (dailyCalories * (goalStrategy['fatRatio'] ?? 0.3)) / 9, // 9 cal per gram
      'fiber': analysis['gender'] == 'Male' ? 38.0 : 25.0, // Recommended daily fiber
    };
  }

  /// Generate personalized recommendations
  static List<String> _generateRecommendations(Map<String, dynamic> analysis) {
    final recommendations = <String>[];
    
    // Weight-based recommendations
    final bmi = analysis['bmi'];
    if (bmi < 18.5) {
      recommendations.add('Consider increasing your caloric intake with nutrient-dense foods');
    } else if (bmi > 25) {
      recommendations.add('Focus on portion control and high-fiber foods to feel full longer');
    }
    
    // Goal-based recommendations
    switch (analysis['goal']) {
      case 'Lose weight':
        recommendations.add('Eat protein-rich foods to maintain muscle mass during weight loss');
        recommendations.add('Include plenty of vegetables to increase fiber and reduce calorie density');
        break;
      case 'Build muscle':
        recommendations.add('Consume protein within 30 minutes after your workout');
        recommendations.add('Include complex carbohydrates to fuel your training sessions');
        break;
      case 'Eat healthier / clean eating':
        recommendations.add('Choose whole, unprocessed foods over refined alternatives');
        recommendations.add('Include a variety of colorful fruits and vegetables');
        break;
    }
    
    // Health condition recommendations
    for (final condition in analysis['healthConditions']) {
      switch (condition) {
        case 'Diabetes':
          recommendations.add('Monitor carbohydrate intake and choose low-glycemic index foods');
          break;
        case 'Hypertension':
          recommendations.add('Limit sodium intake and increase potassium-rich foods');
          break;
        case 'High Cholesterol':
          recommendations.add('Choose heart-healthy fats and increase soluble fiber intake');
          break;
      }
    }
    
    return recommendations;
  }

  /// Helper methods
  static int _calculateAge(String? birthday) {
    if (birthday == null) return 30;
    try {
      final birthDate = DateTime.parse(birthday);
      final now = DateTime.now();
      return now.year - birthDate.year - (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day) ? 1 : 0);
    } catch (e) {
      return 30;
    }
  }

  static String _getWeightCategory(double weight, double height, String gender, int age) {
    final bmi = weight / ((height / 100) * (height / 100));
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  static bool _containsAllergen(Map<String, dynamic> recipe, String allergen) {
    // Simple allergen checking - can be enhanced with proper allergen detection
    final title = recipe['title']?.toString().toLowerCase() ?? '';
    final ingredients = recipe['ingredients']?.toString().toLowerCase() ?? '';
    
    final allergenMap = {
      'Peanuts': ['peanut', 'peanuts'],
      'Tree Nuts': ['almond', 'walnut', 'cashew', 'pecan', 'hazelnut'],
      'Milk': ['milk', 'dairy', 'cheese', 'yogurt', 'cream'],
      'Eggs': ['egg', 'eggs'],
      'Fish': ['fish', 'salmon', 'tuna', 'cod'],
      'Shellfish': ['shrimp', 'crab', 'lobster', 'clam'],
      'Wheat': ['wheat', 'bread', 'pasta', 'flour'],
      'Soy': ['soy', 'soya', 'tofu', 'edamame'],
      'Sesame': ['sesame', 'tahini'],
    };
    
    final allergens = allergenMap[allergen] ?? [];
    return allergens.any((a) => title.contains(a) || ingredients.contains(a));
  }

  static bool _meetsDietaryRestriction(Map<String, dynamic> recipe, String restriction) {
    // Simple dietary restriction checking - can be enhanced
    final title = recipe['title']?.toString().toLowerCase() ?? '';
    final ingredients = recipe['ingredients']?.toString().toLowerCase() ?? '';
    
    switch (restriction) {
      case 'Vegetarian':
        return !_containsAny(title, ingredients, ['meat', 'beef', 'pork', 'chicken', 'fish']);
      case 'Vegan':
        return !_containsAny(title, ingredients, ['meat', 'beef', 'pork', 'chicken', 'fish', 'dairy', 'milk', 'cheese', 'egg']);
      case 'Gluten Free':
        return !_containsAny(title, ingredients, ['wheat', 'gluten', 'bread', 'pasta']);
      default:
        return true;
    }
  }

  static bool _containsAny(String title, String ingredients, List<String> terms) {
    return terms.any((term) => title.contains(term) || ingredients.contains(term));
  }

  static Map<String, dynamic> _calculateMealNutrition(Map<String, dynamic> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    
    for (final meal in meals.values) {
      if (meal is Map<String, dynamic> && meal['nutritionalInfo'] != null) {
        final nutrition = meal['nutritionalInfo'] as Map<String, dynamic>;
        totalCalories += nutrition['calories']?.toDouble() ?? 0;
        totalProtein += nutrition['protein']?.toDouble() ?? 0;
        totalCarbs += nutrition['carbs']?.toDouble() ?? 0;
        totalFat += nutrition['fat']?.toDouble() ?? 0;
        totalFiber += nutrition['fiber']?.toDouble() ?? 0;
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

  /// Get a local fallback recipe when API fails
  static Map<String, dynamic>? _getLocalFallbackRecipe(
    String mealType,
    Map<String, dynamic> analysis,
  ) {
    // Local recipe database - these are high-quality, curated recipes
    final localRecipes = _getLocalRecipeDatabase();
    
    // Filter recipes based on meal type and dietary preferences
    final availableRecipes = localRecipes.where((recipe) {
      // Check meal type
      if (recipe['mealType'] != mealType) return false;
      
      // Check dietary restrictions
      final dietaryPrefs = analysis['dietaryPreferences'] as List<String>? ?? [];
      if (dietaryPrefs.contains('Vegetarian') && recipe['containsMeat'] == true) return false;
      if (dietaryPrefs.contains('Vegan') && (recipe['containsMeat'] == true || recipe['containsDairy'] == true)) return false;
      
      // Check allergies
      final allergies = analysis['allergies'] as List<String>? ?? [];
      for (final allergy in allergies) {
        if (allergy != 'None' && recipe['allergens']?.contains(allergy) == true) return false;
      }
      
      return true;
    }).toList();
    
    if (availableRecipes.isEmpty) return null;
    
    // Return a random suitable recipe
    final random = Random();
    return availableRecipes[random.nextInt(availableRecipes.length)];
  }
  
  /// Local recipe database with high-quality recipes
  static List<Map<String, dynamic>> _getLocalRecipeDatabase() {
    return [
      // Breakfast Recipes
      {
        'id': 'local_breakfast_1',
        'title': 'Greek Yogurt Parfait',
        'description': 'Layered Greek yogurt with honey, granola, and fresh berries',
        'mealType': 'breakfast',
        'calories': 320,
        'protein': 18.0,
        'carbs': 45.0,
        'fat': 8.0,
        'fiber': 6.0,
        'containsMeat': false,
        'containsDairy': true,
        'allergens': ['Milk'],
        'ingredients': ['Greek yogurt', 'Honey', 'Granola', 'Mixed berries'],
        'instructions': 'Layer yogurt, honey, granola, and berries in a glass. Repeat layers and serve.',
      },
      {
        'id': 'local_breakfast_2',
        'title': 'Avocado Toast with Eggs',
        'description': 'Whole grain toast topped with mashed avocado and poached eggs',
        'mealType': 'breakfast',
        'calories': 380,
        'protein': 16.0,
        'carbs': 28.0,
        'fat': 22.0,
        'fiber': 8.0,
        'containsMeat': false,
        'containsDairy': false,
        'allergens': ['Eggs'],
        'ingredients': ['Whole grain bread', 'Avocado', 'Eggs', 'Salt', 'Pepper'],
        'instructions': 'Toast bread, mash avocado, poach eggs, and assemble.',
      },
      
      // Lunch Recipes
      {
        'id': 'local_lunch_1',
        'title': 'Mediterranean Quinoa Bowl',
        'description': 'Quinoa salad with cherry tomatoes, cucumber, olives, and feta',
        'mealType': 'lunch',
        'calories': 420,
        'protein': 14.0,
        'carbs': 58.0,
        'fat': 18.0,
        'fiber': 12.0,
        'containsMeat': false,
        'containsDairy': true,
        'allergens': ['Milk'],
        'ingredients': ['Quinoa', 'Cherry tomatoes', 'Cucumber', 'Kalamata olives', 'Feta cheese'],
        'instructions': 'Cook quinoa, chop vegetables, mix with olive oil and lemon juice.',
      },
      {
        'id': 'local_lunch_2',
        'title': 'Grilled Chicken Caesar Salad',
        'description': 'Fresh romaine lettuce with grilled chicken, parmesan, and caesar dressing',
        'mealType': 'lunch',
        'calories': 450,
        'protein': 35.0,
        'carbs': 12.0,
        'fat': 28.0,
        'fiber': 6.0,
        'containsMeat': true,
        'containsDairy': true,
        'allergens': ['Eggs', 'Milk'],
        'ingredients': ['Romaine lettuce', 'Grilled chicken breast', 'Parmesan cheese', 'Caesar dressing'],
        'instructions': 'Grill chicken, chop lettuce, assemble salad with dressing and cheese.',
      },
      
      // Dinner Recipes
      {
        'id': 'local_dinner_1',
        'title': 'Salmon with Roasted Vegetables',
        'description': 'Baked salmon fillet with seasonal roasted vegetables',
        'mealType': 'dinner',
        'calories': 520,
        'protein': 38.0,
        'carbs': 32.0,
        'fat': 28.0,
        'fiber': 14.0,
        'containsMeat': false,
        'containsDairy': false,
        'allergens': ['Fish'],
        'ingredients': ['Salmon fillet', 'Broccoli', 'Carrots', 'Olive oil', 'Lemon'],
        'instructions': 'Season salmon, roast vegetables, bake salmon until flaky.',
      },
      {
        'id': 'local_dinner_2',
        'title': 'Vegetarian Stir-Fry',
        'description': 'Colorful vegetable stir-fry with tofu and brown rice',
        'mealType': 'dinner',
        'calories': 480,
        'protein': 22.0,
        'carbs': 68.0,
        'fat': 16.0,
        'fiber': 16.0,
        'containsMeat': false,
        'containsDairy': false,
        'allergens': ['Soy'],
        'ingredients': ['Tofu', 'Broccoli', 'Bell peppers', 'Brown rice', 'Soy sauce'],
        'instructions': 'Cook rice, stir-fry vegetables and tofu, combine with sauce.',
      },
      
      // Snack Recipes
      {
        'id': 'local_snack_1',
        'title': 'Trail Mix',
        'description': 'Homemade trail mix with nuts, seeds, and dried fruits',
        'mealType': 'snack',
        'calories': 280,
        'protein': 8.0,
        'carbs': 32.0,
        'fat': 16.0,
        'fiber': 6.0,
        'containsMeat': false,
        'containsDairy': false,
        'allergens': ['Tree Nuts'],
        'ingredients': ['Almonds', 'Pumpkin seeds', 'Dried cranberries', 'Dark chocolate chips'],
        'instructions': 'Mix all ingredients in a bowl and store in an airtight container.',
      },
    ];
  }

  static Map<String, dynamic> _generateFallbackMeal(
    String mealType,
    double targetCalories,
    Map<String, dynamic> analysis,
  ) {
    // Generate a simple fallback meal when recipe fetching fails
    final mealTemplates = {
      'breakfast': {
        'title': 'Healthy Breakfast Bowl',
        'description': 'A balanced breakfast with protein, whole grains, and fruits',
        'estimatedCalories': targetCalories,
        'ingredients': ['Oatmeal', 'Greek yogurt', 'Berries', 'Nuts', 'Honey'],
      },
      'lunch': {
        'title': 'Nutritious Lunch Plate',
        'description': 'A wholesome lunch with lean protein and vegetables',
        'estimatedCalories': targetCalories,
        'ingredients': ['Grilled chicken', 'Mixed greens', 'Quinoa', 'Vegetables', 'Olive oil'],
      },
      'dinner': {
        'title': 'Balanced Dinner',
        'description': 'A complete dinner with protein, complex carbs, and vegetables',
        'estimatedCalories': targetCalories,
        'ingredients': ['Salmon', 'Brown rice', 'Broccoli', 'Sweet potato', 'Herbs'],
      },
      'snack': {
        'title': 'Healthy Snack',
        'description': 'A nutritious snack to keep you energized',
        'estimatedCalories': targetCalories,
        'ingredients': ['Apple', 'Almonds', 'Greek yogurt'],
      },
    };
    
    return {
      'recipe': mealTemplates[mealType] ?? mealTemplates['lunch']!,
      'portionSize': 1.0,
      'estimatedCalories': targetCalories,
      'mealType': mealType,
      'nutritionalInfo': {
        'calories': targetCalories,
        'protein': targetCalories * 0.25 / 4,
        'carbs': targetCalories * 0.45 / 4,
        'fat': targetCalories * 0.3 / 9,
        'fiber': 5.0,
      },
    };
  }
} 