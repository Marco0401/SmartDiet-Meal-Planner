import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';

class GoalProgressSummaryPage extends StatefulWidget {
  const GoalProgressSummaryPage({super.key});

  @override
  State<GoalProgressSummaryPage> createState() => _GoalProgressSummaryPageState();
}

class _GoalProgressSummaryPageState extends State<GoalProgressSummaryPage> {
  late ConfettiController _confettiController;
  bool _isLoading = true;
  
  // Progress data
  double? _startWeight;
  double? _currentWeight;
  double? _weightChange;
  int? _durationDays;
  DateTime? _startDate;
  List<Map<String, dynamic>> _topMeals = [];
  Map<String, double> _nutritionStats = {};
  List<FlSpot> _weightChartData = [];
  String? _goalType;
  List<String> _achievedBadges = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    _loadProgressData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _startWeight = data['initialWeight']?.toDouble();
        _currentWeight = data['weight']?.toDouble();
        _goalType = data['goal'];
        
        if (data['goalStartDate'] != null) {
          _startDate = DateTime.tryParse(data['goalStartDate']);
          if (_startDate != null) {
            _durationDays = DateTime.now().difference(_startDate!).inDays;
          }
        }

        if (_startWeight != null && _currentWeight != null) {
          _weightChange = _currentWeight! - _startWeight!;
        }

        // Load weight history for chart
        await _loadWeightHistory(user.uid);
        
        // Load top meals
        await _loadTopMeals(user.uid);
        
        // Load nutrition stats
        await _loadNutritionStats(user.uid);
        
        // Calculate achievement badges
        _calculateBadges();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading progress data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeightHistory(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('weightHistory')
          .orderBy('date')
          .get();

      final spots = <FlSpot>[];
      
      // Add initial weight as first data point if available
      if (_startWeight != null && _startDate != null) {
        spots.add(FlSpot(0, _startWeight!));
      }
      
      for (var i = 0; i < snapshot.docs.length; i++) {
        final data = snapshot.docs[i].data();
        final weight = data['weight']?.toDouble();
        if (weight != null) {
          spots.add(FlSpot((i + 1).toDouble(), weight));
        }
      }
      
      // If we only have one data point, add current weight as second point
      if (spots.length == 1 && _currentWeight != null && _currentWeight != _startWeight) {
        spots.add(FlSpot(1, _currentWeight!));
      }

      setState(() {
        _weightChartData = spots;
      });
    } catch (e) {
      print('Error loading weight history: $e');
    }
  }

  Future<void> _loadTopMeals(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .get();

      final mealCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final title = doc.data()['title'] as String?;
        if (title != null) {
          mealCounts[title] = (mealCounts[title] ?? 0) + 1;
        }
      }

      final sortedMeals = mealCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _topMeals = sortedMeals.take(5).map((e) => {
          'title': e.key,
          'count': e.value,
        }).toList();
      });
    } catch (e) {
      print('Error loading top meals: $e');
    }
  }

  Future<void> _loadNutritionStats(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('meal_plans')
          .get();

      double totalCalories = 0;
      double totalProtein = 0;
      double totalFiber = 0;
      int count = 0;

      for (final doc in snapshot.docs) {
        final nutrition = doc.data()['nutrition'] as Map<String, dynamic>?;
        if (nutrition != null) {
          totalCalories += (nutrition['calories'] ?? 0).toDouble();
          totalProtein += (nutrition['protein'] ?? 0).toDouble();
          totalFiber += (nutrition['fiber'] ?? 0).toDouble();
          count++;
        }
      }

      if (count > 0) {
        setState(() {
          _nutritionStats = {
            'avgCalories': totalCalories / count,
            'avgProtein': totalProtein / count,
            'avgFiber': totalFiber / count,
            'mealsLogged': count.toDouble(),
          };
        });
      }
    } catch (e) {
      print('Error loading nutrition stats: $e');
    }
  }

  void _calculateBadges() {
    _achievedBadges.clear();
    
    // Weight loss milestones
    if (_weightChange != null && _weightChange! < 0) {
      final lossAmount = _weightChange!.abs();
      if (lossAmount >= 10) _achievedBadges.add('🏆 10kg Champion');
      else if (lossAmount >= 5) _achievedBadges.add('🥇 5kg Achiever');
      else if (lossAmount >= 2) _achievedBadges.add('🥈 2kg Starter');
    }
    
    // Duration milestones
    if (_durationDays != null) {
      if (_durationDays! >= 90) _achievedBadges.add('⏰ 90-Day Warrior');
      else if (_durationDays! >= 30) _achievedBadges.add('📅 30-Day Streak');
      else if (_durationDays! >= 7) _achievedBadges.add('🌟 Week One');
    }
    
    // Meal logging consistency
    final mealsLogged = _nutritionStats['mealsLogged']?.toInt() ?? 0;
    if (mealsLogged >= 100) _achievedBadges.add('🍽️ Century Club');
    else if (mealsLogged >= 50) _achievedBadges.add('📝 Consistent Logger');
    else if (mealsLogged >= 20) _achievedBadges.add('✍️ Getting Started');
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Success is the sum of small efforts repeated day in and day out.',
      'The only bad workout is the one that didn\'t happen.',
      'Your body can stand almost anything. It\'s your mind you have to convince.',
      'Don\'t wish for it, work for it.',
      'The difference between try and triumph is a little umph.',
      'Believe in yourself and all that you are.',
    ];
    return quotes[DateTime.now().millisecond % quotes.length];
  }

  String _getGoalMessage() {
    if (_goalType == null) return 'You\'ve reached your goal!';
    
    switch (_goalType!.toLowerCase()) {
      case 'lose weight':
        return 'You\'ve crushed your weight loss goal!';
      case 'gain weight':
        return 'You\'ve achieved your weight gain goal!';
      case 'maintain weight':
        return 'You\'ve successfully maintained your weight!';
      default:
        return 'You\'ve reached your goal!';
    }
  }

  void _shareProgress() {
    final weightChangeText = _weightChange != null 
        ? '${_weightChange!.abs().toStringAsFixed(1)} kg ${_weightChange! < 0 ? 'lost' : 'gained'}'
        : 'my goal';
    
    final durationText = _durationDays != null 
        ? 'in $_durationDays days'
        : '';
    
    final shareText = '''
🎉 I reached my fitness goal! 🎉

${_getGoalMessage()}

📊 Progress: $weightChangeText $durationText
🍽️ Meals logged: ${_nutritionStats['mealsLogged']?.toStringAsFixed(0) ?? '--'}
💪 Avg protein: ${_nutritionStats['avgProtein']?.toStringAsFixed(1) ?? '--'}g per meal

Keep pushing towards your goals! 💚
''';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Progress Summary'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareProgress,
            tooltip: 'Share Progress',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildCelebrationHeader(),
                      const SizedBox(height: 20),
                      _buildMotivationalQuoteCard(),
                      const SizedBox(height: 16),
                      if (_achievedBadges.isNotEmpty) ...[
                        _buildBadgesCard(),
                        const SizedBox(height: 16),
                      ],
                      _buildProgressSummaryCard(),
                      const SizedBox(height: 16),
                      _buildWeightChartCard(),
                      const SizedBox(height: 16),
                      _buildTopMealsCard(),
                      const SizedBox(height: 16),
                      _buildNutritionInsightsCard(),
                      const SizedBox(height: 16),
                      _buildNextGoalButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple,
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCelebrationHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Icon(
            Icons.emoji_events,
            size: 80,
            color: Colors.amber[300],
          ),
          const SizedBox(height: 16),
          const Text(
            '🎉 Congratulations!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getGoalMessage(),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_down, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Your Journey',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatRow('Start Weight', '${_startWeight?.toStringAsFixed(1) ?? '--'} kg'),
            const Divider(),
            _buildStatRow('Current Weight', '${_currentWeight?.toStringAsFixed(1) ?? '--'} kg'),
            const Divider(),
            _buildStatRow(
              'Weight Change',
              '${_weightChange != null ? (_weightChange! > 0 ? '+' : '') : ''}${_weightChange?.toStringAsFixed(1) ?? '--'} kg',
              color: _weightChange != null && _weightChange! < 0 ? Colors.green : Colors.blue,
            ),
            const Divider(),
            _buildStatRow('Duration', '${_durationDays ?? '--'} days'),
            if (_durationDays != null && _weightChange != null)
              ...[
                const Divider(),
                _buildStatRow(
                  'Avg per Week',
                  '${(_weightChange! / (_durationDays! / 7)).toStringAsFixed(2)} kg',
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChartCard() {
    if (_weightChartData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate min and max for better chart scaling
    final weights = _weightChartData.map((spot) => spot.y).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final padding = (maxWeight - minWeight) * 0.1; // 10% padding

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Weight Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_weightChartData.length} data point${_weightChartData.length > 1 ? 's' : ''} recorded',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: minWeight - padding,
                  maxY: maxWeight + padding,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}kg',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('Start', style: TextStyle(fontSize: 10));
                          if (value == _weightChartData.length - 1) return const Text('Now', style: TextStyle(fontSize: 10));
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _weightChartData,
                      isCurved: true,
                      color: _weightChange != null && _weightChange! < 0 ? Colors.green : Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: _weightChange != null && _weightChange! < 0 ? Colors.green : Colors.blue,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (_weightChange != null && _weightChange! < 0 ? Colors.green : Colors.blue).withOpacity(0.1),
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

  Widget _buildTopMealsCard() {
    if (_topMeals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Top 5 Meals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._topMeals.asMap().entries.map((entry) {
              final index = entry.key;
              final meal = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        meal['title'],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      '${meal['count']}x',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
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

  Widget _buildNutritionInsightsCard() {
    if (_nutritionStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Nutrition Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInsightRow(
              Icons.local_fire_department,
              'Avg Calories',
              '${_nutritionStats['avgCalories']?.toStringAsFixed(0) ?? '--'} kcal',
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              Icons.fitness_center,
              'Avg Protein',
              '${_nutritionStats['avgProtein']?.toStringAsFixed(1) ?? '--'} g',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              Icons.grass,
              'Avg Fiber',
              '${_nutritionStats['avgFiber']?.toStringAsFixed(1) ?? '--'} g',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              Icons.restaurant_menu,
              'Meals Logged',
              '${_nutritionStats['mealsLogged']?.toStringAsFixed(0) ?? '--'}',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalQuoteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.format_quote,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getMotivationalQuote(),
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Achievement Badges',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _achievedBadges.map((badge) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber[100]!, Colors.orange[100]!],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber[700]!, width: 2),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextGoalButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          // Navigate to account settings where users can update their goal
          Navigator.pushNamed(context, '/account_settings');
        },
        icon: const Icon(Icons.flag, size: 24),
        label: const Text(
          'Set New Goal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
