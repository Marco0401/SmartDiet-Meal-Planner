/// Service for determining meal suitability based on time of day
/// 
/// Provides intelligent meal recommendations based on:
/// - Current time of day
/// - Meal type characteristics
/// - Cultural meal patterns
/// - Recipe metadata
class MealTimeService {
  
  /// Meal time periods
  static const String breakfast = 'breakfast';
  static const String brunch = 'brunch';
  static const String lunch = 'lunch';
  static const String snack = 'snack';
  static const String dinner = 'dinner';
  static const String lateNight = 'late_night';

  /// Get current meal period based on time
  static String getCurrentMealPeriod() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour >= 6 && hour < 11) {
      return breakfast;
    } else if (hour >= 11 && hour < 14) {
      return lunch;
    } else if (hour >= 14 && hour < 17) {
      return snack;
    } else if (hour >= 17 && hour < 22) {
      return dinner;
    } else {
      return lateNight;
    }
  }

  /// Get meal period for a specific time
  static String getMealPeriodForTime(DateTime time) {
    final hour = time.hour;
    
    if (hour >= 6 && hour < 11) {
      return breakfast;
    } else if (hour >= 11 && hour < 14) {
      return lunch;
    } else if (hour >= 14 && hour < 17) {
      return snack;
    } else if (hour >= 17 && hour < 22) {
      return dinner;
    } else {
      return lateNight;
    }
  }

  /// Get display name for meal period
  static String getMealPeriodDisplayName(String period) {
    switch (period) {
      case breakfast:
        return 'Breakfast';
      case brunch:
        return 'Brunch';
      case lunch:
        return 'Lunch';
      case snack:
        return 'Snack';
      case dinner:
        return 'Dinner';
      case lateNight:
        return 'Late Night';
      default:
        return 'Meal';
    }
  }

  /// Get icon for meal period
  static String getMealPeriodIcon(String period) {
    switch (period) {
      case breakfast:
        return '🌅';
      case brunch:
        return '🥐';
      case lunch:
        return '🌞';
      case snack:
        return '🍎';
      case dinner:
        return '🌙';
      case lateNight:
        return '🌃';
      default:
        return '🍽️';
    }
  }

  /// Breakfast-suitable dish types
  static const List<String> breakfastDishTypes = [
    'breakfast',
    'brunch',
    'morning meal',
    'cereal',
    'porridge',
    'oatmeal',
    'pancake',
    'waffle',
    'french toast',
    'omelet',
    'scrambled eggs',
    'fried eggs',
    'boiled eggs',
    'breakfast burrito',
    'breakfast sandwich',
    'bagel',
    'muffin',
    'croissant',
    'danish',
    'smoothie',
    'smoothie bowl',
    'acai bowl',
    'yogurt',
    'granola',
  ];

  /// Lunch-suitable dish types
  static const List<String> lunchDishTypes = [
    'lunch',
    'sandwich',
    'wrap',
    'burger',
    'salad',
    'soup',
    'pasta salad',
    'grain bowl',
    'rice bowl',
    'poke bowl',
    'bento',
    'light meal',
    'quick meal',
  ];

  /// Dinner-suitable dish types
  static const List<String> dinnerDishTypes = [
    'dinner',
    'main course',
    'main dish',
    'entree',
    'supper',
    'evening meal',
    'casserole',
    'roast',
    'stew',
    'curry',
    'pasta',
    'rice dish',
    'noodles',
    'stir fry',
    'grilled',
    'baked',
    'braised',
  ];

  /// Snack-suitable dish types
  static const List<String> snackDishTypes = [
    'snack',
    'appetizer',
    'finger food',
    'hors d\'oeuvre',
    'tapas',
    'small plates',
    'light bite',
    'quick snack',
    'energy bar',
    'protein bar',
    'trail mix',
    'nuts',
    'fruit',
    'chips',
    'crackers',
    'dip',
  ];

  /// Breakfast-suitable keywords in recipe titles/descriptions
  static const List<String> breakfastKeywords = [
    'breakfast', 'morning', 'brunch', 'cereal', 'oatmeal', 'porridge',
    'pancake', 'waffle', 'french toast', 'eggs', 'omelet', 'scrambled',
    'fried egg', 'boiled egg', 'poached egg', 'bacon', 'sausage',
    'hash brown', 'toast', 'bagel', 'muffin', 'croissant', 'danish',
    'smoothie', 'juice', 'coffee', 'tea', 'yogurt', 'granola',
  ];

  /// Lunch-suitable keywords
  static const List<String> lunchKeywords = [
    'lunch', 'sandwich', 'wrap', 'burger', 'salad', 'soup',
    'panini', 'sub', 'hoagie', 'club sandwich', 'blt',
    'chicken salad', 'tuna salad', 'pasta salad',
    'grain bowl', 'rice bowl', 'poke', 'bento',
  ];

  /// Dinner-suitable keywords
  static const List<String> dinnerKeywords = [
    'dinner', 'supper', 'main course', 'entree',
    'roast', 'roasted', 'grilled', 'baked', 'braised',
    'stew', 'casserole', 'curry', 'pasta', 'lasagna',
    'stir fry', 'fried rice', 'noodles', 'ramen',
    'steak', 'chicken breast', 'fish fillet', 'pork chop',
  ];

  /// Snack-suitable keywords
  static const List<String> snackKeywords = [
    'snack', 'appetizer', 'finger food', 'bite',
    'chips', 'crackers', 'dip', 'salsa', 'guacamole',
    'hummus', 'nuts', 'trail mix', 'popcorn',
    'fruit', 'vegetable', 'cheese', 'olives',
  ];

  /// Check if a recipe is suitable for a specific meal period
  /// 
  /// Returns a suitability score from 0.0 to 1.0
  static double getRecipeSuitability(
    Map<String, dynamic> recipe,
    String mealPeriod,
  ) {
    double score = 0.0;
    int checks = 0;

    // Get recipe metadata
    final title = recipe['title']?.toString().toLowerCase() ?? '';
    final description = recipe['description']?.toString().toLowerCase() ?? '';
    final dishTypes = recipe['dishTypes'] as List<dynamic>? ?? [];
    final cuisines = recipe['cuisines'] as List<dynamic>? ?? [];
    final readyInMinutes = recipe['readyInMinutes'] as int? ?? 0;

    // Check dish types
    final dishTypeStrings = dishTypes.map((d) => d.toString().toLowerCase()).toList();
    
    switch (mealPeriod) {
      case breakfast:
        // Check dish types
        for (final dishType in breakfastDishTypes) {
          if (dishTypeStrings.any((d) => d.contains(dishType))) {
            score += 0.4;
            checks++;
            break;
          }
        }
        
        // Check keywords in title/description
        for (final keyword in breakfastKeywords) {
          if (title.contains(keyword) || description.contains(keyword)) {
            score += 0.3;
            checks++;
            break;
          }
        }
        
        // Breakfast should be quick (prefer < 30 minutes)
        if (readyInMinutes > 0 && readyInMinutes <= 30) {
          score += 0.2;
          checks++;
        } else if (readyInMinutes > 30) {
          score -= 0.1;
        }
        
        // Check for breakfast-inappropriate items
        if (title.contains('dinner') || title.contains('supper') || 
            description.contains('heavy') || description.contains('rich')) {
          score -= 0.3;
        }
        break;

      case lunch:
        // Check dish types
        for (final dishType in lunchDishTypes) {
          if (dishTypeStrings.any((d) => d.contains(dishType))) {
            score += 0.4;
            checks++;
            break;
          }
        }
        
        // Check keywords
        for (final keyword in lunchKeywords) {
          if (title.contains(keyword) || description.contains(keyword)) {
            score += 0.3;
            checks++;
            break;
          }
        }
        
        // Lunch should be moderate time (prefer < 45 minutes)
        if (readyInMinutes > 0 && readyInMinutes <= 45) {
          score += 0.2;
          checks++;
        }
        break;

      case snack:
        // Check dish types
        for (final dishType in snackDishTypes) {
          if (dishTypeStrings.any((d) => d.contains(dishType))) {
            score += 0.4;
            checks++;
            break;
          }
        }
        
        // Check keywords
        for (final keyword in snackKeywords) {
          if (title.contains(keyword) || description.contains(keyword)) {
            score += 0.3;
            checks++;
            break;
          }
        }
        
        // Snacks should be very quick (prefer < 15 minutes)
        if (readyInMinutes > 0 && readyInMinutes <= 15) {
          score += 0.3;
          checks++;
        } else if (readyInMinutes > 30) {
          score -= 0.2;
        }
        break;

      case dinner:
        // Check dish types
        for (final dishType in dinnerDishTypes) {
          if (dishTypeStrings.any((d) => d.contains(dishType))) {
            score += 0.4;
            checks++;
            break;
          }
        }
        
        // Check keywords
        for (final keyword in dinnerKeywords) {
          if (title.contains(keyword) || description.contains(keyword)) {
            score += 0.3;
            checks++;
            break;
          }
        }
        
        // Dinner can take longer (up to 90 minutes is fine)
        if (readyInMinutes > 0 && readyInMinutes <= 90) {
          score += 0.1;
          checks++;
        }
        
        // Check for dinner-inappropriate items
        if (title.contains('breakfast') || title.contains('cereal') || 
            title.contains('smoothie')) {
          score -= 0.3;
        }
        break;

      case lateNight:
        // Late night prefers light, quick meals
        if (readyInMinutes > 0 && readyInMinutes <= 20) {
          score += 0.3;
          checks++;
        }
        
        // Check for light keywords
        if (title.contains('light') || title.contains('simple') || 
            description.contains('light') || description.contains('simple')) {
          score += 0.2;
          checks++;
        }
        
        // Avoid heavy meals
        if (title.contains('heavy') || title.contains('rich') || 
            description.contains('heavy') || description.contains('rich')) {
          score -= 0.3;
        }
        break;
    }

    // If no specific checks matched, give a neutral score
    if (checks == 0) {
      return 0.5; // Neutral - could work for any meal
    }

    // Normalize score to 0.0 - 1.0 range
    final normalizedScore = (score / checks).clamp(0.0, 1.0);
    
    return normalizedScore;
  }

  /// Filter recipes by meal period suitability
  /// 
  /// Returns recipes sorted by suitability score
  static List<Map<String, dynamic>> filterRecipesByMealPeriod(
    List<Map<String, dynamic>> recipes,
    String mealPeriod, {
    double minSuitability = 0.3,
  }) {
    final scoredRecipes = recipes.map((recipe) {
      final suitability = getRecipeSuitability(recipe, mealPeriod);
      return {
        'recipe': recipe,
        'suitability': suitability,
      };
    }).where((item) {
      return (item['suitability'] as double) >= minSuitability;
    }).toList();

    // Sort by suitability score (highest first)
    scoredRecipes.sort((a, b) {
      return (b['suitability'] as double).compareTo(a['suitability'] as double);
    });

    return scoredRecipes.map((item) => item['recipe'] as Map<String, dynamic>).toList();
  }

  /// Get recommended meal period for a recipe
  /// 
  /// Returns the meal period with the highest suitability score
  static String getRecommendedMealPeriod(Map<String, dynamic> recipe) {
    final periods = [breakfast, lunch, snack, dinner];
    double maxScore = 0.0;
    String bestPeriod = lunch; // Default to lunch

    for (final period in periods) {
      final score = getRecipeSuitability(recipe, period);
      if (score > maxScore) {
        maxScore = score;
        bestPeriod = period;
      }
    }

    return bestPeriod;
  }

  /// Get all suitable meal periods for a recipe
  /// 
  /// Returns a map of meal periods to suitability scores
  static Map<String, double> getAllMealPeriodSuitability(Map<String, dynamic> recipe) {
    return {
      breakfast: getRecipeSuitability(recipe, breakfast),
      lunch: getRecipeSuitability(recipe, lunch),
      snack: getRecipeSuitability(recipe, snack),
      dinner: getRecipeSuitability(recipe, dinner),
      lateNight: getRecipeSuitability(recipe, lateNight),
    };
  }

  /// Get time range for a meal period
  static String getMealPeriodTimeRange(String period) {
    switch (period) {
      case breakfast:
        return '6:00 AM - 11:00 AM';
      case brunch:
        return '10:00 AM - 2:00 PM';
      case lunch:
        return '11:00 AM - 2:00 PM';
      case snack:
        return '2:00 PM - 5:00 PM';
      case dinner:
        return '5:00 PM - 10:00 PM';
      case lateNight:
        return '10:00 PM - 6:00 AM';
      default:
        return 'Anytime';
    }
  }

  /// Check if current time is within a meal period
  static bool isCurrentlyInMealPeriod(String period) {
    return getCurrentMealPeriod() == period;
  }

  /// Get greeting message based on current meal period
  static String getMealPeriodGreeting() {
    final period = getCurrentMealPeriod();
    final hour = DateTime.now().hour;
    
    switch (period) {
      case breakfast:
        return 'Good morning! What would you like for breakfast?';
      case lunch:
        return 'Good afternoon! Ready for lunch?';
      case snack:
        return 'Snack time! Looking for something light?';
      case dinner:
        return 'Good evening! What\'s for dinner?';
      case lateNight:
        if (hour >= 22) {
          return 'Late night cravings? Here are some light options.';
        } else {
          return 'Early bird! Here are some breakfast ideas.';
        }
      default:
        return 'What would you like to eat?';
    }
  }

  /// Get suggested meal types for current time
  static List<String> getSuggestedMealTypes() {
    final period = getCurrentMealPeriod();
    
    switch (period) {
      case breakfast:
        return ['Breakfast', 'Brunch', 'Morning Meal'];
      case lunch:
        return ['Lunch', 'Light Meal', 'Midday Meal'];
      case snack:
        return ['Snack', 'Appetizer', 'Light Bite'];
      case dinner:
        return ['Dinner', 'Main Course', 'Evening Meal'];
      case lateNight:
        return ['Light Meal', 'Snack', 'Quick Bite'];
      default:
        return ['Meal'];
    }
  }

  /// Debug: Print suitability analysis for a recipe
  static void printRecipeSuitabilityAnalysis(Map<String, dynamic> recipe) {
    print('\n=== Recipe Suitability Analysis ===');
    print('Recipe: ${recipe['title']}');
    print('Ready in: ${recipe['readyInMinutes']} minutes');
    print('\nSuitability Scores:');
    
    final suitability = getAllMealPeriodSuitability(recipe);
    for (final entry in suitability.entries) {
      final score = (entry.value * 100).toStringAsFixed(0);
      final icon = getMealPeriodIcon(entry.key);
      final name = getMealPeriodDisplayName(entry.key);
      print('  $icon $name: $score%');
    }
    
    final recommended = getRecommendedMealPeriod(recipe);
    print('\nRecommended: ${getMealPeriodDisplayName(recommended)}');
    print('===================================\n');
  }
}
