import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_profile.dart';

class NutritionAnalyticsPage extends StatefulWidget {
  const NutritionAnalyticsPage({super.key});

  @override
  State<NutritionAnalyticsPage> createState() => _NutritionAnalyticsPageState();
}

class _NutritionAnalyticsPageState extends State<NutritionAnalyticsPage> 
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  
  // Tab controller
  late TabController _tabController;
  
  // Profile analysis data
  UserProfile? _userProfile;
  Map<String, dynamic>? _calculatedAnalysis;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Analytics'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Nutritional Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Profile Analysis', icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildWeekNavigation(startOfWeek),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Nutritional Analytics Tab
                _buildNutritionalAnalyticsTab(startOfWeek),
                // Profile Analysis Tab
                _buildProfileAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }
      
      print('Loading profile for user: ${user.uid}');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        print('User profile found, data: ${doc.data()}');
        setState(() {
          _userProfile = UserProfile.fromMap(doc.data()!);
          _calculatedAnalysis = _calculateUserAnalysis(_userProfile!);
        });
        print('Profile loaded successfully');
      } else {
        print('User profile not found in Firestore');
        // Create a default profile for testing
        setState(() {
          _userProfile = UserProfile(
            uid: user.uid,
            fullName: 'Test User',
            age: 25,
            gender: 'Male',
            height: 175,
            weight: 70,
            activityLevel: 'Moderately Active',
            goal: 'Maintain Weight',
            allergies: [],
            healthConditions: [],
            dietaryPreferences: [],
            notifications: [],
          );
          _calculatedAnalysis = _calculateUserAnalysis(_userProfile!);
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      // Create a default profile for testing
      setState(() {
        _userProfile = UserProfile(
          uid: 'test-uid',
          fullName: 'Test User',
          age: 25,
          gender: 'Male',
          height: 175,
          weight: 70,
          activityLevel: 'Moderately Active',
          goal: 'Maintain Weight',
          allergies: [],
          healthConditions: [],
          dietaryPreferences: [],
          notifications: [],
        );
        _calculatedAnalysis = _calculateUserAnalysis(_userProfile!);
      });
    }
  }

  Map<String, dynamic> _calculateUserAnalysis(UserProfile profile) {
    // Calculate BMI
    final heightInMeters = profile.height / 100;
    final bmi = profile.weight / (heightInMeters * heightInMeters);
    
    String weightCategory;
    if (bmi < 18.5) {
      weightCategory = 'Underweight';
    } else if (bmi < 25) {
      weightCategory = 'Normal weight';
    } else if (bmi < 30) {
      weightCategory = 'Overweight';
    } else {
      weightCategory = 'Obesity';
    }

    // Calculate BMR (Basal Metabolic Rate)
    double bmr;
    if (profile.gender.toLowerCase() == 'male') {
      bmr = 88.362 + (13.397 * profile.weight) + (4.799 * profile.height) - (5.677 * profile.age);
    } else {
      bmr = 447.593 + (9.247 * profile.weight) + (3.098 * profile.height) - (4.330 * profile.age);
    }

    // Apply activity multiplier
    double activityMultiplier = 1.2; // Sedentary default
    switch (profile.activityLevel.toLowerCase()) {
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extremely active':
        activityMultiplier = 1.9;
        break;
    }

    final dailyCalories = bmr * activityMultiplier;

    // Adjust for goals
    double targetCalories = dailyCalories;
    switch (profile.goal.toLowerCase()) {
      case 'lose weight':
        targetCalories *= 0.85; // 15% deficit
        break;
      case 'gain weight':
      case 'gain muscle':
        targetCalories *= 1.15; // 15% surplus
        break;
    }

    // Calculate macros
    final protein = (targetCalories * 0.25) / 4; // 25% of calories from protein
    final fat = (targetCalories * 0.30) / 9; // 30% of calories from fat
    final carbs = (targetCalories * 0.45) / 4; // 45% of calories from carbs
    final fiber = targetCalories / 80; // Roughly 1g per 80 calories

    return {
      'age': profile.age,
      'height': profile.height,
      'weight': profile.weight,
      'gender': profile.gender,
      'bmi': bmi,
      'weightCategory': weightCategory,
      'goal': profile.goal,
      'activityLevel': profile.activityLevel,
      'bmr': bmr,
      'dailyCalories': targetCalories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'allergies': profile.allergies,
      'healthConditions': profile.healthConditions,
    };
  }

  Widget _buildProfileAnalysisTab() {
    if (_userProfile == null || _calculatedAnalysis == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading your profile analysis...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final analysis = _calculatedAnalysis!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Overview Card
          _buildProfileOverviewCard(analysis),
          const SizedBox(height: 20),
          
          // Detailed Macro Analysis
          _buildDetailedMacroAnalysis(analysis),
          const SizedBox(height: 20),
          
          // Health Insights
          _buildHealthInsightsCard(analysis),
        ],
      ),
    );
  }

  Widget _buildProfileOverviewCard(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.green[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Profile Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Age', '${analysis['age']} years', Colors.blue),
              ),
              Expanded(
                child: _buildInfoItem('Gender', analysis['gender'], Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Height', '${analysis['height']} cm', Colors.orange),
              ),
              Expanded(
                child: _buildInfoItem('Weight', '${analysis['weight']} kg', Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('BMI', '${analysis['bmi'].toStringAsFixed(1)}', Colors.teal),
              ),
              Expanded(
                child: _buildInfoItem('Category', analysis['weightCategory'], Colors.indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMacroAnalysis(Map<String, dynamic> analysis) {
    final personalizedMacros = _calculatePersonalizedMacros(analysis);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Personalized Macro Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Daily Calorie Target
          _buildMacroSection(
            'Daily Calorie Target',
            '${analysis['dailyCalories'].toInt()} kcal',
            _getCalorieContext(analysis['goal'], analysis['bmi']),
            Colors.orange,
            Icons.local_fire_department,
          ),
          const SizedBox(height: 16),
          
          // Protein Target
          _buildMacroSection(
            'Protein Target',
            '${personalizedMacros['protein'].toInt()}g (${(personalizedMacros['proteinRatio'] * 100).toInt()}%)',
            _getProteinContext(analysis['goal'], analysis['age'], analysis['gender'], analysis['healthConditions']),
            Colors.blue,
            Icons.fitness_center,
          ),
          const SizedBox(height: 16),
          
          // Carbohydrate Target
          _buildMacroSection(
            'Carbohydrate Target',
            '${personalizedMacros['carbs'].toInt()}g (${(personalizedMacros['carbRatio'] * 100).toInt()}%)',
            _getCarbContext(analysis['goal'], analysis['healthConditions'], analysis['allergies']),
            Colors.purple,
            Icons.grain,
          ),
          const SizedBox(height: 16),
          
          // Fat Target
          _buildMacroSection(
            'Fat Target',
            '${personalizedMacros['fat'].toInt()}g (${(personalizedMacros['fatRatio'] * 100).toInt()}%)',
            _getFatContext(analysis['goal'], analysis['healthConditions'], analysis['age']),
            Colors.red,
            Icons.opacity,
          ),
          const SizedBox(height: 16),
          
          // Fiber Target
          _buildMacroSection(
            'Fiber Target',
            '${personalizedMacros['fiber'].toInt()}g',
            _getFiberContext(analysis['age'], analysis['gender'], analysis['healthConditions']),
            Colors.green,
            Icons.eco,
          ),
          
          // Special Considerations
          if (analysis['allergies'].isNotEmpty || analysis['healthConditions'].isNotEmpty)
            _buildSpecialConsiderations(analysis['allergies'], analysis['healthConditions']),
        ],
      ),
    );
  }

  Widget _buildMacroSection(String title, String value, String context, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialConsiderations(List<String> allergies, List<String> healthConditions) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Special Considerations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (allergies.isNotEmpty)
            Text(
              'Allergies: ${allergies.join(', ')}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          if (healthConditions.isNotEmpty)
            Text(
              'Health Conditions: ${healthConditions.join(', ')}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
        ],
      ),
    );
  }

  Widget _buildHealthInsightsCard(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.purple[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Health Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Based on your profile, you should focus on maintaining a balanced diet with adequate protein for your activity level. Consider consulting with a nutritionist for personalized meal planning.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculatePersonalizedMacros(Map<String, dynamic> analysis) {
    // This is a placeholder for more sophisticated macro calculations
    // In a real app, this would use the PersonalizedNutritionService
    return {
      'protein': analysis['protein'],
      'carbs': analysis['carbs'],
      'fat': analysis['fat'],
      'fiber': analysis['fiber'],
      'proteinRatio': 0.25,
      'carbRatio': 0.45,
      'fatRatio': 0.30,
    };
  }

  String _getCalorieContext(String goal, double bmi) {
    if (goal.toLowerCase().contains('lose')) {
      return 'Calorie deficit for weight loss. Target: 15% below maintenance calories.';
    } else if (goal.toLowerCase().contains('gain')) {
      return 'Calorie surplus for weight gain. Target: 15% above maintenance calories.';
    } else {
      return 'Maintenance calories to maintain current weight.';
    }
  }

  String _getProteinContext(String goal, int age, String gender, List<String> healthConditions) {
    String base = 'Protein supports muscle maintenance and growth.';
    if (goal.toLowerCase().contains('muscle')) {
      base += ' Higher protein needed for muscle building.';
    }
    if (age > 50) {
      base += ' Increased protein recommended for aging.';
    }
    return base;
  }

  String _getCarbContext(String goal, List<String> healthConditions, List<String> allergies) {
    String base = 'Carbohydrates provide energy for daily activities.';
    if (healthConditions.contains('Diabetes')) {
      base += ' Monitor carb intake for blood sugar control.';
    }
    if (allergies.contains('Gluten')) {
      base += ' Choose gluten-free carb sources.';
    }
    return base;
  }

  String _getFatContext(String goal, List<String> healthConditions, int age) {
    String base = 'Healthy fats support hormone production and nutrient absorption.';
    if (healthConditions.contains('Heart Disease')) {
      base += ' Focus on unsaturated fats.';
    }
    if (age < 30) {
      base += ' Higher fat intake supports brain development.';
    }
    return base;
  }

  String _getFiberContext(int age, String gender, List<String> healthConditions) {
    if (age > 50) {
      return 'Adequate fiber intake for digestive health: 25-30g daily.';
    } else if (gender.toLowerCase() == 'female') {
      return 'Adequate fiber intake for digestive health: 25g daily.';
    } else {
      return 'Adequate fiber intake for digestive health: 30g daily.';
    }
  }

  // Nutritional Analytics Tab
  Widget _buildNutritionalAnalyticsTab(DateTime startOfWeek) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMealPlansStream(startOfWeek),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        // Process the real-time data
        final processedData = _processMealPlansData(snapshot.data, startOfWeek);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekly Overview Card
              _buildWeeklyOverviewCard(processedData['weeklyAverages']),
              const SizedBox(height: 20),
              
              // Daily Breakdown
              _buildDailyBreakdownCard(startOfWeek, processedData['dailyNutrition']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyOverviewCard(Map<String, double> weeklyAverages) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Average Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressItem('Calories', weeklyAverages['calories'] ?? 0, 2000, Colors.orange),
          const SizedBox(height: 12),
          _buildProgressItem('Protein', weeklyAverages['protein'] ?? 0, 50, Colors.blue),
          const SizedBox(height: 12),
          _buildProgressItem('Carbs', weeklyAverages['carbs'] ?? 0, 250, Colors.green),
          const SizedBox(height: 12),
          _buildProgressItem('Fat', weeklyAverages['fat'] ?? 0, 65, Colors.red),
          const SizedBox(height: 12),
          _buildProgressItem('Fiber', weeklyAverages['fiber'] ?? 0, 25, Colors.purple),
          const SizedBox(height: 12),
          _buildProgressItem('Sugar', weeklyAverages['sugar'] ?? 0, 50, Colors.amber),
        ],
      ),
    );
  }




  Widget _buildProgressItem(String label, double current, double target, Color color) {
    final percentage = (current / target * 100).clamp(0, 200);
    final isOverTarget = percentage > 100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${current.toInt()} / ${target.toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOverTarget ? Colors.red : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (percentage / 100).clamp(0, 1),
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            isOverTarget ? Colors.red : color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBreakdownCard(DateTime startOfWeek, Map<String, Map<String, double>> dailyNutrition) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(7, (index) {
            final date = startOfWeek.add(Duration(days: index));
            final isToday = date.day == DateTime.now().day && 
                           date.month == DateTime.now().month && 
                           date.year == DateTime.now().year;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDayCard(date, isToday, dailyNutrition),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, bool isToday, Map<String, Map<String, double>> dailyNutrition) {
    // Get real data from daily nutrition or show zeros
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayData = dailyNutrition[dateKey] ?? {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
    };

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[date.weekday - 1];
    final dateStr = '${date.day}/${date.month}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              isToday ? 'Today' : '$dayName $dateStr',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isToday ? Colors.green[700] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: _buildNutrientValue('Cal', dayData['calories']!.toInt(), Colors.orange),
          ),
          Expanded(
            child: _buildNutrientValue('P', dayData['protein']!.toInt(), Colors.blue),
          ),
          Expanded(
            child: _buildNutrientValue('C', dayData['carbs']!.toInt(), Colors.green),
          ),
          Expanded(
            child: _buildNutrientValue('F', dayData['fat']!.toInt(), Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientValue(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }


  Widget _buildWeekNavigation(DateTime startOfWeek) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border.all(
          color: Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: Colors.green[700],
              ),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                });
              },
            ),
          ),
          Expanded(
            child: Text(
              '${_formatDisplayDate(startOfWeek)} - ${_formatDisplayDate(startOfWeek.add(const Duration(days: 6)))}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: Colors.green[700],
              ),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }


  Stream<QuerySnapshot> _getMealPlansStream(DateTime startOfWeek) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    // Calculate the week's date keys
    final List<String> weekDateKeys = [];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      weekDateKeys.add(dateKey);
    }

    // Query the user's meals subcollection (where actual meals are stored)
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meal_plans')
        .where('date', whereIn: weekDateKeys)
        .snapshots();
  }

  Map<String, dynamic> _processMealPlansData(QuerySnapshot? snapshot, DateTime startOfWeek) {
    Map<String, Map<String, double>> dailyNutrition = {};
    
    // Initialize all days with zeros
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyNutrition[dateKey] = {
        'calories': 0.0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
      };
    }

    // Process meals
    if (snapshot != null) {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateKey = data['date'] as String;
        
        if (dailyNutrition.containsKey(dateKey)) {
          // Get nutrition data from the meal
          final nutrition = data['nutrition'] as Map<String, dynamic>?;
          
          if (nutrition != null) {
            // Helper function to convert dynamic values to double
            double toDouble(dynamic value) {
              if (value is int) return value.toDouble();
              if (value is double) return value;
              if (value is String) return double.tryParse(value) ?? 0.0;
              return 0.0;
            }
            
            // Add nutrition values from meal
            dailyNutrition[dateKey]!['calories'] = dailyNutrition[dateKey]!['calories']! + toDouble(nutrition['calories'] ?? 0);
            dailyNutrition[dateKey]!['protein'] = dailyNutrition[dateKey]!['protein']! + toDouble(nutrition['protein'] ?? 0);
            dailyNutrition[dateKey]!['carbs'] = dailyNutrition[dateKey]!['carbs']! + toDouble(nutrition['carbs'] ?? 0);
            dailyNutrition[dateKey]!['fat'] = dailyNutrition[dateKey]!['fat']! + toDouble(nutrition['fat'] ?? 0);
            dailyNutrition[dateKey]!['fiber'] = dailyNutrition[dateKey]!['fiber']! + toDouble(nutrition['fiber'] ?? 0);
            dailyNutrition[dateKey]!['sugar'] = dailyNutrition[dateKey]!['sugar']! + toDouble(nutrition['sugar'] ?? 0);
          }
        }
      }
    }

    // Calculate weekly averages
    final weeklyAverages = <String, double>{
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
    };

    for (var dayData in dailyNutrition.values) {
      weeklyAverages['calories'] = weeklyAverages['calories']! + dayData['calories']!;
      weeklyAverages['protein'] = weeklyAverages['protein']! + dayData['protein']!;
      weeklyAverages['carbs'] = weeklyAverages['carbs']! + dayData['carbs']!;
      weeklyAverages['fat'] = weeklyAverages['fat']! + dayData['fat']!;
      weeklyAverages['fiber'] = weeklyAverages['fiber']! + dayData['fiber']!;
      weeklyAverages['sugar'] = weeklyAverages['sugar']! + dayData['sugar']!;
    }

    // Convert to daily averages
    weeklyAverages['calories'] = weeklyAverages['calories']! / 7;
    weeklyAverages['protein'] = weeklyAverages['protein']! / 7;
    weeklyAverages['carbs'] = weeklyAverages['carbs']! / 7;
    weeklyAverages['fat'] = weeklyAverages['fat']! / 7;
    weeklyAverages['fiber'] = weeklyAverages['fiber']! / 7;
    weeklyAverages['sugar'] = weeklyAverages['sugar']! / 7;

    return {
      'weeklyAverages': weeklyAverages,
      'dailyNutrition': dailyNutrition,
    };
  }

}