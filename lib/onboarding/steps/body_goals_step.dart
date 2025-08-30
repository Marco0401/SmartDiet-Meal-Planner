import 'package:flutter/material.dart';

class BodyGoalsStep extends StatelessWidget {
  final String? goal;
  final String? activityLevel;
  final void Function(String, String) onChanged;

  const BodyGoalsStep({
    super.key,
    this.goal,
    this.activityLevel,
    required this.onChanged,
  });

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

  @override
  Widget build(BuildContext context) {
    String selectedGoal = goal ?? '';
    String selectedActivity = activityLevel ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Body Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('What is your goal?'),
          ...goals.map((g) => RadioListTile<String>(
                value: g,
                groupValue: selectedGoal,
                title: Text(g),
                onChanged: (v) {
                  if (v == 'None') {
                    selectedGoal = 'None';
                  } else if (selectedGoal == 'None') {
                    selectedGoal = v ?? '';
                  } else {
                    selectedGoal = v ?? '';
                  }
                  onChanged(selectedGoal, selectedActivity);
                },
              )),
          const SizedBox(height: 16),
          const Text('Activity Level'),
          ...activityLevels.map((a) => RadioListTile<String>(
                value: a,
                groupValue: selectedActivity,
                title: Text(a),
                onChanged: (v) {
                  if (v == 'None') {
                    selectedActivity = 'None';
                  } else if (selectedActivity == 'None') {
                    selectedActivity = v ?? '';
                  } else {
                    selectedActivity = v ?? '';
                  }
                  onChanged(selectedGoal, selectedActivity);
                },
              )),
        ],
      ),
    );
  }
} 