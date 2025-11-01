import '../models/user_profile.dart';

/// Shared nutrition calculation service
/// Used by both NutritionAnalyticsPage and NutritionProgressNotifier
/// to ensure consistent target calculations across the app
class NutritionCalculatorService {
  
  /// Calculate daily nutrition targets based on user profile
  static Map<String, dynamic> calculateDailyTargets(UserProfile profile) {
    // Calculate BMI
    final heightInMeters = profile.height / 100;
    final bmi = profile.weight / (heightInMeters * heightInMeters);
    
    String weightCategory;
    if (bmi < 18.5) {
      weightCategory = 'Underweight';
    } else if (bmi < 25) {
      weightCategory = 'Normal weight';
    } else if (bmi < 30) {
      weightCategory = 'Overweight';
    } else {
      weightCategory = 'Obesity';
    }

    // Calculate BMR (Basal Metabolic Rate)
    double bmr;
    if (profile.gender.toLowerCase() == 'male') {
      bmr = 88.362 + (13.397 * profile.weight) + (4.799 * profile.height) - (5.677 * profile.age);
    } else {
      bmr = 447.593 + (9.247 * profile.weight) + (3.098 * profile.height) - (4.330 * profile.age);
    }

    // Apply activity multiplier
    double activityMultiplier = 1.2; // Sedentary default
    final activityLower = profile.activityLevel.toLowerCase();
    print('DEBUG: NutritionCalculator - Activity Level: "${profile.activityLevel}" -> lowercase: "$activityLower"');
    
    if (activityLower.contains('lightly')) {
      activityMultiplier = 1.375;
    } else if (activityLower.contains('moderately')) {
      activityMultiplier = 1.55;
    } else if (activityLower.contains('very active')) {
      activityMultiplier = 1.725;
    } else if (activityLower.contains('extremely')) {
      activityMultiplier = 1.9;
    } else if (activityLower.contains('sedentary')) {
      activityMultiplier = 1.2;
    }
    
    print('DEBUG: NutritionCalculator - Activity Multiplier: $activityMultiplier');

    final dailyCalories = bmr * activityMultiplier;

    // Adjust for goals
    double targetCalories = dailyCalories;
    final goalLowerCase = profile.goal.toLowerCase();
    print('DEBUG: NutritionCalculator - Goal: "${profile.goal}" -> lowercase: "$goalLowerCase"');
    print('DEBUG: NutritionCalculator - TDEE before adjustment: $dailyCalories kcal');
    
    switch (goalLowerCase) {
      case 'lose weight':
        targetCalories *= 0.85; // 15% deficit
        break;
      case 'gain weight':
      case 'gain muscle':
      case 'build muscle': // Added to match onboarding goal option
        targetCalories *= 1.15; // 15% surplus
        break;
      case 'maintain current weight':
      case 'maintain weight':
      case 'eat healthier / clean eating':
      case 'none':
      default:
        // Keep same calories (maintenance)
        break;
    }
    
    print('DEBUG: NutritionCalculator - Target calories after adjustment: $targetCalories kcal');

    // Calculate macros
    final protein = (targetCalories * 0.25) / 4; // 25% of calories from protein
    final fat = (targetCalories * 0.30) / 9; // 30% of calories from fat
    final carbs = (targetCalories * 0.45) / 4; // 45% of calories from carbs
    final fiber = targetCalories / 80; // Roughly 1g per 80 calories

    return {
      'age': profile.age,
      'height': profile.height,
      'weight': profile.weight,
      'gender': profile.gender,
      'bmi': bmi,
      'weightCategory': weightCategory,
      'goal': profile.goal,
      'activityLevel': profile.activityLevel,
      'bmr': bmr,
      'dailyCalories': targetCalories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'allergies': profile.allergies,
      'healthConditions': profile.healthConditions,
    };
  }

  /// Calculate targets from raw user data map (for backward compatibility)
  static Map<String, double> calculateDailyTargetsFromMap(Map<String, dynamic> userData) {
    final age = userData['age'] ?? 25;
    final gender = (userData['gender'] ?? 'Male').toString().toLowerCase();
    final height = _toDouble(userData['height'] ?? 175);
    final weight = _toDouble(userData['weight'] ?? 70);
    final activityLevel = (userData['activityLevel'] ?? 'Moderately Active').toString().toLowerCase();
    final goal = (userData['goal'] ?? 'Maintain Weight').toString().toLowerCase();

    // Calculate BMR
    double bmr;
    if (gender == 'male') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }

    // Activity multiplier
    double activityMultiplier = 1.2; // Default sedentary
    if (activityLevel.contains('lightly')) {
      activityMultiplier = 1.375;
    } else if (activityLevel.contains('moderately')) {
      activityMultiplier = 1.55;
    } else if (activityLevel.contains('very active')) {
      activityMultiplier = 1.725;
    } else if (activityLevel.contains('extremely')) {
      activityMultiplier = 1.9;
    } else if (activityLevel.contains('sedentary')) {
      activityMultiplier = 1.2;
    }

    double dailyCalories = bmr * activityMultiplier;

    // Adjust for goals - EXACT SAME LOGIC as UserProfile version
    switch (goal) {
      case 'lose weight':
        dailyCalories *= 0.85; // 15% deficit
        break;
      case 'gain weight':
      case 'gain muscle':
      case 'build muscle': // Added to match onboarding goal option
        dailyCalories *= 1.15; // 15% surplus
        break;
      case 'maintain current weight':
      case 'maintain weight':
      case 'eat healthier / clean eating':
      case 'none':
      default:
        // Keep same calories (maintenance)
        break;
    }

    // Calculate macros
    final protein = (dailyCalories * 0.25) / 4;
    final fat = (dailyCalories * 0.30) / 9;
    final carbs = (dailyCalories * 0.45) / 4;

    return {
      'calories': dailyCalories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
