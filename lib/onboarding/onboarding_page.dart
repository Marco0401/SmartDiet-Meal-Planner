import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'steps/basic_info_step.dart';
import 'steps/health_info_step.dart';
import 'steps/dietary_preferences_step.dart';
import 'steps/body_goals_step.dart';
import 'steps/notifications_step.dart';

class OnboardingPage extends StatefulWidget {
  final String uid;
  const OnboardingPage({required this.uid, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  String? _error;
  // Data for all steps
  String? fullName;
  DateTime? birthday;
  String? gender;
  double? height;
  double? weight;
  List<String> healthConditions = [];
  List<String> allergies = [];
  String? otherCondition;
  String? medication;
  List<String> dietaryPreferences = [];
  String? otherDiet;
  String? goal;
  String? activityLevel;
  List<String> notifications = [];

  bool get _basicInfoValid =>
      fullName != null &&
      fullName!.trim().isNotEmpty &&
      birthday != null &&
      gender != null &&
      gender!.isNotEmpty &&
      height != null &&
      height! > 0 &&
      weight != null &&
      weight! > 0;

  bool get _healthInfoValid =>
      (healthConditions.isNotEmpty &&
          (healthConditions.contains('None') ||
              healthConditions.any((c) => c != 'None' && c.isNotEmpty))) &&
      (allergies.isNotEmpty &&
          (allergies.contains('None') ||
              allergies.any((a) => a != 'None' && a.isNotEmpty)));

  bool get _dietValid =>
      dietaryPreferences.isNotEmpty &&
      (dietaryPreferences.contains('None') ||
          dietaryPreferences.any((d) => d != 'None' && d.isNotEmpty));

  bool get _goalsValid =>
      goal != null &&
      goal!.isNotEmpty &&
      activityLevel != null &&
      activityLevel!.isNotEmpty;

  void _nextStep() {
    setState(() {
      _error = null;
    });
    if (_step == 0 && !_basicInfoValid) {
      setState(() {
        _error = 'Please complete all required fields.';
      });
      return;
    }
    if (_step == 1 && !_healthInfoValid) {
      setState(() {
        _error =
            'Please select at least one health condition and one allergy (or None).';
      });
      return;
    }
    if (_step == 2 && !_dietValid) {
      setState(() {
        _error = 'Please select at least one dietary preference (or None).';
      });
      return;
    }
    if (_step == 3 && !_goalsValid) {
      setState(() {
        _error = 'Please select your goal and activity level.';
      });
      return;
    }
    setState(() {
      _step++;
      _error = null;
    });
  }

  void _prevStep() {
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (!_basicInfoValid) {
      setState(() {
        _error = 'Please complete all required fields.';
      });
      return;
    }
    if (!_healthInfoValid) {
      setState(() {
        _error =
            'Please select at least one health condition and one allergy (or None).';
      });
      return;
    }
    if (!_dietValid) {
      setState(() {
        _error = 'Please select at least one dietary preference (or None).';
      });
      return;
    }
    if (!_goalsValid) {
      setState(() {
        _error = 'Please select your goal and activity level.';
      });
      return;
    }
    // notifications are optional
    int calculateAge(DateTime birthDate) {
      final now = DateTime.now();
      int years = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        years--;
      }
      return years;
    }

    final profile = UserProfile(
      uid: widget.uid,
      fullName: fullName!,
      age: calculateAge(birthday!),
      gender: gender!,
      height: height!,
      weight: weight!,
      healthConditions: healthConditions,
      allergies: allergies,
      otherCondition: otherCondition,
      medication: medication,
      dietaryPreferences: dietaryPreferences,
      otherDiet: otherDiet,
      goal: goal!,
      activityLevel: activityLevel!,
      notifications: notifications,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .set(profile.toMap());
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      BasicInfoStep(
        fullName: fullName,
        birthday: birthday,
        gender: gender,
        height: height,
        weight: weight,
        onChanged: (f, b, g, h, w) {
          setState(() {
            fullName = f;
            birthday = b;
            gender = g;
            height = h;
            weight = w;
          });
        },
      ),
      HealthInfoStep(
        healthConditions: healthConditions,
        allergies: allergies,
        otherCondition: otherCondition,
        medication: medication,
        onChanged: (hc, al, oc, med) {
          setState(() {
            healthConditions = hc;
            allergies = al;
            otherCondition = oc;
            medication = med;
          });
        },
      ),
      DietaryPreferencesStep(
        dietaryPreferences: dietaryPreferences,
        otherDiet: otherDiet,
        onChanged: (dp, od) {
          setState(() {
            dietaryPreferences = dp;
            otherDiet = od;
          });
        },
      ),
      BodyGoalsStep(
        goal: goal,
        activityLevel: activityLevel,
        onChanged: (g, al) {
          setState(() {
            goal = g;
            activityLevel = al;
          });
        },
      ),
      NotificationsStep(
        notifications: notifications,
        onChanged: (n) {
          setState(() {
            notifications = n;
          });
        },
      ),
    ];
    final stepTitles = [
      'Basic Info',
      'Health',
      'Diet',
      'Goals',
      'Notifications',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(stepTitles[_step]),
        automaticallyImplyLeading: _step > 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                steps.length,
                (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step ? Colors.green : Colors.green[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(child: steps[_step]),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    (_step == 0 && !_basicInfoValid) ||
                        (_step == 1 && !_healthInfoValid) ||
                        (_step == 2 && !_dietValid) ||
                        (_step == 3 && !_goalsValid)
                    ? null
                    : _step == steps.length - 1
                    ? _submit
                    : _nextStep,
                child: Text(_step == steps.length - 1 ? 'Finish' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
