import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'user_profile_page.dart';
import 'health_insights_page.dart';
import 'debug_user_data_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // Basic Information
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _email;
  DateTime? _birthday;
  String? _gender;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Health Information
  List<String> _healthConditions = [];
  List<String> _allergies = [];
  final TextEditingController _otherConditionController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _customAllergyController = TextEditingController();

  // Dietary Preferences
  List<String> _dietaryPreferences = [];
  final TextEditingController _otherDietController = TextEditingController();

  // Body Goals
  String? _goal;
  String? _activityLevel;

  // Notifications
  List<String> _notifications = [];

  // Profile Picture
  String? _profilePhotoUrl;
  File? _profileImage;
  bool _uploadingImage = false;

  bool _loading = true;
  bool _saving = false;

  // Constants from onboarding steps
  static const List<String> conditionsList = [
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

  static const List<String> allergiesList = [
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

  static const List<String> dietList = [
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

  static const List<String> goals = [
    'None',
    'Lose weight',
    'Gain weight',
    'Maintain current weight',
    'Build muscle',
    'Eat healthier / clean eating',
  ];

  static const List<String> activityLevels = [
    'None',
    'Sedentary (little or no exercise)',
    'Lightly active (light exercise/sports 1–3 days/week)',
    'Moderately active (moderate exercise/sports 3–5 days/week)',
    'Very active (hard exercise 6–7 days/week)',
  ];

  static const List<String> notificationTypes = [
    'None',
    'Messages',
    'Meal reminders',
    'Tips',
    'Updates',
    'News',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _otherConditionController.dispose();
    _medicationController.dispose();
    _customAllergyController.dispose();
    _otherDietController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
    final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            // Profile Photo
            _profilePhotoUrl = data['profilePhoto'] ?? data['photoUrl'];
            
            // Basic Information
      _fullNameController.text = data['fullName'] ?? '';
            _email = data['email'] ?? user.email;
            _emailController.text = _email ?? '';
      if (data['birthday'] != null) {
        _birthday = DateTime.tryParse(data['birthday']);
      }
            _gender = data['gender'];
            _heightController.text = data['height']?.toString() ?? '';
            _weightController.text = data['weight']?.toString() ?? '';

            // Health Information
      _healthConditions = List<String>.from(data['healthConditions'] ?? []);
      _allergies = List<String>.from(data['allergies'] ?? []);
            _otherConditionController.text = data['otherCondition'] ?? '';
            _medicationController.text = data['medication'] ?? '';

            // Dietary Preferences
            _dietaryPreferences = List<String>.from(data['dietaryPreferences'] ?? []);
            _otherDietController.text = data['otherDiet'] ?? '';

            // Body Goals
            _goal = data['goal'];
            _activityLevel = data['activityLevel'];

            // Notifications
            _notifications = List<String>.from(data['notifications'] ?? []);

            _loading = false;
          });
        } else {
          setState(() {
            _email = user.email;
            _emailController.text = user.email ?? '';
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    setState(() {
      _loading = false;
    });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profileData = {
          'fullName': _fullNameController.text.trim(),
            'birthday': _birthday?.toIso8601String(),
          'gender': _gender,
          'height': double.tryParse(_heightController.text),
          'weight': double.tryParse(_weightController.text),
            'healthConditions': _healthConditions,
            'allergies': _allergies,
          'otherCondition': _otherConditionController.text.trim(),
          'medication': _medicationController.text.trim(),
            'dietaryPreferences': _dietaryPreferences,
          'otherDiet': _otherDietController.text.trim(),
            'goal': _goal,
            'activityLevel': _activityLevel,
            'notifications': _notifications,
          'notificationPreferences': _notifications,
          'email': user.email,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        // Calculate age if birthday is provided
        if (_birthday != null) {
          final now = DateTime.now();
          int age = now.year - _birthday!.year;
          if (now.month < _birthday!.month ||
              (now.month == _birthday!.month && now.day < _birthday!.day)) {
            age--;
          }
          profileData['age'] = age;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(profileData, SetOptions(merge: true));
      
      print('DEBUG: User settings saved successfully');
      print('DEBUG: Health conditions saved: $_healthConditions');
      print('DEBUG: Dietary preferences saved: $_dietaryPreferences');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully!\nHealth conditions: ${_healthConditions.join(", ")}\nDietary preferences: ${_dietaryPreferences.join(", ")}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      setState(() {
        _saving = false;
      });
    }
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

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        await _uploadProfileImage();
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() {
      _uploadingImage = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Convert image to base64
      final bytes = await _profileImage!.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      // Update Firestore with base64 string
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profilePhoto': base64String});

      setState(() {
        _profilePhotoUrl = base64String;
        _uploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Widget _buildProfileHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _fullNameController.text.isEmpty 
        ? (user?.displayName ?? 'User') 
        : _fullNameController.text;
        
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              // Profile Picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                          ? (_profilePhotoUrl!.startsWith('data:image')
                              ? MemoryImage(base64Decode(_profilePhotoUrl!.split(',')[1]))
                              : NetworkImage(_profilePhotoUrl!)) as ImageProvider
                          : null),
                  child: (_profileImage == null && 
                          (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty))
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                          ),
                        )
                      : null,
                ),
              ),
              // Upload Button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploadingImage ? null : _pickProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _uploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4CAF50),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            _email ?? user?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          // View Public Profile Button
          OutlinedButton.icon(
            onPressed: () {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: currentUserId,
                      isOwnProfile: true,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.person, color: Colors.white),
            label: const Text(
              'View Public Profile',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Health Insights Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HealthInsightsPage(),
                ),
              );
            },
            icon: const Icon(Icons.psychology, color: Colors.white),
            label: const Text(
              '🤖 Health Insights',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Debug User Data Button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugUserDataPage(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report, color: Colors.white),
            label: const Text(
              '🔧 Debug User Data',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
    return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Account Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 20),

            // Basic Information (Collapsible)
            _buildExpansionTile(
              title: 'Basic Information',
              icon: Icons.person,
              children: [
                _buildTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  enabled: false,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickBirthday,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: TextEditingController(
                        text: _birthday != null
                            ? DateFormat('yyyy-MM-dd').format(_birthday!)
                            : '',
                      ),
                      label: 'Birthday',
                      icon: Icons.calendar_today,
                    ),
                  ),
                ),
                if (age != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Text('Age: $age years old'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc, color: Color(0xFF4CAF50)),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _weightController,
                        label: 'Weight (kg)',
                        icon: Icons.monitor_weight,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Health Information (Collapsible)
            _buildExpansionTile(
              title: 'Health Information',
              icon: Icons.health_and_safety,
              children: [
                const Text('Health Conditions:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...conditionsList.map((c) => CheckboxListTile(
                      dense: true,
                      value: _healthConditions.contains(c),
                      title: Text(c, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        setState(() {
                          if (c == 'None') {
                            if (v == true) {
                              _healthConditions.clear();
                              _healthConditions.add('None');
                            }
                          } else {
                            _healthConditions.remove('None');
                            if (v == true) {
                              _healthConditions.add(c);
                            } else {
                              _healthConditions.remove(c);
                            }
                          }
                        });
                      },
                    )),
                const SizedBox(height: 8),
                const Text('Allergies:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...allergiesList.map((a) => CheckboxListTile(
                      dense: true,
                      value: _allergies.contains(a),
                      title: Text(a, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        setState(() {
                          if (a == 'None') {
                            if (v == true) {
                              _allergies.clear();
                              _allergies.add('None');
                            }
                          } else {
                            _allergies.remove('None');
                            if (v == true) {
                              _allergies.add(a);
                            } else {
                              _allergies.remove(a);
                            }
                          }
                        });
                      },
                    )),
              ],
            ),
            const SizedBox(height: 12),

            // Dietary Preferences (Collapsible)
            _buildExpansionTile(
              title: 'Dietary Preferences',
              icon: Icons.restaurant_menu,
              children: [
                ...dietList.map((d) => CheckboxListTile(
                      dense: true,
                      value: _dietaryPreferences.contains(d),
                      title: Text(d, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        setState(() {
                          if (d == 'None') {
                            if (v == true) {
                              _dietaryPreferences.clear();
                              _dietaryPreferences.add('None');
                            }
                          } else {
                            _dietaryPreferences.remove('None');
                            if (v == true) {
                              _dietaryPreferences.add(d);
                            } else {
                              _dietaryPreferences.remove(d);
                            }
                          }
                        });
                      },
                    )),
              ],
            ),
            const SizedBox(height: 12),

            // Goals & Activity (Collapsible)
            _buildExpansionTile(
              title: 'Goals & Activity',
              icon: Icons.flag,
              children: [
                DropdownButtonFormField<String>(
                  value: _goal,
                  items: goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _goal = v),
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    prefixIcon: Icon(Icons.flag, color: Color(0xFF4CAF50)),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _activityLevel,
                  items: activityLevels.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _activityLevel = v),
                  decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    prefixIcon: Icon(Icons.directions_run, color: Color(0xFF4CAF50)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notifications (Collapsible)
            _buildExpansionTile(
              title: 'Notifications',
              icon: Icons.notifications,
              children: [
                ...notificationTypes.map((n) => CheckboxListTile(
                      dense: true,
                      value: _notifications.contains(n),
                      title: Text(n, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        setState(() {
                          if (n == 'None') {
                            if (v == true) {
                              _notifications.clear();
                              _notifications.add('None');
                            }
                          } else {
                            _notifications.remove('None');
                            if (v == true) {
                              _notifications.add(n);
                            } else {
                              _notifications.remove(n);
                            }
                          }
                        });
                      },
                    )),
              ],
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: _saving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: const Color(0xFF4CAF50)),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }
}
