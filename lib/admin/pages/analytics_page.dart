import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedTimeRange = '7 days';
  final List<String> _timeRanges = ['24 hours', '7 days', '30 days', '90 days'];
  
  // Cache for expensive queries
  Map<String, dynamic>? _cachedAnalyticsData;
  List<Map<String, dynamic>>? _cachedTopRecipes;
  List<Map<String, dynamic>>? _cachedRecentActivity;
  DateTime? _lastCacheTime;

  // Check if cache is still valid (5 minutes)
  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!).inMinutes < 5;
  }
  
  // Clear cache when time range changes
  void _clearCache() {
    _cachedAnalyticsData = null;
    _cachedTopRecipes = null;
    _cachedRecentActivity = null;
    _lastCacheTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          DropdownButton<String>(
            value: _selectedTimeRange,
            items: _timeRanges.map((range) {
              return DropdownMenuItem(value: range, child: Text(range));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTimeRange = value!;
                _clearCache(); // Clear cache when time range changes
              });
            },
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              _clearCache();
              setState(() {}); // Refresh the UI
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            onPressed: () => _exportReport(),
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Key Metrics Cards - Real Data
            FutureBuilder<Map<String, dynamic>>(
              future: _getAnalyticsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: [
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                    ],
                  );
                }
                
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading analytics: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _clearCache();
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                final userMetrics = data['users'] as Map<String, dynamic>? ?? {};
                final recipeMetrics = data['recipes'] as Map<String, dynamic>? ?? {};
                final mealPlanMetrics = data['mealPlans'] as Map<String, dynamic>? ?? {};
                final nutritionMetrics = data['nutrition'] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    Expanded(child: _buildMetricCard(
                      'Total Users', 
                      '${userMetrics['total'] ?? 0}', 
                      _calculateGrowth(userMetrics['growth']), 
                      Colors.blue, 
                      Icons.people
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Favorite Recipes', 
                      '${recipeMetrics['total'] ?? 0}', 
                      _calculateGrowth(recipeMetrics['growth']), 
                      Colors.orange, 
                      Icons.favorite
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Meal Plans', 
                      '${mealPlanMetrics['total'] ?? 0}', 
                      _calculateGrowth(mealPlanMetrics['growth']), 
                      Colors.green, 
                      Icons.calendar_today
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Nutrition Entries', 
                      '${nutritionMetrics['total'] ?? 0}', 
                      _calculateGrowth(nutritionMetrics['growth']), 
                      Colors.purple, 
                      Icons.analytics
                    )),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Charts and Reports
            Expanded(
              child: Row(
                children: [
                  // Left Column - Charts
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: _buildUserActivityChart()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildPopularAllergensChart()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Right Column - Lists
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildTopRecipesList()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildRecentActivityList()),
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

  Widget _buildMetricCard(String title, String value, String change, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Registration Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUserRegistrationTrends(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final trends = snapshot.data ?? [];
                  if (trends.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No registration data available'),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: trends.map((trend) {
                          final maxCount = trends.map((t) => t['count'] as int).reduce((a, b) => a > b ? a : b);
                          final scaledWidth = maxCount > 0 ? ((trend['count'] as int) / maxCount).clamp(0.0, 1.0) : 0.0;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    trend['date'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: scaledWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${trend['count']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularAllergensChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most Common Allergens',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getAllergenStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allergens = snapshot.data ?? [];
                  if (allergens.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No allergen data available'),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: allergens.take(6).map((allergen) {
                          final maxCount = allergens.isNotEmpty ? allergens.first['count'] as int : 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  allergen['icon'] ?? '⚠️',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    allergen['name'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ((allergen['count'] as int) / maxCount).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${allergen['count']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRecipesList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Recipes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getTopRecipes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading recipes: ${snapshot.error}'),
                    );
                  }
                  
                  final recipes = snapshot.data ?? [];
                  
                  if (recipes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recipe data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final title = recipe['title'] as String;
                      final count = recipe['count'] as int;
                      final type = recipe['type'] as String;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRecipeTypeColor(type),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRecipeTypeColor(type).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getRecipeTypeColor(type),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$count uses'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'times',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
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

  Color _getRecipeTypeColor(String type) {
    switch (type) {
      case 'Filipino': return Colors.red;
      case 'Italian': return Colors.green;
      case 'Asian': return Colors.blue;
      case 'API': return Colors.purple;
      case 'Admin': return Colors.indigo;
      case 'General': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildRecentActivityList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getRecentActivity(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading activity: ${snapshot.error}'),
                    );
                  }
                  
                  final activities = snapshot.data ?? [];
                  
                  if (activities.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recent activity',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      final title = activity['title'] as String;
                      final timestamp = activity['timestamp'] as Timestamp?;
                      final icon = activity['icon'] as IconData;
                      final color = activity['color'] as Color;
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        isThreeLine: false,
                      );
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final activityTime = timestamp.toDate();
    final difference = now.difference(activityTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(activityTime);
    }
  }


  void _exportReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('Export functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  // Real Analytics Data Methods
  Future<List<Map<String, dynamic>>> _getTopRecipes() async {
    // Return cached data if available and valid
    if (_cachedTopRecipes != null && _isCacheValid()) {
      return _cachedTopRecipes!;
    }
    
    try {
      final Map<String, int> recipeCounts = {};
      
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        // Check favorites collection
        final favoritesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('favorites')
            .get();
        
        for (final favoriteDoc in favoritesSnapshot.docs) {
          final data = favoriteDoc.data();
          final recipeTitle = _getRecipeTitle(data);
          if (recipeTitle.isNotEmpty) {
            recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
          }
        }
        
        // Check meal plans for recipe usage
        final mealPlansSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .get();
        
        for (final mealPlanDoc in mealPlansSnapshot.docs) {
          final data = mealPlanDoc.data();
          final meals = data['meals'] as List<dynamic>? ?? [];
          
          for (final meal in meals) {
            if (meal is Map<String, dynamic>) {
              final recipeTitle = _getRecipeTitle(meal);
              if (recipeTitle.isNotEmpty) {
                recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
              }
            }
          }
        }
        
        // Check individual meals
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meals')
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final data = mealDoc.data();
          final recipeTitle = _getRecipeTitle(data);
          if (recipeTitle.isNotEmpty) {
            recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
          }
        }
      }
      
      // Convert to list and sort by count
      final List<Map<String, dynamic>> topRecipes = recipeCounts.entries
          .map((entry) => {
                'title': entry.key,
                'count': entry.value,
                'type': _getRecipeType(entry.key),
              })
          .toList();
      
      topRecipes.sort((a, b) => b['count'].compareTo(a['count']));
      
      final result = topRecipes.take(10).toList();
      
      // Cache the result
      _cachedTopRecipes = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting top recipes: $e');
      return [];
    }
  }

  String _getRecipeTitle(Map<String, dynamic> data) {
    // Try different possible title fields
    String title = '';
    
    // Check if it's a favorite with nested recipe data
    if (data['recipe'] is Map<String, dynamic>) {
      final recipe = data['recipe'] as Map<String, dynamic>;
      title = recipe['title'] ?? 
              recipe['name'] ?? 
              recipe['recipeTitle'] ?? 
              recipe['recipeName'] ?? 
              recipe['dishName'] ?? 
              '';
    }
    
    // If still empty, try top-level fields
    if (title.isEmpty) {
      title = data['title'] ?? 
              data['name'] ?? 
              data['recipeTitle'] ?? 
              data['recipeName'] ?? 
              data['dishName'] ?? 
              data['mealName'] ?? 
              '';
    }
    
    // Clean up the title
    final cleanTitle = title.toString().trim();
    
    // If still empty, try to generate a meaningful name
    if (cleanTitle.isEmpty) {
      // Check if it's from API (Spoonacular/TheMealDB)
      if (data['source'] == 'spoonacular' || data['source'] == 'themealdb') {
        return 'API Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's a Filipino recipe
      if (data['source'] == 'filipino') {
        return 'Filipino Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's an admin recipe
      if (data['source'] == 'admin') {
        return 'Admin Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's a favorite with recipe data
      if (data['recipeId'] != null) {
        return 'Favorite Recipe #${data['recipeId']}';
      }
      
      // If we have ingredients, try to create a name
      final ingredients = data['ingredients'] as List?;
      if (ingredients != null && ingredients.isNotEmpty) {
        final firstIngredient = ingredients.first.toString();
        return 'Recipe with $firstIngredient';
      }
      
      // Check if it's a meal with a specific type
      if (data['mealType'] != null) {
        return '${data['mealType']} Recipe';
      }
      
      // Check if it has a cuisine type
      if (data['cuisine'] != null) {
        return '${data['cuisine']} Recipe';
      }
      
      // Last resort - skip this entry entirely
      return '';
    }
    
    return cleanTitle;
  }

  String _getRecipeType(String title) {
    // Determine recipe type based on title or other criteria
    if (title.toLowerCase().contains('filipino') || 
        title.toLowerCase().contains('adobo') ||
        title.toLowerCase().contains('sinigang')) {
      return 'Filipino';
    } else if (title.toLowerCase().contains('pasta') ||
               title.toLowerCase().contains('pizza')) {
      return 'Italian';
    } else if (title.toLowerCase().contains('sushi') ||
               title.toLowerCase().contains('ramen')) {
      return 'Asian';
    } else if (title.toLowerCase().contains('api recipe')) {
      return 'API';
    } else if (title.toLowerCase().contains('admin recipe')) {
      return 'Admin';
    } else {
      return 'General';
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    // Return cached data if available and valid
    if (_cachedRecentActivity != null && _isCacheValid()) {
      return _cachedRecentActivity!;
    }
    
    try {
      final List<Map<String, dynamic>> activities = [];
      
      // Get recent user registrations (this query is safe)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        activities.add({
          'type': 'user_registration',
          'title': 'New user registered: ${data['name'] ?? data['email']}',
          'timestamp': data['createdAt'],
          'icon': Icons.person_add,
          'color': Colors.green,
        });
      }
      
      // Get recent announcements (this query is safe)
      final announcementsSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      
      for (final announcementDoc in announcementsSnapshot.docs) {
        final data = announcementDoc.data();
        activities.add({
          'type': 'announcement_sent',
          'title': 'Announcement sent: ${data['title']}',
          'timestamp': data['createdAt'],
          'icon': Icons.campaign,
          'color': Colors.purple,
        });
      }
      
      // Get limited user data for meal plans and substitutions (avoid expensive queries)
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(10) // Limit to recent users only
          .get();
      
      // Get meal plans from limited users only
      for (final userDoc in allUsersSnapshot.docs) {
        try {
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .limit(2) // Limit per user
              .get();
          
          for (final mealPlanDoc in mealPlansSnapshot.docs) {
            final data = mealPlanDoc.data();
            if (data['createdAt'] != null) {
              activities.add({
                'type': 'meal_plan_created',
                'title': 'Meal plan created: ${data['name'] ?? 'Weekly Plan'}',
                'timestamp': data['createdAt'],
                'icon': Icons.restaurant_menu,
                'color': Colors.blue,
              });
            }
          }
        } catch (e) {
          // Skip this user if there's an error
          continue;
        }
      }
      
      // Get substitutions from limited users only
      for (final userDoc in allUsersSnapshot.docs) {
        try {
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .where('substituted', isEqualTo: true)
              .limit(2) // Limit per user
              .get();
          
          for (final mealDoc in mealsSnapshot.docs) {
            final data = mealDoc.data();
            final substitutions = data['substitutions'] as Map<String, dynamic>? ?? {};
            if (substitutions.isNotEmpty && data['createdAt'] != null) {
              final substitution = substitutions.values.first;
              activities.add({
                'type': 'substitution_used',
                'title': 'Substitution used: $substitution',
                'timestamp': data['createdAt'],
                'icon': Icons.swap_horiz,
                'color': Colors.orange,
              });
            }
          }
        } catch (e) {
          // Skip this user if there's an error
          continue;
        }
      }
      
      // Sort by timestamp and take the most recent
      activities.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      final result = activities.take(15).toList();
      
      // Cache the result
      _cachedRecentActivity = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    // Return cached data if available and valid
    if (_cachedAnalyticsData != null && _isCacheValid()) {
      return _cachedAnalyticsData!;
    }
    
    try {
      final now = DateTime.now();
      final timeRangeDays = _getTimeRangeDays();
      final startDate = now.subtract(Duration(days: timeRangeDays));

      // Get user metrics
      final userMetrics = await _getUserMetrics(startDate);
      
      // Get recipe metrics
      final recipeMetrics = await _getRecipeMetrics(startDate);
      
      // Get meal plan metrics
      final mealPlanMetrics = await _getMealPlanMetrics(startDate);
      
      // Get nutrition metrics
      final nutritionMetrics = await _getNutritionMetrics(startDate);

      final result = {
        'users': userMetrics,
        'recipes': recipeMetrics,
        'mealPlans': mealPlanMetrics,
        'nutrition': nutritionMetrics,
      };
      
      // Cache the result
      _cachedAnalyticsData = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting analytics data: $e');
      return {};
    }
  }

  int _getTimeRangeDays() {
    switch (_selectedTimeRange) {
      case '24 hours':
        return 1;
      case '7 days':
        return 7;
      case '30 days':
        return 30;
      case '90 days':
        return 90;
      default:
        return 7;
    }
  }

  Future<Map<String, dynamic>> _getUserMetrics(DateTime startDate) async {
    try {
      // Get total users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final totalUsers = usersSnapshot.docs.length;
      
      // Get new users in time range
      final newUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();
      
      final newUsers = newUsersSnapshot.docs.length;
      
      // Calculate growth (simplified)
      final growth = totalUsers > 0 ? (newUsers / totalUsers * 100) : 0.0;

      return {
        'total': totalUsers,
        'new': newUsers,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting user metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getRecipeMetrics(DateTime startDate) async {
    try {
      int totalFavorites = 0;
      int newFavorites = 0;

      // Query all users' favorites
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          final favoritesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .get();

          totalFavorites += favoritesSnapshot.docs.length;

          // Count new favorites in time range
          final newFavoritesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newFavorites += newFavoritesSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} favorites: $e');
        }
      }

      final growth = totalFavorites > 0 ? (newFavorites / totalFavorites * 100) : 0.0;

      return {
        'total': totalFavorites,
        'new': newFavorites,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting recipe metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getMealPlanMetrics(DateTime startDate) async {
    try {
      int totalMealPlans = 0;
      int newMealPlans = 0;

      // Query all users' meal plans
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .get();

          totalMealPlans += mealPlansSnapshot.docs.length;

          // Count new meal plans in time range
          final newMealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newMealPlans += newMealPlansSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} meal plans: $e');
        }
      }

      final growth = totalMealPlans > 0 ? (newMealPlans / totalMealPlans * 100) : 0.0;

      return {
        'total': totalMealPlans,
        'new': newMealPlans,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting meal plan metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getNutritionMetrics(DateTime startDate) async {
    try {
      int totalNutritionEntries = 0;
      int newNutritionEntries = 0;

      // Query all users' nutrition data
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          // Check meals collection for nutrition entries
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .get();

          totalNutritionEntries += mealsSnapshot.docs.length;

          // Count new nutrition entries in time range
          final newMealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newNutritionEntries += newMealsSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} nutrition data: $e');
        }
      }

      final growth = totalNutritionEntries > 0 ? (newNutritionEntries / totalNutritionEntries * 100) : 0.0;

      return {
        'total': totalNutritionEntries,
        'new': newNutritionEntries,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting nutrition metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  String _calculateGrowth(dynamic growth) {
    if (growth == null) return '+0%';
    final growthValue = growth is double ? growth : (growth as num).toDouble();
    final sign = growthValue >= 0 ? '+' : '';
    return '$sign${growthValue.toStringAsFixed(1)}%';
  }

  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUserRegistrationTrends() async {
    try {
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();
      
      // Get registration data for the last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
            .get();
        
        trends.add({
          'date': DateFormat('MMM dd').format(date),
          'count': snapshot.docs.length,
        });
      }
      
      return trends;
    } catch (e) {
      print('Error getting registration trends: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getAllergenStats() async {
    try {
      final allergenCounts = <String, int>{};
      
      // Query all users to get their allergens
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final allergies = userData['allergies'] as List<dynamic>? ?? [];
          
          for (final allergy in allergies) {
            if (allergy.toString().toLowerCase() != 'none') {
              allergenCounts[allergy.toString()] = (allergenCounts[allergy.toString()] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('Error processing user ${userDoc.id} allergens: $e');
        }
      }
      
      // Convert to list and sort by count
      final allergenList = allergenCounts.entries.map((entry) {
        return {
          'name': entry.key,
          'count': entry.value,
          'icon': _getAllergenIcon(entry.key),
        };
      }).toList();
      
      allergenList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return allergenList;
    } catch (e) {
      print('Error getting allergen stats: $e');
      return [];
    }
  }

  String _getAllergenIcon(String allergen) {
    final lowerAllergen = allergen.toLowerCase();
    if (lowerAllergen.contains('dairy') || lowerAllergen.contains('milk')) {
      return '🥛';
    } else if (lowerAllergen.contains('egg')) {
      return '🥚';
    } else if (lowerAllergen.contains('fish')) {
      return '🐟';
    } else if (lowerAllergen.contains('shellfish')) {
      return '🦐';
    } else if (lowerAllergen.contains('nut')) {
      return '🥜';
    } else if (lowerAllergen.contains('wheat') || lowerAllergen.contains('gluten')) {
      return '🌾';
    } else if (lowerAllergen.contains('soy')) {
      return '🫘';
    } else if (lowerAllergen.contains('sesame')) {
      return '🌰';
    }
    return '⚠️';
  }
}
