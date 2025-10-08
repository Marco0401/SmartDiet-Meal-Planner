import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expert_meal_plan_creation_page.dart';
import 'allergen_validation_page.dart';
import 'guidelines_editor_page.dart';
import 'content_creation_page.dart';
import 'notification_center_page.dart';
import 'nutritional_data_validation_page.dart';

class NutritionistDashboardPage extends StatefulWidget {
  const NutritionistDashboardPage({super.key});

  @override
  State<NutritionistDashboardPage> createState() => _NutritionistDashboardPageState();
}

class _NutritionistDashboardPageState extends State<NutritionistDashboardPage> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
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
      child: CustomScrollView(
        slivers: [
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Main Content Grid
                FutureBuilder<Map<String, dynamic>>(
                  future: _getNutritionistStats(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingGrid();
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    }

                    final stats = snapshot.data ?? {};
                    return _buildMainContent(stats);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
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
              child: _buildEnhancedMetricCard(
                'Expert Meal Plans',
                '${stats['expertMealPlans'] ?? 0}',
                '${stats['recentMealPlans'] ?? 0} created recently',
                Icons.restaurant_menu,
                const Color(0xFF4CAF50),
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnhancedMetricCard(
                'Allergen Validations',
                '${stats['validatedAllergens'] ?? 0}',
                '${stats['flaggedAllergens'] ?? 0} need validation',
                Icons.warning_amber_rounded,
                const Color(0xFFFF9800),
                Icons.shield_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEnhancedMetricCard(
                'Guidelines Updated',
                '${stats['updatedGuidelines'] ?? 0}',
                '${stats['recentUpdates'] ?? 0} this week',
                Icons.edit_note,
                const Color(0xFF9C27B0),
                Icons.auto_graph,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Quick Actions Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Navigation Cards Grid
        Row(
          children: [
            Expanded(
              child: _buildModernActionCard(
                'Create Expert Meal Plans',
                'Design personalized meal plans for users',
                Icons.restaurant_menu,
                const Color(0xFF4CAF50),
                _navigateToExpertMealPlans,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernActionCard(
                'Allergen & Substitution',
                'Validate allergen detection system',
                Icons.verified_user,
                const Color(0xFFFF9800),
                _navigateToAllergenValidation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernActionCard(
                'Nutritional Guidelines',
                'Edit and manage nutrition rules',
                Icons.psychology,
                const Color(0xFF9C27B0),
                _navigateToGuidelinesEditor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernActionCard(
                'Nutritional Data',
                'Validate recipe nutrition values',
                Icons.science,
                const Color(0xFF2196F3),
                _navigateToNutritionalDataValidation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernActionCard(
                'Content Creation',
                'Create educational content',
                Icons.create,
                const Color(0xFF00BCD4),
                _navigateToContentCreation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernActionCard(
                'Notification Center',
                'Manage user notifications',
                Icons.notifications_active,
                const Color(0xFF607D8B),
                _navigateToNotificationCenter,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedMetricCard(String title, String value, String subtitle, IconData icon, Color color, IconData trendIcon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(trendIcon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionCard(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
            'Failed to Load Nutritionist Data',
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
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getNutritionistStats() async {
    try {
      print('DEBUG: Fetching nutritionist stats...');
      
      // Get expert meal plans
      final expertMealPlansSnapshot = await FirebaseFirestore.instance
          .collection('expert_meal_plans')
          .get();
      
      // Get recent expert meal plans (this week)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentMealPlansSnapshot = await FirebaseFirestore.instance
          .collection('expert_meal_plans')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();
      
      // Get allergen validations from system_data
      final validationDoc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('validation_status')
          .get();
      
      int validatedAllergens = 0;
      int flaggedAllergens = 0;
      
      if (validationDoc.exists) {
        final data = validationDoc.data() ?? {};
        final allergensData = data['allergens'] as Map<String, dynamic>? ?? {};
        final substitutionsData = data['substitutions'] as Map<String, dynamic>? ?? {};
        
        // Count validated allergens
        allergensData.forEach((key, value) {
          if (value['validated'] == true) validatedAllergens++;
        });
        
        // Count validated substitutions
        substitutionsData.forEach((key, value) {
          if (value['validated'] == true) validatedAllergens++;
        });
        
        // For flagged, we'll show items that need validation
        flaggedAllergens = (allergensData.length + substitutionsData.length) - validatedAllergens;
      }
      
      // Get nutritional guidelines updates
      final guidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .get();
      
      // Get recent guidelines updates (this week)
      final recentGuidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();
      
      final result = {
        'expertMealPlans': expertMealPlansSnapshot.docs.length,
        'recentMealPlans': recentMealPlansSnapshot.docs.length,
        'validatedAllergens': validatedAllergens,
        'flaggedAllergens': flaggedAllergens,
        'updatedGuidelines': guidelinesSnapshot.docs.length,
        'recentUpdates': recentGuidelinesSnapshot.docs.length,
      };
      
      print('DEBUG: Nutritionist stats result: $result');
      return result;
    } catch (e) {
      print('Error getting nutritionist stats: $e');
      return {
        'expertMealPlans': 0,
        'recentMealPlans': 0,
        'validatedAllergens': 0,
        'flaggedAllergens': 0,
        'updatedGuidelines': 0,
        'recentUpdates': 0,
      };
    }
  }

  // Navigation methods
  void _navigateToExpertMealPlans() {
    print('DEBUG: Navigating to Expert Meal Plan Creation page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ExpertMealPlanCreationPage(),
        ),
      );
      print('DEBUG: Navigation successful');
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAllergenValidation() {
    print('DEBUG: Navigating to Allergen Validation page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AllergenValidationPage(),
        ),
      );
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToGuidelinesEditor() {
    print('DEBUG: Navigating to Guidelines Editor page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const GuidelinesEditorPage(),
        ),
      );
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToContentCreation() {
    print('DEBUG: Navigating to Content Creation page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ContentCreationPage(),
        ),
      );
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToNotificationCenter() {
    print('DEBUG: Navigating to Notification Center page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationCenterPage(),
        ),
      );
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToNutritionalDataValidation() {
    print('DEBUG: Navigating to Nutritional Data Validation page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NutritionalDataValidationPage(),
        ),
      );
    } catch (e) {
      print('DEBUG: Navigation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
