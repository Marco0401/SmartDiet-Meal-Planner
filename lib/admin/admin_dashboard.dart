import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/users_management_page.dart';
import 'pages/recipes_management_page.dart';
import 'pages/substitutions_management_page.dart';
import 'pages/analytics_page.dart';
import 'pages/announcements_page.dart';
import 'pages/curated_content_management_page.dart';
import '../services/curated_data_migration_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _migrationChecked = false;
  
  @override
  void initState() {
    super.initState();
    _checkMigration();
  }

  Future<void> _checkMigration() async {
    if (_migrationChecked) return;
    
    try {
      print('DEBUG: Checking migration status...');
      final needsMigration = await CuratedDataMigrationService.needsMigration();
      print('DEBUG: Migration needed: $needsMigration');
      
      if (needsMigration && mounted) {
        print('DEBUG: Showing migration dialog');
        _showMigrationDialog();
      } else {
        print('DEBUG: No migration needed or not mounted');
      }
    } catch (e) {
      print('Error checking migration: $e');
    }
    
    setState(() {
      _migrationChecked = true;
    });
  }

  void _showMigrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('Data Migration Required'),
          ],
        ),
        content: const Text(
          'Curated content needs to be migrated to Firestore to enable editing. '
          'This will move hardcoded data to the database for better management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _runMigration();
            },
            child: const Text('Migrate Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _runMigration() async {
    try {
      await CuratedDataMigrationService.runAllMigrations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Migration completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final List<AdminPage> _pages = [
    AdminPage(
      title: 'Dashboard Overview',
      icon: Icons.dashboard,
      widget: const DashboardOverviewPage(),
    ),
    AdminPage(
      title: 'Manage Users',
      icon: Icons.people,
      widget: const UsersManagementPage(),
    ),
    AdminPage(
      title: 'Manage Recipes',
      icon: Icons.restaurant_menu,
      widget: const RecipesManagementPage(),
    ),
    AdminPage(
      title: 'Manage Substitutions',
      icon: Icons.swap_horiz,
      widget: const SubstitutionsManagementPage(),
    ),
    AdminPage(
      title: 'Analytics & Reports',
      icon: Icons.analytics,
      widget: const AnalyticsPage(),
    ),
    AdminPage(
      title: 'Announcements',
      icon: Icons.campaign,
      widget: const AnnouncementsPage(),
    ),
    AdminPage(
      title: 'Curated Content',
      icon: Icons.edit_note,
      widget: const CuratedContentManagementPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.admin_panel_settings,
                          size: 30,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Migration Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final needsMigration = await CuratedDataMigrationService.needsMigration();
                        if (needsMigration) {
                          _showMigrationDialog();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No migration needed - data is already up to date!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error checking migration: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.system_update, size: 16),
                    label: const Text('Check Migration', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                
                const Divider(color: Colors.white24),
                
                // Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final isSelected = index == _selectedIndex;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.1) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(
                            page.icon,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                          title: Text(
                            page.title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                const Divider(color: Colors.white24),
                
                // Logout Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: _pages[_selectedIndex].widget,
          ),
        ],
      ),
    );
  }
}

class AdminPage {
  final String title;
  final IconData icon;
  final Widget widget;

  AdminPage({
    required this.title,
    required this.icon,
    required this.widget,
  });
}

class DashboardOverviewPage extends StatefulWidget {
  const DashboardOverviewPage({super.key});

  @override
  State<DashboardOverviewPage> createState() => _DashboardOverviewPageState();
}

class _DashboardOverviewPageState extends State<DashboardOverviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {}); // Refresh
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Dashboard',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Welcome to SmartDiet Admin Dashboard',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor your app performance, manage users, and track key metrics.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            
            // Real-time Stats Cards
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getDashboardStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: List.generate(6, (index) => _buildLoadingCard()),
                    );
                  }

                  final stats = snapshot.data ?? {};
                  
                  return GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Total Users',
                        '${stats['totalUsers'] ?? 0}',
                        Icons.people,
                        Colors.blue,
                        '${stats['newUsersToday'] ?? 0} new today',
                      ),
                      _buildStatCard(
                        'Favorite Recipes',
                        '${stats['totalFavorites'] ?? 0}',
                        Icons.favorite,
                        Colors.red,
                        '${stats['newFavoritesToday'] ?? 0} added today',
                      ),
                      _buildStatCard(
                        'Active Meal Plans',
                        '${stats['totalMealPlans'] ?? 0}',
                        Icons.calendar_today,
                        Colors.green,
                        '${stats['newMealPlansToday'] ?? 0} created today',
                      ),
                      _buildStatCard(
                        'Notifications Sent',
                        '${stats['totalNotifications'] ?? 0}',
                        Icons.notifications,
                        Colors.purple,
                        '${stats['notificationsToday'] ?? 0} sent today',
                      ),
                      _buildStatCard(
                        'Nutrition Entries',
                        '${stats['totalNutritionEntries'] ?? 0}',
                        Icons.analytics,
                        Colors.orange,
                        '${stats['nutritionEntriesToday'] ?? 0} logged today',
                      ),
                      _buildStatCard(
                        'Common Allergen',
                        '${stats['topAllergen'] ?? 'None'}',
                        Icons.warning,
                        Colors.amber,
                        '${stats['allergenCount'] ?? 0} users affected',
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getDashboardStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Get total users and new users today
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final newUsersToday = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      // Get total favorites and new favorites today
      int totalFavorites = 0;
      int newFavoritesToday = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final favoritesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .get();
          
          totalFavorites += favoritesSnapshot.docs.length;
          
          final newFavorites = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startOfDay))
              .get();
          
          newFavoritesToday += newFavorites.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} favorites: $e');
        }
      }

      // Get meal plans stats
      int totalMealPlans = 0;
      int newMealPlansToday = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .get();
          
          totalMealPlans += mealPlansSnapshot.docs.length;
          
          final newMealPlans = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
              .get();
          
          newMealPlansToday += newMealPlans.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} meal plans: $e');
        }
      }

      // Get notifications stats
      int totalNotifications = 0;
      int notificationsToday = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final notificationsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('notifications')
              .get();
          
          totalNotifications += notificationsSnapshot.docs.length;
          
          final todayNotifications = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('notifications')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
              .get();
          
          notificationsToday += todayNotifications.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} notifications: $e');
        }
      }

      // Get nutrition entries stats
      int totalNutritionEntries = 0;
      int nutritionEntriesToday = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .get();
          
          totalNutritionEntries += mealsSnapshot.docs.length;
          
          final todayMeals = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startOfDay))
              .get();
          
          nutritionEntriesToday += todayMeals.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} meals: $e');
        }
      }

      // Get most common allergen
      final allergenCounts = <String, int>{};
      
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
      
      String topAllergen = 'None';
      int allergenCount = 0;
      
      if (allergenCounts.isNotEmpty) {
        final sortedAllergens = allergenCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        topAllergen = sortedAllergens.first.key;
        allergenCount = sortedAllergens.first.value;
      }

      return {
        'totalUsers': usersSnapshot.docs.length,
        'newUsersToday': newUsersToday.docs.length,
        'totalFavorites': totalFavorites,
        'newFavoritesToday': newFavoritesToday,
        'totalMealPlans': totalMealPlans,
        'newMealPlansToday': newMealPlansToday,
        'totalNotifications': totalNotifications,
        'notificationsToday': notificationsToday,
        'totalNutritionEntries': totalNutritionEntries,
        'nutritionEntriesToday': nutritionEntriesToday,
        'topAllergen': topAllergen,
        'allergenCount': allergenCount,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {};
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, [String? subtitle]) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 10,
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
}
