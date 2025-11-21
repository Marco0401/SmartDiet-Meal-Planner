import 'package:flutter/material.dart';

class HealthInfoStep extends StatefulWidget {
  final List<String> healthConditions;
  final List<String> allergies;
  final String? otherCondition;
  final String? medication;
  final void Function(List<String>, List<String>, String?, String?) onChanged;

  const HealthInfoStep({
    super.key,
    required this.healthConditions,
    required this.allergies,
    this.otherCondition,
    this.medication,
    required this.onChanged,
  });

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

  @override
  State<HealthInfoStep> createState() => _HealthInfoStepState();
}

class _HealthInfoStepState extends State<HealthInfoStep> {
  late TextEditingController otherConditionController;
  late TextEditingController medicationController;
  late TextEditingController customAllergyController;
  late List<String> selectedConditions;
  late List<String> selectedAllergies;

  @override
  void initState() {
    super.initState();
    otherConditionController = TextEditingController(text: widget.otherCondition);
    medicationController = TextEditingController(text: widget.medication);
    customAllergyController = TextEditingController();
    selectedConditions = List.from(widget.healthConditions);
    selectedAllergies = List.from(widget.allergies);
  }

  @override
  void dispose() {
    otherConditionController.dispose();
    medicationController.dispose();
    customAllergyController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(selectedConditions, selectedAllergies, otherConditionController.text, medicationController.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💪 Health Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Do you have any of the following conditions?'),
          ...HealthInfoStep.conditionsList.map((c) => CheckboxListTile(
                value: selectedConditions.contains(c),
                title: Text(c),
                onChanged: (v) {
                  if (c == 'None') {
                    if (v == true) {
                      selectedConditions.clear();
                      selectedConditions.add('None');
                    } else {
                      selectedConditions.remove('None');
                    }
                  } else {
                    if (v == true) {
                      selectedConditions.remove('None');
                      selectedConditions.add(c);
                    } else {
                      selectedConditions.remove(c);
                    }
                  }
                  _notifyChange();
                },
              )),
          const SizedBox(height: 16),
          const Text('Known Food Allergies?'),
          ...HealthInfoStep.allergiesList.map((a) => CheckboxListTile(
                value: selectedAllergies.contains(a),
                title: Text(a),
                onChanged: (v) {
                  if (a == 'None') {
                    if (v == true) {
                      selectedAllergies.clear();
                      selectedAllergies.add('None');
                    } else {
                      selectedAllergies.remove('None');
                    }
                  } else {
                    if (v == true) {
                      selectedAllergies.remove('None');
                      selectedAllergies.add(a);
                    } else {
                      selectedAllergies.remove(a);
                    }
                  }
                  _notifyChange();
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 