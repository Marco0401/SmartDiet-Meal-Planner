import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

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

  // Expansion state
  bool _basicInfoExpanded = true;
  bool _healthInfoExpanded = false;
  bool _dietaryExpanded = false;
  bool _goalsExpanded = false;
  bool _notificationsExpanded = false;

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
          // Document doesn't exist, use Firebase Auth email
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
          'notificationPreferences': _notifications, // Also save to the field used by NotificationService
          'email': user.email, // Preserve the email from Firebase Auth
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
            .update(profileData);

      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
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

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(_profileImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profilePhoto': downloadUrl});

      setState(() {
        _profilePhotoUrl = downloadUrl;
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
                          ? NetworkImage(_profilePhotoUrl!) as ImageProvider
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
    return Scaffold(
        body: Stack(
          children: [
            // Background gradient
            Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                    Color(0xFF4CAF50),
                    Color(0xFF66BB6A),
                  ),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FFF4), Color(0xFFE8F5E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                // Basic Information Section
                _buildSectionCard(
                  title: '👤 Basic Information',
                  icon: Icons.person,
                  children: [
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        helperText: 'Email cannot be changed',
                        helperStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Birthday',
                            hintText: 'Select your birthday',
                            prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF4CAF50)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          controller: TextEditingController(
                            text: _birthday != null
                                ? DateFormat('yyyy-MM-dd').format(_birthday!)
                                : '',
                          ),
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
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                      decoration: InputDecoration(
                        labelText: 'Sex/Gender',
                        prefixIcon: const Icon(Icons.wc, color: Color(0xFF4CAF50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                                  ),
                                  const SizedBox(height: 16),
                    TextField(
                                          controller: _heightController,
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: const Icon(Icons.height, color: Color(0xFF4CAF50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                                          keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: const Icon(Icons.monitor_weight, color: Color(0xFF4CAF50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                              
                              // Health Information Section
                              _buildSectionCard(
                  title: '💪 Health Information',
                  icon: Icons.health_and_safety,
                                children: [
                    const Text('Do you have any of the following conditions?'),
                    const SizedBox(height: 8),
                    ...conditionsList.map((c) => CheckboxListTile(
                          value: _healthConditions.contains(c),
                          title: Text(c),
                          onChanged: (v) {
                            setState(() {
                              if (c == 'None') {
                                if (v == true) {
                                  _healthConditions.clear();
                                  _healthConditions.add('None');
                                } else {
                                  _healthConditions.remove('None');
                                }
                              } else {
                                if (v == true) {
                                  _healthConditions.remove('None');
                                  _healthConditions.add(c);
                                } else {
                                  _healthConditions.remove(c);
                                }
                              }
                            });
                          },
                        )),
                    CheckboxListTile(
                      value: _otherConditionController.text.isNotEmpty,
                      title: const Text('Other'),
                      onChanged: (v) {},
                      secondary: SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _otherConditionController,
                          decoration: InputDecoration(
                            hintText: 'Specify',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (val) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Known Food Allergies?'),
                    const SizedBox(height: 8),
                    ...allergiesList.map((a) => CheckboxListTile(
                          value: _allergies.contains(a),
                          title: Text(a),
                          onChanged: (v) {
                            setState(() {
                              if (a == 'None') {
                                if (v == true) {
                                  _allergies.clear();
                                  _allergies.add('None');
                                } else {
                                  _allergies.remove('None');
                                }
                              } else {
                                if (v == true) {
                                  _allergies.remove('None');
                                  _allergies.add(a);
                                } else {
                                  _allergies.remove(a);
                                }
                              }
                            });
                          },
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customAllergyController,
                            decoration: InputDecoration(
                              hintText: 'Add your own',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (_customAllergyController.text.isNotEmpty) {
                              setState(() {
                                _allergies.add(_customAllergyController.text);
                                _customAllergyController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Are you taking any medication that affects your diet?'),
                    const SizedBox(height: 8),
                    TextField(
                                    controller: _medicationController,
                      decoration: InputDecoration(
                        labelText: 'Medication (optional)',
                        prefixIcon: const Icon(Icons.medication, color: Color(0xFF4CAF50)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                                  ),
                                ],
                              ),
                              
                              // Dietary Preferences Section
                              _buildSectionCard(
                  title: '🥗 Dietary Preferences',
                                    icon: Icons.restaurant,
                  children: [
                    const Text('Are you following a specific diet?'),
                    const SizedBox(height: 8),
                    ...dietList.map((d) => CheckboxListTile(
                          value: _dietaryPreferences.contains(d),
                          title: Text(d),
                          onChanged: (v) {
                            setState(() {
                              if (d == 'None') {
                                if (v == true) {
                                  _dietaryPreferences.clear();
                                  _dietaryPreferences.add('None');
                                } else {
                                  _dietaryPreferences.remove('None');
                                }
                              } else {
                                if (v == true) {
                                  _dietaryPreferences.remove('None');
                                  _dietaryPreferences.add(d);
                                } else {
                                  _dietaryPreferences.remove(d);
                                }
                              }
                            });
                          },
                        )),
                    CheckboxListTile(
                      value: _otherDietController.text.isNotEmpty,
                      title: const Text('Other'),
                      onChanged: (v) {},
                      secondary: SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _otherDietController,
                          decoration: InputDecoration(
                            hintText: 'Specify',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                                  ),
                                ],
                              ),
                              
                              // Body Goals Section
                              _buildSectionCard(
                  title: '🎯 Body Goals',
                  icon: Icons.fitness_center,
                                children: [
                    const Text('What is your goal?'),
                    const SizedBox(height: 8),
                    ...goals.map((g) => RadioListTile<String>(
                          value: g,
                          groupValue: _goal,
                          title: Text(g),
                                    onChanged: (v) => setState(() => _goal = v),
                        )),
                    const SizedBox(height: 16),
                    const Text('Activity Level'),
                    const SizedBox(height: 8),
                    ...activityLevels.map((a) => RadioListTile<String>(
                          value: a,
                          groupValue: _activityLevel,
                          title: Text(a),
                                    onChanged: (v) => setState(() => _activityLevel = v),
                        )),
                                ],
                              ),
                              
                              // Notifications Section
                              _buildSectionCard(
                  title: '🔔 Push Notifications',
                                    icon: Icons.notifications,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These settings control push notifications. In-app notifications are always shown.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...notificationTypes.map((n) => CheckboxListTile(
                          value: _notifications.contains(n),
                          title: Text(n),
                          onChanged: (v) {
                            setState(() {
                              if (n == 'None') {
                                if (v == true) {
                                  _notifications.clear();
                                  _notifications.add('None');
                                } else {
                                  _notifications.remove('None');
                                }
                              } else {
                                if (v == true) {
                                  _notifications.remove('None');
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

                const SizedBox(height: 32),
                              
                              // Save Button
                              Container(
                                width: double.infinity,
                  height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4CAF50),
                        Color(0xFF66BB6A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                        spreadRadius: 2,
                                    ),
                                  ],
                                ),
                  child: ElevatedButton(
                                  onPressed: _saving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, color: Colors.white, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black26,
                                    ),
                            ],
                          ),
                        ),
                            ],
                      ),
                    ),
                ),

                const SizedBox(height: 32),
                  ],
            ),
                ),
              ),
        ),
      );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.green.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
              padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4CAF50),
                    Color(0xFF66BB6A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
                    color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
      children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
            Text(
                    title,
              style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black26,
                        ),
                      ],
                  ),
                ),
              ],
            ),
          ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}