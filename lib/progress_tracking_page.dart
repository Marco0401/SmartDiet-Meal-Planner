import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProgressTrackingPage extends StatefulWidget {
  const ProgressTrackingPage({super.key});

  @override
  State<ProgressTrackingPage> createState() => _ProgressTrackingPageState();
}

class _ProgressTrackingPageState extends State<ProgressTrackingPage> {
  Map<String, dynamic> _weeklyProgress = {};
  Map<String, dynamic> _monthlyProgress = {};
  Map<String, dynamic> _userGoals = {};
  bool _isLoading = true;
  String? _error;
  int _selectedPeriod = 0; // 0: Week, 1: Month

  final List<String> _periods = ['This Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Load user goals from main user document (Account Settings data)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _userGoals = _calculateUserGoals(userData);
      } else {
        // Set default goals if no profile exists
        _userGoals = {
          'calories': 2000.0,
          'protein': 150.0,
          'carbs': 225.0,
          'fat': 67.0,
          'fiber': 25.0,
        };
      }

      // Load weekly progress
      await _loadWeeklyProgress(user.uid);
      
      // Load monthly progress
      await _loadMonthlyProgress(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateUserGoals(Map<String, dynamic> userData) {
    // Basic goal calculation based on user profile from Account Settings
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
        age = 25; // Default age
      }
    }

    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else if (gender == 'female') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    } else {
      // Use average for other genders
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
      dailyCalories *= 0.85; // 15% deficit
    } else if (goal.contains('Gain weight') || goal.contains('Build muscle')) {
      dailyCalories *= 1.15; // 15% surplus
    }
    // No adjustment for 'Maintain current weight' or 'Eat healthier'

    // Calculate macronutrient targets
    double proteinTarget;
    if (goal.contains('Build muscle')) {
      proteinTarget = weight * 2.4; // Higher protein for muscle building
    } else if (goal.contains('Lose weight')) {
      proteinTarget = weight * 2.0; // Higher protein for weight loss
    } else {
      proteinTarget = weight * 1.6; // Standard protein intake
    }

    return {
      'calories': dailyCalories,
      'protein': proteinTarget,
      'carbs': dailyCalories * 0.45 / 4, // 45% of calories from carbs
      'fat': dailyCalories * 0.25 / 9, // 25% of calories from fat
      'fiber': gender == 'male' ? 38.0 : 25.0,
      'water': weight * 35, // 35ml per kg body weight
    };
  }

  int? _calculateAge(dynamic birthday) {
    if (birthday == null) return null;
    DateTime birthDate;
    if (birthday is Timestamp) {
      birthDate = birthday.toDate();
    } else if (birthday is String) {
      birthDate = DateTime.tryParse(birthday) ?? DateTime.now();
    } else {
      return null;
    }
    return DateTime.now().difference(birthDate).inDays ~/ 365;
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) {
      final doubleValue = value.toDouble();
      return doubleValue.isFinite ? doubleValue : 0.0;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      return (parsed != null && parsed.isFinite) ? parsed : 0.0;
    }
    return 0.0;
  }

  Future<void> _loadWeeklyProgress(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    Map<String, double> weeklyTotals = {
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
    };

    int daysWithData = 0;

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      final mealsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .where('date', isEqualTo: dateKey)
          .get();

      print('DEBUG: Looking for meals on date: $dateKey');
      print('DEBUG: Found ${mealsQuery.docs.length} meals');

      if (mealsQuery.docs.isNotEmpty) {
        daysWithData++;
        for (final doc in mealsQuery.docs) {
          print('DEBUG: Meal data: ${doc.data()}');
          final docData = doc.data();
          
          // Check if this is the old format (meals array) or new format (individual meal)
          if (docData['meal_plans'] != null) {
            // Old format: meals stored as array
            final meals = docData['meal_plans'] as List<dynamic>? ?? [];
            for (final meal in meals) {
              final mealData = meal is Map<String, dynamic> ? meal : Map<String, dynamic>.from(meal as Map);
              final nutritionData = mealData['nutrition'];
              final nutrition = nutritionData is Map<String, dynamic> 
                  ? nutritionData 
                  : nutritionData is Map 
                      ? Map<String, dynamic>.from(nutritionData) 
                      : <String, dynamic>{};
              print('DEBUG: Old format nutrition data: $nutrition');
              
              final calories = nutrition['calories'];
              final protein = nutrition['protein'];
              final carbs = nutrition['carbs'];
              final fat = nutrition['fat'];
              final fiber = nutrition['fiber'];
              
              weeklyTotals['calories'] = (weeklyTotals['calories'] ?? 0) + _safeToDouble(calories);
              weeklyTotals['protein'] = (weeklyTotals['protein'] ?? 0) + _safeToDouble(protein);
              weeklyTotals['carbs'] = (weeklyTotals['carbs'] ?? 0) + _safeToDouble(carbs);
              weeklyTotals['fat'] = (weeklyTotals['fat'] ?? 0) + _safeToDouble(fat);
              weeklyTotals['fiber'] = (weeklyTotals['fiber'] ?? 0) + _safeToDouble(fiber);
            }
          } else {
            // New format: individual meal document
            final nutritionData = docData['nutrition'];
            final nutrition = nutritionData is Map<String, dynamic> 
                ? nutritionData 
                : nutritionData is Map 
                    ? Map<String, dynamic>.from(nutritionData) 
                    : <String, dynamic>{};
            print('DEBUG: New format nutrition data: $nutrition');
            
            final calories = nutrition['calories'];
            final protein = nutrition['protein'];
            final carbs = nutrition['carbs'];
            final fat = nutrition['fat'];
            final fiber = nutrition['fiber'];
            
            // Estimate fiber if missing (calories * 0.02)
            final fiberValue = fiber != null ? _safeToDouble(fiber) : (_safeToDouble(calories) * 0.02);
            
            print('DEBUG: Processing meal nutrition - fiber: $fiber (${fiber.runtimeType}), estimated: $fiberValue');
            
            weeklyTotals['calories'] = (weeklyTotals['calories'] ?? 0) + _safeToDouble(calories);
            weeklyTotals['protein'] = (weeklyTotals['protein'] ?? 0) + _safeToDouble(protein);
            weeklyTotals['carbs'] = (weeklyTotals['carbs'] ?? 0) + _safeToDouble(carbs);
            weeklyTotals['fat'] = (weeklyTotals['fat'] ?? 0) + _safeToDouble(fat);
            weeklyTotals['fiber'] = (weeklyTotals['fiber'] ?? 0) + fiberValue;
            
            print('DEBUG: Weekly fiber total so far: ${weeklyTotals['fiber']}');
          }
        }
      }
    }

    _weeklyProgress = {
      'totals': weeklyTotals,
      'averages': daysWithData > 0 ? {
        'calories': weeklyTotals['calories']! / daysWithData,
        'protein': weeklyTotals['protein']! / daysWithData,
        'carbs': weeklyTotals['carbs']! / daysWithData,
        'fat': weeklyTotals['fat']! / daysWithData,
        'fiber': weeklyTotals['fiber']! / daysWithData,
      } : {},
      'daysWithData': daysWithData,
      'goalAchievement': _calculateGoalAchievement(weeklyTotals, daysWithData),
    };
  }

  Future<void> _loadMonthlyProgress(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    
    Map<String, double> monthlyTotals = {
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
    };

    int daysWithData = 0;

    for (int i = 0; i < daysInMonth; i++) {
      final date = startOfMonth.add(Duration(days: i));
      if (date.isAfter(now)) break;
      
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      final mealsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .where('date', isEqualTo: dateKey)
          .get();

      if (mealsQuery.docs.isNotEmpty) {
        daysWithData++;
        for (final doc in mealsQuery.docs) {
          final docData = doc.data();
          
          // Check if this is the old format (meals array) or new format (individual meal)
          if (docData['meal_plans'] != null) {
            // Old format: meals stored as array
            final meals = docData['meal_plans'] as List<dynamic>? ?? [];
            for (final meal in meals) {
              final mealData = meal is Map<String, dynamic> ? meal : Map<String, dynamic>.from(meal as Map);
              final nutritionData = mealData['nutrition'];
              final nutrition = nutritionData is Map<String, dynamic> 
                  ? nutritionData 
                  : nutritionData is Map 
                      ? Map<String, dynamic>.from(nutritionData) 
                      : <String, dynamic>{};
              
              final calories = nutrition['calories'];
              final protein = nutrition['protein'];
              final carbs = nutrition['carbs'];
              final fat = nutrition['fat'];
              final fiber = nutrition['fiber'];
              
              monthlyTotals['calories'] = (monthlyTotals['calories'] ?? 0) + _safeToDouble(calories);
              monthlyTotals['protein'] = (monthlyTotals['protein'] ?? 0) + _safeToDouble(protein);
              monthlyTotals['carbs'] = (monthlyTotals['carbs'] ?? 0) + _safeToDouble(carbs);
              monthlyTotals['fat'] = (monthlyTotals['fat'] ?? 0) + _safeToDouble(fat);
              monthlyTotals['fiber'] = (monthlyTotals['fiber'] ?? 0) + _safeToDouble(fiber);
            }
          } else {
            // New format: individual meal document
            final nutritionData = docData['nutrition'];
            final nutrition = nutritionData is Map<String, dynamic> 
                ? nutritionData 
                : nutritionData is Map 
                    ? Map<String, dynamic>.from(nutritionData) 
                    : <String, dynamic>{};
            
            final calories = nutrition['calories'];
            final protein = nutrition['protein'];
            final carbs = nutrition['carbs'];
            final fat = nutrition['fat'];
            final fiber = nutrition['fiber'];
            
            // Estimate fiber if missing (calories * 0.02)
            final fiberValue = fiber != null ? _safeToDouble(fiber) : (_safeToDouble(calories) * 0.02);
            
            monthlyTotals['calories'] = (monthlyTotals['calories'] ?? 0) + _safeToDouble(calories);
            monthlyTotals['protein'] = (monthlyTotals['protein'] ?? 0) + _safeToDouble(protein);
            monthlyTotals['carbs'] = (monthlyTotals['carbs'] ?? 0) + _safeToDouble(carbs);
            monthlyTotals['fat'] = (monthlyTotals['fat'] ?? 0) + _safeToDouble(fat);
            monthlyTotals['fiber'] = (monthlyTotals['fiber'] ?? 0) + fiberValue;
          }
        }
      }
    }

    _monthlyProgress = {
      'totals': monthlyTotals,
      'averages': daysWithData > 0 ? {
        'calories': monthlyTotals['calories']! / daysWithData,
        'protein': monthlyTotals['protein']! / daysWithData,
        'carbs': monthlyTotals['carbs']! / daysWithData,
        'fat': monthlyTotals['fat']! / daysWithData,
        'fiber': monthlyTotals['fiber']! / daysWithData,
      } : {},
      'daysWithData': daysWithData,
      'goalAchievement': _calculateGoalAchievement(monthlyTotals, daysWithData),
    };
  }

  Map<String, double> _calculateGoalAchievement(Map<String, double> totals, int daysWithData) {
    if (daysWithData == 0 || _userGoals.isEmpty) return {};
    
    final averages = {
      'calories': totals['calories']! / daysWithData,
      'protein': totals['protein']! / daysWithData,
      'carbs': totals['carbs']! / daysWithData,
      'fat': totals['fat']! / daysWithData,
      'fiber': totals['fiber']! / daysWithData,
    };

    return {
      'calories': (averages['calories']! / _userGoals['calories']) * 100,
      'protein': (averages['protein']! / _userGoals['protein']) * 100,
      'carbs': (averages['carbs']! / _userGoals['carbs']) * 100,
      'fat': (averages['fat']! / _userGoals['fat']) * 100,
      'fiber': (averages['fiber']! / _userGoals['fiber']) * 100,
    };
  }

  @override
  Widget build(BuildContext context) {
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
              'Progress Tracking',
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
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                  ),
                  onPressed: _loadProgressData,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProgressData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Selection
                      Card(
                        elevation: 8,
                        shadowColor: Colors.green.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
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
                            border: Border.all(
                              color: Colors.green[200]!,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Text(
                                  'Time Period:',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SegmentedButton<int>(
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return Colors.green[600]!;
                                        }
                                        return Colors.green[100]!;
                                      }),
                                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                        if (states.contains(WidgetState.selected)) {
                                          return Colors.white;
                                        }
                                        return Colors.green[700]!;
                                      }),
                                    ),
                                    segments: _periods.asMap().entries.map((entry) {
                                      return ButtonSegment<int>(
                                        value: entry.key,
                                        label: Text(entry.value),
                                      );
                                    }).toList(),
                                    selected: {_selectedPeriod},
                                    onSelectionChanged: (Set<int> newSelection) {
                                      setState(() {
                                        _selectedPeriod = newSelection.first;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Goal Achievement Overview
                      _buildGoalAchievementCard(),
                      const SizedBox(height: 16),

                      // Progress Charts
                      _buildProgressChartsCard(),
                      const SizedBox(height: 16),

                      // Detailed Statistics
                      _buildDetailedStatsCard(),
                      const SizedBox(height: 16),

                      // Insights and Recommendations
                      _buildInsightsCard(),
                      const SizedBox(height: 16),

                      // Streak and Consistency
                      _buildConsistencyCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGoalAchievementCard() {
    final progress = _selectedPeriod == 0 ? _weeklyProgress : _monthlyProgress;
    final achievements = progress['goalAchievement'] as Map<String, double>? ?? {};
    
    if (achievements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.track_changes, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available for goal tracking',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Achievement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            ...achievements.entries.map((entry) {
              final percentage = entry.value.clamp(0.0, 150.0);
              final color = _getAchievementColor(percentage);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getNutrientDisplayName(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

  Widget _buildProgressChartsCard() {
    final progress = _selectedPeriod == 0 ? _weeklyProgress : _monthlyProgress;
    final averagesRaw = progress['averages'] as Map<dynamic, dynamic>? ?? {};
    final averages = <String, double>{};
    
    // Safely convert dynamic map to String, double map
    averagesRaw.forEach((key, value) {
      if (key is String && value is num) {
        final doubleValue = value.toDouble();
        if (!doubleValue.isNaN && doubleValue.isFinite) {
          averages[key] = doubleValue;
        }
      }
    });
    
    if (averages.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No chart data available'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(averages),
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> averages) {
    final protein = averages['protein'] ?? 0.0;
    final carbs = averages['carbs'] ?? 0.0;
    final fat = averages['fat'] ?? 0.0;
    
    final total = protein * 4 + carbs * 4 + fat * 9;
    
    // Prevent division by zero and NaN values
    if (total <= 0 || total.isNaN || !total.isFinite) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'No Data',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ];
    }
    
    final proteinPercent = (protein * 4 / total) * 100;
    final carbsPercent = (carbs * 4 / total) * 100;
    final fatPercent = (fat * 9 / total) * 100;
    
    return [
      PieChartSectionData(
        color: Colors.blue,
        value: proteinPercent.isFinite ? proteinPercent : 0,
        title: 'Protein\n${proteinPercent.isFinite ? proteinPercent.toStringAsFixed(0) : '0'}%',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.green,
        value: carbsPercent.isFinite ? carbsPercent : 0,
        title: 'Carbs\n${carbsPercent.isFinite ? carbsPercent.toStringAsFixed(0) : '0'}%',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: fatPercent.isFinite ? fatPercent : 0,
        title: 'Fat\n${fatPercent.isFinite ? fatPercent.toStringAsFixed(0) : '0'}%',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  Widget _buildDetailedStatsCard() {
    final progress = _selectedPeriod == 0 ? _weeklyProgress : _monthlyProgress;
    final averagesRaw = progress['averages'] as Map<dynamic, dynamic>? ?? {};
    final averages = <String, double>{};
    
    // Safely convert dynamic map to String, double map
    averagesRaw.forEach((key, value) {
      if (key is String && value is num) {
        final doubleValue = value.toDouble();
        if (!doubleValue.isNaN && doubleValue.isFinite) {
          averages[key] = doubleValue;
        }
      }
    });
    
    final daysWithData = progress['daysWithData'] as int? ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Days with data', '$daysWithData'),
            const Divider(),
            if (averages.isNotEmpty) ...[
              _buildStatRow('Avg. Calories', '${averages['calories']?.toStringAsFixed(0)} cal'),
              _buildStatRow('Avg. Protein', '${averages['protein']?.toStringAsFixed(1)} g'),
              _buildStatRow('Avg. Carbs', '${averages['carbs']?.toStringAsFixed(1)} g'),
              _buildStatRow('Avg. Fat', '${averages['fat']?.toStringAsFixed(1)} g'),
              _buildStatRow('Avg. Fiber', '${averages['fiber']?.toStringAsFixed(1)} g'),
            ] else
              const Text('No nutrition data available'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Color _getAchievementColor(double percentage) {
    if (percentage >= 90 && percentage <= 110) {
      return Colors.green;
    } else if (percentage >= 80 && percentage <= 120) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getNutrientDisplayName(String nutrient) {
    switch (nutrient) {
      case 'calories': return 'Calories';
      case 'protein': return 'Protein';
      case 'carbs': return 'Carbohydrates';
      case 'fat': return 'Fat';
      case 'fiber': return 'Fiber';
      default: return nutrient;
    }
  }

  Widget _buildInsightsCard() {
    final progress = _selectedPeriod == 0 ? _weeklyProgress : _monthlyProgress;
    final achievements = progress['goalAchievement'] as Map<String, double>? ?? {};
    final daysWithData = progress['daysWithData'] as int? ?? 0;
    
    List<String> insights = [];
    List<String> recommendations = [];
    
    if (daysWithData == 0) {
      insights.add('No meal data available for analysis.');
      recommendations.add('Start logging your meals to get personalized insights.');
    } else {
      // Analyze goal achievements
      achievements.forEach((nutrient, percentage) {
        if (percentage < 80) {
          insights.add('You\'re consuming ${percentage.toStringAsFixed(0)}% of your ${_getNutrientDisplayName(nutrient).toLowerCase()} goal.');
          if (nutrient == 'protein') {
            recommendations.add('Add more protein-rich foods like lean meats, eggs, or legumes.');
          } else if (nutrient == 'fiber') {
            recommendations.add('Include more fruits, vegetables, and whole grains for fiber.');
          } else if (nutrient == 'calories' && percentage < 70) {
            recommendations.add('Consider eating more nutrient-dense foods to meet your calorie needs.');
          }
        } else if (percentage > 120) {
          insights.add('You\'re exceeding your ${_getNutrientDisplayName(nutrient).toLowerCase()} goal by ${(percentage - 100).toStringAsFixed(0)}%.');
          if (nutrient == 'calories') {
            recommendations.add('Consider portion control or more physical activity.');
          } else if (nutrient == 'fat') {
            recommendations.add('Try reducing high-fat foods and cooking methods.');
          }
        }
      });
      
      // Consistency insights
      final periodDays = _selectedPeriod == 0 ? 7 : DateTime.now().day;
      final consistencyRate = (daysWithData / periodDays) * 100;
      
      if (consistencyRate < 50) {
        insights.add('You\'ve logged meals on ${consistencyRate.toStringAsFixed(0)}% of days.');
        recommendations.add('Try to log meals more consistently for better tracking.');
      } else if (consistencyRate >= 80) {
        insights.add('Great job! You\'ve been consistent with meal logging.');
      }
      
      // Default positive message if no issues
      if (insights.isEmpty) {
        insights.add('You\'re doing well with your nutrition goals!');
        recommendations.add('Keep up the great work with balanced eating.');
      }
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Insights & Recommendations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Insights section
            Text(
              'Key Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight)),
                ],
              ),
            )),
            
            const SizedBox(height: 16),
            
            // Recommendations section
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 8),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyCard() {
    final progress = _selectedPeriod == 0 ? _weeklyProgress : _monthlyProgress;
    final daysWithData = progress['daysWithData'] as int? ?? 0;
    final periodDays = _selectedPeriod == 0 ? 7 : DateTime.now().day;
    final consistencyRate = daysWithData > 0 ? (daysWithData / periodDays) * 100 : 0.0;
    
    Color consistencyColor;
    String consistencyLabel;
    IconData consistencyIcon;
    
    if (consistencyRate >= 80) {
      consistencyColor = Colors.green;
      consistencyLabel = 'Excellent';
      consistencyIcon = Icons.emoji_events;
    } else if (consistencyRate >= 60) {
      consistencyColor = Colors.orange;
      consistencyLabel = 'Good';
      consistencyIcon = Icons.thumb_up;
    } else if (consistencyRate >= 40) {
      consistencyColor = Colors.amber;
      consistencyLabel = 'Fair';
      consistencyIcon = Icons.trending_up;
    } else {
      consistencyColor = Colors.red;
      consistencyLabel = 'Needs Improvement';
      consistencyIcon = Icons.flag;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Consistency Tracking',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Consistency rate display
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meal Logging Consistency',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(consistencyIcon, color: consistencyColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$consistencyLabel (${consistencyRate.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              color: consistencyColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: consistencyRate / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(consistencyColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$daysWithData out of $periodDays days logged',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Streak information (simplified)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Streak',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          '$daysWithData days of meal logging',
                          style: TextStyle(color: Colors.green[700]),
                        ),
                      ],
                    ),
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
