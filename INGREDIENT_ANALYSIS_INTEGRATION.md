# Ingredient Analysis Service - Integration Guide

## Quick Start

### Step 1: Import the Service

```dart
import 'package:my_app/services/ingredient_analysis_service.dart';
```

### Step 2: Integrate with Existing Allergen Detection

Update `AllergenDetectionService.detectAllergensInRecipe()`:

```dart
static Future<Map<String, dynamic>> detectAllergensInRecipe(Map<String, dynamic> recipe) async {
  // ... existing code ...
  
  // NEW: Analyze ingredients for hidden allergens
  final ingredients = recipe['extendedIngredients'] ?? recipe['ingredients'] ?? [];
  final analysis = IngredientAnalysisService.analyzeRecipeIngredients(ingredients);
  
  // Combine direct and hidden allergen detections
  final hiddenAllergens = analysis['hiddenAllergens'] as Map<String, Map<String, double>>;
  
  for (final allergenType in hiddenAllergens.keys) {
    // Check if user is allergic to this type
    for (final userAllergen in userAllergens) {
      final normalizedUser = _normalizeAllergenKey(userAllergen);
      if (normalizedUser == allergenType) {
        if (!detectedAllergens.contains(userAllergen)) {
          detectedAllergens.add(userAllergen);
          print('DEBUG: Found hidden allergen: $userAllergen');
        }
      }
    }
  }
  
  // Add warnings to result
  return {
    'hasAllergens': detectedAllergens.isNotEmpty,
    'detectedAllergens': detectedAllergens,
    'safeToEat': detectedAllergens.isEmpty,
    'hiddenAllergens': hiddenAllergens,
    'warnings': analysis['warnings'],
    'recipe': recipe,
  };
}
```

### Step 3: Update Substitution Dialogs

In `ingredient_substitution_dialog.dart`:

```dart
void _findSubstitutableIngredients() async {
  // ... existing code ...
  
  // NEW: Get safe substitutions
  final userAllergens = await AllergenDetectionService.getUserAllergens();
  
  for (final allergen in widget.detectedAllergens) {
    final allergenType = AllergenService.normalizeAllergenName(allergen);
    
    // Get safe substitutions that avoid user's other allergens
    final safeSubs = IngredientAnalysisService.getSafeSubstitutions(
      allergenName,
      userAllergens,
    );
    
    // Validate each substitution
    final validatedSubs = safeSubs.where((sub) {
      return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
    }).toList();
    
    _substitutionOptions[allergenName] = validatedSubs;
  }
}
```

### Step 4: Display Hidden Allergen Warnings

In `recipe_detail_page.dart`:

```dart
Widget _buildAllergenSection(Map<String, dynamic> details) {
  // ... existing code ...
  
  // NEW: Show hidden allergen warnings
  final warnings = details['warnings'] as List<String>? ?? [];
  
  if (warnings.isNotEmpty) {
    return Column(
      children: [
        // ... existing allergen display ...
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ Potential Hidden Allergens',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              ...warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $warning',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
  
  return existingAllergenWidget;
}
```

## Advanced Usage

### Example 1: Ingredient Preprocessing

```dart
// Before checking allergens, extract base ingredients
final processedIngredients = ingredients.map((ingredient) {
  final name = ingredient['name']?.toString() ?? '';
  final base = IngredientAnalysisService.extractBaseIngredient(name);
  
  return {
    ...ingredient,
    'baseName': base,
    'originalName': name,
  };
}).toList();

// Check both original and base names
for (final ingredient in processedIngredients) {
  checkAllergen(ingredient['originalName']);
  checkAllergen(ingredient['baseName']);
}
```

### Example 2: Detailed Analysis Report

```dart
// Generate and display detailed report
final analysis = IngredientAnalysisService.analyzeRecipeIngredients(ingredients);
final report = IngredientAnalysisService.generateIngredientReport(analysis);

// Show in debug mode or admin panel
if (kDebugMode) {
  print(report);
}

// Or display to user
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Ingredient Analysis'),
    content: SingleChildScrollView(
      child: Text(report),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);
```

### Example 3: Smart Substitution Suggestions

```dart
// Get context-aware substitutions
String getSmartSubstitution(String ingredient, List<String> userAllergens) {
  final base = IngredientAnalysisService.extractBaseIngredient(ingredient);
  final safeSubs = IngredientAnalysisService.getSafeSubstitutions(base, userAllergens);
  
  // Filter by user preferences
  final validSubs = safeSubs.where((sub) {
    return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
  }).toList();
  
  if (validSubs.isEmpty) {
    return 'No safe substitutions available';
  }
  
  // Return best match
  return validSubs.first;
}
```

## Migration Path

### Phase 1: Add Service (Current)
- ✅ Create `IngredientAnalysisService`
- ✅ Add comprehensive allergen databases
- ✅ Implement core analysis functions

### Phase 2: Integrate with Detection
- Update `AllergenDetectionService` to use ingredient analysis
- Add hidden allergen detection to recipe scanning
- Display warnings in UI

### Phase 3: Enhance Substitutions
- Update substitution dialogs to use safe substitutions
- Validate all substitutions before showing to user
- Add confidence indicators

### Phase 4: User Features
- Add "Show Analysis Report" button
- Allow users to report incorrect detections
- Implement feedback loop for improvements

## Testing Checklist

- [ ] Base ingredient extraction works correctly
- [ ] Hidden allergens detected in cream soups
- [ ] Worcestershire sauce detected as fish
- [ ] Whey detected as dairy
- [ ] Safe substitutions exclude user allergens
- [ ] Substitution validation prevents unsafe swaps
- [ ] Analysis report generates correctly
- [ ] Warnings display in UI
- [ ] Performance acceptable for large recipes
- [ ] No false positives on safe ingredients

## Troubleshooting

### Issue: Too many false positives
**Solution**: Adjust confidence thresholds or add to false positive list

### Issue: Missing allergen detections
**Solution**: Add missing derivatives to `allergenDerivatives` map

### Issue: Substitutions still unsafe
**Solution**: Enhance `isSubstitutionSafe()` validation logic

### Issue: Performance slow
**Solution**: Implement caching for frequently analyzed ingredients

## Support

For questions or issues:
1. Check the comprehensive documentation in `INGREDIENT_ANALYSIS_SYSTEM.md`
2. Review test cases in `test/ingredient_analysis_service_test.dart`
3. Enable debug logging to see analysis details
4. Report issues with specific ingredient examples
