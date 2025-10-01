import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MealPlanDialog extends StatefulWidget {
  const MealPlanDialog({super.key});

  @override
  State<MealPlanDialog> createState() => _MealPlanDialogState();
}

class _MealPlanDialogState extends State<MealPlanDialog> {
  DateTime _selectedDate = DateTime.now();
  String _selectedMealType = 'lunch';
  
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Meal Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date Selection
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Date'),
            subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Meal Type Selection
          DropdownButtonFormField<String>(
            value: _selectedMealType,
            decoration: const InputDecoration(
              labelText: 'Meal Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.restaurant),
            ),
            items: _mealTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.substring(0, 1).toUpperCase() + type.substring(1)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMealType = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
              'mealType': _selectedMealType,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add to Plan'),
        ),
      ],
    );
  }
}
