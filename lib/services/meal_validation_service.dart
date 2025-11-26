import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealValidationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Submit a meal for nutritionist validation
  static Future<String> submitMealForValidation({
    required Map<String, dynamic> mealData,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      // Get user profile for context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      // Calculate macro targets
      final macroTargets = calculateMacroTargets(userData);
      
      // Create validation request
      final docRef = await _firestore.collection('meal_validation_queue').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'mealData': mealData,
        'userProfile': {
          'age': userData['age'] ?? 0,
          'gender': userData['gender'] ?? 'N/A',
          'height': userData['height'] ?? 0,
          'weight': userData['weight'] ?? 0,
          'goal': userData['goal'] ?? 'N/A',
          'activityLevel': userData['activityLevel'] ?? 'N/A',
          'healthConditions': userData['healthConditions'] ?? [],
          'allergies': userData['allergies'] ?? [],
          'dietaryPreferences': userData['dietaryPreferences'] ?? [],
          'macroTargets': macroTargets,
          'bmi': _calculateBMI(userData['height'], userData['weight']),
          'bmr': _calculateBMR(userData),
        },
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'userNotified': false,
      });
      
      return docRef.id;
    } catch (e) {
      print('Error submitting meal for validation: $e');
      rethrow;
    }
  }
  
  /// Get pending validations for nutritionist
  static Future<List<Map<String, dynamic>>> getPendingValidations() async {
    try {
      final snapshot = await _firestore
          .collection('meal_validation_queue')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: false)
          .get();
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting pending validations: $e');
      return [];
    }
  }
  
  /// Approve a meal
  static Future<void> approveMeal({
    required String validationId,
    required String nutritionistName,
    String? comments,
    Map<String, double>? correctedNutrition,
  }) async {
    try {
      await _firestore.collection('meal_validation_queue').doc(validationId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'nutritionistName': nutritionistName,
        'feedback': {
          'decision': 'approved',
          'comments': comments ?? 'Meal approved by nutritionist',
          'correctedNutrition': correctedNutrition,
        },
      });
    } catch (e) {
      print('Error approving meal: $e');
      rethrow;
    }
  }
  
  /// Reject a meal
  static Future<void> rejectMeal({
    required String validationId,
    required String nutritionistName,
    required String reason,
    List<String>? suggestions,
  }) async {
    try {
      await _firestore.collection('meal_validation_queue').doc(validationId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'nutritionistName': nutritionistName,
        'feedback': {
          'decision': 'rejected',
          'comments': reason,
          'suggestions': suggestions ?? [],
        },
      });
    } catch (e) {
      print('Error rejecting meal: $e');
      rethrow;
    }
  }

  /// Request revisions from the user
  static Future<void> requestRevision({
    required String validationId,
    required String nutritionistName,
    required String comments,
  }) async {
    try {
      await _firestore.collection('meal_validation_queue').doc(validationId).update({
        'status': 'pending',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        'nutritionistName': nutritionistName,
        'feedback': {
          'decision': 'revision_requested',
          'comments': comments,
        },
      });
    } catch (e) {
      print('Error requesting revision: $e');
      rethrow;
    }
  }

  /// Calculate macro targets based on user profile
  static Map<String, double> calculateMacroTargets(Map<String, dynamic> userData) {
    final weight = (userData['weight'] ?? 70).toDouble();
    final height = (userData['height'] ?? 170).toDouble();
    final age = (userData['age'] ?? 30).toInt();
    final gender = userData['gender']?.toString().toLowerCase() ?? 'male';
    final goal = userData['goal']?.toString().toLowerCase() ?? '';
    final activityLevel = userData['activityLevel']?.toString().toLowerCase() ?? '';
    
    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
    
    // Activity multiplier
    double activityMultiplier = 1.2; // Sedentary default
    if (activityLevel.contains('lightly')) {
      activityMultiplier = 1.375;
    } else if (activityLevel.contains('moderately')) {
      activityMultiplier = 1.55;
    } else if (activityLevel.contains('very')) {
      activityMultiplier = 1.725;
    }
    
    double tdee = bmr * activityMultiplier;
    
    // Adjust for goal
    if (goal.contains('lose') || goal.contains('weight loss')) {
      tdee *= 0.85; // 15% deficit
    } else if (goal.contains('gain') || goal.contains('muscle')) {
      tdee *= 1.10; // 10% surplus
    }
    
    // Calculate macros (per meal, assuming 3 meals per day)
    final caloriesPerMeal = tdee / 3;
    
    return {
      'calories': caloriesPerMeal,
      'protein': (caloriesPerMeal * 0.30) / 4, // 30% protein, 4 cal/g
      'carbs': (caloriesPerMeal * 0.40) / 4,   // 40% carbs, 4 cal/g
      'fat': (caloriesPerMeal * 0.30) / 9,     // 30% fat, 9 cal/g
    };
  }
  
  static double _calculateBMI(dynamic height, dynamic weight) {
    final h = (height ?? 170).toDouble() / 100; // Convert cm to m
    final w = (weight ?? 70).toDouble();
    if (h <= 0) return 0;
    return w / (h * h);
  }
  
  static double _calculateBMR(Map<String, dynamic> userData) {
    final weight = (userData['weight'] ?? 70).toDouble();
    final height = (userData['height'] ?? 170).toDouble();
    final age = (userData['age'] ?? 30).toInt();
    final gender = userData['gender']?.toString().toLowerCase() ?? 'male';
    
    if (gender == 'male') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }
  
  /// Analyze meal for potential issues
  static List<String> analyzeMeal(
    Map<String, dynamic> mealData,
    Map<String, dynamic> userProfile,
  ) {
    final issues = <String>[];
    
    final nutrition = mealData['nutrition'] as Map<String, dynamic>?;
    if (nutrition == null) return issues;
    
    final targets = userProfile['macroTargets'] as Map<String, dynamic>?;
    if (targets == null) return issues;
    
    final calories = (nutrition['calories'] ?? 0).toDouble();
    final protein = (nutrition['protein'] ?? 0).toDouble();
    final carbs = (nutrition['carbs'] ?? 0).toDouble();
    final fat = (nutrition['fat'] ?? 0).toDouble();
    
    final targetCalories = (targets['calories'] ?? 0).toDouble();
    final targetProtein = (targets['protein'] ?? 0).toDouble();
    final targetCarbs = (targets['carbs'] ?? 0).toDouble();
    final targetFat = (targets['fat'] ?? 0).toDouble();
    
    // Check if significantly over targets
    if (calories > targetCalories * 1.5) {
      issues.add('⚠️ Calories significantly exceed target (${calories.toInt()} vs ${targetCalories.toInt()})');
    }
    
    if (protein > targetProtein * 1.5) {
      issues.add('⚠️ Protein content very high');
    }
    
    if (carbs > targetCarbs * 1.5) {
      issues.add('⚠️ Carbs significantly exceed target');
    }
    
    if (fat > targetFat * 1.5) {
      issues.add('⚠️ Fat content very high');
    }
    
    // Check health conditions
    final healthConditions = userProfile['healthConditions'] as List?;
    if (healthConditions != null) {
      for (final condition in healthConditions) {
        final conditionStr = condition.toString().toLowerCase();
        
        if (conditionStr.contains('diabetes') && carbs > 45) {
          issues.add('🚨 High carbs - caution for diabetes management');
        }
        
        if (conditionStr.contains('hypertension')) {
          issues.add('⚠️ Check sodium content for hypertension');
        }
        
        if (conditionStr.contains('cholesterol') && fat > 20) {
          issues.add('⚠️ High fat - caution for cholesterol management');
        }
      }
    }
    
    // Check allergens
    final allergies = userProfile['allergies'] as List?;
    final ingredients = mealData['ingredients'] as List?;
    
    if (allergies != null && ingredients != null) {
      for (final allergen in allergies) {
        final allergenStr = allergen.toString().toLowerCase();
        if (allergenStr == 'none') continue;
        
        for (final ingredient in ingredients) {
          final ingredientStr = ingredient.toString().toLowerCase();
          if (ingredientStr.contains(allergenStr)) {
            issues.add('🚨 ALLERGEN ALERT: Contains $allergen');
          }
        }
      }
    }
    
    return issues;
  }
}
