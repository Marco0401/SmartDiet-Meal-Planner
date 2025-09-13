import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/recipe_service.dart';
import 'recipe_detail_page.dart';
import 'manual_meal_entry_page.dart';
import 'barcode_scanner_page.dart';
import 'nutrition_analytics_page.dart';

class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key});

  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<Map<String, dynamic>>> _weeklyMeals = {};
  bool _isLoading = false;
  String? _error;

  // Meal types
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _loadWeeklyMeals();
  }

  Future<void> _loadWeeklyMeals() async {
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

        // Load meals for the entire week
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
            _weeklyMeals[dateKey] = List<Map<String, dynamic>>.from(
              data['meals'] ?? [],
            );
          } else {
            _weeklyMeals[dateKey] = [];
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

  Future<void> _addMeal(String dateKey, String mealType) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddMealDialog(),
    );

    if (result != null) {
      setState(() {
        if (_weeklyMeals[dateKey] == null) {
          _weeklyMeals[dateKey] = [];
        }
        _weeklyMeals[dateKey]!.add({
          ...result,
          'mealType': mealType,
          'addedAt': DateTime.now().toIso8601String(),
        });
      });

      // Save to Firestore
      await _saveMealsToFirestore(dateKey);
    }
  }

  Future<void> _saveMealsToFirestore(String dateKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .doc(dateKey)
            .set({
              'date': dateKey,
              'meals': _weeklyMeals[dateKey],
              'updatedAt': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving meal: $e')));
    }
  }

  Future<void> _removeMeal(String dateKey, int index) async {
    setState(() {
      _weeklyMeals[dateKey]!.removeAt(index);
    });
    await _saveMealsToFirestore(dateKey);
  }

  Map<String, dynamic> _calculateDailyNutrition(String dateKey) {
    final meals = _weeklyMeals[dateKey] ?? [];
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      final nutrition = meal['nutrition'] as Map<String, dynamic>?;
      if (nutrition != null) {
        totalCalories += (nutrition['calories'] ?? 0).toDouble();
        totalProtein += (nutrition['protein'] ?? 0).toDouble();
        totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
        totalFat += (nutrition['fat'] ?? 0).toDouble();
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showNutritionAnalytics(),
            tooltip: 'Nutrition Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
              children: [
                // Week Navigation
                _buildWeekNavigation(startOfWeek),

                // Weekly Calendar
                Expanded(child: _buildWeeklyCalendar(startOfWeek)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddMeal(),
        icon: const Icon(Icons.add),
        label: const Text("Quick Add"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildWeekNavigation(DateTime startOfWeek) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              _loadWeeklyMeals();
            },
          ),
          Text(
            '${_formatDisplayDate(startOfWeek)} - ${_formatDisplayDate(startOfWeek.add(const Duration(days: 6)))}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
              _loadWeeklyMeals();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(DateTime startOfWeek) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = startOfWeek.add(Duration(days: index));
        final dateKey = _formatDate(date);
        final meals = _weeklyMeals[dateKey] ?? [];
        final nutrition = _calculateDailyNutrition(dateKey);
        final isToday = date.isAtSameMomentAs(
          DateTime.now().subtract(
            Duration(days: DateTime.now().weekday - date.weekday),
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: isToday ? 4 : 2,
          color: isToday ? Colors.green[50] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.green[800] : Colors.green[700],
                      ),
                    ),
                    if (nutrition['calories'] > 0)
                      Text(
                        '${nutrition['calories'].toStringAsFixed(0)} cal',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Meal Types
                ..._mealTypes.map((mealType) {
                  final mealTypeMeals = meals
                      .where((meal) => meal['mealType'] == mealType)
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mealType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => _addMeal(dateKey, mealType),
                            color: Colors.green,
                          ),
                        ],
                      ),
                      if (mealTypeMeals.isNotEmpty)
                        ...mealTypeMeals.asMap().entries.map((entry) {
                          final mealIndex = entry.key;
                          final meal = entry.value;

                          return Card(
                            margin: const EdgeInsets.only(left: 16, bottom: 8),
                            child: ListTile(
                              leading: meal['image'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        meal['image'],
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.green[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.restaurant,
                                                  color: Colors.green,
                                                ),
                                              );
                                            },
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: Colors.green,
                                      ),
                                    ),
                              title: Text(
                                meal['title'] ?? 'Unknown Meal',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: meal['nutrition'] != null
                                  ? Text(
                                      '${(meal['nutrition']['calories'] ?? 0).toStringAsFixed(0)} cal',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removeMeal(dateKey, meals.indexOf(meal)),
                                color: Colors.red[400],
                              ),
                              onTap: () {
                                if (meal['id'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RecipeDetailPage(recipe: meal),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }),
                      if (mealTypeMeals.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 16),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No $mealType planned',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickAddMeal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuickAddMealSheet(
        onMealAdded: () => _loadWeeklyMeals(),
      ),
    );
  }

  void _showNutritionAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionAnalyticsPage()),
    );
  }
}

class AddMealDialog extends StatefulWidget {
  const AddMealDialog({super.key});

  @override
  State<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<AddMealDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _searchRecipes();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchRecipes() async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await RecipeService.fetchRecipes(_searchController.text);
      setState(() {
        _searchResults = results.take(5).toList().cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching recipes: $e')));
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Meal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a recipe...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final recipe = _searchResults[index];
                    return ListTile(
                      leading: recipe['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipe['image'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.green,
                              ),
                            ),
                      title: Text(recipe['title'] ?? 'Unknown Recipe'),
                      onTap: () {
                        Navigator.pop(context, recipe);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QuickAddMealSheet extends StatelessWidget {
  final VoidCallback? onMealAdded;
  
  const QuickAddMealSheet({super.key, this.onMealAdded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quick Add Meal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManualMealEntryPage(),
                      ),
                    );
                    if (result == true && onMealAdded != null) {
                      onMealAdded!();
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Manual Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerPage(),
                      ),
                    );
                    if (result == true && onMealAdded != null) {
                      onMealAdded!();
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
