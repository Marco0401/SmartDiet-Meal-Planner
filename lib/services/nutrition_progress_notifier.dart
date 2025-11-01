import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nutrition_calculator_service.dart';

class NutritionProgressNotifier {
  static Future<void> showProgressNotification(
    BuildContext context,
    Map<String, dynamic> nutritionData,
  ) async {
    try {
      // Get user profile to calculate targets
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final userData = doc.data()!;
      
      // Calculate daily targets using shared service
      final targets = NutritionCalculatorService.calculateDailyTargetsFromMap(userData);
      
      // Get today's date
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Get today's total nutrition from all meals
      final mealsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .where('date', isEqualTo: dateKey)
          .get();

      // Calculate totals
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var meal in mealsSnapshot.docs) {
        final mealData = meal.data();
        final nutrition = mealData['nutrition'] as Map<String, dynamic>?;
        
        if (nutrition != null) {
          totalCalories += _toDouble(nutrition['calories']);
          totalProtein += _toDouble(nutrition['protein']);
          totalCarbs += _toDouble(nutrition['carbs']);
          totalFat += _toDouble(nutrition['fat']);
        }
      }

      // Calculate percentages
      final caloriesPercentage = ((totalCalories / (targets['calories'] ?? 2000)) * 100).round();
      final proteinPercentage = ((totalProtein / (targets['protein'] ?? 100)) * 100).round();

      // Generate motivational message
      final message = _generateMotivationalMessage(caloriesPercentage, proteinPercentage);
      
      // Show overlay notification
      _showOverlayNotification(context, message, totalCalories, totalProtein, totalCarbs, totalFat, targets);
    } catch (e) {
      print('Error showing progress notification: $e');
    }
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _generateMotivationalMessage(int caloriesPercentage, int proteinPercentage) {
    if (caloriesPercentage < 30) {
      return "🌟 Great start to your day!";
    } else if (caloriesPercentage < 50) {
      return "💪 You're making excellent progress!";
    } else if (caloriesPercentage < 70) {
      return "🎯 Keep going, you're doing amazing!";
    } else if (caloriesPercentage < 90) {
      return "🔥 Almost there! Stay strong!";
    } else if (caloriesPercentage <= 110) {
      return "✨ Perfect! You've hit your daily target!";
    } else {
      return "⚠️ You've exceeded your target!";
    }
  }

  static void _showOverlayNotification(
    BuildContext context,
    String motivationalMessage,
    double calories,
    double protein,
    double carbs,
    double fat,
    Map<String, double> targets,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.celebration,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              motivationalMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Today's nutrition updated!",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => overlayEntry.remove(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildNutrientRow(
                          'Calories',
                          calories.toInt(),
                          (targets['calories'] ?? 2000).toInt(),
                          'kcal',
                          Icons.local_fire_department,
                        ),
                        const SizedBox(height: 12),
                        _buildNutrientRow(
                          'Protein',
                          protein.toInt(),
                          (targets['protein'] ?? 100).toInt(),
                          'g',
                          Icons.fitness_center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static Widget _buildNutrientRow(
    String label,
    int consumed,
    int target,
    String unit,
    IconData icon,
  ) {
    final percentage = target > 0 ? ((consumed / target) * 100).round() : 0;
    
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$consumed / $target $unit ($percentage%)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0, 1),
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percentage > 100 ? Colors.red : Colors.white,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
