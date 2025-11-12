import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'services/allergen_detection_service.dart';
import 'services/notification_service.dart';
import 'services/nutrition_progress_notifier.dart';
import 'services/allergen_detection_service.dart';
import 'services/health_warning_service.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/substitution_dialog_helper.dart';
import 'widgets/health_warning_dialog.dart';
import 'widgets/time_picker_dialog.dart' as time_picker;
import 'widgets/edit_meal_dialog.dart';
import 'recipe_detail_page.dart';
import 'manual_meal_entry_page.dart';
import 'nutrition_analytics_page.dart';
import 'expert_meal_plans_page.dart';
import 'models/user_profile.dart';
import 'utils/error_handler.dart';
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

  TimeOfDay _normalizeMealTime(dynamic timeValue, String mealType) {
    if (timeValue is TimeOfDay) {
      return timeValue;
    }
    if (timeValue is Map) {
      final hour = timeValue['hour'];
      final minute = timeValue['minute'];
      if (hour is int && minute is int) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    if (timeValue is String && timeValue.contains(':')) {
      final parts = timeValue.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
        }
      }
    }
    return getDefaultTimeForMealType(mealType);
  }

  // Helper function to extract all ingredient names from a recipe
  List<String> _extractAllIngredientNames(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
    final extendedIngredients = recipe['extendedIngredients'] as List<dynamic>? ?? [];
    
    final allIngredientNames = <String>[];
    
    // Add basic ingredients
    allIngredientNames.addAll(ingredients.map((ing) => ing.toString().toLowerCase()));
    
    // Add extended ingredients
    for (final ing in extendedIngredients) {
      if (ing is Map<String, dynamic>) {
        final name = (ing['name'] ?? ing['originalName'] ?? '').toString().toLowerCase();
        if (name.isNotEmpty) {
          allIngredientNames.add(name);
        }
      } else {
        allIngredientNames.add(ing.toString().toLowerCase());
      }
    }
    
    return allIngredientNames;
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
              .collection('meal_plans')
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
    // Check internet connectivity first
    final hasInternet = await ErrorHandler.hasInternetConnection();
    if (!hasInternet && mounted) {
      setState(() {
        _error = 'No internet connection. Please check your network and try again.';
      });
      ErrorHandler.showOfflineSnackbar(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

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
                Map<String, dynamic> meal;
                if (item is Map<String, dynamic>) {
                  meal = item;
                } else if (item is Map) {
                  // Convert Map<dynamic, dynamic> to Map<String, dynamic>
                  meal = Map<String, dynamic>.from(item);
                } else {
                  continue; // Skip invalid items
                }
                
                // Ensure ingredients are properly formatted for RecipeDetailPage
                final ingredients = meal['ingredients'] ?? [];
                final extendedIngredients = meal['extendedIngredients'];
                
                // Debug: Check if summary/description are preserved in loaded meal
                print('DEBUG: Loaded meal ${meal['title']} - summary: ${meal['summary']}, description: ${meal['description']}');
                print('DEBUG: Loaded meal keys: ${meal.keys.toList()}');
                print('DEBUG: Raw meal data from Firestore: $meal');
                
                // Convert ingredients to proper format if needed
                List<dynamic> processedIngredients = ingredients;
                if (ingredients is List && ingredients.isNotEmpty) {
                  processedIngredients = ingredients.map((ingredient) {
                    if (ingredient is Map<String, dynamic>) {
                      // Already in object format, keep as-is
                      return ingredient;
                    } else {
                      // Convert string to object format
                      return {
                        'amount': 1,
                        'unit': '',
                        'name': ingredient.toString(),
                      };
                    }
                  }).toList();
                }
                
                // Update the meal with processed ingredients
                meal['ingredients'] = processedIngredients;
                meal['extendedIngredients'] = extendedIngredients;
                
                // Ensure recipeId is preserved if it exists
                if (meal['recipeId'] == null && meal['id'] != null) {
                  // If no recipeId, use the meal ID as fallback
                  meal['recipeId'] = meal['id'];
                }
                
                // Debug: Check if summary/description are still preserved after processing
                print('DEBUG: After processing meal ${meal['title']} - summary: ${meal['summary']}, description: ${meal['description']}');
                print('DEBUG: After processing meal keys: ${meal.keys.toList()}');
                
                meals.add(meal);
              }
            }
          }

          // Load from meal_plans collection (new structure)
          final individualMealsQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('meal_plans')
              .where('date', isEqualTo: dateKey)
              .get();

          for (final mealDoc in individualMealsQuery.docs) {
            final mealData = mealDoc.data();
            print('DEBUG: Loaded meal from Firestore: ${mealDoc.id}');
            print('DEBUG: Meal data structure: ${mealData.keys.toList()}');
            print('DEBUG: Firestore mealType: ${mealData['mealType']}');
            print('DEBUG: Firestore meal_type: ${mealData['meal_type']}');
            print('DEBUG: Firestore image: ${mealData['image']} (type: ${mealData['image'].runtimeType})');
            print('DEBUG: Ingredients type: ${mealData['ingredients'].runtimeType}');
            print('DEBUG: Ingredients content: ${mealData['ingredients']}');
            print('DEBUG: Firestore summary: ${mealData['summary']} (type: ${mealData['summary'].runtimeType})');
            print('DEBUG: Firestore description: ${mealData['description']} (type: ${mealData['description'].runtimeType})');
            
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
        final mealTime = _normalizeMealTime(mealData['mealTime'], normalizedMealType);

        final convertedMeal = {
          'id': mealDoc.id,
          'date': dateKey, // Add date field from Firestore for Edit button
          'title': mealData['title'] ?? 'Unknown Meal',
          'mealType': normalizedMealType,
          'mealTime': mealTime,
          'nutrition': mealData['nutrition'] ?? {},
          'ingredients': ingredients, // Keep as-is for compatibility
          'summary': mealData['summary'], // Include summary field
          'extendedIngredients': extendedIngredients, // Preserve original API ingredient structure
          'instructions': mealData['instructions'] ?? '',
          'image': mealData['image'],
          'cuisine': mealData['cuisine'],
          'description': mealData['description'],
          'hasAllergens': mealData['hasAllergens'] ?? false,
          'detectedAllergens': mealData['detectedAllergens'],
          'substituted': mealData['substituted'] ?? false,
          'originalAllergens': mealData['originalAllergens'],
          'originalNutrition': mealData['originalNutrition'], // Preserve original nutrition for substituted meals
          'substitutions': mealData['substitutions'],
          'recipeId': mealData['recipeId'], // Preserve original recipe ID
          'source': mealData['source'] ?? 'meal_planner',
        };
            meals.add(convertedMeal);
                    }

          print('DEBUG: Loaded ${meals.length} meals for $dateKey');
          
          for (final meal in meals) {
            print('DEBUG: Meal: ${meal['title']} (${meal['mealType']}) - ${meal['nutrition']?['calories']} cal');
            print('DEBUG: Meal nutrition data: ${meal['nutrition']}');
            print('DEBUG: Meal nutrition type: ${meal['nutrition']?.runtimeType}');
          }
          _weeklyMeals[dateKey] = meals;
        }
      }
    } on FirebaseException catch (e) {
      print('DEBUG: Firebase error loading meals: ${e.code} - ${e.message}');
      final errorMessage = ErrorHandler.getFirestoreErrorMessage(e);
      setState(() {
        _error = errorMessage;
      });
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, errorMessage);
      }
    } on SocketException catch (_) {
      print('DEBUG: Network error loading meals');
      setState(() {
        _error = 'No internet connection. Please check your network.';
      });
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
    } on TimeoutException catch (_) {
      print('DEBUG: Timeout error loading meals');
      setState(() {
        _error = 'Request timeout. Please try again.';
      });
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Request timeout. Please try again.');
      }
    } catch (e) {
      print('DEBUG: Unknown error loading meals: $e');
      final errorMessage = ErrorHandler.getGeneralErrorMessage(e);
      setState(() {
        _error = errorMessage;
      });
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            .collection('meal_plans')
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
    print('DEBUG: _buildMealImage called with path: $imagePath');
    print('DEBUG: Path starts with /: ${imagePath.startsWith('/')}');
    print('DEBUG: Path starts with file://: ${imagePath.startsWith('file://')}');
    print('DEBUG: Path contains /storage/: ${imagePath.contains('/storage/')}');
    print('DEBUG: Path contains /data/: ${imagePath.contains('/data/')}');
    print('DEBUG: Path starts with data:image: ${imagePath.startsWith('data:image')}');
    
    // Check if it's a base64 data URI (from manual meal entries)
    if (imagePath.startsWith('data:image')) {
      try {
        final base64String = imagePath.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG: Error loading base64 image: $error');
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
      } catch (e) {
        print('DEBUG: Error parsing base64 image: $e');
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
      }
    }
    // Check if it's a local asset image
    else if (imagePath.startsWith('assets/')) {
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
    } else if (imagePath.startsWith('/') || imagePath.startsWith('file://') || imagePath.contains('/storage/') || imagePath.contains('/data/')) {
      // Local file image
      return Image.file(
        File(imagePath),
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
          print('DEBUG: Adding substituted meal - checking health warnings first');
          
          // Even substituted meals need health warnings check
          final healthWarnings = await HealthWarningService.checkMealHealth(
            mealData: result,
            customTitle: result['title'],
          );
          
          if (healthWarnings.isNotEmpty) {
            print('DEBUG: Health/dietary warnings detected in substituted meal: ${healthWarnings.length} warnings');
            
            // Show health warning dialog
            final shouldContinue = await showHealthWarningDialog(
              context: context,
              warnings: healthWarnings,
              mealTitle: result['title'] ?? 'Unknown Recipe',
            );
            
            if (shouldContinue != true) {
              print('DEBUG: User cancelled substituted meal addition due to health/dietary warnings');
              return; // User chose to cancel
            }
            
            print('DEBUG: User chose to continue with substituted meal despite health/dietary warnings');
          }
          
          // Create the meal object for substituted meal
          final newMeal = {
            ...result,
            'mealType': mealType,
            'mealTime': getDefaultTimeForMealType(mealType),
            'addedAt': DateTime.now().toIso8601String(),
            'id': null, // Will be set by Firestore
            'recipeId': result['id'], // Preserve original recipe ID for fetching details
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
        
        // Check for health warnings and dietary preferences FIRST
        print('DEBUG: Checking health warnings for meal planner meal: ${result['title']}');
        final healthWarnings = await HealthWarningService.checkMealHealth(
          mealData: result,
          customTitle: result['title'],
        );
        
        if (healthWarnings.isNotEmpty) {
          print('DEBUG: Health/dietary warnings detected in meal planner: ${healthWarnings.length} warnings');
          
          // Show health warning dialog
          final shouldContinue = await showHealthWarningDialog(
            context: context,
            warnings: healthWarnings,
            mealTitle: result['title'] ?? 'Unknown Recipe',
          );
          
          if (shouldContinue != true) {
            print('DEBUG: User cancelled meal addition due to health/dietary warnings');
            return; // User chose to cancel
          }
          
          print('DEBUG: User chose to continue despite health/dietary warnings');
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
          'recipeId': result['id'], // Preserve original recipe ID for fetching details
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
        print('DEBUG: Added estimated fiber: ${nutritionCopy['fiber']}g for $calories calories');
      }
    }
    
    return nutritionCopy;
  }

  Future<void> _saveMealsToFirestore(String dateKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('DEBUG: Saving ${_weeklyMeals[dateKey]?.length ?? 0} meals for $dateKey');
        
        // Get Firestore references
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final mealPlansRef = userRef.collection('meal_plans');
        
        // Only save meals that don't already have an ID (new meals)
        for (final meal in _weeklyMeals[dateKey] ?? []) {
          if (meal['id'] == null) {
            print('DEBUG: Saving new meal to meal_plans: ${meal['title']} (${meal['mealType']}) - ${meal['nutrition']?['calories']} cal');
            
            // Convert mealTime to Map if it's a TimeOfDay object
            Map<String, int> mealTimeData;
            if (meal['mealTime'] != null) {
              if (meal['mealTime'] is TimeOfDay) {
                final timeOfDay = meal['mealTime'] as TimeOfDay;
                mealTimeData = {
                  'hour': timeOfDay.hour,
                  'minute': timeOfDay.minute,
                };
              } else {
                mealTimeData = meal['mealTime'] as Map<String, int>;
              }
            } else {
              final defaultTime = getDefaultTimeForMealType(meal['mealType'] ?? 'lunch');
              mealTimeData = {
                'hour': defaultTime.hour,
                'minute': defaultTime.minute,
              };
            }
            
            final docRef = await mealPlansRef.add({
              'title': meal['title'] ?? 'Planned Meal',
              'date': dateKey,
              'meal_type': meal['mealType'] ?? 'lunch',
              'mealType': meal['mealType'] ?? 'lunch', // Keep both for compatibility
              'mealTime': mealTimeData,
              'nutrition': _ensureNutritionWithFiber(meal['nutrition'] ?? {}),
              'ingredients': meal['ingredients'] ?? [],
              'extendedIngredients': meal['extendedIngredients'], // Preserve original API ingredient structure
              'instructions': meal['instructions'] ?? '',
              'image': meal['image'], // Include image
              'cuisine': meal['cuisine'], // Include cuisine
              'description': meal['description'], // Include description
              'summary': meal['summary'], // Include summary
              'hasAllergens': meal['hasAllergens'] ?? false, // Include allergen info
              'detectedAllergens': meal['detectedAllergens'], // Include detected allergens
              'substituted': meal['substituted'] ?? false, // Include substitution info
              'originalAllergens': meal['originalAllergens'], // Include original allergens if substituted
              'substitutions': meal['substitutions'], // Include substitutions if applied
              'recipeId': meal['recipeId'], // Preserve original recipe ID for fetching details
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
              'userId': user.uid,
              'source': 'meal_planner',
            });
            
            // Update the local meal with the document ID
            meal['id'] = docRef.id;
            print('DEBUG: Assigned ID ${docRef.id} to meal: ${meal['title']}');
            
            // Show motivational progress notification for newly added meal
            final nutrition = meal['nutrition'] as Map<String, dynamic>? ?? {};
            if (mounted && nutrition.isNotEmpty) {
              final mealDate = DateFormat('yyyy-MM-dd').parse(dateKey);
              await NutritionProgressNotifier.showProgressNotification(
                context,
                nutrition,
                mealDate: mealDate,
              );
            }
          } else {
            print('DEBUG: Skipping existing meal: ${meal['title']} (ID: ${meal['id']})');
          }
        }
        print('DEBUG: Successfully saved new meals for $dateKey');
      }
    } on FirebaseException catch (e) {
      print('DEBUG: Firebase error saving meals: ${e.code} - ${e.message}');
      final errorMessage = ErrorHandler.getFirestoreErrorMessage(e);
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, errorMessage);
      }
    } on SocketException catch (_) {
      print('DEBUG: Network error saving meals');
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
    } catch (e) {
      print('DEBUG: Unknown error saving meals: $e');
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          'Failed to save meal. Please try again.',
        );
      }
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
              .collection('meal_plans')
              .doc(mealId)
              .delete();
          print('DEBUG: Successfully deleted meal from meal_plans: ${mealToRemove['title']}');
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

  final Set<DateTime> _selectedWeeks = {};

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

      final copiedWeeksCount = _selectedWeeks.length;

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
              // Clone meal for local state usage
              final newMeal = Map<String, dynamic>.from(meal);
              newMeal.remove('id'); // Remove ID so it gets a new one
              newMeal['date'] = targetDateKey;

              // Prepare Firestore-safe payload with proper structure
              Map<String, int> mealTimeData;
              if (newMeal['mealTime'] is TimeOfDay) {
                final timeOfDay = newMeal['mealTime'] as TimeOfDay;
                mealTimeData = {
                  'hour': timeOfDay.hour,
                  'minute': timeOfDay.minute,
                };
              } else if (newMeal['mealTime'] is Map) {
                mealTimeData = Map<String, int>.from(newMeal['mealTime']);
              } else {
                final defaultTime = getDefaultTimeForMealType(newMeal['mealType'] ?? 'lunch');
                mealTimeData = {
                  'hour': defaultTime.hour,
                  'minute': defaultTime.minute,
                };
              }

              // Save to Firestore with properly structured data
              final docRef = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('meal_plans')
                  .add({
                'title': newMeal['title'] ?? 'Planned Meal',
                'date': targetDateKey,
                'meal_type': newMeal['mealType'] ?? 'lunch',
                'mealType': newMeal['mealType'] ?? 'lunch',
                'mealTime': mealTimeData,
                'nutrition': _ensureNutritionWithFiber(newMeal['nutrition'] ?? {}),
                'ingredients': newMeal['ingredients'] ?? [],
                'extendedIngredients': newMeal['extendedIngredients'],
                'instructions': newMeal['instructions'] ?? '',
                'image': newMeal['image'],
                'cuisine': newMeal['cuisine'],
                'description': newMeal['description'],
                'summary': newMeal['summary'],
                'hasAllergens': newMeal['hasAllergens'] ?? false,
                'detectedAllergens': newMeal['detectedAllergens'],
                'substituted': newMeal['substituted'] ?? false,
                'originalAllergens': newMeal['originalAllergens'],
                'substitutions': newMeal['substitutions'],
                'recipeId': newMeal['recipeId'],
                'created_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
                'userId': user.uid,
                'source': 'meal_planner',
              });

              newMeal['id'] = docRef.id;

              // Ensure local copy keeps TimeOfDay instance for UI
              final normalizedMealType = newMeal['mealType']?.toString() ?? 'Lunch';
              newMeal['mealTime'] = _normalizeMealTime(newMeal['mealTime'], normalizedMealType);

              if (_weeklyMeals[targetDateKey] == null) {
                _weeklyMeals[targetDateKey] = [];
              }
              _weeklyMeals[targetDateKey]!.add(newMeal);
            }
          }
        }
      }

      // Reload meals to show copied data
      await _loadWeeklyMeals();

      setState(() {
        _isLoading = false;
        _selectedWeeks.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan copied to $copiedWeeksCount week(s) successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      print('DEBUG: Firebase error copying plan: ${e.code} - ${e.message}');
      final errorMessage = ErrorHandler.getFirestoreErrorMessage(e);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ErrorHandler.showErrorSnackbar(context, 'Failed to copy plan: $errorMessage');
      }
    } on SocketException catch (_) {
      print('DEBUG: Network error copying plan');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
    } catch (e) {
      print('DEBUG: Unknown error copying plan: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          'Failed to copy plan. Please try again.',
        );
      }
    }
  }

  Future<void> _clearMealsForDate(String dateKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get existing meals for this date from meal_plans collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .where('date', isEqualTo: dateKey)
          .get();

      // Delete each meal
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      // Also clear from local state
      _weeklyMeals[dateKey] = [];
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
                    Icons.restaurant_menu,
                    color: Colors.white,
                  ),
                  onPressed: () => _navigateToExpertMealPlans(),
                  tooltip: 'Expert Meal Plans',
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                        _loadWeeklyMeals();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 8,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadWeeklyMeals();
              },
              child: Column(
                children: [
                  // Week Navigation
                  _buildWeekNavigation(startOfWeek),


                  // Weekly Calendar
                  Expanded(child: _buildWeeklyCalendar(startOfWeek)),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = startOfWeek.add(Duration(days: index));
        final dateKey = _formatDate(date);
        final meals = _weeklyMeals[dateKey] ?? [];
        final nutrition = _calculateDailyNutrition(dateKey);
        final now = DateTime.now();
        final isToday = date.day == now.day && date.month == now.month && date.year == now.year;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isToday 
                  ? [Colors.green[50]!, Colors.green[100]!]
                  : [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isToday ? Colors.green[300]! : Colors.grey[200]!,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isToday ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                blurRadius: isToday ? 12 : 8,
                offset: Offset(0, isToday ? 6 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Header with gradient background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isToday
                          ? [Colors.green[400]!, Colors.green[600]!]
                          : [Colors.grey[300]!, Colors.grey[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isToday ? Icons.today : Icons.calendar_today,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDisplayDate(date),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (nutrition['calories'] > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${nutrition['calories'].toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'cal',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Meals content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal type header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getMealTypeColor(mealType).withOpacity(0.1),
                                _getMealTypeColor(mealType).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getMealTypeColor(mealType).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _getMealTypeColor(mealType).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getMealTypeIcon(mealType),
                                  size: 18,
                                  color: _getMealTypeColor(mealType),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                mealType,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _getMealTypeColor(mealType),
                                ),
                              ),
                              const Spacer(),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _addMeal(dateKey, mealType),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getMealTypeColor(mealType).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 20,
                                      color: _getMealTypeColor(mealType),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (mealTypeMeals.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 12, top: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No meals planned',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...mealTypeMeals.asMap().entries.map((entry) {
                            final meal = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(left: 12, bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    if (meal['id'] != null) {
                                      print('DEBUG: Opening meal from planner: ${meal['title']}');
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RecipeDetailPage(recipe: meal),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Meal image
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: meal['image'] != null && meal['image'].toString().isNotEmpty
                                              ? _buildMealImage(meal['image'])
                                              : Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        _getMealTypeColor(mealType).withOpacity(0.3),
                                                        _getMealTypeColor(mealType).withOpacity(0.1),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.restaurant_menu,
                                                    color: _getMealTypeColor(mealType),
                                                    size: 28,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Meal info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      meal['title'] ?? 'Unknown Meal',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey[800],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (meal['hasAllergens'] == true || meal['substituted'] == true)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: meal['substituted'] == true 
                                                            ? Colors.green.withOpacity(0.15)
                                                            : Colors.orange.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        meal['substituted'] == true 
                                                            ? Icons.swap_horiz
                                                            : Icons.warning_amber,
                                                        size: 14,
                                                        color: meal['substituted'] == true 
                                                            ? Colors.green[700]
                                                            : Colors.orange[700],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  if (meal['nutrition'] != null)...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.local_fire_department,
                                                            size: 12,
                                                            color: Colors.green[700],
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            '${(meal['nutrition']['calories'] ?? 0).toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.green[700],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  GestureDetector(
                                                    onTap: () => _editMealTime(dateKey, meal),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 12,
                                                            color: Colors.green[600],
                                                          ),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            (meal['mealTime'] as TimeOfDay? ?? getDefaultTimeForMealType(meal['mealType'] ?? 'lunch')).format(context),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.green[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _removeMeal(dateKey, meals.indexOf(meal)),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Colors.red[600],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          ],
        ),
      ),
        );
    },
  );
}

  // Helper methods for meal type styling
  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.green[600]!;
      case 'lunch':
        return Colors.green[700]!;
      case 'dinner':
        return Colors.green[800]!;
      case 'snack':
        return Colors.green[500]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  void _showNutritionAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NutritionAnalyticsPage()),
    );
  }

  void _navigateToExpertMealPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpertMealPlansPage()),
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
          fullRecipe = details;
          print('DEBUG: Successfully fetched full recipe details');
                } catch (e) {
          print('DEBUG: Error fetching full recipe details: $e');
          // Continue with basic recipe data
        }
      }
      
      // Check for health warnings first (based on health conditions)
      print('DEBUG: Checking health warnings for recipe: ${fullRecipe['title']}');
      final healthWarnings = await HealthWarningService.checkMealHealth(
        mealData: fullRecipe,
        customTitle: fullRecipe['title'],
      );
      
      if (healthWarnings.isNotEmpty) {
        print('DEBUG: Health warnings detected: ${healthWarnings.length} warnings');
        
        // Show health warning dialog
        final shouldContinue = await showHealthWarningDialog(
          context: context,
          warnings: healthWarnings,
          mealTitle: fullRecipe['title'] ?? 'Unknown Recipe',
        );
        
        if (shouldContinue != true) {
          print('DEBUG: User cancelled due to health warnings');
          return; // User chose to cancel
        }
        
        print('DEBUG: User chose to continue despite health warnings');
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
                final substitutionResult = await SubstitutionDialogHelper.showSubstitutionDialog(
                  context,
                  fullRecipe,
                  detectedAllergens,
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
                  final substitutedMeal = <String, dynamic>{
                    ...substitutionResult,
                    'mealType': widget.mealType,
                    'addedAt': DateTime.now().toIso8601String(),
                    'id': null, // Will be set by Firestore
                    'hasAllergens': false, // Mark as safe after substitution
                    'substituted': true, // Mark as substituted
                    // Preserve original recipe's summary and description
                    'summary': recipe['summary'] ?? substitutionResult['summary'],
                    'description': recipe['description'] ?? substitutionResult['description'],
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
    } else if (imagePath.startsWith('/') || imagePath.startsWith('file://') || imagePath.contains('/storage/') || imagePath.contains('/data/')) {
      // Local file image
      return Image.file(
        File(imagePath),
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


