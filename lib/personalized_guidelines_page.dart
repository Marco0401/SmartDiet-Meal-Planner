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

      // Fetch nutritional guidelines from nutritionist dashboard
      final guidelinesSnapshot = await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      _matchingGuidelines = guidelinesSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Calculate nutrition targets based on user's account settings
      _nutritionTargets = _calculateNutritionTargets();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading guidelines: $e');
      setState(() => _isLoading = false);
    }
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
    if (_userProfile == null) {
      return _getDefaultTargets();
    }

    // Get user's nutrition goals from account settings
    final calories = (_userProfile!['daily_calories'] ?? 2000).toDouble();
    final protein = (_userProfile!['daily_protein'] ?? 150).toDouble();
    final carbs = (_userProfile!['daily_carbs'] ?? 250).toDouble();
    final fat = (_userProfile!['daily_fat'] ?? 67).toDouble();
    final fiber = (_userProfile!['daily_fiber'] ?? 25).toDouble();

    // Calculate ratios
    final proteinRatio = (protein * 4) / calories; // 4 cal per gram
    final carbRatio = (carbs * 4) / calories; // 4 cal per gram
    final fatRatio = (fat * 9) / calories; // 9 cal per gram

    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fat': fat.round(),
      'fiber': fiber.round(),
      'proteinRatio': proteinRatio,
      'carbRatio': carbRatio,
      'fatRatio': fatRatio,
      'mealFrequency': 3, // Default meal frequency
    };
  }


  Map<String, dynamic> _getDefaultTargets() {
    return {
      'calories': 2000,
      'protein': 150,
      'carbs': 250,
      'fat': 67,
      'fiber': 25,
      'proteinRatio': 0.30, // 30% of calories
      'carbRatio': 0.50,    // 50% of calories
      'fatRatio': 0.30,     // 30% of calories
      'mealFrequency': 3,
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

                    // Nutritional Guidelines
                    if (_matchingGuidelines.isNotEmpty) ...[
                      _buildSectionHeader('Nutritional Guidelines'),
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
    
    // Handle bodyGoals - could be String or List
    String bodyGoals = 'Not specified';
    if (_userProfile!['bodyGoals'] != null) {
      if (_userProfile!['bodyGoals'] is List) {
        final goalsList = List<String>.from(_userProfile!['bodyGoals']);
        bodyGoals = goalsList.isNotEmpty ? goalsList.join(', ') : 'Not specified';
      } else {
        bodyGoals = _userProfile!['bodyGoals'].toString();
      }
    }

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
            _buildTargetRow(
              Icons.grass,
              'Fiber',
              '${_nutritionTargets!['fiber']}g',
              Colors.green,
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
                    color: _getCategoryColor(guideline['category']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(guideline['category']), 
                    color: _getCategoryColor(guideline['category']), 
                    size: 20
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guideline['title'] ?? 'Guideline',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      if (guideline['category'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(guideline['category']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getCategoryColor(guideline['category']).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            guideline['category'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(guideline['category']),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (guideline['priority'] != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(guideline['priority']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPriorityText(guideline['priority']),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(guideline['priority']),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (guideline['content'] != null) ...[
              const SizedBox(height: 12),
              Text(
                guideline['content'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
            if (guideline['lastUpdated'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated: ${_formatDate(guideline['lastUpdated'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
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

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'general':
        return Colors.blue;
      case 'weight management':
        return Colors.orange;
      case 'muscle building':
        return Colors.red;
      case 'heart health':
        return Colors.pink;
      case 'diabetes management':
        return Colors.purple;
      case 'pregnancy':
        return Colors.amber;
      case 'sports nutrition':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'general':
        return Icons.info;
      case 'weight management':
        return Icons.monitor_weight;
      case 'muscle building':
        return Icons.fitness_center;
      case 'heart health':
        return Icons.favorite;
      case 'diabetes management':
        return Icons.bloodtype;
      case 'pregnancy':
        return Icons.pregnant_woman;
      case 'sports nutrition':
        return Icons.sports;
      default:
        return Icons.article;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MED';
      case 'low':
        return 'LOW';
      default:
        return 'N/A';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return 'Unknown';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
}

