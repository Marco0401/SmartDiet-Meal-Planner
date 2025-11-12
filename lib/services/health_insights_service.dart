import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HealthInsight {
  final String id;
  final String type; // 'warning', 'suggestion', 'achievement', 'tip'
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final bool actionable;
  final List<String> suggestions;
  final DateTime createdAt;
  final String? relatedCondition;

  HealthInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.actionable = false,
    this.suggestions = const [],
    required this.createdAt,
    this.relatedCondition,
  });
}

class HealthInsightsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generate personalized health insights based on user's meals and conditions
  static Future<List<HealthInsight>> generateInsights() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final healthConditions = List<String>.from(userData['healthConditions'] ?? []);
      final allergies = List<String>.from(userData['allergies'] ?? []);
      final goal = userData['goal'] as String?;

      // Get recent meals (last 30 days to ensure we have data)
      print('DEBUG: Fetching meals for user ${user.uid}');
      final mealsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .orderBy('created_at', descending: true)
          .limit(50) // Get last 50 meals
          .get();

      final meals = mealsSnapshot.docs.map((doc) => doc.data()).toList();
      print('DEBUG: Found ${meals.length} meals for analysis');
      
      // Filter to last 7 days if we have created_at timestamps
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentMeals = meals.where((meal) {
        final createdAt = meal['created_at'] as Timestamp?;
        if (createdAt != null) {
          return createdAt.toDate().isAfter(sevenDaysAgo);
        }
        return true; // Include meals without timestamp for now
      }).toList();
      
      print('DEBUG: ${recentMeals.length} meals from last 7 days');
      print('DEBUG: Health conditions: $healthConditions');
      print('DEBUG: Allergies: $allergies');
      print('DEBUG: Goal: $goal');

      List<HealthInsight> insights = [];

      // Generate condition-specific insights
      for (String condition in healthConditions) {
        if (condition == 'None') continue;
        print('DEBUG: Generating insights for condition: $condition');
        final conditionInsights = await _generateConditionInsights(condition, recentMeals, user.uid);
        print('DEBUG: Generated ${conditionInsights.length} insights for $condition');
        insights.addAll(conditionInsights);
      }

      // Generate goal-based insights
      if (goal != null && goal != 'None') {
        insights.addAll(await _generateGoalInsights(goal, meals, user.uid));
      }

      // Generate allergy insights
      insights.addAll(await _generateAllergyInsights(allergies, meals, user.uid));

      // Generate general nutrition insights
      insights.addAll(await _generateNutritionInsights(meals, user.uid));

      // Sort by priority (warnings first, then suggestions, then tips)
      insights.sort((a, b) {
        const priority = {'warning': 0, 'suggestion': 1, 'achievement': 2, 'tip': 3};
        return priority[a.type]!.compareTo(priority[b.type]!);
      });

      // If no insights generated, create some basic ones
      if (insights.isEmpty) {
        print('DEBUG: No insights generated, creating fallback insights');
        insights.addAll(_generateFallbackInsights(healthConditions, goal));
      }
      
      print('DEBUG: Total insights generated: ${insights.length}');

      // Store insights in Firestore for persistence
      await _storeInsights(insights, user.uid);

      return insights.take(10).toList(); // Limit to top 10 insights
    } catch (e) {
      print('Error generating health insights: $e');
      return [];
    }
  }

  /// Generate insights for specific health conditions
  static Future<List<HealthInsight>> _generateConditionInsights(
    String condition,
    List<Map<String, dynamic>> meals,
    String userId,
  ) async {
    List<HealthInsight> insights = [];

    switch (condition) {
      case 'Diabetes':
        insights.addAll(await _generateDiabetesInsights(meals, userId));
        break;
      case 'Hypertension':
        insights.addAll(await _generateHypertensionInsights(meals, userId));
        break;
      case 'High Cholesterol':
        insights.addAll(await _generateCholesterolInsights(meals, userId));
        break;
      case 'Obesity':
        insights.addAll(await _generateObesityInsights(meals, userId));
        break;
      case 'PCOS':
        insights.addAll(await _generatePCOSInsights(meals, userId));
        break;
      case 'Kidney Disease':
        insights.addAll(await _generateKidneyInsights(meals, userId));
        break;
    }

    return insights;
  }

  /// Generate diabetes-specific insights
  static Future<List<HealthInsight>> _generateDiabetesInsights(
    List<Map<String, dynamic>> meals,
    String userId,
  ) async {
    List<HealthInsight> insights = [];

    // Calculate average daily carbs
    double totalCarbs = 0;
    int mealDays = 0;
    Map<String, double> dailyCarbs = {};

    for (var meal in meals) {
      final date = (meal['date'] as Timestamp).toDate();
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      
      if (nutrition != null) {
        final carbs = (nutrition['carbs'] as num?)?.toDouble() ?? 0;
        dailyCarbs[dateKey] = (dailyCarbs[dateKey] ?? 0) + carbs;
      }
    }

    if (dailyCarbs.isNotEmpty) {
      final avgCarbs = dailyCarbs.values.reduce((a, b) => a + b) / dailyCarbs.length;
      const targetCarbs = 150.0; // Recommended daily carbs for diabetics

      if (avgCarbs > targetCarbs) {
        insights.add(HealthInsight(
          id: 'diabetes_high_carbs',
          type: 'warning',
          title: '⚠️ High Carb Intake Detected',
          message: 'Your average carb intake is ${avgCarbs.toInt()}g/day. Consider reducing to ${targetCarbs.toInt()}g for better blood sugar control.',
          icon: Icons.warning,
          color: Colors.orange,
          actionable: true,
          suggestions: [
            'Replace white rice with cauliflower rice',
            'Choose berries over high-sugar fruits',
            'Try zucchini noodles instead of pasta',
            'Opt for whole grains over refined carbs',
          ],
          createdAt: DateTime.now(),
          relatedCondition: 'Diabetes',
        ));
      } else if (avgCarbs < 100) {
        insights.add(HealthInsight(
          id: 'diabetes_low_carbs',
          type: 'achievement',
          title: '🎉 Excellent Carb Management!',
          message: 'You\'re doing great keeping carbs at ${avgCarbs.toInt()}g/day. This helps maintain stable blood sugar.',
          icon: Icons.celebration,
          color: Colors.green,
          actionable: false,
          createdAt: DateTime.now(),
          relatedCondition: 'Diabetes',
        ));
      }
    }

    // Check for high-glycemic foods
    int highGICount = 0;
    for (var meal in meals) {
      final title = meal['title'] as String? ?? '';
      if (_isHighGlycemicFood(title)) {
        highGICount++;
      }
    }

    if (highGICount > 3) {
      insights.add(HealthInsight(
        id: 'diabetes_high_gi',
        type: 'suggestion',
        title: '📊 High Glycemic Index Alert',
        message: 'You\'ve consumed $highGICount high-GI foods this week. Consider low-GI alternatives.',
        icon: Icons.trending_up,
        color: Colors.blue,
        actionable: true,
        suggestions: [
          'Choose steel-cut oats over instant oats',
          'Eat sweet potatoes instead of white potatoes',
          'Select brown rice over white rice',
          'Add protein or healthy fats to slow carb absorption',
        ],
        createdAt: DateTime.now(),
        relatedCondition: 'Diabetes',
      ));
    }

    return insights;
  }

  /// Generate hypertension-specific insights
  static Future<List<HealthInsight>> _generateHypertensionInsights(
    List<Map<String, dynamic>> meals,
    String userId,
  ) async {
    List<HealthInsight> insights = [];

    // Since sodium data is not available, provide general hypertension guidance
    if (meals.isNotEmpty) {
      // Check for high-sodium ingredients in meal titles/ingredients
      int highSodiumMeals = 0;
      for (var meal in meals) {
        final title = (meal['title'] as String? ?? '').toLowerCase();
        final ingredients = meal['ingredients'] as List<dynamic>? ?? [];
        final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
        
        if (_containsHighSodiumKeywords(allText)) {
          highSodiumMeals++;
        }
      }

      if (highSodiumMeals > 3) {
        insights.add(HealthInsight(
          id: 'hypertension_sodium_warning',
          type: 'warning',
          title: '🧂 High-Sodium Foods Detected',
          message: 'You\'ve consumed $highSodiumMeals meals with high-sodium ingredients this week. Consider low-sodium alternatives.',
          icon: Icons.warning,
          color: Colors.orange,
          actionable: true,
          suggestions: [
            'Use herbs and spices instead of salt',
            'Choose fresh foods over processed',
            'Avoid canned soups and processed meats',
            'Cook at home to control sodium',
          ],
          createdAt: DateTime.now(),
          relatedCondition: 'Hypertension',
        ));
      } else if (highSodiumMeals == 0) {
        insights.add(HealthInsight(
          id: 'hypertension_good_choices',
          type: 'achievement',
          title: '🎉 Great Sodium Management!',
          message: 'You\'ve been avoiding high-sodium foods this week. Keep it up for better blood pressure control!',
          icon: Icons.celebration,
          color: Colors.green,
          actionable: false,
          createdAt: DateTime.now(),
          relatedCondition: 'Hypertension',
        ));
      }
    }

    return insights;
  }

  /// Helper method to detect high-sodium keywords
  static bool _containsHighSodiumKeywords(String text) {
    const highSodiumKeywords = [
      'soy sauce', 'salt', 'bacon', 'ham', 'cheese', 'pickles',
      'canned soup', 'processed meat', 'instant noodles', 'chips',
      'olives', 'anchovies', 'salami', 'pepperoni', 'sausage',
      'canned', 'frozen dinner', 'fast food', 'restaurant'
    ];
    
    return highSodiumKeywords.any((keyword) => text.contains(keyword));
  }

  /// Generate goal-based insights
  static Future<List<HealthInsight>> _generateGoalInsights(
    String goal,
    List<Map<String, dynamic>> meals,
    String userId,
  ) async {
    List<HealthInsight> insights = [];

    switch (goal) {
      case 'Lose weight':
        insights.addAll(await _generateWeightLossInsights(meals, userId));
        break;
      case 'Build muscle':
        insights.addAll(await _generateMuscleGainInsights(meals, userId));
        break;
      case 'Eat healthier / clean eating':
        insights.addAll(await _generateHealthyEatingInsights(meals, userId));
        break;
    }

    return insights;
  }

  /// Generate weight loss insights
  static Future<List<HealthInsight>> _generateWeightLossInsights(
    List<Map<String, dynamic>> meals,
    String userId,
  ) async {
    List<HealthInsight> insights = [];

    if (meals.isNotEmpty) {
      // Analyze macronutrient balance for weight loss
      double totalCarbs = 0;
      double totalProtein = 0;
      double totalFat = 0;
      double totalFiber = 0;
      int mealCount = 0;

      for (var meal in meals) {
        final nutrition = meal['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          totalCarbs += (nutrition['carbs'] as num?)?.toDouble() ?? 0;
          totalProtein += (nutrition['protein'] as num?)?.toDouble() ?? 0;
          totalFat += (nutrition['fat'] as num?)?.toDouble() ?? 0;
          totalFiber += (nutrition['fiber'] as num?)?.toDouble() ?? 0;
          mealCount++;
        }
      }

      if (mealCount > 0) {
        final avgCarbs = totalCarbs / mealCount;
        final avgProtein = totalProtein / mealCount;
        final avgFiber = totalFiber / mealCount;

        // High carb warning for weight loss
        if (avgCarbs > 50) {
          insights.add(HealthInsight(
            id: 'weight_loss_high_carbs',
            type: 'suggestion',
            title: '🍞 Consider Reducing Carbs',
            message: 'Your average carb intake is ${avgCarbs.toInt()}g per meal. Lower carbs can help with weight loss.',
            icon: Icons.trending_down,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Replace rice/pasta with vegetables',
              'Choose protein-rich snacks',
              'Try intermittent fasting',
              'Focus on whole foods',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Weight Loss',
          ));
        }

        // Low protein warning
        if (avgProtein < 20) {
          insights.add(HealthInsight(
            id: 'weight_loss_low_protein',
            type: 'suggestion',
            title: '💪 Increase Protein Intake',
            message: 'Your protein intake is ${avgProtein.toInt()}g per meal. Higher protein helps preserve muscle during weight loss.',
            icon: Icons.fitness_center,
            color: Colors.blue,
            actionable: true,
            suggestions: [
              'Add lean meats to meals',
              'Include eggs or Greek yogurt',
              'Try protein smoothies',
              'Snack on nuts or seeds',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Weight Loss',
          ));
        }

        // Low fiber suggestion
        if (avgFiber < 5) {
          insights.add(HealthInsight(
            id: 'weight_loss_low_fiber',
            type: 'suggestion',
            title: '🥬 Add More Fiber',
            message: 'Your fiber intake is ${avgFiber.toInt()}g per meal. More fiber helps you feel full longer.',
            icon: Icons.eco,
            color: Colors.green,
            actionable: true,
            suggestions: [
              'Add vegetables to every meal',
              'Choose whole grains over refined',
              'Snack on fruits with skin',
              'Include beans and legumes',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Weight Loss',
          ));
        }
      }
    }

    return insights;
  }

  /// Store insights in Firestore
  static Future<void> _storeInsights(List<HealthInsight> insights, String userId) async {
    try {
      final batch = _firestore.batch();
      final insightsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('health_insights');

      // Clear old insights (keep only last 30 days)
      final oldInsights = await insightsRef
          .where('createdAt', isLessThan: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))
          ))
          .get();

      for (var doc in oldInsights.docs) {
        batch.delete(doc.reference);
      }

      // Add new insights
      for (var insight in insights) {
        final docRef = insightsRef.doc(insight.id);
        batch.set(docRef, {
          'type': insight.type,
          'title': insight.title,
          'message': insight.message,
          'icon': insight.icon.codePoint,
          'color': insight.color.value,
          'actionable': insight.actionable,
          'suggestions': insight.suggestions,
          'createdAt': FieldValue.serverTimestamp(),
          'relatedCondition': insight.relatedCondition,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error storing insights: $e');
    }
  }

  /// Helper method to check if food is high glycemic
  static bool _isHighGlycemicFood(String foodName) {
    final highGIFoods = [
      'white bread', 'white rice', 'potato', 'corn flakes', 'watermelon',
      'pineapple', 'instant oats', 'bagel', 'donut', 'candy', 'soda',
      'french fries', 'mashed potato', 'rice cakes', 'pretzels'
    ];
    
    return highGIFoods.any((food) => 
      foodName.toLowerCase().contains(food.toLowerCase())
    );
  }

  /// Get stored insights from Firestore
  static Future<List<HealthInsight>> getStoredInsights() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('health_insights')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return HealthInsight(
          id: doc.id,
          type: data['type'],
          title: data['title'],
          message: data['message'],
          icon: IconData(data['icon'], fontFamily: 'MaterialIcons'),
          color: Color(data['color']),
          actionable: data['actionable'] ?? false,
          suggestions: List<String>.from(data['suggestions'] ?? []),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          relatedCondition: data['relatedCondition'],
        );
      }).toList();
    } catch (e) {
      print('Error getting stored insights: $e');
      return [];
    }
  }

  /// Generate cholesterol-specific insights
  static Future<List<HealthInsight>> _generateCholesterolInsights(List<Map<String, dynamic>> meals, String userId) async {
    List<HealthInsight> insights = [];

    if (meals.isNotEmpty) {
      double totalFat = 0;
      int highFatMeals = 0;
      int mealCount = 0;

      for (var meal in meals) {
        final nutrition = meal['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          final fat = (nutrition['fat'] as num?)?.toDouble() ?? 0;
          totalFat += fat;
          if (fat > 15) highFatMeals++;
          mealCount++;
        }
      }

      if (mealCount > 0) {
        final avgFat = totalFat / mealCount;
        
        if (avgFat > 20) {
          insights.add(HealthInsight(
            id: 'cholesterol_high_fat',
            type: 'warning',
            title: '🥩 High Fat Intake Warning',
            message: 'Your average fat intake is ${avgFat.toInt()}g per meal. High fat can raise cholesterol levels.',
            icon: Icons.warning,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Choose lean cuts of meat',
              'Remove skin from poultry',
              'Use cooking methods that don\'t add fat',
              'Include more plant-based proteins',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'High Cholesterol',
          ));
        } else if (avgFat < 10) {
          insights.add(HealthInsight(
            id: 'cholesterol_good_fat',
            type: 'achievement',
            title: '💚 Great Fat Management!',
            message: 'You\'re keeping fat intake low at ${avgFat.toInt()}g per meal. This helps manage cholesterol.',
            icon: Icons.celebration,
            color: Colors.green,
            actionable: false,
            createdAt: DateTime.now(),
            relatedCondition: 'High Cholesterol',
          ));
        }
      }
    }

    return insights;
  }

  /// Generate obesity-specific insights
  static Future<List<HealthInsight>> _generateObesityInsights(List<Map<String, dynamic>> meals, String userId) async {
    List<HealthInsight> insights = [];

    if (meals.isNotEmpty) {
      double totalCarbs = 0;
      double totalFat = 0;
      double totalFiber = 0;
      int mealCount = 0;

      for (var meal in meals) {
        final nutrition = meal['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          totalCarbs += (nutrition['carbs'] as num?)?.toDouble() ?? 0;
          totalFat += (nutrition['fat'] as num?)?.toDouble() ?? 0;
          totalFiber += (nutrition['fiber'] as num?)?.toDouble() ?? 0;
          mealCount++;
        }
      }

      if (mealCount > 0) {
        final avgCarbs = totalCarbs / mealCount;
        final avgFiber = totalFiber / mealCount;
        
        if (avgCarbs > 60) {
          insights.add(HealthInsight(
            id: 'obesity_high_carbs',
            type: 'suggestion',
            title: '🍞 Consider Lower Carb Meals',
            message: 'High carb intake (${avgCarbs.toInt()}g/meal) can make weight management challenging.',
            icon: Icons.trending_down,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Fill half your plate with vegetables',
              'Choose complex carbs over simple ones',
              'Control portion sizes',
              'Add more protein to feel fuller',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Obesity',
          ));
        }
        
        if (avgFiber < 5) {
          insights.add(HealthInsight(
            id: 'obesity_low_fiber',
            type: 'suggestion',
            title: '🥬 Increase Fiber for Satiety',
            message: 'More fiber (currently ${avgFiber.toInt()}g/meal) helps you feel full and manage weight.',
            icon: Icons.eco,
            color: Colors.green,
            actionable: true,
            suggestions: [
              'Add vegetables to every meal',
              'Choose whole grains',
              'Include beans and legumes',
              'Eat fruits with skin on',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Obesity',
          ));
        }
      }
    }

    return insights;
  }

  /// Generate PCOS-specific insights
  static Future<List<HealthInsight>> _generatePCOSInsights(List<Map<String, dynamic>> meals, String userId) async {
    List<HealthInsight> insights = [];

    if (meals.isNotEmpty) {
      double totalCarbs = 0;
      double totalSugar = 0;
      double totalFiber = 0;
      int mealCount = 0;

      for (var meal in meals) {
        final nutrition = meal['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          totalCarbs += (nutrition['carbs'] as num?)?.toDouble() ?? 0;
          totalSugar += (nutrition['sugar'] as num?)?.toDouble() ?? 0;
          totalFiber += (nutrition['fiber'] as num?)?.toDouble() ?? 0;
          mealCount++;
        }
      }

      if (mealCount > 0) {
        final avgSugar = totalSugar / mealCount;
        final avgCarbs = totalCarbs / mealCount;
        
        if (avgSugar > 15) {
          insights.add(HealthInsight(
            id: 'pcos_high_sugar',
            type: 'warning',
            title: '🍯 High Sugar Intake Alert',
            message: 'High sugar (${avgSugar.toInt()}g/meal) can worsen insulin resistance in PCOS.',
            icon: Icons.warning,
            color: Colors.red,
            actionable: true,
            suggestions: [
              'Choose low-glycemic foods',
              'Avoid processed sugars',
              'Eat protein with carbs',
              'Focus on whole foods',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'PCOS',
          ));
        }
        
        if (avgCarbs > 45) {
          insights.add(HealthInsight(
            id: 'pcos_high_carbs',
            type: 'suggestion',
            title: '🌾 Consider Lower Carb Approach',
            message: 'Lower carb intake can help manage insulin resistance in PCOS.',
            icon: Icons.trending_down,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Try a lower-carb approach',
              'Include anti-inflammatory foods',
              'Add healthy fats like avocado',
              'Choose lean proteins',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'PCOS',
          ));
        }
      }
    }

    return insights;
  }

  /// Generate kidney disease insights
  static Future<List<HealthInsight>> _generateKidneyInsights(List<Map<String, dynamic>> meals, String userId) async {
    List<HealthInsight> insights = [];

    if (meals.isNotEmpty) {
      double totalProtein = 0;
      int mealCount = 0;
      int highSodiumMeals = 0;

      for (var meal in meals) {
        final nutrition = meal['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          totalProtein += (nutrition['protein'] as num?)?.toDouble() ?? 0;
          mealCount++;
        }
        
        // Check for high-sodium ingredients
        final title = (meal['title'] as String? ?? '').toLowerCase();
        final ingredients = meal['ingredients'] as List<dynamic>? ?? [];
        final allText = (title + ' ' + ingredients.join(' ')).toLowerCase();
        if (_containsHighSodiumKeywords(allText)) {
          highSodiumMeals++;
        }
      }

      if (mealCount > 0) {
        final avgProtein = totalProtein / mealCount;
        
        if (avgProtein > 30) {
          insights.add(HealthInsight(
            id: 'kidney_high_protein',
            type: 'warning',
            title: '🥩 High Protein Intake Warning',
            message: 'High protein (${avgProtein.toInt()}g/meal) may strain kidneys. Consult your doctor.',
            icon: Icons.warning,
            color: Colors.red,
            actionable: true,
            suggestions: [
              'Consult your nephrologist',
              'Consider protein restriction',
              'Focus on high-quality proteins',
              'Monitor kidney function regularly',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Kidney Disease',
          ));
        }
        
        if (highSodiumMeals > 2) {
          insights.add(HealthInsight(
            id: 'kidney_high_sodium',
            type: 'warning',
            title: '🧂 Sodium Restriction Needed',
            message: 'Multiple high-sodium meals detected. Kidney disease requires strict sodium control.',
            icon: Icons.warning,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Avoid processed foods',
              'Cook fresh meals at home',
              'Use herbs instead of salt',
              'Read food labels carefully',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Kidney Disease',
          ));
        }
      }
    }

    return insights;
  }

  /// Generate fallback insights when no meal data is available
  static List<HealthInsight> _generateFallbackInsights(List<String> healthConditions, String? goal) {
    List<HealthInsight> insights = [];
    
    // Welcome message
    insights.add(HealthInsight(
      id: 'welcome_message',
      type: 'tip',
      title: '👋 Welcome to Health Insights!',
      message: 'Start logging meals to get personalized health recommendations based on your conditions.',
      icon: Icons.lightbulb,
      color: Colors.blue,
      actionable: true,
      suggestions: [
        'Log your first meal to get started',
        'Add ingredients for better analysis',
        'Check back after a few meals',
      ],
      createdAt: DateTime.now(),
    ));
    
    // Condition-specific tips
    for (String condition in healthConditions) {
      if (condition == 'None') continue;
      
      switch (condition) {
        case 'Diabetes':
          insights.add(HealthInsight(
            id: 'diabetes_tip',
            type: 'tip',
            title: '🩺 Diabetes Management Tips',
            message: 'Monitor your carb intake and choose low-glycemic foods for better blood sugar control.',
            icon: Icons.medical_services,
            color: Colors.green,
            actionable: true,
            suggestions: [
              'Choose whole grains over refined carbs',
              'Include protein with each meal',
              'Monitor portion sizes',
              'Stay hydrated',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Diabetes',
          ));
          break;
        case 'Hypertension':
          insights.add(HealthInsight(
            id: 'hypertension_tip',
            type: 'tip',
            title: '🫀 Blood Pressure Management',
            message: 'Reduce sodium intake and focus on fresh, whole foods to help manage blood pressure.',
            icon: Icons.favorite,
            color: Colors.red,
            actionable: true,
            suggestions: [
              'Use herbs and spices instead of salt',
              'Choose fresh over processed foods',
              'Include potassium-rich foods',
              'Limit alcohol consumption',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Hypertension',
          ));
          break;
        case 'High Cholesterol':
          insights.add(HealthInsight(
            id: 'cholesterol_tip',
            type: 'tip',
            title: '🥩 Cholesterol Management',
            message: 'Choose lean proteins and healthy fats to help manage cholesterol levels.',
            icon: Icons.eco,
            color: Colors.orange,
            actionable: true,
            suggestions: [
              'Choose lean cuts of meat',
              'Include omega-3 rich fish',
              'Use olive oil for cooking',
              'Add more fiber to your diet',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'High Cholesterol',
          ));
          break;
      }
    }
    
    // Goal-based tips
    if (goal != null && goal != 'None') {
      switch (goal) {
        case 'Lose weight':
          insights.add(HealthInsight(
            id: 'weight_loss_tip',
            type: 'tip',
            title: '⚖️ Weight Loss Success Tips',
            message: 'Focus on portion control and nutrient-dense foods for sustainable weight loss.',
            icon: Icons.trending_down,
            color: Colors.purple,
            actionable: true,
            suggestions: [
              'Fill half your plate with vegetables',
              'Choose lean proteins',
              'Control portion sizes',
              'Stay consistent with logging',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Weight Loss',
          ));
          break;
        case 'Build muscle':
          insights.add(HealthInsight(
            id: 'muscle_gain_tip',
            type: 'tip',
            title: '💪 Muscle Building Nutrition',
            message: 'Ensure adequate protein intake and fuel your workouts with proper nutrition.',
            icon: Icons.fitness_center,
            color: Colors.indigo,
            actionable: true,
            suggestions: [
              'Include protein in every meal',
              'Eat within 30 minutes post-workout',
              'Don\'t skip carbs for energy',
              'Stay hydrated',
            ],
            createdAt: DateTime.now(),
            relatedCondition: 'Muscle Gain',
          ));
          break;
      }
    }
    
    return insights;
  }

  // Placeholder methods for other features
  static Future<List<HealthInsight>> _generateMuscleGainInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateHealthyEatingInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateAllergyInsights(List<String> allergies, List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateNutritionInsights(List<Map<String, dynamic>> meals, String userId) async => [];
}
