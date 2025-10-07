import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/personalized_nutrition_service.dart';

class PersonalizedNutritionPage extends StatefulWidget {
  const PersonalizedNutritionPage({super.key});

  @override
  State<PersonalizedNutritionPage> createState() => _PersonalizedNutritionPageState();
}

class _PersonalizedNutritionPageState extends State<PersonalizedNutritionPage> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _recommendations;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final recommendations = await PersonalizedNutritionService.getPersonalizedRecommendations(user.uid);
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalized Nutrition'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Macros', icon: Icon(Icons.pie_chart)),
            Tab(text: 'Guidelines', icon: Icon(Icons.rule)),
            Tab(text: 'Supplements', icon: Icon(Icons.medication)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadRecommendations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecommendations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_recommendations == null) {
      return const Center(
        child: Text('No recommendations available'),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildMacrosTab(),
        _buildGuidelinesTab(),
        _buildSupplementsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final recommendations = _recommendations!['recommendations'] as Map<String, dynamic>;
    final userProfile = _recommendations!['userProfile'] as Map<String, dynamic>?;
    final applicableRules = _recommendations!['applicableRules'] as List<dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Your Personalized Nutrition Plan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (userProfile != null) ...[
                    Text('Based on your profile: ${_getProfileSummary(userProfile)}'),
                    const SizedBox(height: 8),
                    Text('${applicableRules.length} nutrition rules applied'),
                  ] else ...[
                    const Text('Using general recommendations'),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${_formatDate(DateTime.parse(_recommendations!['lastUpdated']))}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Daily Targets
          _buildSectionCard(
            'Daily Nutrition Targets',
            [
              _buildTargetRow('Calories', '${recommendations['dailyCalories']}', 'kcal', Colors.red),
              _buildTargetRow('Protein', '${recommendations['protein']}', 'g', Colors.blue),
              _buildTargetRow('Carbohydrates', '${recommendations['carbs']}', 'g', Colors.orange),
              _buildTargetRow('Fat', '${recommendations['fat']}', 'g', Colors.green),
              _buildTargetRow('Fiber', '${recommendations['fiber']}', 'g', Colors.purple),
              _buildTargetRow('Sodium', '${recommendations['sodium']}', 'mg', Colors.brown),
              _buildTargetRow('Water', '${recommendations['water']}', 'L', Colors.cyan),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Meal Frequency
          _buildSectionCard(
            'Meal Planning',
            [
              _buildInfoRow('Recommended meals per day', '${recommendations['mealFrequency']}'),
              _buildInfoRow('Meal timing', 'Space meals evenly throughout the day'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Special Instructions
          if (recommendations['specialInstructions']?.isNotEmpty == true) ...[
            _buildSectionCard(
              'Special Instructions',
              (recommendations['specialInstructions'] as List<dynamic>).map((instruction) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(instruction.toString())),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacrosTab() {
    final recommendations = _recommendations!['recommendations'] as Map<String, dynamic>;
    final calories = recommendations['dailyCalories'] as int;
    final protein = recommendations['protein'] as int;
    final carbs = recommendations['carbs'] as int;
    final fat = recommendations['fat'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Macro Distribution Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Macronutrient Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMacroBar('Protein', protein, Colors.blue, (protein * 4) / calories),
                        _buildMacroBar('Carbs', carbs, Colors.orange, (carbs * 4) / calories),
                        _buildMacroBar('Fat', fat, Colors.green, (fat * 9) / calories),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMacroLegend('Protein', Colors.blue, '${((protein * 4) / calories * 100).toStringAsFixed(1)}%'),
                      _buildMacroLegend('Carbs', Colors.orange, '${((carbs * 4) / calories * 100).toStringAsFixed(1)}%'),
                      _buildMacroLegend('Fat', Colors.green, '${((fat * 9) / calories * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Detailed Macro Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detailed Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMacroDetail('Protein', protein, 'g', 'Builds and repairs tissues', Colors.blue),
                  _buildMacroDetail('Carbohydrates', carbs, 'g', 'Primary energy source', Colors.orange),
                  _buildMacroDetail('Fat', fat, 'g', 'Essential for hormone production', Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesTab() {
    final recommendations = _recommendations!['recommendations'] as Map<String, dynamic>;
    final foodsToInclude = recommendations['foodsToInclude'] as List<dynamic>? ?? [];
    final foodsToAvoid = recommendations['foodsToAvoid'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Foods to Include
          if (foodsToInclude.isNotEmpty) ...[
            _buildSectionCard(
              'Foods to Include',
              foodsToInclude.map((food) => _buildFoodItem(food.toString(), true)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // Foods to Avoid
          if (foodsToAvoid.isNotEmpty) ...[
            _buildSectionCard(
              'Foods to Limit or Avoid',
              foodsToAvoid.map((food) => _buildFoodItem(food.toString(), false)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // General Guidelines
          _buildSectionCard(
            'General Nutrition Guidelines',
            [
              _buildGuidelineItem('Stay Hydrated', 'Drink ${recommendations['water']}L of water daily'),
              _buildGuidelineItem('Eat Regularly', 'Have ${recommendations['mealFrequency']} balanced meals per day'),
              _buildGuidelineItem('Focus on Whole Foods', 'Choose minimally processed foods'),
              _buildGuidelineItem('Monitor Sodium', 'Keep sodium intake under ${recommendations['sodium']}mg daily'),
              _buildGuidelineItem('Include Fiber', 'Aim for ${recommendations['fiber']}g of fiber daily'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupplementsTab() {
    final recommendations = _recommendations!['recommendations'] as Map<String, dynamic>;
    final supplements = recommendations['supplements'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (supplements.isNotEmpty) ...[
            _buildSectionCard(
              'Recommended Supplements',
              supplements.map((supplement) => _buildSupplementItem(supplement.toString())).toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.medication, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No specific supplements recommended',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Focus on getting nutrients from whole foods first. Consult with a healthcare provider before taking any supplements.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // General Supplement Guidelines
          _buildSectionCard(
            'Supplement Guidelines',
            [
              _buildGuidelineItem('Consult Healthcare Provider', 'Always check with your doctor before starting supplements'),
              _buildGuidelineItem('Quality Matters', 'Choose reputable brands with third-party testing'),
              _buildGuidelineItem('Food First', 'Supplements should complement, not replace, a healthy diet'),
              _buildGuidelineItem('Monitor Interactions', 'Be aware of potential drug interactions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRow(String label, String value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String label, int value, Color color, double percentage) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.15 * percentage,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          '$value g',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildMacroLegend(String label, Color color, String percentage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label $percentage'),
      ],
    );
  }

  Widget _buildMacroDetail(String name, int value, String unit, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name: $value $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(String food, bool isInclude) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isInclude ? Icons.check_circle : Icons.cancel,
            color: isInclude ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(food)),
        ],
      ),
    );
  }

  Widget _buildSupplementItem(String supplement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.medication, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(supplement)),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            description,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _getProfileSummary(Map<String, dynamic> userProfile) {
    final age = userProfile['age'];
    final gender = userProfile['gender'];
    final healthConditions = userProfile['healthConditions'] as List<dynamic>;
    final bodyGoals = userProfile['bodyGoals'] as List<dynamic>;
    
    String summary = '$gender, $age years old';
    if (healthConditions.isNotEmpty) {
      summary += ', with ${healthConditions.join(', ')}';
    }
    if (bodyGoals.isNotEmpty) {
      summary += ', goals: ${bodyGoals.join(', ')}';
    }
    
    return summary;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
