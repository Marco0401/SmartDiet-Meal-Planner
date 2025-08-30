import 'package:flutter/material.dart';
import 'ai_meal_planner_page.dart';

class AIMealPlannerDemoPage extends StatelessWidget {
  const AIMealPlannerDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Meal Planner Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIMealPlannerPage(),
                ),
              );
            },
            child: const Text(
              'Try Real Planner',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI-Powered Meal Planning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get personalized meal plans based on your goals, preferences, and health profile',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Features Section
            const Text(
              'How It Works',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              Icons.analytics,
              'Smart Analysis',
              'Analyzes your age, weight, height, activity level, and health conditions to calculate your optimal daily calorie needs.',
              Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              Icons.flag,
              'Goal-Based Planning',
              'Creates meal plans tailored to your specific goals: weight loss, muscle building, maintenance, or healthy eating.',
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              Icons.restaurant_menu,
              'Personalized Recipes',
              'Selects recipes that match your dietary preferences, allergies, and nutritional requirements.',
              Colors.green,
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              Icons.track_changes,
              'Nutritional Tracking',
              'Provides detailed nutritional breakdowns and portion recommendations to meet your daily targets.',
              Colors.purple,
            ),
            const SizedBox(height: 16),

            // Sample Data Section
            const Text(
              'Sample Analysis',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSampleAnalysisCard(
              'Sample User Profile',
              [
                'Age: 28 years',
                'Height: 170 cm',
                'Weight: 70 kg',
                'Goal: Lose weight',
                'Activity: Moderately active',
                'BMI: 24.2 (Normal weight)',
              ],
              Colors.green,
            ),
            const SizedBox(height: 16),
            _buildSampleAnalysisCard(
              'Calculated Nutritional Goals',
              [
                'Daily Calories: 1,850',
                'Protein: 139g (30%)',
                'Carbohydrates: 208g (45%)',
                'Fat: 62g (25%)',
                'Fiber: 25g',
              ],
              Colors.blue,
            ),
            const SizedBox(height: 16),

            // Sample Meal Plan
            const Text(
              'Sample Meal Plan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSampleMealPlanCard(),
            const SizedBox(height: 24),

            // CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIMealPlannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.psychology),
                label: const Text('Start Your AI Meal Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
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
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
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

  Widget _buildSampleAnalysisCard(
    String title,
    List<String> items,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: const TextStyle(fontSize: 16),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleMealPlanCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day 1',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '1,850 calories',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sample Meals
          _buildSampleMealTile(
            'Breakfast',
            'Protein Oatmeal Bowl',
            'Oatmeal with Greek yogurt, berries, and nuts',
            '555 cal',
            Colors.orange,
            Icons.wb_sunny,
          ),
          _buildSampleMealTile(
            'Lunch',
            'Grilled Chicken Salad',
            'Mixed greens with quinoa and vegetables',
            '648 cal',
            Colors.green,
            Icons.restaurant,
          ),
          _buildSampleMealTile(
            'Dinner',
            'Salmon with Brown Rice',
            'Grilled salmon with broccoli and brown rice',
            '647 cal',
            Colors.purple,
            Icons.nights_stay,
          ),
        ],
      ),
    );
  }

  Widget _buildSampleMealTile(
    String mealType,
    String title,
    String description,
    String calories,
    Color color,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            calories,
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 