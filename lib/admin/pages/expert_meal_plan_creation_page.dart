import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpertMealPlanCreationPage extends StatefulWidget {
  const ExpertMealPlanCreationPage({super.key});

  @override
  State<ExpertMealPlanCreationPage> createState() => _ExpertMealPlanCreationPageState();
}

class _ExpertMealPlanCreationPageState extends State<ExpertMealPlanCreationPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Basic meal plan info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedGoal = 'Weight Loss';
  String _selectedTargetAudience = 'General';
  int _selectedDays = 7;
  
  // Nutrition targets
  int _targetCalories = 2000;
  double _proteinRatio = 0.25;
  double _carbRatio = 0.45;
  double _fatRatio = 0.30;
  
  // Meal structure
  List<Map<String, dynamic>> _meals = [];
  String? _currentPlanId; // For editing existing plans

  final List<String> _goals = [
    'Weight Loss',
    'Weight Gain',
    'Muscle Building',
    'Diabetes Management',
    'Heart Health',
    'General Health',
    'Athletic Performance',
    'Pregnancy',
    'Elderly Care',
    'Child Nutrition'
  ];

  final List<String> _targetAudiences = [
    'General',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Mediterranean',
    'Low-Carb',
    'High-Protein',
    'Gluten-Free',
    'Dairy-Free'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeMeals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeMeals() {
    _meals = List.generate(_selectedDays, (dayIndex) {
      return {
        'day': dayIndex + 1,
        'breakfast': {'name': '', 'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'ingredients': []},
        'lunch': {'name': '', 'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'ingredients': []},
        'dinner': {'name': '', 'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'ingredients': []},
        'snacks': {'name': '', 'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'ingredients': []},
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Meal Plan Creation'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Basic Info', icon: Icon(Icons.info)),
            Tab(text: 'Nutrition Targets', icon: Icon(Icons.track_changes)),
            Tab(text: 'Meal Planning', icon: Icon(Icons.restaurant)),
            Tab(text: 'Manage Plans', icon: Icon(Icons.edit)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _saveMealPlan,
            icon: const Icon(Icons.save),
            tooltip: 'Save Meal Plan',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(),
          _buildNutritionTargetsTab(),
          _buildMealPlanningTab(),
          _buildManagePlansTab(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              'Meal Plan Information',
              [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Meal Plan Name',
                    hintText: 'e.g., Diabetes-Friendly 7-Day Plan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of the meal plan and its benefits',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGoal,
                        decoration: const InputDecoration(
                          labelText: 'Health Goal',
                          border: OutlineInputBorder(),
                        ),
                        items: _goals.map((goal) => DropdownMenuItem(
                          value: goal,
                          child: Text(goal),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedGoal = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTargetAudience,
                        decoration: const InputDecoration(
                          labelText: 'Target Audience',
                          border: OutlineInputBorder(),
                        ),
                        items: _targetAudiences.map((audience) => DropdownMenuItem(
                          value: audience,
                          child: Text(audience),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedTargetAudience = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedDays,
                  decoration: const InputDecoration(
                    labelText: 'Duration (Days)',
                    border: OutlineInputBorder(),
                  ),
                  items: [7, 14, 21, 30].map((days) => DropdownMenuItem(
                    value: days,
                    child: Text('$days days'),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDays = value!;
                      _initializeMeals();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              'Scientific Basis',
              [
                const Text(
                  'This meal plan is designed based on:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoItem('✓ Evidence-based nutritional guidelines'),
                _buildInfoItem('✓ Clinical research on $_selectedGoal'),
                _buildInfoItem('✓ Optimal macronutrient distribution'),
                _buildInfoItem('✓ Safe and sustainable approach'),
                _buildInfoItem('✓ Professional nutritionist expertise'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionTargetsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Daily Calorie Target',
            [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _targetCalories.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Calories per day',
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _targetCalories = int.tryParse(value) ?? 2000;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _calculateCalories,
                    child: const Text('Auto Calculate'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recommended range: ${(_targetCalories * 0.8).round()}-${(_targetCalories * 1.2).round()} kcal based on goal',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            'Macronutrient Distribution',
            [
              _buildMacroSlider('Protein', _proteinRatio, (value) {
                setState(() {
                  _proteinRatio = value;
                  _adjustOtherMacros('protein', value);
                });
              }, Colors.red),
              const SizedBox(height: 16),
              _buildMacroSlider('Carbohydrates', _carbRatio, (value) {
                setState(() {
                  _carbRatio = value;
                  _adjustOtherMacros('carbs', value);
                });
              }, Colors.blue),
              const SizedBox(height: 16),
              _buildMacroSlider('Fats', _fatRatio, (value) {
                setState(() {
                  _fatRatio = value;
                  _adjustOtherMacros('fats', value);
                });
              }, Colors.green),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total: ${((_proteinRatio + _carbRatio + _fatRatio) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (_proteinRatio + _carbRatio + _fatRatio).abs() > 1.01 
                            ? Colors.red 
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Protein: ${(_proteinRatio * _targetCalories / 4).round()}g | '
                      'Carbs: ${(_carbRatio * _targetCalories / 4).round()}g | '
                      'Fats: ${(_fatRatio * _targetCalories / 9).round()}g',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanningTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Design meals for each day. Click on a meal to add recipes and ingredients.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              return _buildDayCard(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final day = _meals[dayIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day ${day['day']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMealCard('Breakfast', day['breakfast'], dayIndex, 'breakfast')),
                const SizedBox(width: 8),
                Expanded(child: _buildMealCard('Lunch', day['lunch'], dayIndex, 'lunch')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMealCard('Dinner', day['dinner'], dayIndex, 'dinner')),
                const SizedBox(width: 8),
                Expanded(child: _buildMealCard('Snacks', day['snacks'], dayIndex, 'snacks')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(String mealType, Map<String, dynamic> meal, int dayIndex, String mealKey) {
    return InkWell(
      onTap: () => _editMeal(dayIndex, mealKey, mealType),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mealType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              meal['name'].isEmpty ? 'Tap to add meal' : meal['name'],
              style: TextStyle(
                fontSize: 11,
                color: meal['name'].isEmpty ? Colors.grey : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meal['calories'] > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${meal['calories']} kcal',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
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

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildMacroSlider(String label, double value, Function(double) onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${(value * 100).toStringAsFixed(1)}%'),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0.1,
            max: 0.6,
            divisions: 50,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _adjustOtherMacros(String changedMacro, double newValue) {
    final remaining = 1.0 - newValue;
    if (changedMacro == 'protein') {
      _carbRatio = remaining * 0.6;
      _fatRatio = remaining * 0.4;
    } else if (changedMacro == 'carbs') {
      _proteinRatio = remaining * 0.4;
      _fatRatio = remaining * 0.6;
    } else if (changedMacro == 'fats') {
      _proteinRatio = remaining * 0.4;
      _carbRatio = remaining * 0.6;
    }
  }

  void _calculateCalories() {
    // Basic calorie calculation based on goal
    switch (_selectedGoal) {
      case 'Weight Loss':
        _targetCalories = 1500;
        break;
      case 'Weight Gain':
        _targetCalories = 2500;
        break;
      case 'Muscle Building':
        _targetCalories = 2200;
        break;
      case 'Diabetes Management':
        _targetCalories = 1800;
        break;
      case 'Heart Health':
        _targetCalories = 2000;
        break;
      default:
        _targetCalories = 2000;
    }
    setState(() {});
  }

  void _editMeal(int dayIndex, String mealKey, String mealType) {
    showDialog(
      context: context,
      builder: (context) => _MealEditDialog(
        meal: _meals[dayIndex][mealKey],
        mealType: mealType,
        onSave: (updatedMeal) {
          setState(() {
            _meals[dayIndex][mealKey] = updatedMeal;
          });
        },
      ),
    );
  }

  Future<void> _saveMealPlan() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final mealPlanData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'goal': _selectedGoal,
        'targetAudience': _selectedTargetAudience,
        'days': _selectedDays,
        'targetCalories': _targetCalories,
        'proteinRatio': _proteinRatio,
        'carbRatio': _carbRatio,
        'fatRatio': _fatRatio,
        'meals': _meals,
        'createdBy': 'nutritionist',
        'isExpertPlan': true,
        'status': 'published',
      };

      if (_currentPlanId != null) {
        // Update existing plan
        await FirebaseFirestore.instance
            .collection('expert_meal_plans')
            .doc(_currentPlanId)
            .update({
          ...mealPlanData,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new plan
        await FirebaseFirestore.instance
            .collection('expert_meal_plans')
            .add({
          ...mealPlanData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_currentPlanId != null 
                ? 'Meal plan updated successfully!' 
                : 'Expert meal plan saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear the form and reset to first tab
        _clearForm();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedGoal = 'Weight Loss';
    _selectedTargetAudience = 'General';
    _selectedDays = 7;
    _targetCalories = 2000;
    _proteinRatio = 0.25;
    _carbRatio = 0.45;
    _fatRatio = 0.30;
    _initializeMeals();
    _currentPlanId = null;
  }

  Widget _buildManagePlansTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expert_meal_plans')
          .where('createdBy', isEqualTo: 'nutritionist')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No meal plans created yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first expert meal plan using the tabs above',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildManagePlanCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildManagePlanCard(String planId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed Plan';
    final description = data['description'] ?? '';
    final goal = data['goal'] ?? 'General Health';
    final audience = data['targetAudience'] ?? 'General';
    final days = data['days'] ?? 7;
    final targetCalories = data['targetCalories'] ?? 2000;
    final status = data['status'] ?? 'draft';
    final createdAt = data['createdAt'] as Timestamp?;
    final lastUpdated = data['lastUpdated'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getGoalColor(goal).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: _getGoalColor(goal),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$goal • $audience • ${days} days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            
            // Plan Details
            Row(
              children: [
                _buildDetailChip(Icons.local_fire_department, '${targetCalories} cal/day'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.schedule, '$days days'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.people, audience),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Timestamps
            Row(
              children: [
                if (createdAt != null) ...[
                  Text(
                    'Created: ${_formatDate(createdAt.toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (lastUpdated != null) ...[
                  const Spacer(),
                  Text(
                    'Updated: ${_formatDate(lastUpdated.toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editMealPlan(planId, data),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _duplicateMealPlan(planId, data),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Duplicate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _togglePlanStatus(planId, status),
                    icon: Icon(
                      status == 'published' ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(status == 'published' ? 'Unpublish' : 'Publish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'published' ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteMealPlan(planId, name),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGoalColor(String goal) {
    switch (goal) {
      case 'Weight Loss':
        return Colors.red;
      case 'Weight Gain':
        return Colors.blue;
      case 'Muscle Building':
        return Colors.orange;
      case 'Diabetes Management':
        return Colors.purple;
      case 'Heart Health':
        return Colors.pink;
      case 'General Health':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editMealPlan(String planId, Map<String, dynamic> data) {
    // Pre-fill the form with existing data
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _selectedGoal = data['goal'] ?? 'Weight Loss';
    _selectedTargetAudience = data['targetAudience'] ?? 'General';
    _selectedDays = data['days'] ?? 7;
    _targetCalories = data['targetCalories'] ?? 2000;
    _proteinRatio = data['proteinRatio'] ?? 0.25;
    _carbRatio = data['carbRatio'] ?? 0.45;
    _fatRatio = data['fatRatio'] ?? 0.30;
    _meals = List<Map<String, dynamic>>.from(data['meals'] ?? []);

    // Switch to first tab to show the form
    _tabController.animateTo(0);

    // Store the plan ID for updating
    _currentPlanId = planId;
  }

  void _duplicateMealPlan(String planId, Map<String, dynamic> data) {
    // Pre-fill the form with existing data but clear the name
    _nameController.text = '${data['name']} (Copy)';
    _descriptionController.text = data['description'] ?? '';
    _selectedGoal = data['goal'] ?? 'Weight Loss';
    _selectedTargetAudience = data['targetAudience'] ?? 'General';
    _selectedDays = data['days'] ?? 7;
    _targetCalories = data['targetCalories'] ?? 2000;
    _proteinRatio = data['proteinRatio'] ?? 0.25;
    _carbRatio = data['carbRatio'] ?? 0.45;
    _fatRatio = data['fatRatio'] ?? 0.30;
    _meals = List<Map<String, dynamic>>.from(data['meals'] ?? []);

    // Switch to first tab to show the form
    _tabController.animateTo(0);

    // Clear the plan ID for creating a new one
    _currentPlanId = null;
  }

  Future<void> _togglePlanStatus(String planId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'published' ? 'draft' : 'published';
      
      await FirebaseFirestore.instance
          .collection('expert_meal_plans')
          .doc(planId)
          .update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meal plan ${newStatus} successfully!'),
            backgroundColor: newStatus == 'published' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMealPlan(String planId, String planName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal Plan'),
        content: Text('Are you sure you want to delete "$planName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('expert_meal_plans')
            .doc(planId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal plan deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting meal plan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _MealEditDialog extends StatefulWidget {
  final Map<String, dynamic> meal;
  final String mealType;
  final Function(Map<String, dynamic>) onSave;

  const _MealEditDialog({
    required this.meal,
    required this.mealType,
    required this.onSave,
  });

  @override
  State<_MealEditDialog> createState() => _MealEditDialogState();
}

class _MealEditDialogState extends State<_MealEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _ingredientsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.meal['name'] ?? '';
    _caloriesController.text = widget.meal['calories']?.toString() ?? '0';
    _proteinController.text = widget.meal['protein']?.toString() ?? '0';
    _carbsController.text = widget.meal['carbs']?.toString() ?? '0';
    _fatController.text = widget.meal['fat']?.toString() ?? '0';
    _ingredientsController.text = (widget.meal['ingredients'] as List?)?.join(', ') ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.mealType}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Meal Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        labelText: 'Calories',
                        border: OutlineInputBorder(),
                        suffixText: 'kcal',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      decoration: const InputDecoration(
                        labelText: 'Protein',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      decoration: const InputDecoration(
                        labelText: 'Carbs',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: 'Fat',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ingredientsController,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (comma-separated)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedMeal = {
                'name': _nameController.text,
                'calories': int.tryParse(_caloriesController.text) ?? 0,
                'protein': double.tryParse(_proteinController.text) ?? 0,
                'carbs': double.tryParse(_carbsController.text) ?? 0,
                'fat': double.tryParse(_fatController.text) ?? 0,
                'ingredients': _ingredientsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              };
              widget.onSave(updatedMeal);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
