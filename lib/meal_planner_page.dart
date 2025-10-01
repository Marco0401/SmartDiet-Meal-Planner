import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'services/allergen_detection_service.dart';
import 'services/notification_service.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/ingredient_substitution_dialog.dart';
import 'widgets/time_picker_dialog.dart' as time_picker;
import 'recipe_detail_page.dart';
import 'manual_meal_entry_page.dart';
import 'barcode_scanner_page.dart';
import 'nutrition_analytics_page.dart';
import 'models/user_profile.dart';
import 'dart:math';

class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key});

  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<Map<String, dynamic>>> _weeklyMeals = {};
  bool _isLoading = false;
  String? _error;
  
  // Analytics integration
  final Map<String, Map<String, dynamic>> _weeklyNutrition = {};
  bool _isAnalyticsLoading = false;
  
  // Nutrition goals (can be made configurable later)
  final Map<String, double> _nutritionGoals = {
    'calories': 2000,
    'protein': 50,
    'carbs': 250,
    'fat': 65,
    'fiber': 25,
    'sugar': 50,
  };

  // Meal types
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

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

  @override
  void initState() {
    super.initState();
    _loadWeeklyMeals();
    // Clean up any duplicate meals that might exist
    _cleanupDuplicateMeals();
    
    // Schedule periodic notifications
    _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    try {
      await NotificationService.schedulePeriodicNotifications();
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  Future<void> _editMealTime(String dateKey, Map<String, dynamic> meal) async {
    final currentTime = meal['mealTime'] as TimeOfDay? ?? getDefaultTimeForMealType(meal['mealType'] ?? 'lunch');
    
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => time_picker.TimePickerDialog(
        initialTime: currentTime,
        title: 'Edit ${meal['title']} Time',
      ),
    );

    if (selectedTime != null && selectedTime != currentTime) {
      setState(() {
        meal['mealTime'] = selectedTime;
      });

      // Update in Firestore
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && meal['id'] != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .doc(meal['id'])
              .update({
            'mealTime': {
              'hour': selectedTime.hour,
              'minute': selectedTime.minute,
            },
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meal time updated to ${selectedTime.format(context)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error updating meal time: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meal time: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadWeeklyMeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get the start of the week (Monday)
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );

        // Load meals for the entire week
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = _formatDate(date);

          // Load from both old format (document with meals array) and new format (individual meal documents)
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .doc(dateKey)
              .get();

          List<Map<String, dynamic>> meals = [];

          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final mealsData = data['meals'];
            if (mealsData is List) {
              // Safely convert each item to Map<String, dynamic>
              for (final item in mealsData) {
                if (item is Map<String, dynamic>) {
                  meals.add(item);
                } else if (item is Map) {
                  // Convert Map<dynamic, dynamic> to Map<String, dynamic>
                  meals.add(Map<String, dynamic>.from(item));
                }
              }
            }
          }

          // Also load individual meal documents for this date
          final individualMealsQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .where('date', isEqualTo: dateKey)
              .get();

          for (final mealDoc in individualMealsQuery.docs) {
            final mealData = mealDoc.data();
            print('DEBUG: Loaded meal from Firestore: ${mealDoc.id}');
            print('DEBUG: Meal data structure: ${mealData.keys.toList()}');
            print('DEBUG: Firestore mealType: ${mealData['mealType']}');
            print('DEBUG: Firestore meal_type: ${mealData['meal_type']}');
            print('DEBUG: Ingredients type: ${mealData['ingredients'].runtimeType}');
            print('DEBUG: Ingredients content: ${mealData['ingredients']}');
            
            if (mealData is Map<String, dynamic>) {
              // Convert individual meal document to meal planner format
              // Ensure ingredients are properly formatted for RecipeDetailPage
              final ingredients = mealData['ingredients'] ?? [];
              final extendedIngredients = mealData['extendedIngredients'];
              
          // Normalize meal type to proper case (Breakfast, Lunch, Dinner, Snack)
          String normalizedMealType = mealData['mealType'] ?? mealData['meal_type'] ?? 'lunch';
          normalizedMealType = normalizedMealType.toLowerCase();
          switch (normalizedMealType) {
            case 'breakfast':
              normalizedMealType = 'Breakfast';
              break;
            case 'lunch':
              normalizedMealType = 'Lunch';
              break;
            case 'dinner':
              normalizedMealType = 'Dinner';
              break;
            case 'snack':
              normalizedMealType = 'Snack';
              break;
            default:
              normalizedMealType = 'Lunch';
          }

          // Handle meal time - use stored time or default based on meal type
          TimeOfDay mealTime;
          if (mealData['mealTime'] != null) {
            // Convert stored time back to TimeOfDay
            final timeData = mealData['mealTime'];
            if (timeData is Map && timeData['hour'] != null && timeData['minute'] != null) {
              mealTime = TimeOfDay(hour: timeData['hour'], minute: timeData['minute']);
          } else {
              mealTime = getDefaultTimeForMealType(normalizedMealType);
            }
          } else {
            mealTime = getDefaultTimeForMealType(normalizedMealType);
          }

          final convertedMeal = {
            'id': mealDoc.id,
            'title': mealData['title'] ?? 'Unknown Meal',
            'mealType': normalizedMealType,
            'mealTime': mealTime,
            'nutrition': mealData['nutrition'] ?? {},
            'ingredients': ingredients, // Keep as-is for compatibility
            'extendedIngredients': extendedIngredients, // Preserve original API ingredient structure
            'instructions': mealData['instructions'] ?? '',
            'image': mealData['image'],
            'cuisine': mealData['cuisine'],
            'description': mealData['description'],
            'hasAllergens': mealData['hasAllergens'] ?? false,
            'detectedAllergens': mealData['detectedAllergens'],
            'substituted': mealData['substituted'] ?? false,
            'originalAllergens': mealData['originalAllergens'],
            'substitutions': mealData['substitutions'],
            'source': mealData['source'] ?? 'meal_planner',
          };
              meals.add(convertedMeal);
            } else if (mealData is Map) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              final convertedData = Map<String, dynamic>.from(mealData);
              
              // Normalize meal type to proper case (Breakfast, Lunch, Dinner, Snack)
              String normalizedMealType = convertedData['mealType'] ?? convertedData['meal_type'] ?? 'lunch';
              normalizedMealType = normalizedMealType.toLowerCase();
              switch (normalizedMealType) {
                case 'breakfast':
                  normalizedMealType = 'Breakfast';
                  break;
                case 'lunch':
                  normalizedMealType = 'Lunch';
                  break;
                case 'dinner':
                  normalizedMealType = 'Dinner';
                  break;
                case 'snack':
                  normalizedMealType = 'Snack';
                  break;
                default:
                  normalizedMealType = 'Lunch';
              }
              
              // Handle meal time - use stored time or default based on meal type
              TimeOfDay mealTime;
              if (convertedData['mealTime'] != null) {
                // Convert stored time back to TimeOfDay
                final timeData = convertedData['mealTime'];
                if (timeData is Map && timeData['hour'] != null && timeData['minute'] != null) {
                  mealTime = TimeOfDay(hour: timeData['hour'], minute: timeData['minute']);
                } else {
                  mealTime = getDefaultTimeForMealType(normalizedMealType);
                }
              } else {
                mealTime = getDefaultTimeForMealType(normalizedMealType);
              }

              final convertedMeal = {
                'id': mealDoc.id,
                'title': convertedData['title'] ?? 'Unknown Meal',
                'mealType': normalizedMealType,
                'mealTime': mealTime,
                'nutrition': convertedData['nutrition'] ?? {},
                'ingredients': convertedData['ingredients'] ?? [],
                'instructions': convertedData['instructions'] ?? '',
                'image': convertedData['image'],
                'cuisine': convertedData['cuisine'],
                'description': convertedData['description'],
                'hasAllergens': convertedData['hasAllergens'] ?? false,
                'detectedAllergens': convertedData['detectedAllergens'],
                'substituted': convertedData['substituted'] ?? false,
                'originalAllergens': convertedData['originalAllergens'],
                'substitutions': convertedData['substitutions'],
                'source': convertedData['source'] ?? 'meal_planner',
              };
              meals.add(convertedMeal);
            }
          }

          print('DEBUG: Loaded ${meals.length} meals for $dateKey');
          for (final meal in meals) {
            print('DEBUG: Meal: ${meal['title']} (${meal['mealType']}) - ${meal['nutrition']?['calories']} cal');
          }
          _weeklyMeals[dateKey] = meals;
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupDuplicateMeals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: Starting cleanup of duplicate meals...');
        
        // Get all meals for the current week
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        
        final mealsQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .where('date', isGreaterThanOrEqualTo: _formatDate(startOfWeek))
            .where('date', isLessThan: _formatDate(endOfWeek))
            .get();
        
        // Group meals by title, date, and mealType to find duplicates
        Map<String, List<QueryDocumentSnapshot>> mealGroups = {};
        
        for (final doc in mealsQuery.docs) {
          final data = doc.data();
          final title = data['title'] ?? 'Unknown';
          final date = data['date'] ?? '';
          final mealType = data['mealType'] ?? 'Unknown';
          final key = '$title-$date-$mealType';
          
          if (mealGroups[key] == null) {
            mealGroups[key] = [];
          }
          mealGroups[key]!.add(doc);
        }
        
        // Delete duplicates (keep the first one, delete the rest)
        int deletedCount = 0;
        for (final group in mealGroups.values) {
          if (group.length > 1) {
            // Keep the first one, delete the rest
            for (int i = 1; i < group.length; i++) {
              await group[i].reference.delete();
              deletedCount++;
              final data = group[i].data() as Map<String, dynamic>;
              print('DEBUG: Deleted duplicate meal: ${data['title']} (${data['mealType']})');
            }
          }
        }
        
        print('DEBUG: Cleanup complete. Deleted $deletedCount duplicate meals.');
        
        if (deletedCount > 0) {
          // Reload the meals after cleanup
          await _loadWeeklyMeals();
        }
      }
    } catch (e) {
      print('DEBUG: Error during cleanup: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMealImage(String imagePath) {
    // Check if it's a local asset image
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.green,
            ),
          );
        },
      );
    } else {
      // Network image
      return Image.network(
        imagePath,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.green,
            ),
          );
        },
      );
    }
  }

  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${_getDayName(date.weekday)} ${date.month}/${date.day}';
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Future<void> _addMeal(String dateKey, String mealType) async {
    print('DEBUG: Opening AddMealDialog for $dateKey - $mealType');
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddMealDialog(
        dateKey: dateKey, 
        mealType: mealType,
        onMealAdded: (meal) async {
          // Check if it's a refresh request
          if (meal['refresh'] == true) {
            print('DEBUG: Refresh requested from manual entry');
            _loadWeeklyMeals();
            return;
          }
          
          // Add to local state
          setState(() {
            if (_weeklyMeals[dateKey] == null) {
              _weeklyMeals[dateKey] = [];
            }
            _weeklyMeals[dateKey]!.add(meal);
          });
          
          // Save to Firestore
          await _saveMealsToFirestore(dateKey);
          print('DEBUG: Substituted meal saved successfully');
          
          // Generate notification for successful substitution
          await NotificationService.createNotification(
            title: 'Ingredient Substituted',
            message: 'Successfully substituted ingredients in ${meal['title'] ?? 'recipe'}',
            type: 'Updates',
            icon: Icons.check_circle,
            color: Colors.green,
          );
        },
      ),
    );

    print('DEBUG: AddMealDialog result: $result');

    if (result != null) {
      // Check if it's a refresh request from manual entry
      if (result['refresh'] == true) {
        print('DEBUG: Refresh requested, reloading meals');
        _loadWeeklyMeals();
        return;
      }

      // If the result contains a meal from the dialog (recipe selection)
      if (result['title'] != null) {
        print('DEBUG: Adding meal: ${result['title']} to $dateKey');
        
        // Check if this is a substituted meal
        if (result['substituted'] == true) {
          print('DEBUG: Adding substituted meal directly');
          // Create the meal object for substituted meal
          final newMeal = {
            ...result,
            'mealType': mealType,
            'mealTime': getDefaultTimeForMealType(mealType),
            'addedAt': DateTime.now().toIso8601String(),
            'id': null, // Will be set by Firestore
            'hasAllergens': false, // Mark as safe after substitution
            'substituted': true, // Mark as substituted
          };
          
          // Add to local state
      setState(() {
        if (_weeklyMeals[dateKey] == null) {
          _weeklyMeals[dateKey] = [];
        }
            _weeklyMeals[dateKey]!.add(newMeal);
          });
          
          // Save to Firestore
          await _saveMealsToFirestore(dateKey);
          print('DEBUG: Substituted meal saved successfully');
          return;
        }
        
        // Check for allergens in the meal
        final allergenResult = await AllergenDetectionService.getDetailedAnalysis(result);
        final hasAllergens = allergenResult['hasAllergens'] == true;
        
        print('DEBUG: Allergen check result - hasAllergens: $hasAllergens, detectedAllergens: ${allergenResult['detectedAllergens']}');
        
        // Create the meal object without an ID first
        final newMeal = {
          ...result,
          'mealType': mealType,
          'mealTime': getDefaultTimeForMealType(mealType),
          'addedAt': DateTime.now().toIso8601String(),
          'id': null, // Ensure no ID initially
          'hasAllergens': hasAllergens, // Mark if meal has allergens
          'detectedAllergens': hasAllergens ? allergenResult['detectedAllergens'] : null,
        };
        
        print('DEBUG: Final meal object with allergen data: $newMeal');

        setState(() {
          if (_weeklyMeals[dateKey] == null) {
            _weeklyMeals[dateKey] = [];
          }
          _weeklyMeals[dateKey]!.add(newMeal);
        });

        print('DEBUG: Added meal to local state, now saving to Firestore...');
        // Save to Firestore and get the ID
      await _saveMealsToFirestore(dateKey);
        print('DEBUG: Meal saved successfully');
        
        // Generate allergy warning notification if meal has allergens
        if (hasAllergens) {
          final detectedAllergens = List<String>.from(allergenResult['detectedAllergens'] ?? []);
          await NotificationService.generateAllergyWarnings(
            detectedAllergens, 
            result['title'] ?? 'Unknown Recipe'
          );
        }
      } else {
        print('DEBUG: Result has no title, not adding meal');
      }
    } else {
      print('DEBUG: No result from AddMealDialog');
    }
  }

  /// Ensure nutrition data includes fiber (estimate if missing)
  Map<String, dynamic> _ensureNutritionWithFiber(Map<String, dynamic> nutrition) {
    final nutritionCopy = Map<String, dynamic>.from(nutrition);
    
    // If fiber is missing, estimate it based on calories (calories * 0.02)
    if (nutritionCopy['fiber'] == null) {
      final calories = nutritionCopy['calories'];
      if (calories != null && calories is num) {
        nutritionCopy['fiber'] = (calories * 0.02).round();
        print('DEBUG: Added estimated fiber: ${nutritionCopy['fiber']}g for ${calories} calories');
      }
    }
    
    return nutritionCopy;
  }

  Future<void> _saveMealsToFirestore(String dateKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: Saving ${_weeklyMeals[dateKey]?.length ?? 0} meals for $dateKey');
        // Only save meals that don't already have an ID (new meals)
        for (final meal in _weeklyMeals[dateKey] ?? []) {
          if (meal['id'] == null) {
            print('DEBUG: Saving new meal: ${meal['title']} (${meal['mealType']}) - ${meal['nutrition']?['calories']} cal');
                final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
                    .add({
                      'title': meal['title'] ?? 'Planned Meal',
              'date': dateKey,
                      'meal_type': meal['mealType'] ?? 'lunch',
                      'mealType': meal['mealType'] ?? 'lunch', // Keep both for compatibility
                      'mealTime': meal['mealTime'] != null ? {
                        'hour': meal['mealTime'].hour,
                        'minute': meal['mealTime'].minute,
                      } : {
                        'hour': getDefaultTimeForMealType(meal['mealType'] ?? 'lunch').hour,
                        'minute': getDefaultTimeForMealType(meal['mealType'] ?? 'lunch').minute,
                      },
                      'nutrition': _ensureNutritionWithFiber(meal['nutrition'] ?? {}),
                      'ingredients': meal['ingredients'] ?? [],
                      'extendedIngredients': meal['extendedIngredients'], // Preserve original API ingredient structure
                      'instructions': meal['instructions'] ?? '',
                      'image': meal['image'], // Include image
                      'cuisine': meal['cuisine'], // Include cuisine
                      'description': meal['description'], // Include description
                      'hasAllergens': meal['hasAllergens'] ?? false, // Include allergen info
                      'detectedAllergens': meal['detectedAllergens'], // Include detected allergens
                      'substituted': meal['substituted'] ?? false, // Include substitution info
                      'originalAllergens': meal['originalAllergens'], // Include original allergens if substituted
                      'substitutions': meal['substitutions'], // Include substitutions if applied
                      'created_at': FieldValue.serverTimestamp(),
                      'source': 'meal_planner',
                    });
            
            // Update the local meal with the document ID
            meal['id'] = docRef.id;
            print('DEBUG: Assigned ID ${docRef.id} to meal: ${meal['title']}');
          } else {
            print('DEBUG: Skipping existing meal: ${meal['title']} (ID: ${meal['id']})');
          }
        }
        print('DEBUG: Successfully saved new meals for $dateKey');
      }
    } catch (e) {
      print('DEBUG: Error saving meals: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving meal: $e')));
    }
  }

  Future<void> _removeMeal(String dateKey, int index) async {
    final mealToRemove = _weeklyMeals[dateKey]![index];
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete the individual meal document if it has an ID
        if (mealToRemove['id'] != null) {
          final mealId = mealToRemove['id'].toString();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .doc(mealId)
              .delete();
          print('DEBUG: Successfully deleted individual meal document: ${mealToRemove['title']}');
        }
        
        // Check if there's an old format document that might contain this meal
        // Only delete it if the meal being deleted doesn't have an individual document ID
        if (mealToRemove['id'] == null) {
          final oldFormatDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meals')
              .doc(dateKey)
              .get();
              
          if (oldFormatDoc.exists && oldFormatDoc.data()?['meals'] != null) {
            print('DEBUG: Found old format document, removing specific meal from array...');
            final data = oldFormatDoc.data()!;
            final mealsArray = List<Map<String, dynamic>>.from(data['meals'] ?? []);
            
            // Remove the specific meal from the array
            mealsArray.removeWhere((meal) => 
              meal['title'] == mealToRemove['title'] && 
              meal['mealType'] == mealToRemove['mealType']
            );
            
            if (mealsArray.isEmpty) {
              // If no meals left, delete the entire document
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('meals')
                  .doc(dateKey)
                  .delete();
              print('DEBUG: Deleted old format document (no meals left)');
            } else {
              // Update the document with remaining meals
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('meals')
                  .doc(dateKey)
                  .update({'meals': mealsArray});
              print('DEBUG: Updated old format document with remaining meals');
            }
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error deleting meal documents: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting meal: $e'))
      );
      return; // Don't remove from local state if Firestore delete failed
    }
    
    // Only remove from local state if Firestore delete was successful
    setState(() {
      _weeklyMeals[dateKey]!.removeAt(index);
    });
  }

  Map<String, dynamic> _calculateDailyNutrition(String dateKey) {
    final meals = _weeklyMeals[dateKey] ?? [];
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in meals) {
      final nutritionData = meal['nutrition'];
      if (nutritionData != null) {
        // Safely convert to Map<String, dynamic>
        Map<String, dynamic> nutrition;
        if (nutritionData is Map<String, dynamic>) {
          nutrition = nutritionData;
        } else if (nutritionData is Map) {
          nutrition = Map<String, dynamic>.from(nutritionData);
        } else {
          continue; // Skip if not a map
        }
        
        totalCalories += (nutrition['calories'] ?? 0).toDouble();
        totalProtein += (nutrition['protein'] ?? 0).toDouble();
        totalCarbs += (nutrition['carbs'] ?? 0).toDouble();
        totalFat += (nutrition['fat'] ?? 0).toDouble();
      }
    }

    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  Set<DateTime> _selectedWeeks = {};

  Future<void> _copyPlanToOtherWeeks() async {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    
    // Check if current week has any meals
    bool hasMeals = false;
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = _formatDate(date);
      if (_weeklyMeals[dateKey]?.isNotEmpty == true) {
        hasMeals = true;
        break;
      }
    }
    
    if (!hasMeals) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meals found in current week to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show dialog to select target weeks
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Copy Plan to Other Weeks'),
          content: const Text(
            'This will copy your current week\'s meal plan to the selected weeks. '
            'Existing meals in those weeks will be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showWeekSelectionDialog(startOfWeek);
              },
              child: const Text('Select Weeks'),
            ),
          ],
        );
      },
    );
  }

  void _showWeekSelectionDialog(DateTime currentWeekStart) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Target Weeks'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Choose which weeks to copy your plan to:'),
                    const SizedBox(height: 16),
                    ...List.generate(4, (index) {
                      final weekStart = currentWeekStart.add(Duration(days: (index + 1) * 7));
                      final weekEnd = weekStart.add(const Duration(days: 6));
                      final isSelected = _selectedWeeks.contains(weekStart);
                      
                      return CheckboxListTile(
                        title: Text('Week of ${_formatDate(weekStart)} - ${_formatDate(weekEnd)}'),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedWeeks.add(weekStart);
                            } else {
                              _selectedWeeks.remove(weekStart);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _selectedWeeks.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _selectedWeeks.isEmpty ? null : () {
                    Navigator.of(context).pop();
                    _performCopyPlan(currentWeekStart);
                  },
                  child: const Text('Copy Plan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performCopyPlan(DateTime currentWeekStart) async {
    if (_selectedWeeks.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Copy meals for each selected week
      for (final targetWeekStart in _selectedWeeks) {
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
          final sourceDate = currentWeekStart.add(Duration(days: dayOffset));
          final targetDate = targetWeekStart.add(Duration(days: dayOffset));
          final sourceDateKey = _formatDate(sourceDate);
          final targetDateKey = _formatDate(targetDate);
          
          final sourceMeals = _weeklyMeals[sourceDateKey] ?? [];
          
          if (sourceMeals.isNotEmpty) {
            // Clear existing meals for target date
            await _clearMealsForDate(targetDateKey);
            
            // Copy meals to target date
            for (final meal in sourceMeals) {
              final newMeal = Map<String, dynamic>.from(meal);
              newMeal.remove('id'); // Remove ID so it gets a new one
              newMeal['date'] = targetDateKey;
              
              // Save to Firestore
              final docRef = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('meals')
                  .add(newMeal);
              
              newMeal['id'] = docRef.id;
              
              // Update local state
              if (_weeklyMeals[targetDateKey] == null) {
                _weeklyMeals[targetDateKey] = [];
              }
              _weeklyMeals[targetDateKey]!.add(newMeal);
            }
          }
        }
      }

      setState(() {
        _isLoading = false;
        _selectedWeeks.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan copied to ${_selectedWeeks.length} week(s) successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearMealsForDate(String dateKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get existing meals for this date
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('date', isEqualTo: dateKey)
          .get();

      // Delete each meal
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing meals for date $dateKey: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Meal Planner',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
        actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                  ),
                  onPressed: () => _showAIPlanningDialog(),
                  tooltip: 'Let AI Plan for You',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    await _loadWeeklyMeals();
                    await _cleanupDuplicateMeals();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshed and cleaned up duplicates'))
                    );
                  },
                  tooltip: 'Refresh & Cleanup',
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.analytics,
                    color: Colors.white,
                  ),
            onPressed: () => _showNutritionAnalytics(),
            tooltip: 'Nutrition Analytics',
                ),
          ),
        ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
              children: [
                // Week Navigation
                _buildWeekNavigation(startOfWeek),


                // Weekly Calendar
                Expanded(child: _buildWeeklyCalendar(startOfWeek)),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _copyPlanToOtherWeeks(),
            heroTag: "copy_plan",
            backgroundColor: Colors.blue[600],
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.copy_all,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
        onPressed: () => _showQuickAddMeal(),
            heroTag: "quick_add",
        icon: const Icon(Icons.add),
            label: const Text(
              "Quick Add",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation(DateTime startOfWeek) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border.all(
          color: Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: Colors.green[700],
              ),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
              _loadWeeklyMeals();
            },
          ),
          ),
          Expanded(
            child: Text(
            '${_formatDisplayDate(startOfWeek)} - ${_formatDisplayDate(startOfWeek.add(const Duration(days: 6)))}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: Colors.green[700],
              ),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
              _loadWeeklyMeals();
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(DateTime startOfWeek) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = startOfWeek.add(Duration(days: index));
        final dateKey = _formatDate(date);
        final meals = _weeklyMeals[dateKey] ?? [];
        final nutrition = _calculateDailyNutrition(dateKey);
        final isToday = date.isAtSameMomentAs(
          DateTime.now().subtract(
            Duration(days: DateTime.now().weekday - date.weekday),
          ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: isToday ? 4 : 2,
          color: isToday ? Colors.green[50] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.green[800] : Colors.green[700],
                      ),
                    ),
                    if (nutrition['calories'] > 0)
                      Text(
                        '${nutrition['calories'].toStringAsFixed(0)} cal',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Meal Types
                ..._mealTypes.map((mealType) {
                  final mealTypeMeals = meals
                      .where((meal) => 
                          (meal['mealType'] == mealType) || 
                          (meal['meal_type'] == mealType.toLowerCase()))
                      .toList();
                  
                  // Sort meals by time within each meal type
                  mealTypeMeals.sort((a, b) {
                    final timeA = a['mealTime'] as TimeOfDay? ?? getDefaultTimeForMealType(mealType);
                    final timeB = b['mealTime'] as TimeOfDay? ?? getDefaultTimeForMealType(mealType);
                    return timeA.hour.compareTo(timeB.hour) != 0 
                        ? timeA.hour.compareTo(timeB.hour)
                        : timeA.minute.compareTo(timeB.minute);
                  });
                  
                  print('DEBUG: Filtering meals for $mealType on $dateKey');
                  print('DEBUG: Total meals available: ${meals.length}');
                  print('DEBUG: Meals found for $mealType: ${mealTypeMeals.length}');
                  for (final meal in mealTypeMeals) {
                    print('DEBUG: Meal in UI: ${meal['title']} - mealType: ${meal['mealType']} - hasAllergens: ${meal['hasAllergens']} - substituted: ${meal['substituted']}');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mealType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => _addMeal(dateKey, mealType),
                            color: Colors.green,
                          ),
                        ],
                      ),
                      if (mealTypeMeals.isNotEmpty)
                        ...mealTypeMeals.asMap().entries.map((entry) {
                          final meal = entry.value;

                          return Card(
                            margin: const EdgeInsets.only(left: 16, bottom: 8),
                            child: ListTile(
                              leading: meal['image'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildMealImage(meal['image']),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: Colors.green,
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                meal['title'] ?? 'Unknown Meal',
                                style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (meal['hasAllergens'] == true || meal['substituted'] == true)
                                    Tooltip(
                                      message: meal['substituted'] == true 
                                          ? 'Substituted ingredients: ${(meal['substitutions'] as Map?)?.values.map((v) => v.toString()).join(', ') ?? 'N/A'}'
                                          : 'Contains allergens: ${(meal['detectedAllergens'] as List?)?.join(', ') ?? 'N/A'}',
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: meal['substituted'] == true 
                                              ? Colors.blue.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          meal['substituted'] == true 
                                              ? Icons.swap_horiz
                                              : Icons.warning_amber_rounded,
                                          size: 16,
                                          color: meal['substituted'] == true 
                                              ? Colors.blue[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (meal['nutrition'] != null)
                                    Text(
                                      '${(meal['nutrition']['calories'] ?? 0).toStringAsFixed(0)} cal',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _editMealTime(dateKey, meal),
                                        child: Text(
                                          (meal['mealTime'] as TimeOfDay? ?? getDefaultTimeForMealType(meal['mealType'] ?? 'lunch')).format(context),
                                          style: TextStyle(
                                            color: Colors.blue[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _removeMeal(dateKey, meals.indexOf(meal)),
                                color: Colors.red[400],
                              ),
                              onTap: () {
                                if (meal['id'] != null) {
                                  print('DEBUG: Opening meal from planner: ${meal['title']}');
                                  print('DEBUG: Meal data keys: ${meal.keys.toList()}');
                                  print('DEBUG: Ingredients type: ${meal['ingredients'].runtimeType}');
                                  print('DEBUG: Ingredients content: ${meal['ingredients']}');
                                  print('DEBUG: ExtendedIngredients type: ${meal['extendedIngredients']?.runtimeType}');
                                  print('DEBUG: ExtendedIngredients content: ${meal['extendedIngredients']}');
                                  
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RecipeDetailPage(recipe: meal),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }),
                      if (mealTypeMeals.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 16),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No $mealType planned',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuickAddMeal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuickAddMealSheet(
        onMealAdded: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal added successfully!'))
          );
        },
      ),
    );
  }

  void _showNutritionAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionAnalyticsPage()),
    );
  }

  // Analytics Integration Methods
  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadWeeklyAnalytics() async {
    setState(() {
      _isAnalyticsLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final startOfWeek = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );

        // Load nutrition for the entire week
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = _formatDate(date);

          // Use existing meals data if available
          if (_weeklyMeals.containsKey(dateKey)) {
            final meals = _weeklyMeals[dateKey]!;
            final nutrition = _calculateNutritionFromMeals(meals);
            _weeklyNutrition[dateKey] = nutrition;
          } else {
            // Load from Firestore if not in memory
            final mealsQuery = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('meals')
                .where('date', isEqualTo: dateKey)
                .get();

            if (mealsQuery.docs.isNotEmpty) {
              List<Map<String, dynamic>> allMeals = [];
              
              for (final doc in mealsQuery.docs) {
                final data = doc.data();
                String title = 'Unknown Meal';
                Map<String, dynamic> nutrition = {};
                String mealType = 'lunch';
                
                if (data['title'] != null) {
                  title = data['title'].toString();
                } else if (data['name'] != null) {
                  title = data['name'].toString();
                }
                
                if (data['nutrition'] != null) {
                  if (data['nutrition'] is Map<String, dynamic>) {
                    nutrition = data['nutrition'];
                  } else if (data['nutrition'] is Map) {
                    nutrition = Map<String, dynamic>.from(data['nutrition']);
                  }
                }
                
                if (data['mealType'] != null) {
                  mealType = data['mealType'].toString();
                } else if (data['meal_type'] != null) {
                  mealType = data['meal_type'].toString();
                }
                
                allMeals.add({
                  'title': title,
                  'nutrition': nutrition,
                  'mealType': mealType,
                });
              }
              
              final nutrition = _calculateNutritionFromMeals(allMeals);
              _weeklyNutrition[dateKey] = nutrition;
            } else {
              _weeklyNutrition[dateKey] = _getEmptyNutrition();
            }
          }
        }
      }
    } catch (e) {
      print('Error loading analytics: $e');
    } finally {
      setState(() {
        _isAnalyticsLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateNutritionFromMeals(List<Map<String, dynamic>> meals) {
    final nutrition = <String, double>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
    };

    for (final meal in meals) {
      final mealNutrition = meal['nutrition'] as Map<String, dynamic>? ?? {};
      for (final key in nutrition.keys) {
        nutrition[key] = nutrition[key]! + _toDouble(mealNutrition[key]);
      }
    }

    return nutrition;
  }

  Map<String, dynamic> _getEmptyNutrition() {
    return {
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
    };
  }

  Map<String, dynamic> _calculateWeeklyAverages() {
    final totals = <String, double>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
    };

    int daysWithData = 0;
    for (final nutrition in _weeklyNutrition.values) {
      final calories = _toDouble(nutrition['calories']);
      if (calories > 0) {
        daysWithData++;
        for (final key in totals.keys) {
          totals[key] = totals[key]! + _toDouble(nutrition[key]);
        }
      }
    }

    if (daysWithData == 0) return _getEmptyNutrition();

    final averages = <String, dynamic>{};
    for (final key in totals.keys) {
      averages[key] = totals[key]! / daysWithData;
    }

    return averages;
  }

  Widget _buildAnalyticsSection(DateTime startOfWeek) {
    if (_isAnalyticsLoading) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final weeklyAverages = _calculateWeeklyAverages();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Weekly Nutrition Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Weekly summary cards
            Row(
              children: [
                Expanded(
                  child: _buildNutritionMetric(
                    'Avg Calories',
                    _toDouble(weeklyAverages['calories']),
                    _nutritionGoals['calories']!,
                    Colors.orange,
                    'kcal',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNutritionMetric(
                    'Avg Protein',
                    _toDouble(weeklyAverages['protein']),
                    _nutritionGoals['protein']!,
                    Colors.blue,
                    'g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNutritionMetric(
                    'Avg Carbs',
                    _toDouble(weeklyAverages['carbs']),
                    _nutritionGoals['carbs']!,
                    Colors.green,
                    'g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNutritionMetric(
                    'Avg Fat',
                    _toDouble(weeklyAverages['fat']),
                    _nutritionGoals['fat']!,
                    Colors.red,
                    'g',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Daily breakdown
            _buildDailyNutritionBreakdown(startOfWeek),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionMetric(
    String label,
    double value,
    double goal,
    Color color,
    String unit,
  ) {
    final percentage = goal > 0 ? (value / goal * 100).clamp(0, 200) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${value.round()}$unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
          const SizedBox(height: 2),
          Text(
            '${percentage.round()}%',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyNutritionBreakdown(DateTime startOfWeek) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = startOfWeek.add(Duration(days: index));
              final dateKey = _formatDate(date);
              final nutrition = _weeklyNutrition[dateKey] ?? _getEmptyNutrition();
              final dayName = DateFormat('EEE').format(date);

              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMiniMetric(
                      'Cal',
                      _toDouble(nutrition['calories']),
                      Colors.orange,
                    ),
                    _buildMiniMetric(
                      'P',
                      _toDouble(nutrition['protein']),
                      Colors.blue,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[600],
            ),
          ),
          Text(
            '${value.round()}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // AI Meal Planning Feature
  void _showAIPlanningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('AI Meal Planning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let AI create a personalized weekly meal plan for you!',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI will consider:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Your allergies and dietary preferences'),
                  const Text('• Your body goals and activity level'),
                  const Text('• Balanced nutrition and variety'),
                  const Text('• Filipino and international cuisines'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will replace your current week\'s meal plan.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _generateAIMealPlan();
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAIMealPlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'AI is creating your personalized meal plan...',
                style: TextStyle(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Load user profile
      final userProfile = await _loadUserProfile(user.uid);
      
      // Generate AI meal plan
      final mealPlan = await _createPersonalizedMealPlan(userProfile);
      
      // Save the meal plan to Firestore
      await _saveMealPlanToFirestore(user.uid, mealPlan);
      
      // Reload meals
      await _loadWeeklyMeals();
      
      // Close progress dialog
      Navigator.pop(context);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('AI meal plan generated successfully! 🎉'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      // Close progress dialog
      Navigator.pop(context);
      
      print('Error generating AI meal plan: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating meal plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<UserProfile?> _loadUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error loading user profile: $e');
      return null;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _createPersonalizedMealPlan(UserProfile? userProfile) async {
    // Get available recipes
    final allRecipes = await _getAllAvailableRecipes();
    
    // Filter recipes based on user preferences
    final filteredRecipes = _filterRecipesByPreferences(allRecipes, userProfile);
    
    // Calculate daily nutrition targets
    final nutritionTargets = _calculateNutritionTargets(userProfile);
    
    // Generate balanced meal plan
    final mealPlan = <String, List<Map<String, dynamic>>>{};
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    for (int day = 0; day < 7; day++) {
      final date = startOfWeek.add(Duration(days: day));
      final dateKey = _formatDate(date);
      
      // Generate meals for this day
      final dayMeals = _generateDayMeals(filteredRecipes, nutritionTargets, day);
      mealPlan[dateKey] = dayMeals;
    }
    
    return mealPlan;
  }

  Future<List<Map<String, dynamic>>> _getAllAvailableRecipes() async {
    List<Map<String, dynamic>> allRecipes = [];
    
    try {
      // Get Filipino recipes
      final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('');
      allRecipes.addAll(filipinoRecipes.cast<Map<String, dynamic>>());
      
      // Get some API recipes for variety
      final apiRecipes = await RecipeService.fetchRecipes('healthy meal');
      allRecipes.addAll(apiRecipes.cast<Map<String, dynamic>>());
      
      print('DEBUG: Total recipes available for AI planning: ${allRecipes.length}');
      return allRecipes;
    } catch (e) {
      print('Error fetching recipes: $e');
      // Fallback to just Filipino recipes
      final fallbackRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('');
      return fallbackRecipes.cast<Map<String, dynamic>>();
    }
  }

  List<Map<String, dynamic>> _filterRecipesByPreferences(
    List<Map<String, dynamic>> recipes,
    UserProfile? userProfile,
  ) {
    if (userProfile == null) return recipes;
    
    return recipes.where((recipe) {
      // Filter by allergies
      final allergens = userProfile.allergies;
      if (allergens.isNotEmpty) {
        final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
        final ingredientText = ingredients.join(' ').toLowerCase();
        
        for (final allergen in allergens) {
          if (ingredientText.contains(allergen.toLowerCase())) {
            return false; // Skip recipes with allergens
          }
        }
      }
      
      // Filter by dietary preferences
      final dietaryPrefs = userProfile.dietaryPreferences;
      if (dietaryPrefs.contains('Vegetarian')) {
        final ingredientText = (recipe['ingredients'] as List<dynamic>? ?? [])
            .join(' ').toLowerCase();
        if (ingredientText.contains('meat') || 
            ingredientText.contains('chicken') || 
            ingredientText.contains('pork') || 
            ingredientText.contains('beef') ||
            ingredientText.contains('fish')) {
          return false;
        }
      }
      
      if (dietaryPrefs.contains('Vegan')) {
        final ingredientText = (recipe['ingredients'] as List<dynamic>? ?? [])
            .join(' ').toLowerCase();
        if (ingredientText.contains('meat') || 
            ingredientText.contains('chicken') || 
            ingredientText.contains('pork') || 
            ingredientText.contains('beef') ||
            ingredientText.contains('fish') ||
            ingredientText.contains('milk') ||
            ingredientText.contains('cheese') ||
            ingredientText.contains('egg')) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  Map<String, double> _calculateNutritionTargets(UserProfile? userProfile) {
    if (userProfile == null) {
      return {
        'calories': 2000,
        'protein': 150,
        'carbs': 250,
        'fat': 67,
        'fiber': 25,
      };
    }
    
    // Calculate BMR (Basal Metabolic Rate)
    double bmr;
    if (userProfile.gender.toLowerCase() == 'male') {
      bmr = 88.362 + (13.397 * userProfile.weight) + (4.799 * userProfile.height) - (5.677 * userProfile.age);
    } else {
      bmr = 447.593 + (9.247 * userProfile.weight) + (3.098 * userProfile.height) - (4.330 * userProfile.age);
    }
    
    // Apply activity multiplier
    double activityMultiplier = 1.2; // Sedentary default
    switch (userProfile.activityLevel.toLowerCase()) {
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extremely active':
        activityMultiplier = 1.9;
        break;
    }
    
    double calories = bmr * activityMultiplier;
    
    // Adjust for goals
    switch (userProfile.goal.toLowerCase()) {
      case 'lose weight':
        calories *= 0.85; // 15% deficit
        break;
      case 'gain weight':
      case 'gain muscle':
        calories *= 1.15; // 15% surplus
        break;
    }
    
    // Calculate macros
    double protein = (calories * 0.25) / 4; // 25% of calories from protein
    double fat = (calories * 0.30) / 9; // 30% of calories from fat
    double carbs = (calories * 0.45) / 4; // 45% of calories from carbs
    double fiber = calories / 80; // Roughly 1g per 80 calories
    
    return {
      'calories': calories.round().toDouble(),
      'protein': protein.round().toDouble(),
      'carbs': carbs.round().toDouble(),
      'fat': fat.round().toDouble(),
      'fiber': fiber.round().toDouble(),
    };
  }

  List<Map<String, dynamic>> _generateDayMeals(
    List<Map<String, dynamic>> recipes,
    Map<String, double> nutritionTargets,
    int dayIndex,
  ) {
    final dayMeals = <Map<String, dynamic>>[];
    final random = Random(dayIndex + DateTime.now().millisecondsSinceEpoch);
    
    // Separate recipes by meal type preference
    final breakfastRecipes = recipes.where((r) => 
      r['mealType']?.toString().toLowerCase() == 'breakfast' ||
      (r['nutrition']?['calories'] ?? 600) < 500
    ).toList();
    
    final lunchRecipes = recipes.where((r) => 
      r['mealType']?.toString().toLowerCase() == 'lunch' ||
      ((r['nutrition']?['calories'] ?? 600) >= 400 && (r['nutrition']?['calories'] ?? 600) <= 700)
    ).toList();
    
    final dinnerRecipes = recipes.where((r) => 
      r['mealType']?.toString().toLowerCase() == 'dinner' ||
      (r['nutrition']?['calories'] ?? 600) >= 450
    ).toList();
    
    final snackRecipes = recipes.where((r) => 
      r['mealType']?.toString().toLowerCase() == 'snack' ||
      (r['nutrition']?['calories'] ?? 600) < 350
    ).toList();
    
    // Add breakfast
    if (breakfastRecipes.isNotEmpty) {
      final breakfast = breakfastRecipes[random.nextInt(breakfastRecipes.length)];
      dayMeals.add({
        ...breakfast,
        'mealType': 'Breakfast',
        'servings': 1,
      });
    }
    
    // Add lunch
    if (lunchRecipes.isNotEmpty) {
      final lunch = lunchRecipes[random.nextInt(lunchRecipes.length)];
      dayMeals.add({
        ...lunch,
        'mealType': 'Lunch',
        'servings': 1,
      });
    }
    
    // Add dinner
    if (dinnerRecipes.isNotEmpty) {
      final dinner = dinnerRecipes[random.nextInt(dinnerRecipes.length)];
      dayMeals.add({
        ...dinner,
        'mealType': 'Dinner',
        'servings': 1,
      });
    }
    
    // Add snack if needed (based on calorie targets)
    if (snackRecipes.isNotEmpty && nutritionTargets['calories']! > 1800) {
      final snack = snackRecipes[random.nextInt(snackRecipes.length)];
      dayMeals.add({
        ...snack,
        'mealType': 'Snack',
        'servings': 1,
      });
    }
    
    return dayMeals;
  }

  Future<void> _saveMealPlanToFirestore(String uid, Map<String, List<Map<String, dynamic>>> mealPlan) async {
    final batch = FirebaseFirestore.instance.batch();
    
    for (final dateEntry in mealPlan.entries) {
      final dateKey = dateEntry.key;
      final meals = dateEntry.value;
      
      // Clear existing meals for this date
      final existingMealsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('meals')
          .where('date', isEqualTo: dateKey)
          .get();
      
      for (final doc in existingMealsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Add new meals
      for (final meal in meals) {
        final mealRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('meals')
            .doc();
        
        final mealData = {
          ...meal,
          'date': dateKey,
          'addedAt': FieldValue.serverTimestamp(),
          'aiGenerated': true,
          'nutrition': _ensureNutritionWithFiber(meal['nutrition'] ?? {}),
        };
        
        batch.set(mealRef, mealData);
      }
    }
    
    await batch.commit();
    print('DEBUG: AI meal plan saved to Firestore');
  }

}

class AddMealDialog extends StatefulWidget {
  final String dateKey;
  final String mealType;
  final Function(Map<String, dynamic>)? onMealAdded;
  
  const AddMealDialog({super.key, required this.dateKey, required this.mealType, this.onMealAdded});

  @override
  State<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<AddMealDialog> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _searchRecipes();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchRecipes() async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Use comprehensive recipe service for all sources (Spoonacular + TheMealDB + Filipino)
      final results = await RecipeService.fetchRecipes(_searchController.text);
      setState(() {
        _searchResults = results.take(5).toList().cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching recipes: $e')));
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _checkAllergensAndAddRecipe(Map<String, dynamic> recipe) async {
    print('DEBUG: Checking allergens for recipe: ${recipe['title']}');
    
    // First, ensure we have full recipe details for API recipes
    Map<String, dynamic> fullRecipe = recipe;
    
    try {
      final recipeId = recipe['id'];
      
      // Check if this is an API recipe that needs full details
      if (recipeId != null && 
          !recipeId.toString().startsWith('local_') && 
          !recipeId.toString().startsWith('curated_') &&
          recipe['source'] != 'manual_entry' &&
          (recipe['ingredients'] == null || recipe['extendedIngredients'] == null || recipe['instructions'] == null)) {
        
        print('DEBUG: Fetching full details for API recipe: ${recipe['title']}');
        try {
          // Fetch full recipe details from API
          final details = await RecipeService.fetchRecipeDetails(recipeId);
          if (details != null) {
            fullRecipe = details;
            print('DEBUG: Successfully fetched full recipe details');
          } else {
            print('DEBUG: Failed to fetch full recipe details, using basic data');
          }
        } catch (e) {
          print('DEBUG: Error fetching full recipe details: $e');
          // Continue with basic recipe data
        }
      }
      
      // Check for allergens in the recipe (now with full details)
      final allergenResult = await AllergenDetectionService.getDetailedAnalysis(fullRecipe);
      print('DEBUG: Allergen detection result: $allergenResult');
      
      if (allergenResult['hasAllergens'] == true) {
        print('DEBUG: Allergens detected, showing warning dialog');
        // Show allergen warning dialog
        final detectedAllergens = List<String>.from(allergenResult['detectedAllergens'] ?? []);
        final substitutionSuggestions = List<String>.from(allergenResult['substitutionSuggestions'] ?? []);
        final riskLevel = allergenResult['riskLevel'] ?? 'low';
        
        if (mounted) {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AllergenWarningDialog(
              recipe: fullRecipe,
              detectedAllergens: detectedAllergens,
              substitutionSuggestions: substitutionSuggestions,
              riskLevel: riskLevel,
              onContinue: () {
                print('DEBUG: User chose to continue with allergens');
                Navigator.of(context).pop(fullRecipe); // Return recipe to meal planner
              },
              onSubstitute: () async {
                print('DEBUG: User chose to find substitutes');
                // Close the warning dialog and show substitution dialog
                Navigator.of(context).pop();
                
                // Show ingredient substitution dialog
                final substitutionResult = await showDialog<Map<String, dynamic>>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => IngredientSubstitutionDialog(
                    recipe: fullRecipe,
                    detectedAllergens: detectedAllergens,
                  ),
                );
                
                if (substitutionResult != null) {
                  print('DEBUG: User applied substitution, adding meal directly');
                  
                  // Clear search bar and hide search results
                  setState(() {
                    _showSearch = false;
                    _searchController.clear();
                    _searchResults = [];
                    _isSearching = false;
                  });
                  
                  // Create the meal object for substituted meal
                  final substitutedMeal = {
                    ...substitutionResult,
                    'mealType': widget.mealType,
                    'addedAt': DateTime.now().toIso8601String(),
                    'id': null, // Will be set by Firestore
                    'hasAllergens': false, // Mark as safe after substitution
                    'substituted': true, // Mark as substituted
                  };
                  
                  // Add to local state using the callback
                  if (widget.onMealAdded != null) {
                    widget.onMealAdded!(substitutedMeal);
                  }
                  
                  // Close the dialog safely
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          );
          
          // If user chose to continue, return the recipe
          if (result != null) {
            print('DEBUG: Returning recipe from allergen warning: $result');
            Navigator.pop(context, result);
          }
        }
      } else {
        print('DEBUG: No allergens detected, adding recipe directly');
        // No allergens detected, add recipe directly
        Navigator.pop(context, fullRecipe);
      }
    } catch (e) {
      print('Error checking allergens: $e');
      // If allergen check fails, add recipe anyway but show a warning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for allergens. Please review the recipe manually.'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, fullRecipe);
    }
  }


  Widget _buildRecipeImage(String imagePath) {
    // Check if it's a local asset image
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.green,
            ),
          );
        },
      );
    } else {
      // Network image
      return Image.network(
        imagePath,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Colors.green,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Meal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_showSearch) ...[
              // Choice buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManualMealEntryPage(
                              selectedDate: widget.dateKey,
                              mealType: widget.mealType,
                            ),
                          ),
                        );
                        if (result == true) {
                          // Refresh the meal planner
                          if (widget.onMealAdded != null) {
                            widget.onMealAdded!({'refresh': true});
                          }
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Manual Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showSearch = true;
                        });
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Search Recipe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Search interface
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showSearch = false;
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a recipe...',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
                    ),
                  ),
                ],
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty)
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final recipe = _searchResults[index];
                    return ListTile(
                      leading: recipe['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                                child: _buildRecipeImage(recipe['image']),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.green,
                              ),
                            ),
                      title: Text(recipe['title'] ?? 'Unknown Recipe'),
                        onTap: () async {
                          // Check for allergens before adding the recipe
                          await _checkAllergensAndAddRecipe(recipe);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class QuickAddMealSheet extends StatelessWidget {
  final VoidCallback? onMealAdded;
  
  const QuickAddMealSheet({super.key, this.onMealAdded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Quick Add Meal',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManualMealEntryPage(),
                      ),
                    );
                    if (result == true && onMealAdded != null) {
                      onMealAdded!();
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Manual Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerPage(),
                      ),
                    );
                    if (result == true && onMealAdded != null) {
                      onMealAdded!();
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Barcode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
