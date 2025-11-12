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

      // Get recent meals (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final mealsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('date', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      final meals = mealsSnapshot.docs.map((doc) => doc.data()).toList();

      List<HealthInsight> insights = [];

      // Generate condition-specific insights
      for (String condition in healthConditions) {
        if (condition == 'None') continue;
        insights.addAll(await _generateConditionInsights(condition, meals, user.uid));
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

    // Check sodium intake
    double totalSodium = 0;
    int mealCount = 0;

    for (var meal in meals) {
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      if (nutrition != null) {
        totalSodium += (nutrition['sodium'] as num?)?.toDouble() ?? 0;
        mealCount++;
      }
    }

    if (mealCount > 0) {
      final avgDailySodium = (totalSodium / 7); // Average per day
      const targetSodium = 1500.0; // mg per day for hypertension

      if (avgDailySodium > targetSodium) {
        insights.add(HealthInsight(
          id: 'hypertension_high_sodium',
          type: 'warning',
          title: '🧂 High Sodium Intake Warning',
          message: 'Your daily sodium intake averages ${avgDailySodium.toInt()}mg. Target is ${targetSodium.toInt()}mg for blood pressure control.',
          icon: Icons.warning,
          color: Colors.red,
          actionable: true,
          suggestions: [
            'Use herbs and spices instead of salt',
            'Choose fresh foods over processed',
            'Read nutrition labels carefully',
            'Rinse canned foods to reduce sodium',
          ],
          createdAt: DateTime.now(),
          relatedCondition: 'Hypertension',
        ));
      }
    }

    return insights;
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

    // Calculate average daily calories
    double totalCalories = 0;
    Map<String, double> dailyCalories = {};

    for (var meal in meals) {
      final date = (meal['date'] as Timestamp).toDate();
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      
      if (nutrition != null) {
        final calories = (nutrition['calories'] as num?)?.toDouble() ?? 0;
        dailyCalories[dateKey] = (dailyCalories[dateKey] ?? 0) + calories;
      }
    }

    if (dailyCalories.isNotEmpty) {
      final avgCalories = dailyCalories.values.reduce((a, b) => a + b) / dailyCalories.length;
      const targetCalories = 1500.0; // Example target for weight loss

      if (avgCalories > targetCalories + 200) {
        insights.add(HealthInsight(
          id: 'weight_loss_high_calories',
          type: 'suggestion',
          title: '🎯 Calorie Adjustment Needed',
          message: 'Your daily calories average ${avgCalories.toInt()}. Consider reducing to ${targetCalories.toInt()} for weight loss.',
          icon: Icons.trending_down,
          color: Colors.orange,
          actionable: true,
          suggestions: [
            'Reduce portion sizes by 20%',
            'Choose lower-calorie cooking methods',
            'Increase vegetable portions',
            'Drink water before meals',
          ],
          createdAt: DateTime.now(),
          relatedCondition: 'Weight Loss',
        ));
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

  // Placeholder methods for other conditions (implement as needed)
  static Future<List<HealthInsight>> _generateCholesterolInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateObesityInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generatePCOSInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateKidneyInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateMuscleGainInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateHealthyEatingInsights(List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateAllergyInsights(List<String> allergies, List<Map<String, dynamic>> meals, String userId) async => [];
  static Future<List<HealthInsight>> _generateNutritionInsights(List<Map<String, dynamic>> meals, String userId) async => [];
}
