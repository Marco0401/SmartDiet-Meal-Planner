import 'package:flutter/material.dart';

class TimePickerDialog extends StatefulWidget {
  final TimeOfDay? initialTime;
  final String title;

  const TimePickerDialog({
    super.key,
    this.initialTime,
    this.title = 'Select Time',
  });

  @override
  State<TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<TimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime ?? TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _selectedTime.format(context),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Quick preset buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton('7:00 AM', TimeOfDay(hour: 7, minute: 0)),
                _buildPresetButton('12:00 PM', TimeOfDay(hour: 12, minute: 0)),
                _buildPresetButton('3:00 PM', TimeOfDay(hour: 15, minute: 0)),
                _buildPresetButton('6:00 PM', TimeOfDay(hour: 18, minute: 0)),
                _buildPresetButton('8:00 PM', TimeOfDay(hour: 20, minute: 0)),
              ],
            ),
            const SizedBox(height: 20),
            
            // Manual time picker
            ElevatedButton.icon(
              onPressed: _showTimePicker,
              icon: const Icon(Icons.access_time),
              label: const Text('Choose Custom Time'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedTime),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, TimeOfDay time) {
    final isSelected = _selectedTime.hour == time.hour && _selectedTime.minute == time.minute;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }
}

// Helper function to get default time for meal type
TimeOfDay getDefaultTimeForMealType(String mealType) {
  switch (mealType.toLowerCase()) {
    case 'breakfast':
      return const TimeOfDay(hour: 7, minute: 0);
    case 'lunch':
      return const TimeOfDay(hour: 12, minute: 0);
    case 'dinner':
      return const TimeOfDay(hour: 18, minute: 0);
    case 'snack':
      return const TimeOfDay(hour: 15, minute: 0);
    default:
      return const TimeOfDay(hour: 12, minute: 0);
  }
}

// Helper function to format time for display
String formatTimeForDisplay(TimeOfDay time, BuildContext context) {
  return time.format(context);
}

// Helper function to convert TimeOfDay to DateTime for storage
DateTime timeOfDayToDateTime(TimeOfDay time, DateTime date) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// Helper function to convert stored time back to TimeOfDay
TimeOfDay dateTimeToTimeOfDay(DateTime dateTime) {
  return TimeOfDay.fromDateTime(dateTime);
}
