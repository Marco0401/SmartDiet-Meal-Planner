import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'meal_planner_page.dart';
import 'ai_meal_planner_page.dart';

class UnifiedMealPlannerPage extends StatefulWidget {
  const UnifiedMealPlannerPage({super.key});

  @override
  State<UnifiedMealPlannerPage> createState() => _UnifiedMealPlannerPageState();
}

class _UnifiedMealPlannerPageState extends State<UnifiedMealPlannerPage> {
  List<Map<String, dynamic>> _savedMealPlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedMealPlans();
  }

  Future<void> _loadSavedMealPlans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meal_plans')
            .orderBy('created_at', descending: true)
            .get();

        setState(() {
          _savedMealPlans = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPlannerTypeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Meal Planning Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you like to plan your meals?'),
              const SizedBox(height: 20),
              _buildPlannerOption(
                icon: Icons.psychology,
                title: 'AI Meal Planner',
                subtitle: 'Get personalized AI-generated meal plans',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIMealPlannerPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildPlannerOption(
                icon: Icons.calendar_month,
                title: 'Manual Meal Planner',
                subtitle: 'Plan meals manually with calendar view',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MealPlannerPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlannerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMealPlan(Map<String, dynamic> mealPlan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meal_plans')
            .add({
          ...mealPlan,
          'created_at': FieldValue.serverTimestamp(),
          'user_id': user.uid,
        });
        
        _loadSavedMealPlans(); // Refresh the list
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMealPlan(String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meal_plans')
            .doc(planId)
            .delete();
        
        _loadSavedMealPlans(); // Refresh the list
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan deleted successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyMealPlan(Map<String, dynamic> mealPlan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final meals = mealPlan['meals'] as List<dynamic>? ?? [];
      
      for (final meal in meals) {
        final mealData = meal as Map<String, dynamic>;
        final date = mealData['date'] as String;
        
        // Save each meal to the user's meal_plans collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meal_plans')
            .add({
          'title': mealData['title'] ?? 'Planned Meal',
          'date': date,
          'meal_type': mealData['meal_type'] ?? 'lunch',
          'nutrition': mealData['nutrition'] ?? {},
          'ingredients': mealData['ingredients'] ?? [],
          'instructions': mealData['instructions'] ?? '',
          'created_at': FieldValue.serverTimestamp(),
          'source': 'meal_plan',
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal plan applied to your calendar!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying meal plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              'Meal Planning',
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
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create New Plan Section
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.add_circle, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Create New Meal Plan',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          const Text(
                            'Choose how you want to plan your meals. AI planning provides personalized recommendations, while manual planning gives you full control.',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showPlannerTypeDialog,
                              icon: const Icon(Icons.restaurant_menu),
                              label: const Text('Start Planning'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Saved Plans Section
                  Text(
                    'Saved Meal Plans',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_savedMealPlans.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved meal plans yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first meal plan to see it here',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_savedMealPlans.map((plan) => _buildMealPlanCard(plan))),
                ],
              ),
            ),
    );
  }

  Widget _buildMealPlanCard(Map<String, dynamic> plan) {
    final createdAt = plan['created_at'] as Timestamp?;
    final dateStr = createdAt != null 
        ? DateFormat('MMM dd, yyyy').format(createdAt.toDate())
        : 'Unknown date';
    
    final planType = plan['type'] as String? ?? 'Unknown';
    final planName = plan['name'] as String? ?? 'Untitled Plan';
    final meals = plan['meals'] as List<dynamic>? ?? [];
    
    // Calculate total nutrition
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (final meal in meals) {
      final nutrition = meal['nutrition'] as Map<String, dynamic>? ?? {};
      totalCalories += (nutrition['calories'] as num?)?.toDouble() ?? 0;
      totalProtein += (nutrition['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (nutrition['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (nutrition['fat'] as num?)?.toDouble() ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewMealPlanDetails(plan),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: planType == 'AI' ? Colors.purple[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      planType == 'AI' ? 'AI Generated' : 'Manual Plan',
                      style: TextStyle(
                        color: planType == 'AI' ? Colors.purple[700] : Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'apply') {
                        _applyMealPlan(plan);
                      } else if (value == 'delete') {
                        _deleteMealPlan(plan['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'apply',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16),
                            SizedBox(width: 8),
                            Text('Apply to Calendar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                planName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Created on $dateStr',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${meals.length} meals planned',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildNutritionChip('${totalCalories.toInt()} cal', Colors.orange),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${totalProtein.toInt()}g protein', Colors.blue),
                  const SizedBox(width: 8),
                  _buildNutritionChip('${totalCarbs.toInt()}g carbs', Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewMealPlanDetails(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final meals = plan['meals'] as List<dynamic>? ?? [];
        final planName = plan['name'] as String? ?? 'Untitled Plan';
        
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        planName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      final nutrition = meal['nutrition'] as Map<String, dynamic>? ?? {};
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(meal['title'] ?? 'Unknown Meal'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${meal['meal_type']?.toString().toUpperCase() ?? 'MEAL'} - ${meal['date'] ?? 'Unknown date'}'),
                              if (nutrition.isNotEmpty)
                                Text('${nutrition['calories']?.toStringAsFixed(0) ?? '0'} cal'),
                            ],
                          ),
                          trailing: const Icon(Icons.restaurant_menu),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _applyMealPlan(plan);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply to Calendar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
