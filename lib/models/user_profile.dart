// User profile model for onboarding and dietary basis
class UserProfile {
  final String uid;
  final String fullName;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final List<String> healthConditions;
  final List<String> allergies;
  final String? otherCondition;
  final String? medication;
  final List<String> dietaryPreferences;
  final String? otherDiet;
  final String goal;
  final String activityLevel;
  final List<String> notifications;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.healthConditions,
    required this.allergies,
    this.otherCondition,
    this.medication,
    required this.dietaryPreferences,
    this.otherDiet,
    required this.goal,
    required this.activityLevel,
    required this.notifications,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'healthConditions': healthConditions,
      'allergies': allergies,
      'otherCondition': otherCondition,
      'medication': medication,
      'dietaryPreferences': dietaryPreferences,
      'otherDiet': otherDiet,
      'goal': goal,
      'activityLevel': activityLevel,
      'notifications': notifications,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'],
      fullName: map['fullName'],
      age: map['age'],
      gender: map['gender'],
      height: (map['height'] as num).toDouble(),
      weight: (map['weight'] as num).toDouble(),
      healthConditions: List<String>.from(map['healthConditions'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      otherCondition: map['otherCondition'],
      medication: map['medication'],
      dietaryPreferences: List<String>.from(map['dietaryPreferences'] ?? []),
      otherDiet: map['otherDiet'],
      goal: map['goal'],
      activityLevel: map['activityLevel'],
      notifications: List<String>.from(map['notifications'] ?? []),
    );
  }
} 