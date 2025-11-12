import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthWarning {
  final String type; // 'critical', 'warning', 'caution'
  final String title;
  final String message;
  final String condition;
  final List<String> risks;
  final List<String> alternatives;
  final IconData icon;
  final Color color;

  HealthWarning({
    required this.type,
    required this.title,
    required this.message,
    required this.condition,
    required this.risks,
    required this.alternatives,
    required this.icon,
    required this.color,
  });
}

class HealthWarningService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if a meal/recipe conflicts with user's health conditions
  static Future<List<HealthWarning>> checkMealHealth({
    required Map<String, dynamic> mealData,
    String? customTitle,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user health profile
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final healthConditions = List<String>.from(userData['healthConditions'] ?? []);
      final allergies = List<String>.from(userData['allergies'] ?? []);
      final medications = userData['medication'] as String?;

      List<HealthWarning> warnings = [];

      // Check each health condition
      for (String condition in healthConditions) {
        if (condition == 'None') continue;
        
        final conditionWarnings = await _checkConditionConflicts(
          condition, 
          mealData, 
          customTitle ?? mealData['title'] ?? 'Unknown'
        );
        warnings.addAll(conditionWarnings);
      }

      // Check allergies
      final allergyWarnings = await _checkAllergyConflicts(allergies, mealData);
      warnings.addAll(allergyWarnings);

      // Check medication interactions
      if (medications != null && medications.isNotEmpty) {
        final medicationWarnings = await _checkMedicationConflicts(medications, mealData);
        warnings.addAll(medicationWarnings);
      }

      return warnings;
    } catch (e) {
      print('Error checking meal health: $e');
      return [];
    }
  }

  /// Check conflicts for specific health conditions
  static Future<List<HealthWarning>> _checkConditionConflicts(
    String condition,
    Map<String, dynamic> mealData,
    String mealTitle,
  ) async {
    List<HealthWarning> warnings = [];

    switch (condition) {
      case 'Diabetes':
        warnings.addAll(_checkDiabetesConflicts(mealData, mealTitle));
        break;
      case 'Hypertension':
        warnings.addAll(_checkHypertensionConflicts(mealData, mealTitle));
        break;
      case 'High Cholesterol':
        warnings.addAll(_checkCholesterolConflicts(mealData, mealTitle));
        break;
      case 'Kidney Disease':
        warnings.addAll(_checkKidneyConflicts(mealData, mealTitle));
        break;
      case 'PCOS':
        warnings.addAll(_checkPCOSConflicts(mealData, mealTitle));
        break;
      case 'Obesity':
        warnings.addAll(_checkObesityConflicts(mealData, mealTitle));
        break;
    }

    return warnings;
  }

  /// Check diabetes-specific conflicts
  static List<HealthWarning> _checkDiabetesConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    final nutrition = mealData['nutrition'] as Map<String, dynamic>?;

    if (nutrition != null) {
      final carbs = (nutrition['carbs'] as num?)?.toDouble() ?? 0;
      final sugar = (nutrition['sugar'] as num?)?.toDouble() ?? 0;
      final fiber = (nutrition['fiber'] as num?)?.toDouble() ?? 0;

      // High carb warning
      if (carbs > 60) {
        warnings.add(HealthWarning(
          type: 'warning',
          title: '⚠️ High Carbohydrate Content',
          message: 'This meal contains ${carbs.toInt()}g of carbs, which may cause blood sugar spikes.',
          condition: 'Diabetes',
          risks: [
            'Blood sugar spike',
            'Increased insulin requirement',
            'Potential hyperglycemia',
          ],
          alternatives: [
            'Reduce portion size by half',
            'Add protein or healthy fats',
            'Choose whole grain alternatives',
            'Pair with low-carb vegetables',
          ],
          icon: Icons.warning,
          color: Colors.orange,
        ));
      }

      // High sugar warning
      if (sugar > 25) {
        warnings.add(HealthWarning(
          type: 'critical',
          title: '🚨 Very High Sugar Content',
          message: 'This meal contains ${sugar.toInt()}g of sugar - dangerous for diabetics!',
          condition: 'Diabetes',
          risks: [
            'Severe blood sugar spike',
            'Diabetic emergency risk',
            'Long-term complications',
          ],
          alternatives: [
            'Choose sugar-free alternatives',
            'Skip this meal entirely',
            'Consult your doctor first',
            'Consider diabetic-friendly substitutes',
          ],
          icon: Icons.dangerous,
          color: Colors.red,
        ));
      }

      // Low fiber warning (for high carb meals)
      if (carbs > 30 && fiber < 5) {
        warnings.add(HealthWarning(
          type: 'caution',
          title: '📊 Low Fiber with High Carbs',
          message: 'This meal is high in carbs but low in fiber, which may cause rapid glucose absorption.',
          condition: 'Diabetes',
          risks: [
            'Rapid blood sugar rise',
            'Poor satiety',
            'Increased hunger later',
          ],
          alternatives: [
            'Add a side salad',
            'Include beans or legumes',
            'Choose whole grain versions',
            'Add chia seeds or flaxseed',
          ],
          icon: Icons.info,
          color: Colors.blue,
        ));
      }
    }

    // Check for high-glycemic ingredients
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    
    if (_containsHighGlycemicIngredients(ingredients, title)) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '📈 High Glycemic Index Foods Detected',
        message: 'This meal contains high-GI ingredients that can rapidly raise blood sugar.',
        condition: 'Diabetes',
        risks: [
          'Quick blood sugar spike',
          'Insulin resistance worsening',
          'Energy crashes',
        ],
        alternatives: [
          'Replace white rice with cauliflower rice',
          'Use sweet potato instead of white potato',
          'Choose steel-cut oats over instant',
          'Add protein to slow absorption',
        ],
        icon: Icons.trending_up,
        color: Colors.orange,
      ));
    }

    return warnings;
  }

  /// Check hypertension-specific conflicts
  static List<HealthWarning> _checkHypertensionConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    final nutrition = mealData['nutrition'] as Map<String, dynamic>?;

    if (nutrition != null) {
      final sodium = (nutrition['sodium'] as num?)?.toDouble() ?? 0;

      if (sodium > 800) { // High sodium per meal
        warnings.add(HealthWarning(
          type: 'critical',
          title: '🧂 Extremely High Sodium Content',
          message: 'This meal contains ${sodium.toInt()}mg of sodium - dangerous for high blood pressure!',
          condition: 'Hypertension',
          risks: [
            'Blood pressure spike',
            'Increased stroke risk',
            'Heart complications',
            'Fluid retention',
          ],
          alternatives: [
            'Choose low-sodium alternatives',
            'Remove added salt',
            'Use herbs and spices instead',
            'Rinse canned ingredients',
          ],
          icon: Icons.dangerous,
          color: Colors.red,
        ));
      } else if (sodium > 500) {
        warnings.add(HealthWarning(
          type: 'warning',
          title: '⚠️ High Sodium Content',
          message: 'This meal contains ${sodium.toInt()}mg of sodium. Daily limit is 1500mg for hypertension.',
          condition: 'Hypertension',
          risks: [
            'Blood pressure increase',
            'Fluid retention',
            'Kidney strain',
          ],
          alternatives: [
            'Reduce portion size',
            'Balance with low-sodium foods today',
            'Drink extra water',
            'Choose fresh over processed ingredients',
          ],
          icon: Icons.warning,
          color: Colors.orange,
        ));
      }
    }

    // Check for high-sodium ingredients
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    if (_containsHighSodiumIngredients(ingredients, mealTitle)) {
      warnings.add(HealthWarning(
        type: 'caution',
        title: '🧂 High-Sodium Ingredients Detected',
        message: 'This meal contains ingredients typically high in sodium.',
        condition: 'Hypertension',
        risks: [
          'Hidden sodium content',
          'Blood pressure elevation',
          'Exceeding daily sodium limit',
        ],
        alternatives: [
          'Use fresh ingredients instead',
          'Make homemade versions',
          'Read nutrition labels carefully',
          'Choose "no salt added" versions',
        ],
        icon: Icons.info,
        color: Colors.blue,
      ));
    }

    return warnings;
  }

  /// Check high cholesterol conflicts
  static List<HealthWarning> _checkCholesterolConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    final nutrition = mealData['nutrition'] as Map<String, dynamic>?;

    if (nutrition != null) {
      final saturatedFat = (nutrition['saturatedFat'] as num?)?.toDouble() ?? 0;
      final cholesterol = (nutrition['cholesterol'] as num?)?.toDouble() ?? 0;

      if (saturatedFat > 10) {
        warnings.add(HealthWarning(
          type: 'warning',
          title: '🥩 High Saturated Fat Content',
          message: 'This meal contains ${saturatedFat.toInt()}g of saturated fat, which can raise cholesterol.',
          condition: 'High Cholesterol',
          risks: [
            'LDL cholesterol increase',
            'Arterial plaque buildup',
            'Heart disease risk',
          ],
          alternatives: [
            'Choose lean protein sources',
            'Use plant-based alternatives',
            'Trim visible fat',
            'Bake instead of frying',
          ],
          icon: Icons.warning,
          color: Colors.orange,
        ));
      }

      if (cholesterol > 200) {
        warnings.add(HealthWarning(
          type: 'critical',
          title: '🚨 Very High Dietary Cholesterol',
          message: 'This meal contains ${cholesterol.toInt()}mg of cholesterol!',
          condition: 'High Cholesterol',
          risks: [
            'Blood cholesterol spike',
            'Cardiovascular complications',
            'Arterial damage',
          ],
          alternatives: [
            'Choose plant-based proteins',
            'Use egg whites instead of whole eggs',
            'Select leaner cuts of meat',
            'Consider cholesterol-free alternatives',
          ],
          icon: Icons.dangerous,
          color: Colors.red,
        ));
      }
    }

    return warnings;
  }

  /// Check allergy conflicts
  static Future<List<HealthWarning>> _checkAllergyConflicts(
    List<String> allergies,
    Map<String, dynamic> mealData,
  ) async {
    List<HealthWarning> warnings = [];

    if (allergies.contains('None') || allergies.isEmpty) return warnings;

    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealData['title'] as String? ?? '';

    for (String allergy in allergies) {
      if (allergy == 'None') continue;

      bool containsAllergen = false;
      String detectedIn = '';

      // Check in ingredients
      for (var ingredient in ingredients) {
        final ingredientStr = ingredient.toString().toLowerCase();
        if (ingredientStr.contains(allergy.toLowerCase())) {
          containsAllergen = true;
          detectedIn = 'ingredients';
          break;
        }
      }

      // Check in title
      if (!containsAllergen && title.toLowerCase().contains(allergy.toLowerCase())) {
        containsAllergen = true;
        detectedIn = 'recipe title';
      }

      if (containsAllergen) {
        warnings.add(HealthWarning(
          type: 'critical',
          title: '🚨 ALLERGEN ALERT: $allergy',
          message: '$allergy detected in $detectedIn. This could cause a severe allergic reaction!',
          condition: 'Allergy',
          risks: [
            'Allergic reaction',
            'Anaphylaxis (potentially fatal)',
            'Respiratory distress',
            'Skin reactions',
          ],
          alternatives: [
            'DO NOT consume this meal',
            'Find allergen-free alternatives',
            'Check all ingredients carefully',
            'Consult allergy-safe recipes',
          ],
          icon: Icons.dangerous,
          color: Colors.red,
        ));
      }
    }

    return warnings;
  }

  /// Helper method to check for high glycemic ingredients
  static bool _containsHighGlycemicIngredients(List<dynamic> ingredients, String title) {
    final highGIItems = [
      'white rice', 'white bread', 'potato', 'corn flakes', 'instant oats',
      'bagel', 'donut', 'candy', 'sugar', 'honey', 'maple syrup',
      'watermelon', 'pineapple', 'dates', 'raisins'
    ];

    final allText = (ingredients.join(' ') + ' ' + title).toLowerCase();
    return highGIItems.any((item) => allText.contains(item));
  }

  /// Helper method to check for high sodium ingredients
  static bool _containsHighSodiumIngredients(List<dynamic> ingredients, String title) {
    final highSodiumItems = [
      'soy sauce', 'salt', 'bacon', 'ham', 'cheese', 'pickles',
      'canned soup', 'processed meat', 'instant noodles', 'chips',
      'olives', 'anchovies', 'salami', 'pepperoni'
    ];

    final allText = (ingredients.join(' ') + ' ' + title).toLowerCase();
    return highSodiumItems.any((item) => allText.contains(item));
  }

  // Placeholder for other condition checks
  static List<HealthWarning> _checkKidneyConflicts(Map<String, dynamic> mealData, String mealTitle) => [];
  static List<HealthWarning> _checkPCOSConflicts(Map<String, dynamic> mealData, String mealTitle) => [];
  static List<HealthWarning> _checkObesityConflicts(Map<String, dynamic> mealData, String mealTitle) => [];
  static Future<List<HealthWarning>> _checkMedicationConflicts(String medications, Map<String, dynamic> mealData) async => [];
}
