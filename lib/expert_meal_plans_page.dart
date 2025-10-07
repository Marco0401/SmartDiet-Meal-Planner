import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ExpertMealPlansPage extends StatefulWidget {
  const ExpertMealPlansPage({super.key});

  @override
  State<ExpertMealPlansPage> createState() => _ExpertMealPlansPageState();
}

class _ExpertMealPlansPageState extends State<ExpertMealPlansPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedGoal = 'All';
  String _selectedAudience = 'All';

  final List<String> _goals = [
    'All',
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

  final List<String> _audiences = [
    'All',
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Meal Plans'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Browse Plans', icon: Icon(Icons.explore)),
            Tab(text: 'My Applied Plans', icon: Icon(Icons.bookmark)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search meal plans...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGoal,
                        decoration: const InputDecoration(
                          labelText: 'Health Goal',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _goals.map((goal) => DropdownMenuItem(
                          value: goal,
                          child: Text(goal),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedGoal = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAudience,
                        decoration: const InputDecoration(
                          labelText: 'Diet Type',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _audiences.map((audience) => DropdownMenuItem(
                          value: audience,
                          child: Text(audience),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedAudience = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBrowsePlansTab(),
                _buildMyAppliedPlansTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowsePlansTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getExpertMealPlansStream(),
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
        final filteredDocs = _filterMealPlans(docs);

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _selectedGoal != 'All' || _selectedAudience != 'All'
                      ? 'No meal plans match your criteria'
                      : 'No expert meal plans available',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty || _selectedGoal != 'All' || _selectedAudience != 'All') ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedGoal = 'All';
                        _selectedAudience = 'All';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildMealPlanCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildMyAppliedPlansTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to view your applied meal plans'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('applied_expert_plans')
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
                const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No applied meal plans yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse and apply expert meal plans to see them here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
            return _buildAppliedMealPlanCard(doc.id, data);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getExpertMealPlansStream() {
    return FirebaseFirestore.instance
        .collection('expert_meal_plans')
        .where('status', isEqualTo: 'published')
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterMealPlans(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final goal = data['goal']?.toString() ?? '';
      final audience = data['targetAudience']?.toString() ?? '';

      // Search filter
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Goal filter
      if (_selectedGoal != 'All' && goal != _selectedGoal) {
        return false;
      }

      // Audience filter
      if (_selectedAudience != 'All' && audience != _selectedAudience) {
        return false;
      }

      return true;
    }).toList();
  }

  Widget _buildMealPlanCard(String planId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed Plan';
    final description = data['description'] ?? '';
    final goal = data['goal'] ?? 'General Health';
    final audience = data['targetAudience'] ?? 'General';
    final days = data['days'] ?? 7;
    final targetCalories = data['targetCalories'] ?? 2000;
    final createdAt = data['createdAt'] as Timestamp?;
    final meals = data['meals'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getGoalColor(goal).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal,
                    style: TextStyle(
                      color: _getGoalColor(goal),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    audience,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text(
                        'EXPERT',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            
            // Plan Details
            Row(
              children: [
                _buildDetailChip(Icons.schedule, '$days days'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.local_fire_department, '${targetCalories} cal/day'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.restaurant, '${meals.length} meals'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Sample Meals Preview
            if (meals.isNotEmpty) ...[
              const Text(
                'Sample Meals:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _getSampleMeals(meals).map((meal) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meal,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            
            // Timestamp
            if (createdAt != null) ...[
              Text(
                'Created: ${_formatDate(createdAt.toDate())}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
            ],
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewMealPlanDetails(planId, data),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _applyMealPlan(planId, data),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Apply Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
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

  Widget _buildAppliedMealPlanCard(String appliedPlanId, Map<String, dynamic> data) {
    final appliedAt = data['appliedAt'] as Timestamp?;
    final status = data['status'] ?? 'active';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    color: status == 'active' ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: status == 'active' ? Colors.green : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (appliedAt != null)
                  Text(
                    'Applied: ${_formatDate(appliedAt.toDate())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['planName'] ?? 'Unknown Plan',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['planDescription'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewAppliedPlanDetails(appliedPlanId, data),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 12),
                if (status == 'active')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _removeAppliedPlan(appliedPlanId),
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
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

  List<String> _getSampleMeals(List<dynamic> meals) {
    final sampleMeals = <String>[];
    for (final day in meals.take(2)) {
      final dayMeals = day as Map<String, dynamic>;
      ['breakfast', 'lunch', 'dinner'].forEach((mealType) {
        final meal = dayMeals[mealType] as Map<String, dynamic>?;
        if (meal != null && meal['name']?.isNotEmpty == true) {
          sampleMeals.add(meal['name']);
        }
      });
    }
    return sampleMeals.take(6).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _viewMealPlanDetails(String planId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _MealPlanDetailsDialog(
        planId: planId,
        data: data,
        onApply: () => _applyMealPlan(planId, data),
      ),
    );
  }

  void _viewAppliedPlanDetails(String appliedPlanId, Map<String, dynamic> data) {
    // Navigate to detailed view of applied plan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viewing applied plan details...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _applyMealPlan(String planId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('applied_expert_plans')
          .add({
        'planId': planId,
        'planName': data['name'],
        'planDescription': data['description'],
        'goal': data['goal'],
        'targetAudience': data['targetAudience'],
        'days': data['days'],
        'targetCalories': data['targetCalories'],
        'meals': data['meals'],
        'appliedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAppliedPlan(String appliedPlanId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('applied_expert_plans')
          .doc(appliedPlanId)
          .update({
        'status': 'removed',
        'removedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan removed successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing meal plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _MealPlanDetailsDialog extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> data;
  final VoidCallback onApply;

  const _MealPlanDetailsDialog({
    required this.planId,
    required this.data,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final meals = data['meals'] as List<dynamic>? ?? [];
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['name'] ?? 'Meal Plan Details',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Plan Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Goal: ${data['goal'] ?? 'General Health'}'),
                  Text('Target Audience: ${data['targetAudience'] ?? 'General'}'),
                  Text('Duration: ${data['days'] ?? 7} days'),
                  Text('Target Calories: ${data['targetCalories'] ?? 2000} kcal/day'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            if (data['description']?.isNotEmpty == true) ...[
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(data['description']),
              const SizedBox(height: 16),
            ],
            
            // Meals
            const Text(
              'Meal Plan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            
            Expanded(
              child: ListView.builder(
                itemCount: meals.length,
                itemBuilder: (context, dayIndex) {
                  final day = meals[dayIndex] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${day['day']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildMealRow('Breakfast', day['breakfast']),
                          _buildMealRow('Lunch', day['lunch']),
                          _buildMealRow('Dinner', day['dinner']),
                          _buildMealRow('Snacks', day['snacks']),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onApply();
                    },
                    child: const Text('Apply This Plan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealRow(String mealType, Map<String, dynamic>? meal) {
    if (meal == null || meal['name']?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              mealType,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(meal['name'] ?? ''),
          ),
          if (meal['calories'] != null && meal['calories'] > 0)
            Text(
              '${meal['calories']} cal',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }
}
