import 'package:flutter/material.dart';

class DietaryPreferencesStep extends StatelessWidget {
  final List<String> dietaryPreferences;
  final String? otherDiet;
  final void Function(List<String>, String?) onChanged;

  const DietaryPreferencesStep({
    super.key,
    required this.dietaryPreferences,
    this.otherDiet,
    required this.onChanged,
  });

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

  @override
  Widget build(BuildContext context) {
    final otherDietController = TextEditingController(text: otherDiet);
    List<String> selectedDiets = List.from(dietaryPreferences);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🥗 Dietary Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Are you following a specific diet?'),
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
                    'Note: Your dietary preferences will automatically filter recipe searches and meal suggestions throughout the app.',
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
          ...dietList.map((d) => CheckboxListTile(
                value: selectedDiets.contains(d),
                title: Text(d),
                onChanged: (v) {
                  if (d == 'None') {
                    if (v == true) {
                      selectedDiets.clear();
                      selectedDiets.add('None');
                    } else {
                      selectedDiets.remove('None');
                    }
                  } else {
                    if (v == true) {
                      selectedDiets.remove('None');
                      selectedDiets.add(d);
                    } else {
                      selectedDiets.remove(d);
                    }
                  }
                  onChanged(selectedDiets, otherDietController.text);
                },
              )),
          CheckboxListTile(
            value: otherDiet != null && otherDiet!.isNotEmpty,
            title: const Text('Other'),
            onChanged: (v) {},
            secondary: SizedBox(
              width: 180,
              child: TextField(
                controller: otherDietController,
                decoration: const InputDecoration(hintText: 'Specify'),
                onChanged: (val) => onChanged(selectedDiets, val),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 