import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BasicInfoStep extends StatefulWidget {
  final String? fullName;
  final DateTime? birthday;
  final String? gender;
  final double? height;
  final double? weight;
  final void Function(String, DateTime?, String, double, double) onChanged;

  const BasicInfoStep({
    super.key,
    this.fullName,
    this.birthday,
    this.gender,
    this.height,
    this.weight,
    required this.onChanged,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late TextEditingController _fullNameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  DateTime? _birthday;
  String? _gender;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName ?? '');
    _heightController = TextEditingController(
      text: widget.height?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.weight?.toString() ?? '',
    );
    _birthday = widget.birthday;
    _gender = widget.gender;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
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

  void _notifyChange() {
    widget.onChanged(
      _fullNameController.text,
      _birthday,
      _gender ?? '',
      double.tryParse(_heightController.text) ?? 0,
      double.tryParse(_weightController.text) ?? 0,
    );
    setState(() {
      _showError = false;
    });
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
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Basic Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              errorText: _showError && _fullNameController.text.trim().isEmpty
                  ? 'Required'
                  : null,
            ),
            onChanged: (v) => setState(_notifyChange),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBirthday,
            child: AbsorbPointer(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Birthday',
                  hintText: 'Select your birthday',
                  suffixIcon: const Icon(Icons.calendar_today),
                  errorText: _showError && _birthday == null
                      ? 'Required'
                      : null,
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
            value: _gender?.isNotEmpty == true ? _gender : null,
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() {
              _gender = v;
              _notifyChange();
            }),
            decoration: InputDecoration(
              labelText: 'Sex/Gender',
              errorText: _showError && (_gender == null || _gender!.isEmpty)
                  ? 'Required'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            decoration: InputDecoration(
              labelText: 'Height (cm)',
              errorText:
                  _showError &&
                      (double.tryParse(_heightController.text) == null ||
                          double.tryParse(_heightController.text)! <= 0)
                  ? 'Required'
                  : null,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(_notifyChange),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            decoration: InputDecoration(
              labelText: 'Weight (kg)',
              errorText:
                  _showError &&
                      (double.tryParse(_weightController.text) == null ||
                          double.tryParse(_weightController.text)! <= 0)
                  ? 'Required'
                  : null,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(_notifyChange),
          ),
        ],
      ),
    );
  }
}
