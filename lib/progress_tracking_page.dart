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

      // Load user goals
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _userGoals = _calculateUserGoals(userData);
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
    // Basic goal calculation based on user profile
    final weight = userData['weight']?.toDouble() ?? 70.0;
    final height = userData['height']?.toDouble() ?? 170.0;
    final age = _calculateAge(userData['birthday']) ?? 25;
    final gender = userData['gender'] ?? 'Other';
    final activityLevel = userData['activityLevel'] ?? 'Moderately active';
    final goal = userData['goal'] ?? 'Maintain current weight';

    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'Male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Activity multipliers
    double activityMultiplier = 1.2;
    if (activityLevel.contains('Lightly active')) {
      activityMultiplier = 1.375;
    } else if (activityLevel.contains('Moderately active')) {
      activityMultiplier = 1.55;
    } else if (activityLevel.contains('Very active')) {
      activityMultiplier = 1.725;
    } else if (activityLevel.contains('Extremely active')) {
      activityMultiplier = 1.9;
    }

    double dailyCalories = bmr * activityMultiplier;

    // Adjust based on goal
    if (goal.contains('Lose weight')) {
      dailyCalories *= 0.85; // 15% deficit
    } else if (goal.contains('Gain weight') || goal.contains('Build muscle')) {
      dailyCalories *= 1.15; // 15% surplus
    }

    return {
      'calories': dailyCalories,
      'protein': weight * 2.2, // 2.2g per kg body weight
      'carbs': dailyCalories * 0.45 / 4, // 45% of calories from carbs
      'fat': dailyCalories * 0.25 / 9, // 25% of calories from fat
      'fiber': gender == 'Male' ? 38.0 : 25.0,
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
          .collection('meals')
          .where('date', isEqualTo: dateKey)
          .get();

      if (mealsQuery.docs.isNotEmpty) {
        daysWithData++;
        for (final doc in mealsQuery.docs) {
          final nutrition = doc.data()['nutrition'] as Map<String, dynamic>? ?? {};
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
          .collection('meals')
          .where('date', isEqualTo: dateKey)
          .get();

      if (mealsQuery.docs.isNotEmpty) {
        daysWithData++;
        for (final doc in mealsQuery.docs) {
          final nutrition = doc.data()['nutrition'] as Map<String, dynamic>? ?? {};
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
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                'Time Period:',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SegmentedButton<int>(
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
                      const SizedBox(height: 16),

                      // Goal Achievement Overview
                      _buildGoalAchievementCard(),
                      const SizedBox(height: 16),

                      // Progress Charts
                      _buildProgressChartsCard(),
                      const SizedBox(height: 16),

                      // Detailed Statistics
                      _buildDetailedStatsCard(),
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
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(averages),
                  centerSpaceRadius: 40,
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
}
