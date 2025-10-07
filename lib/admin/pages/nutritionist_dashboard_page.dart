import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_plan_review_page.dart';
import 'allergen_validation_page.dart';
import 'guidelines_editor_page.dart';
import 'content_creation_page.dart';
import 'notification_center_page.dart';

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
                // Quick Stats Row
                _buildQuickStatsRow(),
                const SizedBox(height: 24),

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


  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Meal Plans to Review',
            '12',
            Icons.assignment,
            const Color(0xFF2196F3),
            '3 pending',
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickStatCard(
            'Allergen Validations',
            '8',
            Icons.warning,
            const Color(0xFFFF9800),
            '2 flagged',
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickStatCard(
            'Guidelines Updated',
            '5',
            Icons.edit_note,
            const Color(0xFF9C27B0),
            'This week',
            true,
          ),
        ),
      ],
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
                'Meal Plans Reviewed',
                '${stats['reviewedMealPlans'] ?? 0}',
                '${stats['pendingMealPlans'] ?? 0} pending review',
                Icons.assignment_turned_in,
                const Color(0xFF4CAF50),
                const Color(0xFFE8F5E8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildMetricCard(
                'Allergen Validations',
                '${stats['validatedAllergens'] ?? 0}',
                '${stats['flaggedAllergens'] ?? 0} flagged for review',
                Icons.warning,
                const Color(0xFFFF9800),
                const Color(0xFFFFF3E0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildMetricCard(
                'Guidelines Updated',
                '${stats['updatedGuidelines'] ?? 0}',
                '${stats['recentUpdates'] ?? 0} this week',
                Icons.edit_note,
                const Color(0xFF9C27B0),
                const Color(0xFFF3E5F5),
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
              child: _buildChartCard('Nutritional Compliance', stats),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildAllergenAlertCard(stats),
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
                'Nutritional Compliance',
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
              _buildBar(0.9, 'Mon'),
              _buildBar(0.7, 'Tue'),
              _buildBar(0.8, 'Wed'),
              _buildBar(0.6, 'Thu'),
              _buildBar(0.85, 'Fri'),
              _buildBar(0.75, 'Sat'),
              _buildBar(0.8, 'Sun'),
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
                'Compliant',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 24),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF9800),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Needs Review',
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

  Widget _buildAllergenAlertCard(Map<String, dynamic> stats) {
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
            'Allergen Alerts',
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange.shade600,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats['flaggedAllergens'] ?? 0}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
                Text(
                  'items need validation',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        print('DEBUG: Action card tapped: $title');
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
      
      // Get all users first, then check their meal plans
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      int pendingMealPlans = 0;
      int approvedMealPlans = 0;
      
      // Check meal plans for each user (since collection group query needs index)
      for (final userDoc in usersSnapshot.docs) {
        try {
          final pendingSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('status', isEqualTo: 'pending_review')
              .get();
          pendingMealPlans += pendingSnapshot.docs.length;
          
          final approvedSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('status', isEqualTo: 'approved')
              .get();
          approvedMealPlans += approvedSnapshot.docs.length;
        } catch (e) {
          print('Error checking meal plans for user ${userDoc.id}: $e');
        }
      }
      
      // Get allergen validations
      final allergenValidationsSnapshot = await FirebaseFirestore.instance
          .collection('allergen_validations')
          .where('status', isEqualTo: 'validated')
          .get();
      
      // Get flagged allergens
      final flaggedAllergensSnapshot = await FirebaseFirestore.instance
          .collection('allergen_validations')
          .where('status', isEqualTo: 'flagged')
          .get();
      
      // Get nutritional guidelines updates
      final guidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();
      
      // Get recent guidelines updates (this week)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentGuidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .where('lastUpdated', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();
      
      final result = {
        'reviewedMealPlans': approvedMealPlans,
        'pendingMealPlans': pendingMealPlans,
        'validatedAllergens': allergenValidationsSnapshot.docs.length,
        'flaggedAllergens': flaggedAllergensSnapshot.docs.length,
        'updatedGuidelines': guidelinesSnapshot.docs.length,
        'recentUpdates': recentGuidelinesSnapshot.docs.length,
      };
      
      print('DEBUG: Nutritionist stats result: $result');
      return result;
    } catch (e) {
      print('Error getting nutritionist stats: $e');
      return {
        'reviewedMealPlans': 0,
        'pendingMealPlans': 0,
        'validatedAllergens': 0,
        'flaggedAllergens': 0,
        'updatedGuidelines': 0,
        'recentUpdates': 0,
      };
    }
  }

  // Navigation methods
  void _navigateToMealPlanReview() {
    print('DEBUG: Navigating to Meal Plan Review page');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MealPlanReviewPage(),
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
}
