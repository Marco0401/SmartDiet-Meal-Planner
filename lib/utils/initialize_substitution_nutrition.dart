import '../services/substitution_nutrition_service.dart';

/// Initialize substitution nutrition data
/// Call this when the app starts to ensure default data is available
class InitializeSubstitutionNutrition {
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await SubstitutionNutritionService.initializeDefaultSubstitutionData();
      _initialized = true;
      print('DEBUG: Substitution nutrition data initialized successfully');
    } catch (e) {
      print('ERROR: Failed to initialize substitution nutrition data: $e');
    }
  }
}
