import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/nutrition_service.dart';
import 'manual_meal_entry_page.dart';
import 'unified_meal_planner_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, double> _todayNutrition = {};
  Map<String, double> _nutritionGoals = {};
  List<Map<String, dynamic>> _todayMeals = [];
  bool _isLoading = true;
  String _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load today's nutrition
      final nutrition = await NutritionService.getDailyNutrition(_todayDate);
      
      // Load nutrition goals from Account Settings data
      final user = FirebaseAuth.instance.currentUser;
      Map<String, double> goals;
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          goals = _calculateUserGoals(userData);
        } else {
          goals = await NutritionService.getNutritionGoals();
        }
      } else {
        goals = await NutritionService.getNutritionGoals();
      }
      
      // Load today's meals
      await _loadTodayMeals();
      
      setState(() {
        _todayNutrition = nutrition;
        _nutritionGoals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, double> _calculateUserGoals(Map<String, dynamic> userData) {
    // Calculate goals based on Account Settings data
    final weight = userData['weight']?.toDouble() ?? 70.0;
    final height = userData['height']?.toDouble() ?? 170.0;
    final gender = userData['gender']?.toString().toLowerCase() ?? 'other';
    final activityLevel = userData['activityLevel'] ?? '';
    final goal = userData['goal'] ?? '';

    // Calculate age from birthday
    int age = 25;
    if (userData['birthday'] != null) {
      try {
        final birthday = DateTime.parse(userData['birthday']);
        age = DateTime.now().difference(birthday).inDays ~/ 365;
      } catch (e) {
        age = 25;
      }
    }

    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else if (gender == 'female') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 78;
    }

    // Activity multipliers based on Account Settings options
    double activityMultiplier = 1.2;
    if (activityLevel.contains('Sedentary')) {
      activityMultiplier = 1.2;
    } else if (activityLevel.contains('Lightly active')) {
      activityMultiplier = 1.375;
    } else if (activityLevel.contains('Moderately active')) {
      activityMultiplier = 1.55;
    } else if (activityLevel.contains('Very active')) {
      activityMultiplier = 1.725;
    }

    double dailyCalories = bmr * activityMultiplier;

    // Adjust based on goal from Account Settings
    if (goal.contains('Lose weight')) {
      dailyCalories *= 0.85;
    } else if (goal.contains('Gain weight') || goal.contains('Build muscle')) {
      dailyCalories *= 1.15;
    }

    // Calculate macronutrient targets
    double proteinTarget;
    if (goal.contains('Build muscle')) {
      proteinTarget = weight * 2.4;
    } else if (goal.contains('Lose weight')) {
      proteinTarget = weight * 2.0;
    } else {
      proteinTarget = weight * 1.6;
    }

    return {
      'calories': dailyCalories,
      'protein': proteinTarget,
      'carbs': dailyCalories * 0.45 / 4,
      'fat': dailyCalories * 0.25 / 9,
      'fiber': gender == 'male' ? 38.0 : 25.0,
    };
  }

  Future<void> _loadTodayMeals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('date', isEqualTo: _todayDate)
          .orderBy('created_at', descending: true)
          .get();

      setState(() {
        _todayMeals = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Overview'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header
                    Text(
                      'Today - ${DateFormat('EEEE, MMM dd').format(DateTime.now())}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // Nutrition Progress
                    _buildNutritionProgress(),
                    const SizedBox(height: 24),

                    // Today's Meals
                    _buildTodayMeals(),
                    const SizedBox(height: 24),

                    // Quick Tips
                    _buildQuickTips(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Log Meal',
                    Icons.restaurant,
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManualMealEntryPage(
                          selectedDate: _todayDate,
                        ),
                      ),
                    ).then((_) => _loadDashboardData()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Plan Meals',
                    Icons.calendar_month,
                    Colors.purple,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UnifiedMealPlannerPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Nutrition Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Calories Progress
            _buildProgressBar(
              'Calories',
              _todayNutrition['calories'] ?? 0,
              _nutritionGoals['calories'] ?? 2000,
              Colors.orange,
              'cal',
            ),
            const SizedBox(height: 12),
            
            // Protein Progress
            _buildProgressBar(
              'Protein',
              _todayNutrition['protein'] ?? 0,
              _nutritionGoals['protein'] ?? 150,
              Colors.red,
              'g',
            ),
            const SizedBox(height: 12),
            
            // Carbs Progress
            _buildProgressBar(
              'Carbs',
              _todayNutrition['carbs'] ?? 0,
              _nutritionGoals['carbs'] ?? 250,
              Colors.blue,
              'g',
            ),
            const SizedBox(height: 12),
            
            // Fat Progress
            _buildProgressBar(
              'Fat',
              _todayNutrition['fat'] ?? 0,
              _nutritionGoals['fat'] ?? 67,
              Colors.purple,
              'g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double current, double goal, Color color, String unit) {
    final percentage = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOverGoal = current > goal;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${current.toInt()}/${goal.toInt()} $unit',
              style: TextStyle(
                color: isOverGoal ? Colors.red : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            isOverGoal ? Colors.red : color,
          ),
        ),
        if (isOverGoal)
          Text(
            'Over goal by ${(current - goal).toInt()} $unit',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildTodayMeals() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Meals (${_todayMeals.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_todayMeals.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.no_meals,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No meals logged today',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Log Meal" to get started!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_todayMeals.map((meal) => _buildMealItem(meal))),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(Map<String, dynamic> meal) {
    final nutrition = meal['nutrition'] as Map<String, dynamic>? ?? {};
    final calories = (nutrition['calories'] as num?)?.toInt() ?? 0;
    final mealType = meal['meal_type'] as String? ?? 'meal';
    final title = meal['title'] as String? ?? 'Unknown meal';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getMealTypeColor(mealType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getMealTypeIcon(mealType),
              color: _getMealTypeColor(mealType),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${mealType.substring(0, 1).toUpperCase()}${mealType.substring(1)} • $calories cal',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Colors.orange;
      case 'lunch': return Colors.green;
      case 'dinner': return Colors.blue;
      case 'snack': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Icons.free_breakfast;
      case 'lunch': return Icons.lunch_dining;
      case 'dinner': return Icons.dinner_dining;
      case 'snack': return Icons.cookie;
      default: return Icons.restaurant;
    }
  }

  Widget _buildQuickTips() {
    final caloriesConsumed = _todayNutrition['calories'] ?? 0;
    final calorieGoal = _nutritionGoals['calories'] ?? 2000;
    final remaining = calorieGoal - caloriesConsumed;
    
    String tip = '';
    IconData tipIcon = Icons.lightbulb;
    Color tipColor = Colors.blue;
    
    if (remaining > 500) {
      tip = 'You have ${remaining.toInt()} calories left today. Consider adding a healthy snack or larger portions.';
      tipIcon = Icons.add_circle;
      tipColor = Colors.green;
    } else if (remaining > 0) {
      tip = 'You\'re ${remaining.toInt()} calories away from your goal. You\'re doing great!';
      tipIcon = Icons.check_circle;
      tipColor = Colors.green;
    } else if (remaining < -200) {
      tip = 'You\'ve exceeded your calorie goal by ${(-remaining).toInt()} calories. Consider lighter meals tomorrow.';
      tipIcon = Icons.warning;
      tipColor = Colors.orange;
    } else {
      tip = 'Perfect! You\'ve hit your calorie goal for today.';
      tipIcon = Icons.star;
      tipColor = Colors.amber;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(tipIcon, color: tipColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Tip',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tipColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
