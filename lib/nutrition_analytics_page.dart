import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class NutritionAnalyticsPage extends StatefulWidget {
  const NutritionAnalyticsPage({super.key});

  @override
  State<NutritionAnalyticsPage> createState() => _NutritionAnalyticsPageState();
}

class _NutritionAnalyticsPageState extends State<NutritionAnalyticsPage> {
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
    _loadWeeklyNutrition();
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

          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .doc(dateKey)
              .get();

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final meals = List<Map<String, dynamic>>.from(data['meals'] ?? []);
            _weeklyNutrition[dateKey] = _calculateDailyNutrition(meals);
          } else {
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
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      if (nutrition != null) {
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
      appBar: AppBar(
        title: const Text('Nutrition Analytics'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyNutrition,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : SingleChildScrollView(
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
            ),
    );
  }

  Widget _buildWeekNavigation(DateTime startOfWeek) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
              _loadWeeklyNutrition();
            },
          ),
          Text(
            '${_formatDisplayDate(startOfWeek)} - ${_formatDisplayDate(startOfWeek.add(const Duration(days: 6)))}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
              _loadWeeklyNutrition();
            },
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
