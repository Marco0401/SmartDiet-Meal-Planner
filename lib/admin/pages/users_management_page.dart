import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _fixMissingEmails,
            icon: const Icon(Icons.healing),
            tooltip: 'Fix Missing Emails',
          ),
          IconButton(
            onPressed: () {
              setState(() {}); // Refresh
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name or email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddUserDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // User Statistics Cards
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final users = snapshot.data!.docs;
                  final totalUsers = users.length;
                  final activeUsers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['fullName'] != null || data['name'] != null) && data['email'] != null;
                  }).length;
                  final incompleteUsers = totalUsers - activeUsers;
                  final adminUsers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['role'] == 'admin' || data['isAdmin'] == true;
                  }).length;
                  
                  return Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Users', totalUsers.toString(), Colors.blue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active Users', activeUsers.toString(), Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Incomplete', incompleteUsers.toString(), Colors.orange)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Admins', adminUsers.toString(), Colors.red)),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            
            // Users List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final users = snapshot.data?.docs ?? [];
                  final filteredUsers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return const Center(
                      child: Text('No users found'),
                    );
                  }

                  return Card(
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(flex: 1, child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(flex: 1, child: Text('Joined', style: TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        
                        // Users List
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final doc = filteredUsers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Name
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['fullName'] ?? data['name'] ?? 'Incomplete Profile',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: (data['fullName'] == null && data['name'] == null) ? Colors.grey : Colors.black,
                                              fontStyle: (data['fullName'] == null && data['name'] == null) ? FontStyle.italic : FontStyle.normal,
                                            ),
                                          ),
                                          if (data['allergies'] != null && (data['allergies'] as List).isNotEmpty)
                                            Text(
                                              'Allergies: ${(data['allergies'] as List).join(', ')}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade600,
                                              ),
                                            ),
                                          if (data['dietaryPreferences'] != null && (data['dietaryPreferences'] as List).isNotEmpty)
                                            Text(
                                              'Diet: ${(data['dietaryPreferences'] as List).where((pref) => pref != 'None').join(', ')}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                          if (data['goal'] != null)
                                            Text(
                                              'Goal: ${data['goal']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Email
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        data['email'] ?? 'No Email',
                                        style: TextStyle(
                                          color: data['email'] == null ? Colors.grey : Colors.black,
                                          fontStyle: data['email'] == null ? FontStyle.italic : FontStyle.normal,
                                        ),
                                      ),
                                    ),
                                    
                                    // Role
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (data['role'] == 'admin' || data['isAdmin'] == true) 
                                              ? Colors.red.shade100 
                                              : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          (data['role'] == 'admin' || data['isAdmin'] == true) ? 'Admin' : 'User',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: (data['role'] == 'admin' || data['isAdmin'] == true) 
                                                ? Colors.red.shade700 
                                                : Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Status
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (data['fullName'] == null && data['name'] == null) || data['email'] == null
                                              ? Colors.orange.shade100
                                              : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          ((data['fullName'] == null && data['name'] == null) || data['email'] == null)
                                              ? 'Incomplete'
                                              : 'Active',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: ((data['fullName'] == null && data['name'] == null) || data['email'] == null)
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Joined Date
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        _formatDate(data['createdAt']),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    
                                    // Actions
                                    SizedBox(
                                      width: 100,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => _showUserDetails(doc.id, data),
                                            icon: const Icon(Icons.visibility, size: 18),
                                            tooltip: 'View Details',
                                          ),
                                          if ((data['fullName'] != null || data['name'] != null) && data['email'] != null)
                                            IconButton(
                                              onPressed: () => _showEditUserDialog(doc.id, data),
                                              icon: const Icon(Icons.edit, size: 18),
                                              tooltip: 'Edit User',
                                            ),
                                          if ((data['fullName'] == null && data['name'] == null) || data['email'] == null)
                                            IconButton(
                                              onPressed: () => _deleteIncompleteUser(doc.id),
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              tooltip: 'Delete Incomplete User',
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showUserDetails(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: ${userData['fullName'] ?? userData['name'] ?? 'Unknown User'}'),
        content: SizedBox(
          width: 500,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                const Text('📋 Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                const SizedBox(height: 8),
                _buildDetailRow('User ID', userId),
                _buildDetailRow('Full Name', userData['fullName'] ?? userData['name'] ?? 'N/A'),
                _buildDetailRow('Email', userData['email'] ?? 'N/A'),
                _buildDetailRow('Gender', userData['gender'] ?? 'N/A'),
                _buildDetailRow('Age', userData['age']?.toString() ?? 'N/A'),
                _buildDetailRow('Birthday', userData['birthday']?.toString().split('T')[0] ?? 'N/A'),
                
                const SizedBox(height: 16),
                const Text('💪 Health & Fitness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                const SizedBox(height: 8),
                _buildDetailRow('Goal', userData['goal'] ?? 'N/A'),
                _buildDetailRow('Height', userData['height'] != null ? '${userData['height']} cm' : 'N/A'),
                _buildDetailRow('Weight', userData['weight'] != null ? '${userData['weight']} kg' : 'N/A'),
                _buildDetailRow('Activity Level', userData['activityLevel'] ?? 'N/A'),
                
                const SizedBox(height: 16),
                const Text('🍽️ Dietary Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                const SizedBox(height: 8),
                _buildDetailRow('Allergies', 
                  userData['allergies'] != null && (userData['allergies'] as List).isNotEmpty
                    ? (userData['allergies'] as List).join(', ')
                    : 'None'),
                _buildDetailRow('Dietary Preferences', 
                  userData['dietaryPreferences'] != null && (userData['dietaryPreferences'] as List).isNotEmpty
                    ? (userData['dietaryPreferences'] as List).where((pref) => pref != 'None').join(', ').isEmpty 
                      ? 'None' 
                      : (userData['dietaryPreferences'] as List).where((pref) => pref != 'None').join(', ')
                    : 'None'),
                if (userData['otherDiet'] != null && userData['otherDiet'].toString().isNotEmpty)
                  _buildDetailRow('Other Dietary Info', userData['otherDiet']),
                
                const SizedBox(height: 16),
                const Text('🏥 Health Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                const SizedBox(height: 8),
                _buildDetailRow('Health Conditions', 
                  userData['healthConditions'] != null && (userData['healthConditions'] as List).isNotEmpty
                    ? (userData['healthConditions'] as List).where((cond) => cond != 'None').join(', ').isEmpty 
                      ? 'None' 
                      : (userData['healthConditions'] as List).where((cond) => cond != 'None').join(', ')
                    : 'None'),
                _buildDetailRow('Medication', 
                  userData['medication'] != null && userData['medication'].toString().isNotEmpty
                    ? userData['medication']
                    : 'None'),
                if (userData['otherCondition'] != null && userData['otherCondition'].toString().isNotEmpty)
                  _buildDetailRow('Other Conditions', userData['otherCondition']),
                
                const SizedBox(height: 16),
                const Text('⚙️ App Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                const SizedBox(height: 8),
                _buildDetailRow('Notifications', 
                  userData['notifications'] != null && userData['notifications'] is List
                    ? (userData['notifications'] as List).join(', ')
                    : userData['notifications']?.toString() ?? 'Default'),
                _buildDetailRow('Role', userData['role'] ?? 'User'),
                _buildDetailRow('Last Updated', _formatDate(userData['lastUpdated'])),
                _buildDetailRow('Account Created', _formatDate(userData['createdAt'])),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        userId: userId,
        userData: userData,
        onUserUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        onUserAdded: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _fixMissingEmails() async {
    try {
      // Get all users from Firestore
      final firestoreUsers = await FirebaseFirestore.instance
          .collection('users')
          .get();

      int fixedCount = 0;
      int totalProcessed = 0;

      for (final doc in firestoreUsers.docs) {
        totalProcessed++;
        final data = doc.data();
        final userId = doc.id;

        // Skip if email already exists
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          continue;
        }

        try {
          // For existing users without emails, we'll mark them for manual review
          // In a real production environment, you'd use Firebase Admin SDK to lookup emails
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'emailStatus': 'missing - needs manual review',
            'lastEmailCheck': FieldValue.serverTimestamp(),
          });
          
          fixedCount++;
        } catch (e) {
          print('Error processing user $userId: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Processed $totalProcessed users. Marked $fixedCount users for email review.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing emails: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteIncompleteUser(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Incomplete User'),
        content: const Text(
          'This user has incomplete profile data (missing name or email). '
          'Are you sure you want to delete this user account?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .delete();
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incomplete user deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  final VoidCallback onUserAdded;

  const AddUserDialog({
    super.key,
    required this.onUserAdded,
  });

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherConditionController = TextEditingController();
  final _medicationController = TextEditingController();
  final _otherDietController = TextEditingController();

  // Form data
  DateTime? _birthday;
  String? _gender;
  String? _role = 'User';
  List<String> _healthConditions = [];
  List<String> _allergies = [];
  List<String> _dietaryPreferences = [];
  String? _goal;
  String? _activityLevel;
  List<String> _notifications = ['Meal reminders', 'Tips', 'Updates', 'News'];

  // Static lists from onboarding
  static const List<String> _conditionsList = [
    'None',
    'Diabetes',
    'Hypertension',
    'High Cholesterol',
    'Obesity',
    'Kidney Disease',
    'PCOS',
    'Lactose Intolerance',
    'Gluten Sensitivity',
  ];

  static const List<String> _allergiesList = [
    'None',
    'Peanuts',
    'Tree Nuts',
    'Milk',
    'Eggs',
    'Fish',
    'Shellfish',
    'Wheat',
    'Soy',
    'Sesame',
  ];

  static const List<String> _dietList = [
    'None',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto',
    'Low Carb',
    'Low Sodium',
    'Halal',
    'No Preference',
  ];

  static const List<String> _goals = [
    'None',
    'Lose weight',
    'Gain weight',
    'Maintain current weight',
    'Build muscle',
    'Eat healthier / clean eating',
  ];

  static const List<String> _activityLevels = [
    'None',
    'Sedentary (little or no exercise)',
    'Lightly active (light exercise/sports 1–3 days/week)',
    'Moderately active (moderate exercise/sports 3–5 days/week)',
    'Very active (hard exercise 6–7 days/week)',
  ];

  static const List<String> _notificationTypes = [
    'None',
    'Meal reminders',
    'Tips',
    'Updates',
    'News',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _otherConditionController.dispose();
    _medicationController.dispose();
    _otherDietController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int? get age {
    if (_birthday == null) return null;
    final now = DateTime.now();
    int years = now.year - _birthday!.year;
    if (now.month < _birthday!.month ||
        (now.month == _birthday!.month && now.day < _birthday!.day)) {
      years--;
    }
    return years;
  }

  bool get _isStepValid {
    switch (_currentStep) {
      case 0: // Account Info
        return _emailController.text.trim().isNotEmpty &&
               _passwordController.text.length >= 6 &&
               _role != null;
      case 1: // Basic Info
        return _fullNameController.text.trim().isNotEmpty &&
               _birthday != null &&
               _gender != null &&
               _heightController.text.isNotEmpty &&
               _weightController.text.isNotEmpty;
      case 2: // Health Info
        return _healthConditions.isNotEmpty &&
               _allergies.isNotEmpty;
      case 3: // Dietary & Goals
        return _dietaryPreferences.isNotEmpty &&
               _goal != null &&
               _activityLevel != null;
      case 4: // Notifications
        return true; // Optional step
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_isStepValid) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
      if (_currentStep < 5) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Please complete all required fields.';
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create Firebase Auth user
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user!;
      
      // Prepare user profile data
      final profileData = {
        'email': _emailController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'age': age ?? 0,
        'gender': _gender,
        'height': double.tryParse(_heightController.text) ?? 0.0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'birthday': _birthday!.toIso8601String(),
        'healthConditions': _healthConditions,
        'allergies': _allergies,
        'otherCondition': _otherConditionController.text.trim().isEmpty 
            ? null : _otherConditionController.text.trim(),
        'medication': _medicationController.text.trim().isEmpty 
            ? null : _medicationController.text.trim(),
        'dietaryPreferences': _dietaryPreferences,
        'otherDiet': _otherDietController.text.trim().isEmpty 
            ? null : _otherDietController.text.trim(),
        'goal': _goal,
        'activityLevel': _activityLevel,
        'notifications': _notifications,
        'role': _role,
        'isAdmin': _role == 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData);

      // Send email verification
      await user.sendEmailVerification();

      widget.onUserAdded();
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'weak-password':
            _errorMessage = 'The password provided is too weak.';
            break;
          case 'email-already-in-use':
            _errorMessage = 'An account already exists for this email.';
            break;
          case 'invalid-email':
            _errorMessage = 'The email address is not valid.';
            break;
          default:
            _errorMessage = 'Error creating user: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Add New User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: List.generate(5, (index) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),
            
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildAccountInfoStep(),
                    _buildBasicInfoStep(),
                    _buildHealthInfoStep(),
                    _buildDietaryGoalsStep(),
                    _buildNotificationsStep(),
                  ],
                ),
              ),
            ),
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_currentStep == 4 ? _createUser : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_currentStep == 4 ? 'Create User' : 'Next'),
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

  Widget _buildAccountInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'user@example.com',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password *',
              hintText: 'Minimum 6 characters',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Role *',
              prefixIcon: Icon(Icons.admin_panel_settings),
            ),
            items: const [
              DropdownMenuItem(value: 'User', child: Text('User')),
              DropdownMenuItem(value: 'Admin', child: Text('Admin')),
            ],
            onChanged: (value) {
              setState(() {
                _role = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBirthday,
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Birthday *',
                  hintText: 'Select birthday',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                controller: TextEditingController(
                  text: _birthday != null
                      ? DateFormat('yyyy-MM-dd').format(_birthday!)
                      : '',
                ),
                validator: (value) {
                  if (_birthday == null) {
                    return 'Birthday is required';
                  }
                  return null;
                },
              ),
            ),
          ),
          if (age != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Age: $age', style: const TextStyle(fontSize: 16)),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _gender?.isNotEmpty == true ? _gender : null,
            decoration: const InputDecoration(
              labelText: 'Gender *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              setState(() {
                _gender = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Gender is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            decoration: const InputDecoration(
              labelText: 'Height (cm) *',
              prefixIcon: Icon(Icons.height),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Height is required';
              }
              final height = double.tryParse(value);
              if (height == null || height <= 0) {
                return 'Please enter a valid height';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Weight (kg) *',
              prefixIcon: Icon(Icons.monitor_weight),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Weight is required';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0) {
                return 'Please enter a valid weight';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('Health Conditions *'),
          const SizedBox(height: 8),
          ..._conditionsList.map((condition) => CheckboxListTile(
            value: _healthConditions.contains(condition),
            title: Text(condition),
            onChanged: (value) {
              setState(() {
                if (condition == 'None') {
                  if (value == true) {
                    _healthConditions.clear();
                    _healthConditions.add('None');
                  } else {
                    _healthConditions.remove('None');
                  }
                } else {
                  if (value == true) {
                    _healthConditions.remove('None');
                    _healthConditions.add(condition);
                  } else {
                    _healthConditions.remove(condition);
                  }
                }
              });
            },
          )),
          CheckboxListTile(
            value: _otherConditionController.text.isNotEmpty,
            title: const Text('Other'),
            onChanged: (value) {},
            secondary: SizedBox(
              width: 200,
              child: TextField(
                controller: _otherConditionController,
                decoration: const InputDecoration(hintText: 'Specify'),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Food Allergies *'),
          const SizedBox(height: 8),
          ..._allergiesList.map((allergy) => CheckboxListTile(
            value: _allergies.contains(allergy),
            title: Text(allergy),
            onChanged: (value) {
              setState(() {
                if (allergy == 'None') {
                  if (value == true) {
                    _allergies.clear();
                    _allergies.add('None');
                  } else {
                    _allergies.remove('None');
                  }
                } else {
                  if (value == true) {
                    _allergies.remove('None');
                    _allergies.add(allergy);
                  } else {
                    _allergies.remove(allergy);
                  }
                }
              });
            },
          )),
          const SizedBox(height: 16),
          const Text('Medication (optional)'),
          TextField(
            controller: _medicationController,
            decoration: const InputDecoration(
              hintText: 'Any medications that affect diet',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryGoalsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary Preferences & Goals',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('Dietary Preferences *'),
          const SizedBox(height: 8),
          ..._dietList.map((diet) => CheckboxListTile(
            value: _dietaryPreferences.contains(diet),
            title: Text(diet),
            onChanged: (value) {
              setState(() {
                if (diet == 'None') {
                  if (value == true) {
                    _dietaryPreferences.clear();
                    _dietaryPreferences.add('None');
                  } else {
                    _dietaryPreferences.remove('None');
                  }
                } else {
                  if (value == true) {
                    _dietaryPreferences.remove('None');
                    _dietaryPreferences.add(diet);
                  } else {
                    _dietaryPreferences.remove(diet);
                  }
                }
              });
            },
          )),
          CheckboxListTile(
            value: _otherDietController.text.isNotEmpty,
            title: const Text('Other'),
            onChanged: (value) {},
            secondary: SizedBox(
              width: 200,
              child: TextField(
                controller: _otherDietController,
                decoration: const InputDecoration(hintText: 'Specify'),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Goal *'),
          const SizedBox(height: 8),
          ..._goals.map((goal) => RadioListTile<String>(
            value: goal,
            groupValue: _goal,
            title: Text(goal),
            onChanged: (value) {
              setState(() {
                _goal = value;
              });
            },
          )),
          const SizedBox(height: 16),
          const Text('Activity Level *'),
          const SizedBox(height: 8),
          ..._activityLevels.map((level) => RadioListTile<String>(
            value: level,
            groupValue: _activityLevel,
            title: Text(level),
            onChanged: (value) {
              setState(() {
                _activityLevel = value;
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildNotificationsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Preferences',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'These settings control push notifications. In-app notifications are always shown.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ..._notificationTypes.map((notification) => CheckboxListTile(
            value: _notifications.contains(notification),
            title: Text(notification),
            onChanged: (value) {
              setState(() {
                if (notification == 'None') {
                  if (value == true) {
                    _notifications.clear();
                    _notifications.add('None');
                  } else {
                    _notifications.remove('None');
                  }
                } else {
                  if (value == true) {
                    _notifications.remove('None');
                    _notifications.add(notification);
                  } else {
                    _notifications.remove(notification);
                  }
                }
              });
            },
          )),
        ],
      ),
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final VoidCallback onUserUpdated;

  const EditUserDialog({
    super.key,
    required this.userId,
    required this.userData,
    required this.onUserUpdated,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Controllers
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherConditionController = TextEditingController();
  final _medicationController = TextEditingController();
  final _otherDietController = TextEditingController();
  
  // State variables
  String? _selectedRole;
  String? _selectedGender;
  DateTime? _selectedBirthday;
  List<String> _selectedHealthConditions = [];
  List<String> _selectedDietaryPreferences = [];
  List<String> _selectedBodyGoals = [];
  List<String> _selectedNotificationPreferences = [];
  List<String> _selectedAllergies = [];
  String? _selectedActivityLevel;
  bool _isUpdating = false;
  int _currentStep = 0;

  final List<String> _roles = ['user', 'admin'];
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _healthConditions = [
    'None', 'Diabetes', 'Hypertension', 'High Cholesterol',
    'Obesity', 'Kidney Disease', 'PCOS', 'Lactose Intolerance',
    'Gluten Sensitivity', 'Other'
  ];
  final List<String> _dietaryPreferences = [
    'None', 'Vegetarian', 'Vegan', 'Pescatarian', 'Keto',
    'Low Carb', 'Low Sodium', 'Halal', 'No Preference'
  ];
  final List<String> _bodyGoals = [
    'None', 'Lose weight', 'Gain weight', 'Maintain current weight',
    'Build muscle', 'Eat healthier / clean eating'
  ];
  final List<String> _notificationTypes = [
    'None', 'Meal reminders', 'Tips', 'Updates', 'News'
  ];
  final List<String> _allergies = [
    'None', 'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 
    'Fish', 'Shellfish', 'Wheat', 'Soy', 'Sesame'
  ];
  final List<String> _activityLevels = [
    'None', 'Sedentary (little or no exercise)',
    'Lightly active (light exercise/sports 1–3 days/week)',
    'Moderately active (moderate exercise/sports 3–5 days/week)',
    'Very active (hard exercise 6–7 days/week)'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _emailController.text = widget.userData['email'] ?? '';
    _fullNameController.text = widget.userData['name'] ?? '';
    _selectedRole = widget.userData['role'] ?? 'user';
    _selectedGender = widget.userData['gender'] ?? '';
    _heightController.text = widget.userData['height']?.toString() ?? '';
    _weightController.text = widget.userData['weight']?.toString() ?? '';
    _otherConditionController.text = widget.userData['otherCondition'] ?? '';
    _medicationController.text = widget.userData['medication'] ?? '';
    _otherDietController.text = widget.userData['otherDiet'] ?? '';
    
    // Parse existing data
    if (widget.userData['healthConditions'] is List) {
      _selectedHealthConditions = List<String>.from(widget.userData['healthConditions']);
    }
    if (widget.userData['dietaryPreferences'] is List) {
      _selectedDietaryPreferences = List<String>.from(widget.userData['dietaryPreferences']);
    }
    if (widget.userData['bodyGoals'] is List) {
      _selectedBodyGoals = List<String>.from(widget.userData['bodyGoals']);
    }
    if (widget.userData['notificationPreferences'] is List) {
      _selectedNotificationPreferences = List<String>.from(widget.userData['notificationPreferences']);
    }
    if (widget.userData['allergies'] is List) {
      _selectedAllergies = List<String>.from(widget.userData['allergies']);
    }
    _selectedActivityLevel = widget.userData['activityLevel'] ?? '';
    
    // Parse birthday
    if (widget.userData['birthday'] != null) {
      try {
        _selectedBirthday = DateTime.parse(widget.userData['birthday']);
      } catch (e) {
        print('Error parsing birthday: $e');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _otherConditionController.dispose();
    _medicationController.dispose();
    _otherDietController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final userData = {
        'email': _emailController.text.trim(),
        'name': _fullNameController.text.trim(),
        'role': _selectedRole,
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text) ?? 0.0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'birthday': _selectedBirthday?.toIso8601String(),
        'healthConditions': _selectedHealthConditions,
        'otherCondition': _otherConditionController.text.trim(),
        'medication': _medicationController.text.trim(),
        'dietaryPreferences': _selectedDietaryPreferences,
        'otherDiet': _otherDietController.text.trim(),
        'bodyGoals': _selectedBodyGoals,
        'notificationPreferences': _selectedNotificationPreferences,
        'allergies': _selectedAllergies,
        'activityLevel': _selectedActivityLevel,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': 'admin',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "${_fullNameController.text.trim()}" updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onUserUpdated();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error updating user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit User',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          'Update user details for ${_fullNameController.text}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Progress indicator
            Row(
              children: [
                _buildStepIndicator(0, 'Account'),
                _buildStepIndicator(1, 'Profile'),
                _buildStepIndicator(2, 'Health'),
                _buildStepIndicator(3, 'Preferences'),
              ],
            ),
            const SizedBox(height: 20),
            
            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                  },
                  children: [
                    _buildAccountStep(),
                    _buildProfileStep(),
                    _buildHealthStep(),
                    _buildPreferencesStep(),
                  ],
                ),
              ),
            ),
            
            // Navigation buttons
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: _isUpdating ? null : () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_currentStep < 3)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Next'),
                    ),
                  ),
                if (_currentStep < 3) const SizedBox(width: 12),
                if (_currentStep == 3)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updateUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update User'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCompleted 
                  ? Colors.green 
                  : isActive 
                      ? Colors.blue 
                      : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.admin_panel_settings),
              border: OutlineInputBorder(),
            ),
            items: _roles.map((role) {
              return DropdownMenuItem<String>(
                value: role,
                child: Text(role.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRole = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a role';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            items: _genders.map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectBirthday,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Birthday',
                prefixIcon: Icon(Icons.cake),
                border: OutlineInputBorder(),
              ),
              child: Text(
                _selectedBirthday != null
                    ? '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}'
                    : 'Select birthday',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    prefixIcon: Icon(Icons.height),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final height = double.tryParse(value);
                      if (height == null || height <= 0) {
                        return 'Please enter a valid height';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final weight = double.tryParse(value);
                      if (weight == null || weight <= 0) {
                        return 'Please enter a valid weight';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Health Conditions:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _healthConditions.map((condition) {
              final isSelected = _selectedHealthConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedHealthConditions.add(condition);
                    } else {
                      _selectedHealthConditions.remove(condition);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherConditionController,
            decoration: const InputDecoration(
              labelText: 'Other Health Conditions',
              prefixIcon: Icon(Icons.medical_services),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _medicationController,
            decoration: const InputDecoration(
              labelText: 'Current Medications',
              prefixIcon: Icon(Icons.medication),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text(
            'Allergies:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergies.map((allergy) {
              final isSelected = _selectedAllergies.contains(allergy);
              return FilterChip(
                label: Text(allergy),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAllergies.add(allergy);
                    } else {
                      _selectedAllergies.remove(allergy);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Dietary Preferences:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietaryPreferences.map((preference) {
              final isSelected = _selectedDietaryPreferences.contains(preference);
              return FilterChip(
                label: Text(preference),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDietaryPreferences.add(preference);
                    } else {
                      _selectedDietaryPreferences.remove(preference);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherDietController,
            decoration: const InputDecoration(
              labelText: 'Other Dietary Preferences',
              prefixIcon: Icon(Icons.restaurant),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text(
            'Body Goals:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bodyGoals.map((goal) {
              final isSelected = _selectedBodyGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedBodyGoals.add(goal);
                    } else {
                      _selectedBodyGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Activity Level:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedActivityLevel,
            decoration: const InputDecoration(
              labelText: 'Activity Level',
              prefixIcon: Icon(Icons.fitness_center),
              border: OutlineInputBorder(),
            ),
            items: _activityLevels.map((level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedActivityLevel = value;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Notification Preferences:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _notificationTypes.map((type) {
              final isSelected = _selectedNotificationPreferences.contains(type);
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedNotificationPreferences.add(type);
                    } else {
                      _selectedNotificationPreferences.remove(type);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }
}
