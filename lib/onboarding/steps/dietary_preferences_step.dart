import 'package:flutter/material.dart';

class DietaryPreferencesStep extends StatefulWidget {
  final List<String> dietaryPreferences;
  final String? otherDiet;
  final void Function(List<String>, String?) onChanged;

  const DietaryPreferencesStep({
    super.key,
    required this.dietaryPreferences,
    this.otherDiet,
    required this.onChanged,
  });

  @override
  State<DietaryPreferencesStep> createState() => _DietaryPreferencesStepState();
}

class _DietaryPreferencesStepState extends State<DietaryPreferencesStep> {
  static const List<String> dietList = [
    'None',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto',
    'Low Carb',
    'Low Sodium',
    'Halal',
  ];

  late String _selectedDiet;
  late TextEditingController _otherDietController;

  @override
  void initState() {
    super.initState();
    // Initialize with first preference or 'None'
    _selectedDiet = widget.dietaryPreferences.isNotEmpty 
        ? widget.dietaryPreferences.first 
        : 'None';
    _otherDietController = TextEditingController(text: widget.otherDiet);
  }

  @override
  void dispose() {
    _otherDietController.dispose();
    super.dispose();
  }

  void _updateSelection(String diet) {
    setState(() {
      _selectedDiet = diet;
    });
    // Always pass as single-item list for consistency
    widget.onChanged([diet], _otherDietController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🥗 Dietary Preference', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Select your primary dietary preference:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: Select ONE dietary preference. This will automatically filter recipe searches and meal suggestions throughout the app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...dietList.map((diet) => RadioListTile<String>(
                value: diet,
                groupValue: _selectedDiet,
                title: Text(diet),
                onChanged: (value) {
                  if (value != null) {
                    _updateSelection(value);
                  }
                },
                activeColor: Colors.green,
              )),
        ],
      ),
    );
  }
} 