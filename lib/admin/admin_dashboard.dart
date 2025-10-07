import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/users_management_page.dart';
import 'pages/recipes_management_page.dart';
import 'pages/substitutions_management_page.dart';
import 'pages/analytics_page.dart';
import 'pages/announcements_page.dart';
import 'pages/curated_content_management_page.dart';
import 'pages/nutritionist_dashboard_page.dart';
import 'pages/expert_meal_plan_creation_page.dart';
import 'pages/allergen_validation_page.dart';
import 'pages/guidelines_editor_page.dart';
import 'pages/content_creation_page.dart';
import 'pages/notification_center_page.dart';
import 'pages/nutritional_data_validation_page.dart';
import '../services/curated_data_migration_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _migrationChecked = false;
  String? _userEmail;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkMigration();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userEmail = user.email;

        // Get user role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          _userRole = userData?['role'] ?? 'User';
        } else {
          _userRole = 'User';
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error getting user info: $e');
      _userRole = 'User';
    }
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

  List<AdminPage> get _pages {
    if (_userRole == 'Nutritionist') {
      return [
        AdminPage(
          title: 'Nutritionist Dashboard',
          icon: Icons.medical_services,
          widget: const NutritionistDashboardPage(),
        ),
        AdminPage(
          title: 'Create Expert Meal Plans',
          icon: Icons.restaurant_menu,
          widget: const ExpertMealPlanCreationPage(),
        ),
        AdminPage(
          title: 'Allergen and Substitution Validation',
          icon: Icons.warning,
          widget: const AllergenValidationPage(),
        ),
        AdminPage(
          title: 'Nutritional Data Validation',
          icon: Icons.analytics,
          widget: const NutritionalDataValidationPage(),
        ),
        AdminPage(
          title: 'Edit Guidelines',
          icon: Icons.edit_note,
          widget: const GuidelinesEditorPage(),
        ),
        AdminPage(
          title: 'Send Content',
          icon: Icons.school,
          widget: const ContentCreationPage(),
        ),
        AdminPage(
          title: 'Notifications',
          icon: Icons.notifications,
          widget: const NotificationCenterPage(),
        ),
      ];
    } else {
      // Admin pages
      return [
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF8BC34A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _userRole == 'Nutritionist'
                              ? Icons.medical_services
                              : Icons.admin_panel_settings,
                          size: 32,
                          color: _userRole == 'Nutritionist'
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        _userRole == 'Nutritionist'
                            ? 'SmartDiet Nutritionist'
                            : 'SmartDiet Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // Subtitle
                      Text(
                        'Real-time Analytics & Management',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // User Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // User Email
                            Text(
                              _userEmail ??
                                  FirebaseAuth.instance.currentUser?.email ??
                                  '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Role Badge
                            if (_userRole != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _userRole == 'Nutritionist'
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _userRole!,
                                  style: TextStyle(
                                    color: _userRole == 'Nutritionist'
                                        ? Colors.blue.shade300
                                        : Colors.green.shade300,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Check Migration Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final needsMigration =
                                  await CuratedDataMigrationService.needsMigration();
                              if (needsMigration) {
                                _showMigrationDialog();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'No migration needed - data is already up to date!'),
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
                          label: const Text(
                            'Check Migration',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            page.icon,
                            color: isSelected
                                ? Colors.white
                                : Colors.white70,
                          ),
                          title: Text(
                            page.title,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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

class _DashboardOverviewPageState extends State<DashboardOverviewPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF8BC34A),
              Color(0xFFCDDC39),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Quick Stats Row
                        _buildQuickStatsRow(),
                        const SizedBox(height: 24),
                        
                        // Main Content Grid
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getDashboardStats().timeout(
                            const Duration(seconds: 10),
                            onTimeout: () {
                              print('DEBUG: Dashboard stats fetch timed out');
                              return <String, dynamic>{
                                'totalUsers': 0,
                                'newUsersToday': 0,
                                'totalFavorites': 0,
                                'newFavoritesToday': 0,
                                'totalMealPlans': 0,
                                'newMealPlansToday': 0,
                                'totalNotifications': 0,
                                'notificationsToday': 0,
                                'totalNutritionEntries': 0,
                                'nutritionEntriesToday': 0,
                                'topAllergen': 'None',
                                'allergenCount': 0,
                              };
                            },
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return _buildLoadingGrid();
                            }
                            
                            if (snapshot.hasError) {
                              return _buildErrorState(snapshot.error.toString());
                            }
                            
                            final stats = snapshot.data ?? {};
                            print('DEBUG: Dashboard stats loaded: $stats');
                            return _buildMainContent(stats);
                          },
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getQuickStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildLoadingCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildLoadingCard()),
            ],
          );
        }
        
        final stats = snapshot.data ?? {};
        
        return Row(
          children: [
            Expanded(
              child: _buildQuickStatCard(
                'Active Users',
                '${stats['totalUsers'] ?? 0}',
                Icons.people,
                const Color(0xFF4CAF50),
                '+${stats['newUsersToday'] ?? 0} today',
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickStatCard(
                'Recipes',
                '${stats['totalRecipes'] ?? 0}',
                Icons.restaurant,
                const Color(0xFF2196F3),
                '+${stats['newRecipesToday'] ?? 0} today',
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickStatCard(
                'Meal Plans',
                '${stats['totalMealPlans'] ?? 0}',
                Icons.calendar_today,
                const Color(0xFFFF9800),
                '+${stats['newMealPlansToday'] ?? 0} today',
                true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
              color: Color(0xFF2D3748),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(Map<String, dynamic> stats) {
    return Column(
      children: [
        // Top Row - Key Metrics
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildMetricCard(
                'User Growth',
                '${stats['totalUsers'] ?? 0}',
                '${stats['newUsersToday'] ?? 0} new today',
                Icons.trending_up,
                const Color(0xFF4CAF50),
                const Color(0xFFE8F5E8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildMetricCard(
                'Recipe Engagement',
                '${stats['totalFavorites'] ?? 0}',
                '${stats['newFavoritesToday'] ?? 0} favorites today',
                Icons.favorite,
                const Color(0xFFE91E63),
                const Color(0xFFFCE4EC),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildMetricCard(
                'Meal Planning',
                '${stats['totalMealPlans'] ?? 0}',
                '${stats['newMealPlansToday'] ?? 0} created today',
                Icons.calendar_today,
                const Color(0xFF2196F3),
                const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Middle Row - Charts and Analytics
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildChartCard('User Activity', stats),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildAllergenCard(stats),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Bottom Row - Additional Metrics
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Notifications',
                '${stats['totalNotifications'] ?? 0}',
                '${stats['notificationsToday'] ?? 0} sent today',
                Icons.notifications,
                const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                'Nutrition Tracking',
                '${stats['totalNutritionEntries'] ?? 0}',
                '${stats['nutritionEntriesToday'] ?? 0} logged today',
                Icons.analytics,
                const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                'Top Allergen',
                '${stats['topAllergen'] ?? 'None'}',
                '${stats['allergenCount'] ?? 0} users affected',
                Icons.warning,
                const Color(0xFFFF5722),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'User Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Simple bar chart representation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBar(0.8, 'Mon'),
              _buildBar(0.6, 'Tue'),
              _buildBar(0.9, 'Wed'),
              _buildBar(0.7, 'Thu'),
              _buildBar(0.95, 'Fri'),
              _buildBar(0.85, 'Sat'),
              _buildBar(0.6, 'Sun'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Users',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 24),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'New Users',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, String label) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 80 * height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAllergenCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allergen Alert',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red.shade600,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats['topAllergen'] ?? 'None'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                Text(
                  '${stats['allergenCount'] ?? 0} users affected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(flex: 3, child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildLoadingCard()),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingCard()),
          ],
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getQuickStats() async {
    try {
      print('DEBUG: Fetching quick stats...');
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Get users count
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final newUsersToday = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();
      
      // Get recipes count (from admin_recipes collection)
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      // Get meal plans count (quick estimate from first few users)
      int totalMealPlans = 0;
      int newMealPlansToday = 0;
      
      // Sample first 5 users for meal plans to avoid timeout
      final sampleUsers = usersSnapshot.docs.take(5);
      for (final userDoc in sampleUsers) {
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
      
      // Scale up meal plans estimate based on sample
      if (usersSnapshot.docs.length > 5) {
        final scaleFactor = usersSnapshot.docs.length / 5;
        totalMealPlans = (totalMealPlans * scaleFactor).round();
        newMealPlansToday = (newMealPlansToday * scaleFactor).round();
      }
      
      final result = {
        'totalUsers': usersSnapshot.docs.length,
        'newUsersToday': newUsersToday.docs.length,
        'totalRecipes': recipesSnapshot.docs.length,
        'newRecipesToday': 0, // We don't track recipe creation date yet
        'totalMealPlans': totalMealPlans,
        'newMealPlansToday': newMealPlansToday,
      };
      
      print('DEBUG: Quick stats result: $result');
      return result;
    } catch (e) {
      print('Error getting quick stats: $e');
      return {
        'totalUsers': 0,
        'newUsersToday': 0,
        'totalRecipes': 0,
        'newRecipesToday': 0,
        'totalMealPlans': 0,
        'newMealPlansToday': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _getDashboardStats() async {
    try {
      print('DEBUG: Starting dashboard stats fetch...');
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Get total users and new users today
      print('DEBUG: Fetching users...');
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      print('DEBUG: Found ${usersSnapshot.docs.length} users');
      
      final newUsersToday = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();
      
      print('DEBUG: Found ${newUsersToday.docs.length} new users today');

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

      final result = {
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
      
      print('DEBUG: Dashboard stats result: $result');
      return result;
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {};
    }
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
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
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to Load Dashboard Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
