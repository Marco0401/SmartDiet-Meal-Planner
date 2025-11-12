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
      print('DEBUG HealthWarning: Fetching user data for ${user.uid}');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('DEBUG HealthWarning: User document does not exist!');
        return [];
      }

      final userData = userDoc.data()!;
      final healthConditions = List<String>.from(userData['healthConditions'] ?? []);
      final allergies = List<String>.from(userData['allergies'] ?? []);
      final dietaryPreferences = List<String>.from(userData['dietaryPreferences'] ?? []);
      final medications = userData['medication'] as String?;
      
      print('DEBUG HealthWarning: User data keys: ${userData.keys}');
      print('DEBUG HealthWarning: Health conditions: $healthConditions');
      print('DEBUG HealthWarning: Allergies: $allergies');
      print('DEBUG HealthWarning: Dietary preferences: $dietaryPreferences');
      print('DEBUG HealthWarning: Medications: $medications');
      print('DEBUG HealthWarning: Meal title: "$customTitle"');
      print('DEBUG HealthWarning: Meal ingredients: ${mealData['ingredients']}');

      List<HealthWarning> warnings = [];

      // Check each health condition
      print('DEBUG HealthWarning: Processing ${healthConditions.length} health conditions');
      for (String condition in healthConditions) {
        if (condition == 'None') {
          print('DEBUG HealthWarning: Skipping "None" condition');
          continue;
        }
        print('DEBUG HealthWarning: Checking condition: "$condition"');
        
        final conditionWarnings = await _checkConditionConflicts(
          condition, 
          mealData, 
          customTitle ?? mealData['title'] ?? 'Unknown'
        );
        warnings.addAll(conditionWarnings);
      }

      // Check dietary preferences
      if (dietaryPreferences.isNotEmpty && !dietaryPreferences.contains('None')) {
        final dietaryWarnings = await _checkDietaryPreferenceConflicts(dietaryPreferences, mealData, customTitle ?? mealData['title'] ?? 'Unknown');
        warnings.addAll(dietaryWarnings);
      }
      
      // Check allergies
      if (allergies.isNotEmpty && !allergies.contains('None')) {
        final allergyWarnings = await _checkAllergyConflicts(allergies, mealData);
        warnings.addAll(allergyWarnings);
      }

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
      case 'Lactose Intolerance':
        warnings.addAll(_checkLactoseIntoleranceConflicts(mealData, mealTitle));
        break;
      case 'Gluten Sensitivity':
        warnings.addAll(_checkGlutenSensitivityConflicts(mealData, mealTitle));
        break;
    }

    return warnings;
  }

  /// Check diabetes-specific conflicts with keyword-based analysis
  static List<HealthWarning> _checkDiabetesConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // High sugar ingredients (CRITICAL)
    const highSugarKeywords = [
      'sugar', 'honey', 'syrup', 'candy', 'chocolate', 'cake', 'cookies',
      'ice cream', 'soda', 'juice', 'jam', 'jelly', 'frosting', 'caramel',
      'molasses', 'agave', 'corn syrup', 'cocoa', 'fructose', 'glucose', 'sucrose'
    ];
    
    // Medium sugar ingredients (WARNING)
    const mediumSugarKeywords = [
      'fruit', 'banana', 'grapes', 'mango', 'pineapple', 'dates', 'raisins',
      'dried fruit', 'fruit juice', 'smoothie', 'yogurt', 'milk', 'bread',
      'pasta', 'rice', 'potato', 'sweet potato'
    ];
    
    // High carb ingredients (WARNING)
    const highCarbKeywords = [
      'bread', 'pasta', 'rice', 'noodles', 'flour', 'wheat', 'oats',
      'cereal', 'crackers', 'chips', 'pizza', 'bagel', 'muffin'
    ];
    
    final foundHighSugar = highSugarKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundMediumSugar = mediumSugarKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundHighCarb = highCarbKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    print('DEBUG Diabetes: Analyzing text: "$allText"');
    print('DEBUG Diabetes: Found high sugar: $foundHighSugar');
    print('DEBUG Diabetes: Found medium sugar: $foundMediumSugar');
    print('DEBUG Diabetes: Found high carb: $foundHighCarb');
    
    // CRITICAL: High sugar content
    if (foundHighSugar.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 DIABETES ALERT: High Sugar Content',
        message: 'This meal contains high-sugar ingredients: ${foundHighSugar.join(", ")}. This can cause dangerous blood sugar spikes.',
        condition: 'Diabetes',
        risks: [
          'Rapid blood sugar spike (>200 mg/dL)',
          'Potential diabetic ketoacidosis',
          'Energy crash after spike',
          'Increased thirst and urination',
          'Long-term complications risk',
        ],
        alternatives: [
          'Use sugar-free alternatives (stevia, erythritol)',
          'Choose fresh berries instead of sweet fruits',
          'Opt for diabetic-friendly desserts',
          'Consider skipping this meal',
          'Consult your doctor before consuming',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: Medium sugar content
    else if (foundMediumSugar.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ DIABETES CAUTION: Moderate Sugar Content',
        message: 'This meal contains moderate-sugar ingredients: ${foundMediumSugar.join(", ")}. Monitor blood glucose carefully.',
        condition: 'Diabetes',
        risks: [
          'Moderate blood sugar elevation',
          'Need for careful monitoring',
          'Possible medication adjustment needed',
        ],
        alternatives: [
          'Eat smaller portions',
          'Pair with protein and fiber',
          'Monitor blood glucose 2 hours after eating',
          'Consider timing with medication',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    // WARNING: High carb content
    if (foundHighCarb.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ DIABETES CAUTION: High Carbohydrate Content',
        message: 'This meal contains high-carb ingredients: ${foundHighCarb.join(", ")}. May affect blood sugar levels.',
        condition: 'Diabetes',
        risks: [
          'Gradual blood sugar increase',
          'Need for carb counting',
          'Possible insulin adjustment',
        ],
        alternatives: [
          'Choose whole grain versions',
          'Reduce portion sizes',
          'Add vegetables to balance the meal',
          'Count carbohydrates carefully',
        ],
        icon: Icons.info,
        color: Colors.blue,
      ));
    }
    
    return warnings;
  }

  /// Check hypertension-specific conflicts with keyword-based analysis
  static List<HealthWarning> _checkHypertensionConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // Very high sodium ingredients (CRITICAL)
    const criticalSodiumKeywords = [
      'soy sauce', 'fish sauce', 'oyster sauce', 'teriyaki sauce',
      'worcestershire sauce', 'salt', 'salted', 'cured', 'smoked',
      'bacon', 'ham', 'salami', 'pepperoni', 'hot dog', 'sausage',
      'pickles', 'pickled', 'olives', 'anchovies', 'capers'
    ];
    
    // High sodium ingredients (WARNING)
    const highSodiumKeywords = [
      'cheese', 'canned soup', 'instant noodles', 'ramen', 'chips',
      'crackers', 'pretzels', 'canned vegetables', 'frozen dinner',
      'deli meat', 'processed meat', 'bouillon', 'broth', 'stock'
    ];
    
    // Medium sodium ingredients (CAUTION)
    const mediumSodiumKeywords = [
      'bread', 'cereal', 'pasta sauce', 'ketchup', 'mustard',
      'salad dressing', 'mayonnaise', 'butter', 'margarine'
    ];
    
    final foundCritical = criticalSodiumKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundHigh = highSodiumKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundMedium = mediumSodiumKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    // CRITICAL: Very high sodium
    if (foundCritical.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 HYPERTENSION ALERT: Extremely High Sodium',
        message: 'This meal contains very high-sodium ingredients: ${foundCritical.join(", ")}. This can cause dangerous blood pressure spikes.',
        condition: 'Hypertension',
        risks: [
          'Severe blood pressure spike',
          'Increased stroke risk',
          'Heart complications',
        ],
        alternatives: [
          'Skip this meal entirely',
          'Use low-sodium alternatives',
          'Consult your doctor first',
          'Choose fresh, unprocessed foods',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: High sodium
    else if (foundHigh.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ HYPERTENSION WARNING: High Sodium Content',
        message: 'This meal contains high-sodium ingredients: ${foundHigh.join(", ")}. Monitor blood pressure closely.',
        condition: 'Hypertension',
        risks: [
          'Moderate blood pressure increase',
          'Fluid retention',
          'Increased medication needs',
          'Long-term cardiovascular risk',
        ],
        alternatives: [
          'Eat smaller portions',
          'Drink extra water',
          'Choose low-sodium versions',
          'Balance with potassium-rich foods',
          'Monitor BP after eating',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    // CAUTION: Medium sodium
    else if (foundMedium.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'suggestion',
        title: '💡 HYPERTENSION TIP: Watch Sodium Intake',
        message: 'This meal contains moderate-sodium ingredients: ${foundMedium.join(", ")}. Consider healthier alternatives.',
        condition: 'Hypertension',
        risks: [
          'Gradual sodium accumulation',
          'Daily limit exceeded if combined with other meals',
        ],
        alternatives: [
          'Choose whole grain, unsalted versions',
          'Make homemade versions with less salt',
          'Add fresh vegetables to dilute sodium',
        ],
        icon: Icons.lightbulb,
        color: Colors.blue,
      ));
    }

    return warnings;
  }

  /// Check high cholesterol conflicts with keyword-based analysis
  static List<HealthWarning> _checkCholesterolConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // Very high cholesterol ingredients (CRITICAL)
    const criticalCholesterolKeywords = [
      'egg yolk', 'liver', 'kidney', 'brain', 'organ meat',
      'caviar', 'roe', 'shrimp', 'lobster', 'crab'
    ];
    
    // High cholesterol/saturated fat ingredients (WARNING)
    const highCholesterolKeywords = [
      'butter', 'lard', 'beef fat', 'pork fat', 'coconut oil',
      'palm oil', 'cream', 'whole milk', 'cheese', 'ice cream',
      'red meat', 'beef', 'pork', 'lamb', 'duck', 'goose'
    ];
    
    // Medium cholesterol ingredients (CAUTION)
    const mediumCholesterolKeywords = [
      'chicken', 'turkey', 'fish', 'salmon', 'tuna',
      'milk', 'yogurt', 'margarine', 'fried food'
    ];
    
    final foundCritical = criticalCholesterolKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundHigh = highCholesterolKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundMedium = mediumCholesterolKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    // CRITICAL: Very high cholesterol
    if (foundCritical.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 CHOLESTEROL ALERT: Extremely High Cholesterol',
        message: 'This meal contains very high-cholesterol ingredients: ${foundCritical.join(", ")}. This can significantly raise blood cholesterol.',
        condition: 'High Cholesterol',
        risks: [
          'Rapid cholesterol level increase',
          'Increased heart attack risk',
          'Arterial plaque buildup',
          'Stroke risk elevation',
        ],
        alternatives: [
          'Avoid this meal completely',
          'Choose egg whites instead of whole eggs',
          'Select lean fish over shellfish',
          'Consult your cardiologist',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: High cholesterol/saturated fat
    else if (foundHigh.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ CHOLESTEROL WARNING: High Saturated Fat',
        message: 'This meal contains high-cholesterol ingredients: ${foundHigh.join(", ")}. May raise cholesterol levels.',
        condition: 'High Cholesterol',
        risks: [
          'Moderate cholesterol increase',
          'Long-term cardiovascular risk',
          'Need for medication adjustment',
        ],
        alternatives: [
          'Choose lean cuts of meat',
          'Use olive oil instead of butter',
          'Select low-fat dairy options',
          'Limit portion sizes',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    // CAUTION: Medium cholesterol
    else if (foundMedium.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'suggestion',
        title: '💡 CHOLESTEROL TIP: Choose Lean Options',
        message: 'This meal contains moderate-cholesterol ingredients: ${foundMedium.join(", ")}. Consider preparation methods.',
        condition: 'High Cholesterol',
        risks: [
          'Gradual cholesterol accumulation',
          'Daily cholesterol limit consideration',
        ],
        alternatives: [
          'Remove skin from poultry',
          'Choose grilled over fried',
          'Use low-fat cooking methods',
          'Add fiber-rich vegetables',
        ],
        icon: Icons.lightbulb,
        color: Colors.blue,
      ));
    }
    
    return warnings;
  }

  /// Check obesity-specific conflicts with keyword-based analysis
  static List<HealthWarning> _checkObesityConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // Very high calorie ingredients (CRITICAL)
    const criticalCalorieKeywords = [
      'deep fried', 'fried chicken', 'french fries', 'donuts', 'pizza',
      'burger', 'fast food', 'ice cream', 'cake', 'cookies', 'chocolate',
      'candy', 'soda', 'milkshake', 'chips', 'nachos'
    ];
    
    // High calorie ingredients (WARNING)
    const highCalorieKeywords = [
      'butter', 'oil', 'cheese', 'nuts', 'avocado', 'bacon',
      'sausage', 'cream', 'pasta', 'bread', 'rice'
    ];
    
    final foundCritical = criticalCalorieKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundHigh = highCalorieKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    // CRITICAL: Very high calorie foods
    if (foundCritical.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 OBESITY ALERT: Very High Calorie Food',
        message: 'This meal contains very high-calorie ingredients: ${foundCritical.join(", ")}. This can significantly impact weight management.',
        condition: 'Obesity',
        risks: [
          'Rapid weight gain',
          'Difficulty losing weight',
          'Increased health complications',
          'Poor satiety despite high calories',
        ],
        alternatives: [
          'Choose grilled instead of fried options',
          'Replace with vegetable-based meals',
          'Opt for smaller portions',
          'Choose water instead of sugary drinks',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: High calorie ingredients
    else if (foundHigh.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ OBESITY WARNING: High Calorie Content',
        message: 'This meal contains calorie-dense ingredients: ${foundHigh.join(", ")}. Consider portion control.',
        condition: 'Obesity',
        risks: [
          'Weight gain if consumed regularly',
          'Exceeding daily calorie goals',
        ],
        alternatives: [
          'Use smaller portions',
          'Balance with low-calorie vegetables',
          'Choose lean cooking methods',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    return warnings;
  }

  /// Check kidney disease-specific conflicts with keyword-based analysis
  static List<HealthWarning> _checkKidneyConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // High protein ingredients (CRITICAL for kidney disease)
    const highProteinKeywords = [
      'steak', 'beef', 'pork', 'lamb', 'chicken breast', 'turkey',
      'fish', 'salmon', 'tuna', 'protein powder', 'protein shake',
      'eggs', 'cheese', 'tofu', 'beans', 'lentils'
    ];
    
    // High phosphorus/potassium ingredients (WARNING)
    const highMineralKeywords = [
      'nuts', 'seeds', 'chocolate', 'cola', 'beer', 'dairy',
      'banana', 'orange', 'tomato', 'potato', 'spinach'
    ];
    
    final foundProtein = highProteinKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundMinerals = highMineralKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    // CRITICAL: High protein content
    if (foundProtein.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 KIDNEY DISEASE ALERT: High Protein Content',
        message: 'This meal contains high-protein ingredients: ${foundProtein.join(", ")}. Excess protein can strain kidneys.',
        condition: 'Kidney Disease',
        risks: [
          'Increased kidney workload',
          'Buildup of waste products',
          'Progression of kidney damage',
          'Electrolyte imbalances',
        ],
        alternatives: [
          'Choose smaller protein portions',
          'Focus on plant-based proteins',
          'Consult your nephrologist',
          'Consider protein restrictions',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: High mineral content
    if (foundMinerals.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ KIDNEY DISEASE WARNING: High Mineral Content',
        message: 'This meal contains ingredients high in phosphorus/potassium: ${foundMinerals.join(", ")}.',
        condition: 'Kidney Disease',
        risks: [
          'Electrolyte imbalances',
          'Bone health issues',
          'Heart rhythm problems',
        ],
        alternatives: [
          'Limit portion sizes',
          'Choose low-potassium alternatives',
          'Monitor lab values regularly',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    return warnings;
  }

  /// Check PCOS-specific conflicts with keyword-based analysis
  static List<HealthWarning> _checkPCOSConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    // High glycemic index ingredients (CRITICAL for PCOS)
    const highGIKeywords = [
      'white bread', 'white rice', 'pasta', 'potato', 'sugar',
      'honey', 'candy', 'soda', 'juice', 'cake', 'cookies',
      'cereal', 'crackers', 'chips'
    ];
    
    // Inflammatory ingredients (WARNING)
    const inflammatoryKeywords = [
      'processed meat', 'fried food', 'trans fat', 'margarine',
      'fast food', 'refined flour', 'artificial sweeteners'
    ];
    
    final foundHighGI = highGIKeywords.where((keyword) => allText.contains(keyword)).toList();
    final foundInflammatory = inflammatoryKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    // CRITICAL: High glycemic foods
    if (foundHighGI.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 PCOS ALERT: High Glycemic Index Foods',
        message: 'This meal contains high-GI ingredients: ${foundHighGI.join(", ")}. These can worsen insulin resistance.',
        condition: 'PCOS',
        risks: [
          'Worsened insulin resistance',
          'Increased androgen levels',
          'Weight gain difficulty',
          'Irregular menstrual cycles',
        ],
        alternatives: [
          'Choose whole grain alternatives',
          'Add protein and fiber',
          'Use natural sweeteners sparingly',
          'Focus on low-GI foods',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    // WARNING: Inflammatory foods
    if (foundInflammatory.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ PCOS WARNING: Inflammatory Foods',
        message: 'This meal contains inflammatory ingredients: ${foundInflammatory.join(", ")}. May worsen PCOS symptoms.',
        condition: 'PCOS',
        risks: [
          'Increased inflammation',
          'Hormonal imbalances',
          'Difficulty managing symptoms',
        ],
        alternatives: [
          'Choose anti-inflammatory foods',
          'Use healthy cooking methods',
          'Add omega-3 rich foods',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
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

  /// Check lactose intolerance conflicts
  static List<HealthWarning> _checkLactoseIntoleranceConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    const lactoseContainingFoods = [
      'milk', 'cheese', 'butter', 'cream', 'yogurt', 'ice cream',
      'whey', 'casein', 'lactose', 'dairy', 'sour cream', 'cottage cheese',
      'mozzarella', 'cheddar', 'parmesan', 'ricotta', 'mascarpone'
    ];
    
    final foundFoods = lactoseContainingFoods.where((food) => allText.contains(food)).toList();
    
    if (foundFoods.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🥛 LACTOSE ALERT: Dairy Products Detected',
        message: 'This meal contains: ${foundFoods.join(", ")} - foods containing lactose that can cause digestive issues.',
        condition: 'Lactose Intolerance',
        risks: [
          'Digestive discomfort',
          'Bloating and gas',
          'Diarrhea',
          'Stomach cramps',
        ],
        alternatives: [
          'Use lactose-free dairy alternatives',
          'Try plant-based milk (almond, oat, soy)',
          'Choose lactose-free cheese options',
          'Take lactase enzyme supplements',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check gluten sensitivity conflicts
  static List<HealthWarning> _checkGlutenSensitivityConflicts(
    Map<String, dynamic> mealData,
    String mealTitle,
  ) {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    const glutenContainingFoods = [
      'wheat', 'flour', 'bread', 'pasta', 'noodles', 'cereal',
      'barley', 'rye', 'bulgur', 'semolina', 'couscous', 'farro',
      'spelt', 'kamut', 'triticale', 'malt', 'brewer\'s yeast',
      'soy sauce', 'teriyaki', 'breadcrumbs', 'croutons'
    ];
    
    final foundFoods = glutenContainingFoods.where((food) => allText.contains(food)).toList();
    
    if (foundFoods.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🌾 GLUTEN ALERT: Gluten-Containing Foods Detected',
        message: 'This meal contains: ${foundFoods.join(", ")} - foods containing gluten that can trigger sensitivity.',
        condition: 'Gluten Sensitivity',
        risks: [
          'Digestive inflammation',
          'Bloating and abdominal pain',
          'Fatigue and headaches',
          'Skin reactions',
        ],
        alternatives: [
          'Use gluten-free flour alternatives',
          'Choose rice, quinoa, or corn-based products',
          'Try gluten-free bread and pasta',
          'Use tamari instead of soy sauce',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check dietary preference conflicts with keyword-based analysis
  static Future<List<HealthWarning>> _checkDietaryPreferenceConflicts(
    List<String> dietaryPreferences,
    Map<String, dynamic> mealData,
    String mealTitle,
  ) async {
    List<HealthWarning> warnings = [];
    
    final ingredients = mealData['ingredients'] as List<dynamic>? ?? [];
    final title = mealTitle.toLowerCase();
    final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
    
    print('DEBUG DietaryWarning: Analyzing meal "$title" for preferences: $dietaryPreferences');
    print('DEBUG DietaryWarning: Checking ingredients: ${ingredients.join(", ")}');
    
    for (String preference in dietaryPreferences) {
      if (preference == 'None' || preference == 'No Preference') continue;
      
      print('DEBUG DietaryWarning: Checking dietary preference: "$preference"');
      
      switch (preference) {
        case 'Halal':
          warnings.addAll(_checkHalalConflicts(allText, title, ingredients));
          break;
        case 'Kosher':
          warnings.addAll(_checkKosherConflicts(allText, title, ingredients));
          break;
        case 'Vegetarian':
          warnings.addAll(_checkVegetarianConflicts(allText, title, ingredients));
          break;
        case 'Vegan':
          warnings.addAll(_checkVeganConflicts(allText, title, ingredients));
          break;
        case 'Pescatarian':
          warnings.addAll(_checkPescatarianConflicts(allText, title, ingredients));
          break;
        case 'Keto':
          warnings.addAll(_checkKetoConflicts(allText, title, ingredients));
          break;
        case 'Low Carb':
          warnings.addAll(_checkLowCarbConflicts(allText, title, ingredients));
          break;
        case 'Low Sodium':
          warnings.addAll(_checkLowSodiumConflicts(allText, title, ingredients));
          break;
      }
    }
    
    print('DEBUG DietaryWarning: Found ${warnings.length} dietary preference warnings');
    return warnings;
  }

  /// Check Halal dietary conflicts
  static List<HealthWarning> _checkHalalConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // Haram (forbidden) ingredients
    const haramKeywords = [
      'pork', 'bacon', 'ham', 'sausage', 'pepperoni', 'prosciutto', 'chorizo',
      'wine', 'beer', 'alcohol', 'rum', 'vodka', 'whiskey', 'brandy',
      'gelatin', 'lard', 'pancetta', 'salami', 'mortadella'
    ];
    
    final foundHaram = haramKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundHaram.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 HALAL ALERT: Haram Ingredients Detected',
        message: 'This meal contains ingredients that are not Halal: ${foundHaram.join(", ")}. These are forbidden in Islamic dietary law.',
        condition: 'Halal Diet',
        risks: [
          'Violates Islamic dietary laws (Haram)',
          'Contains pork or alcohol derivatives',
          'May compromise religious observance',
        ],
        alternatives: [
          'Choose Halal-certified alternatives',
          'Replace pork with Halal beef or chicken',
          'Use alcohol-free cooking methods',
          'Look for explicitly Halal recipes',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check Kosher dietary conflicts  
  static List<HealthWarning> _checkKosherConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // Non-kosher ingredients
    const nonKosherKeywords = [
      'pork', 'bacon', 'ham', 'shellfish', 'shrimp', 'lobster', 'crab', 'oyster',
      'clam', 'scallop', 'squid', 'eel', 'rabbit', 'mixing meat and dairy',
      'cheeseburger', 'meat with cream', 'beef with cheese'
    ];
    
    final foundNonKosher = nonKosherKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundNonKosher.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 KOSHER ALERT: Non-Kosher Ingredients Detected',
        message: 'This meal contains ingredients that are not Kosher: ${foundNonKosher.join(", ")}. These violate Jewish dietary laws.',
        condition: 'Kosher Diet',
        risks: [
          'Violates Jewish dietary laws (Kashrut)',
          'Contains forbidden animals or combinations',
          'May compromise religious observance',
        ],
        alternatives: [
          'Choose Kosher-certified alternatives',
          'Avoid mixing meat and dairy',
          'Replace shellfish with kosher fish',
          'Look for rabbinically supervised recipes',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check Vegetarian dietary conflicts
  static List<HealthWarning> _checkVegetarianConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // Meat and fish ingredients
    const meatKeywords = [
      'beef', 'pork', 'chicken', 'turkey', 'lamb', 'fish', 'salmon', 'tuna',
      'bacon', 'ham', 'sausage', 'meat', 'steak', 'ground beef', 'chicken breast',
      'seafood', 'shrimp', 'lobster', 'crab', 'anchovies', 'gelatin'
    ];
    
    final foundMeat = meatKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundMeat.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 VEGETARIAN ALERT: Meat/Fish Ingredients Detected',
        message: 'This meal contains meat or fish ingredients: ${foundMeat.join(", ")}. These conflict with your vegetarian diet.',
        condition: 'Vegetarian Diet',
        risks: [
          'Violates vegetarian dietary principles',
          'Contains animal flesh or fish',
          'May cause digestive discomfort if avoided long-term',
        ],
        alternatives: [
          'Replace meat with plant-based proteins',
          'Use tofu, tempeh, or legumes instead',
          'Try vegetarian meat substitutes',
          'Choose plant-based recipes',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check Vegan dietary conflicts
  static List<HealthWarning> _checkVeganConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // All animal products
    const animalProductKeywords = [
      'beef', 'pork', 'chicken', 'turkey', 'lamb', 'fish', 'salmon', 'tuna',
      'bacon', 'ham', 'sausage', 'meat', 'dairy', 'milk', 'cheese', 'butter',
      'cream', 'yogurt', 'eggs', 'honey', 'gelatin', 'whey', 'casein'
    ];
    
    final foundAnimalProducts = animalProductKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundAnimalProducts.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 VEGAN ALERT: Animal Products Detected',
        message: 'This meal contains animal products: ${foundAnimalProducts.join(", ")}. These conflict with your vegan lifestyle.',
        condition: 'Vegan Diet',
        risks: [
          'Violates vegan dietary principles',
          'Contains animal-derived ingredients',
          'May cause ethical concerns',
          'Possible digestive issues if avoided long-term',
        ],
        alternatives: [
          'Use plant-based milk alternatives',
          'Replace eggs with flax or chia eggs',
          'Try vegan cheese substitutes',
          'Choose fully plant-based recipes',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check Pescatarian dietary conflicts
  static List<HealthWarning> _checkPescatarianConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // Land animal meat (but fish is allowed)
    const landMeatKeywords = [
      'beef', 'pork', 'chicken', 'turkey', 'lamb', 'bacon', 'ham', 'sausage',
      'steak', 'ground beef', 'chicken breast', 'duck', 'goose', 'venison'
    ];
    
    final foundLandMeat = landMeatKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundLandMeat.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'critical',
        title: '🚨 PESCATARIAN ALERT: Land Animal Meat Detected',
        message: 'This meal contains land animal meat: ${foundLandMeat.join(", ")}. Pescatarian diet allows fish but not land animals.',
        condition: 'Pescatarian Diet',
        risks: [
          'Violates pescatarian dietary principles',
          'Contains forbidden land animal meat',
          'May cause digestive discomfort',
        ],
        alternatives: [
          'Replace meat with fish or seafood',
          'Use plant-based protein sources',
          'Try fish-based recipes instead',
          'Choose vegetarian options with fish',
        ],
        icon: Icons.dangerous,
        color: Colors.red,
      ));
    }
    
    return warnings;
  }

  /// Check Keto dietary conflicts
  static List<HealthWarning> _checkKetoConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // High carb ingredients
    const highCarbKeywords = [
      'bread', 'pasta', 'rice', 'potato', 'sugar', 'flour', 'oats', 'quinoa',
      'beans', 'lentils', 'chickpeas', 'banana', 'apple', 'orange', 'cereal',
      'crackers', 'cookies', 'cake', 'candy', 'honey', 'syrup'
    ];
    
    final foundHighCarb = highCarbKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundHighCarb.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ KETO WARNING: High Carb Ingredients Detected',
        message: 'This meal contains high-carb ingredients: ${foundHighCarb.join(", ")}. These may kick you out of ketosis.',
        condition: 'Keto Diet',
        risks: [
          'May break ketosis state',
          'Can spike blood sugar levels',
          'Interferes with fat burning',
          'May cause keto flu symptoms',
        ],
        alternatives: [
          'Replace with keto-friendly alternatives',
          'Use cauliflower rice instead of regular rice',
          'Choose low-carb vegetables',
          'Focus on high-fat, low-carb options',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    return warnings;
  }

  /// Check Low Carb dietary conflicts
  static List<HealthWarning> _checkLowCarbConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // High carb ingredients (similar to keto but less strict)
    const highCarbKeywords = [
      'bread', 'pasta', 'rice', 'potato', 'sugar', 'flour', 'cereal',
      'crackers', 'cookies', 'cake', 'candy', 'honey', 'syrup', 'bagel'
    ];
    
    final foundHighCarb = highCarbKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundHighCarb.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ LOW CARB WARNING: High Carb Ingredients Detected',
        message: 'This meal contains high-carb ingredients: ${foundHighCarb.join(", ")}. These exceed typical low-carb limits.',
        condition: 'Low Carb Diet',
        risks: [
          'Exceeds daily carb targets',
          'May hinder weight loss goals',
          'Can cause blood sugar spikes',
        ],
        alternatives: [
          'Choose whole grain alternatives',
          'Reduce portion sizes',
          'Replace with low-carb vegetables',
          'Focus on protein and healthy fats',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    return warnings;
  }

  /// Check Low Sodium dietary conflicts
  static List<HealthWarning> _checkLowSodiumConflicts(String allText, String title, List<dynamic> ingredients) {
    List<HealthWarning> warnings = [];
    
    // High sodium ingredients (similar to hypertension but for dietary preference)
    const highSodiumKeywords = [
      'soy sauce', 'salt', 'bacon', 'ham', 'cheese', 'pickles', 'olives',
      'canned soup', 'instant noodles', 'processed meat', 'chips', 'crackers'
    ];
    
    final foundHighSodium = highSodiumKeywords.where((keyword) => allText.contains(keyword)).toList();
    
    if (foundHighSodium.isNotEmpty) {
      warnings.add(HealthWarning(
        type: 'warning',
        title: '⚠️ LOW SODIUM WARNING: High Sodium Ingredients Detected',
        message: 'This meal contains high-sodium ingredients: ${foundHighSodium.join(", ")}. These exceed low-sodium dietary goals.',
        condition: 'Low Sodium Diet',
        risks: [
          'Exceeds daily sodium targets',
          'May cause water retention',
          'Can affect blood pressure',
        ],
        alternatives: [
          'Use herbs and spices for flavor',
          'Choose fresh ingredients over processed',
          'Use low-sodium alternatives',
          'Rinse canned foods before use',
        ],
        icon: Icons.warning,
        color: Colors.orange,
      ));
    }
    
    return warnings;
  }

  // Placeholder for other condition checks
  static Future<List<HealthWarning>> _checkMedicationConflicts(String medications, Map<String, dynamic> mealData) async => [];
}
