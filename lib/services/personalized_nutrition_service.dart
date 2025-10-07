import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalizedNutritionService {
  static const String _collectionName = 'personalized_nutrition_rules';

  /// Get personalized nutrition recommendations for a user
  static Future<Map<String, dynamic>> getPersonalizedRecommendations(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userData = userDoc.data()!;
      final userProfile = _buildUserProfile(userData);
      
      // Get applicable nutrition rules
      final rules = await _getApplicableRules(userProfile);
      
      // Calculate personalized recommendations
      final recommendations = _calculateRecommendations(userProfile, rules);
      
      return {
        'userProfile': userProfile,
        'applicableRules': rules,
        'recommendations': recommendations,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting personalized recommendations: $e');
      return _getDefaultRecommendations();
    }
  }

  /// Get all nutrition rules from the database
  static Future<List<Map<String, dynamic>>> getAllNutritionRules() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .orderBy('priority', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting nutrition rules: $e');
      return [];
    }
  }

  /// Create a new nutrition rule
  static Future<String> createNutritionRule(Map<String, dynamic> ruleData) async {
    try {
      final docRef = await FirebaseFirestore.instance
          .collection(_collectionName)
          .add({
        ...ruleData,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'nutritionist',
        'isActive': true,
      });

      return docRef.id;
    } catch (e) {
      print('Error creating nutrition rule: $e');
      throw Exception('Failed to create nutrition rule');
    }
  }

  /// Update an existing nutrition rule
  static Future<void> updateNutritionRule(String ruleId, Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(ruleId)
          .update({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': 'nutritionist',
      });
    } catch (e) {
      print('Error updating nutrition rule: $e');
      throw Exception('Failed to update nutrition rule');
    }
  }

  /// Delete a nutrition rule
  static Future<void> deleteNutritionRule(String ruleId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(ruleId)
          .delete();
    } catch (e) {
      print('Error deleting nutrition rule: $e');
      throw Exception('Failed to delete nutrition rule');
    }
  }

  /// Build user profile from user data
  static Map<String, dynamic> _buildUserProfile(Map<String, dynamic> userData) {
    return {
      'age': userData['age'] ?? 30,
      'gender': userData['gender'] ?? 'male',
      'weight': userData['weight'] ?? 70.0,
      'height': userData['height'] ?? 170.0,
      'activityLevel': userData['activityLevel'] ?? 'moderate',
      'healthConditions': List<String>.from(userData['healthConditions'] ?? []),
      'allergies': List<String>.from(userData['allergies'] ?? []),
      'dietaryPreferences': List<String>.from(userData['dietaryPreferences'] ?? []),
      'bodyGoals': List<String>.from(userData['bodyGoals'] ?? []),
      'pregnancyStatus': userData['pregnancyStatus'] ?? 'none',
      'lactationStatus': userData['lactationStatus'] ?? false,
    };
  }

  /// Get rules that apply to the user's profile
  static Future<List<Map<String, dynamic>>> _getApplicableRules(Map<String, dynamic> userProfile) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      final allRules = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filter rules that apply to this user
      return allRules.where((rule) => _ruleAppliesToUser(rule, userProfile)).toList();
    } catch (e) {
      print('Error getting applicable rules: $e');
      return [];
    }
  }

  /// Check if a rule applies to the user
  static bool _ruleAppliesToUser(Map<String, dynamic> rule, Map<String, dynamic> userProfile) {
    final conditions = rule['conditions'] as Map<String, dynamic>? ?? {};
    
    // Check age range
    if (conditions['minAge'] != null && userProfile['age'] < conditions['minAge']) return false;
    if (conditions['maxAge'] != null && userProfile['age'] > conditions['maxAge']) return false;
    
    // Check gender
    if (conditions['gender'] != null && userProfile['gender'] != conditions['gender']) return false;
    
    // Check health conditions
    if (conditions['healthConditions'] != null) {
      final requiredConditions = List<String>.from(conditions['healthConditions']);
      final userConditions = List<String>.from(userProfile['healthConditions']);
      if (!requiredConditions.any((condition) => userConditions.contains(condition))) return false;
    }
    
    // Check dietary preferences
    if (conditions['dietaryPreferences'] != null) {
      final requiredPreferences = List<String>.from(conditions['dietaryPreferences']);
      final userPreferences = List<String>.from(userProfile['dietaryPreferences']);
      if (!requiredPreferences.any((pref) => userPreferences.contains(pref))) return false;
    }
    
    // Check body goals
    if (conditions['bodyGoals'] != null) {
      final requiredGoals = List<String>.from(conditions['bodyGoals']);
      final userGoals = List<String>.from(userProfile['bodyGoals']);
      if (!requiredGoals.any((goal) => userGoals.contains(goal))) return false;
    }
    
    // Check pregnancy/lactation status
    if (conditions['pregnancyStatus'] != null && userProfile['pregnancyStatus'] != conditions['pregnancyStatus']) return false;
    if (conditions['lactationStatus'] != null && userProfile['lactationStatus'] != conditions['lactationStatus']) return false;
    
    return true;
  }

  /// Calculate personalized recommendations based on user profile and rules
  static Map<String, dynamic> _calculateRecommendations(
    Map<String, dynamic> userProfile, 
    List<Map<String, dynamic>> rules
  ) {
    // Calculate BMR using Mifflin-St Jeor Equation
    final bmr = _calculateBMR(userProfile);
    
    // Calculate TDEE based on activity level
    final tdee = _calculateTDEE(bmr, userProfile['activityLevel']);
    
    // Base recommendations
    final recommendations = {
      'dailyCalories': tdee.round(),
      'protein': (tdee * 0.25 / 4).round(), // 25% of calories from protein
      'carbs': (tdee * 0.45 / 4).round(), // 45% of calories from carbs
      'fat': (tdee * 0.30 / 9).round(), // 30% of calories from fat
      'fiber': _calculateFiber(userProfile),
      'sodium': _calculateSodium(userProfile),
      'water': _calculateWater(userProfile),
      'mealFrequency': 3,
      'mealTiming': {},
      'supplements': [],
      'foodsToInclude': [],
      'foodsToAvoid': [],
      'specialInstructions': [],
    };

    // Apply rules to modify recommendations
    for (final rule in rules) {
      _applyRuleToRecommendations(rule, recommendations, userProfile);
    }

    return recommendations;
  }

  /// Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation
  static double _calculateBMR(Map<String, dynamic> userProfile) {
    final age = userProfile['age'] as int;
    final weight = userProfile['weight'] as double;
    final height = userProfile['height'] as double;
    final gender = userProfile['gender'] as String;

    if (gender.toLowerCase() == 'male') {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

  /// Calculate Total Daily Energy Expenditure
  static double _calculateTDEE(double bmr, String activityLevel) {
    const activityMultipliers = {
      'sedentary': 1.2,
      'light': 1.375,
      'moderate': 1.55,
      'active': 1.725,
      'very_active': 1.9,
    };

    return bmr * (activityMultipliers[activityLevel.toLowerCase()] ?? 1.55);
  }

  /// Calculate recommended fiber intake
  static int _calculateFiber(Map<String, dynamic> userProfile) {
    final age = userProfile['age'] as int;
    final gender = userProfile['gender'] as String;
    
    // Base fiber recommendations by age and gender
    if (age < 50) {
      return gender.toLowerCase() == 'male' ? 38 : 25;
    } else {
      return gender.toLowerCase() == 'male' ? 30 : 21;
    }
  }

  /// Calculate recommended sodium intake
  static int _calculateSodium(Map<String, dynamic> userProfile) {
    final healthConditions = List<String>.from(userProfile['healthConditions']);
    
    // Lower sodium for certain health conditions
    if (healthConditions.contains('Hypertension') || 
        healthConditions.contains('Heart Disease') ||
        healthConditions.contains('Kidney Disease')) {
      return 1500; // mg
    }
    
    return 2300; // mg (general recommendation)
  }

  /// Calculate recommended water intake
  static double _calculateWater(Map<String, dynamic> userProfile) {
    final weight = userProfile['weight'] as double;
    final activityLevel = userProfile['activityLevel'] as String;
    final pregnancyStatus = userProfile['pregnancyStatus'] as String;
    final lactationStatus = userProfile['lactationStatus'] as bool;
    
    // Base water intake: 35ml per kg body weight
    double baseWater = (weight * 35) / 1000; // Convert to liters
    
    // Adjust for activity level
    const activityMultipliers = {
      'sedentary': 1.0,
      'light': 1.2,
      'moderate': 1.4,
      'active': 1.6,
      'very_active': 1.8,
    };
    
    baseWater *= (activityMultipliers[activityLevel.toLowerCase()] ?? 1.4);
    
    // Adjust for pregnancy/lactation
    if (pregnancyStatus == 'pregnant') {
      baseWater += 0.3; // Additional 300ml during pregnancy
    }
    if (lactationStatus) {
      baseWater += 0.7; // Additional 700ml during lactation
    }
    
    return baseWater;
  }

  /// Apply a rule to modify recommendations
  static void _applyRuleToRecommendations(
    Map<String, dynamic> rule, 
    Map<String, dynamic> recommendations, 
    Map<String, dynamic> userProfile
  ) {
    final adjustments = rule['adjustments'] as Map<String, dynamic>? ?? {};
    
    // Adjust calories
    if (adjustments['calorieMultiplier'] != null) {
      final multiplier = adjustments['calorieMultiplier'] as double;
      recommendations['dailyCalories'] = (recommendations['dailyCalories'] * multiplier).round();
    }
    
    // Adjust macronutrients
    if (adjustments['proteinRatio'] != null) {
      final ratio = adjustments['proteinRatio'] as double;
      recommendations['protein'] = (recommendations['dailyCalories'] * ratio / 4).round();
    }
    if (adjustments['carbRatio'] != null) {
      final ratio = adjustments['carbRatio'] as double;
      recommendations['carbs'] = (recommendations['dailyCalories'] * ratio / 4).round();
    }
    if (adjustments['fatRatio'] != null) {
      final ratio = adjustments['fatRatio'] as double;
      recommendations['fat'] = (recommendations['dailyCalories'] * ratio / 9).round();
    }
    
    // Adjust meal frequency
    if (adjustments['mealFrequency'] != null) {
      recommendations['mealFrequency'] = adjustments['mealFrequency'];
    }
    
    // Add foods to include/avoid
    if (adjustments['foodsToInclude'] != null) {
      final foods = List<String>.from(adjustments['foodsToInclude']);
      recommendations['foodsToInclude'].addAll(foods);
    }
    if (adjustments['foodsToAvoid'] != null) {
      final foods = List<String>.from(adjustments['foodsToAvoid']);
      recommendations['foodsToAvoid'].addAll(foods);
    }
    
    // Add supplements
    if (adjustments['supplements'] != null) {
      final supplements = List<String>.from(adjustments['supplements']);
      recommendations['supplements'].addAll(supplements);
    }
    
    // Add special instructions
    if (adjustments['specialInstructions'] != null) {
      final instructions = List<String>.from(adjustments['specialInstructions']);
      recommendations['specialInstructions'].addAll(instructions);
    }
  }

  /// Get default recommendations when user data is not available
  static Map<String, dynamic> _getDefaultRecommendations() {
    return {
      'userProfile': null,
      'applicableRules': [],
      'recommendations': {
        'dailyCalories': 2000,
        'protein': 125,
        'carbs': 225,
        'fat': 67,
        'fiber': 25,
        'sodium': 2300,
        'water': 2.5,
        'mealFrequency': 3,
        'mealTiming': {},
        'supplements': [],
        'foodsToInclude': [],
        'foodsToAvoid': [],
        'specialInstructions': ['Consult with a healthcare provider for personalized advice'],
      },
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}
