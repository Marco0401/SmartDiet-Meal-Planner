import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/user_profile.dart';

class NutritionAnalyticsPage extends StatefulWidget {
  const NutritionAnalyticsPage({super.key});

  @override
  State<NutritionAnalyticsPage> createState() => _NutritionAnalyticsPageState();
}

class _NutritionAnalyticsPageState extends State<NutritionAnalyticsPage> 
    with TickerProviderStateMixin {
  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _selectedDate = DateTime.now();
  final Map<String, Map<String, dynamic>> _weeklyNutrition = {};
  bool _isLoading = false;
  String? _error;
  
  // Tab controller
  late TabController _tabController;
  
  // Profile analysis data
  UserProfile? _userProfile;
  Map<String, dynamic>? _calculatedAnalysis;

  // Nutrition goals (can be made configurable later)
  final Map<String, double> _nutritionGoals = {
    'calories': 2000,
    'protein': 50,
    'carbs': 250,
    'fat': 65,
    'fiber': 25,
    'sugar': 50,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWeeklyNutrition();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyNutrition() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get the start of the week (Monday)
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );

        // Load nutrition for the entire week
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = _formatDate(date);

          // Query for individual meal documents for this date
          final mealsQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .where('date', isEqualTo: dateKey)
              .get();

          if (mealsQuery.docs.isNotEmpty) {
            print('DEBUG: Found ${mealsQuery.docs.length} meals for $dateKey');
            List<Map<String, dynamic>> allMeals = [];
            
            for (final doc in mealsQuery.docs) {
              final data = doc.data();
              print('DEBUG: Raw meal data for $dateKey: $data');
              
              // Check if this is the old format with meals array
              if (data['meals'] != null && data['meals'] is List) {
                print('DEBUG: Found old format with meals array');
                final mealsArray = data['meals'] as List;
                for (final meal in mealsArray) {
                  final mealData = meal is Map<String, dynamic> ? meal : Map<String, dynamic>.from(meal as Map);
                  
                  String title = mealData['title']?.toString() ?? 'Unknown Meal';
                  Map<String, dynamic> nutrition = {};
                  String mealType = mealData['mealType']?.toString() ?? mealData['meal_type']?.toString() ?? 'lunch';
                  
                  if (mealData['nutrition'] != null) {
                    if (mealData['nutrition'] is Map<String, dynamic>) {
                      nutrition = mealData['nutrition'];
                    } else if (mealData['nutrition'] is Map) {
                      nutrition = Map<String, dynamic>.from(mealData['nutrition']);
                    }
                  }
                  
                  print('DEBUG: Processed old format meal: $title - $nutrition');
                  allMeals.add({
                    'title': title,
                    'nutrition': nutrition,
                    'mealType': mealType,
                  });
                }
              } else {
                // New format - individual meal document
                print('DEBUG: Found new format individual meal');
                String title = 'Unknown Meal';
                Map<String, dynamic> nutrition = {};
                String mealType = 'lunch';
                
                if (data['title'] != null) {
                  title = data['title'].toString();
                } else if (data['name'] != null) {
                  title = data['name'].toString();
                }
                
                if (data['nutrition'] != null) {
                  if (data['nutrition'] is Map<String, dynamic>) {
                    nutrition = data['nutrition'];
                  } else if (data['nutrition'] is Map) {
                    nutrition = Map<String, dynamic>.from(data['nutrition']);
                  }
                }
                
                if (data['mealType'] != null) {
                  mealType = data['mealType'].toString();
                } else if (data['meal_type'] != null) {
                  mealType = data['meal_type'].toString();
                }
                
                print('DEBUG: Processed new format meal: $title - $nutrition');
                allMeals.add({
                  'title': title,
                  'nutrition': nutrition,
                  'mealType': mealType,
                });
              }
            }
            final nutrition = _calculateDailyNutrition(allMeals);
            print('DEBUG: Calculated nutrition for $dateKey: $nutrition');
            _weeklyNutrition[dateKey] = nutrition;
          } else {
            print('DEBUG: No meals found for $dateKey');
            _weeklyNutrition[dateKey] = _getEmptyNutrition();
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${_getDayName(date.weekday)} ${date.month}/${date.day}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Map<String, dynamic> _calculateDailyNutrition(
    List<Map<String, dynamic>> meals,
  ) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalSugar = 0;

    for (final meal in meals) {
      final nutritionData = meal['nutrition'];
      if (nutritionData != null) {
        // Safely convert to Map<String, dynamic>
        Map<String, dynamic> nutrition;
        if (nutritionData is Map<String, dynamic>) {
          nutrition = nutritionData;
        } else if (nutritionData is Map) {
          nutrition = Map<String, dynamic>.from(nutritionData);
        } else {
          continue; // Skip if not a map
        }
        
        totalCalories += _toDouble(nutrition['calories']);
        totalProtein += _toDouble(nutrition['protein']);
        totalCarbs += _toDouble(nutrition['carbs']);
        totalFat += _toDouble(nutrition['fat']);
        totalFiber += _toDouble(nutrition['fiber']);
        totalSugar += _toDouble(nutrition['sugar']);
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
    };
  }

  Map<String, dynamic> _getEmptyNutrition() {
    return {
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
    };
  }

  Map<String, dynamic> _calculateWeeklyAverages() {
    if (_weeklyNutrition.isEmpty) return _getEmptyNutrition();

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalSugar = 0;
    int daysWithData = 0;

    for (final nutrition in _weeklyNutrition.values) {
      final calories = _toDouble(nutrition['calories']);
      if (calories > 0) {
        totalCalories += calories;
        totalProtein += _toDouble(nutrition['protein']);
        totalCarbs += _toDouble(nutrition['carbs']);
        totalFat += _toDouble(nutrition['fat']);
        totalFiber += _toDouble(nutrition['fiber']);
        totalSugar += _toDouble(nutrition['sugar']);
        daysWithData++;
      }
    }

    if (daysWithData == 0) return _getEmptyNutrition();

    return {
      'calories': totalCalories / daysWithData,
      'protein': totalProtein / daysWithData,
      'carbs': totalCarbs / daysWithData,
      'fat': totalFat / daysWithData,
      'fiber': totalFiber / daysWithData,
      'sugar': totalSugar / daysWithData,
    };
  }

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    final weeklyAverages = _calculateWeeklyAverages();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Nutrition Analytics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Analytics'),
                Tab(text: 'Profile Analysis'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : TabBarView(
              controller: _tabController,
              children: [
                // Analytics Tab
                _buildAnalyticsTab(startOfWeek, weeklyAverages),
                // Profile Analysis Tab
                _buildProfileAnalysisTab(),
              ],
            ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          setState(() {
            _userProfile = UserProfile.fromMap(doc.data()!);
            _calculatedAnalysis = _calculateUserAnalysis(_userProfile!);
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Map<String, dynamic> _calculateUserAnalysis(UserProfile profile) {
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
    switch (profile.activityLevel.toLowerCase()) {
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extremely active':
        activityMultiplier = 1.9;
        break;
    }

    final dailyCalories = bmr * activityMultiplier;

    // Adjust for goals
    double targetCalories = dailyCalories;
    switch (profile.goal.toLowerCase()) {
      case 'lose weight':
        targetCalories *= 0.85; // 15% deficit
        break;
      case 'gain weight':
      case 'gain muscle':
        targetCalories *= 1.15; // 15% surplus
        break;
    }

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
      'healthConditions': profile.healthConditions,
      'allergies': profile.allergies,
    };
  }

  Widget _buildAnalyticsTab(DateTime startOfWeek, Map<String, dynamic> weeklyAverages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week Navigation
          _buildWeekNavigation(startOfWeek),
          const SizedBox(height: 24),

          // Weekly Summary Card
          _buildWeeklySummaryCard(weeklyAverages),
          const SizedBox(height: 24),

          // Daily Nutrition Chart
          _buildDailyNutritionChart(startOfWeek),
          const SizedBox(height: 24),

          // Nutrition Goals Progress
          _buildNutritionGoalsProgress(weeklyAverages),
          const SizedBox(height: 24),

          // Daily Breakdown
          _buildDailyBreakdown(startOfWeek),
        ],
      ),
    );
  }

  Widget _buildProfileAnalysisTab() {
    if (_userProfile == null || _calculatedAnalysis == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading your profile analysis...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final analysis = _calculatedAnalysis!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisCard('Personal Information', Icons.person, [
            'Age: ${analysis['age']} years',
            'Height: ${analysis['height']?.toStringAsFixed(1)} cm',
            'Weight: ${analysis['weight']?.toStringAsFixed(1)} kg',
            'Gender: ${analysis['gender']}',
            'BMI: ${analysis['bmi']?.toStringAsFixed(1)} (${analysis['weightCategory']})',
          ], Colors.blue),
          const SizedBox(height: 16),
          _buildAnalysisCard('Fitness Profile', Icons.fitness_center, [
            'Goal: ${analysis['goal']}',
            'Activity Level: ${analysis['activityLevel']}',
            'BMR: ${analysis['bmr']?.toStringAsFixed(0)} calories/day',
            'Daily Calorie Target: ${analysis['dailyCalories']?.toStringAsFixed(0)} calories',
          ], Colors.orange),
          const SizedBox(height: 16),
          _buildAnalysisCard('Nutritional Goals', Icons.restaurant_menu, [
            'Daily Calories: ${analysis['dailyCalories']?.toStringAsFixed(0)}',
            'Protein: ${analysis['protein']?.toStringAsFixed(1)}g',
            'Carbohydrates: ${analysis['carbs']?.toStringAsFixed(1)}g',
            'Fat: ${analysis['fat']?.toStringAsFixed(1)}g',
            'Fiber: ${analysis['fiber']?.toStringAsFixed(1)}g',
          ], Colors.green),
          const SizedBox(height: 16),
          if (analysis['healthConditions']?.isNotEmpty == true)
            _buildAnalysisCard(
              'Health Considerations',
              Icons.health_and_safety,
              (analysis['healthConditions'] as List<String>)
                  .where((condition) => condition != 'None')
                  .map((condition) => '• $condition')
                  .toList(),
              Colors.red,
            ),
          const SizedBox(height: 16),
          if (analysis['allergies']?.isNotEmpty == true)
            _buildAnalysisCard(
              'Allergies & Restrictions',
              Icons.warning,
              (analysis['allergies'] as List<String>)
                  .where((allergy) => allergy != 'None')
                  .map((allergy) => '• $allergy')
                  .toList(),
              Colors.amber,
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
    String title,
    IconData icon,
    List<String> items,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(item, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigation(DateTime startOfWeek) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border.all(
          color: Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: Colors.green[700],
              ),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
              _loadWeeklyNutrition();
            },
          ),
          ),
          Expanded(
            child: Text(
            '${_formatDisplayDate(startOfWeek)} - ${_formatDisplayDate(startOfWeek.add(const Duration(days: 6)))}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: Colors.green[700],
              ),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
              _loadWeeklyNutrition();
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard(Map<String, dynamic> averages) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Average',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNutritionMetric(
                    'Calories',
                    _toDouble(averages['calories']),
                    _nutritionGoals['calories']!,
                    'cal',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNutritionMetric(
                    'Protein',
                    _toDouble(averages['protein']),
                    _nutritionGoals['protein']!,
                    'g',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNutritionMetric(
                    'Carbs',
                    _toDouble(averages['carbs']),
                    _nutritionGoals['carbs']!,
                    'g',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNutritionMetric(
                    'Fat',
                    _toDouble(averages['fat']),
                    _nutritionGoals['fat']!,
                    'g',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionMetric(
    String label,
    double value,
    double goal,
    String unit,
    Color color,
  ) {
    final percentage = goal > 0 ? (value / goal * 100).clamp(0, 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} $unit',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        Text(
          '${percentage.toStringAsFixed(0)}% of goal',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildDailyNutritionChart(DateTime startOfWeek) {
    final chartData = <FlSpot>[];

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = _formatDate(date);
      final nutrition = _weeklyNutrition[dateKey] ?? _getEmptyNutrition();
      chartData.add(FlSpot(i.toDouble(), _toDouble(nutrition['calories'])));
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Calories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return Text(
                            dayNames[value.toInt()],
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionGoalsProgress(Map<String, dynamic> averages) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Goals Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            ..._nutritionGoals.entries.map((entry) {
              final nutrient = entry.key;
              final goal = entry.value;
              final actual = averages[nutrient] ?? 0;
              final percentage = goal > 0
                  ? (actual / goal * 100).clamp(0, 100)
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _capitalizeFirst(nutrient),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${actual.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: percentage >= 100
                                ? Colors.green
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 100 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdown(DateTime startOfWeek) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final dateKey = _formatDate(date);
              final nutrition =
                  _weeklyNutrition[dateKey] ?? _getEmptyNutrition();
              final isToday = date.isAtSameMomentAs(
                DateTime.now().subtract(
                  Duration(days: DateTime.now().weekday - date.weekday),
                ),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isToday ? Colors.green[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: Colors.green) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        _formatDisplayDate(date),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isToday ? Colors.green[800] : Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniMetric(
                            'Cal',
                            _toDouble(nutrition['calories']),
                            Colors.orange,
                          ),
                          _buildMiniMetric(
                            'P',
                            _toDouble(nutrition['protein']),
                            Colors.blue,
                          ),
                          _buildMiniMetric(
                            'C',
                            _toDouble(nutrition['carbs']),
                            Colors.green,
                          ),
                          _buildMiniMetric(
                            'F',
                            _toDouble(nutrition['fat']),
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
