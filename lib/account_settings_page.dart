import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationController = TextEditingController();
  final _otherConditionController = TextEditingController();
  final _otherDietController = TextEditingController();
  DateTime? _birthday;
  String? _gender;
  String? _email;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Onboarding fields
  List<String> _healthConditions = [];
  List<String> _allergies = [];
  List<String> _dietaryPreferences = [];
  String? _goal;
  String? _activityLevel;
  List<String> _notifications = [];

  // Options
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
    'Allergy warnings',
    'New healthy recipes',
    'Nutrition tips',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _email = user.email;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data != null) {
      _fullNameController.text = data['fullName'] ?? '';
      _heightController.text = (data['height']?.toString() ?? '');
      _weightController.text = (data['weight']?.toString() ?? '');
      _gender = data['gender'] ?? '';
      if (data['birthday'] != null) {
        _birthday = DateTime.tryParse(data['birthday']);
      }
      _healthConditions = List<String>.from(data['healthConditions'] ?? []);
      _allergies = List<String>.from(data['allergies'] ?? []);
      _medicationController.text = data['medication'] ?? '';
      _otherConditionController.text = data['otherCondition'] ?? '';
      _dietaryPreferences = List<String>.from(data['dietaryPreferences'] ?? []);
      _otherDietController.text = data['otherDiet'] ?? '';
      _goal = data['goal'] ?? '';
      _activityLevel = data['activityLevel'] ?? '';
      _notifications = List<String>.from(data['notifications'] ?? []);
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'fullName': _fullNameController.text,
            'height': double.tryParse(_heightController.text) ?? 0,
            'weight': double.tryParse(_weightController.text) ?? 0,
            'gender': _gender,
            'birthday': _birthday?.toIso8601String(),
            'healthConditions': _healthConditions,
            'allergies': _allergies,
            'medication': _medicationController.text,
            'otherCondition': _otherConditionController.text,
            'dietaryPreferences': _dietaryPreferences,
            'otherDiet': _otherDietController.text,
            'goal': _goal,
            'activityLevel': _activityLevel,
            'notifications': _notifications,
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update profile.';
      });
    } finally {
      setState(() {
        _saving = false;
      });
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

  Widget _buildChips({
    required List<String> options,
    required List<String> selected,
    required void Function(List<String>) onChanged,
    String? label,
    IconData? icon,
    bool allowCustom = false,
    TextEditingController? customController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Row(
            children: [
              if (icon != null) Icon(icon, size: 20, color: Colors.green),
              if (icon != null) const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (v) {
                final newSelected = List<String>.from(selected);
                if (opt == 'None') {
                  if (v) {
                    newSelected.clear();
                    newSelected.add('None');
                  } else {
                    newSelected.remove('None');
                  }
                } else {
                  if (v) {
                    newSelected.remove('None');
                    newSelected.add(opt);
                  } else {
                    newSelected.remove(opt);
                  }
                }
                onChanged(newSelected);
              },
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[800],
            );
          }).toList(),
        ),
        if (allowCustom && customController != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customController,
                    decoration: const InputDecoration(hintText: 'Add your own'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (customController.text.isNotEmpty) {
                      final newSelected = List<String>.from(selected);
                      newSelected.remove('None');
                      newSelected.add(customController.text);
                      onChanged(newSelected);
                      customController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRadioGroup({
    required List<String> options,
    required String? value,
    required void Function(String?) onChanged,
    String? label,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Row(
            children: [
              if (icon != null) Icon(icon, size: 20, color: Colors.green),
              if (icon != null) const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        const SizedBox(height: 8),
        ...options.map(
          (opt) => RadioListTile<String>(
            value: opt,
            groupValue: value,
            title: Text(opt),
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildNotificationChips() {
    return _buildChips(
      options: notificationTypes,
      selected: _notifications,
      onChanged: (v) => setState(() => _notifications = v),
      label: 'Notifications',
      icon: Icons.notifications,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationController.dispose();
    _otherConditionController.dispose();
    _otherDietController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Birthday',
                            hintText: 'Select your birthday',
                            prefixIcon: const Icon(Icons.cake),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _birthday != null
                                ? DateFormat('yyyy-MM-dd').format(_birthday!)
                                : '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _gender?.isNotEmpty == true ? _gender : null,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() {
                        _gender = v;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Sex/Gender',
                        prefixIcon: Icon(Icons.wc),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Health Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildChips(
                      options: conditionsList,
                      selected: _healthConditions,
                      onChanged: (v) => setState(() => _healthConditions = v),
                      label: 'Health Conditions',
                      icon: Icons.local_hospital,
                      allowCustom: true,
                      customController: _otherConditionController,
                    ),
                    _buildChips(
                      options: allergiesList,
                      selected: _allergies,
                      onChanged: (v) => setState(() => _allergies = v),
                      label: 'Allergies',
                      icon: Icons.warning,
                      allowCustom: true,
                      customController: TextEditingController(),
                    ),
                    TextFormField(
                      controller: _medicationController,
                      decoration: const InputDecoration(
                        labelText: 'Medication (optional)',
                        prefixIcon: Icon(Icons.medication),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Dietary Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildChips(
                      options: dietList,
                      selected: _dietaryPreferences,
                      onChanged: (v) => setState(() => _dietaryPreferences = v),
                      label: 'Dietary Preferences',
                      icon: Icons.restaurant,
                      allowCustom: true,
                      customController: _otherDietController,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Body Goals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildRadioGroup(
                      options: goals,
                      value: _goal,
                      onChanged: (v) => setState(() => _goal = v),
                      label: 'Goal',
                      icon: Icons.flag,
                    ),
                    _buildRadioGroup(
                      options: activityLevels,
                      value: _activityLevel,
                      onChanged: (v) => setState(() => _activityLevel = v),
                      label: 'Activity Level',
                      icon: Icons.directions_run,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _buildNotificationChips(),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save'),
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
                  ],
                ),
              ),
            ),
    );
  }
}
