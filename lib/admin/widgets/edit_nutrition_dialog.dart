import 'package:flutter/material.dart';

class EditNutritionDialog extends StatefulWidget {
  final Map<String, dynamic> substitution;
  final Function(Map<String, dynamic>) onSave;

  const EditNutritionDialog({
    super.key,
    required this.substitution,
    required this.onSave,
  });

  @override
  State<EditNutritionDialog> createState() => _EditNutritionDialogState();
}

class _EditNutritionDialogState extends State<EditNutritionDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  late Map<String, dynamic> _nutrition;

  @override
  void initState() {
    super.initState();
    _nutrition = Map<String, dynamic>.from(widget.substitution['nutrition'] ?? {});
    _controllers = {
      'calories': TextEditingController(text: _nutrition['calories']?.toString() ?? '0'),
      'protein': TextEditingController(text: _nutrition['protein']?.toString() ?? '0'),
      'carbs': TextEditingController(text: _nutrition['carbs']?.toString() ?? '0'),
      'fat': TextEditingController(text: _nutrition['fat']?.toString() ?? '0'),
      'fiber': TextEditingController(text: _nutrition['fiber']?.toString() ?? '0'),
      'sugar': TextEditingController(text: _nutrition['sugar']?.toString() ?? '0'),
      'sodium': TextEditingController(text: _nutrition['sodium']?.toString() ?? '0'),
      'cholesterol': TextEditingController(text: _nutrition['cholesterol']?.toString() ?? '0'),
    };
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final updatedNutrition = <String, dynamic>{};
      _controllers.forEach((key, controller) {
        updatedNutrition[key] = double.tryParse(controller.text) ?? 0.0;
      });

      final updatedSubstitution = Map<String, dynamic>.from(widget.substitution);
      updatedSubstitution['nutrition'] = updatedNutrition;

      widget.onSave(updatedSubstitution);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Nutrition: ${widget.substitution['substitution']}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildNutritionField('Calories', _controllers['calories']!, 'cal'),
                _buildNutritionField('Protein', _controllers['protein']!, 'g'),
                _buildNutritionField('Carbohydrates', _controllers['carbs']!, 'g'),
                _buildNutritionField('Fat', _controllers['fat']!, 'g'),
                _buildNutritionField('Fiber', _controllers['fiber']!, 'g'),
                _buildNutritionField('Sugar', _controllers['sugar']!, 'g'),
                _buildNutritionField('Sodium', _controllers['sodium']!, 'mg'),
                _buildNutritionField('Cholesterol', _controllers['cholesterol']!, 'mg'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildNutritionField(String label, TextEditingController controller, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (double.tryParse(value) == null) return 'Invalid number';
          return null;
        },
      ),
    );
  }
}
