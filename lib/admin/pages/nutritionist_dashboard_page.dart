import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionistDashboardPage extends StatefulWidget {
  const NutritionistDashboardPage({super.key});

  @override
  State<NutritionistDashboardPage> createState() => _NutritionistDashboardPageState();
}

class _NutritionistDashboardPageState extends State<NutritionistDashboardPage> with TickerProviderStateMixin {
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
                  // Nutritionist Header
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4CAF50),
                              Color(0xFF8BC34A),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.medical_services,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Nutritionist Dashboard',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Professional Nutrition Management & Review',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    tooltip: 'Refresh Dashboard',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
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
          ),
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
        const SizedBox(height: 24),
        
        // Bottom Row - Action Cards
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Review Meal Plans',
                'Review and approve user meal plans',
                Icons.assignment,
                const Color(0xFF2196F3),
                () => _navigateToMealPlanReview(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Validate Allergens',
                'Check and validate allergen detections',
                Icons.warning,
                const Color(0xFFFF9800),
                () => _navigateToAllergenValidation(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Edit Guidelines',
                'Update nutritional guidelines and standards',
                Icons.edit_note,
                const Color(0xFF9C27B0),
                () => _navigateToGuidelinesEditor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Communication Row
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Send Educational Content',
                'Share nutrition tips and educational materials',
                Icons.school,
                const Color(0xFF4CAF50),
                () => _navigateToContentCreation(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Send Notifications',
                'Broadcast important updates to users',
                Icons.notifications,
                const Color(0xFFE91E63),
                () => _navigateToNotificationCenter(),
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
      onTap: onTap,
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
      
      // Get meal plans that need review
      final mealPlansSnapshot = await FirebaseFirestore.instance
          .collectionGroup('meal_plans')
          .where('status', isEqualTo: 'pending_review')
          .get();
      
      // Get allergen validations
      final allergenValidationsSnapshot = await FirebaseFirestore.instance
          .collection('allergen_validations')
          .get();
      
      // Get nutritional guidelines updates
      final guidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();
      
      final result = {
        'reviewedMealPlans': 45, // Mock data for now
        'pendingMealPlans': mealPlansSnapshot.docs.length,
        'validatedAllergens': 32, // Mock data
        'flaggedAllergens': allergenValidationsSnapshot.docs.length,
        'updatedGuidelines': guidelinesSnapshot.docs.length,
        'recentUpdates': 3, // Mock data
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meal Plan Review - Coming Soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _navigateToAllergenValidation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Allergen Validation - Coming Soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _navigateToGuidelinesEditor() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guidelines Editor - Coming Soon!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _navigateToContentCreation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content Creation - Coming Soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _navigateToNotificationCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification Center - Coming Soon!'),
        backgroundColor: Colors.pink,
      ),
    );
  }
}
