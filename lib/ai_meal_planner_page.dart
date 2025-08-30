import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/ai_meal_planner_service.dart';
import 'recipe_detail_page.dart';
import 'ai_meal_planner_demo_page.dart';

class AIMealPlannerPage extends StatefulWidget {
  const AIMealPlannerPage({super.key});

  @override
  State<AIMealPlannerPage> createState() => _AIMealPlannerPageState();
}

class _AIMealPlannerPageState extends State<AIMealPlannerPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _mealPlanData;
  bool _isLoading = false;
  String? _error;
  int _selectedDays = 7;
  String? _selectedGoal;
  late TabController _tabController;

  final List<int> _dayOptions = [3, 5, 7, 14];
  final List<String> _goalOptions = [
    'Lose weight',
    'Gain weight',
    'Maintain current weight',
    'Build muscle',
    'Eat healthier / clean eating',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateMealPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateMealPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print(
        'Generating meal plan for $_selectedDays days with goal: $_selectedGoal',
      );

      final mealPlanData =
          await AIMealPlannerService.generatePersonalizedMealPlan(
            days: _selectedDays,
            specificGoal: _selectedGoal,
          );

      print('Received meal plan data: $mealPlanData');
      print('Meal plan keys: ${mealPlanData.keys.toList()}');

      if (mealPlanData['mealPlan'] != null) {
        final mealPlan = mealPlanData['mealPlan'] as Map<String, dynamic>;
        print('Meal plan days: ${mealPlan.keys.toList()}');
      }

      setState(() {
        _mealPlanData = mealPlanData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating meal plan: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      return userData['fullName'] != null &&
          userData['fullName'].toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return const AIMealPlannerDemoPage();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Meal Planner'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Meal Plan'),
                Tab(text: 'Analysis'),
                Tab(text: 'Recommendations'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Control Panel
              _buildControlPanel(),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMealPlanTab(),
                    _buildAnalysisTab(),
                    _buildRecommendationsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Use responsive layout for smaller screens
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Wide screen - side by side
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Plan Duration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _selectedDays,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _dayOptions.map((days) {
                              return DropdownMenuItem(
                                value: days,
                                child: Text('$days days'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDays = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Specific Goal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedGoal,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintText: 'Auto-detect',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Auto-detect'),
                              ),
                              ..._goalOptions.map((goal) {
                                return DropdownMenuItem(
                                  value: goal,
                                  child: Text(goal),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGoal = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Narrow screen - stacked
                return Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan Duration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedDays,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _dayOptions.map((days) {
                            return DropdownMenuItem(
                              value: days,
                              child: Text('$days days'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDays = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Specific Goal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedGoal,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: 'Auto-detect',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Auto-detect'),
                            ),
                            ..._goalOptions.map((goal) {
                              return DropdownMenuItem(
                                value: goal,
                                child: Text(goal),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedGoal = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          // Recipe source info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uses AI-generated recipes when available, falls back to curated local recipes if API is limited',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateMealPlan,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isLoading ? 'Generating...' : 'Generate New Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: TextStyle(color: Colors.red[700], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateMealPlan,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_mealPlanData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No meal plan generated yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Click "Generate New Plan" to get started!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Debug: Print the meal plan data structure
    print('Meal Plan Data: $_mealPlanData');
    print('Meal Plan Data Keys: ${_mealPlanData!.keys.toList()}');

    // Try different possible meal plan structures
    Map<String, dynamic>? mealPlan;

    // Check if mealPlan key exists
    if (_mealPlanData!.containsKey('mealPlan')) {
      mealPlan = _mealPlanData!['mealPlan'] as Map<String, dynamic>?;
      print('Found mealPlan key: ${mealPlan?.keys.toList()}');
    }
    // Check if days key exists (alternative structure)
    else if (_mealPlanData!.containsKey('days')) {
      mealPlan = _mealPlanData!['days'] as Map<String, dynamic>?;
      print('Found days key: ${mealPlan?.keys.toList()}');
    }
    // Check if the data itself is the meal plan
    else {
      // Look for any key that might contain day data
      for (String key in _mealPlanData!.keys) {
        if (key.contains('day') ||
            key.contains('Day') ||
            key.contains('1') ||
            key.contains('2')) {
          print('Found potential day key: $key');
          mealPlan = {key: _mealPlanData![key]};
          break;
        }
      }
    }

    if (mealPlan == null || mealPlan.isEmpty) {
      print('No meal plan structure found, using fallback');

      // Show debug information about what we received
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug: Data Structure Received',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Keys: ${_mealPlanData!.keys.toList()}'),
                    const SizedBox(height: 8),
                    const Text('Data Preview:'),
                    Text(
                      _mealPlanData.toString().substring(
                        0,
                        _mealPlanData.toString().length > 500
                            ? 500
                            : _mealPlanData.toString().length,
                      ),
                    ),
                    if (_mealPlanData.toString().length > 500)
                      const Text('... (truncated)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fallback Meal Plan (Generated Locally)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Generate a simple fallback meal plan for testing
            ...List.generate(_selectedDays, (index) {
              final dayData = _generateFallbackMealPlan()[index];
              final dayNumber = index + 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildDayMealPlan(dayNumber, dayData),
              );
            }),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mealPlan!.length,
      itemBuilder: (context, index) {
        final dayKey = mealPlan!.keys.elementAt(index);
        final dayData = mealPlan![dayKey] as Map<String, dynamic>;
        final dayNumber = index + 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildDayMealPlan(dayNumber, dayData),
        );
      },
    );
  }

  Widget _buildDayMealPlan(int dayNumber, Map<String, dynamic> dayData) {
    // Safely extract data with null checks
    final meals = dayData['meals'] as Map<String, dynamic>? ?? {};
    final totalCalories = dayData['totalCalories']?.toDouble() ?? 0;
    final nutritionalSummary =
        dayData['nutritionalSummary'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $dayNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${totalCalories.toStringAsFixed(0)} calories',
                      style: TextStyle(color: Colors.green[700], fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (nutritionalSummary != null)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showNutritionalInfo(nutritionalSummary),
                  tooltip: 'View nutritional summary',
                ),
            ],
          ),
        ),

        // Meals - safely handle empty meals
        if (meals.isNotEmpty)
          ...meals.entries.map((entry) {
            final mealType = entry.key;
            final mealData = entry.value as Map<String, dynamic>? ?? {};
            return _buildMealTile(mealType, mealData);
          }).toList()
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No meals planned for this day',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildMealTile(String mealType, Map<String, dynamic> mealData) {
    // Safely extract recipe data with null checks
    final recipe = mealData['recipe'] as Map<String, dynamic>? ?? {};
    final estimatedCalories = mealData['estimatedCalories']?.toDouble() ?? 0;
    final portionSize = mealData['portionSize']?.toDouble() ?? 1.0;

    // Generate a more descriptive meal title if it's generic
    String mealTitle = recipe['title']?.toString() ?? 'Unknown Recipe';
    String mealDescription = recipe['description']?.toString() ?? '';

    // If the title is generic, make it more specific based on meal type
    if (mealTitle.toLowerCase().contains('breakfast') ||
        mealTitle.toLowerCase().contains('porridge')) {
      mealTitle = 'Healthy Breakfast Bowl';
      mealDescription =
          'A balanced breakfast with protein, whole grains, and fruits';
    } else if (mealTitle.toLowerCase().contains('lunch') ||
        mealTitle.toLowerCase().contains('plate')) {
      mealTitle = 'Nutritious Lunch Plate';
      mealDescription = 'A wholesome lunch with lean protein and vegetables';
    } else if (mealTitle.toLowerCase().contains('dinner') ||
        mealTitle.toLowerCase().contains('balanced')) {
      mealTitle = 'Balanced Dinner';
      mealDescription =
          'A complete dinner with protein, complex carbs, and vegetables';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: _getMealTypeColor(mealType),
        child: Icon(_getMealTypeIcon(mealType), color: Colors.white),
      ),
      title: Text(
        mealTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mealDescription.isNotEmpty)
            Text(
              mealDescription,
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${estimatedCalories.toStringAsFixed(0)} cal',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (portionSize != 1.0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Portion: ${portionSize.toStringAsFixed(1)}x',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Show recipe source indicator
          Row(
            children: [
              Icon(
                recipe['id']?.toString().startsWith('local_') == true
                    ? Icons.storage
                    : Icons.cloud,
                size: 12,
                color: recipe['id']?.toString().startsWith('local_') == true
                    ? Colors.blue
                    : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                recipe['id']?.toString().startsWith('local_') == true
                    ? 'Local Recipe'
                    : 'AI Generated',
                style: TextStyle(
                  color: recipe['id']?.toString().startsWith('local_') == true
                      ? Colors.blue
                      : Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios),
        onPressed: () => _viewRecipeDetails(recipe),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_mealPlanData == null) {
      return const Center(
        child: Text('Generate a meal plan to see your analysis.'),
      );
    }

    final userAnalysis = _mealPlanData!['userAnalysis'] as Map<String, dynamic>;
    final nutritionalGoals =
        _mealPlanData!['nutritionalGoals'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisCard('Personal Information', Icons.person, [
            'Age: ${userAnalysis['age']} years',
            'Height: ${userAnalysis['height']?.toStringAsFixed(1)} cm',
            'Weight: ${userAnalysis['weight']?.toStringAsFixed(1)} kg',
            'Gender: ${userAnalysis['gender']}',
            'BMI: ${userAnalysis['bmi']?.toStringAsFixed(1)} (${userAnalysis['weightCategory']})',
          ], Colors.blue),
          const SizedBox(height: 16),
          _buildAnalysisCard('Fitness Profile', Icons.fitness_center, [
            'Goal: ${userAnalysis['goal']}',
            'Activity Level: ${userAnalysis['activityLevel']}',
            'BMR: ${userAnalysis['bmr']?.toStringAsFixed(0)} calories/day',
            'Daily Calorie Target: ${userAnalysis['dailyCalories']?.toStringAsFixed(0)} calories',
          ], Colors.orange),
          const SizedBox(height: 16),
          _buildAnalysisCard('Nutritional Goals', Icons.restaurant_menu, [
            'Daily Calories: ${nutritionalGoals['dailyCalories']?.toStringAsFixed(0)}',
            'Protein: ${nutritionalGoals['protein']?.toStringAsFixed(1)}g',
            'Carbohydrates: ${nutritionalGoals['carbs']?.toStringAsFixed(1)}g',
            'Fat: ${nutritionalGoals['fat']?.toStringAsFixed(1)}g',
            'Fiber: ${nutritionalGoals['fiber']?.toStringAsFixed(1)}g',
          ], Colors.green),
          const SizedBox(height: 16),
          if (userAnalysis['healthConditions']?.isNotEmpty == true)
            _buildAnalysisCard(
              'Health Considerations',
              Icons.health_and_safety,
              (userAnalysis['healthConditions'] as List<String>)
                  .where((condition) => condition != 'None')
                  .map((condition) => '• $condition')
                  .toList(),
              Colors.red,
            ),
          const SizedBox(height: 16),
          if (userAnalysis['allergies']?.isNotEmpty == true)
            _buildAnalysisCard(
              'Allergies & Restrictions',
              Icons.warning,
              (userAnalysis['allergies'] as List<String>)
                  .where((allergy) => allergy != 'None')
                  .map((allergy) => '• $allergy')
                  .toList(),
              Colors.amber,
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_mealPlanData == null) {
      return const Center(
        child: Text(
          'Generate a meal plan to see personalized recommendations.',
        ),
      );
    }

    final recommendations = _mealPlanData!['recommendations'] as List<String>;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Icon(Icons.lightbulb, color: Colors.green[700]),
            ),
            title: Text(
              recommendations[index],
              style: const TextStyle(fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        );
      },
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

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.purple;
      case 'snack':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.restaurant;
      case 'dinner':
        return Icons.nights_stay;
      case 'snack':
        return Icons.coffee;
      default:
        return Icons.fastfood;
    }
  }

  void _showNutritionalInfo(Map<String, dynamic> nutritionalSummary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Nutritional Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNutritionRow(
              'Calories',
              '${nutritionalSummary['calories']?.toStringAsFixed(0)} cal',
            ),
            _buildNutritionRow(
              'Protein',
              '${nutritionalSummary['protein']?.toStringAsFixed(1)}g',
            ),
            _buildNutritionRow(
              'Carbs',
              '${nutritionalSummary['carbs']?.toStringAsFixed(1)}g',
            ),
            _buildNutritionRow(
              'Fat',
              '${nutritionalSummary['fat']?.toStringAsFixed(1)}g',
            ),
            _buildNutritionRow(
              'Fiber',
              '${nutritionalSummary['fiber']?.toStringAsFixed(1)}g',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.green)),
        ],
      ),
    );
  }

  void _viewRecipeDetails(Map<String, dynamic> recipe) {
    // Check if this is a real recipe with an ID, or just a placeholder
    if (recipe['id'] == null) {
      // This is a placeholder meal, show a simple dialog instead
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(recipe['title']?.toString() ?? 'Meal Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe['description'] != null &&
                  recipe['description'].toString().isNotEmpty)
                Text(
                  recipe['description'].toString(),
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 16),
              const Text(
                'This is a suggested meal from your AI meal plan. The AI service will generate more detailed recipes in future updates.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      // This is a real recipe, navigate to recipe details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailPage(recipe: recipe),
        ),
      );
    }
  }

  // Generate a simple fallback meal plan for testing when AI service fails
  List<Map<String, dynamic>> _generateFallbackMealPlan() {
    final List<Map<String, dynamic>> fallbackPlan = [];

    for (int day = 1; day <= _selectedDays; day++) {
      final dayPlan = {
        'meals': {
          'breakfast': {
            'recipe': {
              'title': 'Healthy Breakfast Bowl',
              'description': 'Oatmeal with Greek yogurt, berries, and nuts',
            },
            'estimatedCalories': 400.0,
            'portionSize': 1.0,
          },
          'lunch': {
            'recipe': {
              'title': 'Grilled Chicken Salad',
              'description': 'Mixed greens with quinoa and vegetables',
            },
            'estimatedCalories': 500.0,
            'portionSize': 1.0,
          },
          'dinner': {
            'recipe': {
              'title': 'Salmon with Brown Rice',
              'description': 'Grilled salmon with broccoli and brown rice',
            },
            'estimatedCalories': 600.0,
            'portionSize': 1.0,
          },
        },
        'totalCalories': 1500.0,
        'nutritionalSummary': {
          'calories': 1500.0,
          'protein': 80.0,
          'carbs': 150.0,
          'fat': 60.0,
          'fiber': 25.0,
        },
      };

      fallbackPlan.add(dayPlan);
    }

    return fallbackPlan;
  }
}
