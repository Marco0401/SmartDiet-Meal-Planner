import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalizedGuidelinesPage extends StatefulWidget {
  const PersonalizedGuidelinesPage({Key? key}) : super(key: key);

  @override
  State<PersonalizedGuidelinesPage> createState() => _PersonalizedGuidelinesPageState();
}

class _PersonalizedGuidelinesPageState extends State<PersonalizedGuidelinesPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _matchingGuidelines = [];
  Map<String, dynamic>? _nutritionTargets;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndGuidelines();
  }

  Future<void> _loadUserDataAndGuidelines() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      _userProfile = userDoc.data();
      if (_userProfile == null) return;

      // Fetch matching personalized nutrition rules
      final rulesSnapshot = await FirebaseFirestore.instance
          .collection('personalized_nutrition_rules')
          .get();

      _matchingGuidelines = rulesSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((rule) => _doesRuleMatchUser(rule, _userProfile!))
          .toList();

      // Calculate nutrition targets based on matching rules
      _nutritionTargets = _calculateNutritionTargets();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading guidelines: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _doesRuleMatchUser(Map<String, dynamic> rule, Map<String, dynamic> user) {
    final conditions = rule['conditions'] as Map<String, dynamic>?;
    if (conditions == null) return false;

    // Check age range
    if (conditions['ageRange'] != null) {
      final ageRange = conditions['ageRange'] as Map<String, dynamic>;
      final userAge = _calculateAge(user['birthday']);
      final min = ageRange['min'] ?? 0;
      final max = ageRange['max'] ?? 200;
      if (userAge < min || userAge > max) return false;
    }

    // Check gender
    if (conditions['gender'] != null && conditions['gender'] != 'any') {
      if (user['gender'] != conditions['gender']) return false;
    }

    // Check health conditions
    if (conditions['healthConditions'] != null) {
      final ruleConditions = List<String>.from(conditions['healthConditions']);
      final userConditions = List<String>.from(user['healthConditions'] ?? []);
      
      // Check if any of the rule's conditions match the user's conditions
      bool hasMatchingCondition = ruleConditions.any((condition) => 
        userConditions.contains(condition)
      );
      if (!hasMatchingCondition && ruleConditions.isNotEmpty) return false;
    }

    // Check dietary preferences
    if (conditions['dietaryPreferences'] != null) {
      final ruleDiet = List<String>.from(conditions['dietaryPreferences']);
      final userDiet = List<String>.from(user['dietaryPreferences'] ?? []);
      
      bool hasMatchingDiet = ruleDiet.any((diet) => userDiet.contains(diet));
      if (!hasMatchingDiet && ruleDiet.isNotEmpty) return false;
    }

    // Check body goals
    if (conditions['bodyGoals'] != null) {
      final ruleGoals = List<String>.from(conditions['bodyGoals']);
      final userGoals = user['bodyGoals'] as String? ?? '';
      
      if (!ruleGoals.contains(userGoals) && ruleGoals.isNotEmpty) return false;
    }

    // Check pregnancy/lactation
    if (conditions['isPregnant'] != null) {
      if (user['isPregnant'] != conditions['isPregnant']) return false;
    }
    if (conditions['isLactating'] != null) {
      if (user['isLactating'] != conditions['isLactating']) return false;
    }

    return true;
  }

  int _calculateAge(dynamic birthday) {
    if (birthday == null) return 0;
    
    DateTime birthDate;
    if (birthday is Timestamp) {
      birthDate = birthday.toDate();
    } else if (birthday is String) {
      birthDate = DateTime.parse(birthday);
    } else {
      return 0;
    }

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> _calculateNutritionTargets() {
    if (_matchingGuidelines.isEmpty || _userProfile == null) {
      return _getDefaultTargets();
    }

    // Start with base calories (e.g., BMR calculation)
    double baseCalories = _calculateBMR();
    
    // Apply multipliers from matching rules
    double totalMultiplier = 1.0;
    double proteinRatio = 0.25;
    double carbRatio = 0.50;
    double fatRatio = 0.25;
    int mealFrequency = 3;

    for (var rule in _matchingGuidelines) {
      final adjustments = rule['adjustments'] as Map<String, dynamic>?;
      if (adjustments == null) continue;

      if (adjustments['calorieMultiplier'] != null) {
        totalMultiplier *= (adjustments['calorieMultiplier'] as num).toDouble();
      }
      if (adjustments['proteinRatio'] != null) {
        proteinRatio = (adjustments['proteinRatio'] as num).toDouble();
      }
      if (adjustments['carbRatio'] != null) {
        carbRatio = (adjustments['carbRatio'] as num).toDouble();
      }
      if (adjustments['fatRatio'] != null) {
        fatRatio = (adjustments['fatRatio'] as num).toDouble();
      }
      if (adjustments['mealFrequency'] != null) {
        mealFrequency = adjustments['mealFrequency'] as int;
      }
    }

    final targetCalories = (baseCalories * totalMultiplier).round();

    return {
      'calories': targetCalories,
      'protein': ((targetCalories * proteinRatio) / 4).round(), // 4 cal per gram
      'carbs': ((targetCalories * carbRatio) / 4).round(),
      'fat': ((targetCalories * fatRatio) / 9).round(), // 9 cal per gram
      'mealFrequency': mealFrequency,
      'proteinRatio': proteinRatio,
      'carbRatio': carbRatio,
      'fatRatio': fatRatio,
    };
  }

  double _calculateBMR() {
    if (_userProfile == null) return 2000;

    final weight = (_userProfile!['weight'] as num?)?.toDouble() ?? 70;
    final height = (_userProfile!['height'] as num?)?.toDouble() ?? 170;
    final age = _calculateAge(_userProfile!['birthday']);
    final gender = _userProfile!['gender'] as String? ?? 'male';

    // Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    // Apply activity level multiplier
    final activityLevel = _userProfile!['activityLevel'] as String? ?? 'moderate';
    double activityMultiplier = 1.55; // moderate
    switch (activityLevel) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'active':
        activityMultiplier = 1.725;
        break;
      case 'very_active':
        activityMultiplier = 1.9;
        break;
    }

    return bmr * activityMultiplier;
  }

  Map<String, dynamic> _getDefaultTargets() {
    return {
      'calories': 2000,
      'protein': 125, // 25% of 2000 cal
      'carbs': 250,   // 50% of 2000 cal
      'fat': 56,      // 25% of 2000 cal
      'mealFrequency': 3,
      'proteinRatio': 0.25,
      'carbRatio': 0.50,
      'fatRatio': 0.25,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Nutrition Guidelines',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserDataAndGuidelines,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8FFF4), Color(0xFFE8F5E9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // User Profile Summary
                    _buildProfileSummary(),
                    const SizedBox(height: 20),

                    // Nutrition Targets
                    _buildNutritionTargets(),
                    const SizedBox(height: 20),

                    // Matching Guidelines
                    if (_matchingGuidelines.isNotEmpty) ...[
                      _buildSectionHeader('Personalized Recommendations'),
                      const SizedBox(height: 12),
                      ..._matchingGuidelines.map((guideline) => 
                        _buildGuidelineCard(guideline)
                      ),
                    ],

                    // General Tips
                    const SizedBox(height: 20),
                    _buildGeneralTips(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSummary() {
    if (_userProfile == null) return const SizedBox.shrink();

    final age = _calculateAge(_userProfile!['birthday']);
    final gender = _userProfile!['gender'] ?? 'Not specified';
    final weight = _userProfile!['weight']?.toString() ?? 'N/A';
    final height = _userProfile!['height']?.toString() ?? 'N/A';
    final bodyGoals = _userProfile!['bodyGoals'] ?? 'Not specified';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Your Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileRow(Icons.cake, 'Age', '$age years'),
            _buildProfileRow(Icons.person_outline, 'Gender', gender),
            _buildProfileRow(Icons.monitor_weight, 'Weight', '$weight kg'),
            _buildProfileRow(Icons.height, 'Height', '$height cm'),
            _buildProfileRow(Icons.flag, 'Goal', bodyGoals),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTargets() {
    if (_nutritionTargets == null) return const SizedBox.shrink();

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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Daily Nutrition Targets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTargetRow(
              Icons.local_fire_department,
              'Calories',
              '${_nutritionTargets!['calories']} kcal',
              Colors.orange,
            ),
            _buildTargetRow(
              Icons.fitness_center,
              'Protein',
              '${_nutritionTargets!['protein']}g (${(_nutritionTargets!['proteinRatio'] * 100).toInt()}%)',
              Colors.red,
            ),
            _buildTargetRow(
              Icons.grass,
              'Carbs',
              '${_nutritionTargets!['carbs']}g (${(_nutritionTargets!['carbRatio'] * 100).toInt()}%)',
              Colors.blue,
            ),
            _buildTargetRow(
              Icons.water_drop,
              'Fat',
              '${_nutritionTargets!['fat']}g (${(_nutritionTargets!['fatRatio'] * 100).toInt()}%)',
              Colors.purple,
            ),
            const Divider(height: 24),
            _buildTargetRow(
              Icons.restaurant,
              'Recommended Meals',
              '${_nutritionTargets!['mealFrequency']} meals per day',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3748),
      ),
    );
  }

  Widget _buildGuidelineCard(Map<String, dynamic> guideline) {
    final adjustments = guideline['adjustments'] as Map<String, dynamic>? ?? {};
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    guideline['name'] ?? 'Guideline',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
            ),
            if (guideline['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                guideline['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
            if (adjustments['foodsToInclude'] != null && 
                (adjustments['foodsToInclude'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildFoodsList(
                '✅ Recommended Foods:',
                adjustments['foodsToInclude'],
                Colors.green,
              ),
            ],
            if (adjustments['foodsToAvoid'] != null && 
                (adjustments['foodsToAvoid'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildFoodsList(
                '⚠️ Foods to Limit:',
                adjustments['foodsToAvoid'],
                Colors.orange,
              ),
            ],
            if (adjustments['supplements'] != null && 
                (adjustments['supplements'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildFoodsList(
                '💊 Recommended Supplements:',
                adjustments['supplements'],
                Colors.blue,
              ),
            ],
            if (adjustments['specialInstructions'] != null &&
                (adjustments['specialInstructions'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        adjustments['specialInstructions'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFoodsList(String title, dynamic foods, Color color) {
    final foodList = List<String>.from(foods);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: foodList.map((food) => Chip(
            label: Text(
              food,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: color.withOpacity(0.1),
            side: BorderSide(color: color.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildGeneralTips() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'General Tips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem('💧 Stay hydrated - drink at least 8 glasses of water daily'),
            _buildTipItem('🥗 Eat a variety of colorful fruits and vegetables'),
            _buildTipItem('🍽️ Practice portion control and mindful eating'),
            _buildTipItem('🏃 Combine good nutrition with regular physical activity'),
            _buildTipItem('😴 Get adequate sleep (7-9 hours) for better metabolism'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

